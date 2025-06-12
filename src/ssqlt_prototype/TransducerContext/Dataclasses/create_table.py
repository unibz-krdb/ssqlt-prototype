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
    fkey: list[str]

    def __init__(
        self,
        schema: str,
        table: str,
        sql: str,
        pkey: list[str],
        fkey: list[str],
    ) -> None:
        self.schema = schema
        self.table = table
        self.sql = sql
        self.pkey = pkey
        self.fkey = fkey

    @classmethod
    def from_file(cls, file_path: str) -> Self:
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

        # find foreign keys
        index = sql.find("FOREIGN KEY")
        if index == -1:
            fkey = []
        else:
            fkeyshift = sql[index:].find("(") + 1
            fkeyend = sql[index + fkeyshift :].find(")")
            fkey = sql[index + fkeyshift : index + fkeyshift + fkeyend].split(",")

        return cls(
            schema, table, sql, pkey=pkey.split(","), fkey=fkey
        )
