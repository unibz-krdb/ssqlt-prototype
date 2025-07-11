${select_preamble} ${attributes}
FROM transducer._PERSON_PHONE${primary_suffix}
   NATURAL LEFT OUTER JOIN transducer._PERSON${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._PERSON_EMAIL${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._DEPARTMENT_CITY${secondary_suffix}
   NATURAL LEFT OUTER JOIN transducer._CITY_COUNTRY${secondary_suffix}
