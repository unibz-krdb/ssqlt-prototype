import os
from dataclasses import dataclass
from typing import Self
from string import Template


@dataclass
class Universal:
    attributes: str
    to_mappings: dict[str, Template]
    from_mappings: dict[str, Template]

    @classmethod
    def from_files(
        cls,
        attribute_path: str,
        from_mapping_paths: list[str],
        to_mapping_paths: list[str],
    ) -> Self:
        with open(attribute_path, "r") as f:
            attributes = f.read().strip()

        to_mappings = {}
        for mapping_path in to_mapping_paths:
            filename = os.path.basename(mapping_path)
            tokens = filename.split(".")
            target_table = tokens[0]
            with open(mapping_path, "r") as f:
                sql_template = Template(f.read().strip())
            to_mappings[f"{target_table}"] = sql_template

        from_mappings = {}
        for mapping_path in from_mapping_paths:
            filename = os.path.basename(mapping_path)
            tokens = filename.split(".")
            source_table = tokens[0]
            with open(mapping_path, "r") as f:
                sql_template = Template(f.read().strip())
            from_mappings[f"{source_table}"] = sql_template

        return cls(
            attributes=attributes, to_mappings=to_mappings, from_mappings=from_mappings
        )
