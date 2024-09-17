CREATE TABLE transducer._CITY AS
SELECT DISTINCT city, country,mayor FROM transducer._person;
ALTER TABLE transducer._city ADD PRIMARY KEY (city);
ALTER TABLE transducer._city
ADD FOREIGN KEY (mayor) REFERENCES transducer._person_ssn(ssn);
