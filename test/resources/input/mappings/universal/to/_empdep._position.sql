SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._EMPDEP${suffix}
NATURAL LEFT OUTER JOIN transducer._POSITION
