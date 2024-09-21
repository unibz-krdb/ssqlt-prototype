from typing import Self

from .context import Context


class Generator:
    context: Context
    insert_tabless: dict[str, str]
    delete_tables: dict[str, str]

    def __init__(self, context: Context) -> None:
        self.context = context
        self.insert_tables = {context.source_table.table: context.source_table.table + "_INSERT"}
        self.delete_tables = {context.source_table.table: context.source_table.table + "_DELETE"}
        self.schema = context.source_table.schema
        for table in context.target_tables:
            self.insert_tables[table.table] = table.table + "_INSERT"
            self.delete_tables[table.table] = table.table + "_DELETE"

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
            transducer += f"CREATE TABLE {self.schema}.{insert_table} AS\nSELECT * FROM {self.schema}.{table}\nWHERE 1<>1;\n\n"

        # STEP 6: Write delete table

        transducer += "/* DELETE TABLES */\n\n"

        for table in self.delete_tables:
            delete_table = self.delete_tables[table]
            transducer += f"CREATE TABLE {self.schema}.{delete_table} AS\nSELECT * FROM {self.schema}.{table}\nWHERE 1<>1;\n\n"

        # STEP 7: Loop Prevention Mechanism

        transducer += "/* LOOP PREVENTION MECHANISM */\n\n"

        transducer += f"CREATE TABLE {self.schema}._LOOP (loop_start INT NOT NULL );"


        return transducer

    def generate_to_path(self, path: str):
        with open(path, "w") as f:
            f.write(self.generate())
