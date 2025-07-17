from dataclasses import dataclass
import os
from jinja2 import Template
from typing import Self


@dataclass
class UniversalMapping:
    table_name: str
    partner_table_names: list[str]
    from_sql_template: Template
    to_sql_template: Template

    def from_sql(self, universal_tablename) -> str:
        """Generate SQL for the FROM mapping."""
        return self.from_sql_template.render(
            universal_tablename=universal_tablename
        )

    def to_sql(
        self,
        universal_tablename="",
        primary_suffix="",
        secondary_suffix="",
        distinct: bool = False,
    ) -> str:
        """Generate SQL for the FROM mapping."""
        if distinct:
            select_preamble = "SELECT DISTINCT"
        else:
            select_preamble = "SELECT"
        return self.to_sql_template.render(
            universal_tablename=universal_tablename,
            primary_suffix=primary_suffix,
            secondary_suffix=secondary_suffix,
            select_preamble=select_preamble,
        )

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
