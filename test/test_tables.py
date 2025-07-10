import os
from fixtures import resource_dir as resource_dir

from ssqlt_prototype.TransducerContext.Dataclasses.table import Table, MappedTable


def test_table(resource_dir):
    create_filepath = os.path.join(resource_dir, "files", "_empdep.sql")
    tbl = Table.from_create_path(create_filepath)
    assert tbl.name == "_empdep"
    assert tbl.schema == "transducer"
    assert tbl.pkey[0].columns == ["ssn", "phone", "email"]


def test_mapped_table(resource_dir):
    create_filepath = os.path.join(resource_dir, "files", "_empdep.sql")
    tables = {"_empdep": Table.from_create_path(create_filepath)}

    create_filepath = os.path.join(resource_dir, "files", "_department.sql")
    tbl = MappedTable.from_create_path(create_filepath, tables=tables)
