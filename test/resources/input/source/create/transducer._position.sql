CREATE TABLE transducer._POSITION
   (
      dep_address VARCHAR(100) NOT NULL,
      city VARCHAR(100) NOT NULL,
      country VARCHAR(100) NOT NULL
   );
ALTER TABLE transducer._POSITION ADD PRIMARY KEY (dep_address);

