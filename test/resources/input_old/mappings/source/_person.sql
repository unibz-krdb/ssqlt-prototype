SELECT *
FROM _person_ssn
NATURAL JOIN _person_phone
NATURAL JOIN _city
NATURAL JOIN
(SELECT *
FROM _person_manager
NATURAL JOIN _manager
UNION
SELECT ssn, null, null, city
FROM _person_no_manager
)
