from dataclasses import dataclass
from typing import Self

from .constraint import Constraint
from .context_dir import ContextDir
from .context_file_paths import ContextFilePaths
from .create_table import CreateTable
from .mapping import Mapping


@dataclass
class Context:
    source_table: CreateTable
    target_tables: list[CreateTable]
    source_constraints: list[Constraint]
    target_constraints: list[Constraint]
    source_mapping: Mapping
    target_mappings: list[Mapping]

    def __init__(self, context_files: ContextFilePaths) -> None:
        self.source_table = CreateTable.from_file(context_files.source_create)
        self.target_tables = list(
            map(CreateTable.from_file, context_files.target_creates)
        )
        self.source_constraints = list(
            map(Constraint.from_file, context_files.source_constraints)
        )
        self.target_constraints = list(
            map(Constraint.from_file, context_files.target_constraints)
        )
        self.source_mapping = Mapping.from_file(context_files.target_to_source_mapping)
        self.target_mappings = list(
            map(Mapping.from_file, context_files.source_to_target_mappings)
        )

    @classmethod
    def from_dir(cls, file_dir: str) -> Self:
        context_dirs = ContextDir.from_dir(file_dir)
        return cls(ContextFilePaths(context_dirs))

    def get_create(self, schema: str, table: str) -> None | CreateTable:
        if self.source_table.schema == schema and self.source_table.table == table:
            return self.source_table
        for target_table in self.target_tables:
            if target_table.schema == schema and target_table.table == table:
                return target_table
        return None

    def generate_source_insert(self):
        result = ""
        strings: list[str] = []

        for mapping in self.target_mappings:
            target_table = self.get_create(
                schema=mapping.schema, table=mapping.target_table
            )
            if target_table is None:
                raise Exception("Mapping does not have a corresponding table")
            strings.append(
                f"INSERT INTO {mapping.schema}.{mapping.target_table} VALUES ({mapping.sql(['new'])}) ON CONFLICT ({','.join(target_table.pkey)}) DO NOTHING;"
            )
        insert_string = "\n        ".join(strings)

        result = f"""
CREATE OR REPLACE FUNCTION {self.source_table.schema}.source_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
        {insert_string}
        DELETE FROM {self.source_table.schema}.{self.source_table.table}_insert;
        DELETE FROM {self.source_table.schema}._loop;
        RETURN NEW;
END;   $$;
"""

        return result

    def generate_target_delete(self):
        result = ""
        strings: list[str] = []

        for mapping in self.target_mappings:
            target_table = self.get_create(
                schema=mapping.schema, table=mapping.target_table
            )
            if target_table is None:
                raise Exception("Mapping does not have a corresponding table")
            strings.append(
                f"DELETE FROM {mapping.schema}.{mapping.target_table}_delete;"
            )
        delete_string = "\n        ".join(strings)

        result = f"""
CREATE OR REPLACE FUNCTION {self.source_table.schema}.target_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN

        {delete_string}
        DELETE FROM {self.source_table.schema}._loop;
        RETURN NEW;
END;   $$;
"""

        return result
