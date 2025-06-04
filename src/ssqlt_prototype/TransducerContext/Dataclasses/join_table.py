from dataclasses import dataclass
from typing import Literal

from .constraint import Constraint
from .create_table import CreateTable
from .universal import Universal
from .enums import SourceTarget


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
        return self._generate_function(self.insert_tablename, insert_delete=Constraint.InsertDelete.INSERT)

    def generate_delete_function(self) -> str:
        return self._generate_function(self.delete_tablename, insert_delete=Constraint.InsertDelete.DELETE)

    def _generate_function(self, tablename: str, insert_delete: Constraint.InsertDelete) -> str:

        if self.create_table.source_target == SourceTarget.SOURCE:
            ordering = self.universal.source_ordering
        else:
            ordering = self.universal.target_ordering

        if insert_delete == Constraint.InsertDelete.INSERT:
            suffix = "_INSERT"
            ordering = list(reversed(ordering))
        else:
            suffix = "_DELETE"

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

        to_sql = self.universal.mappings[self.create_table.table].to_sql_template.substitute({"suffix": suffix})
        sql += f"\nINSERT INTO temp_table ({to_sql});\n"

        # Insert partners

        for partner_table in ordering[:-1]:
            partner_sql = self.universal.mappings[
                partner_table
            ].from_sql_template.substitute({"universal_tablename": "temp_table"})
            sql += f"\nINSERT INTO {self.create_table.schema}.{partner_table}{suffix}_JOIN ({partner_sql});"

        # Inser loop

        sql += "\nINSERT INTO transducer._loop VALUES (1);"

        # Insert into the join table

        partner_sql = self.universal.mappings[
            ordering[-1]
        ].from_sql_template.substitute({"universal_tablename": "temp_table"})
        sql += f"\nINSERT INTO {self.create_table.schema}.{ordering[-1]}{suffix}_JOIN ({partner_sql});"

        # Conclude

        sql += """\n
DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        """
        return sql

    def generate_trigger(self, tablename: str, _type: Literal["INSERT"] | Literal["DELETE"]) -> str:
        sql = f"""CREATE TRIGGER {tablename}_trigger
AFTER INSERT ON {self.create_table.schema}.{self.create_table.table}_{_type}
FOR EACH ROW
EXECUTE FUNCTION {self.create_table.schema}.{tablename}_fn();
        """
        return sql

    def generate_insert_trigger(self) -> str:
        return self.generate_trigger(self.insert_tablename, "INSERT")

    def generate_delete_trigger(self) -> str:
        return self.generate_trigger(self.delete_tablename, "DELETE")
