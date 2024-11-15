CREATE TABLE transducer._PERSON_NO_MANAGER AS
SELECT DISTINCT ssn FROM transducer._person
WHERE manager IS NULL;
ALTER TABLE transducer._person_no_manager ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._person_no_manager
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
