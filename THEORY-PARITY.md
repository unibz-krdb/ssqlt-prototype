# Theory–Practice Parity

This document records how closely the SSTC implementation in `src/sstc/` matches the theoretical design in `docs/notes/`. It complements `docs/notes/open-problems.md` by giving an at-a-glance parity table and by flagging gaps that are not yet catalogued there.

Last reviewed: 2026-06-11 (Tier A correctness fixes + verification pass: DELETE orphan sweep, non-chain guard rejection, `seed_loop` helper, concurrency catalogued, `check_sync()` emitted, URA-fragment positioning stated; Tier 2 shipped 2026-04-17).

## Summary

The implementation is a faithful **subset** of the theory. Every layer and constraint type the code emits matches the spec closely; the divergences are almost entirely gaps of *scope*, not correctness against the current scope. The supported envelope is shaped by the PERSON URA example — single-table source, CFD-rich decomposition, insert + delete round-trip — which both corpora are organised around.

That envelope is, precisely, the **URA-projection fragment** of the paper: both contexts must be `\project`/`\select_{defined(...)}` views of one universal relation. The paper's general framework — arbitrary per-predicate RA mappings, CARM/OID generation (which requires renaming ϱ and product ×), domain constraints, and value-based horizontal decomposition — is not expressible in the input language. In particular, **the paper's own worked example (Figures 4–6) cannot be compiled**; the bundled PERSON example is its OID-free analogue. Losslessness of the supplied decomposition is trusted at the schema level; the emitted `check_sync()` (section 9) verifies instance-level sync only.

## Architectural parity

| Theoretical layer | Reference | Code | Status |
|---|---|---|---|
| Base tables + source constraints | `docs/notes/example/1_source.sql`, `docs/notes/example/2_target.sql` | `Generator._base_tables`, `_inter_table_inc`, `_constraints` | Full |
| Update tracking (`_INSERT`, `_DELETE`) | `docs/notes/example/3_updates.sql` | `Generator._tracking` | Full |
| Join staging (`_INSERT_JOIN`, `_DELETE_JOIN`) + `_LOOP` | `docs/notes/architecture/layers.md`, `docs/notes/architecture/timing-and-ordering.md` | `Generator._join`, `templates/join_function.sql.j2` | Full |
| Mapping functions (insert / delete) | `docs/notes/example/4_functions.sql`, `docs/notes/sql-generation/mapping-functions.md` | `Generator._mapping`, `templates/insert_mapping.sql.j2`, `templates/delete_mapping.sql.j2` | Full |
| Trigger wiring | `docs/notes/example/5_triggers.sql` | Embedded in each template | Full |
| Test inserts | `docs/notes/example/6_update.sql` | — | Not a compiler artifact |

The `_LOOP` dual-role mechanism from `docs/notes/architecture/timing-and-ordering.md` (sign encodes direction, count encodes wait) is faithfully realised across the trigger chain: `templates/capture_function.sql.j2` performs the sign/direction check, `templates/join_function.sql.j2` writes the per-trigger markers, and the count/wait gate (`ABS(loop_start) = row_count`) lives in `templates/insert_mapping.sql.j2` and `templates/delete_mapping.sql.j2`.

## Constraint parity

| Constraint | Theory | Code | Status |
|---|---|---|---|
| PK | native `PRIMARY KEY` | `templates/create_table.sql.j2` via `Context.primary_keys` | Full |
| FD (unguarded) | `docs/notes/constraints/functional-dependencies.md` | `constraints.fd_sql` → `fd_check.sql.j2` | Full |
| CFD (guarded FD) | `docs/notes/constraints/functional-dependencies.md`, `docs/notes/constraints/guard-dependencies.md` | `constraints.fd_sql` + `guard.build_cfd_where_branches` → `cfd_check.sql.j2` | Full |
| MVD (shared-LHS) | `docs/notes/constraints/multivalued-dependencies.md` | `constraints.mvd_sql` → `mvd_check.sql.j2`, `mvd_grounding.sql.j2` | Full |
| MVD (non-shared-LHS) | idem | `constraints.mvd_sql` raises `UnsupportedError` | Rejected |
| INC⊆ intra-table, single column | `docs/notes/open-problems.md` "Inclusion dependencies" | `constraints.inc_sql` → `inc_check.sql.j2` | Full |
| INC⊆ intra-table, multi-column | idem | `constraints.inc_sql` raises `UnsupportedError` | Rejected |
| INC⊆ / INC= inter-table (refs = PK) | FK | `constraints.inter_table_inc` → `emit_fk` | Full (narrow) |
| INC⊆ / INC= inter-table (refs ≠ PK, single column) | custom trigger per theory | `constraints.emit_inc_trigger` → `inc_inter_check.sql.j2` | Full |
| INC⊆ / INC= inter-table (multi-column, refs ≠ PK) | custom trigger per theory | `constraints.inter_table_inc` raises `UnsupportedError` | Rejected |
| Guard hierarchy (chain) | `docs/notes/constraints/guard-dependencies.md` | `guard.GuardHierarchy`, `guard.build_guard_hierarchy` | Full |
| Guard hierarchy (non-chain lattice) | idem (independent nullable groups) | `guard.build_guard_hierarchy` raises `UnsupportedError` | Rejected |
| Containment pruning | `docs/notes/sql-generation/mapping-functions.md` | `guard.build_containment_pruning` | Full |
| Null-pattern WHERE | idem | `guard.build_null_pattern_where` | Full |
| CJD (conditional join dependency) | `docs/notes/constraints/conditional-join-dependencies.md` | — | Absent |

## Operational parity

| Capability | Theory | Code |
|---|---|---|
| INSERT round-trip | fully specified in `docs/notes/sql-generation/insert-chain.md` | implemented |
| DELETE round-trip with independence check | fully specified in `docs/notes/sql-generation/delete-chain.md` | implemented as a per-target orphan sweep (generalizes the spec's check; preserves rows shared across source keys) |
| UPDATE | `docs/notes/sql-generation/update-chain.md` recommends Option C (explicit rejection) | rejected via per-table `BEFORE UPDATE` trigger (`templates/reject_update.sql.j2`) — Option C implemented |
| Multi-table source schemas | implicit in general theory | `generator.py:73` hard-rejects `len(source.tables) != 1` |
| Automatic NATURAL JOIN ordering | acknowledged open problem | none; joins follow RA declaration order |
| Connected-component partitioning for join layer | acknowledged open problem | none; single full join |
| `_LOOP` pre-seeding for multi-table DELETE | documented client contract | `seed_loop(N)` helper emitted in the preamble; clients no longer hand-compute the seed |
| `universal_mapping` RA expression | central in theory — defines the universal-to-context mapping | consumed for join ordering and projection via `universal_mapping.extract_join_order`; `Context.from_file` validates the mapping tables match declared relations. Deeper join-tree consumption (disconnected components, multi-source, FK-graph-derived ordering) is Tier 3 |
| Losslessness guarantee | the core theorem — `(C_S ∪ M_{S→T}) ≡ (C_T ∪ M_{T→S})` | trusted at the schema level (no chase/equivalence check); `check_sync()` (section 9) verifies the *instances* currently agree — necessary, not sufficient |

## Terminology that does map to code

These terms from the theory are real abstractions in the codebase, not just documentation vocabulary:

- **Guard hierarchy** → `guard.GuardLevel`, `guard.GuardHierarchy`, `guard.build_guard_hierarchy`
- **Containment pruning** → `guard.build_containment_pruning`, consumed by `insert_mapping.sql.j2`
- **Null pattern** → `guard.build_null_pattern_where`
- **CFD where branches** → `guard.build_cfd_where_branches`
- **Universal mapping (name only)** → `Context.UNIVERSAL_MAPPING_NAME`, `Context.universal_mapping`
- **Render callback decoupling** → `RenderFn` parameter on the public `constraints.*` functions

## Gaps not yet in `docs/notes/open-problems.md`

One item is documented in prose but not yet in `docs/notes/open-problems.md` as a formal entry:

1. **Multi-source rejection.** Hard-coded in `Generator.compile()`; the theory does not obviously restrict source schemas to a single table, so the restriction's rationale should be made explicit.

The operating contract for writes is **one writer at a time** — concurrent write transactions corrupt `_loop` state and can jointly bypass the trigger-based constraint checks. This is now a formal catalogue entry ("Concurrent writers corrupt `_loop` and bypass trigger checks" in `docs/notes/open-problems.md`); README states the contract.

### Closed in the verification pass (2026-06-11)

- **Losslessness entirely unverified** — partially closed: the compiled script now ends with `check_sync()`, an instance-level probe (symmetric difference between source and target reconstruction). Schema-level verification (chase-based) remains open.
- **URA-fragment positioning unstated** — the audit found no document said the paper's own worked example is inexpressible; README, FEATURES, CLAUDE.md, and this file now state the fragment explicitly.

### Closed in Tier A (2026-06-11)

- **DELETE independence over-deletion** — resolved: `SOURCE_DELETE_FN` performs a per-target orphan sweep (a target row survives while any remaining source row still projects onto it), replacing the NEW-keyed cascade that removed rows shared across source keys. The strict-xfail test now passes; see `generator._build_source_delete_sweeps`.
- **Non-chain guard lattices silently mis-compiled** — resolved by rejection: `build_guard_hierarchy` validates the chain property; `build_cfd_where_branches` rejects determinants spanning level-groups. Lattice *support* remains open.
- **Concurrency uncatalogued** — the missing open-problems entry now exists; the single-writer contract is stated in README and FEATURES.
- **`_LOOP` pre-seed contract** — wrapped: the preamble emits `seed_loop(N)`; the `N+1` arithmetic is no longer client knowledge. Removing the count-wait mechanism entirely remains open.

### Closed in Tier 1 (2026-04-17)

- **UPDATE silent no-op** — resolved: per-table `BEFORE UPDATE` trigger emits `RAISE EXCEPTION`. See `templates/reject_update.sql.j2` and the UPDATE row of the operational parity table.
- **Inter-table INC (refs ≠ PK) silent skip** — resolved for single-column: `AFTER INSERT DEFERRABLE INITIALLY DEFERRED` constraint trigger (`templates/inc_inter_check.sql.j2`). Multi-column case remains `Rejected` (Tier 3).
- **`universal_mapping` parsed but unread** — tracked as a formal entry in `docs/notes/open-problems.md`; consumption followed in Tier 2.

### Closed in Tier 2 (2026-04-17)

- **`universal_mapping` consumed for join ordering** — `src/sstc/universal_mapping.py` extracts projection attributes and a left-to-right base-table sequence from the `AssignNode`. `Context.universal_mapping_join_order` surfaces that sequence; `Generator._join`, `_mapping`, and `_build_*_delete_checks` iterate in mapping order instead of declaration order. `Context.from_file` raises when the mapping tables diverge from the declared relations. For the two reference examples the compiled SQL is byte-unchanged; the behaviour is now guaranteed by construction.

## How to use this document

- Before adding a new constraint type, check the constraint-parity table: rows marked **Absent** or **Rejected** point at the relevant theory doc as a starting point.
- Before claiming a capability in a paper, demo, or API, check the operational-parity table — especially the UPDATE and multi-source rows.
- When a compilation produces less SQL than expected (e.g. a missing FK), the silent-skip rows explain why.
- Update this file whenever `docs/notes/open-problems.md` gains or closes an item, or when a new `UnsupportedError` or silent-skip branch is introduced.
