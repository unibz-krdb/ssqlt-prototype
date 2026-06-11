"""Integration tests: compile each example, install on Postgres, verify propagation.

Tests using ``transducer_db`` / ``schema_info`` run once per parametrized example
(see ``compiled_example`` in ``test/conftest.py``). Constraint-violation tests
remain example1-specific via an inline skip.
"""

import random

import psycopg.errors
import pytest

from test.helpers import (
    SOURCE_COLUMNS,
    insert_source,
    seed_target_loop,
    source_rows,
    sync_diff,
    target_state,
    truncate_all,
)

pytestmark = pytest.mark.integration


# example1's source INC is manager ⊆ empid (self-ref by empid).
# example2's source INC is manager ⊆ ssn (self-ref by ssn).
# Likewise on the target side for _deptmanager.manager.
def _self_manager(schema_info, *, ssn: str, empid: str) -> str:
    return empid if schema_info.example == "example1" else ssn


# --- Smoke test ---


def test_schema_installs(transducer_db, schema_info):
    """Compiled SQL installs without error; all expected tables exist."""
    rows = transducer_db.execute(
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'transducer'
        """
    ).fetchall()
    tables = {r[0] for r in rows}

    expected_base = {"_loop", schema_info.source_table} | set(
        schema_info.tables.values()
    )
    assert expected_base.issubset(tables), f"Missing: {expected_base - tables}"
    # 9 base (non-_loop) × {base, _INSERT, _DELETE, _INSERT_JOIN, _DELETE_JOIN} + _loop
    assert len(tables) == 46


# --- Source-to-target propagation ---


def test_simple_person_propagates(transducer_db, schema_info):
    """Level 0: person with only ssn/name/phone/email (no employee info)."""
    insert_source(
        transducer_db, schema_info, ssn="S1", name="Alice", phone="P1", email="E1"
    )
    state = target_state(transducer_db, schema_info)

    assert state["person"] == [("S1", "Alice")]
    assert state["phone"] == [("S1", "P1")]
    assert state["email"] == [("S1", "E1")]
    assert state["employee"] == []
    assert state["employee_date"] == []
    assert state["ped"] == []
    assert state["ped_dept"] == []
    assert state["dept_manager"] == []

    assert (
        transducer_db.execute(
            f"SELECT * FROM transducer.{schema_info.source_table}_insert"
        ).fetchall()
        == []
    )
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_employee_propagates(transducer_db, schema_info):
    """Level 1: employee with empid+hdate, no department."""
    insert_source(
        transducer_db,
        schema_info,
        ssn="S2",
        empid="EMP2",
        name="Bob",
        hdate="H2",
        phone="P2",
        email="E2",
    )
    state = target_state(transducer_db, schema_info)

    assert state["person"] == [("S2", "Bob")]
    assert state["phone"] == [("S2", "P2")]
    assert state["email"] == [("S2", "E2")]
    assert state["employee"] == [("S2", "EMP2")]
    assert state["employee_date"] == [("EMP2", "H2")]
    assert state["ped"] == []
    assert state["ped_dept"] == []
    assert state["dept_manager"] == []


def test_full_employee_with_dept_propagates(transducer_db, schema_info):
    """Level 2: full tuple, all 8 target tables populated.

    Self-managing row satisfies the source INC and the target
    ``_deptmanager(manager)`` → person-table(PK) FK.
    """
    manager = _self_manager(schema_info, ssn="S3", empid="EMP3")
    insert_source(
        transducer_db,
        schema_info,
        ssn="S3",
        empid="EMP3",
        name="Carol",
        hdate="H3",
        phone="P3",
        email="E3",
        dept="D3",
        manager=manager,
    )
    state = target_state(transducer_db, schema_info)

    assert state["person"] == [("S3", "Carol")]
    assert state["phone"] == [("S3", "P3")]
    assert state["email"] == [("S3", "E3")]
    assert state["employee"] == [("S3", "EMP3")]
    assert state["employee_date"] == [("EMP3", "H3")]
    assert state["ped"] == [("S3", "EMP3")]
    assert state["ped_dept"] == [("EMP3", "D3")]
    assert state["dept_manager"] == [("D3", manager)]


def test_multiple_persons_propagate(transducer_db, schema_info):
    """Three inserts at different guard levels; verify independent propagation."""
    # Level 0 only
    insert_source(
        transducer_db, schema_info, ssn="S10", name="Xena", phone="P10", email="E10"
    )
    # Level 0 + 1
    insert_source(
        transducer_db,
        schema_info,
        ssn="S20",
        empid="EMP20",
        name="Yara",
        hdate="H20",
        phone="P20",
        email="E20",
    )
    # Level 0 + 1 + 2; manager references S20/EMP20 (an existing row) to satisfy INC
    manager = _self_manager(schema_info, ssn="S20", empid="EMP20")
    insert_source(
        transducer_db,
        schema_info,
        ssn="S30",
        empid="EMP30",
        name="Zara",
        hdate="H30",
        phone="P30",
        email="E30",
        dept="D30",
        manager=manager,
    )

    state = target_state(transducer_db, schema_info)

    assert len(state["person"]) == 3
    assert {r[0] for r in state["person"]} == {"S10", "S20", "S30"}
    assert len(state["phone"]) == 3
    assert len(state["email"]) == 3

    employee = sorted(state["employee"], key=lambda r: r[1])
    assert len(employee) == 2
    assert {r[1] for r in employee} == {"EMP20", "EMP30"}
    assert len(state["employee_date"]) == 2

    assert state["ped"] == [("S30", "EMP30")]
    assert state["ped_dept"] == [("EMP30", "D30")]
    assert state["dept_manager"] == [("D30", manager)]

    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


# --- Constraint enforcement (Phase D) ---
# These tests exercise example1's specific CFD/INC/MVD semantics. Example2
# declares similar constraints but its composite PK and mandatory columns
# make the failure modes sufficiently different that we treat those as
# separate new tests rather than parametrizing these.


def test_cfd_empid_hdate_violation(transducer_db, schema_info):
    """CFD empid→hdate: empid non-null with hdate null rejected (guard incoherence).

    CFD triggers compare NEW against existing rows via cross join, so they
    require at least one row in the source table to fire.
    """
    if schema_info.example != "example1":
        pytest.skip("example1-only constraint test")
    insert_source(
        transducer_db, schema_info, ssn="V0", name="Seed", phone="P0", email="E0"
    )
    with pytest.raises(
        psycopg.errors.RaiseException, match="CFD violation.*empid -> hdate"
    ):
        insert_source(
            transducer_db,
            schema_info,
            ssn="V1",
            empid="EMP_V1",
            name="Vicky",
            phone="PV1",
            email="EV1",
        )


def test_cfd_empid_dept_cross_level_violation(transducer_db, schema_info):
    """CFD empid→dept: dept non-null without empid rejected (cross-level coherence)."""
    if schema_info.example != "example1":
        pytest.skip("example1-only constraint test")
    insert_source(
        transducer_db, schema_info, ssn="V0", name="Seed", phone="P0", email="E0"
    )
    with pytest.raises(
        psycopg.errors.RaiseException, match="CFD violation.*empid -> dept"
    ):
        insert_source(
            transducer_db,
            schema_info,
            ssn="V2",
            name="Wade",
            phone="PV2",
            email="EV2",
            dept="DV2",
        )


def test_cfd_dept_manager_violation(transducer_db, schema_info):
    """CFD dept→manager: same dept with different managers rejected (FD conflict)."""
    if schema_info.example != "example1":
        pytest.skip("example1-only constraint test")
    # First employee: self-managing, dept=DEPTX
    insert_source(
        transducer_db,
        schema_info,
        ssn="VA",
        empid="EMPA",
        name="Amy",
        hdate="HA",
        phone="PA",
        email="EA",
        dept="DEPTX",
        manager="EMPA",
    )
    # Second: no dept (needed so EMPB exists as empid for INC)
    insert_source(
        transducer_db,
        schema_info,
        ssn="VB",
        empid="EMPB",
        name="Ben",
        hdate="HB",
        phone="PB",
        email="EB",
    )
    # Third: same dept=DEPTX but manager=EMPB conflicts with EMPA for DEPTX
    with pytest.raises(
        psycopg.errors.RaiseException, match="CFD violation.*dept -> manager"
    ):
        insert_source(
            transducer_db,
            schema_info,
            ssn="VC",
            empid="EMPC",
            name="Cal",
            hdate="HC",
            phone="PC",
            email="EC",
            dept="DEPTX",
            manager="EMPB",
        )


def test_inc_violation(transducer_db, schema_info):
    """INC manager⊆empid: manager referencing non-existent empid rejected."""
    if schema_info.example != "example1":
        pytest.skip("example1-only constraint test")
    insert_source(
        transducer_db, schema_info, ssn="VA", name="Amy", phone="PA", email="EA"
    )
    with pytest.raises(psycopg.errors.RaiseException, match="INC violation"):
        insert_source(
            transducer_db,
            schema_info,
            ssn="VB",
            empid="EMPB",
            name="Ben",
            hdate="HB",
            phone="PB",
            email="EB",
            dept="DB",
            manager="GHOST",
        )


def test_inter_table_inc_trigger_rejects_orphan(transducer_db, schema_info):
    """Deferred INC trigger: DeptManager.dept must appear in PEDDept.dept.

    Previously this equivalence direction was silently unenforced (emit_fk
    returned None because dept is not PEDDept's PK). Now a DEFERRABLE
    INITIALLY DEFERRED constraint trigger enforces it — under autocommit
    every statement is its own transaction, so the deferred check still
    runs at the end of the single INSERT.
    """
    if schema_info.example != "example1":
        pytest.skip("example1-specific inter-table INC wiring")
    tbl = schema_info.tables
    # Satisfy DeptManager.manager -> Employee.empid FK before exercising the
    # new trigger on DeptManager.dept.
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['person']} VALUES ('ORPHAN_M', 'x')"
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee']} VALUES ('ORPHAN_M', 'ORPHAN_M')"
    )
    with pytest.raises(psycopg.errors.RaiseException, match="INC violation"):
        transducer_db.execute(
            f"INSERT INTO transducer.{tbl['dept_manager']} "
            f"VALUES ('ORPHAN_D', 'ORPHAN_M')"
        )


def test_update_on_base_table_is_rejected(transducer_db, schema_info):
    """UPDATE on any base table raises — UPDATE propagation is not implemented.

    The BEFORE UPDATE trigger emitted per base table fails loudly instead
    of silently bypassing the mapping pipeline.
    """
    insert_source(
        transducer_db, schema_info, ssn="U9", name="Uri", phone="UP9", email="UE9"
    )
    with pytest.raises(psycopg.errors.RaiseException, match="use DELETE \\+ INSERT"):
        transducer_db.execute(
            f"UPDATE transducer.{schema_info.source_table} "
            f"SET name = 'Renamed' WHERE ssn = 'U9'"
        )
    with pytest.raises(psycopg.errors.RaiseException, match="use DELETE \\+ INSERT"):
        transducer_db.execute(
            f"UPDATE transducer.{schema_info.tables['person']} "
            f"SET name = 'Renamed' WHERE ssn = 'U9'"
        )


def test_mvd_violation(transducer_db, schema_info):
    """MVD {ssn}→→{phone}: inconsistent non-MVD attrs for same ssn rejected."""
    if schema_info.example != "example1":
        pytest.skip("example1-only constraint test")
    insert_source(
        transducer_db, schema_info, ssn="VM", name="Mary", phone="PM1", email="EM1"
    )
    # Same ssn, different name → cross-product tuple doesn't exist → violation
    with pytest.raises(psycopg.errors.RaiseException, match="MVD constraint violation"):
        insert_source(
            transducer_db,
            schema_info,
            ssn="VM",
            name="Nora",
            phone="PM2",
            email="EM2",
        )


# --- Target-to-source propagation (Phase C) ---
#
# Protocol: seed ``_loop`` with 1 + N where N is the number of target inserts.
# Each target join-fn decrements by one (via -1); on reaching ABS(seed),
# TARGET_INSERT_FN fires and reconstructs the universal tuple into the
# source table.


def test_target_to_source_simple_person(transducer_db, schema_info):
    """Insert a Level 0 person via target tables; verify source populated."""
    tbl = schema_info.tables
    seed_target_loop(transducer_db, 3)
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['person']} VALUES ('T1', 'Dana')"
    )
    transducer_db.execute(f"INSERT INTO transducer.{tbl['phone']} VALUES ('T1', 'TP1')")
    transducer_db.execute(f"INSERT INTO transducer.{tbl['email']} VALUES ('T1', 'TE1')")

    source = transducer_db.execute(
        f"SELECT * FROM transducer.{schema_info.source_table}"
    ).fetchall()
    assert len(source) == 1, f"Expected 1 row in source, got {len(source)}"
    assert source[0] == ("T1", None, "Dana", None, "TP1", "TE1", None, None)

    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_target_to_source_employee(transducer_db, schema_info):
    """Insert a Level 1 employee via target tables; verify source populated."""
    tbl = schema_info.tables
    seed_target_loop(transducer_db, 5)
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['person']} VALUES ('T2', 'Eve')"
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee']} VALUES ('T2', 'TEMP2')"
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee_date']} VALUES ('TEMP2', 'TH2')"
    )
    transducer_db.execute(f"INSERT INTO transducer.{tbl['phone']} VALUES ('T2', 'TP2')")
    transducer_db.execute(f"INSERT INTO transducer.{tbl['email']} VALUES ('T2', 'TE2')")

    source = transducer_db.execute(
        f"SELECT * FROM transducer.{schema_info.source_table}"
    ).fetchall()
    assert len(source) == 1, f"Expected 1 row in source, got {len(source)}"
    assert source[0] == ("T2", "TEMP2", "Eve", "TH2", "TP2", "TE2", None, None)

    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_target_to_source_full_employee(transducer_db, schema_info):
    """Insert a Level 2 full employee via target tables; verify source populated."""
    tbl = schema_info.tables
    manager = _self_manager(schema_info, ssn="T3", empid="TEMP3")
    seed_target_loop(transducer_db, 8)
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['person']} VALUES ('T3', 'Finn')"
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee']} VALUES ('T3', 'TEMP3')"
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee_date']} VALUES ('TEMP3', 'TH3')"
    )
    transducer_db.execute(f"INSERT INTO transducer.{tbl['ped']} VALUES ('T3', 'TEMP3')")
    # PEDDept must precede DeptManager: the inc=_{dept, dept} equivalence is
    # now enforced by a deferred trigger that checks at statement commit
    # (per-statement transactions under autocommit).
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['ped_dept']} VALUES ('TEMP3', 'TD3')"
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['dept_manager']} VALUES ('TD3', '{manager}')"
    )
    transducer_db.execute(f"INSERT INTO transducer.{tbl['phone']} VALUES ('T3', 'TP3')")
    transducer_db.execute(f"INSERT INTO transducer.{tbl['email']} VALUES ('T3', 'TE3')")

    source = transducer_db.execute(
        f"SELECT * FROM transducer.{schema_info.source_table}"
    ).fetchall()
    assert len(source) == 1, f"Expected 1 row in source, got {len(source)}"
    assert source[0] == ("T3", "TEMP3", "Finn", "TH3", "TP3", "TE3", "TD3", manager)

    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


# --- Idempotence + round-trip ---


def test_source_pk_rejects_duplicate(transducer_db, schema_info):
    """Re-inserting the same source PK raises UniqueViolation; targets unchanged."""
    insert_source(
        transducer_db, schema_info, ssn="ID1", name="Ida", phone="P1", email="E1"
    )
    state_before = target_state(transducer_db, schema_info)
    with pytest.raises(psycopg.errors.UniqueViolation):
        insert_source(
            transducer_db, schema_info, ssn="ID1", name="Ida", phone="P1", email="E1"
        )
    assert target_state(transducer_db, schema_info) == state_before


def test_target_on_conflict_dedupes(transducer_db, schema_info):
    """Two source rows sharing a projected target key must not duplicate target rows.

    Exercises the ``ON CONFLICT ... DO NOTHING`` branch of ``insert_mapping.sql.j2``.
    Only meaningful where the source PK admits distinct rows that project to the
    same target row — true for example2's composite PK ``(ssn, phone, email)``.
    """
    if schema_info.example != "example2":
        pytest.skip(
            "example2-only: needs composite source PK to vary non-projected cols"
        )
    insert_source(
        transducer_db, schema_info, ssn="S1", name="Ada", phone="P1", email="E1"
    )
    insert_source(
        transducer_db, schema_info, ssn="S1", name="Ada", phone="P2", email="E2"
    )
    state = target_state(transducer_db, schema_info)
    assert state["person"] == [("S1", "Ada")]  # deduped
    assert sorted(state["phone"]) == [("S1", "P1"), ("S1", "P2")]
    assert sorted(state["email"]) == [("S1", "E1"), ("S1", "E2")]


def test_source_to_target_to_source_roundtrip(transducer_db, schema_info):
    """Level-2 source row → targets → truncate → re-hydrate via targets → same source.

    End-to-end correctness assertion: the T→S reconstruction must recover the
    exact tuple originally inserted into the source.
    """
    manager = _self_manager(schema_info, ssn="R1", empid="EMPR1")
    original = dict(
        ssn="R1",
        empid="EMPR1",
        name="Rhea",
        hdate="HR1",
        phone="PR1",
        email="ER1",
        dept="DR1",
        manager=manager,
    )
    insert_source(transducer_db, schema_info, **original)
    # Confirm full propagation before wiping state.
    state = target_state(transducer_db, schema_info)
    assert len(state["dept_manager"]) == 1

    truncate_all(transducer_db)

    tbl = schema_info.tables
    seed_target_loop(transducer_db, 8)
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['person']} VALUES (%s, %s)",
        (original["ssn"], original["name"]),
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee']} VALUES (%s, %s)",
        (original["ssn"], original["empid"]),
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['employee_date']} VALUES (%s, %s)",
        (original["empid"], original["hdate"]),
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['ped']} VALUES (%s, %s)",
        (original["ssn"], original["empid"]),
    )
    # PEDDept before DeptManager — see note in test_target_to_source_full_employee.
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['ped_dept']} VALUES (%s, %s)",
        (original["empid"], original["dept"]),
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['dept_manager']} VALUES (%s, %s)",
        (original["dept"], original["manager"]),
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['phone']} VALUES (%s, %s)",
        (original["ssn"], original["phone"]),
    )
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['email']} VALUES (%s, %s)",
        (original["ssn"], original["email"]),
    )

    source = transducer_db.execute(
        f"SELECT {', '.join(SOURCE_COLUMNS)} FROM transducer.{schema_info.source_table}"
    ).fetchall()
    assert len(source) == 1
    assert source[0] == tuple(original[c] for c in SOURCE_COLUMNS)
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


# --- Level-transition / guard hierarchy ---


def test_level_upgrade_via_reinsert_blocked(transducer_db, schema_info):
    """Upgrading an existing row (L0 → L1) by re-inserting the same ssn is rejected.

    UPDATE is compiled only as a rejection trigger (see
    ``test_update_on_base_table_is_rejected``), so L0 → L1 can only be
    attempted via re-INSERT. Either the source PK (identical cols) or the
    MVD check (same ssn, different non-MVD attrs) fires before any trigger
    populates L1 targets.
    """
    insert_source(
        transducer_db, schema_info, ssn="U1", name="Una", phone="UP1", email="UE1"
    )
    pre = target_state(transducer_db, schema_info)
    assert pre["employee"] == []  # L1 not populated yet

    with pytest.raises((psycopg.errors.UniqueViolation, psycopg.errors.RaiseException)):
        insert_source(
            transducer_db,
            schema_info,
            ssn="U1",
            empid="UEMP1",
            name="Una",
            hdate="UH1",
            phone="UP1",
            email="UE1",
        )
    # State unchanged: L1 never populated
    assert target_state(transducer_db, schema_info)["employee"] == []


def test_independent_levels_coexist(transducer_db, schema_info):
    """A later Level-1 row doesn't disturb a previously-inserted Level-0 row."""
    insert_source(
        transducer_db, schema_info, ssn="L0", name="Leo", phone="LP0", email="LE0"
    )
    l0_state = target_state(transducer_db, schema_info)
    assert l0_state["employee"] == []

    insert_source(
        transducer_db,
        schema_info,
        ssn="L1",
        empid="LEMP1",
        name="Lea",
        hdate="LH1",
        phone="LP1",
        email="LE1",
    )
    state = target_state(transducer_db, schema_info)

    # L0 row's data still present unchanged
    assert ("L0", "Leo") in state["person"]
    assert ("L0", "LP0") in state["phone"]
    assert ("L0", "LE0") in state["email"]
    # L1 row adds new entries at all levels it reaches
    assert ("L1", "Lea") in state["person"]
    assert state["employee"] == [("L1", "LEMP1")]
    assert state["employee_date"] == [("LEMP1", "LH1")]


# --- Direct target insert: declared FKs are live ---


def test_target_fk_rejects_orphan_phone(transducer_db, schema_info):
    """Directly inserting into the phone table without a matching person row fails.

    Confirms the declared FK phone(ssn) → person(ssn) is enforced at runtime.
    """
    tbl = schema_info.tables
    with pytest.raises(
        (psycopg.errors.ForeignKeyViolation, psycopg.errors.RaiseException)
    ):
        transducer_db.execute(
            f"INSERT INTO transducer.{tbl['phone']} VALUES ('ORPHAN', 'PX')"
        )


# --- Simultaneous constraint failures ---


def test_simultaneous_cfd_and_inc_violations(transducer_db, schema_info):
    """A row violating both a CFD (empid→hdate) and the INC (manager⊆empid) raises.

    Documents *which* check fires first so future codegen re-ordering can't
    silently change error semantics. The row is constructed so both checks
    would fail: empid set with hdate NULL (CFD), and manager='GHOST' (INC).
    """
    if schema_info.example != "example1":
        pytest.skip("example1-only: uses example1's CFD + INC configuration")
    insert_source(
        transducer_db, schema_info, ssn="SA", name="Seed", phone="PSA", email="ESA"
    )
    with pytest.raises(psycopg.errors.RaiseException) as excinfo:
        insert_source(
            transducer_db,
            schema_info,
            ssn="SB",
            empid="EMPB",
            name="Ben",
            phone="PSB",
            email="ESB",
            manager="GHOST",
        )
    msg = str(excinfo.value)
    # Current ordering: CFD checks fire before INC checks (document both-or-neither).
    assert "CFD violation" in msg or "INC violation" in msg


# --- T→S loop-seed protocol ---


def test_wrong_loop_seed_leaves_source_empty(transducer_db, schema_info):
    """Seeding _loop with the wrong count for a Level-0 T→S insert does not fire
    TARGET_INSERT_FN, so the source table stays empty and _loop still has rows.

    Codifies the protocol contract: ABS(seed) must equal the exact count of
    remaining target decrements for reconstruction to fire.
    """
    tbl = schema_info.tables
    # Off-by-one: correct seed for 3 inserts would be 4; use 5 instead.
    transducer_db.execute("INSERT INTO transducer._loop VALUES (5)")
    transducer_db.execute(
        f"INSERT INTO transducer.{tbl['person']} VALUES ('W1', 'Wyn')"
    )
    transducer_db.execute(f"INSERT INTO transducer.{tbl['phone']} VALUES ('W1', 'WP1')")
    transducer_db.execute(f"INSERT INTO transducer.{tbl['email']} VALUES ('W1', 'WE1')")

    source = transducer_db.execute(
        f"SELECT * FROM transducer.{schema_info.source_table}"
    ).fetchall()
    assert source == []  # TARGET_INSERT_FN never fired
    # _loop still has the decremented counter (not cleaned up)
    loop = transducer_db.execute("SELECT * FROM transducer._loop").fetchall()
    assert loop != []


# --- DELETE propagation: source side (S->T) ---
#
# A source-side DELETE self-fires. The single source table writes one _loop
# row (value 1) via its DELETE_JOIN function, and SOURCE_DELETE_FN's wait
# check (loop_start = row_count, use_abs=False) is satisfied immediately --
# no client pre-seeding is needed, unlike the multi-table target side. These
# tests are the first live coverage of the delete chain (previously only the
# insert chain was exercised against Postgres).


def test_source_delete_simple_person_clears_targets(transducer_db, schema_info):
    """Deleting a Level-0 source row removes its person/phone/email targets."""
    insert_source(
        transducer_db, schema_info, ssn="D1", name="Dot", phone="DP1", email="DE1"
    )
    assert target_state(transducer_db, schema_info)["person"] == [("D1", "Dot")]

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn = 'D1'"
    )

    state = target_state(transducer_db, schema_info)
    assert state["person"] == []
    assert state["phone"] == []
    assert state["email"] == []
    # Tracking + loop state fully reset by SOURCE_DELETE_FN cleanup.
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []
    assert (
        transducer_db.execute(
            f"SELECT * FROM transducer.{schema_info.source_table}_delete"
        ).fetchall()
        == []
    )


def test_source_delete_full_employee_clears_all_targets(transducer_db, schema_info):
    """Deleting the sole Level-2 source row cascades to all eight target tables.

    With only one source tuple, no target row retains a witness in the source
    table, so the orphan sweep empties every target table.
    """
    manager = _self_manager(schema_info, ssn="D3", empid="DEMP3")
    insert_source(
        transducer_db,
        schema_info,
        ssn="D3",
        empid="DEMP3",
        name="Dora",
        hdate="DH3",
        phone="DP3",
        email="DE3",
        dept="DD3",
        manager=manager,
    )
    assert target_state(transducer_db, schema_info)["dept_manager"] == [
        ("DD3", manager)
    ]

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn = 'D3'"
    )

    state = target_state(transducer_db, schema_info)
    residual = {role: rows for role, rows in state.items() if rows}
    assert residual == {}, f"target rows survived the cascade: {residual}"
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_source_delete_preserves_shared_dept_manager(transducer_db, schema_info):
    """Independence: deleting one of two same-dept employees must keep the
    shared dept_manager row the remaining employee still references.

    Two employees share department DSHARE with the same manager (required by
    CFD dept->manager). Deleting employee 2 should remove only employee 2's
    own rows, leaving employee 1 and the shared dept_manager intact.

    SOURCE_DELETE_FN's orphan sweep keeps a target row while any remaining
    source row still projects onto it, so the shared ``_deptmanager`` row
    survives via employee 1's witness row.
    """
    mgr = _self_manager(schema_info, ssn="K1", empid="KMGR")
    # Employee 1 self-manages dept DSHARE.
    insert_source(
        transducer_db,
        schema_info,
        ssn="K1",
        empid="KMGR",
        name="Kim",
        hdate="KH1",
        phone="KP1",
        email="KE1",
        dept="DSHARE",
        manager=mgr,
    )
    # Employee 2: same dept + same manager (satisfies CFD dept->manager and
    # INC manager subset-of empid/ssn).
    insert_source(
        transducer_db,
        schema_info,
        ssn="K2",
        empid="KEMP2",
        name="Kya",
        hdate="KH2",
        phone="KP2",
        email="KE2",
        dept="DSHARE",
        manager=mgr,
    )
    assert ("DSHARE", mgr) in target_state(transducer_db, schema_info)["dept_manager"]

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn = 'K2'"
    )

    state = target_state(transducer_db, schema_info)
    # Employee 2's own rows are gone.
    assert ("K2", "Kya") not in state["person"]
    assert ("KEMP2", "DSHARE") not in state["ped_dept"]
    # Employee 1 and the shared department/manager survive.
    assert ("K1", "Kim") in state["person"]
    assert ("DSHARE", mgr) in state["dept_manager"]
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_source_delete_partial_mvd_row_preserves_shared_pairs(
    transducer_db, schema_info
):
    """Deleting one row of an MVD cross-product must keep every (ssn, phone)
    and (ssn, email) pair another source row still carries.

    Only example2 admits several source rows per person (PK ssn+phone+email);
    in example1 ssn alone is the PK, so the scenario is unreachable there.

    Two inserts with disjoint phone/email get grounded to the full 2x2
    cross-product (4 source rows). Deleting exactly one of them leaves a
    witness for every pair, so the orphan sweep must delete *nothing* from
    the targets — the old per-MVD EXCEPT checks wrongly removed the deleted
    row's (ssn, phone) and (ssn, email) pairs here.
    """
    if schema_info.example != "example2":
        pytest.skip("example2-only: needs multiple source rows per ssn")
    insert_source(
        transducer_db, schema_info, ssn="M1", name="Mia", phone="MP1", email="ME1"
    )
    insert_source(
        transducer_db, schema_info, ssn="M1", name="Mia", phone="MP2", email="ME2"
    )
    # MVD grounding completed the cross-product: 4 source rows.
    assert len(source_rows(transducer_db, schema_info)) == 4

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} "
        f"WHERE ssn = 'M1' AND phone = 'MP2' AND email = 'ME2'"
    )

    state = target_state(transducer_db, schema_info)
    # Every pair still has a witness among the 3 remaining rows.
    assert set(state["phone"]) == {("M1", "MP1"), ("M1", "MP2")}
    assert set(state["email"]) == {("M1", "ME1"), ("M1", "ME2")}
    assert state["person"] == [("M1", "Mia")]
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_source_delete_multi_row_statement_preserves_shared_rows(
    transducer_db, schema_info
):
    """One DELETE statement removing two employees runs one full cascade per
    row; the sweeps must stay FK-safe across cascades and still preserve the
    dept_manager row a surviving third employee references."""
    mgr = _self_manager(schema_info, ssn="W1", empid="WMGR")
    # W1 self-manages dept WD; W2 and W3 work in WD under the same manager.
    for ssn, empid, name in [
        ("W1", "WMGR", "Wes"),
        ("W2", "WEMP2", "Wyn"),
        ("W3", "WEMP3", "Wim"),
    ]:
        insert_source(
            transducer_db,
            schema_info,
            ssn=ssn,
            empid=empid,
            name=name,
            hdate=f"WH{ssn[-1]}",
            phone=f"WP{ssn[-1]}",
            email=f"WE{ssn[-1]}",
            dept="WD",
            manager=mgr,
        )
    assert ("WD", mgr) in target_state(transducer_db, schema_info)["dept_manager"]

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn IN ('W2', 'W3')"
    )

    state = target_state(transducer_db, schema_info)
    names = {row[0] for row in state["person"]}
    assert "W2" not in names and "W3" not in names
    assert "W1" in names
    assert ("WD", mgr) in state["dept_manager"]
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


def test_source_delete_full_mvd_person_in_one_statement(transducer_db, schema_info):
    """Deleting an entire multi-row person (the grounded 2x2 cross-product) in
    one statement must clear every target row without FK violations.

    This is the batch-independence claim: each of the 4 deleted rows runs its
    own cascade, and the first cascade's sweep already removes all orphaned
    child rows (phones/emails) before the parent person row, so no cascade
    ever deletes a parent that a sibling row's child still references.
    """
    if schema_info.example != "example2":
        pytest.skip("example2-only: needs multiple source rows per ssn")
    insert_source(
        transducer_db, schema_info, ssn="N1", name="Nia", phone="NP1", email="NE1"
    )
    insert_source(
        transducer_db, schema_info, ssn="N1", name="Nia", phone="NP2", email="NE2"
    )
    assert len(source_rows(transducer_db, schema_info)) == 4

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn = 'N1'"
    )

    assert source_rows(transducer_db, schema_info) == []
    state = target_state(transducer_db, schema_info)
    residual = {role: rows for role, rows in state.items() if rows}
    assert residual == {}, f"target rows survived the batch delete: {residual}"
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


# --- DELETE propagation: target side (T->S) ---
#
# Mirror of the T->S insert protocol: seed _loop with N+1 (N = number of
# target-table deletes). Each target DELETE_JOIN writes -1; when the row
# count reaches ABS(seed), TARGET_DELETE_FN reconstructs the universal tuple
# and deletes the matching source row. FK order requires deleting child
# tables (phone/email) before the parent (person). The back-propagating
# source DELETE is suppressed because _loop still holds -1 markers when it
# fires (capture trigger's loop_check = -1).


def test_target_delete_clears_source(transducer_db, schema_info):
    """Deleting a Level-0 person's target rows removes the source row (T->S)."""
    tbl = schema_info.tables
    insert_source(
        transducer_db, schema_info, ssn="TD1", name="Tod", phone="TDP1", email="TDE1"
    )
    assert len(source_rows(transducer_db, schema_info)) == 1

    seed_target_loop(transducer_db, 3)
    # Child tables before parent to satisfy the phone/email -> person FKs.
    transducer_db.execute(f"DELETE FROM transducer.{tbl['phone']} WHERE ssn = 'TD1'")
    transducer_db.execute(f"DELETE FROM transducer.{tbl['email']} WHERE ssn = 'TD1'")
    transducer_db.execute(f"DELETE FROM transducer.{tbl['person']} WHERE ssn = 'TD1'")

    assert source_rows(transducer_db, schema_info) == []
    assert transducer_db.execute("SELECT * FROM transducer._loop").fetchall() == []


# --- Sync verification (check_sync) ---
#
# check_sync() returns the symmetric difference between the source table and
# the NATURAL LEFT OUTER JOIN reconstruction of the target tables. Empty
# result = both databases encode the same instance. It is an instance-level
# probe (a necessary condition for losslessness), not a schema-level proof.


def test_check_sync_empty_after_propagation_and_delete(transducer_db, schema_info):
    """The probe reports no diff after mixed-level inserts nor after a delete."""
    mgr = _self_manager(schema_info, ssn="Y1", empid="YMGR")
    insert_source(
        transducer_db,
        schema_info,
        ssn="Y1",
        empid="YMGR",
        name="Yan",
        hdate="YH1",
        phone="YP1",
        email="YE1",
        dept="YD",
        manager=mgr,
    )
    insert_source(
        transducer_db, schema_info, ssn="Y2", name="Yu", phone="YP2", email="YE2"
    )
    assert sync_diff(transducer_db) == []

    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn = 'Y2'"
    )
    assert sync_diff(transducer_db) == []


def test_check_sync_detects_manual_desync(transducer_db, schema_info):
    """An orphan row injected behind the triggers' back is reported, labelled
    with the side it is missing from."""
    insert_source(
        transducer_db, schema_info, ssn="Z1", name="Zoe", phone="ZP1", email="ZE1"
    )
    assert sync_diff(transducer_db) == []

    # session_replication_role=replica disables the capture triggers, so the
    # row reaches the target table without propagating to the source.
    transducer_db.execute("SET session_replication_role = replica")
    try:
        transducer_db.execute(
            f"INSERT INTO transducer.{schema_info.tables['person']} "
            f"VALUES ('ZX', 'Ghost')"
        )
    finally:
        transducer_db.execute("SET session_replication_role = DEFAULT")

    diff = sync_diff(transducer_db)
    assert any(row[0] == "missing-in-source" and row[1] == "ZX" for row in diff), (
        f"ghost row not reported: {diff}"
    )
    # The synced person Z1 must not be flagged.
    assert not any(row[1] == "Z1" for row in diff)


def test_random_round_trip_stays_in_sync(transducer_db, schema_info):
    """Seeded-random instance: mixed guard levels in, random sample deleted,
    check_sync() empty at every stage (deterministic via Random(42))."""
    rng = random.Random(42)
    # Two level-1 bosses anchor the manager INC (manager ⊆ empid/ssn) and the
    # CFD dept→manager (one fixed manager per department).
    bosses = {"DA": ("B1", "BE1"), "DB": ("B2", "BE2")}
    for dept, (ssn, empid) in bosses.items():
        insert_source(
            transducer_db,
            schema_info,
            ssn=ssn,
            empid=empid,
            name=f"Boss{ssn}",
            hdate=f"H{ssn}",
            phone=f"P{ssn}",
            email=f"M{ssn}",
        )

    people = []
    for i in range(12):
        ssn = f"R{i}"
        cols = dict(ssn=ssn, name=f"Name{i}", phone=f"Ph{i}", email=f"Em{i}")
        level = rng.choice([0, 1, 2])
        if level >= 1:
            cols.update(empid=f"RE{i}", hdate=f"RH{i}")
        if level == 2:
            dept = rng.choice(sorted(bosses))
            boss_ssn, boss_empid = bosses[dept]
            cols.update(
                dept=dept,
                manager=_self_manager(schema_info, ssn=boss_ssn, empid=boss_empid),
            )
        insert_source(transducer_db, schema_info, **cols)
        people.append(ssn)

    assert sync_diff(transducer_db) == []

    victims = rng.sample(people, 6)
    transducer_db.execute(
        f"DELETE FROM transducer.{schema_info.source_table} WHERE ssn = ANY(%s)",
        (victims,),
    )

    assert sync_diff(transducer_db) == []
    remaining = {row[0] for row in source_rows(transducer_db, schema_info)}
    assert remaining == (set(people) - set(victims)) | {"B1", "B2"}
