import os
from dataclasses import dataclass
from typing import Self


@dataclass
class Mapping:
    schema: str
    source_tables: list[str]
    target_table: str
    sql_template: str

    @classmethod
    def from_file(cls, file_path: str) -> Self:
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        schema = tokens[0]
        target_table = tokens[-2]
        source_tables = tokens[1:-2]
        with open(file_path, "r") as f:
            sql_template = f.read().strip()
        return cls(
            schema=schema,
            source_tables=source_tables,
            target_table=target_table,
            sql_template=sql_template,
        )
