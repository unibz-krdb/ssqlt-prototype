CREATE OR REPLACE FUNCTION transducer._person_mvd_1_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT DISTINCT r1.ssn, r1.phone, r2.manager, r2.title, r2.city, r2.country, r2.mayor
         FROM transducer._person AS r1,
         (SELECT NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor) AS r2
            WHERE  r1.ssn = r2.ssn
         EXCEPT
         SELECT *
         FROM transducer._person
         ) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE MVD CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;
