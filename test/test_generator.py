from fixtures import resource_dir as resource_dir, input_dir as input_dir

from ssqlt_prototype.generator import Generator

def test_from_dir(input_dir):
    generator = Generator.from_dir(input_dir)
    generator.generate_to_path("output.sql")
