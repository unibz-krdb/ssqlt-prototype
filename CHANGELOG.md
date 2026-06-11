# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Ninth pipeline section, **Sync verification**: the compiled script now ends
  with `check_sync()`, returning the symmetric difference between the source
  table and the NATURAL-LEFT-OUTER-JOIN reconstruction of the target tables
  (rows labelled `missing-in-target` / `missing-in-source`; empty = in sync).
  Instance-level probe only — schema-level losslessness remains trusted.
- Integration coverage for the probe: clean-after-propagation and
  clean-after-delete assertions, a trigger-bypassing desync-injection negative
  test, and a seeded randomized insert/delete round-trip
  (`test_random_round_trip_stays_in_sync`) running for both examples.
- Explicit **URA-projection fragment** positioning across README, FEATURES,
  THEORY-PARITY, and CLAUDE.md: the paper's general mappings, CARM/OIDs, and
  value-based horizontal decomposition are not expressible — including the
  paper's own worked example (Figures 4–6).

- DELETE-propagation integration tests (first live coverage of the delete
  chain): source→target clearing of a Level-0 person and a full Level-2
  cascade, target→source clearing, and a strict-xfail test documenting the
  then-unresolved shared-row independence limitation (since fixed; see below).
- Generated `seed_loop(change_count)` helper in the preamble: clients start an
  N-statement target-side transaction with `SELECT <schema>.seed_loop(N)`
  instead of hand-computing the `N + 1` `_loop` insert.
  `test/helpers.py::seed_target_loop` delegates to it.
- `errors.py` leaf module holding `UnsupportedError` (still re-exported by
  `constraints.py`), so leaf modules like `guard.py` can raise it.
- Loud rejection (`UnsupportedError`) of non-chain guard hierarchies and of
  CFD determinants whose *nullable* attributes span guard level-groups — both
  previously compiled silently into wrong null-pattern SQL. Mandatory
  attributes in a CFD determinant are exempt (always defined, so they cannot
  affect null patterns) and no longer produce unsatisfiable `IS NULL`
  branches.
- Behavioral tests for the orphan sweep's claims: partial MVD-row deletion
  preserves shared (ssn, phone)/(ssn, email) pairs (example2, first live
  coverage of MVD grounding), a multi-row DELETE statement preserves rows a
  surviving employee still derives, and batch-deleting a grounded multi-row
  person clears all targets FK-safely. Plus compile-time rejection coverage
  for target attributes missing from the source table.
- Concurrency entry in `docs/notes/open-problems.md` and a single-writer
  operating contract in README/FEATURES: concurrent write transactions corrupt
  `_loop` state and can race the trigger-based constraint checks.

### Changed

- `SOURCE_DELETE_FN` now propagates deletes via a per-target-table **orphan
  sweep**: a target row is deleted iff no remaining source row still projects
  onto it (NULL-safe equality on every target attribute, witness constrained
  by the table's guard), children before parents. This replaces the per-MVD
  independence checks and the NEW-keyed full cascade. Golden files
  regenerated.

### Fixed

- `SOURCE_DELETE_FN` over-deleted target rows shared across source keys
  (deleting one of two same-department employees removed the `_deptmanager`
  row the other still references). The orphan sweep preserves any row a
  remaining source row still derives; the strict-xfail marker on
  `test_source_delete_preserves_shared_dept_manager` is removed and the test
  passes for both examples.
- `SOURCE_DELETE_FN` deleted target tables in root-first order (parent before
  children), raising a `ForeignKeyViolation` whenever a deleted source row's
  full cascade ran against a live FK-enforcing database. The cascade now
  deletes children before parents (reverse of the join order). Golden files
  regenerated accordingly.

## [0.0.1] - 2025-10-07

### Added

- CHANGELOG.md