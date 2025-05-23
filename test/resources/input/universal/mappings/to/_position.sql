SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._POSITION_INSERT
NATURAL LEFT OUTER JOIN transducer._EMPDEP
