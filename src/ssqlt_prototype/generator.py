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

        for tablename, table in context.source.tables.items():
            self.schema = table.schema

            mapping = context.source.mappings[tablename]
            self.insert_tables[tablename] = InsertTable(source=table, mapping=mapping)
            self.delete_tables[tablename] = DeleteTable(source=table)

        for tablename, table in context.target.tables.items():
            mapping = context.target.mappings[tablename]
            self.insert_tables[tablename] = InsertTable(source=table, mapping=mapping)
            self.delete_tables[tablename] = DeleteTable(source=table)

        self.join_tables = {}
        for create_table in list(self.context.source.tables.values()) + list(
            self.context.target.tables.values()
        ):
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

        for source_tablename in self.context.source.dep_orderings:
            table = self.context.source.tables[source_tablename]
            transducer += table.sql + "\n\n"

        # STEP 2: Write source constraints

        transducer += "/* SOURCE CONSTRAINTS */\n\n"

        for constraints in self.context.source.constraints.values():
            for constraint in constraints:
                transducer += constraint.generate_function() + "\n\n"
                transducer += constraint.generate_trigger() + "\n\n\n"

        # STEP 3: Write target table creates

        transducer += "/* TARGET TABLES */\n\n"

        for target_tablename in self.context.target.dep_orderings:
            table = self.context.target.tables[target_tablename]
            transducer += table.sql + "\n\n"

        # STEP 4: Write target table constraints

        transducer += "/* TARGET CONSTRAINTS */\n\n"

        for constraints in self.context.target.constraints.values():
            for constraint in constraints:
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
        transducer += self.context.generate_target_insert()

        transducer += "/* T->S INSERTS */\n"
        transducer += self.context.generate_source_insert()

        return transducer

    def generate_to_path(self, path: str):
        with open(path, "w") as f:
            f.write(self.generate())
