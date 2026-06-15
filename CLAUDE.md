# CLAUDE.md

## Project Overview

SSTC (Semantic SQL Transducer Compiler) compiles relational algebra definitions into PostgreSQL SQL. It parses source/target context definitions (relational algebra) against a universal schema (JSON) using RAPT2, then generates a single PostgreSQL script — `CREATE` statements, constraint triggers, change-tracking tables, and bidirectional mapping functions — that keeps a **source** and a **target** database synchronised after every `INSERT`/`DELETE`.

It is the *execution* layer of Abgrall & Franconi's transducer paper, not its synthesis layer: it realises the paper's trigger architecture but does **not** derive the lossless decomposition — you supply the already-decomposed target context and the universal mapping as input. The input language covers the **URA-projection fragment** only (both contexts project from one universal relation); the paper's CARM/OID machinery and general RA mappings — including the paper's own worked example — are not expressible. See `THEORY-PARITY.md` for which parts of the theory are implemented vs. scoped out.

## Commands

Requires Python >= 3.13.

```bash
uv sync                                              # Install runtime dependencies
uv sync --group dev                                  # + pytest, ruff, debugpy, testcontainers, psycopg
uv run pytest                                        # Run all tests (integration tests skip without Docker)
uv run pytest -m "not integration"                   # Unit + golden only (no Docker needed)
uv run pytest -m integration                         # Only the Docker-backed integration tests
uv run pytest test/test_context.py::test_name        # Run single test
uv run pytest test/test_golden.py --update-golden    # Regenerate golden SQL after intended output changes
uv run ruff check .                                  # Lint
uv run ruff format .                                 # Format
```

Compile an example via the `sstc` CLI: `uv run sstc <universal.json> <source.txt> <target.txt> [-o out.sql] [-c/--comments]`. The `--comments` flag annotates the generated SQL with section banners, per-object headers, and inline notes; it is purely additive (default output is unchanged) and gated by `Generator(ctx, comments=...)`.

## Architecture

**Data flow:** Universal JSON + relational algebra text files → RAPT2 parser → Context/Table objects → SQL output

A deeper, narrative version of this section (module map in dependency order, data flow, design patterns) lives in `docs/architecture.md`.

### Core pipeline (`src/sstc/`)

- **`context.py`** — `Direction` StrEnum and `Context` class. `Context.from_file()` parses RA via RAPT2, separating nodes into table `AssignNode`s, `DependencyNode`s, and the reserved `UniversalMapping`; it validates that the mapping's tables match the declared relations. Exposes cached constraint accessors (`primary_keys`, `functional_dependencies`, `multivalued_dependencies`, `inclusion_equivalences`, `inclusion_subsumptions`) plus `universal_mapping_join_order`/`ordered_tables`. Holds `universal_schema` and `universal_mapping`.
- **`universal_mapping.py`** — Leaf module. Pure functions `extract_projection` and `extract_join_order` peel a `UniversalMapping` `AssignNode` down to its projection list and its left-to-right base-table sequence (the declared `\natural_join` order). Imported by `context.py`.
- **`table.py`** — `Table` wraps an `AssignNode` with its associated dependency nodes. Pure data model — no SQL generation.
- **`definition.py`** — `AttributeSchema` dataclass for JSON deserialization of the universal schema.
- **`errors.py`** — Leaf module defining `UnsupportedError` (re-exported by `constraints.py` for backwards compatibility).
- **`guard.py`** — Guard hierarchy logic (leaf module). `GuardLevel`/`GuardHierarchy` dataclasses and pure functions: `build_guard_hierarchy` (rejects non-chain guard lattices), `build_cfd_where_branches`, `build_containment_pruning`, `build_null_pattern_where`.
- **`constraints.py`** — Constraint SQL generation. Functions accept a `RenderFn` callback for template rendering: `inter_table_inc` (native FK via `emit_fk`, else a deferred constraint trigger via `emit_inc_trigger`), `mvd_sql`, `fd_sql`, `inc_sql`, `constraints`. Re-exports `UnsupportedError`.
- **`generator.py`** — Orchestrates compilation via Jinja2 templates loaded from `templates/`. `Generator(ctx, schema="transducer")`; `compile()` emits nine sections in dependency order (see below). Imports from `guard.py` and `constraints.py`.
- **`templates/`** — Jinja2 `*.sql.j2` templates, one per SQL fragment (`preamble`, `create_table`, `tracking_table`, `*_check`, `*_mapping`, `*_function`, `*_trigger`). All are rendered with the target `schema` name.
- **`transducer_context.py`** — `TransducerContext` holds source and target `Context` instances, created via `from_files()`.
- **`transducer.py`** — `Transducer` entry point; `compile()` delegates to `Generator`.
- **`__init__.py`** — Public API exports: `Context`, `Direction`, `Transducer`, `TransducerContext`.
- **`__main__.py`** — CLI entry point. Accepts universal schema, source, and target paths plus `-o/--output` (default stdout) and `-c/--comments` (annotate output). Mapped to `sstc` command via `pyproject.toml` scripts.

### Compilation pipeline

`Generator.compile()` emits nine sections in dependency order; the full table (method → output) is in `FEATURES.md`:

1. `_preamble` — drop/create the `transducer` schema + the `_loop` cycle-detection table + the `seed_loop(N)` client helper
2. `_base_tables` — `CREATE TABLE` per source/target table (PKs + nullability)
3. `_reject_updates` — one `BEFORE UPDATE` raise-trigger per base table (UPDATE is unsupported)
4. `_inter_table_inc` — native FK, or a deferred constraint trigger when an FK is impossible
5. `_constraints` — FD/CFD, MVD check + grounding, intra-table INC functions
6. `_tracking` — `_INSERT`/`_DELETE` change-tracking tables + capture triggers
7. `_join` — `_INSERT_JOIN`/`_DELETE_JOIN` staging + join functions (drive `_loop`)
8. `_mapping` — the four bidirectional mapping functions (`SOURCE/TARGET` × `INSERT/DELETE`) + triggers
9. `_verification` — `check_sync()`, the instance-level sync probe (symmetric difference: source table vs. target reconstruction)

### Key patterns

- Factory class methods (`from_file`, `from_relations_and_dependencies`) create instances from parsed external data
- `Direction` StrEnum (`Direction.SOURCE`, `Direction.TARGET`) — must use `enum.StrEnum`, not `str, enum.Enum` (the latter breaks Jinja2 template rendering in Python 3.11+)
- Module dependency order: leaves `errors.py` / `guard.py` / `universal_mapping.py` / `definition.py` ← `constraints.py` & `context.py` ← `generator.py` (orchestrator). No circular deps.
- Constraint functions use a `RenderFn` callback to decouple template rendering from logic
- `Generator.compile()` validates exactly 1 source table; raises `UnsupportedError` (defined in `errors.py`, re-exported by `constraints.py`) otherwise
- RAPT2 node types: `AssignNode` (table definitions) and constraint `DependencyNode`s (`PrimaryKeyNode`, `FunctionalDependencyNode`, `MultivaluedDependencyNode`, `InclusionEquivalenceNode`, `InclusionSubsumptionNode`)
- Input table names use plain names (e.g. `Person_Source`, `PersonPhone`); RAPT2 lowercases them, and generated objects are `_`-prefixed inside the `transducer` schema (e.g. `transducer._person_source`)
- The reserved name `UniversalMapping` in relational algebra files defines the universal-to-context mapping and the join order

### Key dependency

`rapt2` (pinned `==0.5.0`) is installed as an editable dependency from sibling directory `../rapt2` (`[tool.uv.sources]`). It must be present for the project to build.

### Gotchas

- The preamble emits `DROP SCHEMA IF EXISTS transducer CASCADE; CREATE SCHEMA transducer;` then creates `transducer._loop` — so the compiler provides the cycle-detection table itself, and **applying the compiled script destroys any existing `transducer` schema**. The schema name is a `Generator` constructor argument (default `"transducer"`).
- Tests use `conftest.py` for shared fixtures and must be run from the project root (`pythonpath = ["."]` + relative fixture paths)
- Golden-file tests in `test/test_golden.py` compare full `compile()` output (for `example1` and `example2`) against `test/golden/*.sql`; regenerate with `uv run pytest test/test_golden.py --update-golden`
- Integration tests (`test/test_integration.py`, marker `integration`) compile each example, install it on a throwaway `postgres:17` container (`testcontainers` + `psycopg`), and assert end-to-end propagation. They **skip automatically when Docker is unavailable**, so a bare `uv run pytest` succeeds without Docker (silently skipping them) — use `-m integration` to force them. Per-test reset is `TRUNCATE` (AFTER triggers don't fire on TRUNCATE).
- `test/helpers.py` provides a `SchemaInfo` role map so one test body covers both examples despite different target table names. Target→source propagation requires seeding `_loop` first; the generated `seed_loop(N)` helper owns the arithmetic (`seed_target_loop` in the helpers delegates to it). Writes assume a single writer at a time — see README "Scope & limitations".
- Tests import `GuardHierarchy`, `GuardLevel`, and guard functions directly from `sstc.guard` — not via `generator`

## Input format

- **Universal schema**: JSON array of `{name, data_type, is_nullable}` objects
- **Context definitions**: Relational algebra text files using RAPT2 syntax with operators like `\project_{}`, `\select_{}`, `\natural_join`, the guard predicate `defined(attr)`, and constraint declarations (`pk_{}`, `fd_{}`, `mvd_{}`, `inc=_{}`, `inc⊆_{}`). Each file must end with a reserved `UniversalMapping` assignment.

See `test/inputs/example1/` and `test/inputs/example2/` for complete working examples (two variants of the PERSON URA example); `PERSON_EXAMPLE.md` is a researcher-facing walkthrough of that example.

## Reference materials

Top-level docs (kept current; read these first):

- **`README.md`** — install, `sstc` CLI usage, the three-file input format, and scope/limitations
- **`FEATURES.md`** — capability reference: the 9-section pipeline table and the supported envelope
- **`THEORY-PARITY.md`** — how `src/sstc/` maps to the paper; an at-a-glance parity table of what's implemented vs. scoped out
- **`PERSON_EXAMPLE.md`** — researcher-facing walkthrough of the canonical PERSON URA example: universal relation, source constraints, the lossless 8-table decomposition, guard hierarchy, the worked instance, and the bidirectional sync contract
- **`docs/architecture.md`** — the compiler's internal software architecture (module map, data flow, patterns)
- **`CHANGELOG.md`** — Keep a Changelog format; record behavior changes under the `[Unreleased]` section as part of the change

Design/theory notes (`docs/notes/`):

- **`architecture/`** — the three-layer transducer stack, loop prevention, timing/ordering
- **`constraints/`** — SQL theory for FDs, MVDs, guard dependencies, conditional join dependencies
- **`sql-generation/`** — table creation, insert/delete/update chains, mapping functions
- **`open-problems.md`** — known correctness gaps (e.g. concurrent-writer races, non-chain guard lattices)
- **`example/`** — **authoritative** reference SQL for the PERSON URA example (single table with NULLs/CFDs, decomposed into 8 target tables). Files are numbered by layer: `1_source.sql` (constraints), `2_target.sql` (decomposition), `3_updates.sql` (tracking tables), `4_functions.sql` (trigger functions), `5_triggers.sql` (trigger wiring), `6_update.sql` (test inserts); `full_script.sql` is the assembled script and `PIPELINE.md` walks input → output.

The source paper lives in **`docs/papers/`** (arXiv:2407.07502).
