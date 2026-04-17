from rapt2.treebrd.node import (
    FunctionalDependencyNode,
    MultivaluedDependencyNode,
)


def test_context(example_1_ctx):
    transducer_ctx = example_1_ctx

    source_ctx = transducer_ctx.source
    assert len(source_ctx.tables) == 1
    assert source_ctx.schema.to_dict() == {
        "person_source": [
            "ssn",
            "empid",
            "name",
            "hdate",
            "phone",
            "email",
            "dept",
            "manager",
        ]
    }


def test_context_direction(example_1_ctx):
    assert example_1_ctx.source.direction == "source"
    assert example_1_ctx.target.direction == "target"


def test_context_primary_keys(example_1_ctx):
    src_pks = example_1_ctx.source.primary_keys
    assert "person_source" in src_pks
    assert src_pks["person_source"] == ["ssn"]

    tgt_pks = example_1_ctx.target.primary_keys
    assert "person" in tgt_pks
    assert tgt_pks["person"] == ["ssn"]
    assert tgt_pks["personphone"] == ["ssn", "phone"]


def test_context_constraint_nodes(example_1_ctx):
    src = example_1_ctx.source
    assert len(src.functional_dependencies) == 3
    assert all(
        isinstance(fd, FunctionalDependencyNode) for fd in src.functional_dependencies
    )
    assert len(src.multivalued_dependencies) == 2
    assert all(
        isinstance(m, MultivaluedDependencyNode) for m in src.multivalued_dependencies
    )

    tgt = example_1_ctx.target
    assert len(tgt.inclusion_equivalences) == 5
    assert len(tgt.inclusion_subsumptions) == 3


def test_example2_context_primary_keys(example_2_ctx):
    """Example2 composite PK (ssn, phone, email) correctly parsed."""
    assert example_2_ctx.source.primary_keys["person_source"] == [
        "ssn",
        "phone",
        "email",
    ]


def test_example2_context_nullability(example_2_ctx):
    """Example2 mixed nullability: 4 mandatory, 4 nullable."""
    schema = example_2_ctx.source.universal_schema
    mandatory = [a.name for a in schema if not a.is_nullable]
    nullable = [a.name for a in schema if a.is_nullable]
    assert set(mandatory) == {"ssn", "name", "phone", "email"}
    assert set(nullable) == {"empid", "hdate", "dept", "manager"}


def test_mixed_case_schema_names_normalized(tmp_path):
    """Attribute names from JSON should be lowercased to match RAPT2 output."""
    import json
    from sstc.context import Context, Direction

    # Write a minimal universal schema with mixed case
    schema_path = tmp_path / "universal.json"
    schema_path.write_text(
        json.dumps(
            [
                {"name": "SSN", "data_type": "VARCHAR(100)", "is_nullable": False},
                {"name": "Name", "data_type": "VARCHAR(100)", "is_nullable": False},
            ]
        )
    )

    # Write a minimal RA file (Dependency Grammar uses := and ; terminators)
    ra_path = tmp_path / "source.txt"
    ra_path.write_text(
        "T1 := \\project_{SSN, Name} Universal;\n"
        "pk_{SSN} T1;\n"
        "UniversalMapping := \\project_{SSN, Name} T1;\n"
    )

    ctx = Context.from_file(str(schema_path), str(ra_path), Direction.SOURCE)
    # RAPT2 lowercases: table attributes should be ['ssn', 'name']
    assert ctx.tables[0].attributes == ["ssn", "name"]
    # Schema dict names should also be lowercase
    for attr in ctx.universal_schema:
        assert attr.name == attr.name.lower(), f"Expected lowercase, got {attr.name}"


def test_universal_mapping_constant_exists():
    """The reserved mapping name should be a module-level constant."""
    from sstc.context import UNIVERSAL_MAPPING_NAME

    assert UNIVERSAL_MAPPING_NAME == "universalmapping"


def test_target_universal_mapping_join_order_matches_declared_tables(example_1_ctx):
    target = example_1_ctx.target
    assert target.universal_mapping_join_order == [
        "person",
        "personphone",
        "personemail",
        "employee",
        "employeedate",
        "ped",
        "peddept",
        "deptmanager",
    ]
    assert sorted(target.universal_mapping_join_order) == sorted(
        t.name for t in target.tables
    )


def test_source_universal_mapping_join_order_is_single_table(example_1_ctx):
    assert example_1_ctx.source.universal_mapping_join_order == ["person_source"]


def test_from_file_rejects_universal_mapping_missing_declared_table(tmp_path):
    """If a declared table is missing from UniversalMapping, from_file must raise."""
    import json
    import pytest
    from sstc.context import Context, Direction

    schema_path = tmp_path / "universal.json"
    schema_path.write_text(
        json.dumps(
            [
                {"name": "ssn", "data_type": "VARCHAR(100)", "is_nullable": False},
                {"name": "name", "data_type": "VARCHAR(100)", "is_nullable": False},
            ]
        )
    )
    ra_path = tmp_path / "source.txt"
    ra_path.write_text(
        "T1 := \\project_{ssn, name} Universal;\n"
        "T2 := \\project_{ssn} Universal;\n"
        "pk_{ssn} T1;\n"
        "pk_{ssn} T2;\n"
        "UniversalMapping := \\project_{ssn, name} T1;\n"
    )
    with pytest.raises(ValueError, match="UniversalMapping tables"):
        Context.from_file(str(schema_path), str(ra_path), Direction.SOURCE)
