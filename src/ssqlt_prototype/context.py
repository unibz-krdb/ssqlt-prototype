from dataclasses import dataclass
from typing import Self
from .context_file_paths import ContextFilePaths
from .context_dir import ContextDir
from .create_table import CreateTable
from .constraint import Constraint
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
        self.target_tables = list(map(lambda f: CreateTable.from_file(f), context_files.target_creates))
        self.source_constraints = list(map(lambda f: Constraint.from_file(f), context_files.source_constraints))
        self.target_constraints = list(map(lambda f: Constraint.from_file(f), context_files.target_constraints))
        self.source_mapping = Mapping.from_file(context_files.target_to_source_mapping)
        self.target_mappings = list(map(lambda f: Mapping.from_file(f), context_files.source_to_target_mappings))

    @classmethod
    def from_dir(cls, file_dir: str) -> Self:
        context_dirs = ContextDir.from_dir(file_dir)
        return cls(ContextFilePaths(context_dirs))
