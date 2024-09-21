from ssqlt_prototype.context_file_paths import ContextFilePaths

from fixtures import resource_dir as resource_dir, input_dir as input_dir


def test_from_dir(input_dir):
    _ = ContextFilePaths.from_dir(input_dir)
