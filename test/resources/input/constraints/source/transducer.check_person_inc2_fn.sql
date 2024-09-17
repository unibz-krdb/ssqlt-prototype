CREATE OR REPLACE FUNCTION transducer.check_person_inc2_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS ( SELECT DISTINCT NEW.mayor
            FROM transducer._person
         EXCEPT(
         SELECT ssn AS mayor
         FROM transducer._person
         UNION
         SELECT NEW.ssn as mayor)) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE INC2 CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;
