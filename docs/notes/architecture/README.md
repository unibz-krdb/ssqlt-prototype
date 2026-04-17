# Architecture

The Semantic SQL Transducer's three-layer trigger-based architecture for bidirectional schema synchronization. The base layer holds the actual data, the update tracking layer captures INSERTs and DELETEs as they happen, and the join layer reconstructs full universal tuples from partial updates so the mapping function always has complete data to work with. Without the join layer, the mapping function would have to special-case every combination of which tracking tables are populated — a combinatorial explosion tied to the specific schema.

The three layers compose in strict dependency order: **base → tracking → join → mapping**. Each layer fires the next via AFTER triggers. Loop prevention and trigger timing are cross-cutting concerns that touch every layer through the shared `_LOOP` control table.

## Files

- [layers.md](layers.md) — Base tables, update tracking layer, and join layer (with the detailed motivation for why three layers are needed)
- [loop-prevention.md](loop-prevention.md) — The `_LOOP` table mechanism that prevents infinite trigger recursion between source and target
- [timing-and-ordering.md](timing-and-ordering.md) — INSERT/DELETE ordering for foreign keys, NATURAL JOIN ordering, and the count-based wait mechanism that synchronizes the final mapping function
- [concurrency.md](concurrency.md) — Transaction isolation assumptions, known failure modes under concurrent writes, and why `_LOOP` is fragile when used by more than one writer at a time
