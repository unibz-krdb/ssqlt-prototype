import os
from dataclasses import dataclass
from typing import Self

from .universal_mapping import UniversalMapping


@dataclass
class Universal:
    attributes: str
    mappings: dict[str, UniversalMapping]

    @staticmethod
    def get_tablename(file_path: str) -> str:
        """Return target tablename."""
        filename = os.path.basename(file_path)
        tokens = filename.split(".")
        target_table = tokens[-2]
        return target_table

    @classmethod
    def from_files(
        cls,
        attribute_path: str,
        from_mapping_paths: list[str],
        to_mapping_paths: list[str],
    ) -> Self:

        with open(attribute_path, "r") as f:
            attributes = f.read().strip()

        mappings = {}
        for from_mapping_path in from_mapping_paths:
            mappings[cls.get_tablename(from_mapping_path)] = [from_mapping_path]

        for to_mapping_path in to_mapping_paths:
            mappings[cls.get_tablename(to_mapping_path)].append(to_mapping_path)

        return cls(
            attributes=attributes,
            mappings={
                table_name: UniversalMapping.from_files(from_path, to_path)
                for table_name, (from_path, to_path) in mappings.items()
            },
        )
