from typing import Self

from .TransducerContext import Context, DeleteTable, InsertTable, JoinTable


class Generator:
    context: Context
    insert_tables: dict[str, InsertTable]
    delete_tables: dict[str, DeleteTable]
    join_tables: dict[str, JoinTable]

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

        self.join_tables = {}
        for create_table in self.context.source_tables + self.context.target_tables:
            self.join_tables[create_table.table] = JoinTable(
                create_table=create_table,
                universal=self.context.universal,
            )

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
            transducer += self.insert_tables[table].create_sql() + "\n\n"
            transducer += self.join_tables[table].create_insert_sql() + "\n\n"

        # STEP 6: Write delete table

        transducer += "/* DELETE TABLES */\n\n"

        for table in self.delete_tables:
            transducer += self.delete_tables[table].create_sql() + "\n\n"
            transducer += self.join_tables[table].create_delete_sql() + "\n\n"

        # STEP 7: Loop Prevention Mechanism

        transducer += "/* LOOP PREVENTION MECHANISM */\n\n"

        transducer += (
            f"CREATE TABLE {self.schema}._LOOP (loop_start INT NOT NULL );\n\n"
        )

        # STEP 8: Write insert functions

        transducer += "/* INSERT FUNCTIONS & TRIGGERS */\n\n"

        for table in self.insert_tables:
            insert_table = self.insert_tables[table]
            transducer += insert_table.generate_function() + "\n"
            transducer += insert_table.generate_trigger() + "\n\n"
            join_table = self.join_tables[table]
            transducer += join_table.generate_insert_function() + "\n"
            transducer += join_table.generate_insert_trigger() + "\n\n"

        # STEP 9: Write delete functions

        transducer += "/* DELETE FUNCTIONS & TRIGGERS */\n\n"

        for table in self.insert_tables:
            delete_table = self.delete_tables[table]
            transducer += delete_table.generate_function() + "\n"
            transducer += delete_table.generate_trigger() + "\n\n"
            join_table = self.join_tables[table]
            transducer += join_table.generate_delete_function() + "\n"
            transducer += join_table.generate_delete_trigger() + "\n\n"

        # STEP 10: Write complex source functions

        transducer += "/* COMPLEX SOURCE */\n\n"

        transducer += "/* S->T INSERTS */\n"
        transducer += self.context.generate_source_insert()

        transducer += "\n/* T->S DELETE */\n"
        transducer += self.context.generate_target_delete()

        return transducer

    def generate_to_path(self, path: str):
        with open(path, "w") as f:
            f.write(self.generate())
