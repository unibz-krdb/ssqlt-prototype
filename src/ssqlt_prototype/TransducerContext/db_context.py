from dataclasses import dataclass
from string import Template

from .Dataclasses import Constraint, CreateTable, Mapping


@dataclass
class DbContext:
    tables: dict[str, CreateTable]
    constraints: dict[str, list[Constraint]]
    mappings: dict[str, Mapping]
    _full_join: Template
    dep_orderings: list[str]

    @classmethod
    def from_files(
        cls,
        attribute_paths: list[str],
        create_paths: list[str],
        constraint_paths: list[str],
        mapping_paths: list[str],
        full_join_path: str,
        dep_orderings_path: str,
    ) -> "DbContext":

        tables = {}
        for file_path in create_paths:
            filename = file_path.split("/")[-1].split(".")[1]
            for attribute_path in attribute_paths:
                if filename.startswith(attribute_path.split("/")[-1].split(".")[0]):
                    create_table = CreateTable.from_file(file_path, attribute_path)
                    tables[create_table.table] = create_table
                    break

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

        with open(dep_orderings_path, "r") as f:
            dep_orderings = [line.strip() for line in f if line.strip()]

        return cls(
            tables=tables,
            constraints=constraints,
            mappings=mappings,
            _full_join=Template(full_join_str),
            dep_orderings=dep_orderings,
        )

    def full_join(self, suffix: str = ""):
        return self._full_join.substitute(suffix=suffix)
