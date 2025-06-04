${select_preamble} ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._POSITION${primary_suffix}
NATURAL LEFT OUTER JOIN transducer._EMPDEP
