# Tier A correctness fixes — design

Date: 2026-06-11
Status: approved scope ("Focus on Tier A" directive against the 2026-06-11 paper-parity audit); design decisions made autonomously per that audit's recommendations.

## Context

The paper-parity audit identified four blocking correctness items ("Tier A") that
must be resolved before the prototype can honestly claim its supported envelope:

1. `SOURCE_DELETE_FN` over-deletes target rows shared across source keys
   (strict-xfail `test_source_delete_preserves_shared_dept_manager`).
2. `build_guard_hierarchy` silently mis-compiles non-chain guard lattices.
3. No concurrency contract is stated anywhere; `_loop` is racy by design.
4. The `_loop` pre-seed protocol (seed = N+1) leaks a compiler internal to
   every client issuing multi-statement target-side transactions.

## Item 1 — DELETE propagation: orphan sweep

**Decision.** Replace the per-MVD independence checks and the PK-scoped
full-cascade in `SOURCE_DELETE_FN` with a uniform per-target-table **orphan
sweep**: for every target table `T` (children before parents, i.e. reverse
`UniversalMapping` order), delete the rows of `T` that are no longer derivable
from the current source table:

```sql
DELETE FROM <schema>._<T> AS t
WHERE NOT EXISTS (
    SELECT 1 FROM <schema>._<source> AS s
    WHERE s.<a> IS NOT DISTINCT FROM t.<a>   -- for every attribute a of T
      AND s.<g> IS NOT NULL                  -- for every guard attribute g of T
);
```

**Why this shape (vs. patching the independence check):**

- It is the definitional semantics of the transducer: `T = π_T(σ_guard(source))`,
  so after a source delete a `T`-row survives iff a witness row still projects
  onto it. This is what the paper means by the target being a lossless view.
- It is order- and batch-independent: the old NEW-keyed cascade is FK-unsafe
  when one statement deletes several rows of the same entity (cascade *i*
  deletes the parent while cascade *j > i* still holds children). The sweep
  removes all orphans in every cascade, so FK order (children first) always
  holds.
- It subsumes both old mechanisms and additionally fixes a second latent
  over-deletion: the old MVD branch deleted a (ssn, phone) pair even when
  another source row still carried it.

`IS NOT DISTINCT FROM` is used uniformly (NULL-safe; mandatory columns are
never NULL so it degenerates to `=`). Sweep cost is a full scan per target per
deleted tuple — acceptable; performance is already a catalogued open problem
("Join layer optimization").

Compile-time validation: every target attribute must appear in the source
table's attributes, else `UnsupportedError` (the sweep SQL would otherwise
reference a non-existent column).

`TARGET_DELETE_FN` (temp-join branch) is unchanged.

**Acceptance:** xfail marker removed; full integration suite green on both
examples; goldens regenerated.

*Addendum (post-review):* the sweep's two strongest claims are now pinned by
behavioral tests — `test_source_delete_partial_mvd_row_preserves_shared_pairs`
(the old per-MVD over-deletion, example2-only), `test_source_delete_multi_row_
statement_preserves_shared_rows`, and `test_source_delete_full_mvd_person_in_
one_statement` (batch/FK-order independence). The missing-attribute
`UnsupportedError` branch is covered by
`test_source_delete_sweeps_reject_attr_missing_from_source`. The CFD validator
was refined after review: mandatory attributes in a determinant are exempt
from the spanning check and produce no dead `IS NULL` branches
(`test_cfd_branches_allow_mandatory_in_lhs`).

## Item 2 — Loud rejection of non-chain guard lattices

**Decision.** `build_guard_hierarchy` validates that the distinct guard sets
(plus the implicit empty set) form a chain under set inclusion when sorted by
cardinality; otherwise it raises `UnsupportedError` naming the incomparable
sets. One adjacent silent assumption gets the same treatment:

- `build_cfd_where_branches`: all CFD LHS attributes must live in one
  level-group (the code consults `lhs_attrs[0]` only) — validate or raise.

*Revised during implementation:* the third candidate, `inc_sql`'s use of
`pk[0]` as the self-reference column, is **documented rather than rejected** —
example2 pairs a composite source PK with an intra-table INC and is
integration-tested green, so raising would break a supported input. The
`pk[0]` semantics (first PK column = entity identity) is now stated in the
`inc_sql` docstring and tracked under "Inclusion dependencies" in
`open-problems.md`.

`UnsupportedError` moves to a new leaf module `src/sstc/errors.py` so `guard.py`
(a leaf) can raise it without importing `constraints.py` (which imports
`guard`); `constraints.py` re-exports it for backwards compatibility.

**Acceptance:** unit tests for the chain validator (accept chains, reject
lattices), for the CFD multi-group rejection, and for the composite-PK INC
rejection; parity docs updated (guard rows no longer claim unconditional
"Full").

## Item 3 — Concurrency contract (document-and-fence)

**Decision.** No mechanism change (Tier B). Add the missing entry to
`docs/notes/open-problems.md` (severity: Correctness) covering both failure
modes: `_loop` shared-state races between concurrent transactions, and
read-then-decide trigger checks (FD/CFD/MVD/INC) that pass concurrently under
snapshot isolation. State the operating contract — **one writer at a time;
serialize write transactions** — in README "Scope & limitations" and FEATURES;
update THEORY-PARITY's "gaps not yet catalogued" section (the entry graduates
into the catalogue).

## Item 4 — `_loop` seed helper

**Decision.** The preamble emits one extra function:

```sql
CREATE FUNCTION <schema>.seed_loop(change_count INT) RETURNS VOID
LANGUAGE SQL AS $$ INSERT INTO <schema>._loop VALUES (change_count + 1); $$;
```

Clients call `SELECT <schema>.seed_loop(N)` (N = number of target-side DML
statements in the transaction) instead of hand-computing the N+1 row. The
arithmetic becomes a compiler implementation detail again; the deeper redesign
(removing the count-wait entirely) stays a catalogued open problem.
`test/helpers.py::seed_target_loop` switches to the helper (dogfooding), README
and FEATURES document it as the public protocol.

**Acceptance:** goldens updated; integration tests (which exercise the helper
through `seed_target_loop`) green.

## Out of scope (unchanged from audit)

Concurrency mechanism redesign, non-chain lattice *support*, multi-source
schemas, UPDATE recasting, losslessness checking, CARM/OID input language.
