import os
from dataclasses import dataclass
from .context_dir import ContextDir


@dataclass
class ContextFilePaths:
    source_creates: list[str]
    source_constraints: list[str]
    source_to_target_mappings: list[str]
    source_ordering: str

    target_creates: list[str]
    target_constraints: list[str]
    target_to_source_mappings: list[str]
    target_ordering: str

    universal_attributes: str
    universal_mappings_from: list[str]
    universal_mappings_to: list[str]
    universal_source_ordering: str
    universal_target_ordering: str

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

        # Get target_creates files
        files = os.listdir(context_paths.target_create_dir)
        if len(files) == 0:
            raise FileNotFoundError(
                f"No create files found in {context_paths.target_create_dir}"
            )
        self.target_creates = list(
            map(lambda f: os.path.join(context_paths.target_create_dir, f), files)
        )

        # Get source_constraints files
        files = os.listdir(context_paths.source_constraints_dir)
        self.source_constraints = list(
            map(lambda f: os.path.join(context_paths.source_constraints_dir, f), files)
        )

        # Get target_constraints files
        files = os.listdir(context_paths.target_constraints_dir)
        self.target_constraints = list(
            map(lambda f: os.path.join(context_paths.target_constraints_dir, f), files)
        )

        # Get source_to_target_mappings files
        files = os.listdir(context_paths.target_mappings_dir)
        if len(files) != len(self.target_creates):
            raise FileNotFoundError(
                f"Number of mapping files ({len(files)}) does not match number of target creates ({len(self.target_creates)})"
            )
        self.source_to_target_mappings = list(
            map(lambda f: os.path.join(context_paths.target_mappings_dir, f), files)
        )

        # Get target_to_source_mapping file
        files = os.listdir(context_paths.source_mappings_dir)
        if len(files) == 0:
            raise FileNotFoundError(
                f"No mapping files found in {context_paths.source_mappings_dir}"
            )
        self.target_to_source_mappings = list(
            map(lambda f: os.path.join(context_paths.source_mappings_dir, f), files)
        )

        # Get universal attributes file
        self.universal_attributes = os.path.join(
            context_paths.universal_dir, "attributes.sql"
        )

        # Get combined_from_mappings files
        files = os.listdir(context_paths.universal_mappings_from_dir)
        self.universal_mappings_from = list(
            map(
                lambda f: os.path.join(context_paths.universal_mappings_from_dir, f),
                files,
            )
        )

        # Get combined_to_mappings files
        files = os.listdir(context_paths.universal_mappings_to_dir)
        self.universal_mappings_to = list(
            map(
                lambda f: os.path.join(context_paths.universal_mappings_to_dir, f),
                files,
            )
        )

        # Get universal source ordering file
        self.universal_source_ordering = os.path.join(
            context_paths.universal_orderings_dir, "source.txt"
        )

        if not os.path.exists(self.universal_source_ordering):
            raise FileNotFoundError(
                f"Universal source ordering file not found at {self.universal_source_ordering}"
            )

        # Get universal target ordering file
        self.universal_target_ordering = os.path.join(
            context_paths.universal_orderings_dir, "target.txt"
        )
        if not os.path.exists(self.universal_target_ordering):
            raise FileNotFoundError(
                f"Universal target ordering file not found at {self.universal_target_ordering}"
            )

    @classmethod
    def from_dir(cls, path: str):
        context_paths = ContextDir.from_dir(path)
        return cls(context_paths)
