import json

import pytest

from sstc import TransducerContext
from sstc.constraints import UnsupportedError, inc_sql
from sstc.context import Context, Direction
from sstc.generator import Generator
from sstc.guard import (
    GuardHierarchy,
    GuardLevel,
    build_cfd_where_branches,
    build_containment_pruning,
    build_guard_hierarchy,
    build_null_pattern_where,
)


def _extract_section(result: str, start_marker: str, end_marker: str) -> str:
    """Extract SQL between two function definitions (CREATE OR REPLACE FUNCTION ... start_marker)."""
    start_pattern = "CREATE OR REPLACE FUNCTION"
    # Find the function definition containing start_marker
    start = result.index(start_marker)
    # Walk back to the CREATE OR REPLACE FUNCTION line
    fn_start = result.rfind(start_pattern, 0, start)
    if fn_start == -1:
        fn_start = start
    # Find the next function definition containing end_marker
    end = result.index(end_marker, start + len(start_marker))
    fn_end = result.rfind(start_pattern, 0, end)
    if fn_end == -1:
        fn_end = end
    return result[fn_start:fn_end]


def _assert_compile_structure(sql: str):
    assert "DROP SCHEMA IF EXISTS transducer CASCADE" in sql
    assert "CREATE SCHEMA transducer" in sql
    assert "CREATE TABLE transducer._loop" in sql

    create_count = sql.count("CREATE TABLE transducer.")
    assert create_count == 46, f"Expected 46 CREATE TABLE, got {create_count}"

    fn_count = sql.count("CREATE OR REPLACE FUNCTION")
    assert fn_count == 56, f"Expected 56 functions, got {fn_count}"

    trigger_count = sql.count("CREATE TRIGGER") + sql.count("CREATE CONSTRAINT TRIGGER")
    assert trigger_count == 70, f"Expected 70 triggers, got {trigger_count}"

    assert "SOURCE_INSERT_FN" in sql
    assert "SOURCE_DELETE_FN" in sql
    assert "TARGET_INSERT_FN" in sql
    assert "TARGET_DELETE_FN" in sql

    assert "ON CONFLICT" in sql
    assert "DO NOTHING" in sql
    assert "NATURAL LEFT OUTER JOIN" in sql
    assert "ABS(loop_start)" in sql


def test_preamble(example_1_gen):
    preamble = example_1_gen._preamble()
    assert "DROP SCHEMA IF EXISTS transducer CASCADE" in preamble
    assert "CREATE SCHEMA transducer" in preamble
    assert "CREATE TABLE transducer._loop" in preamble
    assert "loop_start" in preamble


def test_base_tables(example_1_gen):
    result = example_1_gen._base_tables()

    # All 9 tables created
    assert result.count("CREATE TABLE") == 9

    # Source table with PK
    assert "CREATE TABLE transducer._person_source" in result
    assert "PRIMARY KEY (ssn)" in result

    # Target tables present
    for name in [
        "person",
        "personphone",
        "personemail",
        "employee",
        "employeedate",
        "ped",
        "peddept",
        "deptmanager",
    ]:
        assert f"CREATE TABLE transducer._{name}" in result


def test_reject_update_triggers_present(example_1_gen):
    result = example_1_gen.compile()
    # One BEFORE UPDATE trigger per base table: 1 source + 8 target = 9
    assert result.count("BEFORE UPDATE ON") == 9
    # Each table yields 3 occurrences of _REJECT_UPDATE
    # (function def, trigger def, EXECUTE FUNCTION): 9 * 3 = 27
    assert result.count("_REJECT_UPDATE") == 27
    # Distinctive message (other RAISE EXCEPTIONs exist for CFDs etc.)
    assert "use DELETE + INSERT" in result


def test_inter_table_inc_fks_and_triggers(example_1_gen):
    result = example_1_gen._inter_table_inc()

    # One FK per INC when referenced cols match the referenced table's PK;
    # otherwise an AFTER INSERT DEFERRABLE INITIALLY DEFERRED constraint
    # trigger enforcing the inclusion.
    # example1: 4 equivalences are PK-match (PersonPhone->Person, PersonEmail->Person,
    # EmployeeDate->Employee, PEDDept->PED) + 3 inter-table subsumptions
    # (Employee->Person, PED->Employee, DeptManager->Employee) = 7 FKs.
    # The PEDDept->DeptManager equivalence references dept (not PEDDept.pk=empid);
    # previously a silent skip, now a trigger.
    assert result.count("ADD FOREIGN KEY") == 7
    # Each trigger emits 2 _INC_INTER_CHECK() mentions (fn def + EXECUTE FUNCTION).
    assert result.count("_INC_INTER_CHECK()") == 2
    assert result.count("CREATE CONSTRAINT TRIGGER") == 1
    # Enforcement is deferred so the transducer's multi-statement mapping
    # cascade can tolerate intermediate violations within a transaction.
    assert "DEFERRABLE INITIALLY DEFERRED" in result

    # Equivalence (PK-match): PersonPhone.ssn -> Person.ssn
    assert (
        "ALTER TABLE transducer._personphone ADD FOREIGN KEY (ssn) REFERENCES transducer._person (ssn);"
        in result
    )
    # Subsumption: DeptManager.manager -> Employee.empid
    assert (
        "ALTER TABLE transducer._deptmanager ADD FOREIGN KEY (manager) REFERENCES transducer._employee (empid);"
        in result
    )
    # Trigger for previously-silent DeptManager->PEDDept equivalence direction
    # (dept is PEDDept's attr but not its PK = empid).
    assert "deptmanager_1_INC_INTER_CHECK" in result
    assert "AFTER INSERT ON transducer._deptmanager" in result
    assert "INC violation" in result


def test_mvd_constraints(example_1_gen):
    result = example_1_gen._constraints()

    # MVD check function (BEFORE INSERT)
    assert "check_person_source_mvd_check" in result.lower()
    assert "BEFORE INSERT" in result
    assert "EXCEPT" in result
    assert "RAISE EXCEPTION" in result

    # MVD grounding function (AFTER INSERT)
    assert "check_person_source_mvd_grounding" in result.lower()
    assert "AFTER INSERT" in result
    assert "UNION" in result


def test_fd_constraints(example_1_gen):
    result = example_1_gen._constraints()

    # 3 CFD check functions for person_source (each has function + trigger = 6)
    assert result.lower().count("check_person_source_cfd") == 6

    # All have exhaustive OR branches with IS NOT NULL
    assert "IS NOT NULL" in result

    # Contains RAISE EXCEPTION and BEFORE INSERT trigger
    assert result.count("RAISE EXCEPTION") >= 3
    assert "BEFORE INSERT" in result


def test_tracking_layer(example_1_gen):
    result = example_1_gen._tracking()

    # 9 tables x 2 (INSERT + DELETE) = 18 tracking tables
    assert result.count("CREATE TABLE") == 18

    # 9 x 2 = 18 capture functions
    assert result.count("CREATE OR REPLACE FUNCTION") == 18

    # 9 x 2 = 18 triggers
    assert result.count("CREATE TRIGGER") == 18

    # Source functions check loop_start = -1, target check loop_start = 1
    assert "loop_start = -1" in result
    assert "loop_start = 1" in result

    # Correct naming
    assert "_person_source_INSERT" in result
    assert "_person_source_DELETE" in result
    assert "_person_INSERT" in result


def test_join_layer(example_1_gen):
    result = example_1_gen._join()

    # 9 tables x 2 (INSERT_JOIN + DELETE_JOIN) = 18 staging tables
    assert result.count("CREATE TABLE") == 18

    # 9 x 2 = 18 join functions
    assert result.count("CREATE OR REPLACE FUNCTION") == 18

    # 9 x 2 = 18 join triggers
    assert result.count("CREATE TRIGGER") == 18

    # Source functions insert VALUES (1), target insert VALUES (-1)
    assert "VALUES (1)" in result
    assert "VALUES (-1)" in result

    # NATURAL LEFT OUTER JOIN used
    assert "NATURAL LEFT OUTER JOIN" in result

    # Temp table created with universal columns
    assert "CREATE TEMPORARY TABLE" in result


def test_join_function_uses_universal_mapping_order(example_1_gen):
    """Target's per-table join functions list tables in UniversalMapping order."""
    result = example_1_gen.compile()
    start = result.index("FUNCTION transducer.target_person_INSERT_JOIN_fn()")
    end = result.index("$$;", start)
    body = result[start:end]
    expected_sequence = [
        "_personphone",
        "_personemail",
        "_employee",
        "_employeedate",
        "_ped",
        "_peddept",
        "_deptmanager",
    ]
    cursor = 0
    for table in expected_sequence:
        idx = body.find(table, cursor)
        assert idx != -1, (
            f"Expected {table} after position {cursor} in order; not found"
        )
        cursor = idx


def test_source_insert_mapping(example_1_gen):
    result = example_1_gen._mapping()

    # Wait mechanism
    assert "ABS(loop_start)" in result

    # For each of 8 target tables: INSERT with ON CONFLICT DO NOTHING
    assert "ON CONFLICT" in result
    assert "DO NOTHING" in result

    # Cleanup DELETEs for source tracking tables
    assert "DELETE FROM" in result

    # Function name
    assert "SOURCE_INSERT_FN" in result


def test_target_insert_mapping(example_1_gen):
    result = example_1_gen._mapping()

    # Target insert mapping function
    assert "TARGET_INSERT_FN" in result

    # WHERE clause with IS NOT NULL for all universal columns
    assert "IS NOT NULL" in result

    # Insert into source tables
    assert "_person_source" in result


def test_target_insert_mapping_uses_loop_constant(example_1_gen):
    """Regression: TARGET_INSERT_FN must use TARGET_LOOP_VALUE, not a raw literal."""
    from sstc.generator import TARGET_LOOP_VALUE

    result = example_1_gen._mapping()
    target_fn = _extract_section(result, "TARGET_INSERT_FN", "SOURCE_DELETE_FN")
    assert f"VALUES ({TARGET_LOOP_VALUE})" in target_fn


def test_source_delete_mapping(example_1_gen):
    result = example_1_gen._mapping()

    # Source delete function: per-target orphan sweeps with NULL-safe witness
    assert "SOURCE_DELETE_FN" in result
    assert "NOT EXISTS (SELECT 1 FROM transducer._person_source AS s" in result
    assert "s.ssn IS NOT DISTINCT FROM t.ssn" in result


def test_source_delete_sweeps_children_before_parents(example_1_gen):
    """Sweeps run in reverse UniversalMapping order so child FKs never dangle."""
    sweeps = example_1_gen._build_source_delete_sweeps(
        example_1_gen.ctx.source, example_1_gen.ctx.target
    )
    order = [s["table"] for s in sweeps]
    assert order.index("deptmanager") < order.index("person")
    assert order.index("personphone") < order.index("person")


def test_source_delete_sweep_witness_includes_guards(example_1_gen):
    """A witness row must satisfy the target table's guard, not just match
    the projected attributes (e.g. _employee requires hdate defined even
    though hdate is not one of its columns)."""
    sweeps = example_1_gen._build_source_delete_sweeps(
        example_1_gen.ctx.source, example_1_gen.ctx.target
    )
    by_table = {s["table"]: s["witness_condition"] for s in sweeps}
    assert "s.hdate IS NOT NULL" in by_table["employee"]
    assert "s.manager IS NOT NULL" in by_table["deptmanager"]
    # Unguarded tables carry no guard conjuncts.
    assert "IS NOT NULL" not in by_table["person"]


def test_target_delete_mapping(example_1_gen):
    result = example_1_gen._mapping()

    # Target delete function
    assert "TARGET_DELETE_FN" in result


def test_full_compile_structure(example_1_gen):
    sql = example_1_gen.compile()

    _assert_compile_structure(sql)

    # Foreign keys: 4 from inc= (PK-match) + 3 from inc subsumption = 7.
    # The fifth equivalence (PEDDept<->DeptManager on dept, not PEDDept PK)
    # is enforced by a trigger instead of silently dropped.
    fk_count = sql.count("ADD FOREIGN KEY")
    assert fk_count == 7, f"Expected 7 foreign keys, got {fk_count}"
    inc_trigger_count = sql.count("_INC_INTER_CHECK()")
    assert inc_trigger_count == 2, (
        f"Expected 2 _INC_INTER_CHECK() mentions, got {inc_trigger_count}"
    )


def test_example2_parses(example_2_ctx):
    assert len(example_2_ctx.source.tables) == 1
    assert len(example_2_ctx.target.tables) == 8


def test_guard_hierarchy_example1(example_1_gen):
    hierarchy = example_1_gen._build_guard_hierarchy()

    # example1: all columns nullable
    assert hierarchy.mandatory_cols == []
    assert set(hierarchy.nullable_cols) == {
        "ssn",
        "empid",
        "name",
        "hdate",
        "phone",
        "email",
        "dept",
        "manager",
    }

    # 3 distinct guard levels: {}, {empid,hdate}, {empid,hdate,dept,manager}
    assert len(hierarchy.levels) == 3
    assert hierarchy.levels[0].guard_attrs == set()
    assert hierarchy.levels[1].guard_attrs == {"empid", "hdate"}
    assert hierarchy.levels[2].guard_attrs == {"empid", "hdate", "dept", "manager"}


def test_guard_hierarchy_example2(example_2_gen):
    hierarchy = example_2_gen._build_guard_hierarchy()

    # example2: ssn, name, phone, email are NOT nullable
    assert set(hierarchy.mandatory_cols) == {"ssn", "name", "phone", "email"}
    assert set(hierarchy.nullable_cols) == {"empid", "hdate", "dept", "manager"}

    # Same 3 levels
    assert len(hierarchy.levels) == 3

    # Level 0: all nullable cols are NULL
    assert hierarchy.levels[0].null_cols == ["empid", "hdate", "dept", "manager"]
    assert hierarchy.levels[0].not_null_cols == []

    # Level 1: empid, hdate NOT NULL; dept, manager NULL
    assert set(hierarchy.levels[1].not_null_cols) == {"empid", "hdate"}
    assert set(hierarchy.levels[1].null_cols) == {"dept", "manager"}

    # Level 2: all NOT NULL
    assert set(hierarchy.levels[2].not_null_cols) == {
        "empid",
        "hdate",
        "dept",
        "manager",
    }
    assert hierarchy.levels[2].null_cols == []


def test_cfd_exhaustive_checks_example2(example_2_gen):
    result = example_2_gen._constraints()

    # 3 CFD check functions (guarded FDs -> CFD template)
    assert result.lower().count("check_person_source_cfd") == 6

    # CFD_1 (empid -> hdate, guard {empid, hdate}):
    assert "R2.empid IS NULL AND R2.hdate IS NOT NULL" in result
    assert "R2.empid IS NOT NULL AND R2.hdate IS NULL" in result

    # CFD_2 (empid -> dept, guard {empid, hdate, dept, manager}):
    assert "R2.empid IS NULL AND R2.dept IS NOT NULL" in result
    assert "R2.empid IS NULL AND R2.manager IS NOT NULL" in result
    assert "R2.dept IS NOT NULL AND R2.manager IS NULL" in result
    assert "R2.dept IS NULL AND R2.manager IS NOT NULL" in result

    # All use BEFORE INSERT triggers
    assert result.count("BEFORE INSERT") >= 3


def test_inc_constraint_example2(example_2_gen):
    result = example_2_gen._constraints()

    # INC enforcement function exists
    assert "check_person_source_inc" in result.lower()

    # Allows NULL manager
    assert "IS NULL" in result

    # Uses EXCEPT pattern for existence check
    assert "EXCEPT" in result

    # BEFORE INSERT trigger
    assert "BEFORE INSERT" in result


def test_conditional_inserts_example2(example_2_gen):
    result = example_2_gen._mapping()

    # Extract just the SOURCE_INSERT_FN section
    source_fn = _extract_section(result, "SOURCE_INSERT_FN", "TARGET_INSERT_FN")

    # Guarded tables should have IF EXISTS wrapping
    assert "IF EXISTS" in source_fn
    assert "empid IS NOT NULL AND hdate IS NOT NULL" in source_fn


def test_null_pattern_where_example2(example_2_gen):
    result = example_2_gen._mapping()

    # Extract TARGET_INSERT_FN section
    target_fn = _extract_section(result, "TARGET_INSERT_FN", "SOURCE_DELETE_FN")

    # Mandatory cols always NOT NULL
    assert "ssn IS NOT NULL" in target_fn
    assert "name IS NOT NULL" in target_fn
    assert "phone IS NOT NULL" in target_fn
    assert "email IS NOT NULL" in target_fn

    # Null-pattern disjunction (not all-NOT-NULL)
    assert "empid IS NULL AND hdate IS NULL" in target_fn
    assert "empid IS NOT NULL AND hdate IS NOT NULL" in target_fn


def test_tuple_containment_pruning_example2(example_2_gen):
    result = example_2_gen._mapping()

    # Extract TARGET_INSERT_FN section
    target_fn = _extract_section(result, "TARGET_INSERT_FN", "SOURCE_DELETE_FN")

    # Tuple containment pruning should appear AFTER temp_table_join INSERT
    assert "DELETE FROM temp_table_join" in target_fn

    # Should check for richer tuples at Level 1 (empid, hdate non-null)
    assert "empid IS NOT NULL AND hdate IS NOT NULL" in target_fn

    # Should delete poorer tuples where nullable cols are NULL
    assert "empid IS NULL" in target_fn


def test_full_compile_example2(example_2_gen):
    sql = example_2_gen.compile()

    _assert_compile_structure(sql)

    # Composite PK on source
    assert "PRIMARY KEY (ssn, phone, email)" in sql

    # NOT NULL on mandatory columns
    assert "ssn VARCHAR(100) NOT NULL" in sql
    assert "name VARCHAR(100) NOT NULL" in sql

    # Key patterns from design
    assert "IF EXISTS" in sql  # Conditional INSERTs
    assert "empid IS NULL AND hdate IS NULL" in sql  # Null-pattern WHERE


def test_null_pattern_where_example1_requires_pk_not_null(example_1_gen):
    """Regression: all-nullable schema must require source PK NOT NULL in WHERE."""
    hierarchy = example_1_gen._build_guard_hierarchy()
    where = build_null_pattern_where(hierarchy)

    # Source PK must always be NOT NULL
    assert where.startswith("ssn IS NOT NULL")

    # ssn must not appear as IS NULL anywhere in the WHERE
    assert "ssn IS NULL" not in where


# --- Unit tests for _build_null_pattern_where ---


def test_null_pattern_where_all_mandatory():
    """All mandatory cols, no nullable -> just NOT NULL conjunction."""
    h = GuardHierarchy(
        mandatory_cols=["a", "b"],
        nullable_cols=[],
        levels=[GuardLevel(guard_attrs=set(), not_null_cols=[], null_cols=[])],
        source_pk=["a"],
    )
    result = build_null_pattern_where(h)
    assert result == "a IS NOT NULL AND b IS NOT NULL"


def test_null_pattern_where_mixed():
    """Mandatory prefix + disjunction for nullable cols."""
    h = GuardHierarchy(
        mandatory_cols=["ssn", "name"],
        nullable_cols=["empid", "hdate"],
        levels=[
            GuardLevel(
                guard_attrs=set(), not_null_cols=[], null_cols=["empid", "hdate"]
            ),
            GuardLevel(
                guard_attrs={"empid", "hdate"},
                not_null_cols=["empid", "hdate"],
                null_cols=[],
            ),
        ],
        source_pk=["ssn"],
    )
    result = build_null_pattern_where(h)
    assert result.startswith("ssn IS NOT NULL AND name IS NOT NULL")
    assert "(empid IS NULL AND hdate IS NULL)" in result
    assert "(empid IS NOT NULL AND hdate IS NOT NULL)" in result


def test_null_pattern_where_all_nullable_uses_source_pk():
    """All nullable schema: source_pk used as identity prefix, excluded from branches."""
    h = GuardHierarchy(
        mandatory_cols=[],
        nullable_cols=["pk1", "a", "b"],
        levels=[
            GuardLevel(
                guard_attrs=set(), not_null_cols=[], null_cols=["pk1", "a", "b"]
            ),
            GuardLevel(
                guard_attrs={"a", "b"}, not_null_cols=["a", "b"], null_cols=["pk1"]
            ),
        ],
        source_pk=["pk1"],
    )
    result = build_null_pattern_where(h)
    assert result.startswith("pk1 IS NOT NULL")
    assert "pk1 IS NULL" not in result
    assert "(a IS NULL AND b IS NULL)" in result
    assert "(a IS NOT NULL AND b IS NOT NULL)" in result


def test_null_pattern_where_single_level():
    """Single level, no guards -> non-guard nullable cols required NOT NULL."""
    h = GuardHierarchy(
        mandatory_cols=["pk"],
        nullable_cols=["x"],
        levels=[GuardLevel(guard_attrs=set(), not_null_cols=[], null_cols=["x"])],
        source_pk=["pk"],
    )
    result = build_null_pattern_where(h)
    assert result == "pk IS NOT NULL AND x IS NOT NULL"


# --- Unit tests for _build_cfd_where_branches ---


def test_cfd_branches_simple_2attr_guard():
    """empid -> hdate with guard {empid, hdate} -> exactly 3 branches."""
    h = GuardHierarchy(
        mandatory_cols=[],
        nullable_cols=["empid", "hdate"],
        levels=[
            GuardLevel(
                guard_attrs=set(), not_null_cols=[], null_cols=["empid", "hdate"]
            ),
            GuardLevel(
                guard_attrs={"empid", "hdate"},
                not_null_cols=["empid", "hdate"],
                null_cols=[],
            ),
        ],
        source_pk=["ssn"],
    )
    branches = build_cfd_where_branches(
        lhs_attrs=["empid"],
        rhs_attrs=["hdate"],
        guard_attrs=["empid", "hdate"],
        hierarchy=h,
    )
    assert len(branches) == 3
    assert "R1.empid = R2.empid" in branches[0]
    assert "R1.hdate <> R2.hdate" in branches[0]
    assert "(R2.empid IS NULL AND R2.hdate IS NOT NULL)" in branches
    assert "(R2.empid IS NOT NULL AND R2.hdate IS NULL)" in branches


def test_cfd_branches_complex_4attr_guard():
    """empid -> dept with guard {empid, hdate, dept, manager} -> 5 branches.

    Matches reference SQL: 1 main + 2 cross-level + 2 coherence.
    """
    h = GuardHierarchy(
        mandatory_cols=[],
        nullable_cols=["empid", "hdate", "dept", "manager"],
        levels=[
            GuardLevel(
                guard_attrs=set(),
                not_null_cols=[],
                null_cols=["empid", "hdate", "dept", "manager"],
            ),
            GuardLevel(
                guard_attrs={"empid", "hdate"},
                not_null_cols=["empid", "hdate"],
                null_cols=["dept", "manager"],
            ),
            GuardLevel(
                guard_attrs={"empid", "hdate", "dept", "manager"},
                not_null_cols=["empid", "hdate", "dept", "manager"],
                null_cols=[],
            ),
        ],
        source_pk=["ssn"],
    )
    branches = build_cfd_where_branches(
        lhs_attrs=["empid"],
        rhs_attrs=["dept"],
        guard_attrs=["empid", "hdate", "dept", "manager"],
        hierarchy=h,
    )
    assert len(branches) == 5
    assert "R1.empid = R2.empid AND R1.dept <> R2.dept" in branches[0]
    # Cross-level: LHS NULL -> no RHS-group attr NOT NULL
    assert "(R2.empid IS NULL AND R2.dept IS NOT NULL)" in branches
    assert "(R2.empid IS NULL AND R2.manager IS NOT NULL)" in branches
    # Coherence: dept and manager must be jointly defined
    assert (
        "(R2.empid IS NOT NULL AND R2.dept IS NOT NULL AND R2.manager IS NULL)"
        in branches
    )
    assert (
        "(R2.empid IS NOT NULL AND R2.dept IS NULL AND R2.manager IS NOT NULL)"
        in branches
    )


def test_cfd_branches_no_duplicates():
    """No duplicate branches regardless of attr overlap."""
    h = GuardHierarchy(
        mandatory_cols=[],
        nullable_cols=["a", "b"],
        levels=[
            GuardLevel(guard_attrs=set(), not_null_cols=[], null_cols=["a", "b"]),
            GuardLevel(guard_attrs={"a", "b"}, not_null_cols=["a", "b"], null_cols=[]),
        ],
        source_pk=["pk"],
    )
    branches = build_cfd_where_branches(
        lhs_attrs=["a"], rhs_attrs=["b"], guard_attrs=["a", "b"], hierarchy=h
    )
    assert len(branches) == len(set(branches))


# --- Unit tests for _build_containment_pruning ---


def test_containment_pruning_multi_level(example_1_gen):
    """3 levels -> 2 pruning rules, identity uses source_pk."""
    hierarchy = example_1_gen._build_guard_hierarchy()
    rules = build_containment_pruning(hierarchy)

    assert len(rules) == 2
    assert "t_rich.empid IS NOT NULL" in rules[0]["richer_condition"]
    assert "t_rich.hdate IS NOT NULL" in rules[0]["richer_condition"]
    assert "t_poor.empid IS NULL" in rules[0]["poorer_condition"]
    assert "empid IS NOT NULL" in rules[0]["richer_check"]
    assert rules[0]["identity_match"] == "t_rich.ssn = t_poor.ssn"


def test_containment_pruning_single_level():
    """Single hierarchy level -> no pruning rules."""
    h = GuardHierarchy(
        mandatory_cols=["pk"],
        nullable_cols=["x"],
        levels=[GuardLevel(guard_attrs=set(), not_null_cols=[], null_cols=["x"])],
        source_pk=["pk"],
    )
    assert build_containment_pruning(h) == []


def test_containment_pruning_no_nullable():
    """No nullable columns -> no pruning needed."""
    h = GuardHierarchy(
        mandatory_cols=["a", "b"],
        nullable_cols=[],
        levels=[
            GuardLevel(guard_attrs=set(), not_null_cols=[], null_cols=[]),
            GuardLevel(guard_attrs={"a"}, not_null_cols=[], null_cols=[]),
        ],
        source_pk=["a"],
    )
    assert build_containment_pruning(h) == []


def test_containment_pruning_identity_uses_mandatory(example_2_gen):
    """When mandatory_cols is non-empty, identity_match uses mandatory_cols."""
    hierarchy = example_2_gen._build_guard_hierarchy()
    rules = build_containment_pruning(hierarchy)

    assert len(rules) == 2
    for rule in rules:
        assert "t_rich.ssn = t_poor.ssn" in rule["identity_match"]
        assert "t_rich.name = t_poor.name" in rule["identity_match"]
        assert "t_rich.phone = t_poor.phone" in rule["identity_match"]
        assert "t_rich.email = t_poor.email" in rule["identity_match"]


# --- Parametrized tests for _extract_table_guard_attrs ---


@pytest.mark.parametrize(
    "table_name,expected",
    [
        ("employee", {"empid", "hdate"}),
        ("person", set()),
    ],
)
def test_extract_guard_attrs(example_1_gen, example_1_ctx, table_name, expected):
    table = next(t for t in example_1_ctx.target.tables if t.name == table_name)
    assert set(example_1_gen._extract_table_guard_attrs(table)) == expected


# --- Parametrized tests for _inc_sql ---


@pytest.mark.parametrize(
    "context_attr,expect_empty",
    [
        ("source", False),
        ("target", True),
    ],
)
def test_inc_sql(example_1_gen, example_1_ctx, context_attr, expect_empty):
    ctx = getattr(example_1_ctx, context_attr)
    result = inc_sql(ctx, example_1_gen._render)
    if expect_empty:
        assert result == ""
    else:
        assert result != ""
        assert "check_person_source_inc_1_fn" in result
        assert "BEFORE INSERT" in result
        assert "EXCEPT" in result


# --- compile() validation, dead-branch, and schema-name propagation ---


def _two_table_source_ctx(tmp_path):
    """A source Context with two tables (multi-source) parsed from inline RA."""
    schema_path = tmp_path / "universal.json"
    schema_path.write_text(
        json.dumps(
            [
                {"name": "a", "data_type": "VARCHAR(100)", "is_nullable": False},
                {"name": "b", "data_type": "VARCHAR(100)", "is_nullable": True},
                {"name": "c", "data_type": "VARCHAR(100)", "is_nullable": True},
            ]
        )
    )
    ra_path = tmp_path / "source.txt"
    ra_path.write_text(
        "R1 := \\project_{a, b} Universal;\n"
        "R2 := \\project_{a, c} Universal;\n"
        "pk_{a} R1;\n"
        "pk_{a} R2;\n"
        "UniversalMapping := \\project_{a, b, c} (R1 \\natural_join R2);\n"
    )
    return Context.from_file(str(schema_path), str(ra_path), Direction.SOURCE)


def test_compile_rejects_multi_source_table(tmp_path):
    """compile() raises UnsupportedError when the source context has != 1 table."""
    src = _two_table_source_ctx(tmp_path)
    assert len(src.tables) == 2  # precondition: two source tables parsed
    with pytest.raises(UnsupportedError, match="Expected exactly 1 source table"):
        Generator(TransducerContext(source=src, target=src)).compile()


def test_build_target_delete_checks_multi_source_arm(tmp_path):
    """Directly cover the multi-source branch of _build_target_delete_checks.

    compile() rejects >1 source table, so this branch is unreachable end-to-end;
    a direct call is the only way to exercise the per-dependent-table checks.
    """
    src = _two_table_source_ctx(tmp_path)
    gen = Generator(TransducerContext(source=src, target=src))

    checks = gen._build_target_delete_checks(src)

    # One check per dependent (non-main) source table, each with a dependent delete.
    assert len(checks) == len(src.tables) - 1
    assert all(c["dependent_deletes"] for c in checks)


def _non_chain_target_ctx(tmp_path):
    """A target Context whose guard sets {b} and {c} are incomparable."""
    schema_path = tmp_path / "universal.json"
    schema_path.write_text(
        json.dumps(
            [
                {"name": "a", "data_type": "VARCHAR(100)", "is_nullable": False},
                {"name": "b", "data_type": "VARCHAR(100)", "is_nullable": True},
                {"name": "c", "data_type": "VARCHAR(100)", "is_nullable": True},
            ]
        )
    )
    ra_path = tmp_path / "target.txt"
    ra_path.write_text(
        "T1 := \\project_{a, b} \\select_{defined(b)} Universal;\n"
        "pk_{a} T1;\n"
        "T2 := \\project_{a, c} \\select_{defined(c)} Universal;\n"
        "pk_{a} T2;\n"
        "UniversalMapping := \\project_{a, b, c} (T1 \\natural_join T2);\n"
    )
    return Context.from_file(str(schema_path), str(ra_path), Direction.TARGET)


def test_build_guard_hierarchy_rejects_non_chain(tmp_path):
    """Incomparable guard sets (a lattice of independent nullable groups) must
    fail loudly: the cumulative level construction silently mis-compiles them."""
    tgt = _non_chain_target_ctx(tmp_path)
    with pytest.raises(UnsupportedError, match="Non-chain guard hierarchy"):
        build_guard_hierarchy(
            target_tables=tgt.tables,
            universal_schema=tgt.universal_schema,
            source_primary_keys={},
        )


def test_cfd_branches_reject_lhs_spanning_levels():
    """A CFD determinant whose attributes sit in different guard level-groups
    must be rejected; branch derivation keys off a single level."""
    h = GuardHierarchy(
        mandatory_cols=["a"],
        nullable_cols=["b", "c"],
        levels=[
            GuardLevel(
                guard_attrs=set(), tables=[], not_null_cols=[], null_cols=["b", "c"]
            ),
            GuardLevel(
                guard_attrs={"b"}, tables=[], not_null_cols=["b"], null_cols=["c"]
            ),
            GuardLevel(
                guard_attrs={"b", "c"},
                tables=[],
                not_null_cols=["b", "c"],
                null_cols=[],
            ),
        ],
        source_pk=["a"],
    )
    with pytest.raises(UnsupportedError, match="spans multiple guard levels"):
        build_cfd_where_branches(["b", "c"], ["c"], ["b", "c"], h)


def test_cfd_branches_allow_mandatory_in_lhs():
    """A mandatory attribute in the CFD determinant is always defined, so it
    must neither trip the spanning check nor produce a dead IS NULL branch."""
    h = GuardHierarchy(
        mandatory_cols=["a"],
        nullable_cols=["b", "c"],
        levels=[
            GuardLevel(
                guard_attrs=set(), tables=[], not_null_cols=[], null_cols=["b", "c"]
            ),
            GuardLevel(
                guard_attrs={"b"}, tables=[], not_null_cols=["b"], null_cols=["c"]
            ),
            GuardLevel(
                guard_attrs={"b", "c"},
                tables=[],
                not_null_cols=["b", "c"],
                null_cols=[],
            ),
        ],
        source_pk=["a"],
    )
    branches = build_cfd_where_branches(["a", "b"], ["c"], ["b", "c"], h)

    # Cross-level branch comes from the nullable determinant attribute only.
    assert "(R2.b IS NULL AND R2.c IS NOT NULL)" in branches
    # No dead branch for the mandatory attribute (R2.a can never be NULL).
    assert not any("R2.a IS NULL" in br for br in branches)


def _mismatched_attr_ctxs(tmp_path):
    """Source/target Contexts where the target projects an attribute (c)
    the source table does not carry."""
    schema_path = tmp_path / "universal.json"
    schema_path.write_text(
        json.dumps(
            [
                {"name": "a", "data_type": "VARCHAR(100)", "is_nullable": False},
                {"name": "b", "data_type": "VARCHAR(100)", "is_nullable": True},
                {"name": "c", "data_type": "VARCHAR(100)", "is_nullable": True},
            ]
        )
    )
    src_path = tmp_path / "source.txt"
    src_path.write_text(
        "R1 := \\project_{a, b} Universal;\n"
        "pk_{a} R1;\n"
        "UniversalMapping := \\project_{a, b} R1;\n"
    )
    tgt_path = tmp_path / "target.txt"
    tgt_path.write_text(
        "T1 := \\project_{a, c} Universal;\n"
        "pk_{a} T1;\n"
        "UniversalMapping := \\project_{a, c} T1;\n"
    )
    return (
        Context.from_file(str(schema_path), str(src_path), Direction.SOURCE),
        Context.from_file(str(schema_path), str(tgt_path), Direction.TARGET),
    )


def test_source_delete_sweeps_reject_attr_missing_from_source(tmp_path):
    """The orphan sweep needs every target attribute on the source table to
    build a witness query; a missing attribute must fail at compile time, not
    as an unknown-column error at install time."""
    src, tgt = _mismatched_attr_ctxs(tmp_path)
    gen = Generator(TransducerContext(source=src, target=tgt))
    with pytest.raises(UnsupportedError, match="does not carry"):
        gen._build_source_delete_sweeps(src, tgt)


def test_compile_propagates_custom_schema_name(example_1_ctx):
    """A non-default schema= must replace every schema-qualified reference;
    no 'transducer.'-qualified object may leak through."""
    sql = Generator(example_1_ctx, schema="xfoo").compile()

    assert "xfoo._loop" in sql  # preamble + objects use the custom schema
    assert "xfoo._person_source" in sql
    assert "transducer." not in sql  # no leak of the default schema name
