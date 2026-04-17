# UPDATE Trigger Chain

**Status: UPDATE operations are not currently supported.** The compiler generates AFTER INSERT and AFTER DELETE triggers only. No BEFORE/AFTER UPDATE trigger is emitted, no `_UPDATE` tracking table exists, and the four mapping functions (`SOURCE_INSERT_FN`, `TARGET_INSERT_FN`, `SOURCE_DELETE_FN`, `TARGET_DELETE_FN`) have no UPDATE counterparts.

This document describes the observable behavior when an UPDATE is issued against a transducer-compiled schema, why it fails silently rather than loudly, and what a future UPDATE chain would need to do.

---

## Current behavior

An `UPDATE` on a base table (source or target) executes directly against the row:

```sql
UPDATE transducer._PERSON SET name = 'Jane' WHERE ssn = 'ssn1';
```

Because no UPDATE trigger exists:

1. **No tracking capture.** The `_PERSON_INSERT` and `_PERSON_DELETE` tables remain empty. The update layer (Layer 2 in [layers.md](../architecture/layers.md)) never sees the change.
2. **No join propagation.** The `_INSERT_JOIN` / `_DELETE_JOIN` tables (Layer 3) are never populated.
3. **No mapping function fires.** The opposite side's tables are never modified.
4. **The `_LOOP` table is not touched.** No cycle-prevention marker is written.

The net effect: the updated row exists on one schema side but not the other. The two sides drift out of sync silently. No error is raised. Constraint triggers (MVD, CFD, INC) are also bypassed on UPDATE because they are BEFORE INSERT triggers, so integrity constraints can be violated by UPDATE paths.

## Why this is a silent-correctness issue

The transducer's core invariant is that source and target schemas represent the same information in different shapes. INSERT and DELETE preserve this invariant through the trigger chain. UPDATE bypasses the chain entirely, so the invariant is broken for every UPDATE issued.

An application built on top of the transducer must currently enforce an "UPDATE = DELETE + INSERT" discipline at the application layer. This is fragile: any UPDATE that slips through (ad-hoc psql session, misbehaving ORM, admin script) breaks synchronization, and the breakage is invisible until someone reads the opposite side and notices stale data.

## Three ways UPDATE could be supported

### Option A: Native UPDATE triggers

Generate `AFTER UPDATE` triggers that capture both `OLD` and `NEW` rows. This requires:

- New `_UPDATE` tracking tables (or dual-populating `_DELETE` + `_INSERT` with `OLD` and `NEW`).
- A new UPDATE JOIN function that reconstructs both "before" and "after" universal tuples.
- New `SOURCE_UPDATE_FN` / `TARGET_UPDATE_FN` mapping functions that compute the diff and apply it to the opposite side (typically as paired DELETE + INSERT on the target tables whose projection of the universal tuple actually changed).
- Extension of the `_LOOP` wait mechanism to count UPDATE triggers alongside INSERT and DELETE triggers.

### Option B: Compile UPDATE to DELETE + INSERT at the trigger level

Generate a single `BEFORE UPDATE` trigger that translates the UPDATE into a DELETE of `OLD` followed by an INSERT of `NEW`, reusing the existing chains. Simpler to generate than Option A but has subtle issues:

- PK-stable updates (where the PK columns do not change) incur an unnecessary DELETE+INSERT roundtrip through the target side.
- MVD grounding (the AFTER INSERT trigger in `constraints/multivalued-dependencies.md`) re-runs and may re-generate cross-product tuples that were already present, producing redundant work.
- The `_LOOP` pre-seeding pattern for multi-row UPDATEs becomes opaque — the client cannot easily predict how many DELETE + INSERT triggers will fire.

### Option C: Explicitly reject UPDATE

Generate a `BEFORE UPDATE` trigger that raises an exception, forcing the application to use DELETE+INSERT explicitly. This makes the limitation loud rather than silent. Cheapest to implement, and it matches the spirit of the [open problems](../open-problems.md) list: surface the gap rather than paper over it.

## Recommendation

Until a proper UPDATE chain is designed, the compiler should emit Option C (reject with an exception). This converts a silent-correctness bug into a loud one and does not pretend to support an operation that cannot be made correct without nontrivial design work.

A proper UPDATE chain (Option A) is a significant addition:

- Doubles the number of mapping functions from 4 to 6.
- Requires the wait mechanism in `loop-prevention.md` to differentiate UPDATE markers from INSERT/DELETE markers (otherwise a transaction mixing the three cannot be counted correctly).
- Forces a decision on whether UPDATE is atomic at the universal-tuple level or at the per-table level — these differ when the UPDATE changes an attribute that is projected into multiple target tables.

This is tracked in [open-problems.md](../open-problems.md).

## Related

- [insert-chain.md](insert-chain.md) — the INSERT trigger chain this document mirrors
- [delete-chain.md](delete-chain.md) — the DELETE trigger chain
- [architecture/loop-prevention.md](../architecture/loop-prevention.md) — why adding UPDATE requires changes to the `_LOOP` counter semantics
