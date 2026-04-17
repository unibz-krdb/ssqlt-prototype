import pytest

from sstc.context import Context, Direction
from sstc.universal_mapping import extract_join_order, extract_projection


def test_single_relation_join_order_is_single_name():
    ctx = Context.from_file(
        "test/inputs/example1/universal.json",
        "test/inputs/example1/source.txt",
        direction=Direction.SOURCE,
    )
    assert extract_join_order(ctx.universal_mapping) == ["person_source"]


def test_single_relation_projection_is_column_list():
    ctx = Context.from_file(
        "test/inputs/example1/universal.json",
        "test/inputs/example1/source.txt",
        direction=Direction.SOURCE,
    )
    assert extract_projection(ctx.universal_mapping) == [
        "ssn",
        "empid",
        "name",
        "hdate",
        "phone",
        "email",
        "dept",
        "manager",
    ]


def test_multi_relation_join_order_matches_declaration():
    ctx = Context.from_file(
        "test/inputs/example1/universal.json",
        "test/inputs/example1/target.txt",
        direction=Direction.TARGET,
    )
    assert extract_join_order(ctx.universal_mapping) == [
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
