import os
from fixtures import resource_dir as resource_dir

from ssqlt_prototype.TransducerContext.Dataclasses.table import Table


def test_table(resource_dir):  # noqa: F811
    create_filepath = os.path.join(resource_dir, "files", "_empdep.sql")
    mapping_filepath = os.path.join(resource_dir, "files", "mapping.sql")
    tbl = Table.from_create_path(create_filepath, mapping_path=mapping_filepath)
    assert tbl.name == "_empdep"
    assert tbl.schema == "transducer"
    assert tbl.pkey[0].columns == ["ssn", "phone", "email"]
