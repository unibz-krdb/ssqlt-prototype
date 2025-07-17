{{ select_preamble }} {{ attributes }}
FROM transducer._EMPDEP{{ primary_suffix }}
NATURAL LEFT OUTER JOIN transducer._POSITION{{ secondary_suffix }}
