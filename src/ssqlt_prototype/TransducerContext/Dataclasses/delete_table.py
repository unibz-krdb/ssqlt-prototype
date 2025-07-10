from dataclasses import dataclass

from .table import Table


@dataclass
class DeleteTable:
    source: Table
    schema: str
    table: str

    def __init__(self, source: Table) -> None:
        self.source = source
        self.table = source.name + "_DELETE"

    def create_sql(self) -> str:
        sql = f"CREATE TABLE {self.source.schema}.{self.table} AS\n"
        sql += f"SELECT * FROM {self.source.schema}.{self.source.name}\n"
        sql += "WHERE 1<>1;"
        return sql

    def generate_function(self) -> str:
        sql = f"""CREATE OR REPLACE FUNCTION {self.source.schema}.{self.table}_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM {self.source.schema}._loop WHERE loop_start = 2) THEN
         DELETE FROM {self.source.schema}.{self.table};
         RETURN NULL;
   END IF;
   IF EXISTS (SELECT * FROM {self.source.schema}._loop WHERE loop_start = 1) THEN
         RETURN NULL;
   END IF;
   INSERT INTO {self.source.schema}._loop VALUES (-1);
   INSERT INTO {self.source.schema}.{self.table} VALUES(SELECT * FROM OLD);
   RETURN NEW;
END;  $$;
"""

        return sql

    def generate_trigger(self) -> str:
        sql = f"""CREATE TRIGGER {self.source.schema}_{self.table}_trigger
AFTER DELETE ON {self.source.schema}.{self.source.name}
FOR EACH ROW
EXECUTE FUNCTION {self.source.schema}.{self.table}_fn();
        """
        return sql
