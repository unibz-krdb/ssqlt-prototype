from ssqlt_prototype.TransducerContext.context_dir import ContextDir
import os

from fixtures import resource_dir as resource_dir, input_dir as input_dir


def test_from_dir(input_dir):
    context_paths = ContextDir.from_dir(input_dir)
    assert context_paths.source_create_dir == os.path.join(
        input_dir, "source", "create"
    )
    assert context_paths.target_create_dir == os.path.join(
        input_dir, "target", "create"
    )
    assert context_paths.source_mappings_dir == os.path.join(
        input_dir, "source", "mappings"
    )
    assert context_paths.target_mappings_dir == os.path.join(
        input_dir, "target", "mappings"
    )
    assert context_paths.source_constraints_dir == os.path.join(
        input_dir, "source", "constraints"
    )
    assert context_paths.target_constraints_dir == os.path.join(
        input_dir, "target", "constraints"
    )
