# Semantic SQL Transducer Prototype

SSTC (Semantic SQL Transducer Compiler) compiles relational-algebra context
definitions into PostgreSQL. Given a *universal schema* and two contexts — a
**source** and a **target** — it generates the SQL (tables, constraint
triggers, change-tracking tables, and bidirectional mapping functions) that
keeps the two databases synchronised after every `INSERT`/`DELETE`.

It is the executable companion to *"Understanding the Semantic SQL Transducer"*
(Abgrall & Franconi, 2024 — [arXiv:2407.07502](https://arxiv.org/abs/2407.07502),
included under [`docs/papers/`](docs/papers/)). The prototype realises the
paper's trigger architecture; it does **not** derive the lossless decomposition
for you — you supply the already-decomposed target context and the universal
mapping as input. See [`docs/notes/THEORY-PARITY.md`](docs/notes/THEORY-PARITY.md)
for exactly which parts of the theory are implemented.

## Requirements

- Python **>= 3.13**
- [uv](https://docs.astral.sh/uv/) for dependency management
- [`rapt2`](https://github.com/unibz-krdb/rapt2) — the relational-algebra parser,
  installed as an editable dependency from the sibling directory `../rapt2`
- PostgreSQL — only needed to *run* the compiled SQL (and for the Docker-backed
  integration tests); not needed to compile

## Install

```shell
uv sync                # runtime dependencies
uv sync --group dev    # + pytest, ruff, testcontainers, psycopg
```

## Usage

The compiler is exposed as the `sstc` command (see `[project.scripts]` in
`pyproject.toml`). It takes three input paths and writes SQL to stdout or to a
file:

```shell
sstc <universal.json> <source.txt> <target.txt> [-o output.sql]

# e.g. compile the bundled example
uv run sstc test/inputs/example1/universal.json \
            test/inputs/example1/source.txt \
            test/inputs/example1/target.txt \
            -o output.sql
```

Apply `output.sql` to a PostgreSQL database to install the transducer. (The
generated insert/delete functions reference a `_loop` cycle-detection table,
which the script creates for you.)

## Input format

Each compilation takes three files. A complete, working set lives in
[`test/inputs/example1/`](test/inputs/example1/).

### 1. Universal schema — JSON

A JSON array of attribute definitions describing the universal relation that
both contexts project from:

```json
[
    { "name": "ssn",   "data_type": "VARCHAR(100)", "is_nullable": true },
    { "name": "empid", "data_type": "VARCHAR(100)", "is_nullable": true },
    { "name": "name",  "data_type": "VARCHAR(100)", "is_nullable": true }
]
```

### 2. Source & target contexts — relational algebra (RAPT2 syntax)

Each context is a text file of RAPT2 statements. Tables are defined by
projecting (and selecting) from the reserved relation `Universal`; constraints
are declared with dedicated operators. Both files must end with a reserved
`UniversalMapping` assignment that defines the context-to-universal mapping (and
the join order used to reconstruct full tuples).

A single-table **source** (`source.txt`):

```
Person_Source := \project_{ssn, empid, name, hdate, phone, email, dept, manager} Universal;
pk_{ssn} Person_Source;
mvd_{ssn, phone} Person_Source;
fd_{empid, hdate} \select_{defined(empid) and defined(hdate)} Person_Source;
inc⊆_{manager, empid} (Person_Source, Person_Source);

UniversalMapping := \project_{ssn, empid, name, hdate, phone, email, dept, manager} Person_Source;
```

A decomposed **target** (`target.txt`, abridged):

```
Person       := \project_{ssn, name} Universal;
pk_{ssn} Person;
Employee     := \project_{ssn, empid} \select_{defined(empid) and defined(hdate)} Universal;
pk_{empid} Employee;

inc=_{ssn, ssn} (Person, PersonPhone);
inc⊆_{ssn, ssn} (Employee, Person);

UniversalMapping := \project_{ssn, empid, name, hdate, phone, email, dept, manager}
    (Person \natural_join PersonPhone \natural_join Employee);
```

Supported operators: `\project_{}`, `\select_{}`, `\natural_join`, the guard
predicate `defined(attr)`, and the constraint declarations `pk_{}`, `fd_{}`,
`mvd_{}`, `inc=_{}` (equality), and `inc⊆_{}` (subset).

## What it generates

For each context the compiler emits, in dependency order:

1. Base tables with primary keys (nullability from the universal schema)
2. `BEFORE UPDATE` triggers that reject `UPDATE` (use `DELETE` + `INSERT`)
3. Constraint enforcement: foreign keys / inclusion-dependency triggers,
   functional- and conditional-functional-dependency checks, multivalued-
   dependency checks and grounding
4. `_INSERT` / `_DELETE` change-tracking tables and capture triggers
5. `_INSERT_JOIN` / `_DELETE_JOIN` staging tables and join functions (with the
   `_loop` cycle-detection table)
6. The four bidirectional mapping functions — `SOURCE_INSERT_FN`,
   `TARGET_INSERT_FN`, `SOURCE_DELETE_FN`, `TARGET_DELETE_FN` — and their triggers

See [`FEATURES.md`](FEATURES.md) for the complete capability reference.

## Testing

```shell
uv run pytest                                   # unit + golden + integration
uv run pytest -m "not integration"              # skip the Docker-backed tests
uv run pytest test/test_golden.py --update-golden   # regenerate golden SQL
uv run ruff check .                             # lint
```

Integration tests (`test/test_integration.py`) compile each example, install it
on a throwaway PostgreSQL container via `testcontainers`, and assert
end-to-end propagation. They are skipped automatically when Docker is
unavailable.

## Scope & limitations

The supported envelope is shaped by the PERSON example both bundled inputs are
organised around:

- **Exactly one source table** — multi-source schemas are rejected.
- **`INSERT` and `DELETE` propagate**; `UPDATE` is rejected by design.
- Single-column inclusion dependencies only; non-shared-LHS MVDs are rejected.
- Join order is taken from `UniversalMapping`, not derived from the FK graph.

Known correctness gaps (e.g. `DELETE` independence for shared rows) are tracked
in [`docs/notes/open-problems.md`](docs/notes/open-problems.md). Architecture and
design notes live under [`docs/notes/`](docs/notes/); contributor-facing
conventions are in [`CLAUDE.md`](CLAUDE.md).

## License

LGPL v2 — see [`LICENSE`](LICENSE).
