${select_preamble} ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._DEPARTMENT${primary_suffix}
   NATURAL LEFT OUTER JOIN transducer._PERSON
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY
