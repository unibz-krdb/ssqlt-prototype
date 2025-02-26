/* SOURCE TABLE */

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

/* SOURCE CONSTRAINTS */

CREATE OR REPLACE FUNCTION transducer._person_inc_1_delete_fn()
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

CREATE TRIGGER transducer._person_inc_1_delete_trigger
BEFORE DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_inc_1_delete_fn();


CREATE OR REPLACE FUNCTION transducer._person_fd_1_insert_fn()
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

CREATE TRIGGER transducer._person_fd_1_insert_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_fd_1_insert_fn();


CREATE OR REPLACE FUNCTION transducer._person_cfd_1_insert_fn()
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

CREATE TRIGGER transducer._person_cfd_1_insert_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_cfd_1_insert_fn();


CREATE OR REPLACE FUNCTION transducer._person_inc_2_insert_fn()
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

CREATE TRIGGER transducer._person_inc_2_insert_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_inc_2_insert_fn();


CREATE OR REPLACE FUNCTION transducer._person_inc_1_insert_fn()
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

CREATE TRIGGER transducer._person_inc_1_insert_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_inc_1_insert_fn();


CREATE OR REPLACE FUNCTION transducer._person_mvd_1_insert_fn()
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

CREATE TRIGGER transducer._person_mvd_1_insert_trigger
BEFORE INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_mvd_1_insert_fn();


CREATE OR REPLACE FUNCTION transducer._person_inc_2_delete_fn()
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

CREATE TRIGGER transducer._person_inc_2_delete_trigger
BEFORE DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_inc_2_delete_fn();


/* TARGET TABLES */

CREATE TABLE transducer._PERSON_CITY AS
SELECT DISTINCT ssn, city FROM transducer._person;
/* FIXME: No primary key? */
ALTER TABLE transducer._person_city
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
ALTER TABLE transducer._person_city
ADD FOREIGN KEY (city) REFERENCES transducer._city(city);

CREATE TABLE transducer._PERSON_NO_MANAGER AS
SELECT DISTINCT ssn FROM transducer._person
WHERE manager IS NULL;
ALTER TABLE transducer._person_no_manager ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._person_no_manager
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);

CREATE TABLE transducer._PERSON_MANAGER AS
SELECT DISTINCT ssn, manager FROM transducer._person
WHERE manager IS NOT NULL;
ALTER TABLE transducer._person_manager ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._person_manager
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
ALTER TABLE transducer._person_manager
ADD FOREIGN KEY (manager) REFERENCES transducer._manager(manager);

CREATE TABLE transducer._PERSON_SSN AS
SELECT DISTINCT ssn FROM transducer._person;
ALTER TABLE transducer._person_ssn ADD PRIMARY KEY (ssn);

CREATE TABLE transducer._PERSON_PHONE AS
SELECT DISTINCT ssn, phone FROM transducer._person;
ALTER TABLE transducer._person_phone ADD PRIMARY KEY (ssn,phone);
ALTER TABLE transducer._person_phone
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);

CREATE TABLE transducer._CITY AS
SELECT DISTINCT city, country,mayor FROM transducer._person;
ALTER TABLE transducer._city ADD PRIMARY KEY (city);
ALTER TABLE transducer._city
ADD FOREIGN KEY (mayor) REFERENCES transducer._person_ssn(ssn);

CREATE TABLE transducer._MANAGER AS
SELECT DISTINCT manager,title FROM transducer._person
WHERE manager IS NOT NULL
AND title IS NOT NULL;
ALTER TABLE transducer._manager ADD PRIMARY KEY (manager);
ALTER TABLE transducer._manager
ADD FOREIGN KEY (manager) REFERENCES transducer._person_ssn(ssn);

/* TARGET CONSTRAINTS */

/* INSERT TABLES */

CREATE TABLE transducer._person_INSERT AS
SELECT * FROM transducer._person
WHERE 1<>1;

CREATE TABLE transducer._person_city_INSERT AS
SELECT * FROM transducer._person_city
WHERE 1<>1;

CREATE TABLE transducer._person_no_manager_INSERT AS
SELECT * FROM transducer._person_no_manager
WHERE 1<>1;

CREATE TABLE transducer._person_manager_INSERT AS
SELECT * FROM transducer._person_manager
WHERE 1<>1;

CREATE TABLE transducer._person_ssn_INSERT AS
SELECT * FROM transducer._person_ssn
WHERE 1<>1;

CREATE TABLE transducer._person_phone_INSERT AS
SELECT * FROM transducer._person_phone
WHERE 1<>1;

CREATE TABLE transducer._city_INSERT AS
SELECT * FROM transducer._city
WHERE 1<>1;

CREATE TABLE transducer._manager_INSERT AS
SELECT * FROM transducer._manager
WHERE 1<>1;

/* DELETE TABLES */

CREATE TABLE transducer._person_DELETE AS
SELECT * FROM transducer._person
WHERE 1<>1;

CREATE TABLE transducer._person_city_DELETE AS
SELECT * FROM transducer._person_city
WHERE 1<>1;

CREATE TABLE transducer._person_no_manager_DELETE AS
SELECT * FROM transducer._person_no_manager
WHERE 1<>1;

CREATE TABLE transducer._person_manager_DELETE AS
SELECT * FROM transducer._person_manager
WHERE 1<>1;

CREATE TABLE transducer._person_ssn_DELETE AS
SELECT * FROM transducer._person_ssn
WHERE 1<>1;

CREATE TABLE transducer._person_phone_DELETE AS
SELECT * FROM transducer._person_phone
WHERE 1<>1;

CREATE TABLE transducer._city_DELETE AS
SELECT * FROM transducer._city
WHERE 1<>1;

CREATE TABLE transducer._manager_DELETE AS
SELECT * FROM transducer._manager
WHERE 1<>1;

/* LOOP PREVENTION MECHANISM */

CREATE TABLE transducer._LOOP (loop_start INT NOT NULL );

/* INSERT FUNCTIONS & TRIGGERS */

CREATE OR REPLACE FUNCTION transducer._person_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._person_INSERT_trigger
AFTER INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_city_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_city_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_city_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._person_city_INSERT_trigger
AFTER INSERT ON transducer._person_city
FOR EACH ROW
EXECUTE FUNCTION transducer._person_city_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_no_manager_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_no_manager_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_no_manager_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._person_no_manager_INSERT_trigger
AFTER INSERT ON transducer._person_no_manager
FOR EACH ROW
EXECUTE FUNCTION transducer._person_no_manager_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_manager_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_manager_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_manager_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._person_manager_INSERT_trigger
AFTER INSERT ON transducer._person_manager
FOR EACH ROW
EXECUTE FUNCTION transducer._person_manager_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_ssn_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_ssn_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_ssn_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._person_ssn_INSERT_trigger
AFTER INSERT ON transducer._person_ssn
FOR EACH ROW
EXECUTE FUNCTION transducer._person_ssn_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_phone_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_phone_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_phone_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._person_phone_INSERT_trigger
AFTER INSERT ON transducer._person_phone
FOR EACH ROW
EXECUTE FUNCTION transducer._person_phone_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._city_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._city_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._city_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._city_INSERT_trigger
AFTER INSERT ON transducer._city
FOR EACH ROW
EXECUTE FUNCTION transducer._city_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._manager_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._manager_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._manager_INSERT VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;


CREATE TRIGGER transducer._manager_INSERT_trigger
AFTER INSERT ON transducer._manager
FOR EACH ROW
EXECUTE FUNCTION transducer._manager_INSERT_fn();
        

/* DELETE FUNCTIONS & TRIGGERS */

CREATE OR REPLACE FUNCTION transducer._person_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._person_DELETE_trigger
AFTER DELETE ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_city_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_city_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_city_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._person_city_DELETE_trigger
AFTER DELETE ON transducer._person_city
FOR EACH ROW
EXECUTE FUNCTION transducer._person_city_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_no_manager_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_no_manager_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_no_manager_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._person_no_manager_DELETE_trigger
AFTER DELETE ON transducer._person_no_manager
FOR EACH ROW
EXECUTE FUNCTION transducer._person_no_manager_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_manager_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_manager_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_manager_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._person_manager_DELETE_trigger
AFTER DELETE ON transducer._person_manager
FOR EACH ROW
EXECUTE FUNCTION transducer._person_manager_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_ssn_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_ssn_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_ssn_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._person_ssn_DELETE_trigger
AFTER DELETE ON transducer._person_ssn
FOR EACH ROW
EXECUTE FUNCTION transducer._person_ssn_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_phone_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._person_phone_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._person_phone_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._person_phone_DELETE_trigger
AFTER DELETE ON transducer._person_phone
FOR EACH ROW
EXECUTE FUNCTION transducer._person_phone_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._city_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._city_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._city_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._city_DELETE_trigger
AFTER DELETE ON transducer._city
FOR EACH ROW
EXECUTE FUNCTION transducer._city_DELETE_fn();
        

CREATE OR REPLACE FUNCTION transducer._manager_DELETE_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 2) THEN
         DELETE FROM transducer._manager_DELETE;
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM transducer._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO transducer._loop VALUES (-1);
   INSERT INTO transducer._manager_DELETE VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;


CREATE TRIGGER transducer._manager_DELETE_trigger
AFTER DELETE ON transducer._manager
FOR EACH ROW
EXECUTE FUNCTION transducer._manager_DELETE_fn();
        

/* COMPLEX SOURCE */

/* S->T INSERTS */

CREATE OR REPLACE FUNCTION transducer.source_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
        INSERT INTO transducer._person_phone VALUES (SELECT new.ssn, new.phone FROM new._person) ON CONFLICT (ssn,phone) DO NOTHING;
        INSERT INTO transducer._manager VALUES (SELECT new.manager, new.title FROM new WHERE new.manager IS NOT NULL) ON CONFLICT (manager) DO NOTHING;
        INSERT INTO transducer._city VALUES (SELECT new.city, new.country, new.mayor FROM new._person) ON CONFLICT (city) DO NOTHING;
        INSERT INTO transducer._person_city VALUES (SELECT new.ssn, new.city FROM new._person) ON CONFLICT () DO NOTHING;
        INSERT INTO transducer._person_no_manager VALUES (SELECT new.ssn, new.city FROM new._person WHERE new.manager IS NULL) ON CONFLICT (ssn) DO NOTHING;
        INSERT INTO transducer._person_manager VALUES (SELECT new.ssn, new.manager, new.city FROM new._person WHERE new.manager IS NOT NULL AND new.title IS NOT NULL) ON CONFLICT (ssn) DO NOTHING;
        INSERT INTO transducer._person_ssn VALUES (SELECT new.ssn FROM new._person) ON CONFLICT (ssn) DO NOTHING;
        DELETE FROM transducer._person_insert;
        DELETE FROM transducer._loop;
        RETURN NEW;
END;   $$;

/* T->S DELETE */

CREATE OR REPLACE FUNCTION transducer.target_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN

        DELETE FROM transducer._person_phone_delete;
        DELETE FROM transducer._manager_delete;
        DELETE FROM transducer._city_delete;
        DELETE FROM transducer._person_city_delete;
        DELETE FROM transducer._person_no_manager_delete;
        DELETE FROM transducer._person_manager_delete;
        DELETE FROM transducer._person_ssn_delete;
        DELETE FROM transducer._loop;
        RETURN NEW;
END;   $$;
