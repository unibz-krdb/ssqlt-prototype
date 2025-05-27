from dataclasses import dataclass
from typing import Self

from .Dataclasses import Constraint, CreateTable, Mapping, Universal, JoinTable
from .context_dir import ContextDir
from .context_file_paths import ContextFilePaths


@dataclass
class Context:
    source_tables: list[CreateTable]
    target_tables: list[CreateTable]
    source_constraints: list[Constraint]
    target_constraints: list[Constraint]
    source_mappings: list[Mapping]
    target_mappings: list[Mapping]
    universal: Universal

    def __init__(self, context_files: ContextFilePaths) -> None:
        self.source_tables = list(
            map(CreateTable.from_file, context_files.source_creates)
        )
        self.target_tables = list(
            map(CreateTable.from_file, context_files.target_creates)
        )
        self.source_constraints = list(
            map(Constraint.from_file, context_files.source_constraints)
        )
        self.target_constraints = list(
            map(Constraint.from_file, context_files.target_constraints)
        )
        self.source_mappings = list(
            map(Mapping.from_file, context_files.target_to_source_mappings)
        )
        self.target_mappings = list(
            map(Mapping.from_file, context_files.source_to_target_mappings)
        )
        self.universal = Universal.from_files(
            attribute_path=context_files.universal_attributes,
            from_mapping_paths=context_files.universal_mappings_from,
            to_mapping_paths=context_files.universal_mappings_to,
        )

    @classmethod
    def from_dir(cls, file_dir: str) -> Self:
        context_dirs = ContextDir.from_dir(file_dir)
        return cls(ContextFilePaths(context_dirs))

    def get_create(self, schema: str, table: str) -> None | CreateTable:
        for source_table in self.source_tables:
            if source_table.schema == schema and source_table.table == table:
                return source_table
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
CREATE OR REPLACE FUNCTION {self.source_tables[0].schema}.source_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN
        {insert_string}
        DELETE FROM {self.source_tables[0].schema}.{self.source_tables[0].table}_insert;
        DELETE FROM {self.source_tables[0].schema}._loop;
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
CREATE OR REPLACE FUNCTION {self.source_tables[0].schema}.target_insert_fn()
   RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
   BEGIN

        {delete_string}
        DELETE FROM {self.source_tables[0].schema}._loop;
        RETURN NEW;
END;   $$;
"""

        return result
