# Features

What the SSTC prototype can do today. This is a capability reference; for how
to *run* it see [`README.md`](README.md), for how features map to the source
paper see [`docs/notes/THEORY-PARITY.md`](docs/notes/THEORY-PARITY.md), and for
known gaps see [`docs/notes/open-problems.md`](docs/notes/open-problems.md).

> **Supported envelope.** Every feature below is solid within the shape the two
> bundled examples share: a **single source table**, single-column inclusion
> dependencies, shared-LHS multivalued dependencies, and `INSERT`/`DELETE`
> propagation. Outside that envelope the compiler either raises
> `UnsupportedError` or hits a catalogued open problem — see the end of this
> document.

## Input

- **CLI**: `sstc <universal.json> <source.txt> <target.txt> [-o out.sql]`
  (`src/sstc/__main__.py`), emitting a single PostgreSQL script.
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

`Generator.compile()` emits eight sections in dependency order:

| # | Section | Method | Output |
|---|---------|--------|--------|
| 1 | Schema preamble | `_preamble` | `DROP`/`CREATE SCHEMA`; the `_loop` cycle-detection table |
| 2 | Base tables | `_base_tables` | `CREATE TABLE` per source/target table with PKs + nullability |
| 3 | Update rejection | `_reject_updates` | one `BEFORE UPDATE` raise-trigger per base table |
| 4 | Inter-table INC | `_inter_table_inc` | native FK, or deferred constraint trigger when an FK is impossible |
| 5 | Constraint enforcement | `_constraints` | FD/CFD, MVD check + grounding, intra-table INC functions |
| 6 | Change tracking | `_tracking` | `_INSERT`/`_DELETE` shadow tables + capture triggers |
| 7 | Join staging | `_join` | `_INSERT_JOIN`/`_DELETE_JOIN` tables + join functions (write `_loop`) |
| 8 | Mapping | `_mapping` | the four bidirectional mapping functions + triggers |

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

Multi-column INCs and non-shared-LHS MVDs are explicitly rejected with
`UnsupportedError` rather than mis-compiled.

## Guard hierarchy & NULL handling

For Universal-Relation-Assumption schemas where source rows are partially NULL
(`guard.py`):

- **`build_guard_hierarchy`** — partitions universal columns into specialization
  levels from the `defined(...)` predicates on target tables.
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
| **INSERT target → source** | works, integration-tested | client seeds `_loop` with `N+1` (N target inserts) |
| **DELETE source → target** | works, integration-tested | self-firing |
| **DELETE target → source** | works, integration-tested | client seeds `_loop` with `N+1` (N target deletes) |
| **UPDATE** | rejected by design | use `DELETE` + `INSERT` |

**Loop prevention** uses the `_loop` table: the sign of a row encodes the
propagation direction and the row count drives a wait so a one-directional
propagation does not re-trigger back across the bridge.

## Quality & tooling

- **Architecture**: `guard.py` (leaf) ← `constraints.py` ← `generator.py`
  orchestrator; Jinja2 templates; constraint functions take a `RenderFn`
  callback to decouple logic from rendering.
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
[`docs/notes/THEORY-PARITY.md`](docs/notes/THEORY-PARITY.md):

- Multiple source tables; automatic FK-graph join ordering; disconnected-component
  partitioning.
- Multi-column inclusion dependencies; non-shared-LHS MVDs; conditional join
  dependencies (CJD).
- `UPDATE` propagation.
- General DELETE independence for rows shared across source keys (a strict-xfail
  test documents the current over-deletion).
- Concurrency / `_loop` races; the multi-table-DELETE `_loop` pre-seed contract.
- Deriving the lossless decomposition itself, and verifying losslessness — SSTC
  executes a decomposition you supply; it does not synthesise or check one.
