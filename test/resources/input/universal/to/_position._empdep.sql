SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._POSITION${suffix}
NATURAL LEFT OUTER JOIN transducer._EMPDEP
