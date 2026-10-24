"""Griffe extension: turn the stub docstrings into Markdown.

The Zig `///` docs are `Description`, then sections: a header on its own line (`Example`, `Note`, `Type`, `Flags`, ...)
with its content indented 4 spaces. Markdown reads that as code and quotes, so each section is rewritten:
`Note` / `Warning` become admonitions, `Example` (and a bare `>>>` session) a `pycon` block, anything else a
`text` block.
"""

import ast
import re
import textwrap
import griffe

HEADER = re.compile(r"[A-Z][A-Za-z ]*")
ADMONITION = {"Note": "note", "Warning": "warning"}


def convert(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if HEADER.fullmatch(line) and i + 1 < len(lines) and lines[i + 1].startswith(" "):
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j].startswith(" ")):
                j += 1
            block = textwrap.dedent("\n".join(lines[i + 1 : j])).strip("\n")
            if line in ADMONITION:
                out += [f'!!! {ADMONITION[line]} "{line}"', "", textwrap.indent(block, "    "), ""]
            else:
                out += [f"**{line}**", "", "```pycon" if line == "Example" else "```text", block, "```", ""]
            i = j
        elif line.startswith(">>>"):  # a bare session, no `Example` header: up to the next blank line
            j = i
            while j < len(lines) and lines[j].strip():
                j += 1
            out += ["```pycon", *lines[i:j], "```"]
            i = j
        else:
            out.append(line)
            i += 1
    return "\n".join(out).strip("\n")


def raw_docstring(node) -> str | None:
    """The docstring as written: griffe's `value` has the section indent stripped (`inspect.cleandoc`).

    Griffe loads the module twice, the stub (an `ast` node) and the compiled module (`__doc__`); both get converted.
    """
    if isinstance(node, ast.AST):
        raw = ast.get_docstring(node, clean=False)  # type: ignore[arg-type]
        if raw is None:
            return None
        first, *rest = raw.split("\n")
        base = " " * (node.col_offset + 4)  # the docstring's own indent
        return "\n".join([first, *(line.removeprefix(base) for line in rest)])
    doc = getattr(getattr(node, "obj", None), "__doc__", None)
    return doc if isinstance(doc, str) else None


class Markdown(griffe.Extension):
    def on_instance(self, *, node, obj, agent=None, **kwargs) -> None:
        if obj.docstring is not None and (raw := raw_docstring(node)) is not None:
            obj.docstring.value = convert(raw)
