# The PERSON URA Example

This is the canonical worked example of the SSTC prototype. Every test corpus,
golden file, and integration test in the repository is organised around it, and
the supported feature envelope is, in effect, *defined* by what this example
needs. If you want to understand what the compiler does — and, just as
importantly, what it deliberately does not do — read this example first.

It is a textbook relational-design scenario: a single wide `PERSON` relation
whose attributes are partially `NULL`, losslessly decomposed into eight
fully-keyed tables, with the compiler generating the PostgreSQL triggers that
keep the wide **source** and the decomposed **target** synchronised after every
`INSERT` and `DELETE`.

- **Inputs:** [`test/inputs/example1/`](test/inputs/example1/) and
  [`test/inputs/example2/`](test/inputs/example2/) (two variants — see
  [§9](#9-the-two-variants)).
- **Authoritative reference SQL:** [`docs/notes/example/`](docs/notes/example/)
  (hand-written layer-by-layer; `1_source.sql` … `6_update.sql`,
  `full_script.sql`).
- **Stage-by-stage compiler walkthrough:**
  [`docs/notes/example/PIPELINE.md`](docs/notes/example/PIPELINE.md).

---

## 1. Provenance and role

SSTC is the *executable* companion to **"Understanding the Semantic SQL
Transducer"** (Abgrall & Franconi, 2024 —
[arXiv:2407.07502](https://arxiv.org/abs/2407.07502), bundled under
[`docs/papers/`](docs/papers/)). The paper formalises lossless, bidirectional
mappings between information-capacity-equivalent schemas and gives a trigger
architecture that maintains them. SSTC realises that architecture — but only for
a restricted input language.

That restriction matters, and this example sits exactly on its boundary:

- **It is the URA-projection fragment.** Both the source and target contexts
  must be `\project` / `\select_{defined(...)}` views of one shared *universal
  relation* (the Universal-Relation Assumption). The PERSON example is built
  this way by construction: the source is the whole universal relation, the
  target is eight projections of it.
- **It is the OID-free analogue of the paper's own example.** The paper's worked
  example (Figures 4–6) relies on CARM/OID generation, renaming, and product —
  machinery the input language cannot express, so the paper's example *cannot be
  compiled by this prototype*. The PERSON example is the closest expressible
  stand-in: same spirit (a denormalised relation reverse-engineered into a
  normalised, NULL-free decomposition), without object identifiers.
- **Losslessness is an input assumption, not an output guarantee.** You supply
  an already-lossless decomposition. SSTC trusts it at the schema level; it does
  not run a chase or an equivalence check. The generated `check_sync()` probe
  (§8) verifies only that the two databases *currently* encode the same
  instance — necessary for losslessness, not sufficient.

For the precise mapping of theory to code, see
[`THEORY-PARITY.md`](THEORY-PARITY.md); for the paper-section ↔ notes crosswalk,
see [`docs/papers/README.md`](docs/papers/README.md).

---

## 2. At a glance

| | Source context | Target context |
|---|---|---|
| Tables | 1 (`Person_Source`, all 8 attributes) | 8 (vertical + NULL-free horizontal decomposition) |
| Dependency declarations | 7 (1 PK, 2 MVD, 3 CFD, 1 intra-table IND) | 16 (8 PK, 5 `inc=`, 3 `inc⊆`) |
| Shape | one wide, partially-`NULL`, constraint-rich relation | many narrow, fully-keyed relations wired by inclusion dependencies |
| Reconstruction | identity (it *is* the universal relation) | `NATURAL JOIN` of all 8 tables (`UniversalMapping`) |

The whole transduction is defined by three small text files (~45 lines total).
Compiling them produces roughly **2,100 lines** of PostgreSQL across nine
pipeline sections — see [`FEATURES.md`](FEATURES.md) for the section table and
[PIPELINE.md](docs/notes/example/PIPELINE.md) for the object-by-object count.

---

## 3. The universal relation

[`universal.json`](test/inputs/example1/universal.json) declares eight
attributes, every one `VARCHAR(100)` and **nullable**:

```
ssn, empid, name, hdate, phone, email, dept, manager
```

Nullability is not incidental — it is the modelling device. A `NULL` encodes
*absence of a specialization level*, and the pattern of which attributes are
non-`NULL` decides which target tables a tuple belongs in:

| Real-world entity | Non-`NULL` attributes |
|---|---|
| A person who is not an employee | `ssn, name, phone, email` |
| An employee with no department | `+ empid, hdate` |
| An employee with a department | `+ dept, manager` |

This three-way ladder is the **guard hierarchy** (§6) and is the conceptual
heart of the example.

---

## 4. The source context — one wide relation

[`source.txt`](test/inputs/example1/source.txt) declares a single relation that
projects the entire universal relation, plus the constraints that hold over it:

```
Person_Source := \project_{ssn, empid, name, hdate, phone, email, dept, manager} Universal;
pk_{ssn} Person_Source;
mvd_{ssn, phone} Person_Source;
mvd_{ssn, email} Person_Source;
fd_{empid, hdate} \select_{defined(empid) and defined(hdate)} Person_Source;
fd_{empid, dept}  \select_{defined(empid) and defined(hdate) and defined(dept) and defined(manager)} Person_Source;
fd_{dept, manager} \select_{defined(empid) and defined(hdate) and defined(dept) and defined(manager)} Person_Source;
inc⊆_{manager, empid} (Person_Source, Person_Source);

UniversalMapping := \project_{ssn, empid, name, hdate, phone, email, dept, manager} Person_Source;
```

| Declaration | Reading | Realisation |
|---|---|---|
| `pk_{ssn}` | a person is identified by SSN | native `PRIMARY KEY` |
| `mvd_{ssn, phone}` / `mvd_{ssn, email}` | a person's phones are independent of their emails (4NF) | `BEFORE INSERT` check **+** `AFTER INSERT` grounding |
| `fd_{empid, hdate}` (guarded `defined(empid) ∧ defined(hdate)`) | among employees, `empid → hdate` | CFD check over the guard hierarchy |
| `fd_{empid, dept}` (guarded by all four) | among departmented employees, `empid → dept` | CFD check (cross-level guard) |
| `fd_{dept, manager}` (guarded by all four) | each department has one manager | CFD check |
| `inc⊆_{manager, empid}` (intra-table) | every manager is an employee | `BEFORE INSERT` trigger (NULL-safe, self-reference-safe) |

Three points worth a researcher's attention:

- **The FDs are conditional (CFDs).** Each is wrapped in a
  `\select_{defined(...)}` guard, so it constrains only the rows that have
  reached the relevant specialization level. An unemployed person's `NULL`
  `hdate` does not violate `empid → hdate` because the guard excludes them. This
  is what `guard.build_cfd_where_branches` turns into exhaustive null-pattern
  `WHERE` branches.
- **The MVDs are trivial in `example1`.** Because `pk_{ssn}` makes `ssn` a key,
  every MVD with `ssn` on the left holds automatically, and the 4NF grounding
  never has a second row to complete. The multivalued case becomes observable
  only under `example2`'s composite `pk_{ssn, phone, email}` (§9). Do not cite
  `example1` as a demonstration of non-trivial MVD handling.
- **"Every manager is an employee" is stated twice.** Here as a source
  intra-table IND, and again on the target side as a foreign key
  (`DeptManager.manager → Employee.empid`, §5). Keeping those two encodings
  coherent under propagation is precisely the transducer's job.

---

## 5. The target context — the lossless 8-table decomposition

[`target.txt`](test/inputs/example1/target.txt) defines eight fully-keyed
projections. The decomposition is *vertical* (splitting columns into separate
relations) combined with *NULL-free horizontal* decomposition (each
specialization level becomes its own relation, so no stored row carries a `NULL`):

| Table | Attributes | PK | Guard level | Holds |
|---|---|---|---|---|
| `Person` | `ssn, name` | `ssn` | 0 | every person |
| `PersonPhone` | `ssn, phone` | `ssn, phone` | 0 | a person's phone(s) |
| `PersonEmail` | `ssn, email` | `ssn, email` | 0 | a person's email(s) |
| `Employee` | `ssn, empid` | `empid` | 1 | the person↔empid identity for employees |
| `EmployeeDate` | `empid, hdate` | `empid` | 1 | an employee's hire date |
| `PED` | `ssn, empid` | `empid` | 2 | person–employee–dept identity (employees with a department) |
| `PEDDept` | `empid, dept` | `empid` | 2 | an employee's department |
| `DeptManager` | `dept, manager` | `dept` | 2 | a department's manager |

The eight tables are wired together by **inclusion dependencies** — this is what
makes the decomposition lossless rather than merely a column split:

- **5 equality INCs (`inc=`)** tie co-located facts together, e.g.
  `inc=_{ssn, ssn}(Person, PersonPhone)` (a phone row exists iff its person
  does), `inc=_{empid, empid}(Employee, EmployeeDate)`,
  `inc=_{dept, dept}(PEDDept, DeptManager)`.
- **3 subsumption INCs (`inc⊆`)** encode the specialization ladder:
  `inc⊆_{ssn, ssn}(Employee, Person)` (every employee is a person),
  `inc⊆_{empid, empid}(PED, Employee)` (every departmented employee is an
  employee), and `inc⊆_{manager, empid}(DeptManager, Employee)` (every manager
  is an employee).

When a referenced column set is the referenced table's primary key, the compiler
emits a **native foreign key**; otherwise it falls back to a deferred constraint
trigger. For this example that is **7 native FKs + 1 deferred trigger** — the
single trigger is `inc=_{dept, dept}(PEDDept, DeptManager)`, because `dept` is
not `PEDDept`'s key (`empid` is), so no native FK is possible. The exact FK list
is in [PIPELINE.md §4.4](docs/notes/example/PIPELINE.md).

Finally, the reserved `UniversalMapping` says how to rebuild a universal tuple
from the eight tables — and fixes the join order used throughout the generated
code:

```
UniversalMapping := \project_{ssn, empid, name, hdate, phone, email, dept, manager}
    (Person \natural_join PersonPhone \natural_join PersonEmail
            \natural_join Employee \natural_join EmployeeDate
            \natural_join PED \natural_join PEDDept \natural_join DeptManager);
```

---

## 6. The guard hierarchy — specialization as a chain

The bridge between "one wide relation with `NULL`s" and "eight `NULL`-free
tables" is the **guard hierarchy** (`guard.py`). It reads the
`defined(...)` predicates off the target tables and partitions the universal
columns into a *chain* of specialization levels:

| Level | Guard (must be defined) | Tables at this level | Adds columns |
|---|---|---|---|
| 0 | — | `Person`, `PersonPhone`, `PersonEmail` | `ssn, name, phone, email` |
| 1 | `empid, hdate` | `Employee`, `EmployeeDate` | `empid, hdate` |
| 2 | `empid, hdate, dept, manager` | `PED`, `PEDDept`, `DeptManager` | `dept, manager` |

A tuple is mapped into a target table iff that table's guard is satisfied, so a
partially-`NULL` source row lands in exactly the right *prefix* of the ladder.
The hierarchy drives three distinct pieces of generated logic:

- **`build_cfd_where_branches`** — the null-pattern branches that make the CFD
  checks exhaustive (including "incoherent" states such as `empid` defined but
  `hdate` `NULL`).
- **`build_null_pattern_where`** — on the target→source side, keeps only
  coherent specialization patterns during reconstruction.
- **`build_containment_pruning`** — drops a less-informative tuple (e.g. a
  level-0 reconstruction) when a more-informative one (level-2) exists for the
  same identity, so the source `pk_{ssn}` is not violated.

> **Chain requirement.** The guard sets must be totally ordered by inclusion
> (∅ ⊂ {empid,hdate} ⊂ {empid,hdate,dept,manager}). Two *incomparable* nullable
> groups (independent optional facts) form a lattice, not a chain, and
> `build_guard_hierarchy` raises `UnsupportedError` rather than silently
> linearising them. This example is deliberately a clean chain.

---

## 7. A worked instance

Three people, one at each specialization level, illustrate how the wide source
maps onto the narrow target. (Phone/email kept single-valued so the rows are
valid under `example1`'s `pk_{ssn}`; see §9 for the multivalued case.)

**Source — `Person_Source`:**

| ssn | empid | name | hdate | phone | email | dept | manager |
|---|---|---|---|---|---|---|---|
| ssn1 | — | Alice | — | 555-0001 | alice@x | — | — |
| ssn2 | emp2 | Bob | 2021-03-01 | 555-0002 | bob@x | — | — |
| ssn3 | emp3 | Carol | 2020-06-15 | 555-0003 | carol@x | sales | emp2 |

`—` is `NULL`. Alice is a bare person (level 0); Bob is an employee with no
department (level 1); Carol is a departmented employee (level 2) whose manager
`emp2` is Bob — satisfying `inc⊆_{manager, empid}`.

**Target — after `INSERT … → target` propagation:**

| Table | Rows |
|---|---|
| `Person` | (ssn1, Alice), (ssn2, Bob), (ssn3, Carol) |
| `PersonPhone` | (ssn1, 555-0001), (ssn2, 555-0002), (ssn3, 555-0003) |
| `PersonEmail` | (ssn1, alice@x), (ssn2, bob@x), (ssn3, carol@x) |
| `Employee` | (ssn2, emp2), (ssn3, emp3) |
| `EmployeeDate` | (emp2, 2021-03-01), (emp3, 2020-06-15) |
| `PED` | (ssn3, emp3) |
| `PEDDept` | (emp3, sales) |
| `DeptManager` | (sales, emp2) |

Alice touches 3 tables, Bob 5, Carol all 8 — each tuple fills the prefix of the
ladder its `NULL`-pattern selects. The `NATURAL LEFT OUTER JOIN` reconstruction
named by `UniversalMapping` returns exactly the three original rows, so
`check_sync()` (§8) is empty.

---

## 8. Bidirectional synchronisation

A plain `INSERT` or `DELETE` on either side reconstructs the universal tuple and
applies the equivalent change to the other side — entirely in-database, via
triggers, with no external runtime. Four mapping functions implement it:
`SOURCE_INSERT_FN`, `TARGET_INSERT_FN`, `SOURCE_DELETE_FN`, `TARGET_DELETE_FN`.

| Operation | Behaviour | Loop protocol |
|---|---|---|
| `INSERT` source → target | project the universal tuple into the guard-selected target tables | self-firing |
| `INSERT` target → source | natural-join the 8 tables, null-pattern filter, containment-prune, insert | client calls `seed_loop(N)` first |
| `DELETE` source → target | per-target **orphan sweep**: drop a target row iff no remaining source row still projects onto it | self-firing |
| `DELETE` target → source | remove the source tuple unless other source rows still need the data | client calls `seed_loop(N)` first |
| `UPDATE` | **rejected by design** — every base table has a `BEFORE UPDATE` raise-trigger | use `DELETE` + `INSERT` |

Two mechanisms are worth understanding:

- **Loop prevention (`_loop`).** Bidirectional triggers would otherwise cascade
  forever. The `_loop` ledger encodes *direction* in the sign of a row and a
  *wait* in the row count, so a one-directional propagation does not re-trigger
  back across the bridge. Source-side writes are self-firing; a **target-side**
  transaction touching `N` tables must call `SELECT transducer.seed_loop(N)`
  first so propagation fires only after all `N` statements are captured. The
  `seed_loop(N)` helper owns the arithmetic.
- **Delete is an orphan sweep, not a mirror delete.** Removing one source row
  must not delete target rows still shared by another source key — e.g. a
  department/manager pair two employees reference. The source→target delete
  therefore removes a target row only when nothing else still projects onto it
  (NULL-safe, guard-aware, children before parents).

**Sync verification.** The script ends with `check_sync()`:

```sql
SELECT * FROM transducer.check_sync();
```

It returns the symmetric difference between the source table and the
`NATURAL LEFT OUTER JOIN` reconstruction of the target tables, each row labelled
`missing-in-target` or `missing-in-source`. An empty result means both databases
currently encode the same instance. It is an **instance-level probe** — a
necessary condition for losslessness, not a schema-level proof.

---

## 9. The two variants

`example1` and `example2` are the *same* PERSON example stressed differently —
two fixtures give the golden and integration tests broader coverage than one.
They differ in exactly three ways:

| | `example1` | `example2` |
|---|---|---|
| Source PK | `pk_{ssn}` (single) | `pk_{ssn, phone, email}` (composite) |
| `manager` references | `empid` — manager is an employee id (`DeptManager.manager → Employee.empid`) | `ssn` — manager is a person (`DeptManager.manager → P.ssn`) |
| Target table names | descriptive (`Person`, `Employee`, `EmployeeDate`, …) | terse (`P`, `PE`, `PE_HDATE`, …) |

The first difference is the semantically interesting one. Under `example1`'s
`pk_{ssn}`, `ssn` is a key, so the two MVDs are trivially satisfied and 4NF
grounding is a no-op — a person has at most one stored `(phone, email)` pair.
`example2`'s composite key is what lets the source actually represent a person
with several phones and emails, at which point the MVD check and the
`AFTER INSERT` grounding (which restores the missing cross-product tuples) do
real work. The terse target names in `example2` are also why
[`test/helpers.py`](test/helpers.py) carries a `SchemaInfo` role map: one
parametrised test body addresses tables by *role*, not by hard-coded name, and
so covers both variants.

---

## 10. What this example deliberately does not exercise

A researcher should read the example's *boundary* as carefully as its content.
The following are out of scope by construction (see
[`THEORY-PARITY.md`](THEORY-PARITY.md) and
[`docs/notes/open-problems.md`](docs/notes/open-problems.md)):

- **The paper's own worked example (Figures 4–6).** It needs CARM/OID
  generation, renaming, and product — not expressible here. PERSON is its
  OID-free analogue.
- **General relational-algebra mappings.** Both contexts must be
  `\project`/`\select_{defined(...)}` views of one universal relation. Arbitrary
  per-predicate RA views and value-based horizontal decomposition are not
  expressible.
- **Multiple source tables.** `Generator.compile()` hard-rejects any source with
  ≠ 1 table.
- **`UPDATE` propagation.** Rejected by design (the paper is silent on UPDATE).
- **Concurrent writers.** The contract is **one writer at a time**: `_loop` is a
  shared ledger and the trigger-based checks race under snapshot isolation.
- **Schema-level losslessness.** Trusted, never derived or verified;
  `check_sync()` only checks the current instances agree.
- **Constructs outside the chain shape.** Multi-column INCs, non-shared-LHS MVDs,
  non-chain guard hierarchies, and conditional join dependencies are rejected
  with `UnsupportedError` rather than mis-compiled.

---

## 11. Reproduce it

The `rapt2` editable dependency resolves only from the primary checkout, so
compile from there (not from a `.loom` worktree):

```shell
uv run sstc test/inputs/example1/universal.json \
            test/inputs/example1/source.txt \
            test/inputs/example1/target.txt \
            -o person_example.sql            # add -c/--comments to annotate

# install on a database, then probe:
psql -f person_example.sql
psql -c 'SELECT * FROM transducer.check_sync();'   # empty ⇒ in sync
```

The Docker-backed integration tests compile each variant, install it on a
throwaway `postgres:17` container, and assert end-to-end propagation in both
directions plus constraint rejection:

```shell
uv run pytest -m integration        # requires Docker; skipped otherwise
```

---

## 12. See also

- [`docs/notes/example/PIPELINE.md`](docs/notes/example/PIPELINE.md) — the
  stage-by-stage compiler walkthrough for this example (parse → 9 sections →
  runtime trigger chain).
- [`docs/notes/example/`](docs/notes/example/) — the authoritative hand-written
  reference SQL, numbered by layer.
- [`FEATURES.md`](FEATURES.md) — capability reference and the 9-section pipeline
  table.
- [`THEORY-PARITY.md`](THEORY-PARITY.md) — how `src/sstc/` maps to the paper,
  with a parity table of what is implemented vs. scoped out.
- [`docs/papers/README.md`](docs/papers/README.md) — paper-section ↔ notes
  crosswalk.
- [`README.md`](README.md) — install, CLI usage, input format, scope.
