# Sync checker + URA positioning — design

Date: 2026-06-11
Status: scope selected by user from the Tier B menu ("Sync checker + honest
positioning"); follows the Tier A pass recorded in
`2026-06-11-tier-a-correctness-design.md`.

## Item 1 — generated `check_sync()` (pipeline section 9)

The compiled script gains one function:

```sql
CREATE OR REPLACE FUNCTION <schema>.check_sync()
RETURNS TABLE(side TEXT, <universal columns>) LANGUAGE SQL AS $$
  ('missing-in-target' rows: source EXCEPT target-reconstruction)
  UNION ALL
  ('missing-in-source' rows: target-reconstruction EXCEPT source)
$$;
```

where the target reconstruction is the `NATURAL LEFT OUTER JOIN` of the
target base tables in `UniversalMapping` order. Design points:

- **Set operations, not joins, do the comparison** — `EXCEPT` treats NULLs as
  equal, which is exactly the NULL-safe semantics partially-NULL URA tuples
  need; no `IS NOT DISTINCT FROM` scaffolding required.
- **No null-pattern filter on the reconstruction.** The mapping functions
  filter incoherent null patterns because their staging joins are partial;
  here the *absence* of a filter is the point — an incoherent target state
  must surface as a diff, not be hidden by the WHERE clause.
- **Instance-level probe, not a losslessness proof.** An empty result says
  the two databases currently encode the same instance (a necessary
  condition); it does not prove the supplied decomposition lossless for all
  instances. Docs must say this plainly.
- `LANGUAGE SQL` (not plpgsql): in SQL-language functions, table columns take
  precedence over the `RETURNS TABLE` output parameters with the same names,
  so the universal column names can be used unqualified in the body.
- Emitted as a ninth pipeline section ("SYNC VERIFICATION") after mapping —
  it must follow base-table creation because SQL-function bodies are
  validated at `CREATE` time.

**Acceptance:** unit test for the emitted shape; integration tests that (a)
assert an empty diff after mixed-level propagation and after deletes, (b)
assert a manually injected orphan row (triggers disabled via
`session_replication_role = replica`) is reported on the correct side; golden
files regenerated; the `--comments` section-title test extended to 9 titles.

## Item 2 — randomized round-trip test

A seeded (`random.Random(42)`, deterministic) instance generator: two level-1
"boss" rows anchor the manager INC, then 12 persons at random guard levels
(level-2 rows pick a dept whose manager is that dept's boss, satisfying the
CFD `dept -> manager` and `manager ⊆ empid/ssn`). Assert `check_sync()` empty
after all inserts, delete a random sample of 6 in one statement, assert empty
again and victims/survivors correct. Runs for both examples.

## Item 3 — URA-fragment positioning

State explicitly in README, THEORY-PARITY, FEATURES, and CLAUDE.md what the
audit found implicit: the input language covers the **URA-projection
fragment** of the paper — both contexts must be projections/guarded
selections of one universal relation. The paper's general mapping framework
(arbitrary per-predicate RA views), CARM/OIDs (which need renaming ϱ and
product ×), domain constraints, and value-based horizontal decomposition are
not expressible; in particular **the paper's own worked example (Figures
4–6) is outside the envelope**, and the bundled PERSON example is its
OID-free analogue. The losslessness claim is likewise scoped: SSTC trusts
the decomposition and now verifies instance-level sync only.

## Out of scope

UPDATE recasting, multi-source, CARM input language (remaining Tier B items);
schema-level losslessness checking (chase-based) stays an open problem.
