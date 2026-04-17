import os

import pytest

from sstc import TransducerContext
from sstc.generator import Generator

from test.helpers import EXAMPLES, dump_state, truncate_all

_TEST_DIR = os.path.dirname(__file__)


def pytest_addoption(parser):
    parser.addoption(
        "--update-golden",
        action="store_true",
        default=False,
        help="Regenerate golden files instead of comparing against them.",
    )


@pytest.fixture
def update_golden(request):
    return request.config.getoption("--update-golden")


def _example_dir(name: str) -> str:
    path = os.path.join(_TEST_DIR, "inputs", name)
    if not os.path.exists(path):
        raise FileNotFoundError(f"Path {path} does not exist.")
    return path


@pytest.fixture
def example_1_dir():
    return _example_dir("example1")


@pytest.fixture
def example_2_dir():
    return _example_dir("example2")


@pytest.fixture
def example_1_ctx(example_1_dir):
    return TransducerContext.from_files(
        universal_path=os.path.join(example_1_dir, "universal.json"),
        source_path=os.path.join(example_1_dir, "source.txt"),
        target_path=os.path.join(example_1_dir, "target.txt"),
    )


@pytest.fixture
def example_2_ctx(example_2_dir):
    return TransducerContext.from_files(
        universal_path=os.path.join(example_2_dir, "universal.json"),
        source_path=os.path.join(example_2_dir, "source.txt"),
        target_path=os.path.join(example_2_dir, "target.txt"),
    )


@pytest.fixture
def example_1_gen(example_1_ctx):
    return Generator(example_1_ctx)


@pytest.fixture
def example_2_gen(example_2_ctx):
    return Generator(example_2_ctx)


# ---------------------------------------------------------------------------
# Integration test fixtures (require testcontainers + psycopg)
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def pg_container():
    pytest.importorskip("testcontainers", reason="testcontainers not installed")
    from testcontainers.postgres import PostgresContainer

    try:
        container = PostgresContainer("postgres:17", driver=None)
        container.start()
    except Exception as e:
        pytest.skip(f"Docker not available: {e}")

    yield container
    container.stop()


@pytest.fixture
def pg_conn(pg_container):
    import psycopg

    conn = psycopg.connect(pg_container.get_connection_url(), autocommit=True)
    yield conn
    conn.close()


@pytest.fixture(scope="session", params=["example1", "example2"])
def compiled_example(request):
    """Session-scoped, parametrized: compiles each example's SQL once.

    Returns (name, sql, SchemaInfo). pytest runs every test using this fixture
    once per example; the compile is cached for the session.
    """
    name = request.param
    d = _example_dir(name)
    ctx = TransducerContext.from_files(
        universal_path=os.path.join(d, "universal.json"),
        source_path=os.path.join(d, "source.txt"),
        target_path=os.path.join(d, "target.txt"),
    )
    sql = Generator(ctx).compile()
    return name, sql, EXAMPLES[name]


@pytest.fixture(scope="session")
def installed_schema(pg_container, compiled_example):
    """Install the compiled schema once per parametrized example.

    Per-test state reset is done via TRUNCATE in ``transducer_db`` — much
    cheaper than dropping/recreating ~2000 lines of DDL each test.
    """
    import psycopg

    _, sql, _ = compiled_example
    conn = psycopg.connect(pg_container.get_connection_url(), autocommit=True)
    conn.execute(sql)
    yield
    conn.execute("DROP SCHEMA IF EXISTS transducer CASCADE")
    conn.close()


@pytest.fixture
def transducer_db(pg_conn, installed_schema):
    """Per-test DB handle. Schema is pre-installed; we just TRUNCATE.

    AFTER INSERT / AFTER DELETE triggers do not fire on TRUNCATE, so tracking
    tables and _loop are safely reset without trigger side effects.
    """
    truncate_all(pg_conn)
    yield pg_conn


@pytest.fixture
def schema_info(compiled_example):
    """The SchemaInfo matching the currently-parametrized example."""
    _, _, info = compiled_example
    return info


# ---------------------------------------------------------------------------
# Failure-time state dump
# ---------------------------------------------------------------------------


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Expose per-phase test reports on the item so fixtures can inspect them."""
    outcome = yield
    rep = outcome.get_result()
    setattr(item, f"rep_{rep.when}", rep)


@pytest.fixture(autouse=True)
def _dump_on_failure(request):
    """On test failure, dump source + target + _loop state for any test using
    ``transducer_db``. Helps diagnose propagation bugs without re-running."""
    yield
    rep = getattr(request.node, "rep_call", None)
    if rep is None or not rep.failed:
        return
    if "transducer_db" not in request.fixturenames:
        return
    db = request.getfixturevalue("transducer_db")
    info = request.getfixturevalue("schema_info")
    print("\n" + dump_state(db, info))
