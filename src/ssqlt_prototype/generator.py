from typing import Self

from .context import Context


class Generator:
    context: Context

    def __init__(self, context: Context) -> None:
        self.context = context

    @classmethod
    def from_dir(cls, path: str) -> Self:
        context = Context.from_dir(path)
        return cls(context)
