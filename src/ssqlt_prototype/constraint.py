from dataclasses import dataclass
import os
from typing import Self


@dataclass
class Constraint:
    schema: str
    table: str
    type_: str
    index: int
    stage: str
    sql: str

    def __init__(self, schema: str, table: str, type_: str, index: int, stage: str, sql: str) -> None:
        self.schema = schema
        self.table = table
        self.type_ = type_
        self.index = index
        self.stage = stage
        self.sql = sql

    @classmethod
    def from_file(cls, file_path: str) -> Self:
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        schema = tokens[0]
        table = tokens[1]
        type_ = tokens[2]
        index = int(tokens[3])
        stage = tokens[4]
        with open(file_path, "r") as f:
            sql = f.read().strip()
        return cls(schema, table, type_, index, stage, sql)
