"""Tests for the optional explanatory-comment layer in generated SQL.

The ``comments`` flag on :class:`~sstc.generator.Generator` adds three layers
of SQL comments (section banners, per-object headers, inline body comments)
without changing any emitted statement. These tests pin both halves of that
contract: the comments appear when requested, and they are *purely additive*
(stripping them reproduces the default, uncommented output line-for-line).
"""

import os
import sys

import pytest

from sstc import Transducer, TransducerContext
from sstc.generator import Generator

_TEST_DIR = os.path.dirname(__file__)


def _example_paths(name: str) -> list[str]:
    input_dir = os.path.join(_TEST_DIR, "inputs", name)
    return [
        os.path.join(input_dir, "universal.json"),
        os.path.join(input_dir, "source.txt"),
        os.path.join(input_dir, "target.txt"),
    ]


# The eight pipeline-section banner titles, in dependency order. Each must
# surface as a banner header line when comments are enabled.
SECTION_TITLES = [
    "SCHEMA PREAMBLE",
    "BASE TABLES",
    "REJECT UPDATES",
    "INTER-TABLE INCLUSION",
    "CONSTRAINTS",
    "CHANGE TRACKING",
    "JOIN STAGING",
    "BIDIRECTIONAL MAPPING",
]


def _compile(name: str, *, comments: bool) -> str:
    input_dir = os.path.join(_TEST_DIR, "inputs", name)
    ctx = TransducerContext.from_files(
        universal_path=os.path.join(input_dir, "universal.json"),
        source_path=os.path.join(input_dir, "source.txt"),
        target_path=os.path.join(input_dir, "target.txt"),
    )
    return Generator(ctx, comments=comments).compile()


def _meaningful_lines(sql: str) -> list[str]:
    """Return SQL lines that carry statements: non-blank and not comment-only."""
    return [
        line
        for line in sql.splitlines()
        if line.strip() and not line.lstrip().startswith("--")
    ]


@pytest.mark.parametrize("example", ["example1", "example2"])
def test_comments_are_purely_additive(example):
    """Enabling comments must not alter any emitted SQL statement."""
    commented = _compile(example, comments=True)
    plain = _compile(example, comments=False)
    assert _meaningful_lines(commented) == _meaningful_lines(plain)


@pytest.mark.parametrize("example", ["example1", "example2"])
def test_commented_output_adds_lines(example):
    """The commented variant must actually contain more lines than the plain one."""
    commented = _compile(example, comments=True)
    plain = _compile(example, comments=False)
    assert len(commented.splitlines()) > len(plain.splitlines())


@pytest.mark.parametrize("example", ["example1", "example2"])
def test_all_section_banners_present(example):
    """Every pipeline section gets a banner when comments are enabled."""
    commented = _compile(example, comments=True)
    for i, title in enumerate(SECTION_TITLES, 1):
        assert f"SECTION {i}: {title}" in commented, f"missing banner for {title}"


@pytest.mark.parametrize("example", ["example1", "example2"])
def test_default_output_has_no_banners(example):
    """Default output stays uncommented: no banner rules, no section headers."""
    plain = _compile(example, comments=False)
    assert "-- ====" not in plain
    for i in range(1, len(SECTION_TITLES) + 1):
        assert f"SECTION {i}:" not in plain


@pytest.mark.parametrize("example", ["example1", "example2"])
def test_per_object_and_inline_comments_present(example):
    """All three comment layers show up: banner rule, per-object headers, inline."""
    commented = _compile(example, comments=True)
    assert "-- ====" in commented  # banner rule (layer 1)
    assert "Shadow" in commented  # tracking-table per-object header (layer 2)
    assert "Capture" in commented  # capture-function per-object header (layer 2)
    assert "loop guard" in commented  # inline body comment (layer 3)


def test_transducer_threads_comments_flag():
    """Transducer.compile forwards the comments flag to the Generator."""
    transducer = Transducer.from_file(*_example_paths("example1"))
    assert "SECTION 1: SCHEMA PREAMBLE" in transducer.compile(comments=True)
    assert "SECTION 1:" not in transducer.compile()


def test_cli_comments_flag_enables_banners(capsys, monkeypatch):
    """`sstc ... --comments` emits the commented script to stdout."""
    from sstc.__main__ import main

    monkeypatch.setattr(
        sys, "argv", ["sstc", *_example_paths("example1"), "--comments"]
    )
    main()
    out = capsys.readouterr().out
    assert "SECTION 1: SCHEMA PREAMBLE" in out


def test_cli_defaults_to_uncommented(capsys, monkeypatch):
    """Without --comments the CLI emits the default, uncommented script."""
    from sstc.__main__ import main

    monkeypatch.setattr(sys, "argv", ["sstc", *_example_paths("example1")])
    main()
    out = capsys.readouterr().out
    assert "SECTION 1:" not in out
    assert "-- ====" not in out
