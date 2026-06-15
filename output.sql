-- ============================================================
--  SECTION 1: SCHEMA PREAMBLE
--  Drop and recreate the transducer schema, then create _loop,
--  the cycle-detection table that breaks the source<->target
--  feedback loop, and seed_loop(N), the client helper that
--  starts an N-statement target-side transaction. Applying this
--  script destroys any existing transducer schema.
-- ============================================================

-- Reset the target schema. CASCADE drops every object inside it, so applying
-- this script discards any prior transducer state in transducer.
DROP SCHEMA IF EXISTS transducer CASCADE;
CREATE SCHEMA transducer;

-- _loop is the cycle-detection ledger. Capture and mapping functions push a
-- signed marker into it and refuse to act while it is set, which is what stops
-- a source change from echoing back through the target (and vice versa) forever.
CREATE TABLE transducer._loop (loop_start INT NOT NULL);

-- Client protocol for target-side transactions: call seed_loop(N) before the
-- first of N INSERT/DELETE statements on target tables in the transaction.
-- The mapping fires once the ledger row count reaches the seeded value, i.e.
-- after all N statements have been captured. Source-side changes self-fire
-- and need no seeding.
CREATE FUNCTION transducer.seed_loop(change_count INT)
RETURNS VOID LANGUAGE SQL AS
$$ INSERT INTO transducer._loop VALUES (change_count + 1); $$;


-- ============================================================
--  SECTION 2: BASE TABLES
--  One CREATE TABLE per source and target relation. Primary
--  keys and NOT NULL come from the universal schema; every
--  object is _-prefixed inside the transducer schema.
-- ============================================================

-- Base table _person_source: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._person_source (
    ssn VARCHAR(100),    empid VARCHAR(100),    name VARCHAR(100),    hdate VARCHAR(100),    phone VARCHAR(100),    email VARCHAR(100),    dept VARCHAR(100),    manager VARCHAR(100),    PRIMARY KEY (ssn)
);

-- Base table _person: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._person (
    ssn VARCHAR(100),    name VARCHAR(100),    PRIMARY KEY (ssn)
);

-- Base table _personphone: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._personphone (
    ssn VARCHAR(100),    phone VARCHAR(100),    PRIMARY KEY (ssn, phone)
);

-- Base table _personemail: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._personemail (
    ssn VARCHAR(100),    email VARCHAR(100),    PRIMARY KEY (ssn, email)
);

-- Base table _employee: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._employee (
    ssn VARCHAR(100),    empid VARCHAR(100),    PRIMARY KEY (empid)
);

-- Base table _employeedate: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._employeedate (
    empid VARCHAR(100),    hdate VARCHAR(100),    PRIMARY KEY (empid)
);

-- Base table _ped: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._ped (
    ssn VARCHAR(100),    empid VARCHAR(100),    PRIMARY KEY (empid)
);

-- Base table _peddept: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._peddept (
    empid VARCHAR(100),    dept VARCHAR(100),    PRIMARY KEY (empid)
);

-- Base table _deptmanager: one relation of the decomposition. Column types,
-- nullability and the primary key are projected from the universal schema.
CREATE TABLE transducer._deptmanager (
    dept VARCHAR(100),    manager VARCHAR(100),    PRIMARY KEY (dept)
);


-- ============================================================
--  SECTION 3: REJECT UPDATES
--  UPDATE propagation is unimplemented. One BEFORE UPDATE
--  trigger per base table raises an exception so updates fail
--  loudly instead of bypassing the mapping functions; use
--  DELETE + INSERT.
-- ============================================================

-- Reject UPDATE on _person_source: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.person_source_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _person_source.
CREATE TRIGGER person_source_REJECT_UPDATE
BEFORE UPDATE ON transducer._person_source
FOR EACH ROW EXECUTE FUNCTION transducer.person_source_REJECT_UPDATE();


-- Reject UPDATE on _person: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.person_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _person.
CREATE TRIGGER person_REJECT_UPDATE
BEFORE UPDATE ON transducer._person
FOR EACH ROW EXECUTE FUNCTION transducer.person_REJECT_UPDATE();


-- Reject UPDATE on _personphone: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.personphone_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _personphone.
CREATE TRIGGER personphone_REJECT_UPDATE
BEFORE UPDATE ON transducer._personphone
FOR EACH ROW EXECUTE FUNCTION transducer.personphone_REJECT_UPDATE();


-- Reject UPDATE on _personemail: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.personemail_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _personemail.
CREATE TRIGGER personemail_REJECT_UPDATE
BEFORE UPDATE ON transducer._personemail
FOR EACH ROW EXECUTE FUNCTION transducer.personemail_REJECT_UPDATE();


-- Reject UPDATE on _employee: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.employee_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _employee.
CREATE TRIGGER employee_REJECT_UPDATE
BEFORE UPDATE ON transducer._employee
FOR EACH ROW EXECUTE FUNCTION transducer.employee_REJECT_UPDATE();


-- Reject UPDATE on _employeedate: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.employeedate_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _employeedate.
CREATE TRIGGER employeedate_REJECT_UPDATE
BEFORE UPDATE ON transducer._employeedate
FOR EACH ROW EXECUTE FUNCTION transducer.employeedate_REJECT_UPDATE();


-- Reject UPDATE on _ped: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.ped_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _ped.
CREATE TRIGGER ped_REJECT_UPDATE
BEFORE UPDATE ON transducer._ped
FOR EACH ROW EXECUTE FUNCTION transducer.ped_REJECT_UPDATE();


-- Reject UPDATE on _peddept: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.peddept_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _peddept.
CREATE TRIGGER peddept_REJECT_UPDATE
BEFORE UPDATE ON transducer._peddept
FOR EACH ROW EXECUTE FUNCTION transducer.peddept_REJECT_UPDATE();


-- Reject UPDATE on _deptmanager: UPDATE has no mapping, so this BEFORE
-- UPDATE trigger raises instead of silently bypassing the transducer.
CREATE OR REPLACE FUNCTION transducer.deptmanager_REJECT_UPDATE()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'UPDATE on %.% is not supported by this transducer; use DELETE + INSERT', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

-- Fire the guard before any row-level UPDATE reaches _deptmanager.
CREATE TRIGGER deptmanager_REJECT_UPDATE
BEFORE UPDATE ON transducer._deptmanager
FOR EACH ROW EXECUTE FUNCTION transducer.deptmanager_REJECT_UPDATE();


-- ============================================================
--  SECTION 4: INTER-TABLE INCLUSION
--  Inclusion dependencies that cross tables: a native FOREIGN
--  KEY where the referenced columns are the referenced table's
--  primary key, otherwise a DEFERRABLE constraint trigger that
--  tolerates mid-cascade violations.
-- ============================================================

-- Inter-table inclusion as a native FK: _personphone(ssn) must reference _person(ssn)
ALTER TABLE transducer._personphone ADD FOREIGN KEY (ssn) REFERENCES transducer._person (ssn);
-- Inter-table inclusion as a native FK: _personemail(ssn) must reference _person(ssn)
ALTER TABLE transducer._personemail ADD FOREIGN KEY (ssn) REFERENCES transducer._person (ssn);
-- Inter-table inclusion as a native FK: _employeedate(empid) must reference _employee(empid)
ALTER TABLE transducer._employeedate ADD FOREIGN KEY (empid) REFERENCES transducer._employee (empid);
-- Inter-table inclusion as a native FK: _peddept(empid) must reference _ped(empid)
ALTER TABLE transducer._peddept ADD FOREIGN KEY (empid) REFERENCES transducer._ped (empid);
-- Inter-table INC trigger for _deptmanager: enforces
-- _deptmanager.dept ⊆ _peddept.dept
-- when a native FK is not possible (the referenced column is not a PK).
CREATE OR REPLACE FUNCTION transducer.deptmanager_1_INC_INTER_CHECK()
RETURNS TRIGGER AS $$
BEGIN
    -- A non-NULL referencing value with no match in the referenced table fails.
    IF NEW.dept IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM transducer._peddept
        WHERE dept = NEW.dept
    ) THEN
        RAISE EXCEPTION 'INC violation: %.% = % has no match in %.%',
            TG_TABLE_NAME, 'dept', NEW.dept,
            'peddept', 'dept';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- DEFERRABLE INITIALLY DEFERRED: checked at COMMIT, so the multi-statement
-- mapping cascade can pass through intermediate violations within the txn.
CREATE CONSTRAINT TRIGGER deptmanager_1_INC_INTER_CHECK
AFTER INSERT ON transducer._deptmanager
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION transducer.deptmanager_1_INC_INTER_CHECK();

-- Inter-table inclusion as a native FK: _employee(ssn) must reference _person(ssn)
ALTER TABLE transducer._employee ADD FOREIGN KEY (ssn) REFERENCES transducer._person (ssn);
-- Inter-table inclusion as a native FK: _ped(empid) must reference _employee(empid)
ALTER TABLE transducer._ped ADD FOREIGN KEY (empid) REFERENCES transducer._employee (empid);
-- Inter-table inclusion as a native FK: _deptmanager(manager) must reference _employee(empid)
ALTER TABLE transducer._deptmanager ADD FOREIGN KEY (manager) REFERENCES transducer._employee (empid);

-- ============================================================
--  SECTION 5: CONSTRAINTS
--  Intra-table enforcement: FD/CFD checks, MVD check plus
--  grounding (re-inserting complementary tuples for 4NF), and
--  intra-table inclusion checks. All run as BEFORE/AFTER INSERT
--  triggers.
-- ============================================================

-- MVD check on _person_source: a new tuple must not imply a cross-product
-- combination that is absent from the table (4NF would require it present).
CREATE OR REPLACE FUNCTION transducer.check_person_source_mvd_check_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- EXCEPT surfaces an implied tuple that does not yet exist -> reject.
    IF EXISTS (SELECT DISTINCT r1.ssn, r2.empid, r2.name, r2.hdate, r1.phone, r1.email, r2.dept, r2.manager
        FROM transducer._person_source AS r1,
        (SELECT NEW.ssn, NEW.empid, NEW.name, NEW.hdate, NEW.phone, NEW.email, NEW.dept, NEW.manager) AS r2
        WHERE r1.ssn = r2.ssn
        EXCEPT
        SELECT *
        FROM transducer._person_source
    ) THEN
        RAISE EXCEPTION 'MVD constraint violation on person_source';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Enforce the MVD on every row inserted into _person_source.
CREATE TRIGGER person_source_mvd_check_trigger
BEFORE INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_source_mvd_check_fn();


-- MVD grounding on _person_source: the AFTER-INSERT complement to the check.
-- It inserts the complementary tuples the MVD forces, restoring 4NF.
CREATE OR REPLACE FUNCTION transducer.check_person_source_mvd_grounding_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- If the MVD implies tuples that are missing, materialise them.
    IF EXISTS (
        SELECT r1.ssn, r1.empid, r1.name, r1.hdate, NEW.phone, r1.email, r1.dept, r1.manager
        FROM transducer._person_source AS r1
        WHERE r1.ssn = NEW.ssn
        UNION
        SELECT r1.ssn, r1.empid, r1.name, r1.hdate, r1.phone, NEW.email, r1.dept, r1.manager
        FROM transducer._person_source AS r1
        WHERE r1.ssn = NEW.ssn
        EXCEPT
        (SELECT * FROM transducer._person_source)
    ) THEN
        RAISE NOTICE 'MVD grounding: tuple % leads to additional tuples', NEW;
        INSERT INTO transducer._person_source (
            SELECT r1.ssn, r1.empid, r1.name, r1.hdate, NEW.phone, r1.email, r1.dept, r1.manager
            FROM transducer._person_source AS r1
            WHERE r1.ssn = NEW.ssn
            UNION
            SELECT r1.ssn, r1.empid, r1.name, r1.hdate, r1.phone, NEW.email, r1.dept, r1.manager
            FROM transducer._person_source AS r1
            WHERE r1.ssn = NEW.ssn
            EXCEPT
            (SELECT * FROM transducer._person_source)
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Run grounding after each insert into _person_source.
CREATE TRIGGER person_source_mvd_grounding_trigger
AFTER INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_source_mvd_grounding_fn();


-- CFD check on _person_source: the conditional form of empid ->
-- hdate. where_branches enumerate every null-pattern that violates it.
CREATE OR REPLACE FUNCTION transducer.check_person_source_cfd_1_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Reject when any branch matches an existing, conflicting row.
    IF EXISTS (SELECT *
        FROM transducer._person_source AS R1,
        (SELECT NEW.ssn, NEW.empid, NEW.name, NEW.hdate, NEW.phone, NEW.email, NEW.dept, NEW.manager) AS R2
        WHERE (R2.empid IS NOT NULL AND R2.hdate IS NOT NULL AND R1.empid = R2.empid AND R1.hdate <> R2.hdate)
            OR (R2.empid IS NOT NULL AND R2.hdate IS NULL)
            OR (R2.empid IS NULL AND R2.hdate IS NOT NULL)) THEN
        RAISE EXCEPTION 'CFD violation on person_source: empid -> hdate %', NEW;
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Enforce the CFD on every row inserted into _person_source.
CREATE TRIGGER person_source_cfd_1_trigger
BEFORE INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_source_cfd_1_fn();


-- CFD check on _person_source: the conditional form of empid ->
-- dept. where_branches enumerate every null-pattern that violates it.
CREATE OR REPLACE FUNCTION transducer.check_person_source_cfd_2_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Reject when any branch matches an existing, conflicting row.
    IF EXISTS (SELECT *
        FROM transducer._person_source AS R1,
        (SELECT NEW.ssn, NEW.empid, NEW.name, NEW.hdate, NEW.phone, NEW.email, NEW.dept, NEW.manager) AS R2
        WHERE (R2.empid IS NOT NULL AND R2.hdate IS NOT NULL AND R2.dept IS NOT NULL AND R2.manager IS NOT NULL AND R1.empid = R2.empid AND R1.dept <> R2.dept)
            OR (R2.empid IS NULL AND R2.dept IS NOT NULL)
            OR (R2.empid IS NULL AND R2.manager IS NOT NULL)
            OR (R2.empid IS NOT NULL AND R2.dept IS NOT NULL AND R2.manager IS NULL)
            OR (R2.empid IS NOT NULL AND R2.dept IS NULL AND R2.manager IS NOT NULL)) THEN
        RAISE EXCEPTION 'CFD violation on person_source: empid -> dept %', NEW;
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Enforce the CFD on every row inserted into _person_source.
CREATE TRIGGER person_source_cfd_2_trigger
BEFORE INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_source_cfd_2_fn();


-- CFD check on _person_source: the conditional form of dept ->
-- manager. where_branches enumerate every null-pattern that violates it.
CREATE OR REPLACE FUNCTION transducer.check_person_source_cfd_3_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Reject when any branch matches an existing, conflicting row.
    IF EXISTS (SELECT *
        FROM transducer._person_source AS R1,
        (SELECT NEW.ssn, NEW.empid, NEW.name, NEW.hdate, NEW.phone, NEW.email, NEW.dept, NEW.manager) AS R2
        WHERE (R2.empid IS NOT NULL AND R2.hdate IS NOT NULL AND R2.dept IS NOT NULL AND R2.manager IS NOT NULL AND R1.dept = R2.dept AND R1.manager <> R2.manager)
            OR (R2.dept IS NOT NULL AND R2.manager IS NULL)
            OR (R2.dept IS NULL AND R2.manager IS NOT NULL)) THEN
        RAISE EXCEPTION 'CFD violation on person_source: dept -> manager %', NEW;
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Enforce the CFD on every row inserted into _person_source.
CREATE TRIGGER person_source_cfd_3_trigger
BEFORE INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_source_cfd_3_fn();


-- Intra-table INC on _person_source: NEW.manager must already appear in
-- _person_source.empid (NULL and self-reference are exempt).
CREATE OR REPLACE FUNCTION transducer.check_person_source_inc_1_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- NULL references nothing.
    IF (NEW.manager IS NULL) THEN
        RETURN NEW;
    END IF;
    -- A row may reference its own key.
    IF (NEW.manager = NEW.ssn) THEN
        RETURN NEW;
    END IF;
    -- Otherwise the value must already exist in the referenced column.
    IF EXISTS (SELECT DISTINCT NEW.manager
        FROM transducer._person_source
        EXCEPT (
            SELECT empid AS manager
            FROM transducer._person_source
            UNION
            SELECT NEW.ssn AS manager
        )) THEN
        RAISE EXCEPTION 'INC violation: person_source.manager ⊆ person_source.empid';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Enforce the inclusion on every row inserted into _person_source.
CREATE TRIGGER person_source_inc_1_trigger
BEFORE INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_source_inc_1_fn();


-- ============================================================
--  SECTION 6: CHANGE TRACKING
--  Per table: a shadow _INSERT/_DELETE table plus AFTER
--  INSERT/DELETE capture triggers. Each change is staged for
--  propagation unless the loop guard shows a sync is already in
--  flight.
-- ============================================================

-- Shadow of _person_source: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._person_source_INSERT AS
SELECT * FROM transducer._person_source
WHERE 1<>1;


-- Capture (source): fires on every INSERT to _person_source and stages the
-- affected row in _person_source_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.source_person_source_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of -1 means a source-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._person_source_INSERT VALUES(NEW.ssn, NEW.empid, NEW.name, NEW.hdate, NEW.phone, NEW.email, NEW.dept, NEW.manager);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _person_source.
CREATE TRIGGER source_person_source_INSERT_trigger
AFTER INSERT ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.source_person_source_INSERT_fn();


-- Shadow of _person_source: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._person_source_DELETE AS
SELECT * FROM transducer._person_source
WHERE 1<>1;


-- Capture (source): fires on every DELETE to _person_source and stages the
-- affected row in _person_source_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.source_person_source_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of -1 means a source-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._person_source_DELETE VALUES(OLD.ssn, OLD.empid, OLD.name, OLD.hdate, OLD.phone, OLD.email, OLD.dept, OLD.manager);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _person_source.
CREATE TRIGGER source_person_source_DELETE_trigger
AFTER DELETE ON transducer._person_source
FOR EACH ROW
EXECUTE FUNCTION transducer.source_person_source_DELETE_fn();


-- Shadow of _person: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._person_INSERT AS
SELECT * FROM transducer._person
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _person and stages the
-- affected row in _person_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_person_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._person_INSERT VALUES(NEW.ssn, NEW.name);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _person.
CREATE TRIGGER target_person_INSERT_trigger
AFTER INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_INSERT_fn();


-- Shadow of _person: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._person_DELETE AS
SELECT * FROM transducer._person
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _person and stages the
-- affected row in _person_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_person_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._person_DELETE VALUES(OLD.ssn, OLD.name);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _person.
CREATE TRIGGER target_person_DELETE_trigger
AFTER DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_DELETE_fn();


-- Shadow of _personphone: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._personphone_INSERT AS
SELECT * FROM transducer._personphone
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _personphone and stages the
-- affected row in _personphone_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_personphone_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._personphone_INSERT VALUES(NEW.ssn, NEW.phone);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _personphone.
CREATE TRIGGER target_personphone_INSERT_trigger
AFTER INSERT ON transducer._personphone
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personphone_INSERT_fn();


-- Shadow of _personphone: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._personphone_DELETE AS
SELECT * FROM transducer._personphone
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _personphone and stages the
-- affected row in _personphone_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_personphone_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._personphone_DELETE VALUES(OLD.ssn, OLD.phone);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _personphone.
CREATE TRIGGER target_personphone_DELETE_trigger
AFTER DELETE ON transducer._personphone
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personphone_DELETE_fn();


-- Shadow of _personemail: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._personemail_INSERT AS
SELECT * FROM transducer._personemail
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _personemail and stages the
-- affected row in _personemail_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_personemail_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._personemail_INSERT VALUES(NEW.ssn, NEW.email);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _personemail.
CREATE TRIGGER target_personemail_INSERT_trigger
AFTER INSERT ON transducer._personemail
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personemail_INSERT_fn();


-- Shadow of _personemail: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._personemail_DELETE AS
SELECT * FROM transducer._personemail
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _personemail and stages the
-- affected row in _personemail_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_personemail_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._personemail_DELETE VALUES(OLD.ssn, OLD.email);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _personemail.
CREATE TRIGGER target_personemail_DELETE_trigger
AFTER DELETE ON transducer._personemail
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personemail_DELETE_fn();


-- Shadow of _employee: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._employee_INSERT AS
SELECT * FROM transducer._employee
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _employee and stages the
-- affected row in _employee_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_employee_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._employee_INSERT VALUES(NEW.ssn, NEW.empid);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _employee.
CREATE TRIGGER target_employee_INSERT_trigger
AFTER INSERT ON transducer._employee
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employee_INSERT_fn();


-- Shadow of _employee: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._employee_DELETE AS
SELECT * FROM transducer._employee
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _employee and stages the
-- affected row in _employee_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_employee_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._employee_DELETE VALUES(OLD.ssn, OLD.empid);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _employee.
CREATE TRIGGER target_employee_DELETE_trigger
AFTER DELETE ON transducer._employee
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employee_DELETE_fn();


-- Shadow of _employeedate: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._employeedate_INSERT AS
SELECT * FROM transducer._employeedate
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _employeedate and stages the
-- affected row in _employeedate_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_employeedate_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._employeedate_INSERT VALUES(NEW.empid, NEW.hdate);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _employeedate.
CREATE TRIGGER target_employeedate_INSERT_trigger
AFTER INSERT ON transducer._employeedate
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employeedate_INSERT_fn();


-- Shadow of _employeedate: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._employeedate_DELETE AS
SELECT * FROM transducer._employeedate
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _employeedate and stages the
-- affected row in _employeedate_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_employeedate_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._employeedate_DELETE VALUES(OLD.empid, OLD.hdate);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _employeedate.
CREATE TRIGGER target_employeedate_DELETE_trigger
AFTER DELETE ON transducer._employeedate
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employeedate_DELETE_fn();


-- Shadow of _ped: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._ped_INSERT AS
SELECT * FROM transducer._ped
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _ped and stages the
-- affected row in _ped_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_ped_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._ped_INSERT VALUES(NEW.ssn, NEW.empid);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _ped.
CREATE TRIGGER target_ped_INSERT_trigger
AFTER INSERT ON transducer._ped
FOR EACH ROW
EXECUTE FUNCTION transducer.target_ped_INSERT_fn();


-- Shadow of _ped: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._ped_DELETE AS
SELECT * FROM transducer._ped
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _ped and stages the
-- affected row in _ped_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_ped_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._ped_DELETE VALUES(OLD.ssn, OLD.empid);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _ped.
CREATE TRIGGER target_ped_DELETE_trigger
AFTER DELETE ON transducer._ped
FOR EACH ROW
EXECUTE FUNCTION transducer.target_ped_DELETE_fn();


-- Shadow of _peddept: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._peddept_INSERT AS
SELECT * FROM transducer._peddept
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _peddept and stages the
-- affected row in _peddept_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_peddept_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._peddept_INSERT VALUES(NEW.empid, NEW.dept);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _peddept.
CREATE TRIGGER target_peddept_INSERT_trigger
AFTER INSERT ON transducer._peddept
FOR EACH ROW
EXECUTE FUNCTION transducer.target_peddept_INSERT_fn();


-- Shadow of _peddept: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._peddept_DELETE AS
SELECT * FROM transducer._peddept
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _peddept and stages the
-- affected row in _peddept_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_peddept_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._peddept_DELETE VALUES(OLD.empid, OLD.dept);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _peddept.
CREATE TRIGGER target_peddept_DELETE_trigger
AFTER DELETE ON transducer._peddept
FOR EACH ROW
EXECUTE FUNCTION transducer.target_peddept_DELETE_fn();


-- Shadow of _deptmanager: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT changes awaiting propagation.
CREATE TABLE transducer._deptmanager_INSERT AS
SELECT * FROM transducer._deptmanager
WHERE 1<>1;


-- Capture (target): fires on every INSERT to _deptmanager and stages the
-- affected row in _deptmanager_INSERT for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_deptmanager_INSERT_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._deptmanager_INSERT VALUES(NEW.dept, NEW.manager);
        RETURN NEW;
    END IF;
END;
$$;


-- Wire the capture function to AFTER INSERT on _deptmanager.
CREATE TRIGGER target_deptmanager_INSERT_trigger
AFTER INSERT ON transducer._deptmanager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_deptmanager_INSERT_fn();


-- Shadow of _deptmanager: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE changes awaiting propagation.
CREATE TABLE transducer._deptmanager_DELETE AS
SELECT * FROM transducer._deptmanager
WHERE 1<>1;


-- Capture (target): fires on every DELETE to _deptmanager and stages the
-- affected row in _deptmanager_DELETE for the join layer to pick up,
-- unless the loop guard shows this change is itself the echo of a sync.
CREATE OR REPLACE FUNCTION transducer.target_deptmanager_DELETE_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- loop guard: a marker of 1 means a target-side sync is already
    -- in flight, so skip capture and let the in-progress cascade unwind.
    IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
        RETURN NULL;
    ELSE
        -- genuine change: stage the row so the JOIN layer can rebuild tuples.
        INSERT INTO transducer._deptmanager_DELETE VALUES(OLD.dept, OLD.manager);
        RETURN OLD;
    END IF;
END;
$$;


-- Wire the capture function to AFTER DELETE on _deptmanager.
CREATE TRIGGER target_deptmanager_DELETE_trigger
AFTER DELETE ON transducer._deptmanager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_deptmanager_DELETE_fn();


-- ============================================================
--  SECTION 7: JOIN STAGING
--  Natural-join the tracked per-table changes back into
--  universal tuples in _..._JOIN tables, writing to _loop for
--  cycle detection. This bridges per-table deltas to the
--  universal relation the mapping reads.
-- ============================================================

-- Shadow of _person_source: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._person_source_INSERT_JOIN AS
SELECT * FROM transducer._person_source
WHERE 1<>1;


-- Join (source): once captured INSERT rows land in _person_source_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.source_person_source_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _person_source alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_source_INSERT
    );

    -- Stamp the loop ledger (1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (1);
    INSERT INTO transducer._person_source_INSERT_JOIN (SELECT ssn, empid, name, hdate, phone, email, dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER source_person_source_INSERT_JOIN_trigger
AFTER INSERT ON transducer._person_source_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.source_person_source_INSERT_JOIN_fn();


-- Shadow of _person_source: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._person_source_DELETE_JOIN AS
SELECT * FROM transducer._person_source
WHERE 1<>1;


-- Join (source): once captured DELETE rows land in _person_source_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.source_person_source_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _person_source alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_source_DELETE
    );

    -- Stamp the loop ledger (1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (1);
    INSERT INTO transducer._person_source_DELETE_JOIN (SELECT ssn, empid, name, hdate, phone, email, dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER source_person_source_DELETE_JOIN_trigger
AFTER INSERT ON transducer._person_source_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.source_person_source_DELETE_JOIN_fn();


-- Shadow of _person: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._person_INSERT_JOIN AS
SELECT * FROM transducer._person
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _person_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_person_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _person alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_INSERT
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_person_INSERT_JOIN_trigger
AFTER INSERT ON transducer._person_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_INSERT_JOIN_fn();


-- Shadow of _person: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._person_DELETE_JOIN AS
SELECT * FROM transducer._person
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _person_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_person_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _person alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_DELETE
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_person_DELETE_JOIN_trigger
AFTER INSERT ON transducer._person_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_DELETE_JOIN_fn();


-- Shadow of _personphone: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._personphone_INSERT_JOIN AS
SELECT * FROM transducer._personphone
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _personphone_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_personphone_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _personphone alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._personphone_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_personphone_INSERT_JOIN_trigger
AFTER INSERT ON transducer._personphone_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personphone_INSERT_JOIN_fn();


-- Shadow of _personphone: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._personphone_DELETE_JOIN AS
SELECT * FROM transducer._personphone
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _personphone_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_personphone_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _personphone alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._personphone_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_personphone_DELETE_JOIN_trigger
AFTER INSERT ON transducer._personphone_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personphone_DELETE_JOIN_fn();


-- Shadow of _personemail: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._personemail_INSERT_JOIN AS
SELECT * FROM transducer._personemail
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _personemail_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_personemail_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _personemail alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._personemail_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_personemail_INSERT_JOIN_trigger
AFTER INSERT ON transducer._personemail_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personemail_INSERT_JOIN_fn();


-- Shadow of _personemail: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._personemail_DELETE_JOIN AS
SELECT * FROM transducer._personemail
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _personemail_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_personemail_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _personemail alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._personemail_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_personemail_DELETE_JOIN_trigger
AFTER INSERT ON transducer._personemail_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_personemail_DELETE_JOIN_fn();


-- Shadow of _employee: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._employee_INSERT_JOIN AS
SELECT * FROM transducer._employee
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _employee_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_employee_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _employee alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._employee_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_employee_INSERT_JOIN_trigger
AFTER INSERT ON transducer._employee_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employee_INSERT_JOIN_fn();


-- Shadow of _employee: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._employee_DELETE_JOIN AS
SELECT * FROM transducer._employee
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _employee_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_employee_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _employee alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._employee_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_employee_DELETE_JOIN_trigger
AFTER INSERT ON transducer._employee_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employee_DELETE_JOIN_fn();


-- Shadow of _employeedate: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._employeedate_INSERT_JOIN AS
SELECT * FROM transducer._employeedate
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _employeedate_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_employeedate_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _employeedate alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._employeedate_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_employeedate_INSERT_JOIN_trigger
AFTER INSERT ON transducer._employeedate_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employeedate_INSERT_JOIN_fn();


-- Shadow of _employeedate: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._employeedate_DELETE_JOIN AS
SELECT * FROM transducer._employeedate
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _employeedate_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_employeedate_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _employeedate alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._employeedate_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_employeedate_DELETE_JOIN_trigger
AFTER INSERT ON transducer._employeedate_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_employeedate_DELETE_JOIN_fn();


-- Shadow of _ped: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._ped_INSERT_JOIN AS
SELECT * FROM transducer._ped
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _ped_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_ped_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _ped alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._ped_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_ped_INSERT_JOIN_trigger
AFTER INSERT ON transducer._ped_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_ped_INSERT_JOIN_fn();


-- Shadow of _ped: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._ped_DELETE_JOIN AS
SELECT * FROM transducer._ped
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _ped_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_ped_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _ped alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._ped_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_ped_DELETE_JOIN_trigger
AFTER INSERT ON transducer._ped_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_ped_DELETE_JOIN_fn();


-- Shadow of _peddept: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._peddept_INSERT_JOIN AS
SELECT * FROM transducer._peddept
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _peddept_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_peddept_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _peddept alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._peddept_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_peddept_INSERT_JOIN_trigger
AFTER INSERT ON transducer._peddept_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_peddept_INSERT_JOIN_fn();


-- Shadow of _peddept: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._peddept_DELETE_JOIN AS
SELECT * FROM transducer._peddept
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _peddept_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_peddept_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _peddept alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._peddept_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_peddept_DELETE_JOIN_trigger
AFTER INSERT ON transducer._peddept_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_peddept_DELETE_JOIN_fn();


-- Shadow of _deptmanager: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _INSERT_JOIN changes awaiting propagation.
CREATE TABLE transducer._deptmanager_INSERT_JOIN AS
SELECT * FROM transducer._deptmanager
WHERE 1<>1;


-- Join (target): once captured INSERT rows land in _deptmanager_INSERT,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._INSERT_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_deptmanager_INSERT_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _deptmanager alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._deptmanager_INSERT
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
    );

    INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_INSERT_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_INSERT_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_INSERT_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_INSERT_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_INSERT_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured INSERT row lands in the stage.
CREATE TRIGGER target_deptmanager_INSERT_JOIN_trigger
AFTER INSERT ON transducer._deptmanager_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer.target_deptmanager_INSERT_JOIN_fn();


-- Shadow of _deptmanager: an empty clone (WHERE 1<>1 copies the column
-- layout but no rows) that stages _DELETE_JOIN changes awaiting propagation.
CREATE TABLE transducer._deptmanager_DELETE_JOIN AS
SELECT * FROM transducer._deptmanager
WHERE 1<>1;


-- Join (target): once captured DELETE rows land in _deptmanager_DELETE,
-- reassemble full universal tuples by natural-joining this delta against the
-- sibling tables, then fan the result out into every _..._DELETE_JOIN stage.
CREATE OR REPLACE FUNCTION transducer.target_deptmanager_DELETE_JOIN_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Scratch table holding the reconstructed universal tuples.
    DROP TABLE IF EXISTS temp_table;
    CREATE TEMPORARY TABLE temp_table(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    -- Natural-join the captured delta with the sibling tables to recover the
    -- universal attributes that _deptmanager alone does not carry.
    INSERT INTO temp_table (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._deptmanager_DELETE
        NATURAL LEFT OUTER JOIN transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
    );

    INSERT INTO transducer._person_DELETE_JOIN (SELECT ssn, name FROM temp_table);
    INSERT INTO transducer._personphone_DELETE_JOIN (SELECT ssn, phone FROM temp_table);
    INSERT INTO transducer._personemail_DELETE_JOIN (SELECT ssn, email FROM temp_table);
    INSERT INTO transducer._employee_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._employeedate_DELETE_JOIN (SELECT empid, hdate FROM temp_table);
    INSERT INTO transducer._ped_DELETE_JOIN (SELECT ssn, empid FROM temp_table);
    INSERT INTO transducer._peddept_DELETE_JOIN (SELECT empid, dept FROM temp_table);
    -- Stamp the loop ledger (-1) so the mapping fires exactly once.
    INSERT INTO transducer._loop VALUES (-1);
    INSERT INTO transducer._deptmanager_DELETE_JOIN (SELECT dept, manager FROM temp_table);

    DELETE FROM temp_table;
    DROP TABLE temp_table;
    RETURN NEW;
END;
$$;


-- Fire the join function when a captured DELETE row lands in the stage.
CREATE TRIGGER target_deptmanager_DELETE_JOIN_trigger
AFTER INSERT ON transducer._deptmanager_DELETE
FOR EACH ROW
EXECUTE FUNCTION transducer.target_deptmanager_DELETE_JOIN_fn();


-- ============================================================
--  SECTION 8: BIDIRECTIONAL MAPPING
--  The four mapping functions (SOURCE/TARGET x INSERT/DELETE).
--  Each reads the JOIN staging, projects universal tuples into
--  the opposite context, and clears tracking state. Inserts use
--  containment pruning and null-pattern filtering; source-side
--  deletes sweep each target table for rows no remaining source
--  row still derives.
-- ============================================================

-- SOURCE_INSERT_FN: project staged universal tuples into the opposite context.
-- Fires once the JOIN stage is fully populated; clears tracking + _loop after.
CREATE OR REPLACE FUNCTION transducer.SOURCE_INSERT_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Loop guard: run only when the _loop marker magnitude equals the marker
    -- count, i.e. every join-stage trigger has fired for this one sync.
    IF NOT EXISTS (SELECT * FROM transducer._loop,
        (SELECT COUNT(*) AS rc_value FROM transducer._loop) AS row_count
        WHERE ABS(loop_start) = row_count.rc_value) THEN
        RETURN NULL;
    END IF;

    -- Direct path (no temp join): project straight from the JOIN stage, with a
    -- guard so a target table is filled only when its guard attributes are set.
    INSERT INTO transducer._person (SELECT DISTINCT ssn, name
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL)
        ON CONFLICT (ssn) DO NOTHING;
    INSERT INTO transducer._personphone (SELECT DISTINCT ssn, phone
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND phone IS NOT NULL)
        ON CONFLICT (ssn, phone) DO NOTHING;
    INSERT INTO transducer._personemail (SELECT DISTINCT ssn, email
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND email IS NOT NULL)
        ON CONFLICT (ssn, email) DO NOTHING;
    IF EXISTS (SELECT * FROM transducer._person_source_INSERT_JOIN
              WHERE empid IS NOT NULL AND hdate IS NOT NULL) THEN
    INSERT INTO transducer._employee (SELECT DISTINCT ssn, empid
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND empid IS NOT NULL)
        ON CONFLICT (empid) DO NOTHING;
    END IF;
    IF EXISTS (SELECT * FROM transducer._person_source_INSERT_JOIN
              WHERE empid IS NOT NULL AND hdate IS NOT NULL) THEN
    INSERT INTO transducer._employeedate (SELECT DISTINCT empid, hdate
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND empid IS NOT NULL)
        ON CONFLICT (empid) DO NOTHING;
    END IF;
    IF EXISTS (SELECT * FROM transducer._person_source_INSERT_JOIN
              WHERE empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NOT NULL AND manager IS NOT NULL) THEN
    INSERT INTO transducer._ped (SELECT DISTINCT ssn, empid
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND empid IS NOT NULL)
        ON CONFLICT (empid) DO NOTHING;
    END IF;
    IF EXISTS (SELECT * FROM transducer._person_source_INSERT_JOIN
              WHERE empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NOT NULL AND manager IS NOT NULL) THEN
    INSERT INTO transducer._peddept (SELECT DISTINCT empid, dept
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND empid IS NOT NULL)
        ON CONFLICT (empid) DO NOTHING;
    END IF;
    IF EXISTS (SELECT * FROM transducer._person_source_INSERT_JOIN
              WHERE empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NOT NULL AND manager IS NOT NULL) THEN
    INSERT INTO transducer._deptmanager (SELECT DISTINCT dept, manager
        FROM transducer._person_source_INSERT_JOIN
        WHERE ssn IS NOT NULL AND dept IS NOT NULL)
        ON CONFLICT (dept) DO NOTHING;
    END IF;

    -- Clear the tracking + join stages and the loop ledger for the next change.
    DELETE FROM transducer._person_source_INSERT;
    DELETE FROM transducer._person_source_INSERT_JOIN;
    DELETE FROM transducer._loop;
    RETURN NEW;
END;
$$;


-- Run SOURCE_INSERT_FN when reassembled tuples land in _person_source_INSERT_JOIN.
CREATE TRIGGER SOURCE_INSERT_FN_trigger_person_source
AFTER INSERT ON transducer._person_source_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.SOURCE_INSERT_FN();


-- TARGET_INSERT_FN: project staged universal tuples into the opposite context.
-- Fires once the JOIN stage is fully populated; clears tracking + _loop after.
CREATE OR REPLACE FUNCTION transducer.TARGET_INSERT_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Loop guard: run only when the _loop marker magnitude equals the marker
    -- count, i.e. every join-stage trigger has fired for this one sync.
    IF NOT EXISTS (SELECT * FROM transducer._loop,
        (SELECT COUNT(*) AS rc_value FROM transducer._loop) AS row_count
        WHERE ABS(loop_start) = row_count.rc_value) THEN
        RETURN NULL;
    END IF;

    -- Reassemble distinct universal tuples from the JOIN stages.
    DROP TABLE IF EXISTS temp_table_join;
    CREATE TEMPORARY TABLE temp_table_join(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    INSERT INTO temp_table_join (
        SELECT DISTINCT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._personphone_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._personemail_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._employee_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._employeedate_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._ped_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._peddept_INSERT_JOIN
        NATURAL LEFT OUTER JOIN transducer._deptmanager_INSERT_JOIN
        WHERE ssn IS NOT NULL AND name IS NOT NULL AND phone IS NOT NULL AND email IS NOT NULL AND ((empid IS NULL AND hdate IS NULL AND dept IS NULL AND manager IS NULL) OR (empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NULL AND manager IS NULL) OR (empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NOT NULL AND manager IS NOT NULL))
    );

    -- Tuple containment: keep only most informative tuples
    IF EXISTS (SELECT * FROM temp_table_join WHERE empid IS NOT NULL AND hdate IS NOT NULL) THEN
        DELETE FROM temp_table_join t_poor
        WHERE t_poor.empid IS NULL AND t_poor.hdate IS NULL
        AND EXISTS (
            SELECT 1 FROM temp_table_join t_rich
            WHERE t_rich.ssn = t_poor.ssn
            AND t_rich.empid IS NOT NULL AND t_rich.hdate IS NOT NULL
        );
    END IF;
    IF EXISTS (SELECT * FROM temp_table_join WHERE empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NOT NULL AND manager IS NOT NULL) THEN
        DELETE FROM temp_table_join t_poor
        WHERE t_poor.dept IS NULL AND t_poor.manager IS NULL
        AND EXISTS (
            SELECT 1 FROM temp_table_join t_rich
            WHERE t_rich.ssn = t_poor.ssn
            AND t_rich.empid IS NOT NULL AND t_rich.hdate IS NOT NULL AND t_rich.dept IS NOT NULL AND t_rich.manager IS NOT NULL
        );
    END IF;

    -- Insert each projected relation; ON CONFLICT DO NOTHING keeps it idempotent.
    INSERT INTO transducer._person_source (SELECT ssn, empid, name, hdate, phone, email, dept, manager FROM temp_table_join)
        ON CONFLICT (ssn) DO NOTHING;
    -- Stamp _loop so the opposite-direction capture treats these as echoes.
    INSERT INTO transducer._loop VALUES (-1);


    -- Clear the tracking + join stages and the loop ledger for the next change.
    DELETE FROM transducer._person_INSERT;
    DELETE FROM transducer._person_INSERT_JOIN;
    DELETE FROM transducer._personphone_INSERT;
    DELETE FROM transducer._personphone_INSERT_JOIN;
    DELETE FROM transducer._personemail_INSERT;
    DELETE FROM transducer._personemail_INSERT_JOIN;
    DELETE FROM transducer._employee_INSERT;
    DELETE FROM transducer._employee_INSERT_JOIN;
    DELETE FROM transducer._employeedate_INSERT;
    DELETE FROM transducer._employeedate_INSERT_JOIN;
    DELETE FROM transducer._ped_INSERT;
    DELETE FROM transducer._ped_INSERT_JOIN;
    DELETE FROM transducer._peddept_INSERT;
    DELETE FROM transducer._peddept_INSERT_JOIN;
    DELETE FROM transducer._deptmanager_INSERT;
    DELETE FROM transducer._deptmanager_INSERT_JOIN;
    DELETE FROM transducer._loop;
    DELETE FROM temp_table_join;
    DROP TABLE temp_table_join;
    RETURN NEW;
END;
$$;


-- Run TARGET_INSERT_FN when reassembled tuples land in _person_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_person
AFTER INSERT ON transducer._person_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _personphone_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_personphone
AFTER INSERT ON transducer._personphone_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _personemail_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_personemail
AFTER INSERT ON transducer._personemail_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _employee_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_employee
AFTER INSERT ON transducer._employee_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _employeedate_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_employeedate
AFTER INSERT ON transducer._employeedate_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _ped_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_ped
AFTER INSERT ON transducer._ped_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _peddept_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_peddept
AFTER INSERT ON transducer._peddept_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- Run TARGET_INSERT_FN when reassembled tuples land in _deptmanager_INSERT_JOIN.
CREATE TRIGGER TARGET_INSERT_FN_trigger_deptmanager
AFTER INSERT ON transducer._deptmanager_INSERT_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_INSERT_FN();


-- SOURCE_DELETE_FN: propagate a DELETE into the opposite context, but only where no
-- surviving tuple still depends on the removed data (independence checks below).
CREATE OR REPLACE FUNCTION transducer.SOURCE_DELETE_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Loop guard: act only on the firing that completes this sync.
    IF NOT EXISTS (SELECT * FROM transducer._loop,
        (SELECT COUNT(*) AS rc_value FROM transducer._loop) AS row_count
        WHERE loop_start = row_count.rc_value) THEN
        RETURN NULL;
    END IF;

    -- Orphan sweep: a target row survives only while some remaining source row
    -- still projects onto it (NULL-safe match on every column, witness must
    -- satisfy the table's guard). Children sweep before parents so the FK
    -- order is respected, and rows still derived by another source key are
    -- never touched.
    DELETE FROM transducer._deptmanager AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.dept IS NOT DISTINCT FROM t.dept AND s.manager IS NOT DISTINCT FROM t.manager AND s.empid IS NOT NULL AND s.hdate IS NOT NULL AND s.dept IS NOT NULL AND s.manager IS NOT NULL);
    DELETE FROM transducer._peddept AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.empid IS NOT DISTINCT FROM t.empid AND s.dept IS NOT DISTINCT FROM t.dept AND s.empid IS NOT NULL AND s.hdate IS NOT NULL AND s.dept IS NOT NULL AND s.manager IS NOT NULL);
    DELETE FROM transducer._ped AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.ssn IS NOT DISTINCT FROM t.ssn AND s.empid IS NOT DISTINCT FROM t.empid AND s.empid IS NOT NULL AND s.hdate IS NOT NULL AND s.dept IS NOT NULL AND s.manager IS NOT NULL);
    DELETE FROM transducer._employeedate AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.empid IS NOT DISTINCT FROM t.empid AND s.hdate IS NOT DISTINCT FROM t.hdate AND s.empid IS NOT NULL AND s.hdate IS NOT NULL);
    DELETE FROM transducer._employee AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.ssn IS NOT DISTINCT FROM t.ssn AND s.empid IS NOT DISTINCT FROM t.empid AND s.empid IS NOT NULL AND s.hdate IS NOT NULL);
    DELETE FROM transducer._personemail AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.ssn IS NOT DISTINCT FROM t.ssn AND s.email IS NOT DISTINCT FROM t.email);
    DELETE FROM transducer._personphone AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.ssn IS NOT DISTINCT FROM t.ssn AND s.phone IS NOT DISTINCT FROM t.phone);
    DELETE FROM transducer._person AS t
        WHERE NOT EXISTS (SELECT 1 FROM transducer._person_source AS s
            WHERE s.ssn IS NOT DISTINCT FROM t.ssn AND s.name IS NOT DISTINCT FROM t.name);

    -- Clear the tracking + join stages and the loop ledger for the next change.
    DELETE FROM transducer._person_source_DELETE;
    DELETE FROM transducer._person_source_DELETE_JOIN;
    DELETE FROM transducer._loop;
    RETURN NEW;
END;
$$;


-- Run SOURCE_DELETE_FN when reassembled tuples land in _person_source_DELETE_JOIN.
CREATE TRIGGER SOURCE_DELETE_FN_trigger_person_source
AFTER INSERT ON transducer._person_source_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.SOURCE_DELETE_FN();


-- TARGET_DELETE_FN: propagate a DELETE into the opposite context, but only where no
-- surviving tuple still depends on the removed data (independence checks below).
CREATE OR REPLACE FUNCTION transducer.TARGET_DELETE_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
    -- Loop guard: act only on the firing that completes this sync.
    IF NOT EXISTS (SELECT * FROM transducer._loop,
        (SELECT COUNT(*) AS rc_value FROM transducer._loop) AS row_count
        WHERE ABS(loop_start) = row_count.rc_value) THEN
        RETURN NULL;
    END IF;

    -- Reassemble the universal tuples being deleted from the JOIN stages.
    DROP TABLE IF EXISTS temp_table_join;
    CREATE TEMPORARY TABLE temp_table_join(
        ssn VARCHAR(100),
        empid VARCHAR(100),
        name VARCHAR(100),
        hdate VARCHAR(100),
        phone VARCHAR(100),
        email VARCHAR(100),
        dept VARCHAR(100),
        manager VARCHAR(100)
    );

    INSERT INTO temp_table_join (
        SELECT DISTINCT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._personphone_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._personemail_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._employee_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._employeedate_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._ped_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._peddept_DELETE_JOIN
        NATURAL LEFT OUTER JOIN transducer._deptmanager_DELETE_JOIN
        WHERE ssn IS NOT NULL AND name IS NOT NULL AND phone IS NOT NULL AND email IS NOT NULL AND ((empid IS NULL AND hdate IS NULL AND dept IS NULL AND manager IS NULL) OR (empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NULL AND manager IS NULL) OR (empid IS NOT NULL AND hdate IS NOT NULL AND dept IS NOT NULL AND manager IS NOT NULL))
    );

    -- Delete the main relation, then each dependent relation only if no other
    -- surviving universal tuple still requires it (the EXCEPT independence test).
    DELETE FROM transducer._person_source WHERE (ssn) IN (SELECT ssn FROM temp_table_join);


    -- Clear the tracking + join stages and the loop ledger for the next change.
    DELETE FROM transducer._person_DELETE;
    DELETE FROM transducer._person_DELETE_JOIN;
    DELETE FROM transducer._personphone_DELETE;
    DELETE FROM transducer._personphone_DELETE_JOIN;
    DELETE FROM transducer._personemail_DELETE;
    DELETE FROM transducer._personemail_DELETE_JOIN;
    DELETE FROM transducer._employee_DELETE;
    DELETE FROM transducer._employee_DELETE_JOIN;
    DELETE FROM transducer._employeedate_DELETE;
    DELETE FROM transducer._employeedate_DELETE_JOIN;
    DELETE FROM transducer._ped_DELETE;
    DELETE FROM transducer._ped_DELETE_JOIN;
    DELETE FROM transducer._peddept_DELETE;
    DELETE FROM transducer._peddept_DELETE_JOIN;
    DELETE FROM transducer._deptmanager_DELETE;
    DELETE FROM transducer._deptmanager_DELETE_JOIN;
    DELETE FROM transducer._loop;
    DELETE FROM temp_table_join;
    DROP TABLE temp_table_join;
    RETURN NEW;
END;
$$;


-- Run TARGET_DELETE_FN when reassembled tuples land in _person_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_person
AFTER INSERT ON transducer._person_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _personphone_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_personphone
AFTER INSERT ON transducer._personphone_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _personemail_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_personemail
AFTER INSERT ON transducer._personemail_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _employee_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_employee
AFTER INSERT ON transducer._employee_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _employeedate_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_employeedate
AFTER INSERT ON transducer._employeedate_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _ped_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_ped
AFTER INSERT ON transducer._ped_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _peddept_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_peddept
AFTER INSERT ON transducer._peddept_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- Run TARGET_DELETE_FN when reassembled tuples land in _deptmanager_DELETE_JOIN.
CREATE TRIGGER TARGET_DELETE_FN_trigger_deptmanager
AFTER INSERT ON transducer._deptmanager_DELETE_JOIN
FOR EACH ROW
EXECUTE FUNCTION transducer.TARGET_DELETE_FN();


-- ============================================================
--  SECTION 9: SYNC VERIFICATION
--  check_sync() reconstructs the universal relation from the
--  target tables and returns its symmetric difference against
--  the source table. An empty result means both databases
--  encode the same instance; rows are labelled with the side
--  they are missing from.
-- ============================================================

-- check_sync(): instance-level sync probe. Reconstructs the universal
-- relation from the target tables (NATURAL LEFT OUTER JOIN in mapping order)
-- and returns its symmetric difference against the source table. An empty
-- result means both databases currently encode the same instance; each
-- returned row is labelled with the side it is missing from. EXCEPT compares
-- NULLs as equal, so partially-NULL (URA) tuples diff correctly. Note: an
-- empty diff is a necessary condition for losslessness, not a proof of it.
CREATE OR REPLACE FUNCTION transducer.check_sync()
RETURNS TABLE(
    side TEXT,
    ssn VARCHAR(100),
    empid VARCHAR(100),
    name VARCHAR(100),
    hdate VARCHAR(100),
    phone VARCHAR(100),
    email VARCHAR(100),
    dept VARCHAR(100),
    manager VARCHAR(100)
)
LANGUAGE SQL AS $$
    SELECT 'missing-in-target'::TEXT AS side, *
    FROM (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_source
        EXCEPT
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
    ) AS missing_in_target
    UNION ALL
    SELECT 'missing-in-source'::TEXT AS side, *
    FROM (
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person
        NATURAL LEFT OUTER JOIN transducer._personphone
        NATURAL LEFT OUTER JOIN transducer._personemail
        NATURAL LEFT OUTER JOIN transducer._employee
        NATURAL LEFT OUTER JOIN transducer._employeedate
        NATURAL LEFT OUTER JOIN transducer._ped
        NATURAL LEFT OUTER JOIN transducer._peddept
        NATURAL LEFT OUTER JOIN transducer._deptmanager
        EXCEPT
        SELECT ssn, empid, name, hdate, phone, email, dept, manager
        FROM transducer._person_source
    ) AS missing_in_source
$$;
