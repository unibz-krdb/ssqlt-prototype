import os
from dataclasses import dataclass
from typing import Self

from .universal_mapping import UniversalMapping


@dataclass
class Universal:
    attributes: str
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

    @classmethod
    def from_files(
        cls,
        attribute_path: str,
        from_mapping_paths: list[str],
        to_mapping_paths: list[str],
        source_ordering_path: str,
        target_ordering_path: str,
    ) -> Self:

        with open(attribute_path, "r") as f:
            attributes = f.read().strip()

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
            mappings={
                table_name: UniversalMapping.from_files(from_path, to_path)
                for table_name, (from_path, to_path) in mappings.items()
            },
            source_ordering=source_ordering,
            target_ordering=target_ordering,
        )
