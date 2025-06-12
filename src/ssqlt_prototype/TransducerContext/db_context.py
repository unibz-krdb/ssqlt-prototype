from dataclasses import dataclass
from string import Template

from .Dataclasses import Constraint, CreateTable, Mapping


@dataclass
class DbContext:
    tables: dict[str, CreateTable]
    constraints: dict[str, list[Constraint]]
    mappings: dict[str, Mapping]
    _full_join: Template

    @classmethod
    def from_files(
        cls,
        create_paths: list[str],
        constraint_paths: list[str],
        mapping_paths: list[str],
        full_join_path: str,
    ) -> "DbContext":

        tables = {}
        for file_path in create_paths:
            create_table = CreateTable.from_file(file_path)
            tables[create_table.table] = create_table

        constraints = {}
        for file_path in constraint_paths:
            constraint = Constraint.from_file(file_path)
            if constraint.table not in constraints:
                constraints[constraint.table] = []
            constraints[constraint.table].append(constraint)

        mappings = {}
        for file_path in mapping_paths:
            mapping = Mapping.from_file(file_path)
            mappings[mapping.target_table] = mapping

        with open(full_join_path, "r") as f:
            full_join_str = f.read().strip()

        return cls(
            tables=tables,
            constraints=constraints,
            mappings=mappings,
            _full_join=Template(full_join_str),
        )
