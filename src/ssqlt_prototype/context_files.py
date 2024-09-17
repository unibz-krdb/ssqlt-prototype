import os
from dataclasses import dataclass
from .context_paths import ContextPaths

@dataclass
class ContextFiles:
    source_create: dict[str, str]
    target_creates: dict[str, str]
    source_constraints: dict[str, str]
    target_constraints: dict[str, str]
    target_to_source_mapping: dict[str, str]
    source_to_target_mappings: dict[str, str]

    def __init__(self, context_paths: ContextPaths) -> None:
        # Get source_create file
        files = os.listdir(context_paths.create_source_path)
        if len(files) == 0:
            raise FileNotFoundError(f"No create files found in {context_paths.create_source_path}")
        if len(files) > 1:
            raise FileNotFoundError(f"Multiple create files found in {context_paths.create_source_path}")
        with open(os.path.join(context_paths.create_source_path, files[0])) as f:
            self.source_create = {files[0]: f.read()}

        # Get target_creates files
        files = os.listdir(context_paths.create_target_path)
        if len(files) == 0:
            raise FileNotFoundError(f"No create files found in {context_paths.create_target_path}")
        self.target_creates = {}
        for filename in files:
            with open(os.path.join(context_paths.create_target_path, filename)) as f:
                self.target_creates[filename] = f.read()

        # Get source_constraints files
        files = os.listdir(context_paths.constraints_source_path)
        self.source_constraints = {}
        for filename in files:
            with open(os.path.join(context_paths.constraints_source_path, filename)) as f:
                self.source_constraints[filename] = f.read()

        # Get target_constraints files
        files = os.listdir(context_paths.constraints_target_path)
        self.target_constraints = {}
        for filename in files:
            with open(os.path.join(context_paths.constraints_target_path, filename)) as f:
                self.target_constraints[filename] = f.read()

        # Get target_to_source_mapping file
        files = os.listdir(context_paths.mappings_source_path)
        if len(files) == 0:
            raise FileNotFoundError(f"No mapping files found in {context_paths.mappings_source_path}")
        if len(files) > 1:
            raise FileNotFoundError(f"Multiple mapping files found in {context_paths.mappings_source_path}")
        with open(os.path.join(context_paths.mappings_source_path, files[0])) as f:
            self.target_to_source_mapping = {files[0]: f.read()}

        # Get source_to_target_mappings files
        files = os.listdir(context_paths.mappings_target_path)
        self.source_to_target_mappings = {}
        if len(files) != len(self.target_creates):
            raise FileNotFoundError(f"Number of mapping files ({len(files)}) does not match number of target creates ({len(self.target_creates)})")
        for filename in files:
            with open(os.path.join(context_paths.mappings_target_path, filename)) as f:
                self.source_to_target_mappings[filename] = f.read()

    @classmethod
    def from_dir(cls, path: str):
        context_paths = ContextPaths.from_dir(path)
        return cls(context_paths)
