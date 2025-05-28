from dataclasses import dataclass
import os
from string import Template
from typing import Self

@dataclass
class UniversalMapping:
    table_name: str
    partner_table_names: list[str]
    from_sql_template: Template
    to_sql_template: Template

    @classmethod
    def from_files(cls, from_file_path: str, to_file_path: str) -> Self:

        with open(from_file_path, "r") as f:
            from_sql_template = Template(f.read().strip())

        to_filename = os.path.basename(to_file_path)
        tokens = to_filename.split(".")
        source_tables = tokens[1:-1]
        target_table = tokens[0]
        with open(to_file_path, "r") as f:
            to_sql_template = Template(f.read().strip())

        return cls(
            table_name=target_table,
            partner_table_names=source_tables,
            from_sql_template=from_sql_template,
            to_sql_template=to_sql_template,
        )
