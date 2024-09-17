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
        return cls(schema, table, type_, index, insert_delete, sql)
