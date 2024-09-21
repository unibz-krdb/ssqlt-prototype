from dataclasses import dataclass

from .create_table import CreateTable


@dataclass
class DeleteTable:
    source: CreateTable
    schema: str
    table: str

    def __init__(self, source: CreateTable) -> None:
        self.source = source
        self.table = source.table + "_DELETE"

    def createSql(self) -> str:
        sql = f"CREATE TABLE {self.source.schema}.{self.table} AS\n"
        sql += f"SELECT * FROM {self.source.schema}.{self.source.table}\n"
        sql += "WHERE 1<>1;"
        return sql
