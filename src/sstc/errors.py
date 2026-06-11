"""Shared exception types for the SSTC pipeline.

Leaf module: importable from anywhere (including other leaf modules such as
``guard``) without creating dependency cycles. ``constraints`` re-exports
``UnsupportedError`` for backwards compatibility.
"""


class UnsupportedError(Exception):
    """Raised when the generator encounters a constraint pattern it cannot compile."""

    pass
