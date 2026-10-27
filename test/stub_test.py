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
    # `__init__.pyi` (Setu's stub generator) names exactly what the extension module has.
    module = importlib.import_module("liburing")
    stub = stub_names(pathlib.Path(module.__file__).with_name("__init__.pyi"))
    assert len(stub) == len(set(stub))  # no name twice
    assert public(stub) == public(dir(module))
    assert "__version__" in stub


def test_package_is_the_extension():
    # The extension is the package itself (`liburing/__init__.so`): no `__init__.py`, no `liburing.liburing`.
    package = importlib.import_module("liburing")
    assert pathlib.Path(package.__file__).name == "__init__.so"
    assert package.__path__ == [str(pathlib.Path(package.__file__).parent)]
    assert package.Ring is Ring
    assert "liburing" not in public(dir(package))
