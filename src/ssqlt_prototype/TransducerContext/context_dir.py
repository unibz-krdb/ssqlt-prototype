import os
from dataclasses import dataclass


@dataclass
class ContextDir:
    create_source_dir: str
    create_target_dir: str
    create_universal_dir: str
    mappings_source_dir: str
    mappings_target_dir: str
    mappings_from_universal_dir: str
    mappings_to_universal_dir: str
    constraints_source_dir: str
    constraints_target_dir: str

    def __init__(
        self,
        create_source_dir: str,
        create_target_dir: str,
        create_universal_dir: str,
        mappings_source_dir: str,
        mappings_target_dir: str,
        mappings_from_universal_dir: str,
        mappings_to_universal_dir: str,
        constraints_source_dir: str,
        constraints_target_dir: str,
    ) -> None:
        self.create_source_dir = create_source_dir
        self.create_target_dir = create_target_dir
        self.create_universal_dir = create_universal_dir
        self.mappings_source_dir = mappings_source_dir
        self.mappings_target_dir = mappings_target_dir
        self.mappings_from_universal_dir = mappings_from_universal_dir
        self.mappings_to_universal_dir = mappings_to_universal_dir
        self.constraints_source_dir = constraints_source_dir
        self.constraints_target_dir = constraints_target_dir
        if not os.path.exists(self.create_source_dir):
            raise FileNotFoundError(f"Path {self.create_source_dir} does not exist.")
        if not os.path.exists(self.create_target_dir):
            raise FileNotFoundError(f"Path {self.create_target_dir} does not exist.")
        if not os.path.exists(self.create_universal_dir):
            raise FileNotFoundError(f"Path {self.create_universal_dir} does not exist.")
        if not os.path.exists(self.mappings_from_universal_dir):
            raise FileNotFoundError(
                f"Path {self.mappings_from_universal_dir} does not exist."
            )
        if not os.path.exists(self.mappings_to_universal_dir):
            raise FileNotFoundError(
                f"Path {self.mappings_to_universal_dir} does not exist."
            )
        if not os.path.exists(self.mappings_source_dir):
            raise FileNotFoundError(f"Path {self.mappings_source_dir} does not exist.")
        if not os.path.exists(self.mappings_target_dir):
            raise FileNotFoundError(f"Path {self.mappings_target_dir} does not exist.")
        if not os.path.exists(self.constraints_source_dir):
            raise FileNotFoundError(f"Path {self.constraints_source_dir} does not exist.")
        if not os.path.exists(constraints_target_dir):
            raise FileNotFoundError(f"Path {self.constraints_target_dir} does not exist.")


    @classmethod
    def from_dir(cls, path: str):
        create_dir = os.path.join(path, "create")
        create_source_dir = os.path.join(create_dir, "source")
        create_target_dir = os.path.join(create_dir, "target")
        create_universal_dir = os.path.join(create_dir, "universal")
        mappings_dir = os.path.join(path, "mappings")
        mappings_source_dir = os.path.join(mappings_dir, "source")
        mappings_target_dir = os.path.join(mappings_dir, "target")
        mappings_from_universal_dir = os.path.join(mappings_dir, "universal", "from")
        mappings_to_universal_dir = os.path.join(mappings_dir, "universal", "to")
        constraints_dir = os.path.join(path, "constraints")
        constraints_source_dir = os.path.join(constraints_dir, "source")
        constraints_target_dir = os.path.join(constraints_dir, "target")
        return cls(
            create_source_dir=create_source_dir,
            create_target_dir=create_target_dir,
            create_universal_dir=create_universal_dir,
            mappings_source_dir=mappings_source_dir,
            mappings_target_dir=mappings_target_dir,
            mappings_from_universal_dir=mappings_from_universal_dir,
            mappings_to_universal_dir=mappings_to_universal_dir,
            constraints_source_dir=constraints_source_dir,
            constraints_target_dir=constraints_target_dir,
        )
