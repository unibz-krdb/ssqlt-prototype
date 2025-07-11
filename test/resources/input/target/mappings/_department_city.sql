${select_preamble} ${attributes}
FROM transducer._DEPARTMENT_CITY${primary_suffix}
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._PERSON${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._PERSON_PHONE${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL${secondary_suffix}
