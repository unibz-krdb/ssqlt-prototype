"""Constraint enforcement SQL generation for the SSTC pipeline.

Generates trigger-based enforcement for MVDs (multivalued dependencies),
FDs/CFDs (functional/conditional functional dependencies), INCs (inclusion
dependencies), and foreign keys derived from inclusion constraints.
"""

from typing import Callable

from rapt2.treebrd.node import SelectNode

from .context import Context
from .guard import (
    GuardHierarchy,
    build_cfd_where_branches,
    extract_defined_attrs,
)
from .table import Table


class UnsupportedError(Exception):
    """Raised when the generator encounters a constraint pattern it cannot compile."""

    pass


RenderFn = Callable[..., str]


def _find_table(name: str, context: Context) -> Table:
    """Look up a table by name in a context. Raises ValueError if not found."""
    for table in context.tables:
        if table.name == name:
            return table
    raise ValueError(f"Table {name} not found in context")


def emit_fk(
    referencing_table: str,
    referencing_cols: list[str],
    referenced_table: str,
    referenced_cols: list[str],
    pks: dict[str, list[str]],
    schema: str,
) -> str | None:
    """Emit an ALTER TABLE ADD FOREIGN KEY, or None if referenced_cols isn't the PK."""
    ref_pk = pks.get(referenced_table, [])
    if sorted(referenced_cols) != sorted(ref_pk):
        return None
    return (
        f"ALTER TABLE {schema}._{referencing_table} "
        f"ADD FOREIGN KEY ({', '.join(referencing_cols)}) "
        f"REFERENCES {schema}._{referenced_table}"
        f" ({', '.join(referenced_cols)});"
    )


def emit_inc_trigger(
    referencing_table: str,
    referencing_col: str,
    referenced_table: str,
    referenced_col: str,
    *,
    idx: int,
    render: RenderFn,
) -> str:
    """Emit a deferred constraint trigger enforcing an inter-table INC.

    The trigger fires AFTER INSERT and is DEFERRABLE INITIALLY DEFERRED so
    the multi-statement mapping cascade can tolerate intermediate
    violations within a transaction. Scoped to single-column references;
    multi-column inter-table INC enforcement is tracked as Tier 3 work in
    docs/notes/open-problems.md.
    The schema prefix is injected by the Generator's render callback.
    """
    return render(
        "inc_inter_check.sql.j2",
        referencing_table=referencing_table,
        referenced_table=referenced_table,
        referencing_col=referencing_col,
        referenced_col=referenced_col,
        idx=idx,
    )


def _inc_direction(inc, *, equivalence: bool) -> tuple[str, list[str], str, list[str]]:
    """Return (referencing_table, referencing_cols, referenced_table, referenced_cols).

    Subsumption inc⊆_{a,b}(R1, R2) means R1.a ⊆ R2.b, so R1 references R2.
    Equivalence inc=_{a,b}(R1, R2) holds in both directions, but we only
    compile one direction (R2 references R1) so it composes with the
    transducer's phased mapping cascade — the reverse direction is
    maintained implicitly by the mapping functions. See
    docs/notes/open-problems.md "Equivalence INC reverse direction".
    """
    names = list(inc.relation_names)
    attrs = list(inc.attributes)
    mid = len(attrs) // 2
    if equivalence:
        # Match the historical emit_fk convention: names[1] references names[0].
        return (names[1], attrs[mid:], names[0], attrs[:mid])
    return (names[0], attrs[:mid], names[1], attrs[mid:])


def inter_table_inc(
    source: Context, target: Context, render: RenderFn, schema: str
) -> str:
    """Generate inter-table inclusion enforcement: FK where possible, trigger otherwise.

    For each INC, a native FK is emitted when the referenced columns equal
    the referenced table's PK; otherwise a per-row AFTER INSERT DEFERRABLE
    INITIALLY DEFERRED constraint trigger enforces the inclusion by subquery. Intra-table subsumptions are
    handled by ``inc_sql``. Equivalence INCs are enforced in only one
    direction at the compiled-SQL layer (see ``_inc_direction`` docstring).
    """
    parts: list[str] = []
    idx = 0

    def emit_one(rfing, rfing_cols, rfed, rfed_cols, pks):
        nonlocal idx
        fk = emit_fk(rfing, rfing_cols, rfed, rfed_cols, pks, schema)
        if fk:
            parts.append(fk)
            return
        if len(rfing_cols) != 1 or len(rfed_cols) != 1:
            raise UnsupportedError(
                f"Multi-column inter-table INC not supported: "
                f"{rfing}({rfing_cols}) -> {rfed}({rfed_cols})"
            )
        idx += 1
        parts.append(
            emit_inc_trigger(
                rfing,
                rfing_cols[0],
                rfed,
                rfed_cols[0],
                idx=idx,
                render=render,
            )
        )

    for context in [source, target]:
        pks = context.primary_keys
        for inc in context.inclusion_equivalences:
            emit_one(*_inc_direction(inc, equivalence=True), pks)
        for inc in context.inclusion_subsumptions:
            names = list(inc.relation_names)
            if names[0] == names[1]:
                continue  # Intra-table: handled by inc_sql in constraints()
            emit_one(*_inc_direction(inc, equivalence=False), pks)
    return "\n".join(parts) if parts else ""


def mvd_sql(context: Context, render: RenderFn) -> str:
    """Generate MVD enforcement for a context: a check function and a grounding function per table.

    The check function is a trigger that rejects inserts violating the
    MVD (same LHS, different RHS without complementary tuple). The
    grounding function inserts the missing complementary tuples to
    restore the 4th-normal-form property. Raises UnsupportedError if
    a table has MVDs with non-shared LHS determinants.
    """
    mvds = context.multivalued_dependencies
    if not mvds:
        return ""

    # Group MVDs by table name
    mvds_by_table: dict[str, list] = {}
    for mvd in mvds:
        mvds_by_table.setdefault(mvd.relation_name, []).append(mvd)

    parts = []
    for table_name, table_mvds in mvds_by_table.items():
        # RAPT2 convention: mvd_{a, b} stores attributes as [a, b]
        # where attrs[:-1] = LHS determinant, attrs[-1:] = determined attribute
        lhs_set = {tuple(list(m.attributes)[:-1]) for m in table_mvds}
        if len(lhs_set) > 1:
            raise UnsupportedError(f"Non-shared-LHS MVDs on {table_name}: {lhs_set}")
        lhs_attrs = list(lhs_set.pop())
        determined_attrs = [list(m.attributes)[-1] for m in table_mvds]

        # Find table object for attribute list
        table = _find_table(table_name, context)
        all_attrs = table.attributes

        # MVD check: r1 for LHS+determined, r2 for rest
        lhs_and_determined = set(lhs_attrs) | set(determined_attrs)
        select_cols = ", ".join(
            f"r1.{a}" if a in lhs_and_determined else f"r2.{a}" for a in all_attrs
        )
        new_cols = ", ".join(f"NEW.{a}" for a in all_attrs)
        join_condition = " AND ".join(f"r1.{a} = r2.{a}" for a in lhs_attrs)

        parts.append(
            render(
                "mvd_check.sql.j2",
                table_name=table_name,
                select_cols=select_cols,
                new_cols=new_cols,
                join_condition=join_condition,
            )
        )

        # MVD grounding: one UNION SELECT per determined attr
        # Each SELECT swaps that determined attr with NEW, keeps rest from r1
        union_selects = []
        for det_attr in determined_attrs:
            cols = ", ".join(
                f"NEW.{a}" if a == det_attr else f"r1.{a}" for a in all_attrs
            )
            union_selects.append({"cols": cols})

        grounding_join = " AND ".join(f"r1.{a} = NEW.{a}" for a in lhs_attrs)

        parts.append(
            render(
                "mvd_grounding.sql.j2",
                table_name=table_name,
                union_selects=union_selects,
                join_condition=grounding_join,
            )
        )

    return "\n\n".join(parts)


def inc_sql(context: Context, render: RenderFn) -> str:
    """Generate trigger-based INC enforcement for intra-table inclusion dependencies."""
    parts = []
    idx = 0
    for inc in context.inclusion_subsumptions:
        names = list(inc.relation_names)
        if names[0] != names[1]:
            continue  # Only handle intra-table INC here; inter-table uses FKs
        idx += 1
        attrs = list(inc.attributes)
        mid = len(attrs) // 2
        if mid != 1:
            raise UnsupportedError(
                f"Multi-column intra-table INC not supported: {attrs}"
            )
        referencing_col = attrs[0]
        referenced_col = attrs[mid]
        pk = context.primary_keys.get(names[0], [])
        parts.append(
            render(
                "inc_check.sql.j2",
                table_name=names[0],
                referencing_col=referencing_col,
                referenced_col=referenced_col,
                referenced_table=names[0],
                self_ref_col=pk[0] if pk else referenced_col,
                inc_index=idx,
            )
        )
    return "\n\n".join(parts) if parts else ""


def fd_sql(context: Context, hierarchy: GuardHierarchy, render: RenderFn) -> str:
    """Generate FD and CFD enforcement trigger functions.

    Unguarded FDs produce a simple check (LHS match implies RHS match).
    Guarded FDs (CFDs) use the guard hierarchy to build exhaustive
    OR-branches covering all null-pattern states that would violate
    the dependency.
    """
    fds = context.functional_dependencies
    if not fds:
        return ""

    parts = []
    for i, fd in enumerate(fds, 1):
        lhs_attrs = list(fd.attributes)[:-1]
        rhs_attrs = list(fd.attributes)[-1:]

        table = _find_table(fd.relation_name, context)
        all_attrs = table.attributes
        new_cols = ", ".join(f"NEW.{a}" for a in all_attrs)

        # Extract guard attributes if FD is guarded (child is SelectNode)
        guard_attrs = []
        if isinstance(fd.child, SelectNode):
            guard_attrs = extract_defined_attrs(fd.child.conditions)

        if guard_attrs:
            # Guarded FD -> CFD template with exhaustive OR branches
            where_branches = build_cfd_where_branches(
                lhs_attrs, rhs_attrs, guard_attrs, hierarchy
            )
            parts.append(
                render(
                    "cfd_check.sql.j2",
                    table_name=fd.relation_name,
                    fd_index=i,
                    new_cols=new_cols,
                    lhs_attrs=lhs_attrs,
                    rhs_attrs=rhs_attrs,
                    where_branches=where_branches,
                )
            )
        else:
            # Unguarded FD -> existing simple template
            lhs_condition = " AND ".join(f"r1.{a} = r2.{a}" for a in lhs_attrs)
            rhs_condition = " AND ".join(f"r1.{a} <> r2.{a}" for a in rhs_attrs)
            parts.append(
                render(
                    "fd_check.sql.j2",
                    table_name=fd.relation_name,
                    fd_index=i,
                    new_cols=new_cols,
                    lhs_attrs=lhs_attrs,
                    rhs_attrs=rhs_attrs,
                    lhs_condition=lhs_condition,
                    rhs_condition=rhs_condition,
                    guard_attrs=[],
                )
            )

    return "\n\n".join(parts)


def constraints(
    source: Context,
    target: Context,
    hierarchy: GuardHierarchy,
    render: RenderFn,
) -> str:
    """Generate all constraint enforcement (MVDs, FDs/CFDs, INCs) for both contexts."""
    parts = []
    for context in [source, target]:
        mvd = mvd_sql(context, render)
        if mvd:
            parts.append(mvd)
        fd = fd_sql(context, hierarchy, render)
        if fd:
            parts.append(fd)
        inc = inc_sql(context, render)
        if inc:
            parts.append(inc)
    return "\n\n".join(parts) if parts else ""
