CREATE OR REPLACE FUNCTION transducer._person_cfd_1_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
   IF EXISTS (SELECT *
         FROM transducer._person AS r1,
         (SELECT NEW.ssn,NEW.phone,NEW.manager,NEW.title,NEW.city,NEW.country,NEW.mayor) AS r2
            WHERE  (r2.manager IS NOT NULL AND r2.title IS NOT NULL
               AND r1.manager = r2.manager
               AND r1.title <> r2.title)
         OR
            (r2.manager IS NULL AND r2.title IS NOT NULL) OR
            (r2.manager IS NOT NULL AND r2.title IS NULL)

           ) THEN
      RAISE EXCEPTION 'THIS ADDED VALUES VIOLATE THE CFD CONSTRAINT';
      RETURN NULL;
   ELSE
      RETURN NEW;
   END IF;
END;
$$;
