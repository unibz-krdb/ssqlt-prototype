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

    def generate(self) -> str:
        transducer = ""

        ##########
        # SOURCE #
        ##########

        # STEP 1: Write source table create

        transducer += "/* SOURCE TABLE */\n\n"

        transducer += self.context.source_table.sql + "\n\n"

        # STEP 2: Write source constraints

        transducer += "/* SOURCE CONSTRAINTS */\n\n"

        for constraint in self.context.source_constraints:
            transducer += constraint.generate_function() + "\n\n"
            transducer += constraint.generate_trigger() + "\n\n\n"

        # STEP 3: Write target table creates

        transducer += "/* TARGET TABLES */\n\n"

        for table in self.context.target_tables:
            transducer += table.sql + "\n\n"

        # STEP 4: Write target table constraints

        transducer += "/* TARGET CONSTRAINTS */\n\n"

        for constraint in self.context.target_constraints:
            transducer += constraint.generate_function() + "\n\n"
            transducer += constraint.generate_trigger() + "\n\n\n"

        return transducer

    def generate_to_path(self, path: str):
        with open(path, "w") as f:
            f.write(self.generate())
