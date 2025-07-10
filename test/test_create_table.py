import os
from fixtures import resource_dir as resource_dir, input_dir as input_dir

from ssqlt_prototype import CreateTable


def test_from_file(input_dir):
    create_filepath = os.path.join(input_dir, "source", "create", "transducer._empdep.sql")
    attributes_filepath = os.path.join(input_dir, "source", "attributes", "_empdep.csv")
    create_table = CreateTable.from_file(create_filepath, attributes_filepath)
    assert create_table.schema == "transducer"
    assert create_table.table == "_empdep"
    with open(create_filepath, "r") as f:
        assert create_table.sql == f.read().strip()
