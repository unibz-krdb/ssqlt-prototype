"""Test helpers for Docker-based integration tests.

Provides a SchemaInfo abstraction and utility functions that let propagation
tests be parametrized over example1 and example2 despite their different
target table names.
"""

from dataclasses import dataclass, field


SOURCE_COLUMNS = ("ssn", "empid", "name", "hdate", "phone", "email", "dept", "manager")

TARGET_ROLES = (
    "person",
    "phone",
    "email",
    "employee",
    "employee_date",
    "ped",
    "ped_dept",
    "dept_manager",
)


@dataclass
class SchemaInfo:
    """Role-based view of a compiled example's schema.

    Lets tests address target tables by semantic role instead of literal
    table name, so the same test body works for example1 and example2.
    """

    example: str
    source_table: str
    source_pk: list[str]
    mandatory_cols: list[str]
    tables: dict[str, str] = field(default_factory=dict)


EXAMPLE1 = SchemaInfo(
    example="example1",
    source_table="_person_source",
    source_pk=["ssn"],
    mandatory_cols=[],
    tables={
        "person": "_person",
        "phone": "_personphone",
        "email": "_personemail",
        "employee": "_employee",
        "employee_date": "_employeedate",
        "ped": "_ped",
        "ped_dept": "_peddept",
        "dept_manager": "_deptmanager",
    },
)


EXAMPLE2 = SchemaInfo(
    example="example2",
    source_table="_person_source",
    source_pk=["ssn", "phone", "email"],
    mandatory_cols=["ssn", "name", "phone", "email"],
    tables={
        "person": "_p",
        "phone": "_personphone",
        "email": "_personemail",
        "employee": "_pe",
        "employee_date": "_pe_hdate",
        "ped": "_ped",
        "ped_dept": "_peddept",
        "dept_manager": "_deptmanager",
    },
)


EXAMPLES = {"example1": EXAMPLE1, "example2": EXAMPLE2}


def insert_source(db, schema_info: SchemaInfo, **cols) -> None:
    """Insert a row into the source table. Unspecified columns default to NULL."""
    unknown = set(cols) - set(SOURCE_COLUMNS)
    if unknown:
        raise ValueError(f"Unknown source columns: {unknown}")
    values = [cols.get(c) for c in SOURCE_COLUMNS]
    placeholders = ", ".join(["%s"] * len(SOURCE_COLUMNS))
    db.execute(
        f"INSERT INTO transducer.{schema_info.source_table} "
        f"({', '.join(SOURCE_COLUMNS)}) VALUES ({placeholders})",
        values,
    )


def source_rows(db, schema_info: SchemaInfo) -> list[tuple]:
    """Return all rows from the source table, ordered by source PK."""
    order = ", ".join(schema_info.source_pk)
    return db.execute(
        f"SELECT {', '.join(SOURCE_COLUMNS)} "
        f"FROM transducer.{schema_info.source_table} ORDER BY {order}"
    ).fetchall()


def target_state(db, schema_info: SchemaInfo) -> dict[str, list[tuple]]:
    """Return {role: rows} for every target role. Rows are unordered."""
    state = {}
    for role, table in schema_info.tables.items():
        state[role] = db.execute(f"SELECT * FROM transducer.{table}").fetchall()
    return state


def seed_target_loop(db, n_target_inserts: int) -> None:
    """Seed the _loop table for a T->S propagation with N expected inserts.

    The target capture triggers each write -1 to _loop; when the row count
    reaches ABS(seed), TARGET_INSERT_FN fires. Protocol: seed = N + 1.
    """
    db.execute("INSERT INTO transducer._loop VALUES (%s)", (n_target_inserts + 1,))


def loop_rows(db) -> list[tuple]:
    """Return all rows currently in _loop (should be empty after propagation)."""
    return db.execute("SELECT * FROM transducer._loop").fetchall()


def dump_state(db, schema_info: SchemaInfo) -> str:
    """Multi-line dump of source + all targets + _loop; used by failure hook."""
    lines = [f"=== schema: {schema_info.example} ==="]
    lines.append(f"-- source {schema_info.source_table}")
    for row in source_rows(db, schema_info):
        lines.append(f"  {row}")
    for role, table in schema_info.tables.items():
        rows = db.execute(f"SELECT * FROM transducer.{table}").fetchall()
        lines.append(f"-- target {role} ({table}): {len(rows)} row(s)")
        for row in rows:
            lines.append(f"  {row}")
    lines.append(f"-- _loop: {loop_rows(db)}")
    return "\n".join(lines)


_LIST_BASE_TABLES_SQL = """
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'transducer' AND table_type = 'BASE TABLE'
"""


def truncate_all(db) -> None:
    """TRUNCATE every base table in the transducer schema.

    AFTER INSERT / AFTER DELETE triggers do not fire on TRUNCATE, so this
    safely resets per-test state without polluting tracking tables.
    """
    tables = [r[0] for r in db.execute(_LIST_BASE_TABLES_SQL).fetchall()]
    if not tables:
        return
    qualified = ", ".join(f"transducer.{t}" for t in tables)
    db.execute(f"TRUNCATE {qualified} CASCADE")
