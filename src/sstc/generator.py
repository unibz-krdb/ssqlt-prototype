"""SQL generator for the SSTC compilation pipeline.

Transforms a TransducerContext (parsed source/target relational algebra)
into executable PostgreSQL DDL: schema creation, base tables, foreign keys,
constraint enforcement (MVDs, CFDs, INCs), insert/delete tracking,
join staging, and bidirectional mapping functions with triggers.
"""

import textwrap
from pathlib import Path

import jinja2

from .constraints import UnsupportedError as UnsupportedError
from .constraints import constraints, inter_table_inc
from .context import Context, Direction
from .guard import (
    GuardHierarchy,
    build_containment_pruning,
    build_guard_hierarchy,
    build_null_pattern_where,
    extract_table_guard_attrs,
)
from .table import Table
from .transducer_context import TransducerContext


SOURCE_LOOP_CHECK = -1
TARGET_LOOP_CHECK = 1
SOURCE_LOOP_VALUE = 1
TARGET_LOOP_VALUE = -1

# Width of the wrapped prose inside a section banner (excludes the "--  " prefix).
_BANNER_WIDTH = 60
# Horizontal rule that opens and closes every section banner.
_BANNER_RULE = "-- " + "=" * _BANNER_WIDTH


class Generator:
    """Compiles a TransducerContext into a complete PostgreSQL SQL script.

    The compilation pipeline produces layered output: a schema preamble,
    base tables with foreign keys, constraint enforcement functions
    (MVDs, FDs/CFDs, INCs), insert/delete tracking infrastructure,
    natural-join staging, and four bidirectional mapping functions
    (source/target x insert/delete) with their triggers.
    """

    def __init__(
        self,
        ctx: TransducerContext,
        schema: str = "transducer",
        comments: bool = False,
    ):
        self.ctx = ctx
        self.schema = schema
        self.comments = comments
        self.env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(Path(__file__).parent / "templates"),
            keep_trailing_newline=True,
            trim_blocks=True,
            lstrip_blocks=True,
        )
        self._hierarchy: GuardHierarchy | None = None

    @property
    def _universal_schema(self) -> list:
        return self.ctx.source.universal_schema

    def _universal_columns(self) -> list[dict]:
        return [
            {"name": a.name, "data_type": a.data_type} for a in self._universal_schema
        ]

    def _universal_col_names(self) -> list[str]:
        return [a.name for a in self._universal_schema]

    def compile(self) -> str:
        """Generate the full SQL script from all pipeline layers.

        Returns a single string containing schema preamble, base tables,
        foreign keys, constraints, tracking, join staging, and mapping
        sections, separated by blank lines.
        """
        if len(self.ctx.source.tables) != 1:
            raise UnsupportedError(
                f"Expected exactly 1 source table, got {len(self.ctx.source.tables)}. "
                "Multi-source-table transducers are not yet supported."
            )
        # Each section pairs a banner title + prose with its generated SQL. The
        # banners are emitted only when ``comments`` is set; numbering follows
        # the fixed pipeline position so empty sections leave gaps rather than
        # renumbering the rest.
        sections = [
            (
                "SCHEMA PREAMBLE",
                "Drop and recreate the transducer schema, then create _loop, "
                "the cycle-detection table that breaks the source<->target "
                "feedback loop, and seed_loop(N), the client helper that "
                "starts an N-statement target-side transaction. Applying "
                "this script destroys any existing transducer schema.",
                self._preamble(),
            ),
            (
                "BASE TABLES",
                "One CREATE TABLE per source and target relation. Primary keys "
                "and NOT NULL come from the universal schema; every object is "
                "_-prefixed inside the transducer schema.",
                self._base_tables(),
            ),
            (
                "REJECT UPDATES",
                "UPDATE propagation is unimplemented. One BEFORE UPDATE trigger "
                "per base table raises an exception so updates fail loudly "
                "instead of bypassing the mapping functions; use DELETE + INSERT.",
                self._reject_updates(),
            ),
            (
                "INTER-TABLE INCLUSION",
                "Inclusion dependencies that cross tables: a native FOREIGN KEY "
                "where the referenced columns are the referenced table's primary "
                "key, otherwise a DEFERRABLE constraint trigger that tolerates "
                "mid-cascade violations.",
                self._inter_table_inc(),
            ),
            (
                "CONSTRAINTS",
                "Intra-table enforcement: FD/CFD checks, MVD check plus grounding "
                "(re-inserting complementary tuples for 4NF), and intra-table "
                "inclusion checks. All run as BEFORE/AFTER INSERT triggers.",
                self._constraints(),
            ),
            (
                "CHANGE TRACKING",
                "Per table: a shadow _INSERT/_DELETE table plus AFTER "
                "INSERT/DELETE capture triggers. Each change is staged for "
                "propagation unless the loop guard shows a sync is already in "
                "flight.",
                self._tracking(),
            ),
            (
                "JOIN STAGING",
                "Natural-join the tracked per-table changes back into universal "
                "tuples in _..._JOIN tables, writing to _loop for cycle "
                "detection. This bridges per-table deltas to the universal "
                "relation the mapping reads.",
                self._join(),
            ),
            (
                "BIDIRECTIONAL MAPPING",
                "The four mapping functions (SOURCE/TARGET x INSERT/DELETE). Each "
                "reads the JOIN staging, projects universal tuples into the "
                "opposite context, and clears tracking state. Inserts use "
                "containment pruning and null-pattern filtering; source-side "
                "deletes sweep each target table for rows no remaining source "
                "row still derives.",
                self._mapping(),
            ),
            (
                "SYNC VERIFICATION",
                "check_sync() reconstructs the universal relation from the "
                "target tables and returns its symmetric difference against "
                "the source table. An empty result means both databases "
                "encode the same instance; rows are labelled with the side "
                "they are missing from.",
                self._verification(),
            ),
        ]
        rendered = []
        for num, (title, description, sql) in enumerate(sections, 1):
            if not sql:
                continue
            if self.comments:
                rendered.append(f"{self._banner(num, title, description)}\n\n{sql}")
            else:
                rendered.append(sql)
        return "\n\n".join(rendered)

    def _render(self, template_name: str, **kwargs) -> str:
        template = self.env.get_template(template_name)
        return template.render(schema=self.schema, comments=self.comments, **kwargs)

    def _banner(self, num: int, title: str, description: str) -> str:
        """Render a section banner: a ruled box with a numbered title and prose."""
        lines = [_BANNER_RULE, f"--  SECTION {num}: {title}"]
        lines += [f"--  {line}" for line in textwrap.wrap(description, _BANNER_WIDTH)]
        lines.append(_BANNER_RULE)
        return "\n".join(lines)

    def _preamble(self) -> str:
        return self._render("preamble.sql.j2")

    def _table_columns(self, table: Table) -> list[dict]:
        schema_by_name = {a.name.lower(): a for a in self._universal_schema}
        columns = []
        for attr_name in table.attributes:
            attr = schema_by_name.get(attr_name.lower())
            if attr:
                columns.append(
                    {
                        "name": attr.name,
                        "data_type": attr.data_type,
                        "is_nullable": attr.is_nullable,
                    }
                )
        return columns

    def _create_table(self, table: Table, context: Context) -> str:
        pk_columns = context.primary_keys.get(table.name, [])
        return self._render(
            "create_table.sql.j2",
            table_name=table.name,
            columns=self._table_columns(table),
            pk_columns=pk_columns,
        )

    def _base_tables(self) -> str:
        parts = []
        for context in [self.ctx.source, self.ctx.target]:
            for table in context.tables:
                parts.append(self._create_table(table, context))
        return "\n".join(parts)

    def _reject_updates(self) -> str:
        """Emit BEFORE UPDATE triggers that raise an exception on every base table.

        UPDATE propagation is not implemented; this ensures the transducer
        fails loudly rather than silently bypassing mapping functions.
        """
        parts = []
        for context in [self.ctx.source, self.ctx.target]:
            for table in context.tables:
                parts.append(
                    self._render("reject_update.sql.j2", table_name=table.name)
                )
        return "\n\n".join(parts)

    def _build_guard_hierarchy(self) -> GuardHierarchy:
        """Build (and cache) the specialization hierarchy from universal schema + target table guards."""
        if self._hierarchy is not None:
            return self._hierarchy
        self._hierarchy = build_guard_hierarchy(
            target_tables=self.ctx.target.tables,
            universal_schema=self._universal_schema,
            source_primary_keys=self.ctx.source.primary_keys,
        )
        return self._hierarchy

    def _extract_table_guard_attrs(self, table: Table) -> list[str]:
        """Extract guard attributes from a target table's select clause."""
        return extract_table_guard_attrs(table)

    def _inter_table_inc(self) -> str:
        return inter_table_inc(
            self.ctx.source,
            self.ctx.target,
            self._render,
            self.schema,
            comments=self.comments,
        )

    def _constraints(self) -> str:
        """Generate all constraint enforcement (MVDs, FDs/CFDs, INCs) for both contexts."""
        return constraints(
            self.ctx.source,
            self.ctx.target,
            self._build_guard_hierarchy(),
            self._render,
        )

    def _tracking(self) -> str:
        """Generate insert/delete tracking infrastructure for both contexts.

        For each table in each context, produces a tracking table (shadow
        clone), a capture function (guarded by loop detection), and a
        trigger that fires AFTER INSERT or AFTER DELETE on the base table.
        """
        parts = []
        for context in [self.ctx.source, self.ctx.target]:
            direction = context.direction
            # Source checks loop_start = -1, target checks loop_start = 1
            loop_check = (
                SOURCE_LOOP_CHECK
                if direction is Direction.SOURCE
                else TARGET_LOOP_CHECK
            )
            for table in context.tables:
                for suffix, event, row_prefix, return_val in [
                    ("INSERT", "AFTER INSERT", "NEW", "NEW"),
                    ("DELETE", "AFTER DELETE", "OLD", "OLD"),
                ]:
                    row_values = ", ".join(
                        f"{row_prefix}.{a}" for a in table.attributes
                    )
                    parts.append(
                        self._render(
                            "tracking_table.sql.j2",
                            table_name=table.name,
                            suffix=suffix,
                        )
                    )
                    parts.append(
                        self._render(
                            "capture_function.sql.j2",
                            direction=direction,
                            table_name=table.name,
                            suffix=suffix,
                            loop_check=loop_check,
                            row_values=row_values,
                            return_value=return_val,
                        )
                    )
                    parts.append(
                        self._render(
                            "capture_trigger.sql.j2",
                            direction=direction,
                            table_name=table.name,
                            suffix=suffix,
                            event=event,
                        )
                    )
        return "\n\n".join(parts)

    def _join(self) -> str:
        """Generate join staging layer for both contexts.

        For each table, produces a JOIN staging table, a function that
        natural-joins all tracked changes into universal tuples (writing
        to the loop table for cycle detection), and a trigger that fires
        when rows land in the tracking table.
        """
        parts = []
        universal_columns = self._universal_columns()
        universal_col_names = self._universal_col_names()

        for context in [self.ctx.source, self.ctx.target]:
            direction = context.direction
            # Source inserts +1 to loop, target inserts -1
            loop_value = (
                SOURCE_LOOP_VALUE
                if direction is Direction.SOURCE
                else TARGET_LOOP_VALUE
            )

            ordered = context.ordered_tables
            all_tables_info = [{"name": t.name, "attrs": t.attributes} for t in ordered]

            for table in ordered:
                other_tables = [t.name for t in ordered if t.name != table.name]

                for suffix in ["INSERT", "DELETE"]:
                    # JOIN staging table (empty clone of base table)
                    parts.append(
                        self._render(
                            "tracking_table.sql.j2",
                            table_name=table.name,
                            suffix=f"{suffix}_JOIN",
                        )
                    )
                    # JOIN function
                    parts.append(
                        self._render(
                            "join_function.sql.j2",
                            direction=direction,
                            table_name=table.name,
                            suffix=suffix,
                            universal_columns=universal_columns,
                            universal_col_names=universal_col_names,
                            other_tables=other_tables,
                            all_tables=all_tables_info,
                            loop_value=loop_value,
                        )
                    )
                    # JOIN trigger (fires on INSERT into _TABLE_INSERT/DELETE)
                    parts.append(
                        self._render(
                            "join_trigger.sql.j2",
                            direction=direction,
                            table_name=table.name,
                            suffix=suffix,
                        )
                    )
        return "\n\n".join(parts)

    @staticmethod
    def _cleanup_names(table_names: list[str], suffix: str) -> list[str]:
        """Return tracking and join staging table names to TRUNCATE after mapping."""
        result = []
        for name in table_names:
            result.extend([f"{name}_{suffix}", f"{name}_{suffix}_JOIN"])
        return result

    def _mapping_triggers(
        self, fn_name: str, table_names: list[str], suffix: str
    ) -> list[str]:
        """Render triggers that wire each table's JOIN staging table to a mapping function."""
        return [
            self._render(
                "mapping_trigger.sql.j2",
                fn_name=fn_name,
                table_name=name,
                suffix=suffix,
            )
            for name in table_names
        ]

    def _mapping(self) -> str:
        """Generate the four bidirectional mapping functions and their triggers.

        Produces SOURCE_INSERT_FN, TARGET_INSERT_FN, SOURCE_DELETE_FN,
        and TARGET_DELETE_FN. Each function reads from join staging tables,
        applies the appropriate mapping (project universal tuples into the
        opposite context's tables), and cleans up tracking state. Insert
        mappings use containment pruning and null-pattern filtering; the
        source delete mapping sweeps each target table for orphans, and the
        target delete mapping uses full-tuple independence checks.
        """
        parts = []
        source = self.ctx.source
        target = self.ctx.target
        universal_columns = self._universal_columns()
        universal_col_names = self._universal_col_names()

        ordered_source = source.ordered_tables
        ordered_target = target.ordered_tables
        src_table_names = [t.name for t in ordered_source]
        tgt_table_names = [t.name for t in ordered_target]

        src_tables_info = [
            {
                "name": t.name,
                "attrs": t.attributes,
                "pk": source.primary_keys.get(t.name, []),
            }
            for t in ordered_source
        ]
        tgt_tables_info = [
            {
                "name": t.name,
                "attrs": t.attributes,
                "pk": target.primary_keys.get(t.name, []),
                "guard_check": " AND ".join(
                    f"{a} IS NOT NULL" for a in extract_table_guard_attrs(t)
                ),
            }
            for t in ordered_target
        ]

        hierarchy = self._build_guard_hierarchy()

        # Cleanup table names for each direction + suffix
        src_cleanup = self._cleanup_names(src_table_names, "INSERT")
        tgt_cleanup = self._cleanup_names(tgt_table_names, "INSERT")
        src_del_cleanup = self._cleanup_names(src_table_names, "DELETE")
        tgt_del_cleanup = self._cleanup_names(tgt_table_names, "DELETE")

        # Per-table WHERE: source PK columns + each target table's PK columns
        src_pk_cols = hierarchy.source_pk
        for info in tgt_tables_info:
            where_cols = list(src_pk_cols)
            for pk_col in info["pk"]:
                if pk_col not in where_cols:
                    where_cols.append(pk_col)
            info["where_not_null"] = " AND ".join(
                f"{a} IS NOT NULL" for a in where_cols
            )
        tgt_insert_where = build_null_pattern_where(hierarchy)

        # --- SOURCE_INSERT_FN ---
        parts.append(
            self._render(
                "insert_mapping.sql.j2",
                fn_name="SOURCE_INSERT_FN",
                suffix="INSERT",
                source_tables=src_table_names,
                target_tables=tgt_tables_info,
                where_not_null="",
                cleanup_tables=src_cleanup,
                use_temp_join=False,
                universal_columns=universal_columns,
                universal_col_names=universal_col_names,
                loop_value=None,
            )
        )
        parts.extend(
            self._mapping_triggers("SOURCE_INSERT_FN", src_table_names, "INSERT")
        )

        # --- TARGET_INSERT_FN ---
        prune_rules = build_containment_pruning(hierarchy)
        parts.append(
            self._render(
                "insert_mapping.sql.j2",
                fn_name="TARGET_INSERT_FN",
                suffix="INSERT",
                source_tables=tgt_table_names,
                target_tables=src_tables_info,
                where_not_null=tgt_insert_where,
                cleanup_tables=tgt_cleanup,
                use_temp_join=True,
                universal_columns=universal_columns,
                universal_col_names=universal_col_names,
                loop_value=TARGET_LOOP_VALUE,
                prune_rules=prune_rules,
            )
        )
        parts.extend(
            self._mapping_triggers("TARGET_INSERT_FN", tgt_table_names, "INSERT")
        )

        # --- SOURCE_DELETE_FN ---
        sweeps = self._build_source_delete_sweeps(source, target)
        parts.append(
            self._render(
                "delete_mapping.sql.j2",
                fn_name="SOURCE_DELETE_FN",
                source_tables=src_table_names,
                sweeps=sweeps,
                sweep_source=ordered_source[0].name,
                cleanup_tables=src_del_cleanup,
                use_temp_join=False,
                universal_columns=universal_columns,
                universal_col_names=universal_col_names,
                where_not_null="",
                use_abs=False,
                suffix="DELETE",
            )
        )
        parts.extend(
            self._mapping_triggers("SOURCE_DELETE_FN", src_table_names, "DELETE")
        )

        # --- TARGET_DELETE_FN ---
        tgt_delete_checks = self._build_target_delete_checks(source)
        parts.append(
            self._render(
                "delete_mapping.sql.j2",
                fn_name="TARGET_DELETE_FN",
                source_tables=tgt_table_names,
                independence_checks=tgt_delete_checks,
                full_independence_check=None,
                cleanup_tables=tgt_del_cleanup,
                use_temp_join=True,
                universal_columns=universal_columns,
                universal_col_names=universal_col_names,
                where_not_null=tgt_insert_where,
                use_abs=True,
                suffix="DELETE",
            )
        )
        parts.extend(
            self._mapping_triggers("TARGET_DELETE_FN", tgt_table_names, "DELETE")
        )

        return "\n\n".join(parts)

    def _verification(self) -> str:
        """Generate the check_sync() instance-level sync probe.

        Compares the source table against the NATURAL LEFT OUTER JOIN
        reconstruction of the target tables via two EXCEPTs (set operations
        treat NULLs as equal, so partially-NULL URA tuples diff correctly).
        Emitted after the base tables because SQL-language function bodies
        are validated at CREATE time.
        """
        return self._render(
            "check_sync.sql.j2",
            source_table=self.ctx.source.ordered_tables[0].name,
            target_tables=[t.name for t in self.ctx.target.ordered_tables],
            universal_columns=self._universal_columns(),
            universal_col_names=self._universal_col_names(),
        )

    def _build_source_delete_sweeps(
        self, source: Context, target: Context
    ) -> list[dict]:
        """Build per-target orphan sweeps for the source->target DELETE mapping.

        A target row survives a source DELETE iff some remaining source row
        still projects onto it: NULL-safe equality on every target attribute,
        with the target's guard attributes non-NULL on the witness. Sweeping
        every target table this way is order- and batch-independent, and it
        never removes a row another source key still derives (the previous
        NEW-keyed cascade did — see "DELETE independence generalization" in
        docs/notes/open-problems.md).

        Sweeps are emitted children-before-parents: ``ordered_target`` is
        root-first (the order the JOIN reconstruction needs), so the FK-safe
        DELETE order is its reverse.
        """
        src_table = source.ordered_tables[0]
        src_attrs = set(src_table.attributes)

        sweeps = []
        for t in reversed(target.ordered_tables):
            missing = [a for a in t.attributes if a not in src_attrs]
            if missing:
                raise UnsupportedError(
                    f"Target table {t.name} has attributes {missing} that the "
                    f"source table {src_table.name} does not carry; the DELETE "
                    "orphan sweep cannot build a witness query."
                )
            conditions = [f"s.{a} IS NOT DISTINCT FROM t.{a}" for a in t.attributes]
            conditions += [f"s.{g} IS NOT NULL" for g in extract_table_guard_attrs(t)]
            sweeps.append(
                {"table": t.name, "witness_condition": " AND ".join(conditions)}
            )
        return sweeps

    def _build_target_delete_checks(self, source: Context) -> list[dict]:
        """Build independence checks for target->source DELETE mapping.

        Joins SOURCE base tables (not target) to check whether removing
        a universal tuple leaves other source tuples that still require
        the same data.
        """
        ordered_source = source.ordered_tables
        src_names = [t.name for t in ordered_source]
        join_source = "SELECT * FROM " + " NATURAL LEFT OUTER JOIN ".join(
            f"{self.schema}._{n}" for n in src_names
        )
        join_cols = ", ".join(f"r1.{a}" for a in self._universal_col_names())

        nullable_set = set(self._build_guard_hierarchy().nullable_cols)

        def _eq(a: str) -> str:
            if a in nullable_set:
                return f"r1.{a} IS NOT DISTINCT FROM temp_table_join.{a}"
            return f"r1.{a} = temp_table_join.{a}"

        if len(ordered_source) == 1:
            src = ordered_source[0]
            src_pk = source.primary_keys.get(src.name, [])
            join_cond = " AND ".join(_eq(a) for a in src.attributes)
            return [
                {
                    "main_table": src.name,
                    "pk": src_pk,
                    "join_source": join_source,
                    "join_cols": join_cols,
                    "join_condition": join_cond,
                    "dependent_deletes": [],
                }
            ]

        # Multi-source: main table always deleted, dependent tables conditionally
        main = ordered_source[0]
        main_pk = source.primary_keys.get(main.name, [])
        checks = []
        for dep in ordered_source[1:]:
            dep_pk = source.primary_keys.get(dep.name, [])
            join_cond = " AND ".join(_eq(a) for a in dep.attributes)
            checks.append(
                {
                    "main_table": main.name,
                    "pk": main_pk,
                    "join_source": join_source,
                    "join_cols": join_cols,
                    "join_condition": join_cond,
                    "dependent_deletes": [{"name": dep.name, "pk": dep_pk}],
                }
            )
        return checks
