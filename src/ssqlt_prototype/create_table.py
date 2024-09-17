from dataclasses import dataclass
import os
from typing import Self


@dataclass
class CreateTable:
    schema: str
    table: str
    sql: str

    def __init__(self, schema: str, table: str, sql: str) -> None:
        self.schema = schema
        self.table = table
        self.sql = sql

    @classmethod
    def from_file(cls, file_path: str) -> Self:
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        schema = tokens[0]
        table = tokens[1]
        with open(file_path, "r") as f:
            sql = f.read().strip()
        return cls(schema, table, sql)
