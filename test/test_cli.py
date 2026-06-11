"""Tests for the ``sstc`` command-line entry point (``sstc.__main__:main``).

Covers the output paths and error handling that the comments-focused CLI
tests in ``test_comments.py`` do not: writing to a ``-o`` file, and exiting
non-zero (with a message on stderr) when an input is missing or unparseable.
"""

import json
import os
import sys

import pytest

from sstc.__main__ import main

_TEST_DIR = os.path.dirname(__file__)


def _example_paths(name: str) -> list[str]:
    input_dir = os.path.join(_TEST_DIR, "inputs", name)
    return [
        os.path.join(input_dir, "universal.json"),
        os.path.join(input_dir, "source.txt"),
        os.path.join(input_dir, "target.txt"),
    ]


def test_cli_writes_output_file(tmp_path, monkeypatch, capsys):
    """``sstc ... -o FILE`` writes the compiled SQL to FILE and not to stdout."""
    out = tmp_path / "out.sql"
    monkeypatch.setattr(
        sys, "argv", ["sstc", *_example_paths("example1"), "-o", str(out)]
    )

    main()

    captured = capsys.readouterr()
    assert out.exists()
    sql = out.read_text()
    assert "CREATE SCHEMA transducer" in sql
    assert "SOURCE_INSERT_FN" in sql
    # When -o is given, nothing is written to stdout.
    assert captured.out == ""


def test_cli_missing_input_file_exits_1(tmp_path, monkeypatch, capsys):
    """A nonexistent input path makes the CLI exit(1) with an error on stderr."""
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "sstc",
            str(tmp_path / "nope.json"),
            str(tmp_path / "missing_source.txt"),
            str(tmp_path / "missing_target.txt"),
        ],
    )

    with pytest.raises(SystemExit) as exc:
        main()

    assert exc.value.code == 1
    assert "Error:" in capsys.readouterr().err


def test_cli_invalid_input_exits_1(tmp_path, monkeypatch, capsys):
    """A relational-algebra file the parser rejects makes the CLI exit(1).

    The source file omits the reserved ``UniversalMapping`` assignment, so
    ``Context.from_file`` raises ``ValueError`` and ``main`` converts it to a
    clean non-zero exit instead of a traceback.
    """
    universal = tmp_path / "universal.json"
    universal.write_text(
        json.dumps([{"name": "a", "data_type": "VARCHAR(100)", "is_nullable": False}])
    )
    source = tmp_path / "source.txt"
    source.write_text(
        "T1 := \\project_{a} Universal;\npk_{a} T1;\n"
    )  # no UniversalMapping
    target = tmp_path / "target.txt"
    target.write_text(
        "T1 := \\project_{a} Universal;\npk_{a} T1;\n"
        "UniversalMapping := \\project_{a} T1;\n"
    )
    monkeypatch.setattr(sys, "argv", ["sstc", str(universal), str(source), str(target)])

    with pytest.raises(SystemExit) as exc:
        main()

    assert exc.value.code == 1
    assert "Error:" in capsys.readouterr().err
