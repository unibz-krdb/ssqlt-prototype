CREATE TABLE transducer._MANAGER AS
SELECT DISTINCT manager,title FROM transducer._person
WHERE manager IS NOT NULL
AND title IS NOT NULL;
ALTER TABLE transducer._manager ADD PRIMARY KEY (manager);
ALTER TABLE transducer._manager
ADD FOREIGN KEY (manager) REFERENCES transducer._person_ssn(ssn);
