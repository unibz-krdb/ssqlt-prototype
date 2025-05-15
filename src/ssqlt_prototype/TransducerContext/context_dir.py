import os
from dataclasses import dataclass


@dataclass
class ContextDir:
    create_source_dir: str
    create_target_dir: str
    mappings_source_dir: str
    mappings_target_dir: str
    constraints_source_dir: str
    constraints_target_dir: str
    unified_dir: str
    unified_mappings_from_dir: str
    unified_mappings_to_dir: str

    def __init__(
        self,
        create_source_dir: str,
        create_target_dir: str,
        mappings_source_dir: str,
        mappings_target_dir: str,
        constraints_source_dir: str,
        constraints_target_dir: str,
        unified_dir: str,
    ) -> None:
        if not os.path.exists(create_source_dir):
            raise FileNotFoundError(f"Path {create_source_dir} does not exist.")
        if not os.path.exists(create_target_dir):
            raise FileNotFoundError(f"Path {create_target_dir} does not exist.")
        if not os.path.exists(mappings_source_dir):
            raise FileNotFoundError(f"Path {mappings_source_dir} does not exist.")
        if not os.path.exists(mappings_target_dir):
            raise FileNotFoundError(f"Path {mappings_target_dir} does not exist.")
        if not os.path.exists(constraints_source_dir):
            raise FileNotFoundError(f"Path {constraints_source_dir} does not exist.")
        if not os.path.exists(constraints_target_dir):
            raise FileNotFoundError(f"Path {constraints_target_dir} does not exist.")
        if not os.path.exists(unified_dir):
            raise FileNotFoundError(f"Path {unified_dir} does not exist.")
        self.create_source_dir = create_source_dir
        self.create_target_dir = create_target_dir
        self.mappings_source_dir = mappings_source_dir
        self.mappings_target_dir = mappings_target_dir
        self.constraints_source_dir = constraints_source_dir
        self.constraints_target_dir = constraints_target_dir
        self.unified_dir = unified_dir
        self.unified_mappings_from_dir = os.path.join(unified_dir, "mappings", "from")
        self.unified_mappings_to_dir = os.path.join(unified_dir, "mappings", "to")

    @classmethod
    def from_dir(cls, path: str):
        create_dir = os.path.join(path, "create")
        create_source_dir = os.path.join(create_dir, "source")
        create_target_dir = os.path.join(create_dir, "target")
        mappings_dir = os.path.join(path, "mappings")
        mappings_source_dir = os.path.join(mappings_dir, "source")
        mappings_target_dir = os.path.join(mappings_dir, "target")
        constraints_dir = os.path.join(path, "constraints")
        constraints_source_dir = os.path.join(constraints_dir, "source")
        constraints_target_dir = os.path.join(constraints_dir, "target")
        unified_dir = os.path.join(path, "unified")
        return cls(
            create_source_dir=create_source_dir,
            create_target_dir=create_target_dir,
            mappings_source_dir=mappings_source_dir,
            mappings_target_dir=mappings_target_dir,
            constraints_source_dir=constraints_source_dir,
            constraints_target_dir=constraints_target_dir,
            unified_dir=unified_dir,

        )
