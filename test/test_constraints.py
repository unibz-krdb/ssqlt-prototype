"""Tests for constraint-generation branches not reached by the two examples.

example1 / example2 only contain *guarded* FDs and a *shared-LHS* MVD pair, so
the non-shared-LHS ``UnsupportedError`` guard and the unguarded-FD template
branch in ``constraints.py`` are never exercised by the example inputs. These
tests construct minimal synthetic contexts that hit each.

Not covered here (deliberately): the *multi-column* INC ``UnsupportedError``
guards in ``inc_sql`` (constraints.py:252) and ``inter_table_inc``
(constraints.py:139). RAPT2's grammar defines an inclusion dependency as
exactly two attributes — one column per side (``inc_expr`` in
rapt2/treebrd/grammars/dependency_grammar.py is ``attribute_name delim
attribute_name``). A multi-column INC therefore cannot be expressed in a
parseable input, so ``mid`` is always 1 and those guards are unreachable
defensive code; triggering them would require fabricating an invalid AST node.
"""

import json

import pytest

from sstc import TransducerContext
from sstc.constraints import UnsupportedError, fd_sql, mvd_sql
from sstc.context import Context, Direction
from sstc.generator import Generator


def _ctx(tmp_path, schema_attrs: list[dict], ra_body: str) -> Context:
    """Parse a Context from an inline universal schema + relational-algebra body."""
    schema_path = tmp_path / "universal.json"
    schema_path.write_text(json.dumps(schema_attrs))
    ra_path = tmp_path / "ctx.txt"
    ra_path.write_text(ra_body)
    return Context.from_file(str(schema_path), str(ra_path), Direction.SOURCE)


def _nullable(*names: str) -> list[dict]:
    return [
        {"name": n, "data_type": "VARCHAR(100)", "is_nullable": True} for n in names
    ]


def test_mvd_sql_rejects_non_shared_lhs(tmp_path):
    """Two MVDs on one table with different LHS determinants -> UnsupportedError."""
    ctx = _ctx(
        tmp_path,
        _nullable("a", "b", "c"),
        "R := \\project_{a, b, c} Universal;\n"
        "pk_{a} R;\n"
        "mvd_{a, c} R;\n"  # LHS = {a}
        "mvd_{b, c} R;\n"  # LHS = {b}  -> non-shared
        "UniversalMapping := \\project_{a, b, c} R;\n",
    )
    with pytest.raises(UnsupportedError, match="Non-shared-LHS MVDs"):
        mvd_sql(ctx, lambda *a, **k: "")


def test_fd_sql_unguarded_uses_simple_template(tmp_path):
    """A bare (unguarded) FD compiles via the simple FD template, not the CFD path.

    Both example inputs guard every FD with ``\\select_{defined(...)}``, so the
    ``else`` branch of ``fd_sql`` (constraints.py) is otherwise never reached.
    """
    ctx = _ctx(
        tmp_path,
        [
            {"name": "a", "data_type": "VARCHAR(100)", "is_nullable": False},
            {"name": "b", "data_type": "VARCHAR(100)", "is_nullable": False},
        ],
        "R := \\project_{a, b} Universal;\n"
        "pk_{a} R;\n"
        "fd_{a, b} R;\n"  # unguarded: no \select wrapper
        "UniversalMapping := \\project_{a, b} R;\n",
    )
    gen = Generator(TransducerContext(source=ctx, target=ctx))

    result = fd_sql(ctx, gen._build_guard_hierarchy(), gen._render)

    # Simple FD template: LHS-equal + RHS-differ join conditions.
    assert "r1.a = r2.a" in result
    assert "r1.b <> r2.b" in result
