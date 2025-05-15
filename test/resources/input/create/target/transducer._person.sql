CREATE TABLE transducer._PERSON AS 
SELECT DISTINCT ssn, name, dep_name FROM transducer._EMPDEP;
ALTER TABLE transducer._PERSON ADD PRIMARY KEY (ssn);
ALTER TABLE transducer._PERSON
ADD FOREIGN KEY (dep_name) REFERENCES transducer._DEPARTMENT(dep_name);