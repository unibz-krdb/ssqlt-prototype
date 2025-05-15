CREATE TABLE transducer._PERSON_PHONE AS
SELECT DISTINCT ssn, phone FROM transducer._person;
ALTER TABLE transducer._person_phone ADD PRIMARY KEY (ssn,phone);
ALTER TABLE transducer._person_phone
ADD FOREIGN KEY (ssn) REFERENCES transducer._person_ssn(ssn);
