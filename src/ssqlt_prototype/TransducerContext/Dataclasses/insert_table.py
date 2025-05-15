from dataclasses import dataclass

from .create_table import CreateTable
from .mapping import Mapping


@dataclass
class InsertTable:
    source: CreateTable
    mapping: Mapping
    schema: str
    table: str

    def __init__(self, source: CreateTable, mapping: Mapping) -> None:
        self.source = source
        self.table = source.table + "_INSERT"
        self.mapping = mapping

    def create_sql(self) -> str:
        sql = f"CREATE TABLE {self.source.schema}.{self.table} AS\n"
        sql += f"SELECT * FROM {self.source.schema}.{self.source.table}\n"
        sql += "WHERE 1<>1;"
        return sql

    def join_create_sql(self) -> str:
        sql = f"CREATE TABLE {self.source.schema}.{self.table}_JOIN AS\n"
        sql += f"SELECT * FROM {self.source.schema}.{self.source.table}\n"
        sql += "WHERE 1<>1;"
        return sql

    def generate_function(self) -> str:
        sql = f"""CREATE OR REPLACE FUNCTION {self.source.schema}.{self.table}_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
   IF EXISTS (SELECT * FROM {self.source.schema}._loop) THEN
      DELETE FROM {self.source.schema}._loop;
      DELETE FROM {self.source.schema}.{self.table};
      RETURN NULL;
   ELSE
      INSERT INTO {self.source.schema}._loop VALUES (-1);
      INSERT INTO {self.source.schema}.{self.table} VALUES(SELECT * from NEW);
      RETURN NEW;
   END IF;
END;  $$;
"""

        return sql

    def generate_trigger(self) -> str:
        sql = f"""CREATE TRIGGER {self.source.schema}.{self.table}_trigger
AFTER INSERT ON {self.source.schema}.{self.source.table}
FOR EACH ROW
EXECUTE FUNCTION {self.source.schema}.{self.table}_fn();
        """
        return sql
