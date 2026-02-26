# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
import shlex
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import pytest
from dotenv import find_dotenv, load_dotenv
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import create_database, database_exists, drop_database

#from gfmstudio.common.api.utils import get_db
#from gfmstudio.common.db.base import Base
#from gfmstudio.config import settings
#from gfmstudio.main import app
from tests.integration._support.gateway import GatewayApiClient

from .integration.utils import make_timestamped_name


# -------------------------------
# Common configurations for Integration and Unit tests
# -------------------------------
@pytest.hookimpl(tryfirst=True)
def pytest_configure(config):
    # # --- load env and set test DB (unit tests support) ---
    # load_dotenv(".env", override=True)
    # db_url = os.environ.get("DATABASE_URI", str(settings.DATABASE_URI)) + "_test"
    # settings.DATABASE_URI = db_url
    # settings.AUTH_ENABLED = False
    #
    # --- register markers (integration tests support) ---
    config.addinivalue_line(
        "markers", "integration: marks tests that hit live external services"
    )


# -------------------------------
# Unit Tests Support
# -------------------------------
def _db_session():
    db_url = str(settings.DATABASE_URI)
    if not database_exists(db_url):
        create_database(db_url)

    engine = create_engine(db_url)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return db_url, TestingSessionLocal, engine


@pytest.fixture(scope="session")
def db():
    """Fixture sets up and tears down PostgreSQL test database."""
    db_url, TestingSessionLocal, engine = _db_session()
    Base.metadata.create_all(bind=engine)

    session = TestingSessionLocal()
    yield session

    session.close_all()
    drop_database(db_url)


def override_get_db():
    try:
        _, TestingSessionLocal, _ = _db_session()
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="module")
def client(db):
    """Sets up FastAPI test client for sending HTTP requests during testing."""
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)
    return client


@pytest.fixture(scope="session")
def repo_root() -> Path:
    toplevel = (
        subprocess.check_output(shlex.split("git rev-parse --show-toplevel"))
        .decode()
        .strip()
    )
    return Path(toplevel)


def pytest_addoption(parser):
    # https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
    parser.addoption(
        "--tune-id",
        action="store",
        default=None,
        help="A ID of a geotune" "from the Fine Tune Service",
    )


@pytest.fixture(scope="session")
def tune_id(pytestconfig):
    tune_id = pytestconfig.getoption("tune_id")
    if not tune_id:
        pytest.skip("[unit] skipped due to missing tune-id")
    return tune_id


@pytest.fixture(scope="session")
def token() -> Optional[str]:
    """
    Returns a valid option for IBM Verify to authenticate. Only used for interactive
    integration tests. This value can be provided by .envrc or .env
    """
    token = os.environ.get("TOKEN")
    if not token:
        pytest.skip("[unit] skipped due to missing authentication TOKEN in environment")
    return token


# -------------------------------
# Integration Tests Support (APIs)
# -------------------------------
def _int_env(name: str, default: str | None = None, required: bool = False) -> str:
    v = os.getenv(name, default)
    if required and not v:
        pytest.skip(f"[integration] Missing env var {name}; skipping")
    return v or ""


@pytest.fixture(scope="session")
def gateway() -> GatewayApiClient:
    """
    External Gateway client.
    Requires:
      BASE_GATEWAY_URL and API_KEY in .env file
    """
    # Make sure .env is found whether you run from repo root or a subfolder
    load_dotenv(find_dotenv(usecwd=True), override=True)

    base_url = os.getenv("BASE_GATEWAY_URL")
    api_key = os.getenv("API_KEY")

    if not base_url or not api_key:
        pytest.skip("[integration] Missing BASE_GATEWAY_URL or API_KEY; skipping")

    # Normalize possible CRLF or stray quotes from copy/paste
    api_key = api_key.strip().strip('"').strip("'")
    if api_key.endswith("\r"):
        api_key = api_key[:-1]

    return GatewayApiClient(base_url=base_url, api_key=api_key)


@pytest.fixture(scope="function")
def name_factory():
    """One fixed timestamp per test so related names match."""
    fixed_now = datetime.now(timezone.utc)

    def _make(base: str, *, prefix: str | None = None, ext: str = "") -> str:
        return make_timestamped_name(base, prefix=prefix, ext=ext, now=fixed_now)

    return _make
