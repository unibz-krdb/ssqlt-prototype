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

    def _generate_function(self, tablename: str) -> str:

        # Function Header
        sql = f"""
        CREATE OR REPLACE FUNCTION {self.create_table.schema}.{tablename}_FN()
        RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
        BEGIN
        """

        # Create temporary table
        sql += f"""
        create temporary table temp_table(
        {self.universal.attributes}
        );
        """

        # Insert into temp table
        #to_sql = self.universal.mappings[self.createTable.source.table].to_sql_template.substitute()
        #sql += f""" {to_sql} + "\n"
        #"""

        """
INSERT INTO temp_table (
SELECT ssn, name, phone, email, dep_name, dep_address, city, country
FROM transducer._POSITION_INSERT
NATURAL LEFT OUTER JOIN transducer._EMPDEP

);

INSERT INTO transducer._EMPDEP_INSERT_JOIN (SELECT ssn, name, phone, email, dep_name, dep_address FROM temp_table);
INSERT INTO transducer._loop VALUES (1);
INSERT INTO transducer._POSITION_INSERT_JOIN (SELECT dep_address, city, country FROM temp_table);

DELETE FROM temp_table;
DROP TABLE temp_table;
RETURN NEW;
END;  $$;
        """
        return sql
