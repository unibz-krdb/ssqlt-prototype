from dataclasses import dataclass
import os
from typing import Self
from enum import Enum


class InsertDelete(Enum):
    INSERT = "insert"
    DELETE = "delete"


@dataclass
class Constraint:
    schema: str
    table: str
    type_: str
    index: int
    insert_delete: InsertDelete
    sql: str

    @classmethod
    def from_file(cls, file_path: str) -> Self:
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        schema = tokens[0]
        table = tokens[1]
        type_ = tokens[2]
        index = int(tokens[3])
        insert_delete = InsertDelete(tokens[4])
        with open(file_path, "r") as f:
            sql = f.read().strip()
        sql = sql[sql.index("$$") :]
        return cls(schema, table, type_, index, insert_delete, sql)

    def _function_name(self) -> str:
        return f"{self.table}_{self.type_}_{self.index}_{self.insert_delete.value}_fn"

    def _trigger_name(self) -> str:
        return (
            f"{self.table}_{self.type_}_{self.index}_{self.insert_delete.value}_trigger"
        )

    def generate_function(self) -> str:
        return f"""CREATE OR REPLACE FUNCTION {self.schema}.{self._function_name()}()
RETURNS TRIGGER LANGUAGE PLPGSQL AS {self.sql}"""

    def generate_trigger(self) -> str:
        return f"""CREATE TRIGGER {self.schema}.{self._trigger_name()}
BEFORE {self.insert_delete.name} ON {self.schema}.{self.table}
FOR EACH ROW
EXECUTE FUNCTION {self.schema}.{self._function_name()}();"""
