import pytest

from sstc.universal_mapping import extract_join_order, extract_projection


def test_single_relation_join_order_is_single_name(example_1_ctx):
    assert extract_join_order(example_1_ctx.source.universal_mapping) == [
        "person_source"
    ]


def test_single_relation_projection_is_column_list(example_1_ctx):
    assert extract_projection(example_1_ctx.source.universal_mapping) == [
        "ssn",
        "empid",
        "name",
        "hdate",
        "phone",
        "email",
        "dept",
        "manager",
    ]


def test_multi_relation_join_order_matches_declaration(example_1_ctx):
    assert extract_join_order(example_1_ctx.target.universal_mapping) == [
        "person",
        "personphone",
        "personemail",
        "employee",
        "employeedate",
        "ped",
        "peddept",
        "deptmanager",
    ]


def test_rejects_non_assign_node():
    class Dummy:
        pass

    with pytest.raises(ValueError, match="Expected AssignNode"):
        extract_join_order(Dummy())  # type: ignore[arg-type]
