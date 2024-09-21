DROP SCHEMA IF EXISTS transducer CASCADE;
CREATE SCHEMA transducer;

/*
* STEP 1
*
* Parse in source table
*/

CREATE TABLE transducer._PERSON
    (
      ssn VARCHAR(100) NOT NULL,
      phone VARCHAR(100) NOT NULL,
      manager VARCHAR(100),
      title VARCHAR(100),
      city VARCHAR(100) NOT NULL,
      country VARCHAR(100) NOT NULL,
      mayor VARCHAR(100) NOT NULL
    );

    ALTER TABLE transducer._person ADD PRIMARY KEY (ssn,phone);

/*
* STEP 2
*
* Parse in dependencies
*/

CREATE OR REPLACE FUNCTION transducer.check_person_inc1_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN

   IF (NEW.manager IS NULL) THEN
      RETURN NEW;
   END IF;
   IF EXISTS (SELECT DISTINCT NEW.manager
            FROM transducer._person
         EXCEPT(
         SELECT ssn AS manager
         FROM transducer._person
         UNION
         SELECT NEW.ssn as manager)) THEN
         RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE INC1 CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE OR REPLACE FUNCTION transducer.check_person_inc2_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS ( SELECT DISTINCT NEW.mayor
            FROM transducer._person
         EXCEPT(
         SELECT ssn AS mayor
         FROM transducer._person
         UNION
         SELECT NEW.ssn as mayor)) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE INC2 CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE OR REPLACE FUNCTION transducer.check_person_mvd_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT DISTINCT r1.ssn, r1.phone, r2.manager, r2.title, r2.city, r2.country, r2.mayor
         FROM transducer._person AS r1,
         (SELECT NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor) AS r2
            WHERE  r1.ssn = r2.ssn
         EXCEPT
         SELECT *
         FROM transducer._person
         ) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE MVD CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE OR REPLACE FUNCTION transducer.check_person_fd_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT *
         FROM transducer._person AS r1,
         (SELECT NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor) AS r2
            WHERE  r1.city = r2.city
         AND (r1.country <> r2.country
         OR r1.mayor <> r2.mayor)) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE FD CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE OR REPLACE FUNCTION transducer.check_person_cfd_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT *
         FROM transducer._person AS r1,
         (SELECT NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor) AS r2
            WHERE  (r2.manager IS NOT NULL AND r2.title IS NOT NULL
               AND r1.manager = r2.manager
               AND r1.title <> r2.title)
         OR
            (r2.manager IS NULL AND r2.title IS NOT NULL) OR
            (r2.manager IS NOT NULL AND r2.title IS NULL)

           ) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE CFD CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;


CREATE OR REPLACE FUNCTION transducer.check_person_delete_inc1_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN

   IF (OLD.manager IS NULL) THEN
      RETURN OLD;
   END IF;

   /*In two time, we first check if the deleted tuple actually remove VALUES in ssn or manager */
   IF NOT EXISTS (SELECT * FROM transducer._person WHERE ssn = OLD.ssn
   EXCEPT (SELECT * FROM transducer._person WHERE ssn = OLD.ssn AND phone = OLD.phone)) THEN
      /*If so, then we check is other tuple are dependent on those values*/
      IF EXISTS (SELECT ssn, phone
        FROM transducer._person WHERE manager = OLD.ssn
        EXCEPT(SELECT OLD.ssn, OLD.phone)) THEN
         /*If so, then it violates the inclusion dependency constraint*/
            RAISE EXCEPTION 'THIS REMOVED VALUES VIOLATE THE INC1 CONSTRAINT';
            RETURN NULL;
      END IF;
   END IF;
   RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION transducer.check_person_delete_inc2_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN

   /*In two time, we first check if the deleted tuple actually remove VALUES in ssn or mayor */
   IF NOT EXISTS (SELECT * FROM transducer._person WHERE ssn = OLD.ssn
   EXCEPT (SELECT * FROM transducer._person WHERE ssn = OLD.ssn AND phone = OLD.phone)) THEN
      /*If so, then we check is other tuple are dependent on those values*/
      IF EXISTS (SELECT ssn, phone
        FROM transducer._person WHERE mayor = OLD.ssn
        EXCEPT(SELECT OLD.ssn, OLD.phone)) THEN
         /*If so, then it violates the inclusion dependency constraint*/
            RAISE EXCEPTION 'THIS REMOVED VALUES VIOLATE THE INC2 CONSTRAINT';
            RETURN NULL;
      END IF;
   END IF;
   RETURN OLD;
END;
$$;

/*
* STEP 3
*
* Generate corresponding triggers for the dependencies
*
* Notes:
* - The triggers are set to fire before an insert on the source table
* - The only piece of information required from a dependency is the table it relates to
*/

CREATE TRIGGER person_inc1_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_inc1_fn();

CREATE TRIGGER person_inc2_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_inc2_fn();

CREATE TRIGGER person_fd_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_fd_fn();

CREATE TRIGGER person_mvd_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_mvd_fn();

CREATE TRIGGER person_cfd_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_cfd_fn();

CREATE TRIGGER person_inc1_delete_trigger
BEFORE DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_delete_inc1_fn();

CREATE TRIGGER person_inc2_delete_trigger
BEFORE DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.check_person_delete_inc2_fn();

/*
* STEP 4
*
* Parse in target tables
*/

CREATE TABLE transducer._PERSON_SSN AS
SELECT DISTINCT ssn FROM transducer._person;
ALTER TABLE transducer._person_ssn ADD PRIMARY KEY (ssn);

CREATE TABLE transducer._PERSON_CITY AS
SELECT DISTINCT ssn, city FROM transducer._person;
/* FIXME: No primary key? */
ALTER TABLE transducer._person_city
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
ALTER TABLE transducer._person_city
ADD FOREIGN KEY (city) REFERENCES transducer._city(city);

CREATE TABLE transducer._PERSON_PHONE AS
SELECT DISTINCT ssn, phone FROM transducer._person;
ALTER TABLE transducer._person_phone ADD PRIMARY KEY (ssn,phone);
ALTER TABLE transducer._person_phone
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);

CREATE TABLE transducer._PERSON_MANAGER AS
SELECT DISTINCT ssn, manager FROM transducer._person
WHERE manager IS NOT NULL;
ALTER TABLE transducer._person_manager ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._person_manager
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
ALTER TABLE transducer._person_manager
ADD FOREIGN KEY (manager) REFERENCES transducer._manager(manager);

CREATE TABLE transducer._MANAGER AS
SELECT DISTINCT manager,title FROM transducer._person
WHERE manager IS NOT NULL
AND title IS NOT NULL;
ALTER TABLE transducer._manager ADD PRIMARY KEY (manager);
ALTER TABLE transducer._manager
ADD FOREIGN KEY (manager) REFERENCES transducer._person_ssn(ssn);

CREATE TABLE transducer._PERSON_NO_MANAGER AS
SELECT DISTINCT ssn FROM transducer._person
WHERE manager IS NULL;
ALTER TABLE transducer._person_no_manager ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._person_no_manager
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);

CREATE TABLE transducer._CITY AS
SELECT DISTINCT city, country,mayor FROM transducer._person;
ALTER TABLE transducer._city ADD PRIMARY KEY (city);
ALTER TABLE transducer._city
ADD FOREIGN KEY (mayor) REFERENCES transducer._person_ssn(ssn);

/*
* STEP 5
*
* Create source-to-target insert/delete tables.
*/

/* S -> T */

CREATE TABLE transducer._person_INSERT AS
SELECT * FROM transducer._person
WHERE 1<>1;

CREATE TABLE transducer._person_DELETE AS
SELECT * FROM transducer._person
WHERE 1<>1;

/*
* STEP 6
*
* Create target-to-source insert/delete tables.
*/

/* T -> S */

CREATE TABLE transducer._person_ssn_INSERT AS
SELECT * FROM transducer._person_ssn
WHERE 1<>1;

CREATE TABLE transducer._person_ssn_DELETE AS
SELECT * FROM transducer._person_ssn
WHERE 1<>1;

CREATE TABLE transducer._person_phone_INSERT AS
SELECT * FROM transducer._person_phone
WHERE 1<>1;

CREATE TABLE transducer._person_phone_DELETE AS
SELECT * FROM transducer._person_phone
WHERE 1<>1;

CREATE TABLE transducer._manager_INSERT AS
SELECT * FROM transducer._manager
WHERE 1<>1;

CREATE TABLE transducer._manager_DELETE AS
SELECT * FROM transducer._manager
WHERE 1<>1;

CREATE TABLE transducer._person_manager_INSERT AS
SELECT * FROM transducer._person_manager
WHERE 1<>1;

CREATE TABLE transducer._person_manager_DELETE AS
SELECT * FROM transducer._person_manager
WHERE 1<>1;

CREATE TABLE transducer._person_no_manager_INSERT AS
SELECT * FROM transducer._person_no_manager
WHERE 1<>1;

CREATE TABLE transducer._person_no_manager_DELETE AS
SELECT * FROM transducer._person_no_manager
WHERE 1<>1;

CREATE TABLE transducer._city_INSERT AS
SELECT * FROM transducer._city
WHERE 1<>1;

CREATE TABLE transducer._city_DELETE AS
SELECT * FROM transducer._city
WHERE 1<>1;

/* LOOP PREVENTION MECHANISM */

CREATE TABLE transducer._LOOP (
loop_start INT NOT NULL );


/** SIMPLE **/
/** S->T INSERTS **/

/* First we insert into _person insert table */
CREATE OR REPLACE FUNCTION transducer.source_person_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_insert;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_insert VALUES(NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER source_person_insert_trigger
AFTER INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.source_person_insert_fn();

/* Then we insert into the target tables from the insert table */
CREATE OR REPLACE FUNCTION transducer.source_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN

      INSERT INTO transducer._person_ssn VALUES (NEW.ssn) ON CONFLICT (ssn) DO NOTHING;
      INSERT INTO transducer._city VALUES (NEW.city, NEW.country, NEW.mayor) ON CONFLICT (city) DO NOTHING;
      INSERT INTO transducer._person_phone VALUES (NEW.ssn, NEW.phone) ON CONFLICT (ssn,phone) DO NOTHING;
      INSERT INTO transducer._manager (SELECT NEW.manager, NEW.title WHERE NEW.manager IS NOT NULL AND NEW.title IS NOT NULL) ON CONFLICT (manager) DO NOTHING;
      INSERT INTO transducer._person_manager (SELECT NEW.ssn, NEW.manager, NEW.city WHERE NEW.manager IS NOT NULL) ON CONFLICT (ssn) DO NOTHING;
      INSERT INTO transducer._person_no_manager (SELECT NEW.ssn, NEW.city WHERE NEW.manager IS NULL) ON CONFLICT (ssn) DO NOTHING;
      DELETE FROM transducer._person_insert;
      DELETE FROM transducer._loop;

      RETURN NEW;
END;  $$;

CREATE TRIGGER source_insert_trigger
AFTER INSERT ON transducer._person_insert
FOR EACH ROW
EXECUTE FUNCTION transducer.source_insert_fn();

/** S->T DELETES **/

CREATE OR REPLACE FUNCTION transducer.source_person_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_delete;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (1);
      INSERT INTO transducer._person_delete VALUES(OLD.ssn,OLD.phone,OLD.manager,OLD.title,OLD.city,OLD.country,OLD.mayor);
      RETURN NEW;
   END IF;
END;  $$;




/**T->S INSERTS **/
CREATE OR REPLACE FUNCTION transducer.target_person_ssn_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
         DELETE FROM transducer._person_ssn_insert;
         RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES(1);
      INSERT INTO transducer._person_ssn_insert VALUES(NEW.ssn);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER target_person_ssn_insert_trigger
AFTER INSERT ON transducer._person_ssn
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_ssn_insert_fn();

CREATE OR REPLACE FUNCTION transducer.target_person_manager_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
         DELETE FROM transducer._person_manager_insert;
         RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES(1);
      INSERT INTO transducer._person_manager_insert VALUES(NEW.ssn, NEW.manager, NEW.city);
      RETURN NEW;
   END IF;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_manager_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
         DELETE FROM transducer._manager_insert;
         RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES(1);
      INSERT INTO transducer._manager_insert VALUES(NEW.manager, NEW.title);
      RETURN NEW;
   END IF;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_person_no_manager_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
         DELETE FROM transducer._person_no_manager_insert;
         RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES(1);
      INSERT INTO transducer._person_no_manager_insert VALUES(NEW.ssn, NEW.city);
      RETURN NEW;
   END IF;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_person_phone_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
      DELETE FROM transducer._person_phone_insert;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES(1);
      INSERT INTO transducer._person_phone_insert VALUES(NEW.ssn, NEW.phone);
      RETURN NEW;
   END IF;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_city_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = -1) THEN
      DELETE FROM transducer._person_ssn_insert;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES(1);
      INSERT INTO transducer._city_insert VALUES  (NEW.city, NEW.country, NEW.mayor);
      RETURN NEW;
   END IF;
END; $$;

/** T->S DELETE **/


CREATE OR REPLACE FUNCTION transducer.target_person_ssn_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_delete;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_ssn_delete VALUES(OLD.ssn);
   RETURN NEW;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_person_manager_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_delete;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_manager_delete VALUES(OLD.ssn, OLD.manager, OLD.city);
   RETURN NEW;

END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_manager_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_delete;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._manager_delete VALUES(OLD.manager, OLD.title);
   RETURN NEW;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_person_no_manager_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_delete;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_no_manager_delete VALUES(OLD.ssn, OLD.city);
   RETURN NEW;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_person_phone_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_delete;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_phone_delete VALUES(OLD.ssn, OLD.phone);
   RETURN NEW;
END;  $$;

CREATE OR REPLACE FUNCTION transducer.target_city_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_delete;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._city_delete VALUES(OLD.city, OLD.country, OLD.mayor);
   RETURN NEW;
END;  $$;


CREATE OR REPLACE FUNCTION transducer.target_person_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Starting DELETE from target';
   DELETE FROM transducer._person WHERE phone IN (SELECT phone FROM transducer._person_phone_delete);

   DELETE FROM transducer._person_ssn_delete;
   DELETE FROM transducer._person_manager_delete;
   DELETE FROM transducer._manager_delete;
   DELETE FROM transducer._person_no_manager_delete;
   DELETE FROM transducer._person_phone_delete;
   DELETE FROM transducer._city_delete;
   DELETE FROM transducer._loop;

   RETURN NEW;
END;  $$;

/* */

/** S->T INSERT TRIGGERS **/





/** S->T DELETE TRIGGERS **/

CREATE TRIGGER source_person_delete_trigger
AFTER DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer.source_person_delete_fn();

CREATE TRIGGER source_delete_trigger
AFTER INSERT ON transducer._person_delete
FOR EACH ROW
EXECUTE FUNCTION transducer.source_delete_fn();

/** T->S INSERT **/


CREATE TRIGGER target_person_manager_insert_trigger
AFTER INSERT ON transducer._person_manager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_manager_insert_fn();

CREATE TRIGGER target_manager_insert_trigger
AFTER INSERT ON transducer._manager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_manager_insert_fn();

CREATE TRIGGER target_person_no_manager_insert_trigger
AFTER INSERT ON transducer._person_no_manager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_no_manager_insert_fn();

CREATE TRIGGER target_person_phone_insert_trigger
AFTER INSERT ON transducer._person_phone
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_phone_insert_fn();

CREATE TRIGGER target_person_ssn_insert_trigger
AFTER INSERT ON transducer._city
FOR EACH ROW
EXECUTE FUNCTION transducer.target_city_insert_fn();

/*
	CREATE TRIGGER target_person_insert_trigger_1
   AFTER INSERT ON transducer._person_ssn_insert
   FOR EACH ROW
   EXECUTE FUNCTION transducer.target_person_insert_fn();
*/
CREATE TRIGGER target_person_insert_trigger_2
AFTER INSERT ON transducer._person_phone_insert
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_insert_fn();
/*
   CREATE TRIGGER target_person_insert_trigger_3
   AFTER INSERT ON transducer._person_manager_insert
   FOR EACH ROW
   EXECUTE FUNCTION transducer.target_person_insert_fn();

   CREATE TRIGGER target_person_insert_trigger_4
   AFTER INSERT ON transducer._manager_insert
   FOR EACH ROW
   EXECUTE FUNCTION transducer.target_person_insert_fn();

   CREATE TRIGGER target_person_insert_trigger_5
   AFTER INSERT ON transducer._person_no_manager_insert
   FOR EACH ROW
   EXECUTE FUNCTION transducer.target_person_insert_fn();

   CREATE TRIGGER target_person_insert_trigger_6
   AFTER INSERT ON transducer._city_insert
   FOR EACH ROW
   EXECUTE FUNCTION transducer.target_person_insert_fn();
*/
/** T->S DELETE **/

CREATE TRIGGER target_person_ssn_delete_trigger
AFTER DELETE ON transducer._person_ssn
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_ssn_delete_fn();

CREATE TRIGGER target_person_manager_delete_trigger
AFTER DELETE ON transducer._person_manager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_manager_delete_fn();

CREATE TRIGGER target_manager_delete_trigger
AFTER DELETE ON transducer._manager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_manager_delete_fn();

CREATE TRIGGER target_person_no_manager_delete_trigger
AFTER DELETE ON transducer._person_no_manager
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_no_manager_delete_fn();

CREATE TRIGGER target_person_phone_delete_trigger
AFTER DELETE ON transducer._person_phone
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_phone_delete_fn();

CREATE TRIGGER target_person_ssn_delete_trigger
AFTER DELETE ON transducer._city
FOR EACH ROW
EXECUTE FUNCTION transducer.target_city_delete_fn();

CREATE TRIGGER target_person_delete_trigger
AFTER INSERT ON transducer._person_phone_delete
FOR EACH ROW
EXECUTE FUNCTION transducer.target_person_delete_fn();

/* */


/** COMPLEX **/
/** S->T DELETES **/
CREATE OR REPLACE FUNCTION transducer.source_delete_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   /* THE MVD AND THE CONDITONAL SPLIT MAKE THIS PROCESS SO MUCH MORE COMPLEX */
   /* WE START BY CHECKING IF WE HAVE TO DELETE AN ENTIRE PERSON, OR JUST A PHONE NUMBER */
   RAISE NOTICE 'BEGIN THE DELETE';
   IF EXISTS (SELECT ssn, phone FROM transducer._person_phone WHERE ssn = NEW.ssn EXCEPT SELECT NEW.ssn, NEW.phone) THEN
      RAISE NOTICE 'ONLY PHONE DELETE';
      DELETE FROM transducer._person_phone WHERE ssn = NEW.ssn AND phone = NEW.phone;
   ELSE
      DELETE FROM transducer._person_phone WHERE ssn = NEW.ssn AND phone = NEW.phone;
      /* THEN WE CHECK IF THE TUPLE REMOVE A MANAGER*/
      IF (NEW.manager IS NOT NULL) THEN
         DELETE FROM transducer._person_manager WHERE ssn = NEW.ssn AND manager = NEW.manager AND city = NEW.city;
         IF NOT EXISTS(SELECT ssn, manager, city FROM transducer._person_manager WHERE manager = NEW.manager) THEN
            DELETE FROM transducer._manager WHERE manager = NEW.manager AND title = NEW.title;
         END IF;
      ELSE
         DELETE FROM transducer._person_no_manager WHERE ssn = NEW.ssn AND city = NEW.city;
      END IF;
      /* A REALLY FUN ASPECT OF HAVING NO RELATION TABLE BETWEEEN PERSON AND CITY MEAN THAT DELETING CITIES IS QUITE COMPLEX */
      IF NOT EXISTS ((SELECT ssn, city FROM transducer._person_manager WHERE city = NEW.city
         UNION SELECT ssn, city FROM transducer._person_no_manager WHERE city = NEW.city)
         EXCEPT SELECT NEW.ssn, NEW.city) THEN
         DELETE FROM transducer._city WHERE city = NEW.city AND country = NEW.country AND mayor = NEW.mayor;
      END IF;
      DELETE FROM transducer._person_ssn WHERE ssn = NEW.ssn;

   END IF;
   DELETE FROM transducer._person_delete;
   DELETE FROM transducer._loop;
   RETURN NEW;
END;  $$;

/** COMPLEX **/

/**T->S INSERTS **/

/* This gets a bit complicated as the person update fully depend on which new information was actually added.
   For example, adding a new ssn,phone couple would only update the _person_phone_insert table, but it still need to get inserted into _person,
   requiring a bunch of joins to be made*/

CREATE OR REPLACE FUNCTION transducer.target_person_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   /*
   IF((SELECT SUM(loop_start) FROM transducer._loop WHERE loop_start = 1 ) >0) THEN
      RAISE NOTICE 'I wish there was an easier way to check how many rows exists in _loop';
      DELETE FROM transducer._loop WHERE loop_start IN (SELECT * FROM transducer._loop WHERE loop_start = 1 LIMIT 1);
      RETURN NULL;
   END IF;
   */
   RAISE NOTICE 'Starting insertion from target';
   /* I guess we can start with a first split checking if the added tuple bring any new cities*/
   IF EXISTS (SELECT * FROM transducer._city_insert) THEN
      /* If a new city is added, then it must be linked to a new ssn and everything that goes with it */
      RAISE NOTICE 'WE ADDED A FULL NEW TUPLE WITH A NEW CITY';
      INSERT INTO transducer._person (
            SELECT ssn, phone, manager, title, city, country, mayor FROM transducer._person_ssn_insert
            NATURAL JOIN transducer._person_phone_insert NATURAL JOIN transducer._city_insert NATURAL JOIN(
            SELECT ssn, manager, title, city FROM transducer._person_manager_insert NATURAL JOIN transducer._manager_insert
            UNION
            SELECT ssn, null, null, city FROM transducer._person_no_manager_insert));
   ELSE
      /* If no new city is added, then this could be new person, so we check for SSN*/
      IF EXISTS (SELECT * FROM transducer._person_ssn_insert) THEN
         /* Then we use join with target tables instead of target_insert tables */
         IF EXISTS (SELECT * FROM transducer._manager_insert) THEN
            RAISE NOTICE 'WE ADDED A NEW MANAGER CONNECTION';
            /* This is really annoying but if _manager_insert is empty then we can't add a new subaltern */
            INSERT INTO transducer._person (
            SELECT ssn, phone, manager, title, city, country, mayor FROM transducer._person_ssn_insert
            NATURAL JOIN transducer._person_phone_insert NATURAL JOIN transducer._city NATURAL JOIN(
            SELECT ssn, manager, title, city FROM transducer._person_manager_insert NATURAL JOIN transducer._manager_insert
            UNION
            SELECT ssn, null, null, city FROM transducer._person_no_manager_insert));
         ELSE
            INSERT INTO transducer._person (
            SELECT ssn, phone, manager, title, city, country, mayor FROM transducer._person_ssn_insert
            NATURAL JOIN transducer._person_phone_insert NATURAL JOIN transducer._city NATURAL JOIN(
            SELECT ssn, manager, title, city FROM transducer._person_manager_insert NATURAL JOIN transducer._manager
            UNION
            SELECT ssn, null, null, city FROM transducer._person_no_manager_insert));
         END IF;
      ELSE
         /* If no new person is added, then it's a new phone number for an already existing person*/
         INSERT INTO transducer._person (
            SELECT ssn, phone, manager, title, city, country, mayor FROM transducer._person_phone_insert
            NATURAL JOIN transducer._person_ssn NATURAL JOIN transducer._city NATURAL JOIN(
            SELECT ssn, manager, title, city FROM transducer._person_manager NATURAL JOIN transducer._manager
            UNION
            SELECT ssn, null, null, city FROM transducer._person_no_manager));
      END IF;
   END IF;
   /* A LOT OF INSERT TABLE DELETE TO CLEAR IT ALL */
   DELETE FROM transducer._person_ssn_insert;
   DELETE FROM transducer._person_manager_insert;
   DELETE FROM transducer._manager_insert;
   DELETE FROM transducer._person_no_manager_insert;
   DELETE FROM transducer._person_phone_insert;
   DELETE FROM transducer._city_insert;
   /*
   DELETE FROM transducer._loop;
   */
   RETURN NEW;
END;  $$;
