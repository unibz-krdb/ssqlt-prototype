# Concurrency and Transaction Isolation

The transducer's trigger chain was designed assuming a single writer per transaction. The `_LOOP` table (see [loop-prevention.md](loop-prevention.md)) serves two orthogonal purposes — cycle prevention and a count-based wait mechanism — and both break under concurrent writes. This document records what currently works, what is known to fail, and what would need to change to make the architecture concurrency-safe.

---

## Current status: single-writer, untested under concurrency

The compiler does not emit any explicit locking, advisory locks, or isolation-level directives. The generated SQL assumes:

- Only one transaction at a time is writing to either schema side.
- Triggers within a transaction fire deterministically and sequentially (which PostgreSQL guarantees *within* a statement, not across statements).
- The `_LOOP` table accumulates markers from exactly one logical operation at a time.

There is no test coverage for concurrent writes, and none of the design notes address what happens when two transactions insert into the transducer schema simultaneously.

## Why `_LOOP` is fragile under concurrency

`_LOOP` is **schema-scoped** (a single row-storing table in `transducer._LOOP`), not session-scoped or transaction-scoped. Any transaction writing to any base table on either schema side writes markers into this shared table. Two problems follow.

### Problem 1: the wait mechanism mis-counts

The wait mechanism (documented in [timing-and-ordering.md](timing-and-ordering.md)) fires the final mapping function only when:

```sql
ABS(loop_start) = COUNT(*) FROM _loop
```

This works when a single transaction inserts N markers of the same sign and fires the mapping function on the last insert. With two concurrent transactions:

1. Transaction A inserts `1` into `_LOOP` (first JOIN function fires, writing marker).
2. Transaction B inserts `1` into `_LOOP` (its first JOIN function fires).
3. Transaction A's second JOIN function sees `COUNT(*) = 2` and fires the mapping function prematurely — it reads `_INSERT_JOIN` tables that B has partially populated and maps an interleaved mess to the opposite side.

The count check has no notion of transaction identity, so there is no way to distinguish A's markers from B's.

### Problem 2: loop prevention misfires

The cycle-prevention check fires `RETURN NULL` when the opposite side's marker is present:

```sql
IF EXISTS (SELECT * FROM _loop WHERE loop_start = -1) THEN RETURN NULL;
```

If transaction A (source-originated) is mid-chain and transaction B is simultaneously initiating a target-side INSERT, B writes `-1` markers. A's subsequent source-side INSERT triggers see `-1` and cancel legitimate source inserts, mistaking them for propagations from the target.

### Problem 3: tracking and join tables are also schema-scoped

`_INSERT`, `_DELETE`, `_INSERT_JOIN`, `_DELETE_JOIN` are all shared, not per-session. Two concurrent transactions writing to the same base table both deposit rows into the same `_INSERT` table, and the mapping function's cleanup (`DELETE FROM _INSERT`) deletes both transactions' rows, including any not yet mapped.

## Required isolation level

The transducer has not been tested under any specific isolation level, and no level is sufficient without further changes:

- **`READ COMMITTED`** (PostgreSQL default): concurrent transactions see each other's committed rows between statements, so the wait-mechanism count includes rows from other transactions. Broken.
- **`REPEATABLE READ`**: each transaction sees a snapshot from its start, but writes to `_LOOP` are still visible to concurrent readers (writes are never snapshot-isolated in PostgreSQL's MVCC). Count-based wait still broken.
- **`SERIALIZABLE`**: PostgreSQL may detect the serialization anomaly and abort one transaction. This converts silent corruption into an explicit abort, but does not make the architecture concurrency-safe; it just makes failure visible.

Even under `SERIALIZABLE`, the shared `_INSERT` / `_INSERT_JOIN` tables mean that two transactions must be fully serialized (one at a time) to produce correct results. This is effectively a schema-wide write lock.

## Known failure modes

| Scenario | Outcome |
|---|---|
| Two source-side INSERTs in different tables, concurrent | Wait mechanism over-counts; mapping function fires early; target sees interleaved partial data |
| Source-side INSERT + target-side INSERT, concurrent | Both loop markers present; both chains cancel each other; inserts are silently dropped on both sides |
| Source-side INSERT + source-side DELETE, concurrent | Markers intermix in `_LOOP`; wait condition may never be satisfied, leaving `_INSERT`/`_DELETE` tables populated indefinitely |
| Two DELETEs using pre-seeded `_LOOP` counts | Pre-seeded counts compose incorrectly; one transaction's count-N is misinterpreted as the other's |

## Possible mitigations (none currently implemented)

### Session-scoping the control tables

Replace the schema-level `_LOOP`, `_INSERT`, `_DELETE`, `_INSERT_JOIN`, `_DELETE_JOIN` tables with `TEMPORARY` tables (`CREATE TEMPORARY TABLE ... ON COMMIT DROP`). Temporary tables are per-session in PostgreSQL, so concurrent transactions cannot interfere. This requires regenerating all trigger functions to create these tables on demand, which complicates the AFTER INSERT → mapping chain because temporary tables are not visible across sessions.

### Per-transaction tagging

Add a `txid` column to `_LOOP` (and all tracking / join tables), populated via `pg_current_xact_id()`. Rewrite the wait check to count only rows matching the current transaction's txid:

```sql
IF ABS(loop_start) = (SELECT COUNT(*) FROM _loop WHERE txid = pg_current_xact_id())
```

Cleanup at mapping time also filters by txid. This preserves the schema-level tables but isolates transactions from each other.

### Advisory locks

Acquire `pg_advisory_xact_lock(schema_oid)` at the start of each transaction that writes to the transducer schema. Guarantees strict serialization at the cost of throughput. Acceptable if the transducer is a low-write-rate system; unacceptable for high-concurrency workloads.

### Document the limitation

Until any of the above is implemented, the most honest mitigation is to document that the transducer requires application-level serialization of writes — e.g., a queue in front of the database ensuring one transaction at a time. This is an operational constraint, not a fix.

## Relationship to other architecture components

- **Loop prevention** ([loop-prevention.md](loop-prevention.md)) — the concurrency issue is a failure mode of the same `_LOOP` table
- **Wait mechanism** ([timing-and-ordering.md](timing-and-ordering.md)) — the count-based wait is the most concurrency-fragile piece
- **Multi-table DELETE pre-seeding** ([../sql-generation/delete-chain.md](../sql-generation/delete-chain.md#multi-table-delete-transactions)) — the pre-seeded `_LOOP` count is wrong if another transaction is also writing

Concurrency-safety is not on the current [open-problems.md](../open-problems.md) list but should be — it is a correctness hole for any non-trivial deployment.
