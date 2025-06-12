from fixtures import resource_dir as resource_dir, input_dir as input_dir

from ssqlt_prototype import Context


def test_from_dir(input_dir):
    _ = Context.from_dir(input_dir)
