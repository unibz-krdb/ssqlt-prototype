from ssqlt_prototype.context_files import ContextFiles

from fixtures import resource_dir as resource_dir, input_dir as input_dir

def test_from_dir(input_dir):
    _ = ContextFiles.from_dir(input_dir)
