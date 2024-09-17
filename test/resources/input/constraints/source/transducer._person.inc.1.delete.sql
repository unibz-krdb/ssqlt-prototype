CREATE OR REPLACE FUNCTION transducer._person_inc_1_delete_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN

   IF (OLD.manager IS NULL) THEN
      RETURN OLD;
   END IF;

   /*In two time, we first check if the deleted tuple actually remove VALUES in ssn or manager */
   IF NOT EXISTS (SELECT * FROM transducer._person WHERE ssn = OLD.ssn
   EXCEPT (SELECT * FROM transducer._person WHERE ssn = OLD.ssn AND phone = OLD.phone)) THEN
      /*If so, then we check is other tuple are dependent on those values*/
      IF EXISTS (SELECT ssn, phone
        FROM transducer._person WHERE manager = OLD.ssn
        EXCEPT(SELECT OLD.ssn, OLD.phone)) THEN
         /*If so, then it violates the inclusion dependency constraint*/
            RAISE EXCEPTION 'THIS REMOVED VALUES VIOLATE THE INC1 CONSTRAINT';
            RETURN NULL;
      END IF;
   END IF;
   RETURN OLD;
END;
$$;
