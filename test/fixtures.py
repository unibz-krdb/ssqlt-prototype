import os
import pytest

@pytest.fixture
def resource_dir():
    path = os.path.join("test", "resources")
    if not os.path.exists(path):
        raise FileNotFoundError(f"Path {path} does not exist.")
    return path

@pytest.fixture
def input_dir(resource_dir):
    path = os.path.join(resource_dir, "input")
    if not os.path.exists(path):
        raise FileNotFoundError(f"Path {path} does not exist.")
    return path
