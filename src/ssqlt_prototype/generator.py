from typing import Self

from .TransducerContext import Context, InsertTable, DeleteTable


class Generator:
    context: Context
    insert_tables: dict[str, InsertTable]
    delete_tables: dict[str, DeleteTable]

    def __init__(self, context: Context) -> None:
        self.context = context
        self.insert_tables = {}
        self.delete_tables = {}

        for table in context.source_tables:
            self.schema = table.schema

            mapping = next(
                mapping
                for mapping in context.source_mappings
                if mapping.target_table.lower() == table.table.lower()
            )
            self.insert_tables[table.table] = InsertTable(source=table, mapping=mapping)
            self.delete_tables[table.table] = DeleteTable(source=table)

        for table in context.target_tables:
            mapping = next(
                mapping
                for mapping in context.target_mappings
                if mapping.target_table.lower() == table.table.lower()
            )
            self.insert_tables[table.table] = InsertTable(source=table, mapping=mapping)
            self.delete_tables[table.table] = DeleteTable(source=table)

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

        transducer += "/* SOURCE TABLES */\n\n"

        for table in self.context.source_tables:
            transducer += table.sql + "\n\n"

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
            transducer += insert_table.create_sql() + "\n\n"
            transducer += insert_table.join_create_sql() + "\n\n"

        # STEP 6: Write delete table

        transducer += "/* DELETE TABLES */\n\n"

        for table in self.delete_tables:
            delete_table = self.delete_tables[table]
            transducer += delete_table.createSql() + "\n\n"
            transducer += delete_table.join_create_sql() + "\n\n"

        # STEP 7: Loop Prevention Mechanism

        transducer += "/* LOOP PREVENTION MECHANISM */\n\n"

        transducer += (
            f"CREATE TABLE {self.schema}._LOOP (loop_start INT NOT NULL );\n\n"
        )

        # STEP 8: Write insert functions

        transducer += f"/* INSERT FUNCTIONS & TRIGGERS */\n\n"

        for table in self.insert_tables:
            insert_table = self.insert_tables[table]
            transducer += insert_table.generate_function() + "\n\n"
            transducer += insert_table.generate_trigger() + "\n\n"

        # STEP 9: Write delete functions

        transducer += f"/* DELETE FUNCTIONS & TRIGGERS */\n\n"

        for table in self.insert_tables:
            delete_table = self.delete_tables[table]
            transducer += delete_table.generate_function() + "\n\n"
            transducer += delete_table.generate_trigger() + "\n\n"

        # STEP 10: Write complex source functions

        transducer += f"/* COMPLEX SOURCE */\n\n"

        transducer += f"/* S->T INSERTS */\n"
        transducer += self.context.generate_source_insert()

        transducer += f"\n/* T->S DELETE */\n"
        transducer += self.context.generate_target_delete()

        return transducer

    def generate_to_path(self, path: str):
        with open(path, "w") as f:
            f.write(self.generate())
