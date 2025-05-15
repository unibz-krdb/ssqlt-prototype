CREATE TABLE transducer._EMPDEP
    (
      ssn VARCHAR(100) NOT NULL,
      name VARCHAR(100) NOT NULL,
      phone VARCHAR(100) NOT NULL,
      email VARCHAR(100) NOT NULL,
      dep_name VARCHAR(100) NOT NULL,
      dep_address VARCHAR(100) NOT NULL
    );
ALTER TABLE transducer._EMPDEP ADD PRIMARY KEY (ssn,phone,email);
ALTER TABLE transducer._EMPDEP ADD FOREIGN KEY (dep_address) REFERENCES transducer._POSITION(dep_address);