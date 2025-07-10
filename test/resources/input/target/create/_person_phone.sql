CREATE TABLE transducer._PERSON_PHONE (
  ssn          VARCHAR(100) NOT NULL,
  phone        VARCHAR(100) NOT NULL,
  PRIMARY KEY (ssn,phone),
  FOREIGN KEY (ssn) REFERENCES transducer._PERSON(ssn)
);