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

CREATE TABLE transducer._PERSON_INSERT AS
SELECT * FROM transducer._PERSON
WHERE 1<>1;

CREATE TABLE transducer._PERSON_CITY_INSERT AS
SELECT * FROM transducer._PERSON_CITY
WHERE 1<>1;

CREATE TABLE transducer._PERSON_NO_MANAGER_INSERT AS
SELECT * FROM transducer._PERSON_NO_MANAGER
WHERE 1<>1;

CREATE TABLE transducer._PERSON_MANAGER_INSERT AS
SELECT * FROM transducer._PERSON_MANAGER
WHERE 1<>1;

CREATE TABLE transducer._PERSON_SSN_INSERT AS
SELECT * FROM transducer._PERSON_SSN
WHERE 1<>1;

CREATE TABLE transducer._PERSON_PHONE_INSERT AS
SELECT * FROM transducer._PERSON_PHONE
WHERE 1<>1;

CREATE TABLE transducer._CITY_INSERT AS
SELECT * FROM transducer._CITY
WHERE 1<>1;

CREATE TABLE transducer._MANAGER_INSERT AS
SELECT * FROM transducer._MANAGER
WHERE 1<>1;

/* DELETE TABLES */

CREATE TABLE transducer._PERSON_DELETE AS
SELECT * FROM transducer._PERSON
WHERE 1<>1;

CREATE TABLE transducer._PERSON_CITY_DELETE AS
SELECT * FROM transducer._PERSON_CITY
WHERE 1<>1;

CREATE TABLE transducer._PERSON_NO_MANAGER_DELETE AS
SELECT * FROM transducer._PERSON_NO_MANAGER
WHERE 1<>1;

CREATE TABLE transducer._PERSON_MANAGER_DELETE AS
SELECT * FROM transducer._PERSON_MANAGER
WHERE 1<>1;

CREATE TABLE transducer._PERSON_SSN_DELETE AS
SELECT * FROM transducer._PERSON_SSN
WHERE 1<>1;

CREATE TABLE transducer._PERSON_PHONE_DELETE AS
SELECT * FROM transducer._PERSON_PHONE
WHERE 1<>1;

CREATE TABLE transducer._CITY_DELETE AS
SELECT * FROM transducer._CITY
WHERE 1<>1;

CREATE TABLE transducer._MANAGER_DELETE AS
SELECT * FROM transducer._MANAGER
WHERE 1<>1;

/* LOOP PREVENTION MECHANISM */

CREATE TABLE transducer._LOOP (loop_start INT NOT NULL );