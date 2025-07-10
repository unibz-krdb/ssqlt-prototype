CREATE TABLE transducer._PERSON_EMAIL (
  ssn VARCHAR(100) NOT NULL,
  email        VARCHAR(100) NOT NULL,
  PRIMARY KEY (ssn, email),
  FOREIGN KEY (ssn) REFERENCES transducer._PERSON(ssn)
);