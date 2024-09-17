import os
from dataclasses import dataclass
from .context_paths import ContextPaths

@dataclass
class ContextFilePaths:
    source_create: str
    target_creates: list[str]
    source_constraints: list[str]
    target_constraints: list[str]
    target_to_source_mapping: str
    source_to_target_mappings: list[str]

    def __init__(self, context_paths: ContextPaths) -> None:
        # Get source_create file
        files = os.listdir(context_paths.create_source_path)
        if len(files) == 0:
            raise FileNotFoundError(f"No create files found in {context_paths.create_source_path}")
        if len(files) > 1:
            raise FileNotFoundError(f"Multiple create files found in {context_paths.create_source_path}")
        self.source_create = os.path.join(context_paths.create_source_path, files[0])

        # Get target_creates files
        files = os.listdir(context_paths.create_target_path)
        if len(files) == 0:
            raise FileNotFoundError(f"No create files found in {context_paths.create_target_path}")
        self.target_creates = list(map(lambda f: os.path.join(context_paths.create_target_path, f), files))

        # Get source_constraints files
        files = os.listdir(context_paths.constraints_source_path)
        self.source_constraints = list(map(lambda f: os.path.join(context_paths.constraints_source_path, f), files))

        # Get target_constraints files
        files = os.listdir(context_paths.constraints_target_path)
        self.target_constraints = list(map(lambda f: os.path.join(context_paths.constraints_target_path, f), files))

        # Get target_to_source_mapping file
        files = os.listdir(context_paths.mappings_source_path)
        if len(files) == 0:
            raise FileNotFoundError(f"No mapping files found in {context_paths.mappings_source_path}")
        if len(files) > 1:
            raise FileNotFoundError(f"Multiple mapping files found in {context_paths.mappings_source_path}")
        self.target_to_source_mapping = os.path.join(context_paths.mappings_source_path, files[0])

        # Get source_to_target_mappings files
        files = os.listdir(context_paths.mappings_target_path)
        if len(files) != len(self.target_creates):
            raise FileNotFoundError(f"Number of mapping files ({len(files)}) does not match number of target creates ({len(self.target_creates)})")
        self.source_to_target_mappings = list(map(lambda f: os.path.join(context_paths.mappings_target_path, f), files))


    @classmethod
    def from_dir(cls, path: str):
        context_paths = ContextPaths.from_dir(path)
        return cls(context_paths)
