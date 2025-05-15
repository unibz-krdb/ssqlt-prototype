CREATE TABLE transducer._DEPARTMENT AS
SELECT DISTINCT dep_name, dep_address FROM transducer._EMPDEP;
ALTER TABLE transducer._DEPARTMENT ADD PRIMARY KEY (dep_name);
ALTER TABLE transducer._DEPARTMENT
ADD FOREIGN KEY (dep_address) REFERENCES transducer._DEPARTMENT_CITY(dep_address);