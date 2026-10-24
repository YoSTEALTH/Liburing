import ast
import importlib
import pathlib
from liburing import *


def public(names):
    return {name for name in names if not name.startswith("_")}


def stub_names(path):
    names = []
    for node in ast.parse(path.read_text()).body:
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
            names.append(node.name)
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            names.append(node.target.id)
        elif isinstance(node, ast.Assign):
            names.extend(target.id for target in node.targets if isinstance(target, ast.Name))
    return names


def test_stub_matches_module():
    # `liburing.pyi` (Setu's stub generator) names exactly what the extension module has.
    module = importlib.import_module("liburing.liburing")
    stub = stub_names(pathlib.Path(module.__file__).with_name("liburing.pyi"))
    assert len(stub) == len(set(stub))  # no name twice
    assert public(stub) == public(dir(module))
    assert "__version__" in stub
