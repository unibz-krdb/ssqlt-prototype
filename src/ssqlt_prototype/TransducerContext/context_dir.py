import os
from dataclasses import dataclass


@dataclass
class ContextDir:
    source_create_dir: str
    source_constraints_dir: str
    source_mappings_dir: str

    target_dir: str
    target_create_dir: str
    target_constraints_dir: str
    target_mappings_dir: str

    def __init__(
        self,
        source_create_dir: str,
        source_constraints_dir: str,
        source_mappings_dir: str,
        target_create_dir: str,
        target_constraints_dir: str,
        target_mappings_dir: str,
    ) -> None:
        # Source
        self.source_create_dir = source_create_dir
        self.source_constraints_dir = source_constraints_dir
        self.source_mappings_dir = source_mappings_dir

        if not os.path.exists(self.source_create_dir):
            raise FileNotFoundError(f"Path {self.source_create_dir} does not exist.")
        if not os.path.exists(self.source_constraints_dir):
            raise FileNotFoundError(
                f"Path {self.source_constraints_dir} does not exist."
            )
        if not os.path.exists(self.source_mappings_dir):
            raise FileNotFoundError(f"Path {self.source_mappings_dir} does not exist.")

        # Target
        self.target_create_dir = target_create_dir
        self.target_constraints_dir = target_constraints_dir
        self.target_mappings_dir = target_mappings_dir

        if not os.path.exists(self.target_create_dir):
            raise FileNotFoundError(f"Path {self.target_create_dir} does not exist.")
        if not os.path.exists(self.target_constraints_dir):
            raise FileNotFoundError(
                f"Path {self.target_constraints_dir} does not exist."
            )
        if not os.path.exists(self.target_mappings_dir):
            raise FileNotFoundError(f"Path {self.target_mappings_dir} does not exist.")


    @classmethod
    def from_dir(cls, path: str) -> "ContextDir":
        """Create a ContextDir instance from a given directory path."""

        # Source dirs
        source_dir = os.path.join(path, "source")
        source_create_dir = os.path.join(source_dir, "create")
        source_constraints_dir = os.path.join(source_dir, "constraints")
        source_mappings_dir = os.path.join(source_dir, "mappings")

        # Target dirs
        target_dir = os.path.join(path, "target")
        target_create_dir = os.path.join(target_dir, "create")
        target_constraints_dir = os.path.join(target_dir, "constraints")
        target_mappings_dir = os.path.join(target_dir, "mappings")

        return cls(
            source_create_dir=source_create_dir,
            source_constraints_dir=source_constraints_dir,
            source_mappings_dir=source_mappings_dir,
            target_create_dir=target_create_dir,
            target_constraints_dir=target_constraints_dir,
            target_mappings_dir=target_mappings_dir,
        )
