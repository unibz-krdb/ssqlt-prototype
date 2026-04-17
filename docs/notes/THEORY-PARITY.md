# Theory–Practice Parity

This document records how closely the SSTC implementation in `src/sstc/` matches the theoretical design in `docs/notes/`. It complements `open-problems.md` by giving an at-a-glance parity table and by flagging gaps that are not yet catalogued there.

Last reviewed: 2026-04-17 (Tier 2 shipped).

## Summary

The implementation is a faithful **subset** of the theory. Every layer and constraint type the code emits matches the spec closely; the divergences are almost entirely gaps of *scope*, not correctness against the current scope. The supported envelope is shaped by the PERSON URA example — single-table source, CFD-rich decomposition, insert + delete round-trip — which both corpora are organised around.

## Architectural parity

| Theoretical layer | Reference | Code | Status |
|---|---|---|---|
| Base tables + source constraints | `example/1_source.sql`, `example/2_target.sql` | `Generator._base_tables`, `_inter_table_inc`, `_constraints` | Full |
| Update tracking (`_INSERT`, `_DELETE`) | `example/3_updates.sql` | `Generator._tracking` | Full |
| Join staging (`_INSERT_JOIN`, `_DELETE_JOIN`) + `_LOOP` | `architecture/layers.md`, `architecture/timing-and-ordering.md` | `Generator._join`, `templates/join_function.sql.j2` | Full |
| Mapping functions (insert / delete) | `example/4_functions.sql`, `sql-generation/mapping-functions.md` | `Generator._mapping`, `templates/insert_mapping.sql.j2`, `templates/delete_mapping.sql.j2` | Full |
| Trigger wiring | `example/5_triggers.sql` | Embedded in each template | Full |
| Test inserts | `example/6_update.sql` | — | Not a compiler artifact |

The `_LOOP` dual-role mechanism from `architecture/timing-and-ordering.md` (sign encodes direction, count encodes wait) is faithfully realised in `templates/capture_function.sql.j2` and `templates/join_function.sql.j2`.

## Constraint parity

| Constraint | Theory | Code | Status |
|---|---|---|---|
| PK | native `PRIMARY KEY` | `templates/create_table.sql.j2` via `Context.primary_keys` | Full |
| FD (unguarded) | `constraints/functional-dependencies.md` | `constraints.fd_sql` → `fd_check.sql.j2` | Full |
| CFD (guarded FD) | `constraints/conditional-join-dependencies.md`, `constraints/guard-dependencies.md` | `constraints.fd_sql` + `guard.build_cfd_where_branches` → `cfd_check.sql.j2` | Full |
| MVD (shared-LHS) | `constraints/multivalued-dependencies.md` | `constraints.mvd_sql` → `mvd_check.sql.j2`, `mvd_grounding.sql.j2` | Full |
| MVD (non-shared-LHS) | idem | `constraints.py:108` `UnsupportedError` | Rejected |
| INC⊆ intra-table, single column | `constraints/inclusion-dependencies.md` | `constraints.inc_sql` → `inc_check.sql.j2` | Full |
| INC⊆ intra-table, multi-column | idem | `constraints.py:169` `UnsupportedError` | Rejected |
| INC⊆ / INC= inter-table (refs = PK) | FK | `constraints.inter_table_inc` → `emit_fk` | Full (narrow) |
| INC⊆ / INC= inter-table (refs ≠ PK, single column) | custom trigger per theory | `constraints.emit_inc_trigger` → `inc_inter_check.sql.j2` | Full |
| INC⊆ / INC= inter-table (multi-column, refs ≠ PK) | custom trigger per theory | `constraints.py:123` `UnsupportedError` | Rejected |
| Guard hierarchy | `constraints/guard-dependencies.md` | `guard.GuardHierarchy`, `guard.build_guard_hierarchy` | Full |
| Containment pruning | `sql-generation/mapping-functions.md` | `guard.build_containment_pruning` | Full |
| Null-pattern WHERE | idem | `guard.build_null_pattern_where` | Full |
| CJD (conditional join dependency) | `constraints/conditional-join-dependencies.md` | — | Absent |

## Operational parity

| Capability | Theory | Code |
|---|---|---|
| INSERT round-trip | fully specified in `sql-generation/insert-chain.md` | implemented |
| DELETE round-trip with independence check | fully specified in `sql-generation/delete-chain.md` | implemented |
| UPDATE | `sql-generation/update-chain.md` recommends Option C (explicit rejection) | rejected via per-table `BEFORE UPDATE` trigger (`templates/reject_update.sql.j2`) — Option C implemented |
| Multi-table source schemas | implicit in general theory | `generator.py:73` hard-rejects `len(source.tables) != 1` |
| Automatic NATURAL JOIN ordering | acknowledged open problem | none; joins follow RA declaration order |
| Connected-component partitioning for join layer | acknowledged open problem | none; single full join |
| `_LOOP` pre-seeding for multi-table DELETE | documented client contract | no helper emitted |
| `universal_mapping` RA expression | central in theory — defines the universal-to-context mapping | consumed for join ordering and projection via `universal_mapping.extract_join_order`; `Context.from_file` validates the mapping tables match declared relations. Deeper join-tree consumption (disconnected components, multi-source, FK-graph-derived ordering) is Tier 3 |

## Terminology that does map to code

These terms from the theory are real abstractions in the codebase, not just documentation vocabulary:

- **Guard hierarchy** → `guard.GuardLevel`, `guard.GuardHierarchy`, `guard.build_guard_hierarchy`
- **Containment pruning** → `guard.build_containment_pruning`, consumed by `insert_mapping.sql.j2`
- **Null pattern** → `guard.build_null_pattern_where`
- **CFD where branches** → `guard.build_cfd_where_branches`
- **Universal mapping (name only)** → `Context.UNIVERSAL_MAPPING_NAME`, `Context.universal_mapping`
- **Render callback decoupling** → `RenderFn` parameter on the public `constraints.*` functions

## Gaps not yet in `open-problems.md`

One hole sits outside the canonical open-problems catalogue and deserves an entry there:

1. **Concurrency / `_LOOP` races.** `architecture/concurrency.md` analyses the failure modes under concurrent writers, but `open-problems.md` does not list concurrency at all and no mitigation exists in the generated SQL. Two concurrent transactions can corrupt each other's `_LOOP` state, breaking both the direction sign and the wait count.

One further item is documented in prose but not yet in `open-problems.md` as a formal entry:

2. **Multi-source rejection.** Hard-coded in `generator.py:73`; the theory does not obviously restrict source schemas to a single table, so the restriction's rationale should be made explicit.

### Closed in Tier 1 (2026-04-17)

- **UPDATE silent no-op** — resolved: per-table `BEFORE UPDATE` trigger emits `RAISE EXCEPTION`. See `templates/reject_update.sql.j2` and the UPDATE row of the operational parity table.
- **Inter-table INC (refs ≠ PK) silent skip** — resolved for single-column: `AFTER INSERT DEFERRABLE INITIALLY DEFERRED` constraint trigger (`templates/inc_inter_check.sql.j2`). Multi-column case remains `Rejected` (Tier 3).
- **`universal_mapping` parsed but unread** — tracked as a formal entry in `open-problems.md`; consumption followed in Tier 2.

### Closed in Tier 2 (2026-04-17)

- **`universal_mapping` consumed for join ordering** — `src/sstc/universal_mapping.py` extracts projection attributes and a left-to-right base-table sequence from the `AssignNode`. `Context.universal_mapping_join_order` surfaces that sequence; `Generator._join`, `_mapping`, and `_build_*_delete_checks` iterate in mapping order instead of declaration order. `Context.from_file` raises when the mapping tables diverge from the declared relations. For the two reference examples the compiled SQL is byte-unchanged; the behaviour is now guaranteed by construction.

## How to use this document

- Before adding a new constraint type, check the constraint-parity table: rows marked **Absent** or **Rejected** point at the relevant theory doc as a starting point.
- Before claiming a capability in a paper, demo, or API, check the operational-parity table — especially the UPDATE and multi-source rows.
- When a compilation produces less SQL than expected (e.g. a missing FK), the silent-skip rows explain why.
- Update this file whenever `open-problems.md` gains or closes an item, or when a new `UnsupportedError` or silent-skip branch is introduced.
