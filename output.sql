DROP SCHEMA IF EXISTS transducer CASCADE;
CREATE SCHEMA transducer;
/* SOURCE TABLES */

CREATE TABLE transducer._POSITION
   (
      dep_address VARCHAR(100) NOT NULL,
      city VARCHAR(100) NOT NULL,
      country VARCHAR(100) NOT NULL
   );
ALTER TABLE transducer._POSITION ADD PRIMARY KEY (dep_address);

CREATE TABLE transducer._EMPDEP
    (
      ssn VARCHAR(100) NOT NULL,
      name VARCHAR(100) NOT NULL,
      phone VARCHAR(100) NOT NULL,
      email VARCHAR(100) NOT NULL,
      dep_name VARCHAR(100) NOT NULL,
      dep_address VARCHAR(100) NOT NULL
    );
ALTER TABLE transducer._EMPDEP ADD PRIMARY KEY (ssn,phone,email);
ALTER TABLE transducer._EMPDEP ADD FOREIGN KEY (dep_address) REFERENCES transducer._POSITION(dep_address);

/* SOURCE CONSTRAINTS */

CREATE OR REPLACE FUNCTION transducer._position_fd_1_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT * 
         FROM transducer._POSITION AS r1,
         (SELECT NEW.dep_address, NEW.city, NEW.country ) AS r2
            WHERE  r1.city = r2.city 
         AND r1.country<> r2.country) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE FD CONSTRAINT IN POSITION';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE TRIGGER transducer__position_fd_1_insert_trigger
BEFORE INSERT ON transducer._position
FOR EACH ROW
EXECUTE FUNCTION transducer._position_fd_1_insert_fn();


CREATE OR REPLACE FUNCTION transducer._empdep_mvd_2_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS   (SELECT r1.ssn, r1.name, r1.phone, NEW.email, r1.dep_name, r1.dep_address
            FROM transducer._EMPDEP as r1
            WHERE r1.ssn = NEW.ssn
            UNION
            SELECT r1.ssn, r1.name, NEW.phone, r1.email, r1.dep_name, r1.dep_address
            FROM transducer._EMPDEP as r1
            WHERE r1.ssn = NEW.ssn
            EXCEPT 
            (SELECT * FROM transducer._EMPDEP)) THEN
      RAISE NOTICE 'THE TUPLE % LEAD TO ADITIONAL ONES', NEW;
      INSERT INTO transducer._EMPDEP 
            (SELECT r1.ssn, r1.name, r1.phone, NEW.email, r1.dep_name, r1.dep_address
            FROM transducer._EMPDEP as r1
            WHERE r1.ssn = NEW.ssn
            UNION
            SELECT r1.ssn, r1.name, NEW.phone, r1.email, r1.dep_name, r1.dep_address
            FROM transducer._EMPDEP as r1
            WHERE r1.ssn = NEW.ssn
            EXCEPT 
            (SELECT * FROM transducer._EMPDEP));
      RETURN NEW;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE TRIGGER transducer__empdep_mvd_2_insert_trigger
BEFORE INSERT ON transducer._empdep
FOR EACH ROW
EXECUTE FUNCTION transducer._empdep_mvd_2_insert_fn();


CREATE OR REPLACE FUNCTION transducer._empdep_fd_1_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT * 
         FROM transducer._EMPDEP AS r1,
         (SELECT NEW.ssn, NEW.name, NEW.phone, NEW.email, NEW.dep_name,NEW.dep_address) AS r2
            WHERE  r1.dep_name = r2.dep_name 
         AND r1.dep_address<> r2.dep_address) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE FD CONSTRAINT IN EMPDEP';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE TRIGGER transducer__empdep_fd_1_insert_trigger
BEFORE INSERT ON transducer._empdep
FOR EACH ROW
EXECUTE FUNCTION transducer._empdep_fd_1_insert_fn();


CREATE OR REPLACE FUNCTION transducer._empdep_mvd_1_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT DISTINCT r1.ssn, r2.name, r1.phone, r1.email, r2.dep_name, r2.dep_address 
         FROM transducer._EMPDEP AS r1,
         (SELECT NEW.ssn, NEW.name, NEW.phone, NEW.email, NEW.dep_name, NEW.dep_address) AS r2
            WHERE  r1.ssn = r2.ssn 
         EXCEPT
         SELECT *
         FROM transducer._EMPDEP
         ) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE MVD CONSTRAINT ON PHONE %', NEW;
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;

CREATE TRIGGER transducer__empdep_mvd_1_insert_trigger
BEFORE INSERT ON transducer._empdep
FOR EACH ROW
EXECUTE FUNCTION transducer._empdep_mvd_1_insert_fn();


/* TARGET TABLES */

CREATE TABLE transducer._CITY_COUNTRY AS
SELECT DISTINCT city, country FROM transducer._POSITION;
ALTER TABLE transducer._CITY_COUNTRY ADD PRIMARY KEY (city);

CREATE TABLE transducer._DEPARTMENT_CITY AS
SELECT DISTINCT dep_address, city FROM transducer._POSITION;
ALTER TABLE transducer._DEPARTMENT_CITY ADD PRIMARY KEY (dep_address);
ALTER TABLE transducer._DEPARTMENT_CITY
ADD FOREIGN KEY (city) REFERENCES transducer._CITY_COUNTRY(city);

CREATE TABLE transducer._DEPARTMENT AS
SELECT DISTINCT dep_name, dep_address FROM transducer._EMPDEP;
ALTER TABLE transducer._DEPARTMENT ADD PRIMARY KEY (dep_name);
ALTER TABLE transducer._DEPARTMENT
ADD FOREIGN KEY (dep_address) REFERENCES transducer._DEPARTMENT_CITY(dep_address);

CREATE TABLE transducer._PERSON AS 
SELECT DISTINCT ssn, name, dep_name FROM transducer._EMPDEP;
ALTER TABLE transducer._PERSON ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._PERSON
ADD FOREIGN KEY (dep_name) REFERENCES transducer._DEPARTMENT(dep_name);

CREATE TABLE transducer._PERSON_EMAIL AS 
SELECT DISTINCT ssn, email FROM transducer._EMPDEP;
ALTER TABLE transducer._PERSON_EMAIL ADD PRIMARY KEY (ssn,email);
ALTER TABLE transducer._PERSON_EMAIL ADD FOREIGN KEY (ssn) REFERENCES transducer._PERSON(ssn);

CREATE TABLE transducer._PERSON_PHONE AS
SELECT DISTINCT ssn, phone FROM transducer._EMPDEP;
ALTER TABLE transducer._PERSON_PHONE ADD PRIMARY KEY (ssn,phone);
ALTER TABLE transducer._PERSON_PHONE
ADD FOREIGN KEY (ssn) REFERENCES transducer._PERSON(ssn);

/* TARGET CONSTRAINTS */

/* INSERT TABLES */

CREATE TABLE transducer._empdep_INSERT AS
SELECT * FROM transducer._empdep
WHERE 1<>1;

CREATE TABLE transducer._empdep_INSERT_JOIN AS
SELECT * FROM transducer._empdep
WHERE 1<>1;

CREATE TABLE transducer._position_INSERT AS
SELECT * FROM transducer._position
WHERE 1<>1;

CREATE TABLE transducer._position_INSERT_JOIN AS
SELECT * FROM transducer._position
WHERE 1<>1;

CREATE TABLE transducer._person_INSERT AS
SELECT * FROM transducer._person
WHERE 1<>1;

CREATE TABLE transducer._person_INSERT_JOIN AS
SELECT * FROM transducer._person
WHERE 1<>1;

CREATE TABLE transducer._department_city_INSERT AS
SELECT * FROM transducer._department_city
WHERE 1<>1;

CREATE TABLE transducer._department_city_INSERT_JOIN AS
SELECT * FROM transducer._department_city
WHERE 1<>1;

CREATE TABLE transducer._person_email_INSERT AS
SELECT * FROM transducer._person_email
WHERE 1<>1;

CREATE TABLE transducer._person_email_INSERT_JOIN AS
SELECT * FROM transducer._person_email
WHERE 1<>1;

CREATE TABLE transducer._person_phone_INSERT AS
SELECT * FROM transducer._person_phone
WHERE 1<>1;

CREATE TABLE transducer._person_phone_INSERT_JOIN AS
SELECT * FROM transducer._person_phone
WHERE 1<>1;

CREATE TABLE transducer._city_country_INSERT AS
SELECT * FROM transducer._city_country
WHERE 1<>1;

CREATE TABLE transducer._city_country_INSERT_JOIN AS
SELECT * FROM transducer._city_country
WHERE 1<>1;

CREATE TABLE transducer._department_INSERT AS
SELECT * FROM transducer._department
WHERE 1<>1;

CREATE TABLE transducer._department_INSERT_JOIN AS
SELECT * FROM transducer._department
WHERE 1<>1;

/* LOOP PREVENTION MECHANISM */

CREATE TABLE transducer._LOOP (loop_start INT NOT NULL );

/* INSERT FUNCTIONS & TRIGGERS */

CREATE OR REPLACE FUNCTION transducer._empdep_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._empdep_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._empdep_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._empdep_INSERT VALUES(new.ssn, new.name, new.phone, new.email, new.dep_name, new.dep_address);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__empdep_INSERT_trigger
AFTER INSERT ON transducer._empdep
FOR EACH ROW
EXECUTE FUNCTION transducer._empdep_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._empdep_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._EMPDEP_INSERT
NATURAL LEFT OUTER JOIN transducer._POSITION);

INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._position_INSERT_JOIN (SELECT dep_address, city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _empdep_INSERT_JOIN_trigger
AFTER INSERT ON transducer._empdep_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._empdep_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._position_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._position_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._position_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._position_INSERT VALUES(new.dep_address, new.city, new.country);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__position_INSERT_trigger
AFTER INSERT ON transducer._position
FOR EACH ROW
EXECUTE FUNCTION transducer._position_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._position_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._POSITION_INSERT
NATURAL LEFT OUTER JOIN transducer._EMPDEP);

INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._empdep_INSERT_JOIN (SELECT ssn, name, phone, email, dep_name, dep_address FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _position_INSERT_JOIN_trigger
AFTER INSERT ON transducer._position_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._position_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._person_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_INSERT VALUES(new.ssn, new.name, new.dep_name);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__person_INSERT_trigger
AFTER INSERT ON transducer._person
FOR EACH ROW
EXECUTE FUNCTION transducer._person_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
   FROM transducer._PERSON_INSERT
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY);

INSERT INTO transducer._person_phone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
INSERT INTO transducer._person_email_INSERT_JOIN (SELECT ssn, email FROM temp_table);
INSERT INTO transducer._department_INSERT_JOIN (SELECT dep_name, dep_address FROM temp_table);
INSERT INTO transducer._department_city_INSERT_JOIN (SELECT dep_address, city FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._city_country_INSERT_JOIN (SELECT city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _person_INSERT_JOIN_trigger
AFTER INSERT ON transducer._person_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._person_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._department_city_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._department_city_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._department_city_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._department_city_INSERT VALUES(new.dep_name, new.dep_address);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__department_city_INSERT_trigger
AFTER INSERT ON transducer._department_city
FOR EACH ROW
EXECUTE FUNCTION transducer._department_city_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._department_city_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._DEPARTMENT_CITY_INSERT
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT
   NATURAL LEFT OUTER JOIN transducer._PERSON
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL);

INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name, dep_name FROM temp_table);
INSERT INTO transducer._person_phone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
INSERT INTO transducer._person_email_INSERT_JOIN (SELECT ssn, email FROM temp_table);
INSERT INTO transducer._department_INSERT_JOIN (SELECT dep_name, dep_address FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._city_country_INSERT_JOIN (SELECT city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _department_city_INSERT_JOIN_trigger
AFTER INSERT ON transducer._department_city_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._department_city_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_email_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._person_email_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_email_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_email_INSERT VALUES(new.ssn, new.email);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__person_email_INSERT_trigger
AFTER INSERT ON transducer._person_email
FOR EACH ROW
EXECUTE FUNCTION transducer._person_email_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_email_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._PERSON_EMAIL_INSERT
   NATURAL LEFT OUTER JOIN transducer._PERSON
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY);

INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name, dep_name FROM temp_table);
INSERT INTO transducer._person_phone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
INSERT INTO transducer._department_INSERT_JOIN (SELECT dep_name, dep_address FROM temp_table);
INSERT INTO transducer._department_city_INSERT_JOIN (SELECT dep_address, city FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._city_country_INSERT_JOIN (SELECT city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _person_email_INSERT_JOIN_trigger
AFTER INSERT ON transducer._person_email_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._person_email_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_phone_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._person_phone_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._person_phone_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._person_phone_INSERT VALUES(new.ssn, new.phone);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__person_phone_INSERT_trigger
AFTER INSERT ON transducer._person_phone
FOR EACH ROW
EXECUTE FUNCTION transducer._person_phone_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._person_phone_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._PERSON_PHONE_INSERT
   NATURAL LEFT OUTER JOIN transducer._PERSON
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY);

INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name, dep_name FROM temp_table);
INSERT INTO transducer._person_email_INSERT_JOIN (SELECT ssn, email FROM temp_table);
INSERT INTO transducer._department_INSERT_JOIN (SELECT dep_name, dep_address FROM temp_table);
INSERT INTO transducer._department_city_INSERT_JOIN (SELECT dep_address, city FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._city_country_INSERT_JOIN (SELECT city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _person_phone_INSERT_JOIN_trigger
AFTER INSERT ON transducer._person_phone_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._person_phone_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._city_country_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._city_country_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._city_country_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._city_country_INSERT VALUES(new.city, new.country);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__city_country_INSERT_trigger
AFTER INSERT ON transducer._city_country
FOR EACH ROW
EXECUTE FUNCTION transducer._city_country_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._city_country_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._CITY_COUNTRY_INSERT
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT
   NATURAL LEFT OUTER JOIN transducer._PERSON
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL);

INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name, dep_name FROM temp_table);
INSERT INTO transducer._person_phone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
INSERT INTO transducer._person_email_INSERT_JOIN (SELECT ssn, email FROM temp_table);
INSERT INTO transducer._department_INSERT_JOIN (SELECT dep_name, dep_address FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._department_city_INSERT_JOIN (SELECT dep_address, city FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _city_country_INSERT_JOIN_trigger
AFTER INSERT ON transducer._city_country_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._city_country_INSERT_JOIN_fn();
        

CREATE OR REPLACE FUNCTION transducer._department_INSERT_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   RAISE NOTICE 'Triggered function transducer._department_INSERT_fn called';
   IF EXISTS (SELECT * FROM transducer._loop) THEN
      DELETE FROM transducer._loop;
      DELETE FROM transducer._department_INSERT;
      RETURN NULL;
   ELSE
      INSERT INTO transducer._loop VALUES (-1);
      INSERT INTO transducer._department_INSERT VALUES(new.dep_name, new.dep_address);
      RETURN NEW;
   END IF;
END;  $$;

CREATE TRIGGER transducer__department_INSERT_trigger
AFTER INSERT ON transducer._department
FOR EACH ROW
EXECUTE FUNCTION transducer._department_INSERT_fn();
        

CREATE OR REPLACE FUNCTION transducer._department_INSERT_JOIN_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
create temporary table temp_table (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));
INSERT INTO temp_table (SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._DEPARTMENT_INSERT
   NATURAL LEFT OUTER JOIN transducer._PERSON
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY);

INSERT INTO transducer._person_INSERT_JOIN (SELECT ssn, name, dep_name FROM temp_table);
INSERT INTO transducer._person_phone_INSERT_JOIN (SELECT ssn, phone FROM temp_table);
INSERT INTO transducer._person_email_INSERT_JOIN (SELECT ssn, email FROM temp_table);
INSERT INTO transducer._department_city_INSERT_JOIN (SELECT dep_address, city FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._city_country_INSERT_JOIN (SELECT city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        
CREATE TRIGGER _department_INSERT_JOIN_trigger
AFTER INSERT ON transducer._department_INSERT
FOR EACH ROW
EXECUTE FUNCTION transducer._department_INSERT_JOIN_fn();
        

/* COMPLEX SOURCE */

/* S->T INSERTS */

CREATE OR REPLACE FUNCTION transducer.target_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
DECLARE
v_loop INT;
BEGIN

SELECT count(*) INTO v_loop from transducer._loop;


IF NOT EXISTS (SELECT * FROM transducer._loop, (SELECT COUNT(*) as rc_value FROM transducer._loop) AS row_count
WHERE ABS(loop_start) = row_count.rc_value) THEN
   RAISE NOTICE 'Wait %', v_loop;
   RETURN NULL;
ELSE
   RAISE NOTICE 'This should conclude with an INSERT on _EMPDEP';
        
create temporary table temp_table_join (
ssn VARCHAR(100),
name VARCHAR(100),
phone VARCHAR(100),
email VARCHAR(100),
dep_name VARCHAR(100),
dep_address VARCHAR(100),
city VARCHAR(100),
country VARCHAR(100));

INSERT INTO temp_table_join(SELECT DISTINCT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._CITY_COUNTRY_INSERT_JOIN
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY_INSERT_JOIN
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_INSERT_JOIN
   NATURAL LEFT OUTER JOIN transducer._PERSON_INSERT_JOIN
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE_INSERT_JOIN
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL_INSERT_JOIN
 where ssn IS NOT NULL
 AND name IS NOT NULL
 AND phone IS NOT NULL
 AND email IS NOT NULL
 AND dep_name IS NOT NULL
 AND dep_address IS NOT NULL
 AND city IS NOT NULL
 AND country IS NOT NULL
 );

INSERT INTO transducer._position (SELECT dep_address, city, country FROM temp_table_join) ON CONFLICT (dep_address) DO NOTHING;
INSERT INTO transducer._loop VALUES (-1);
INSERT INTO transducer._empdep (SELECT ssn, name, phone, email, dep_name, dep_address FROM temp_table_join) ON CONFLICT (ssn, phone, email) DO NOTHING;

DELETE FROM transducer._person_INSERT;
DELETE FROM transducer._person_phone_INSERT;
DELETE FROM transducer._person_email_INSERT;
DELETE FROM transducer._department_INSERT;
DELETE FROM transducer._department_city_INSERT;
DELETE FROM transducer._city_country_INSERT;

DELETE FROM transducer._person_INSERT_JOIN;
DELETE FROM transducer._person_phone_INSERT_JOIN;
DELETE FROM transducer._person_email_INSERT_JOIN;
DELETE FROM transducer._department_INSERT_JOIN;
DELETE FROM transducer._department_city_INSERT_JOIN;
DELETE FROM transducer._city_country_INSERT_JOIN;

DELETE FROM transducer._loop;
DELETE FROM temp_table_join;
DROP TABLE temp_table_join;
RETURN NEW;
END IF;
END;    $$;
/* T->S INSERTS */

CREATE OR REPLACE FUNCTION transducer.source_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
RAISE NOTICE 'Something got added in a JOIN table';
IF NOT EXISTS (SELECT * FROM transducer._loop, (SELECT COUNT(*) as rc_value FROM transducer._loop) AS row_count
WHERE ABS(loop_start) = row_count.rc_value) THEN
   RAISE NOTICE 'But now is not the time to generate the query';
   RETURN NULL;
ELSE
   RAISE NOTICE 'This should conclude with an INSERT on _EMPDEP';

	INSERT INTO transducer._city_country SELECT city, country FROM transducer._EMPDEP_INSERT_JOIN
NATURAL LEFT OUTER JOIN transducer._POSITION_INSERT_JOIN WHERE ssn IS NOT NULL AND dep_address IS NOT NULL ON CONFLICT (city) DO NOTHING;

	INSERT INTO transducer._department_city SELECT dep_address, city FROM transducer._EMPDEP_INSERT_JOIN
NATURAL LEFT OUTER JOIN transducer._POSITION_INSERT_JOIN WHERE ssn IS NOT NULL AND dep_address IS NOT NULL ON CONFLICT (dep_address) DO NOTHING;

	INSERT INTO transducer._department SELECT dep_name, dep_address FROM transducer._EMPDEP_INSERT_JOIN
NATURAL LEFT OUTER JOIN transducer._POSITION_INSERT_JOIN WHERE ssn IS NOT NULL AND dep_address IS NOT NULL ON CONFLICT (dep_name) DO NOTHING;

	INSERT INTO transducer._person_email SELECT ssn, email FROM transducer._EMPDEP_INSERT_JOIN
NATURAL LEFT OUTER JOIN transducer._POSITION_INSERT_JOIN WHERE ssn IS NOT NULL AND dep_address IS NOT NULL ON CONFLICT (ssn,email) DO NOTHING;

	INSERT INTO transducer._person_phone SELECT ssn, phone FROM transducer._EMPDEP_INSERT_JOIN
NATURAL LEFT OUTER JOIN transducer._POSITION_INSERT_JOIN WHERE ssn IS NOT NULL AND dep_address IS NOT NULL ON CONFLICT (ssn,phone) DO NOTHING;

	INSERT INTO transducer._person SELECT ssn, name, dep_name FROM transducer._EMPDEP_INSERT_JOIN
NATURAL LEFT OUTER JOIN transducer._POSITION_INSERT_JOIN WHERE ssn IS NOT NULL AND dep_address IS NOT NULL ON CONFLICT (ssn) DO NOTHING;

	DELETE FROM transducer._empdep_INSERT;
	DELETE FROM transducer._position_INSERT;
	DELETE FROM transducer._empdep_INSERT_JOIN;
	DELETE FROM transducer._position_INSERT_JOIN;
	DELETE FROM transducer._loop NEW;
END IF;
END;  $$;
