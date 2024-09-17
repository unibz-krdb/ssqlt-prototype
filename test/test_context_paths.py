from ssqlt_prototype.context_paths import ContextPaths
import os

from fixtures import resource_dir as resource_dir, input_dir as input_dir

def test_from_dir(input_dir):
    context_paths = ContextPaths.from_dir(input_dir)
    assert context_paths.create_source_path == os.path.join(input_dir, "create", "source")
    assert context_paths.create_target_path == os.path.join(input_dir, "create", "target")
    assert context_paths.mappings_source_path == os.path.join(input_dir, "mappings", "source")
    assert context_paths.mappings_target_path == os.path.join(input_dir, "mappings", "target")
    assert context_paths.constraints_source_path == os.path.join(input_dir, "constraints", "source")
    assert context_paths.constraints_target_path == os.path.join(input_dir, "constraints", "target")
