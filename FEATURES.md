# Features

What the SSTC prototype can do today. This is a capability reference; for how
to *run* it see [`README.md`](README.md), for how features map to the source
paper see [`THEORY-PARITY.md`](THEORY-PARITY.md), and for
known gaps see [`docs/notes/open-problems.md`](docs/notes/open-problems.md).

> **Supported envelope.** SSTC compiles the **URA-projection fragment** of the
> transducer theory: both contexts are projections (optionally guarded by
> `defined(...)`) of one universal relation. Every feature below is solid
> within the shape the two bundled examples share: a **single source table**,
> single-column inclusion dependencies, shared-LHS multivalued dependencies,
> and `INSERT`/`DELETE` propagation. The paper's general mappings, CARM/OIDs,
> and value-based horizontal decomposition are not expressible — including the
> paper's own worked example. Outside the envelope the compiler either raises
> `UnsupportedError` or hits a catalogued open problem — see the end of this
> document.

## Input

- **CLI**: `sstc <universal.json> <source.txt> <target.txt> [-o out.sql] [-c/--comments]`
  (`src/sstc/__main__.py`), emitting a single PostgreSQL script. `--comments`
  annotates the output with section banners, per-object headers, and inline
  notes (purely additive; default output is unchanged).
- **Universal schema** from a JSON array of `{name, data_type, is_nullable}`.
- **Source and target contexts** written in relational algebra, parsed with
  **RAPT2** (`Context.from_file`).
- **Operators understood**: `\project_{}`, `\select_{defined(...)}`,
  `\natural_join`, and the constraint declarations `pk_{}`, `fd_{}`, `mvd_{}`,
  `inc=_{}` (equality) and `inc⊆_{}` (subset).
- **`UniversalMapping`** — the reserved per-context relation. Its projection and
  left-to-right base-table sequence are extracted (`universal_mapping.py`) and
  drive join and mapping order; `Context.from_file` rejects an input whose
  mapping tables diverge from its declared relations.

## Compilation pipeline

`Generator.compile()` emits nine sections in dependency order:

| # | Section | Method | Output |
|---|---------|--------|--------|
| 1 | Schema preamble | `_preamble` | `DROP`/`CREATE SCHEMA`; the `_loop` cycle-detection table; the `seed_loop(N)` client helper |
| 2 | Base tables | `_base_tables` | `CREATE TABLE` per source/target table with PKs + nullability |
| 3 | Update rejection | `_reject_updates` | one `BEFORE UPDATE` raise-trigger per base table |
| 4 | Inter-table INC | `_inter_table_inc` | native FK, or deferred constraint trigger when an FK is impossible |
| 5 | Constraint enforcement | `_constraints` | FD/CFD, MVD check + grounding, intra-table INC functions |
| 6 | Change tracking | `_tracking` | `_INSERT`/`_DELETE` shadow tables + capture triggers |
| 7 | Join staging | `_join` | `_INSERT_JOIN`/`_DELETE_JOIN` tables + join functions (write `_loop`) |
| 8 | Mapping | `_mapping` | the four bidirectional mapping functions + triggers |
| 9 | Sync verification | `_verification` | `check_sync()` — symmetric difference between source and target reconstruction |

## Constraint generation

| Constraint | Realisation | Source |
|---|---|---|
| **Primary key** | native `PRIMARY KEY` | `create_table.sql.j2` |
| **Foreign key** (inter-table INC, refs = PK) | native `ADD FOREIGN KEY` | `constraints.emit_fk` |
| **Inter-table INC** (refs ≠ PK, single column) | `AFTER INSERT DEFERRABLE INITIALLY DEFERRED` trigger | `constraints.emit_inc_trigger` |
| **Intra-table INC** (single column) | `BEFORE INSERT` trigger; handles NULL and self-reference | `constraints.inc_sql` |
| **FD** (unguarded) | `BEFORE INSERT` cross-join violation check | `constraints.fd_sql` |
| **CFD** (guarded FD) | `BEFORE INSERT` with exhaustive OR-branch WHERE from the guard hierarchy | `constraints.fd_sql` + `guard.build_cfd_where_branches` |
| **MVD** (shared-LHS) | `BEFORE INSERT` check **and** `AFTER INSERT` grounding of missing complementary tuples | `constraints.mvd_sql` |

Multi-column INCs, non-shared-LHS MVDs, non-chain guard hierarchies, and CFD
determinants spanning guard levels are explicitly rejected with
`UnsupportedError` rather than mis-compiled.

## Guard hierarchy & NULL handling

For Universal-Relation-Assumption schemas where source rows are partially NULL
(`guard.py`):

- **`build_guard_hierarchy`** — partitions universal columns into specialization
  levels from the `defined(...)` predicates on target tables. Guard sets must
  form a chain by inclusion; incomparable sets (independent nullable groups)
  raise `UnsupportedError` instead of silently linearizing.
- **`build_cfd_where_branches`** — exhaustive null-pattern branches for CFD checks.
- **`build_containment_pruning`** — drops dominated (more-NULL) tuples in the
  target→source insert mapping so they don't violate the source PK.
- **`build_null_pattern_where`** — the WHERE filter that keeps only coherent
  null-patterns during reconstruction.

This is what lets a single partially-NULL source row (e.g. person vs. employee
vs. employee-with-department) land in exactly the right subset of target tables.

## Bidirectional propagation

A plain `INSERT` or `DELETE` on either side reconstructs the universal tuple and
applies the equivalent change to the other side — entirely in-database via
triggers, no external runtime. The four mapping functions are `SOURCE_INSERT_FN`,
`TARGET_INSERT_FN`, `SOURCE_DELETE_FN`, `TARGET_DELETE_FN`.

| Operation | Status | Loop protocol |
|---|---|---|
| **INSERT source → target** | works, integration-tested | self-firing |
| **INSERT target → source** | works, integration-tested | client calls `seed_loop(N)` first (N target inserts) |
| **DELETE source → target** | works, integration-tested | self-firing |
| **DELETE target → source** | works, integration-tested | client calls `seed_loop(N)` first (N target deletes) |
| **UPDATE** | rejected by design | use `DELETE` + `INSERT` |

Source→target DELETEs propagate via a per-target **orphan sweep**: a target
row is deleted iff no remaining source row still projects onto it (NULL-safe,
guard-aware, children before parents), so rows shared with another source key
— e.g. a department/manager pair two employees reference — survive.

## Sync verification

The compiled script ends with `check_sync()`: `SELECT * FROM
transducer.check_sync()` returns the symmetric difference between the source
table and the NATURAL-LEFT-OUTER-JOIN reconstruction of the target tables,
each row labelled `missing-in-target` or `missing-in-source`. An empty result
means both databases currently encode the same instance. It is an
**instance-level probe** — a necessary condition for losslessness, not a
schema-level proof. Integration tests use it after every propagation pattern,
including a seeded randomized insert/delete round-trip.

**Loop prevention** uses the `_loop` table: the sign of a row encodes the
propagation direction and the row count drives a wait so a one-directional
propagation does not re-trigger back across the bridge.

## Quality & tooling

- **Architecture**: `generator.py` (orchestrator) builds on both `constraints.py`
  and `guard.py`, and `constraints.py` itself builds on `guard.py`; Jinja2
  templates; constraint functions take a `RenderFn` callback to decouple logic
  from rendering.
- **Golden-file tests** — byte-exact full-compile output for both examples
  (`test/golden/`), regenerable with `--update-golden`.
- **Integration tests** — compile, install on a throwaway PostgreSQL container
  (`testcontainers`), and assert real propagation and constraint rejection,
  parametrized over both examples; covers INSERT and DELETE in both directions.
  Skipped automatically when Docker is unavailable.
- **Unit tests** — context parsing, every generator stage, the guard functions,
  and `UniversalMapping` extraction.
- **Lint/format** via `ruff`; `uv`-managed; Python ≥ 3.13.

## Out of scope (today)

Tracked in [`docs/notes/open-problems.md`](docs/notes/open-problems.md) and the
operational-parity table of
[`THEORY-PARITY.md`](THEORY-PARITY.md):

- Multiple source tables; automatic FK-graph join ordering; disconnected-component
  partitioning.
- Multi-column inclusion dependencies; non-shared-LHS MVDs; non-chain guard
  hierarchies (independent nullable groups); conditional join dependencies (CJD).
- `UPDATE` propagation.
- Concurrent writers — the contract is **one writer at a time**: `_loop` is a
  shared ledger and the trigger-based constraint checks race under snapshot
  isolation. The count-based `_loop` wait also remains: `seed_loop(N)` hides
  the arithmetic, but clients still supply N for target-side transactions.
- Deriving the lossless decomposition itself, and verifying losslessness at
  the schema level — SSTC executes a decomposition you supply; `check_sync()`
  verifies the *current instances* agree, which is necessary but not
  sufficient.
