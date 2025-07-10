CREATE TABLE transducer._DEPARTMENT (
  dep_name VARCHAR(100) NOT NULL,
  dep_address VARCHAR(100) NOT NULL,
  PRIMARY KEY (dep_name),
  FOREIGN KEY (dep_address) REFERENCES transducer._DEPARTMENT_CITY(dep_address)
);