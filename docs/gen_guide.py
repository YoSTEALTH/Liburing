"""Build `guide.md` from `guide.template`: each `@@path@@` line becomes a code block with that file.

The files under `example/` are the tested ones, so the page always matches them. (A `pymdownx.snippets` include
line was rewritten by an editor's Markdown formatter, hence this plain placeholder.)
"""

import re
from pathlib import Path
import mkdocs_gen_files

TEMPLATE = Path("docs/guide.template")


def block(match: re.Match[str]) -> str:
    return "```python\n" + Path(match[1]).read_text().rstrip("\n") + "\n```"


with mkdocs_gen_files.open("guide.md", "w") as out:
    out.write(re.sub(r"^@@(.+)@@$", block, TEMPLATE.read_text(), flags=re.MULTILINE))
