CREATE OR REPLACE FUNCTION transducer.check_person_inc1_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN

   IF (NEW.manager IS NULL) THEN
      RETURN NEW;
   END IF;
   IF EXISTS (SELECT DISTINCT NEW.manager
            FROM transducer._person
         EXCEPT(
         SELECT ssn AS manager
         FROM transducer._person
         UNION
         SELECT NEW.ssn as manager)) THEN
         RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE INC1 CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;
