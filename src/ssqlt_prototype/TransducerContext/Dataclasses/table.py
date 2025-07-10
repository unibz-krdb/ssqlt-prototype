from dataclasses import dataclass
from mo_sql_parsing import parse

@dataclass
class Attr:
    name: str
    _type: str
    nullable: bool

    @classmethod
    def from_dict(cls, col: dict):
        attr_name = col["name"]
        attr_type = list(col["type"])[0]
        if col["type"][attr_type] != {}:
            attr_type = attr_type + "(" + str(col["type"][attr_type]) + ")"
        attr_nullable = col.get("nullable", True)
        return cls(name=attr_name.lower(), _type=attr_type.upper() , nullable=attr_nullable)

@dataclass
class PK:
    columns: list[str]

    @classmethod
    def from_dict(cls, pk: dict):
        if isinstance(pk["columns"], list):
            columns = [col.lower() for col in pk["columns"]]
        elif isinstance(pk["columns"], str):
            columns = [pk["columns"].lower()]
        else:
            raise ValueError("Primary key columns must be a list or a string")
        return cls(columns=columns)

@dataclass 
class FK:
    columns: list[str]
    ref_tablename: str
    ref_tableschema: str
    ref_columns: list[str]

    @classmethod
    def from_dict(cls, fk: dict):

        cols = fk["columns"]
        if isinstance(cols, list):
            columns = [col.lower() for col in cols] 
        elif isinstance(cols, str):
            columns = [cols.lower()]
        else: 
            raise ValueError("Foreign key columns must be a list or a string")
        
        references = fk["references"]
        (ref_tableschema, ref_tablename) = references["table"].lower().split(".")

        ref_cols = references["columns"]
        if isinstance(ref_cols, list):
            ref_columns = [col.lower() for col in ref_cols]
        elif isinstance(ref_cols, str):
            ref_columns = [ref_cols.lower()]
        else:
            raise ValueError("Referenced columns must be a list or a string")
        
        return cls(
            columns=columns,
            ref_tablename=ref_tablename,
            ref_tableschema=ref_tableschema,
            ref_columns=ref_columns
        )

@dataclass
class Table:
    schema: str
    name: str
    attributes: list[Attr]
    pkey: list[PK]
    fkey: list[FK]

    @classmethod
    def from_create_path(cls, path: str):
        with open(path, "r") as f:
            sql = f.read().strip()
        return cls.from_create_stmt(sql)

    @classmethod
    def from_create_stmt(cls, sql: str) -> "Table":

        parsed = parse(sql)
        if "create table" not in parsed:
            raise ValueError("Invalid CREATE TABLE statement")

        statement = parsed["create table"]

        try: 
            (schema, tablename) = statement["name"].lower().split(".")
        except ValueError:
            raise ValueError("CREATE TABLE statement must include schema and table name")

        attrs = list(map(Attr.from_dict, statement["columns"]))

        constraints = statement.get("constraint", [])
        pkeys = []
        fkeys = []
        for constraint in constraints:
            if "primary_key" in constraint:
                pkeys.append(PK.from_dict(constraint["primary_key"]))
            elif "foreign_key" in constraint:
                fkeys.append(FK.from_dict(constraint["foreign_key"]))
            else: 
                raise ValueError("Unknown constraint type in CREATE TABLE statement")

        return cls(
            schema=schema,
            name=tablename,
            attributes=list(attrs),
            pkey=pkeys,
            fkey=fkeys
        )

    def from_full_join(self, tablename: str, schema: str | None = None):
        if schema is not None:
            from_tablename = schema + "."
        from_tablename += tablename
        return f"""
SELECT {', '.join(attr.name for attr in self.attributes)} FROM {from_tablename}
"""

@dataclass
class MappedTable(Table):

    mapping: str

    @classmethod
    def from_create_path(cls, create_path: str, mapping_path: str) -> "MappedTable":
        with open(create_path, "r") as f:
            create_sql = f.read().strip()
        with open(mapping_path, "r") as f:
            mapping_sql = f.read().strip()
        return cls.from_create_stmt(create_sql=create_sql, mapping_sql=mapping_sql)

    @classmethod
    def from_create_stmt(cls, create_sql: str, mapping_sql: str) -> "MappedTable":

        tbl = Table.from_create_stmt(create_sql)

        return cls(
            schema=tbl.schema,
            name=tbl.name,
            attributes=tbl.attributes,
            pkey=tbl.pkey,
            fkey=tbl.fkey,
            mapping_sql=mapping_sql
        )



