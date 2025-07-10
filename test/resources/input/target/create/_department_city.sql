CREATE TABLE transducer._DEPARTMENT_CITY (
  dep_address VARCHAR(100) NOT NULL,
  city        VARCHAR(100) NOT NULL,
  PRIMARY KEY (dep_address),
  FOREIGN KEY (city) REFERENCES transducer._CITY_COUNTRY(city)
);