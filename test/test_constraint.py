import os
from fixtures import resource_dir as resource_dir, single_create_input_dir as input_dir

from ssqlt_prototype import Constraint

def test_from_file(input_dir):
    file_path = os.path.join(
        input_dir, "constraints", "source", "transducer._person.cfd.1.insert.sql"
    )
    constraint = Constraint.from_file(file_path)
    assert constraint.schema == "transducer"
    assert constraint.table == "_person"
    assert constraint.type_ == "cfd"
    assert constraint.index == 1
    assert constraint.insert_delete == Constraint.InsertDelete.INSERT
    with open(file_path, "r") as f:
        assert constraint.generate_function() == f.read().strip()
