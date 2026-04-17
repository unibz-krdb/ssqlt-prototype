# Theory–Practice Parity

This document records how closely the SSTC implementation in `src/sstc/` matches the theoretical design in `docs/notes/`. It complements `open-problems.md` by giving an at-a-glance parity table and by flagging gaps that are not yet catalogued there.

Last reviewed: 2026-04-17.

## Summary

The implementation is a faithful **subset** of the theory. Every layer and constraint type the code emits matches the spec closely; the divergences are almost entirely gaps of *scope*, not correctness against the current scope. The supported envelope is shaped by the PERSON URA example — single-table source, CFD-rich decomposition, insert + delete round-trip — which both corpora are organised around.

## Architectural parity

| Theoretical layer | Reference | Code | Status |
|---|---|---|---|
| Base tables + source constraints | `example/1_source.sql`, `example/2_target.sql` | `Generator._base_tables`, `_foreign_keys`, `_constraints` | Full |
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
| INC⊆ / INC= inter-table (refs = PK) | FK | `constraints.foreign_keys` → `emit_fk` | Full (narrow) |
| INC⊆ / INC= inter-table (refs ≠ PK) | custom trigger per theory | `constraints.py:58` `emit_fk` returns `None` (silent skip) | Missing |
| Guard hierarchy | `constraints/guard-dependencies.md` | `guard.GuardHierarchy`, `guard.build_guard_hierarchy` | Full |
| Containment pruning | `sql-generation/mapping-functions.md` | `guard.build_containment_pruning` | Full |
| Null-pattern WHERE | idem | `guard.build_null_pattern_where` | Full |
| CJD (conditional join dependency) | `constraints/conditional-join-dependencies.md` | — | Absent |

## Operational parity

| Capability | Theory | Code |
|---|---|---|
| INSERT round-trip | fully specified in `sql-generation/insert-chain.md` | implemented |
| DELETE round-trip with independence check | fully specified in `sql-generation/delete-chain.md` | implemented |
| UPDATE | `sql-generation/update-chain.md` recommends Option C (explicit rejection) | silent no-op — neither implemented nor rejected |
| Multi-table source schemas | implicit in general theory | `generator.py:73` hard-rejects `len(source.tables) != 1` |
| Automatic NATURAL JOIN ordering | acknowledged open problem | none; joins follow RA declaration order |
| Connected-component partitioning for join layer | acknowledged open problem | none; single full join |
| `_LOOP` pre-seeding for multi-table DELETE | documented client contract | no helper emitted |
| `universal_mapping` RA expression | central in theory — defines the universal-to-context mapping | `Context.from_file` validates presence (`context.py:137`) but the relational expression is never inspected; downstream code reads `Table.attributes` directly |

## Terminology that does map to code

These terms from the theory are real abstractions in the codebase, not just documentation vocabulary:

- **Guard hierarchy** → `guard.GuardLevel`, `guard.GuardHierarchy`, `guard.build_guard_hierarchy`
- **Containment pruning** → `guard.build_containment_pruning`, consumed by `insert_mapping.sql.j2`
- **Null pattern** → `guard.build_null_pattern_where`
- **CFD where branches** → `guard.build_cfd_where_branches`
- **Universal mapping (name only)** → `Context.UNIVERSAL_MAPPING_NAME`, `Context.universal_mapping`
- **Render callback decoupling** → `RenderFn` parameter on the public `constraints.*` functions

## Gaps not yet in `open-problems.md`

Two holes sit outside the canonical open-problems catalogue and deserve entries there:

1. **Concurrency / `_LOOP` races.** `architecture/concurrency.md` analyses the failure modes under concurrent writers, but `open-problems.md` does not list concurrency at all and no mitigation exists in the generated SQL. Two concurrent transactions can corrupt each other's `_LOOP` state, breaking both the direction sign and the wait count.
2. **`universal_mapping` parsed but unread.** The reserved `UniversalMapping` AssignNode is required (`context.py:137` raises on absence) but its RA expression is never consumed by `Generator`. If the theory intends join structure or column mappings to be derived from it, that derivation is a missing component, not a dormant one. If it is deliberately unused, the requirement on the input file is misleading.

Two further items are documented in prose but not in `open-problems.md` as formal entries:

3. **Multi-source rejection.** Hard-coded in `generator.py:73`; the theory does not obviously restrict source schemas to a single table, so the restriction's rationale should be made explicit.
4. **UPDATE silent no-op.** `sql-generation/update-chain.md` recommends Option C (raise). The code does neither: no UPDATE triggers are installed, so an `UPDATE` on a base table silently bypasses propagation instead of failing loudly.

## How to use this document

- Before adding a new constraint type, check the constraint-parity table: rows marked **Absent** or **Rejected** point at the relevant theory doc as a starting point.
- Before claiming a capability in a paper, demo, or API, check the operational-parity table — especially the UPDATE and multi-source rows.
- When a compilation produces less SQL than expected (e.g. a missing FK), the silent-skip rows explain why.
- Update this file whenever `open-problems.md` gains or closes an item, or when a new `UnsupportedError` or silent-skip branch is introduced.
