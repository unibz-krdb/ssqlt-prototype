   {{ select_preamble }} {{ attributes }}
   FROM transducer._PERSON{{ primary_suffix }}
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY
