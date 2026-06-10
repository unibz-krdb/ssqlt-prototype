# Papers

Academic publications related to the Semantic SQL Transducer.

- [2407.07502v1.pdf](2407.07502v1.pdf) — "Understanding the Semantic SQL Transducer (extended version)", Abgrall & Franconi, 2024. Formalizes lossless bidirectional schema transformations and the transducer architecture.

## Paper ↔ notes crosswalk

The paper is a short, formal introduction; the notes are an implementation-oriented companion. The paper defines *what* the transducer guarantees (lossless bidirectional mapping between information-capacity-equivalent schemas); the notes describe *how* the compiler generates SQL that realizes those guarantees. Entries marked `(gap)` are paper topics with no dedicated notes file yet.

| Paper section | Notes file(s) |
|---|---|
| §1 Introduction — motivation, modern data stack | [notes/README.md](../notes/README.md) (project overview) |
| §2 The role of a Semantic SQL Transducer — Figure 2 (Semantic Data Stack) | [notes/README.md](../notes/README.md) |
| §3 Inside the Semantic SQL Transducer — Figure 3 (abstract architecture, trigger templates) | [notes/architecture/README.md](../notes/architecture/README.md), [notes/architecture/layers.md](../notes/architecture/layers.md) |
| §3 — "SQL code" `INSERT S ⇒ T` and `INSERT T ⇒ S` trigger chains | [notes/sql-generation/insert-chain.md](../notes/sql-generation/insert-chain.md) |
| §3 — "Similarly: Delete S ⇒ T, Delete T ⇒ S" | [notes/sql-generation/delete-chain.md](../notes/sql-generation/delete-chain.md) |
| §3 — "attention has to be paid to avoid infinite looping of the triggers" | [notes/architecture/loop-prevention.md](../notes/architecture/loop-prevention.md) |
| §3 — UPDATE handling | (gap) — paper silent on UPDATE; notes document current non-support in [notes/sql-generation/update-chain.md](../notes/sql-generation/update-chain.md) |
| §3 — trigger firing order, synchronization across multiple tables | [notes/architecture/timing-and-ordering.md](../notes/architecture/timing-and-ordering.md) |
| §3 — concurrent transactions, isolation | (gap) — paper does not address; notes cover known failure modes in [notes/architecture/concurrency.md](../notes/architecture/concurrency.md) |
| §4 First-order database schema, dependency notation | [notes/constraints/README.md](../notes/constraints/README.md) |
| §4 — functional dependencies (a₁,…,aₙ → b₁,…,bₘ) | [notes/constraints/functional-dependencies.md](../notes/constraints/functional-dependencies.md) |
| §4 — multivalued dependencies (a₁,…,aₙ ↠ b₁,…,bₘ) | [notes/constraints/multivalued-dependencies.md](../notes/constraints/multivalued-dependencies.md) |
| §4 — inclusion dependencies (a ⊆ b) | (gap) — no dedicated notes file; implementation status in [notes/open-problems.md §Inclusion dependencies](../notes/open-problems.md#inclusion-dependencies) |
| §4 — key / PK constraints | Covered within [notes/constraints/functional-dependencies.md](../notes/constraints/functional-dependencies.md) (keys are FDs with RHS = full schema) |
| §4 Lossless transformations (schema dominance, equivalence, information capacity) | [notes/README.md](../notes/README.md) (conceptual — not expanded in notes) |
| §4 Transformation patterns — vertical decomposition | [notes/sql-generation/table-creation.md](../notes/sql-generation/table-creation.md) |
| §4 Transformation patterns — horizontal decomposition (σ-based split) | [notes/sql-generation/table-creation.md §Horizontal decomposition](../notes/sql-generation/table-creation.md) |
| §4 NULL-free lossless transformation (NULLABLE → horizontally decomposed NOT NULL) | [notes/constraints/guard-dependencies.md](../notes/constraints/guard-dependencies.md), [notes/sql-generation/mapping-functions.md](../notes/sql-generation/mapping-functions.md) |
| §4 Reverse engineering — source → CARM (Canonical Abstract Relational Model) | [notes/example/PIPELINE.md](../notes/example/PIPELINE.md) |
| §4 Complete example (Source → Person, Employee, works-in, …) | [notes/example/](../notes/example/) (`1_source.sql` through `6_update.sql`, `full_script.sql`) |
| §4 Conditional FDs / guard hierarchy (not in paper, URA-specific) | (paper gap) — [notes/constraints/guard-dependencies.md](../notes/constraints/guard-dependencies.md), [notes/constraints/conditional-join-dependencies.md](../notes/constraints/conditional-join-dependencies.md) |
| §5 Conclusions | — |

Entries marked `(gap)` on the notes side are candidates for future notes. Entries marked `(paper gap)` are topics the notes cover that the paper does not (typically implementation details that emerged during prototyping).
