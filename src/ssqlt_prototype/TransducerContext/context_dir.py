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
    universal_dir: str
    universal_mappings_from_dir: str
    universal_mappings_to_dir: str

    def __init__(
        self,
        create_source_dir: str,
        create_target_dir: str,
        mappings_source_dir: str,
        mappings_target_dir: str,
        constraints_source_dir: str,
        constraints_target_dir: str,
        universal_dir: str,
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
        if not os.path.exists(universal_dir):
            raise FileNotFoundError(f"Path {universal_dir} does not exist.")
        self.create_source_dir = create_source_dir
        self.create_target_dir = create_target_dir
        self.mappings_source_dir = mappings_source_dir
        self.mappings_target_dir = mappings_target_dir
        self.constraints_source_dir = constraints_source_dir
        self.constraints_target_dir = constraints_target_dir
        self.universal_dir = universal_dir
        self.universal_mappings_from_dir = os.path.join(universal_dir, "mappings", "from")
        self.universal_mappings_to_dir = os.path.join(universal_dir, "mappings", "to")

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
        universal_dir = os.path.join(path, "universal")
        return cls(
            create_source_dir=create_source_dir,
            create_target_dir=create_target_dir,
            mappings_source_dir=mappings_source_dir,
            mappings_target_dir=mappings_target_dir,
            constraints_source_dir=constraints_source_dir,
            constraints_target_dir=constraints_target_dir,
            universal_dir=universal_dir,

        )
