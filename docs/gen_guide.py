"""Write `docs/guide.md` from `docs/guide.template`: each `@@path@@` line becomes a code block with that file.

The files under `example/` are the tested ones, so the page always matches them. (A `pymdownx.snippets` include
line was rewritten by an editor's Markdown formatter, hence this plain placeholder.) Run it from the repo root before
`python3 tools/setu_docs.py`.
"""

import re
from pathlib import Path

TEMPLATE = Path("docs/guide.template")


def block(match: re.Match[str]) -> str:
    return "```python\n" + Path(match[1]).read_text().rstrip("\n") + "\n```"


Path("docs/guide.md").write_text(re.sub(r"^@@(.+)@@$", block, TEMPLATE.read_text(), flags=re.MULTILINE))
