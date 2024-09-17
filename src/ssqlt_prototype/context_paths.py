import os
from dataclasses import dataclass


@dataclass
class ContextPaths:
    create_source_path: str
    create_target_path: str
    mappings_source_path: str
    mappings_target_path: str
    constraints_source_path: str
    constraints_target_path: str

    def __init__(
        self,
        create_source_path: str,
        create_target_path: str,
        mappings_source_path: str,
        mappings_target_path: str,
        constraints_source_path: str,
        constraints_target_path: str,
    ) -> None:
        if not os.path.exists(create_source_path):
            raise FileNotFoundError(f"Path {create_source_path} does not exist.")
        if not os.path.exists(create_target_path):
            raise FileNotFoundError(f"Path {create_target_path} does not exist.")
        if not os.path.exists(mappings_source_path):
            raise FileNotFoundError(f"Path {mappings_source_path} does not exist.")
        if not os.path.exists(mappings_target_path):
            raise FileNotFoundError(f"Path {mappings_target_path} does not exist.")
        if not os.path.exists(constraints_source_path):
            raise FileNotFoundError(f"Path {constraints_source_path} does not exist.")
        if not os.path.exists(constraints_target_path):
            raise FileNotFoundError(f"Path {constraints_target_path} does not exist.")

    @classmethod
    def from_dir(cls, path: str):
        create_path = os.path.join(path, "create")
        create_source_path = os.path.join(create_path, "source")
        create_target_path = os.path.join(create_path, "target")
        mappings_path = os.path.join(path, "mappings")
        mappings_source_path = os.path.join(mappings_path, "source")
        mappings_target_path = os.path.join(mappings_path, "target")
        constraints_path = os.path.join(path, "constraints")
        constraints_source_path = os.path.join(constraints_path, "source")
        constraints_target_path = os.path.join(constraints_path, "target")
        return cls(
            create_source_path=create_source_path,
            create_target_path=create_target_path,
            mappings_source_path=mappings_source_path,
            mappings_target_path=mappings_target_path,
            constraints_source_path=constraints_source_path,
            constraints_target_path=constraints_target_path,
        )
