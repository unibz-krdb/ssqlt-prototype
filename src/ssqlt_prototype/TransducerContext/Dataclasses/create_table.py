import os
from dataclasses import dataclass
from typing import Self

from .enums import SourceTarget


@dataclass
class CreateTable:
    schema: str
    table: str
    sql: str
    pkey: list[str]

    def __init__(
        self,
        schema: str,
        table: str,
        sql: str,
        pkey: list[str],
        source_target: SourceTarget,
    ) -> None:
        self.schema = schema
        self.table = table
        self.sql = sql
        self.pkey = pkey
        self.source_target = source_target

    @classmethod
    def from_file(cls, file_path: str, source_target: SourceTarget) -> Self:
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        schema = tokens[0]
        table = tokens[1]
        with open(file_path, "r") as f:
            sql = f.read().strip()

        # find primary key
        index = sql.find("PRIMARY KEY")
        pkeyshift = sql[index:].find("(") + 1
        pkeyend = sql[index + pkeyshift :].find(")")
        pkey = sql[index + pkeyshift : index + pkeyshift + pkeyend]

        return cls(
            schema, table, sql, pkey=pkey.split(","), source_target=source_target
        )
