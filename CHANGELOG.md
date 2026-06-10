# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- DELETE-propagation integration tests (first live coverage of the delete
  chain): source→target clearing of a Level-0 person and a full Level-2
  cascade, target→source clearing, and a strict-xfail test documenting the
  unresolved shared-row independence limitation.

### Fixed

- `SOURCE_DELETE_FN` deleted target tables in root-first order (parent before
  children), raising a `ForeignKeyViolation` whenever a deleted source row's
  full cascade ran against a live FK-enforcing database. The cascade now
  deletes children before parents (reverse of the join order). Golden files
  regenerated accordingly.

## [0.0.1] - 2025-10-07

### Added

- CHANGELOG.md