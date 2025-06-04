import os
from dataclasses import dataclass
from typing import Self

from .universal_mapping import UniversalMapping


@dataclass
class Universal:
    attributes: list[str]
    types: list[str]
    mappings: dict[str, UniversalMapping]
    source_ordering: list[str]
    target_ordering: list[str]

    @staticmethod
    def get_tablename(file_path: str) -> str:
        """Return target tablename."""
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        target_table = tokens[0]
        return target_table

    def get_attributes(self) -> list[str]:
        """Return attributes as a string."""
        return self.attributes

    def create_sql(self, tablename: str, temp: bool) -> str:
        """Create SQL for the universal table."""
        sql = "create"
        if temp:
            sql += " temporary"
        sql += f" table {tablename} (\n"

        for attribute, type_ in zip(self.attributes, self.types):
            sql += f"    {attribute} {type_},\n"
        sql += ");"

        return sql

    @classmethod
    def from_files(
        cls,
        attribute_path: str,
        from_mapping_paths: list[str],
        to_mapping_paths: list[str],
        source_ordering_path: str,
        target_ordering_path: str,
    ) -> Self:

        attributes = []
        types = []
        with open(attribute_path, "r") as f:
            attributes_types = f.read().strip().splitlines()
            for attribute_type in attributes_types:
                attribute, type_ = attribute_type.split(",")
                attributes.append(attribute.strip())
                types.append(type_.strip())

        mappings = {}
        for from_mapping_path in from_mapping_paths:
            mappings[cls.get_tablename(from_mapping_path)] = [from_mapping_path]

        for to_mapping_path in to_mapping_paths:
            mappings[cls.get_tablename(to_mapping_path)].append(to_mapping_path)

        with open(source_ordering_path, "r") as f:
            source_ordering = f.read().strip().splitlines()

        with open(target_ordering_path, "r") as f:
            target_ordering = f.read().strip().splitlines()

        return cls(
            attributes=attributes,
            types=types,
            mappings={
                table_name: UniversalMapping.from_files(from_path, to_path)
                for table_name, (from_path, to_path) in mappings.items()
            },
            source_ordering=source_ordering,
            target_ordering=target_ordering,
        )
