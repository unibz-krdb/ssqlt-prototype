CREATE TABLE transducer._PERSON_SSN AS
SELECT DISTINCT ssn FROM transducer._person;
ALTER TABLE transducer._person_ssn ADD PRIMARY KEY (ssn);
