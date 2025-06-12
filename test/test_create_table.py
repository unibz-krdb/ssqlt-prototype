import os
from fixtures import resource_dir as resource_dir, input_dir as input_dir

from ssqlt_prototype import CreateTable
from ssqlt_prototype.TransducerContext.Dataclasses.enums import SourceTarget


def test_from_file(input_dir):
    file_path = os.path.join(input_dir, "source", "create", "transducer._empdep.sql")
    create_table = CreateTable.from_file(file_path)
    assert create_table.schema == "transducer"
    assert create_table.table == "_empdep"
    with open(file_path, "r") as f:
        assert create_table.sql == f.read().strip()
