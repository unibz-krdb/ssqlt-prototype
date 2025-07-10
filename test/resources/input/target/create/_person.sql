CREATE TABLE transducer._PERSON (
  ssn         VARCHAR(100) NOT NULL,
  name        VARCHAR(100) NOT NULL,
  dep_name    VARCHAR(100) NOT NULL,
  PRIMARY KEY (ssn),
  FOREIGN KEY (dep_name) REFERENCES transducer._DEPARTMENT(dep_name)
);