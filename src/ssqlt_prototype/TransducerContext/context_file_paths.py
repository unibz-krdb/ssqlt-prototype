import os
from dataclasses import dataclass
from .context_dir import ContextDir


@dataclass
class ContextFilePaths:

    source_creates: list[str]
    source_constraints: list[str]
    source_mappings: list[str]

    target_creates: list[str]
    target_constraints: list[str]
    target_mappings: list[str]

    def __init__(self, context_paths: ContextDir) -> None:

        # Get source_create file
        files = os.listdir(context_paths.source_create_dir)
        if len(files) == 0:
            raise FileNotFoundError(
                f"No create files found in {context_paths.source_create_dir}"
            )
        self.source_creates = list(
            map(lambda f: os.path.join(context_paths.source_create_dir, f), files)
        )

        # Get source_constraints files
        files = os.listdir(context_paths.source_constraints_dir)
        self.source_constraints = list(
            map(lambda f: os.path.join(context_paths.source_constraints_dir, f), files)
        )

        # Get source_mappings files
        files = os.listdir(context_paths.source_mappings_dir)
        self.source_mappings = list(
            map(lambda f: os.path.join(context_paths.source_mappings_dir, f), files)
        )

        # Get target_creates files
        files = os.listdir(context_paths.target_create_dir)
        if len(files) == 0:
            raise FileNotFoundError(
                f"No create files found in {context_paths.target_create_dir}"
            )
        self.target_creates = list(
            map(lambda f: os.path.join(context_paths.target_create_dir, f), files)
        )

        # Get target_constraints files
        files = os.listdir(context_paths.target_constraints_dir)
        self.target_constraints = list(
            map(lambda f: os.path.join(context_paths.target_constraints_dir, f), files)
        )

        # Get target_mappings files
        files = os.listdir(context_paths.target_mappings_dir)
        self.target_mappings = list(
            map(lambda f: os.path.join(context_paths.target_mappings_dir, f), files)
        )

    @classmethod
    def from_dir(cls, path: str):
        context_paths = ContextDir.from_dir(path)
        return cls(context_paths)
