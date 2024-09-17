CREATE TABLE transducer._PERSON_CITY AS
SELECT DISTINCT ssn, city FROM transducer._person;
/* FIXME: No primary key? */
ALTER TABLE transducer._person_city
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
ALTER TABLE transducer._person_city
ADD FOREIGN KEY (city) REFERENCES transducer._city(city);
