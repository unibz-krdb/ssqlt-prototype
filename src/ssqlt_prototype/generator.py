from typing import Self

from .insert_table import InsertTable
from .delete_table import DeleteTable
from .context import Context


class Generator:
    context: Context
    insert_tabless: dict[str, InsertTable]
    delete_tables: dict[str, DeleteTable]

    def __init__(self, context: Context) -> None:
        self.context = context
        self.insert_tables = {context.source_table.table: InsertTable(context.source_table)}
        self.delete_tables = {context.source_table.table: DeleteTable(context.source_table)}
        self.schema = context.source_table.schema
        for table in context.target_tables:
            self.insert_tables[table.table] = InsertTable(table)
            self.delete_tables[table.table] = DeleteTable(table)

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

        # STEP 5: Write insert table

        transducer += "/* INSERT TABLES */\n\n"

        for table in self.insert_tables:
            insert_table = self.insert_tables[table]
            transducer += insert_table.createSql() + "\n\n"

        # STEP 6: Write delete table

        transducer += "/* DELETE TABLES */\n\n"

        for table in self.delete_tables:
            delete_table = self.delete_tables[table]
            transducer += delete_table.createSql() + "\n\n"

        # STEP 7: Loop Prevention Mechanism

        transducer += "/* LOOP PREVENTION MECHANISM */\n\n"

        transducer += f"CREATE TABLE {self.schema}._LOOP (loop_start INT NOT NULL );"


        return transducer

    def generate_to_path(self, path: str):
        with open(path, "w") as f:
            f.write(self.generate())
