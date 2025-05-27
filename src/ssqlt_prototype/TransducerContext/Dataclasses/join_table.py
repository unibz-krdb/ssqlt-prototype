from dataclasses import dataclass

from .create_table import CreateTable
from .universal import Universal


@dataclass
class JoinTable:
    create_table: CreateTable
    universal: Universal

    def __init__(self, create_table: CreateTable, universal: Universal) -> None:
        self.create_table = create_table
        self.universal = universal
        self.insert_tablename = create_table.table + "_INSERT_JOIN"
        self.delete_tablename = create_table.table + "_DELETE_JOIN"

    def _create_sql(self, tablename: str) -> str:
        sql = f"CREATE TABLE {self.create_table.schema}.{tablename} AS\n"
        sql += f"SELECT * FROM {self.create_table.schema}.{self.create_table.table}\n"
        sql += "WHERE 1<>1;"
        return sql

    def create_insert_sql(self) -> str:
        return self._create_sql(self.insert_tablename)

    def create_delete_sql(self) -> str:
        return self._create_sql(self.delete_tablename)

    def generate_insert_function(self) -> str:
        return self._generate_function(self.insert_tablename)

    def generate_delete_function(self) -> str:
        return self._generate_function(self.delete_tablename)

    def _generate_function(self, tablename: str) -> str:

        # Function Header
        sql = f"""CREATE OR REPLACE FUNCTION {self.create_table.schema}.{tablename}_FN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
"""

        # Create temporary table
        sql += f"""
create temporary table temp_table(
{self.universal.attributes}
);
"""

        mappings = self.universal.mappings[self.create_table.table]

        to_sql = self.universal.mappings[self.create_table.table].to_sql_template.substitute({"suffix": "_INSERT"})
        sql += f"\nINSERT INTO temp_table ({to_sql});\n"

        # Insert partners

        for partner_table in mappings.partner_table_names:
            partner_sql = self.universal.mappings[
                partner_table
            ].from_sql_template.substitute({"universal_tablename": "temp_table"})
            sql += f"\nINSERT INTO {self.create_table.schema}.{partner_table}_INSERT_JOIN ({partner_sql});"

        # Inser loop

        sql += "\nINSERT INTO transducer._loop VALUES (1);"

        # Insert into the join table

        sql += f"\nINSERT INTO {self.create_table.schema}.{tablename} ({mappings.from_sql_template.substitute({'universal_tablename': 'temp_table'})});"

        # Conclude

        sql += """\n
DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        """
        return sql
