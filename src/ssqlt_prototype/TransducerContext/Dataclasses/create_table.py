import os
from dataclasses import dataclass
from typing import Self

from .attribute import Attribute


@dataclass
class CreateTable:
    schema: str
    table: str
    attributes: list[Attribute]
    sql: str
    pkey: list[str]
    fkey: list[str]

    def __init__(
        self,
        schema: str,
        table: str,
        attributes: list[Attribute],
        sql: str,
        pkey: list[str],
        fkey: list[str],
    ) -> None:
        self.schema = schema
        self.table = table
        self.attributes = attributes
        self.sql = sql
        self.pkey = pkey
        self.fkey = fkey

    @classmethod
    def from_file(cls, create_filepath: str, attributes_filepath: str) -> Self:
        filename = os.path.basename(create_filepath)
        tokens = filename.split(".")
        schema = tokens[0]
        table = tokens[1]
        with open(create_filepath, "r") as f:
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

        # read attributes
        attributes = []
        with open(attributes_filepath, "r") as f:
            lines = f.read().strip().splitlines()
            for line in lines:
                if line.strip():
                    attr_name, attr_type = line.split(",")
                    attributes.append(Attribute(attr_name.strip(), attr_type.strip()))

        return cls(
            schema=schema, table=table, sql=sql, pkey=pkey.split(","), fkey=fkey, attributes=attributes
        )
