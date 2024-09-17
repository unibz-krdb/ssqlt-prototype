CREATE TABLE transducer._PERSON_MANAGER AS
SELECT DISTINCT ssn, manager FROM transducer._person
WHERE manager IS NOT NULL;
ALTER TABLE transducer._person_manager ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._person_manager
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
ALTER TABLE transducer._person_manager
ADD FOREIGN KEY (manager) REFERENCES transducer._manager(manager);
