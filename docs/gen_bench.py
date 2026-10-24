"""Publish `example/bench/bench.md` (the latest benchmark run) as the `bench.md` page: one source, no copy to keep."""

from pathlib import Path
import mkdocs_gen_files

with mkdocs_gen_files.open("bench.md", "w") as out:
    out.write(Path("example/bench/bench.md").read_text())
