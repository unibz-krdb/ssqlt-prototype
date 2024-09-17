CREATE OR REPLACE FUNCTION transducer._person_fd_1_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT *
         FROM transducer._person AS r1,
         (SELECT NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor) AS r2
            WHERE  r1.city = r2.city
         AND (r1.country <> r2.country
         OR r1.mayor <> r2.mayor)) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE FD CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;
