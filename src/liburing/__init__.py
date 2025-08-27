from dynamic_import import importer


__version__ = '2025.08.26'


importer(exclude_dir=['lib', 'include'])
# - `importer()` helps this project manage all import needs. It auto scans for
# `*.so` files and caches import names for dynamic loading `*.so` files as needed.
# - `importer()` also makes all import names accessible at top level, regardless of
# where `*.so` files are located.
# - This helps managing the project much easy and moving files/function around
# doesn't break the project.
