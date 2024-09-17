import os
from fixtures import resource_dir as resource_dir, input_dir as input_dir
from string import Template

from ssqlt_prototype.mapping import Mapping

def test_from_file(input_dir):
    file_path = os.path.join(input_dir, "mappings", "target", "transducer._person._city.sql")
    mapping = Mapping.from_file(file_path)
    assert mapping.schema == "transducer"
    assert mapping.source_tables == ["_person"]
    assert mapping.target_table == "_city"
    with open(file_path, "r") as f:
        text = f.read().strip()
        subsistuted = Template(text).substitute({"S0": "_person"})
        subsistuted_new = Template(text).substitute({"S0": "NEW"})
    assert mapping.sql_template.substitute({"S0": "_person"}) == subsistuted
    assert mapping.sql(["NEW"]) == subsistuted_new
