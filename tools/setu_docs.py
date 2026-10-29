'''Documentation site for a Zig + Setu extension: static HTML built from the imported module's docstrings (the
`///` docs Setu turns into them), Markdown pages of the project, and a runner for the `>>>` examples.

Kept in Setu (`tools/setu_docs.py`) and copied unchanged into each project that uses Setu
(`zig build setu-docs-sync` / `setu-docs-check`, see `addSetuDocsSteps` in Setu's `build.zig`). Project settings
go in `pyproject.toml`, never in a copy. Python standard library only; the site's behaviour (search, Run, the ◐ menu,
Copy, the repository facts, the source views) is Zig compiled to WebAssembly (Setu's `tools/setu_docs_web.zig`, built
by the project's `zig build docs-web`), and `app.js` is a fixed loop that runs the module's commands. The HTML has
every element those need, hidden, and is the page as it is without the module: `file://` pages can not load
`.wasm`, so served the site has search, Run and the rest; from disk it is the static HTML.

Usage (after `zig build develop`, from the project root)
    python3 tools/setu_docs.py                    # build the site into `out` (runs `zig build docs-web`)
    python3 tools/setu_docs.py build --out DIR    # ... somewhere else
    python3 tools/setu_docs.py serve              # serve it on http://127.0.0.1:8000, Run buttons enabled
    python3 tools/setu_docs.py run read           # run the `read` example, print the session
    python3 tools/setu_docs.py run read:2         # ... only its second `Example` block
    python3 tools/setu_docs.py run --json File.read
    python3 tools/setu_docs.py run example/hi.py  # run an example script
    python3 tools/setu_docs.py check              # run every example, report mismatches
    python3 tools/setu_docs.py --config other/pyproject.toml build

The settings, in `pyproject.toml` (paths relative to it):

    [tool.setu_docs]
    module = 'pkg.pkg'              # the module documented (imported after `path`)
    path = ['src']                  # optional: put on `sys.path` (and `PYTHONPATH` of Run) first
    stub = 'src/pkg/pkg.pyi'        # optional: typed signatures, and `llms-full.txt`
    name = 'pkg'                    # optional: the site's name (default: the module's last part)
    version = 'build.zig.zon'       # optional: show its `.version` (default: the module's `__version__`)
    summary = 'io_uring for Python' # optional: the home page's lead and `llms.txt`'s summary
    out = 'site'                    # optional: where the site goes (the default)
    home = 'docs/index.md'          # optional: the home page's text (default: the module docstring)
    css = 'docs/extra.css'          # optional: appended to `style.css` (colors: `--accent`, ...)
    favicon = 'docs/icon.svg'       # optional: the tab icon (`.svg`, `.png`, `.ico`; default: the name's letter)
    edit = 'https://github.com/me/pkg/edit/dev/'  # optional: an Edit link on Markdown pages (+ the file)
    repo = 'https://github.com/me/pkg'  # optional: the header's repository link (default: from `[project.urls]`)
    scripts = 'example'             # optional: runnable example scripts, a page of their own
    scripts_skip = ['server.py']    # optional: scripts shown but not run
    featured = 'example/hi.py'      # optional: a script on the home page, with a Run box
    runner = 'asyncio:run'          # optional: runs a coroutine an example statement returns (the default)
    hooks = 'tools/docs_hooks.py'   # optional: fixtures and tables for the examples (below)
    serial = true                   # optional: the server runs one example at a time (the default)
    timeout = 20                    # optional: seconds an example may take
    coverage = 'zig-out/coverage.json'  # optional: a Coverage page from `zig build coverage`'s result (below)
    coverage_history = 'docs/coverage-history.json'  # optional: its history chart (`zig build coverage`'s `.history`)
    profile = 'zig-out/profile.json'    # optional: a Profile page (`serve` only) from `zig build profile` (below)

    [[tool.setu_docs.markdown]]     # Markdown pages, in nav order
    file = 'docs/install.md'
    title = 'Install'
    section = 'Guide'               # optional: a nav heading (consecutive pages with one share it)
    slug = 'install'                # optional: the page name (default: the file's stem)
    split = true                    # optional: a page per `##` chapter (`<slug>-<title>`), listed under this one;
                                    # this page keeps the text before the first `##` and a list of the chapters

    [[tool.setu_docs.pages]]        # API pages, in this order; a name goes on the first that claims it
    slug = 'ring'
    title = 'Ring and setup'
    text = 'Create, configure and tear down a `Ring`.'
    classes = ['Ring', 'Param']                     # exact class names
    functions = ['probe']                           # exact function names
    patterns = ['^io_uring_(queue_|setup)']         # `re.search` on function names
    sources = ['src/pkg/ring.zig']                  # the `pub` names (and `setu.Class(Name, ...)`) of files

    [[tool.setu_docs.pages]]
    slug = 'types'
    title = 'Types'
    text = 'Everything else.'
    default = true                  # exactly one: the names no page claims

    [[tool.setu_docs.pages]]
    slug = 'constants'
    title = 'Constants'
    text = 'Grouped by prefix.'
    constants = true                # at most one: the module's values that are not classes or functions
    groups = ['IORING_OP_', 'O_']   # optional: prefixes, first match wins (default: up to the first `_`;
                                    # a group of one goes under `Other`)

The footer also reads `[project]`: `urls.Homepage` (the name links to it) and `requires-python` (`>=3.14` shows as
`CPython 3.14+`); each is left out when missing. The header's top right links the repository: `repo = 'https://
github.com/me/pkg'` in `[tool.setu_docs]`, else the first GitHub URL of `urls.Repository`, `.Source`, `.Homepage`;
a GitHub one shows `me/pkg` with its latest release, stars and forks (the page asks GitHub's API, once a session).

The header's ◐ button opens the theme menu: Nord Day, Nord Night (Snow Storm, Polar Night), Tokyo Day, Tokyo Night; the
browser remembers the choice (`<html data-palette="nord" data-theme="dark">`). Until one is made the theme is Tokyo
Day, or Nord Night when the system is dark. A `css` file can override any color: page `--bg`, `--panel`, `--line`,
`--text`, `--muted`, `--accent`, ...; code `--kw` (keywords), `--bi` (builtins), `--str`, `--num`, `--com` (comments),
`--ref` (API names, linked), `--code-fg` (code text; else `--text`), `--con` (`None` / `True` / ...; else `--num`),
`--ty` (a `class` name; else `--bi`), `--dec` (decorators; else `--kw`), `--fn` (a `def` name, a call, an API name in
code), `--slf` (`self` / `cls` / a dunder), `--attr` (attributes), `--arg` (`name=` in brackets), `--op` (operators;
these last five else the text's).

Markdown: headings (with anchors), paragraphs, `-` / `1.` lists, `>` quotes, GFM tables, fenced code (python, pycon, sh
and c highlighted, zig by `docs.wasm`, every block with a Copy button), inline code, links (`page.md` -> its page),
images, `**bold**`, `*em*`, raw HTML blocks. An inline code span naming an export links to its entry. A line `@@path@@`
is replaced by that file (from the project's root) as a fenced code block, the language from its suffix: a page shows a
tested example script as it is, with no generated copy.

A table right after a `<!-- chart -->` line is drawn as a bar chart (GitHub still shows the table): a bar per row,
labeled by the first column, its length the first column of numbers (`627,427`, `**627k**`, `48 ns`), its color the
row's group (the label's first word; up to 8 colors, the rest `Other`). Options, all optional:
`<!-- chart value="req/s" group="^(C \\w+|\\w+)" -->`: the column, and a regex whose match (or first group) on the
label is the group.

The hooks file is plain Python; each of these is optional:

    FIXTURES = {}   # example name -> `[async] def setup(ns)`, run first in the example's namespace `ns`
    SKIP = {}       # (example name, statement) -> why it is not run
    LOOSE = set()   # (example name, statement): output differs per run; run, not compared
    NAMESPACE = {}  # extra names every example sees

`ns['_keep']` takes objects to `close()` after the example, `ns['_cleanup']` callables to call. Every example runs
in a new temporary directory; fds it leaves open are closed after. An example without a fixture that reads a name
nothing defines (`ring`: not the module's, a builtin, in `NAMESPACE` or assigned in the example) gets no Run button
and is not run by `check`, which lists those names instead.

A repeated `Example` header starts another block (`Sqe()`, then `Sqe(2)`, ...; a first `# comment` line labels
it): each block is shown with its own Run and runs on its own, in a new namespace with the name's fixture run
again. Setu numbers the headers in the docstring (`help()` shows `Example #1`, `Example #2`, ...; one block stays
`Example`); the page and the Markdown show them as written. `run Sqe` runs every block, `run Sqe:2` the one headed
`Example #2`.

The Coverage page (`coverage`: the JSON of Setu's `tools/check_coverage.py`, merged over the interpreters it ran)
shows the line coverage of the project's Zig code under its tests, a section per owner: the project's files (a
donut, with `coverage_history` (`check_coverage.py --history`) a chart of the total per version beside it, a row per
file, lowest first, with its missed lines by function: a function Python has links to its entry, one
none of whose lines ran says `never run`, each range linked to the file on GitHub at the run's `commit` when the run
was on a tree as committed; where the interpreters ran different lines of a file, each one's count),
then each dependency's (a file whose path does not
start with a directory of the project, Setu's `setu/src/args.zig`): how much of it the project's tests run, the
total with the project's code, each interpreter's run, its files. A dependency shows as the `name` in the
`[tool.setu_docs]` of its own `pyproject.toml` (Setu's: `Setu`), else as its package name. A click on a file's row
shows its source under it, Zig highlighted, covered lines green and missed red (`docs.wasm` renders it; static, on
any HTTP server, not from `file://`): the site copies each source to `source/<path>`, a dependency's found through
the project's `build.zig.zon` (`.path`, else `zig-pkg/<.hash>`). A source whose CRC-32 is not the one measured
(`crc32` in the JSON) is flagged `changed`. Without the file (no kcov in CI) the page is left out.

The Profile page (`profile`: the JSON of Setu's `tools/check_profile.py`) shows the instructions one call of each case
costs (callgrind): a row per case, a bar per interpreter, its dark part the extension's own code. A click on a case
shows, under it, the extension's files the call runs in, costliest first, each file's source Zig highlighted, every
costly line with its instructions per call and shaded by them (`docs.wasm` renders it), scrolled to the costliest. It
is a local tool: only `serve` has it, made per request from the file as it is (rerun `zig build profile`, reload),
its sources served at `source/<path>`; its nav item shows only on a live page. `build` writes no Profile page, so a
published site (CI) never needs the file.

The site also gets `llms.txt` (an index of the pages, for AI readers) and, with `stub`, `llms-full.txt` (every
class, function and constant with its signature and docstring, one Markdown page). A build records what it wrote
in `.setu-docs-files` in the site's folder; the next one removes what it no longer writes (a page or source gone),
so an old file is not served or deployed. Files it never wrote stay.

Example
    >>> sections('Read it.\\n\\nType\\n    return: int\\n')
    {'': 'Read it.', 'Type': 'return: int'}
'''

import argparse
import ast
import builtins
import collections
import contextlib
import dataclasses
import datetime
import html
import http.server
import importlib
import importlib.util
import inspect
import io
import json
import keyword
import os
import pathlib
import re
import shutil
import signal
import subprocess
import symtable
import sys
import tempfile
import textwrap
import threading
import tomllib
import urllib.parse
import zlib

SETU_DOCS = pathlib.Path(__file__).resolve()
HEADER = re.compile(r'Example #\d+|[A-Z][A-Za-z ]*')  # Setu numbers repeated `Example` headers
EXAMPLE = re.compile(r'Example(?: #\d+)?')

# --- settings ---------------------------------------------------------------------------------

KEYS = {'module', 'path', 'stub', 'name', 'version', 'summary', 'out', 'home', 'css', 'favicon', 'edit', 'repo',
        'scripts', 'scripts_skip', 'featured', 'runner', 'hooks', 'serial', 'timeout', 'coverage',
        'coverage_history', 'profile', 'markdown', 'pages'}  # fmt: skip
FAVICON_TYPES = ('.svg', '.png', '.ico')
PAGE_KEYS = {'slug', 'title', 'text', 'classes', 'functions', 'patterns', 'sources', 'default', 'constants', 'groups'}
MARKDOWN_KEYS = {'file', 'title', 'section', 'slug', 'split'}


def fail(msg):
    raise SystemExit(f'setu_docs: {msg}')


def zon_version(path):
    '''The `.version` of the `build.zig.zon` at `path`.

    Example
        >>> zon_version(pathlib.Path('build.zig.zon'))  # it has `.version = "2026.10.28",`
        '2026.10.28'
    '''
    try:
        text = re.sub(r'//.*', '', path.read_text())
    except OSError as e:
        fail(f'`version`: {e.strerror}: {path}')
    found = re.search(r'^\s*\.version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if not found:
        fail(f'`version`: no `.version = "..."` in {path}')
    return found[1]


def load_config(pyproject='pyproject.toml'):
    '''`[tool.setu_docs]` of `pyproject`, checked.'''
    path = pathlib.Path(pyproject)
    config = tomllib.loads(path.read_text()).get('tool', {}).get('setu_docs')
    if config is None:
        fail(f'no [tool.setu_docs] in {path}')
    if unknown := set(config) - KEYS:
        fail(f'[tool.setu_docs]: unknown key {sorted(unknown)}')
    for key in ('module', 'pages'):
        if key not in config:
            fail(f'[tool.setu_docs] needs `{key}`')
    if 'favicon' in config and pathlib.Path(config['favicon']).suffix not in FAVICON_TYPES:
        fail(f'`favicon` is not one of {", ".join(FAVICON_TYPES)}: {config["favicon"]}')
    pages = config['pages']
    for page in pages:
        for key in ('slug', 'title', 'text'):
            if key not in page:
                fail(f'every page needs `{key}`: {page}')
        if unknown := set(page) - PAGE_KEYS:
            fail(f'page {page["slug"]}: unknown key {sorted(unknown)}')
    for page in config.get('markdown', ()):
        if 'file' not in page or 'title' not in page:
            fail(f'every Markdown page needs `file` and `title`: {page}')
        if unknown := set(page) - MARKDOWN_KEYS:
            fail(f'Markdown page {page["file"]}: unknown key {sorted(unknown)}')
    slugs = [p['slug'] for p in pages] + [md_slug(p) for p in config.get('markdown', ())]
    if len(set(slugs)) != len(slugs):
        fail('a page slug twice')
    if {'index', 'examples', 'coverage', 'profile'} & set(slugs):
        fail('`index`, `examples`, `coverage` and `profile` are taken (the home page, the example scripts, ...)')
    if sum(bool(p.get('default')) for p in pages) != 1:
        fail('exactly one page needs `default = true`')
    if sum(bool(p.get('constants')) for p in pages) > 1:
        fail('at most one page can have `constants = true`')
    return config


INCLUDE = re.compile(r'^@@(.+)@@$', re.MULTILINE)
FENCE_LANGUAGES = {'.py': 'python', '.sh': 'sh', '.c': 'c', '.h': 'c', '.zig': 'zig', '.toml': 'toml'}


def include_files(text, root):
    '''Each `@@path@@` line of the Markdown `text` as a fenced code block of that file (`path` from the project's
    root `root`, the language from its suffix), so a page shows a tested file as it is.

    Example
        >>> include_files('Run:\n@@example/hi.py@@\n', pathlib.Path('test/docs')).splitlines()[:2]
        ['Run:', '```python']
    '''

    def block(m):
        path = root / m[1].strip()
        try:
            code = path.read_text().rstrip('\n')
        except OSError as e:
            fail(f'`@@{m[1]}@@`: {e.strerror}: {path}')
        if '```' in code:
            fail(f'`@@{m[1]}@@`: the file has a ``` line, which would end the code block')
        return f'```{FENCE_LANGUAGES.get(path.suffix, "")}\n{code}\n```'

    return INCLUDE.sub(block, text)


def md_slug(page):
    return page.get('slug') or pathlib.Path(page['file']).stem


def heading_id(title):
    '''A heading's id before it is made unique on its page: lower case, punctuation dropped, spaces as `-`.

    Example
        >>> heading_id('11. Checks')
        '11-checks'
    '''
    return re.sub(r'[\s]+', '-', re.sub(r'[^\w\s-]', '', title.lower()).strip()) or 'section'


def chapters(text):
    '''A `split` Markdown page's `text` as `(intro, [(title, text), ...])`: a chapter per level 2 heading outside
    code blocks, its headings one level up (its `##` is its page's `#`).

    Example
        >>> chapters('# G\nHi.\n## 1. One\nA.\n### Sub\n```\n## no\n```\n')
        ('# G\nHi.', [('1. One', '# 1. One\nA.\n## Sub\n```\n## no\n```')])
    '''
    intro, parts, fence = [], [], None
    for line in text.splitlines():
        if fence:
            if line.strip().startswith(fence):
                fence = None
        elif m := FENCE.match(line):
            fence = m.group(2)
        elif (m := HEADING.match(line)) and len(m.group(1)) >= 2:
            if len(m.group(1)) == 2:
                parts.append((m.group(2), []))
            if parts:
                line = line[1:]
        (parts[-1][1] if parts else intro).append(line)
    return '\n'.join(intro).strip('\n'), [(title, '\n'.join(lines).strip('\n')) for title, lines in parts]


def letter_icon(name):
    '''The tab icon without a `favicon`: `name`'s first letter, white on the dark theme's `--accent-soft` (an icon
    is its own document, so no CSS variables), as a `data:` URL.'''
    letter = html.escape(next((c for c in name if c.isalnum()), '?').upper())
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6"'
        ' fill="#283457"/><text x="16" y="17" text-anchor="middle" dominant-baseline="central" fill="#fff"'
        f' font-family="system-ui, sans-serif" font-size="22" font-weight="700">{letter}</text></svg>'
    )
    return 'data:image/svg+xml,' + urllib.parse.quote(svg, safe=' "=/:,')


class Project:
    '''A project's settings, its imported module and its hooks.'''

    def __init__(self, pyproject='pyproject.toml'):
        self.pyproject = pathlib.Path(pyproject).resolve()
        self.root = self.pyproject.parent
        self.config = load_config(self.pyproject)
        self.path = [str(self.root / p) for p in self.config.get('path', ())]
        for entry in reversed(self.path):
            if entry not in sys.path:
                sys.path.insert(0, entry)
        self.module = importlib.import_module(self.config['module'])
        self.name = self.config.get('name', self.config['module'].rpartition('.')[2])
        self.version = getattr(self.module, '__version__', '')
        if 'version' in self.config:  # a `build.zig.zon`: its `.version` (the module may be a test or a stand-in)
            self.version = zon_version(self.root / self.config['version'])
        # `[project]`: the footer links the name to `Homepage` and gives `requires-python` (`>=3.14` -> `3.14+`)
        meta = tomllib.loads(self.pyproject.read_text()).get('project', {})
        self.homepage = meta.get('urls', {}).get('Homepage', '')
        # the header's repository link: `repo`, else the first GitHub one of `[project.urls]`
        urls = meta.get('urls', {})
        repo = self.config.get('repo') or next(
            (u for k in ('Repository', 'Source', 'Homepage') if GITHUB.fullmatch(u := urls.get(k, ''))), ''
        )
        self.repo = repo.rstrip('/').removesuffix('.git')
        self.repo_name = m.group(1) if (m := GITHUB.fullmatch(repo)) else ''
        requires = meta.get('requires-python', '').replace(' ', '')
        self.requires = f'{requires[2:]}+' if re.fullmatch(r'>=[\d.]+', requires) else requires
        self.timeout = self.config.get('timeout', 20)
        self.stub = (self.root / self.config['stub']).read_text() if 'stub' in self.config else None
        # the site's copy of `favicon` (`favicon.svg`, ...), else '' (`letter_icon`, inline: no `/favicon.ico` 404)
        self.favicon = 'favicon' + pathlib.Path(self.config['favicon']).suffix if 'favicon' in self.config else ''
        if self.favicon and not (self.root / self.config['favicon']).is_file():
            fail(f'`favicon` not found: {self.config["favicon"]}')
        hooks = self.load_hooks()
        self.fixtures = getattr(hooks, 'FIXTURES', {})
        self.skip = getattr(hooks, 'SKIP', {})
        self.loose = getattr(hooks, 'LOOSE', set())
        self.namespace = getattr(hooks, 'NAMESPACE', {})
        module, _, attr = self.config.get('runner', 'asyncio:run').partition(':')
        self.runner = getattr(importlib.import_module(module), attr)

    def load_hooks(self):
        if 'hooks' not in self.config:
            return None
        path = self.root / self.config['hooks']
        spec = importlib.util.spec_from_file_location(f'_setu_docs_hooks_{path.stem}', path)
        hooks = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(hooks)
        return hooks

    def out(self):
        return self.root / self.config.get('out', 'site')

    def env(self):
        '''The environment Run's child processes get: `path` on `PYTHONPATH`.'''
        paths = [*self.path, *filter(None, [os.environ.get('PYTHONPATH')])]
        return {**os.environ, 'PYTHONPATH': os.pathsep.join(paths), 'PYTHON_COLORS': '0'}

    def scripts(self):
        '''The example scripts (paths relative to the root) and whether Run may start them.'''
        if 'scripts' not in self.config:
            return []
        skip = set(self.config.get('scripts_skip', ()))
        folder = self.root / self.config['scripts']
        return [(str(p.relative_to(self.root)), p.name not in skip) for p in sorted(folder.glob('*.py'))]

    def find(self, name):
        '''`'read'` -> `module.read`, `'File.read'` -> `module.File.read`.'''
        obj = self.module
        for part in name.split('.'):
            obj = getattr(obj, part)
        return obj

    # -- the API, grouped by page

    def exported(self):
        return [n for n in dir(self.module) if not n.startswith('_') and not inspect.ismodule(getattr(self.module, n))]

    def is_constant(self, name):
        obj = getattr(self.module, name)
        return not callable(obj) and not inspect.ismodule(obj)

    def sources(self, page):
        '''The `pub` names of a page's `sources`, in file order: `pub fn` / `pub const` / `setu.Class(Name`.'''
        names = []
        for source in page.get('sources', ()):
            text = (self.root / source).read_text()
            for m in re.finditer(r'^pub (?:fn|const|var) (\w+)|setu\.Class\((\w+)', text, re.MULTILINE):
                names.append(m.group(1) or m.group(2))
        return names

    def api(self):
        '''`[(page, [name, ...])]` for the pages without `constants`, and the constants.'''
        exported = self.exported()
        constants = [n for n in exported if self.is_constant(n)]
        pages = [p for p in self.config['pages'] if not p.get('constants')]
        claimed = {p['slug']: self.sources(p) for p in pages}
        order = {}
        if self.stub:
            for node in ast.parse(self.stub).body:
                if isinstance(node, ast.ClassDef | ast.FunctionDef):
                    order.setdefault(node.name, len(order))
        names = {p['slug']: [] for p in pages}
        for name in exported:
            if name in constants:
                continue
            kind = 'class' if isinstance(getattr(self.module, name), type) else 'def'
            names[page_of(pages, kind, name, claimed)].append(name)
        for page in pages:
            source = {n: i for i, n in reversed(list(enumerate(claimed[page['slug']])))}
            names[page['slug']].sort(key=lambda n: (source.get(n, len(source)), order.get(n, len(order)), n))
        return [(p, names[p['slug']]) for p in pages], constants

    def examples(self):
        '''Every documented name with an `Example` section: `read`, `File.read`, ...'''
        out = []
        for _page, names in self.api()[0]:
            for name in names:
                obj = self.find(name)
                if example_blocks(obj.__doc__):
                    out.append(name)
                if isinstance(obj, type) and not issubclass(obj, BaseException):
                    for member, _kind, mobj in members(obj):
                        if example_blocks(getattr(mobj, '__doc__', None)):
                            out.append(f'{name}.{member}')
        return out

    def blocks(self, name):
        '''The `Example` blocks of the documented name `name` (`example_blocks`).'''
        return example_blocks(self.find(name).__doc__)

    def needs(self, name, example=None):
        '''The names `name`'s example block `example` (default: each block, merged) reads that nothing gives it,
        sorted: not the module's, a builtin, in `NAMESPACE` or assigned at the block's top level (a name a
        function, lambda, class body or comprehension binds is its own; skipped statements left out). With a
        fixture: none, the fixture sets them up.'''
        if name in self.fixtures:
            return []
        if example is None:
            return sorted({n for block in self.blocks(name) for n in self.needs(name, block)})
        sources = []
        for step in steps(example):
            if (name, step.source) not in self.skip:
                with contextlib.suppress(SyntaxError):  # running it reports the error (`check`, Run)
                    compile(step.source + '\n', '<example>', 'exec', flags=ast.PyCF_ONLY_AST | FLAGS)
                    sources.append(step.source)
        # the statements as one `async def` body: `symtable` refuses a top-level `await`
        body = textwrap.indent('\n'.join(sources) or 'pass', ' ', lambda line: True)
        try:
            table = symtable.symtable(f'async def _example():\n{body}\n', '<example>', 'exec')
        except SyntaxError:  # `nonlocal x`, ...: running it reports the error
            return []
        top = next(t for t in table.get_children() if t.get_name() == '_example')
        defined = {s.get_name() for s in top.get_symbols() if s.is_local()}
        defined |= {'__name__', '_keep', '_cleanup', '_name'} | set(vars(self.module)) | set(self.namespace)
        defined |= set(dir(builtins))
        read, todo = set(), [top]
        while todo:
            scope = todo.pop()
            todo += scope.get_children()
            read |= {s.get_name() for s in scope.get_symbols() if s.is_referenced() and s.is_global()}
        return sorted(read - defined)


def page_of(pages, kind, name, claimed=None):
    '''The slug of the page that lists the class or function `name`: the first claiming it, else the default.'''
    for page in pages:
        if kind == 'class' and name in page.get('classes', ()):
            return page['slug']
        if kind == 'def' and (
            name in page.get('functions', ()) or any(re.search(rx, name) for rx in page.get('patterns', ()))
        ):
            return page['slug']
        if claimed and name in claimed.get(page['slug'], ()):
            return page['slug']
    return next(p['slug'] for p in pages if p.get('default'))


def constant_group(page, name):
    '''The heading a constant goes under: the first of the page's `groups` it starts with (`O_*`), else the
    part before its first `_`.'''
    for prefix in page.get('groups', ()):
        if name.startswith(prefix):
            return prefix.rstrip('_') + ('_*' if prefix.endswith('_') else '*')
    head, sep, _ = name.partition('_')
    return f'{head}_*' if sep else name


def members(cls):
    '''`[(name, kind, obj)]` of a class's own public attributes: `method`, `property` or `value`.'''
    out = []
    for name, obj in vars(cls).items():
        if name.startswith('_'):
            continue
        if isinstance(obj, classmethod | staticmethod):
            obj, kind = obj.__func__, 'method'  # 3.14's wrapper of a builtin has no `__doc__` of its own
        elif inspect.isdatadescriptor(obj):
            kind = 'property'
        elif callable(obj):
            kind = 'method'
        else:
            kind = 'value'
        out.append((name, kind, obj))
    return out


# --- docstring parsing ------------------------------------------------------------------------


def parts(doc):
    '''Split a docstring into its description and `Header` sections (content dedented 4), in order; a header
    may repeat (one `Example` per block, numbered `Example #1`, `Example #2`, ... by Setu).

    Example
        >>> parts('Read it.\\n\\nExample #1\\n    >>> 1\\n    1\\nExample #2\\n    >>> 2\\n    2\\n')
        [('', 'Read it.'), ('Example #1', '>>> 1\\n1'), ('Example #2', '>>> 2\\n2')]
    '''
    out = [('', [])]
    for line in (doc or '').splitlines():
        if line and not line[0].isspace() and HEADER.fullmatch(line.strip()) and line.strip() != line.strip().upper():
            out.append((line.strip(), []))
        else:
            out[-1][1].append(line[4:] if out[-1][0] and line.startswith('    ') else line)
    return [(k, '\n'.join(v).strip('\n')) for k, v in out]


def sections(doc):
    '''`parts` as a dict: a repeated header keeps its first section (`example_blocks` gives every `Example`).

    Example
        >>> sections('Read it.\\n\\nType\\n    return: int\\n')
        {'': 'Read it.', 'Type': 'return: int'}
    '''
    out = {}
    for header, text in parts(doc):
        out.setdefault(header, text)
    return out


def example_blocks(doc):
    '''The docstring's `Example` (`Example #<n>`) sections that are not empty, in order: each runs on its own.'''
    return [text for header, text in parts(doc) if EXAMPLE.fullmatch(header) and text.strip()]


@dataclasses.dataclass
class Step:
    '''One `>>>` statement of an example and the output written below it.'''

    source: str
    expected: str
    got: str = ''
    status: str = ''  # ok, fail, loose (output not compared), skip
    block: int = 0  # which `Example` block of the docstring (1, 2, ...), when `run_example` runs them all


def steps(example):
    '''The `>>>` statements of an `Example` section, with their expected output.

    Example
        >>> [(s.source, s.expected) for s in steps(">>> x = 1\\n>>> x + 1\\n2")]
        [('x = 1', ''), ('x + 1', '2')]
    '''
    out, cur = [], None
    for line in example.splitlines():
        if line.startswith('>>> ') or line == '>>>':
            cur = Step(line[4:], '')
            out.append(cur)
        elif cur and (line.startswith('... ') or line == '...') and not cur.expected:
            cur.source += '\n' + line[4:]
        elif not line.strip() or (line.lstrip().startswith('#') and cur and not cur.expected):
            cur = None if not line.strip() else cur
        elif cur:
            cur.expected += ('\n' if cur.expected else '') + line
    return out


# --- running an example -----------------------------------------------------------------------

FLAGS = ast.PyCF_ALLOW_TOP_LEVEL_AWAIT


def _call(project, source, ns, mode):
    '''Compile `source` (top-level `await` allowed), run it, and give what it printed.'''
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = compile(source + '\n', '<example>', mode, flags=FLAGS)
        result = eval(code, ns)
        if inspect.iscoroutine(result):
            project.runner(result)
    return out.getvalue()


def _shown(e):
    '''The exception `e` as the REPL's last line shows it: `ValueError: bad`, a bare `MemoryError`.'''
    return f'{type(e).__name__}: {e}' if str(e) else type(e).__name__


def _open_fds():
    return set(map(int, os.listdir('/proc/self/fd')))


def run_example(project, name, example=None):
    '''Run the example block `example` of `name` (`read`, `File.read`) in a new temporary directory, with a new
    namespace (and its fixture); without `example`, each of `name`'s blocks so (`Step.block`: 1, 2, ...).

    Note
        - Gives up after the project's `timeout` (`SIGALRM`), so call it from the main thread.
    '''
    if example is None:
        return [
            dataclasses.replace(s, block=k)
            for k, block in enumerate(project.blocks(name), 1)
            for s in run_example(project, name, block)
        ]
    todo = steps(example)
    ns = {**vars(project.module), **project.namespace, '__name__': '__example__', '_keep': [], '_cleanup': [],
          '_name': name}  # fmt: skip
    fds, cwd = _open_fds(), os.getcwd()
    work = tempfile.mkdtemp(prefix='setu-docs-')
    os.chdir(work)

    def timeout(signum, frame):
        raise TimeoutError(f'example took over {project.timeout} s')

    old = signal.signal(signal.SIGALRM, timeout)
    signal.alarm(project.timeout)
    try:
        if setup := project.fixtures.get(name):
            try:
                _call(project, '_setup(ns)', {'_setup': setup, 'ns': ns}, 'eval')
            except Exception as e:  # noqa: BLE001  (any setup error fails the example)
                failed = Step(f'# setup: {setup.__name__}(ns)', '', _shown(e), 'fail')
                return [failed] + [dataclasses.replace(s, status='skip', got='(not run: setup failed)') for s in todo]
        for step in todo:
            if reason := project.skip.get((name, step.source)):
                step.status, step.got = 'skip', f'(not run: {reason})'
                continue
            try:
                step.got = _call(project, step.source, ns, 'single')
            except BaseException as e:  # shown like the REPL shows it
                if isinstance(e, (KeyboardInterrupt, SystemExit)):
                    raise
                step.got = _shown(e)
            step.got = step.got.rstrip('\n')
            loose = (name, step.source) in project.loose
            if [line.rstrip() for line in step.got.splitlines()] == step.expected.splitlines():
                step.status = 'ok'
            else:
                step.status = 'loose' if loose and not _raised(step.got) else 'fail'
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)
        os.chdir(cwd)
        for obj in ns['_keep']:
            obj.close()
        for fn in ns['_cleanup']:
            fn()
        for fd in _open_fds() - fds:
            with contextlib.suppress(OSError):
                os.close(fd)
        shutil.rmtree(work, ignore_errors=True)
    return todo


def _raised(got):
    '''Does `got` read like a raised exception (`NameError: ...`, a bare `MemoryError`)? A loose step must still
    not raise.'''
    return re.match(r'[A-Z]\w*(?:Error|Exception|Interrupt)(?:: |$)', got) is not None


def run_script(project, path, timeout=30):
    '''Run an example script in a new temporary directory; give `(returncode, output)`.'''
    with tempfile.TemporaryDirectory(prefix='setu-docs-') as work:
        try:
            p = subprocess.run(
                [sys.executable, str(project.root / path)],
                cwd=work,
                env=project.env(),
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired as e:
            return -1, f'{e.stdout or ""}{e.stderr or ""}\n(stopped after {timeout} s)'
    return p.returncode, p.stdout + p.stderr


def run_target(project, target):
    '''Run a documented name's examples (`Sqe`: every block, `Sqe:2`: the second) or an example script;
    JSON-ready result.'''
    if target.endswith('.py'):
        if target not in {p for p, runnable in project.scripts() if runnable}:
            raise LookupError(f'not a runnable example script: {target!r}')
        code, output = run_script(project, target)
        return {'target': target, 'ok': code == 0, 'returncode': code, 'output': output}
    name, colon, k = target.partition(':')
    if name not in project.examples():
        raise LookupError(f'no documented example named {name!r}')
    if colon:
        blocks = project.blocks(name)
        if not (k.isascii() and k.isdigit()) or not 1 <= int(k) <= len(blocks):
            raise LookupError(f'{name!r} has {len(blocks)} example block(s), no {k!r}')
        todo = run_example(project, name, blocks[int(k) - 1])
    else:
        todo = run_example(project, name)
    return {
        'target': target,
        'ok': all(s.status != 'fail' for s in todo),
        'steps': [dataclasses.asdict(s) for s in todo],
    }


# --- signatures from the stub -----------------------------------------------------------------


def stub_signatures(stub):
    '''`{name: signature}` from the stub text, as the stub writes it: `'f'` -> `'(x: int) -> str'`, `'C.m'` ->
    `'(x: int) -> None'` (no `self` / `cls`), `'C'` -> its `__init__`'s, `'C.p'` -> `': int'` for a property.
    The first overload wins.'''
    lines, out = stub.splitlines(), {}

    def params(node, method):
        text = re.sub(r'^def \w+', '', signature(lines, node))
        return re.sub(r'^\((self|cls)(, )?', '(', text) if method else text

    for node in ast.parse(stub).body:
        if isinstance(node, ast.FunctionDef):
            out.setdefault(node.name, params(node, False))
        elif isinstance(node, ast.ClassDef):
            for member in node.body:
                if not isinstance(member, ast.FunctionDef):
                    continue
                decorators = {ast.unparse(d) for d in member.decorator_list}
                if member.name == '__init__':
                    out.setdefault(node.name, params(member, True).removesuffix(' -> None'))
                elif 'property' in decorators and member.returns:
                    out.setdefault(f'{node.name}.{member.name}', f': {ast.unparse(member.returns)}')
                elif not any(d.endswith(('.setter', '.deleter')) for d in decorators):
                    out.setdefault(f'{node.name}.{member.name}', params(member, 'staticmethod' not in decorators))
    return out


# --- HTML -------------------------------------------------------------------------------------

KEYWORDS = set(keyword.kwlist)
BUILTINS = {
    'print', 'len', 'bytes', 'bytearray', 'str', 'int', 'bool', 'list', 'tuple', 'dict', 'range', 'open', 'type',
    'isinstance', 'super',
}  # fmt: skip
TOKEN = re.compile(
    r'''(?P<comment>\#.*)'''
    # triple-quoted first; a one-quote string ends at its line (an apostrophe in a docstring must not pair up)
    r'''|(?P<string>[rRbBfF]{0,2}(?:\'\'\'[\s\S]*?\'\'\'|"""[\s\S]*?"""|'(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*"))'''
    r'''|(?P<number>\b(?:0[xXoObB][\da-fA-F_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)\b)'''
    r'''|(?P<decorator>(?<![\w)\]])@[A-Za-z_][\w.]*)'''
    r'''|(?P<name>[A-Za-z_]\w*)'''
    r'''|(?P<op>[-+*/%=<>!&|^~@:.,;]+)'''
)
CONSTANTS = {'None', 'True', 'False', 'Ellipsis', 'NotImplemented'}
# A link off the site (`http(s)://`, no `target` yet): it opens in a new tab
EXTERNAL_LINK = re.compile(r'<a\b(?![^>]*\btarget=)[^>]*\bhref="https?://[^"]*"')
GITHUB = re.compile(r'https://github\.com/([\w.-]+/[\w.-]+?)(?:\.git)?/?')
# The header's repository link: the GitHub mark, then the latest release, stars and forks (filled in by `app.js`).
ICON_GITHUB = (
    '<svg class="gh" viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 '
    '3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-'
    '.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-'
    '3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 '
    '1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95'
    '.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>'
)
# The header's theme (◐) and menu (☰) buttons: SVG, so every header icon has the same height (`--icon`).
ICON_THEME = (
    '<svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="7" fill="none" stroke="currentColor"'
    ' stroke-width="1.5"/><path fill="currentColor" d="M8 1a7 7 0 0 0 0 14z"/></svg>'
)
ICON_MENU = (
    '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M1 2h14v2H1zM1 7h14v2H1zM1 12h14v2H1z"/>'
    '</svg>'
)
ICON_FACT = {  # 16px line icons, `stroke: currentColor` (CSS)
    'tag': '<path d="M1.5 2.5v5l7 7 6-6-7-7z"/><circle cx="4.75" cy="5.25" r="1"/>',
    'stars': '<path d="M8 1.5l1.9 4.1 4.4.4-3.3 3 1 4.4L8 11.1l-4 2.3 1-4.4-3.3-3 4.4-.4z"/>',
    'forks': '<circle cx="4" cy="3" r="1.5"/><circle cx="12" cy="3" r="1.5"/><circle cx="8" cy="13" r="1.5"/>'
    '<path d="M4 4.5V6a2 2 0 002 2h4a2 2 0 002-2V4.5M8 8v3.5"/>',
}
SH_KEYWORDS = {
    'if', 'then', 'elif', 'else', 'fi', 'for', 'while', 'until', 'do', 'done', 'case', 'esac', 'in', 'function',
}  # fmt: skip
SH_TOKEN = re.compile(
    r'''(?P<comment>(?<!\S)\#.*)'''
    r'''|(?P<string>'[^']*'|"(?:\\.|[^"\\])*")'''
    r'''|(?P<variable>\$\{[^}]*\}|\$\w+|\$[@*#?$!])'''
    r'''|(?P<placeholder><[\w.-]+>)'''
    r'''|(?P<option>(?<!\S)--?[A-Za-z][\w-]*)'''
    r'''|(?P<op>&&|\|\||\d?>>?(?:&\d)?|&>|[|;&<])'''
    r'''|(?P<word>[^\s|;&<>'"$]+)'''
)
SH_CLASS = {'comment': 'com', 'string': 'str', 'variable': 'bi', 'placeholder': 'arg', 'option': 'arg', 'op': 'op'}
C_KEYWORDS = {
    'auto', 'break', 'case', 'const', 'continue', 'default', 'do', 'else', 'enum', 'extern', 'for', 'goto', 'if',
    'inline', 'register', 'restrict', 'return', 'sizeof', 'static', 'struct', 'switch', 'typedef', 'union',
    'volatile', 'while',
}  # fmt: skip
C_TYPES = {
    'bool', 'char', 'double', 'float', 'int', 'long', 'short', 'signed', 'unsigned', 'void', 'size_t', 'ssize_t',
    'off_t', 'mode_t', 'pid_t', 'socklen_t', 'int8_t', 'int16_t', 'int32_t', 'int64_t', 'uint8_t', 'uint16_t',
    'uint32_t', 'uint64_t', 'intptr_t', 'uintptr_t', '__u8', '__u16', '__u32', '__u64', '__s32', '__s64',
}  # fmt: skip
C_CONSTANTS = {'NULL', 'true', 'false'}
C_TOKEN = re.compile(
    r'''(?P<comment>//.*|/\*[\s\S]*?\*/)'''
    r'''|(?P<decorator>^[ \t]*\#[ \t]*\w+)'''  # a preprocessor directive
    r'''|(?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|(?<=\#include)\s*<[^>\n]*>)'''
    r'''|(?P<number>\b(?:0[xX][\da-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)[uUlLfF]*\b)'''
    r'''|(?P<name>[A-Za-z_]\w*)'''
    r'''|(?P<op>[-+*/%=<>!&|^~?:.,;]+)''',
    re.MULTILINE,
)
FENCE = re.compile(r'( *)(`{3,}|~{3,})\s*([\w+-]*)')
HEADING = re.compile(r'(#{1,6})\s+(.*?)\s*#*\s*$')
LIST_ITEM = re.compile(r'( *)([-*+]|\d+[.)])\s+(.*)')
RULE = re.compile(r' {0,3}([-*_])( *\1){2,} *')
TABLE_SEP = re.compile(r' *\|? *:?-+:? *(\| *:?-+:? *)*\|? *')
HTML_BLOCK = re.compile(r' {0,3}</?[A-Za-z][\w-]*[\s/>]|<!--')
CHART = re.compile(r' {0,3}<!--\s*chart\b(.*?)-->\s*')
CHART_OPTION = re.compile(r'(\w+)="([^"]*)"')
CHART_NUMBER = re.compile(r'(-?\d[\d,]*(?:\.\d+)?)\s*([kMG]?)')
SERIES = 8  # chart colors (`--s1` ... `--s8`); more groups share `Other`'s
# a link's or image's destination: no spaces, brackets only balanced (`badge/abi-abi3t%20(PEP%20803)-blue`)
DEST = r'(?:[^()\s]|\([^()\s]*\))+'
INLINE = re.compile(
    r'(?P<code>(?P<ticks>`+)(?P<ctext>.+?)(?<!`)(?P=ticks)(?!`))'
    rf'|(?P<img>!\[(?P<ialt>[^\]]*)\]\((?P<isrc>{DEST})\))'
    rf'|(?P<link>\[(?P<ltext>(?:[^\[\]]|\[[^\]]*\])+)\]\((?P<lhref>{DEST})(?: +"[^"]*")?\))'
    r'|(?P<auto><(?P<aurl>https?://[^>\s]+)>)'
    r'|(?P<strong>\*\*(?P<stext>.+?)\*\*)'
    r'|(?P<em>(?<![\w*])\*(?P<etext>[^*\s](?:[^*]*[^*\s])?)\*(?![\w*])'
    r'|(?<!\w)_(?P<etext2>[^_\s](?:[^_]*[^_\s])?)_(?!\w))'
)
# A bare URL in a docstring; `autolink` leaves trailing punctuation (`see https://x.org/a.`) as text
BARE_URL = re.compile(r'''https?://[^\s<>`"']+''')


class Site:
    '''The pages being written, and where each exported name is documented (for links).'''

    def __init__(self, project):
        self.project = project
        self.pages, self.constants = project.api()
        self.constants_page = next((p for p in project.config['pages'] if p.get('constants')), None)
        self.signatures = stub_signatures(project.stub) if project.stub else {}
        self.markdown_pages = project.config.get('markdown', ())
        self.md_files = {(project.root / p['file']).resolve(): md_slug(p) for p in self.markdown_pages}
        if 'home' in project.config:
            self.md_files[(project.root / project.config['home']).resolve()] = 'index'
        self.chapters = {}  # a `split` Markdown page's slug -> (its intro, [(slug, title, text), ...])
        self.md_anchors = {}  # a `split` Markdown file -> {heading id: the slug of the page it is on}
        slugs = {p['slug'] for p in project.config['pages']} | {md_slug(p) for p in self.markdown_pages}
        for page in (p for p in self.markdown_pages if p.get('split')):
            path = (project.root / page['file']).resolve()
            intro, parts = chapters(include_files(path.read_text(), project.root))
            if not parts:
                fail(f'`split` Markdown page {page["file"]}: no `##` chapter')
            listed, anchors = [], {}
            for title, text in parts:
                plain = re.sub(r'[`*]', '', title)
                slug = f'{md_slug(page)}-{re.sub(r"^[0-9]+-", "", heading_id(plain))}'
                if slug in slugs:
                    fail(f'`split` Markdown page {page["file"]}: the page slug {slug} twice')
                slugs.add(slug)
                listed.append((slug, title, text))
                for m in filter(None, map(HEADING.match, text.splitlines())):  # a code block's `#` lines too:
                    anchors.setdefault(heading_id(re.sub(r'[`*]', '', m.group(2))), slug)  # harmless, never linked
            self.chapters[md_slug(page)] = intro, listed
            self.md_anchors[path] = anchors
        self.where = {}  # name -> 'page.html#anchor'
        for page, names in self.pages:
            for name in names:
                self.where[name] = f'{page["slug"]}.html#{name}'
                obj = project.find(name)
                if isinstance(obj, type) and not issubclass(obj, BaseException):
                    for member, _kind, _obj in members(obj):
                        self.where[f'{name}.{member}'] = f'{page["slug"]}.html#{name}.{member}'
        if self.constants_page:
            for name in self.constants:
                self.where[name] = f'{self.constants_page["slug"]}.html#{name}'
        self.coverage = None  # `coverage`'s JSON, if there is one
        if 'coverage' in project.config and (path := project.root / project.config['coverage']).is_file():
            self.coverage = json.loads(path.read_text())
            keys = {'total', 'interpreters', 'files'}
            if not isinstance(self.coverage, dict) or not keys <= self.coverage.keys() <= keys | {'commit'}:
                fail(f'`coverage`: {path} is not a result of `tools/check_coverage.py`')
            self.coverage_date = datetime.datetime.fromtimestamp(path.stat().st_mtime).strftime('%Y-%m-%d %H:%M')
        self.coverage_history = []  # `coverage_history`'s runs, oldest first
        if (
            'coverage_history' in project.config
            and (path := project.root / project.config['coverage_history']).is_file()
        ):
            data = json.loads(path.read_text())
            runs = data.get('runs') if isinstance(data, dict) and data.keys() == {'runs'} else None
            if not isinstance(runs, list) or not all(
                isinstance(r, dict) and {'version', 'covered', 'lines'} <= r.keys() and r['lines'] > 0 for r in runs
            ):
                fail(f'`coverage_history`: {path} is not a `--history` file of `tools/check_coverage.py`')
            self.coverage_history = runs
        self.load_profile()
        self.ids = set()  # the heading ids of the page being written

    def load_profile(self):
        '''Read `profile`'s JSON (`self.profile`; None without the file). The server calls it for each Profile page:
        a new `zig build profile` shows on a reload.'''
        self.profile = None
        config = self.project.config
        if 'profile' in config and (path := self.project.root / config['profile']).is_file():
            self.profile = json.loads(path.read_text())
            if not isinstance(self.profile, dict) or self.profile.keys() != {'number', 'interpreters', 'sources'}:
                fail(f'`profile`: {path} is not a result of `tools/check_profile.py`')
            self.profile_date = datetime.datetime.fromtimestamp(path.stat().st_mtime).strftime('%Y-%m-%d %H:%M')

    # -- inline text

    def link(self, name, text=None):
        text = html.escape(text or name)
        if href := self.where.get(name):
            return f'<a href="{href}">{text}</a>'
        return text

    def code(self, code):
        '''An inline code span, linked when it names an export (`read`, `File.read()`).'''
        name = re.match(r'[A-Za-z_][\w.]*', code)
        if name and name.group(0).rstrip('.') in self.where:
            return f'<code>{self.link(name.group(0).rstrip("."), code)}</code>'
        return f'<code>{html.escape(code)}</code>'

    def inline(self, text):
        '''Escape docstring `text`, turning `code` spans into `<code>` (linked when it names an export) and bare
        `http(s)://` URLs into links.'''
        out = []
        for part in re.split(r'(`[^`]+`)', text):
            if part.startswith('`') and part.endswith('`') and len(part) > 2:
                out.append(self.code(part[1:-1]))
            else:
                out.append(autolink(part))
        return ''.join(out)

    def paragraphs(self, text):
        return ''.join(f'<p>{self.inline(" ".join(p.split()))}</p>' for p in re.split(r'\n\s*\n', text) if p.strip())

    def highlight(self, code):
        '''Python `code` as HTML: a `<span>` per token kind, API names as links.

        Classes: `kw` keyword, `con` `None` / `True` / `False`, `bi` builtin, `slf` `self` / `cls` / a dunder
        name, `fn` a function (`def` name, a call, a method), `ty` a `class` name, `arg` a keyword argument
        (`name=` in brackets), `attr` an attribute, `dec` a decorator, `op` an operator or delimiter (brackets stay
        plain), `str`, `num`, `com`; `a.ref` an API name.
        '''
        out, pos, prev, depth = [], 0, '', 0
        for m in TOKEN.finditer(code):
            gap = code[pos : m.start()]
            if gap.strip():
                prev = ''
                depth = max(depth + sum(gap.count(c) for c in '([{') - sum(gap.count(c) for c in ')]}'), 0)
            out.append(html.escape(code[pos : m.start()]))
            kind, text = m.lastgroup, m.group(0)
            if kind == 'name':
                after = code[m.end() :].lstrip(' ')
                call = after.startswith('(')
                if text in CONSTANTS:
                    cls = 'con'
                elif text in KEYWORDS:
                    cls = 'kw'
                elif text in self.where:
                    cls = 'ref'
                elif prev == 'class':
                    cls = 'ty'
                elif prev == 'def' or (call and text not in BUILTINS):
                    cls = 'fn'
                elif text in BUILTINS:
                    cls = 'bi'
                elif text in ('self', 'cls') or (text.startswith('__') and text.endswith('__')):
                    cls = 'slf'
                elif prev.endswith('.'):
                    cls = 'attr'
                elif depth and after.startswith('=') and not after.startswith('=='):
                    cls = 'arg'
                else:
                    cls = ''
                if cls == 'ref':
                    out.append(f'<a class="ref" href="{self.where[text]}">{text}</a>')
                else:
                    out.append(f'<span class="{cls}">{text}</span>' if cls else text)
            else:
                out.append(f'<span class="{kind[:3]}">{html.escape(text)}</span>')
            pos, prev = m.end(), text
        out.append(html.escape(code[pos:]))
        return ''.join(out)

    def session(self, example):
        '''An `Example` section as a REPL session: prompts, code, output and `# headings`.'''
        lines = []
        for line in example.splitlines():
            if line.startswith(('>>> ', '... ')) or line in ('>>>', '...'):
                lines.append(f'<span class="pr">{line[:3]}</span>{self.highlight(line[3:])}')
            elif line.lstrip().startswith('#'):
                lines.append(f'<span class="com">{html.escape(line)}</span>')
            else:
                lines.append(f'<span class="out">{html.escape(line)}</span>')
        return code_box('\n'.join(lines), 'code session')

    def shell(self, code):
        '''A shell block as HTML: `fn` a command, `kw` a keyword, `arg` an option or a `<placeholder>`, `str` a
        string, `bi` a variable, `op` a pipe / `&&` / `;` / redirection, `com` a comment. When a line starts with a
        `$ ` prompt (a `console` session), the prompt is `pr` and the other lines are output.
        '''
        session = any(line.startswith('$ ') for line in code.splitlines())
        lines = []
        for line in code.splitlines():
            if session and not line.startswith('$ '):
                lines.append(f'<span class="out">{html.escape(line)}</span>' if line else '')
                continue
            out, pos, command = [], 0, True
            if session:
                out.append('<span class="pr">$ </span>')
                pos = 2
            for m in SH_TOKEN.finditer(line, pos):
                out.append(html.escape(line[pos : m.start()]))
                kind, text = m.lastgroup, m.group(0)
                if kind == 'word':
                    if text in SH_KEYWORDS:
                        cls, command = 'kw', True
                    elif command and not re.match(r'\w+=', text):
                        cls, command = 'fn', False
                    else:
                        cls = ''
                    out.append(f'<span class="{cls}">{html.escape(text)}</span>' if cls else html.escape(text))
                else:
                    out.append(f'<span class="{SH_CLASS[kind]}">{html.escape(text)}</span>')
                    command = command or text in ('|', '||', '&&', ';', '&')
                pos = m.end()
            out.append(html.escape(line[pos:]))
            lines.append(''.join(out))
        return '\n'.join(lines)

    def highlight_c(self, code):
        '''C `code` as HTML, with `highlight`'s classes (`dec` a preprocessor directive, `ty` a type).'''
        out, pos = [], 0
        for m in C_TOKEN.finditer(code):
            out.append(html.escape(code[pos : m.start()]))
            kind, text = m.lastgroup, m.group(0)
            if kind == 'name':
                if text in C_CONSTANTS or (text.isupper() and len(text) > 1):
                    cls = 'con'
                elif text in C_KEYWORDS:
                    cls = 'kw'
                elif text in C_TYPES or text.endswith('_t'):
                    cls = 'ty'
                elif code[m.end() :].lstrip(' ').startswith('('):
                    cls = 'fn'
                else:
                    cls = ''
                out.append(f'<span class="{cls}">{text}</span>' if cls else text)
            else:
                out.append(f'<span class="{kind[:3]}">{html.escape(text)}</span>')
            pos = m.end()
        out.append(html.escape(code[pos:]))
        return ''.join(out)

    def code_block(self, code, lang):
        lang = lang.lower()
        if lang == 'pycon' or (not lang and code.startswith('>>> ')):
            return self.session(code)
        if lang in ('python', 'py', 'python3'):
            body = self.highlight(code)
        elif lang in ('sh', 'bash', 'shell', 'console'):
            body = self.shell(code)
        elif lang in ('c', 'h'):
            body = self.highlight_c(code)
        else:
            body = html.escape(code)
        attr = f' data-lang="{html.escape(lang)}"' if lang else ''
        return code_box(body, attrs=attr)

    # -- Markdown

    def anchor(self, title):
        '''A unique id for a heading of the page being written.'''
        base = heading_id(title)
        anchor, n = base, 1
        while anchor in self.ids:
            n += 1
            anchor = f'{base}-{n}'
        self.ids.add(anchor)
        return anchor

    def href(self, url, base):
        '''A Markdown link target: `other.md#x` -> `other.html#x` (a Markdown page or an API page by slug).'''
        parts = urllib.parse.urlsplit(url)
        if parts.scheme or parts.netloc or not parts.path.endswith('.md'):
            return url
        fragment = f'#{parts.fragment}' if parts.fragment else ''
        if base is not None and (slug := self.md_files.get(path := (base / parts.path).resolve())):
            slug = self.md_anchors.get(path, {}).get(parts.fragment, slug)  # the chapter of a `split` page
            return f'{slug}.html{fragment}'
        stem = pathlib.PurePosixPath(parts.path).stem
        if stem in {p['slug'] for p in self.project.config['pages']} | set(self.md_files.values()):
            return f'{stem}.html{fragment}'
        return url

    def inline_md(self, text, base=None):
        '''Markdown inline text as HTML: code spans, links, images, bold, emphasis; the rest escaped.'''
        out, pos = [], 0
        for m in INLINE.finditer(text):
            out.append(html.escape(text[pos : m.start()]))
            if m.group('code'):
                code = m.group('ctext')
                out.append(self.code(code[1:-1] if code.startswith(' ') and code.endswith(' ') else code))
            elif m.group('img'):
                src = html.escape(self.href(m.group('isrc'), base))
                out.append(f'<img src="{src}" alt="{html.escape(m.group("ialt"))}">')
            elif m.group('link'):
                href = html.escape(self.href(m.group('lhref'), base))
                out.append(f'<a href="{href}">{self.inline_md(m.group("ltext"), base)}</a>')
            elif m.group('auto'):
                url = html.escape(m.group('aurl'))
                out.append(f'<a href="{url}">{url}</a>')
            elif m.group('strong'):
                out.append(f'<strong>{self.inline_md(m.group("stext"), base)}</strong>')
            else:
                out.append(f'<em>{self.inline_md(m.group("etext") or m.group("etext2"), base)}</em>')
            pos = m.end()
        out.append(html.escape(text[pos:]))
        return ''.join(out)

    @staticmethod
    def starts_block(line):
        return bool(
            FENCE.match(line) or HEADING.match(line) or RULE.fullmatch(line) or line.lstrip().startswith('>')
            or (LIST_ITEM.match(line) and len(LIST_ITEM.match(line).group(1)) < 4)
        )  # fmt: skip

    @staticmethod
    def cells(row):
        row = row.strip()
        row = row.removeprefix('|')
        row = row[:-1] if row.endswith('|') and not row.endswith('\\|') else row
        return [c.strip().replace('\\|', '|') for c in re.split(r'(?<!\\)\|', row)]

    def table(self, head, sep, rows, base):
        aligns = []
        for c in self.cells(sep):
            left, right = c.startswith(':'), c.endswith(':')
            aligns.append(' style="text-align: center"' if left and right else ' style="text-align: right"'
                          if right else '')  # fmt: skip

        def row(cells, tag):
            cells = (cells + [''] * len(aligns))[: len(aligns)]
            return (
                '<tr>'
                + ''.join(f'<{tag}{a}>{self.inline_md(c, base)}</{tag}>' for c, a in zip(cells, aligns))
                + '</tr>'
            )

        body = ''.join(row(self.cells(r), 'td') for r in rows)
        return f'<table class="md"><thead>{row(self.cells(head), "th")}</thead><tbody>{body}</tbody></table>'

    def chart(self, options, head, rows, base):
        '''A `<!-- chart -->` table as a horizontal bar chart: a bar per row, colored by the row's group.'''
        opts = dict(CHART_OPTION.findall(options))
        if CHART_OPTION.sub('', options).strip() or set(opts) - {'value', 'group'}:
            fail(f'<!-- chart{options}-->: the options are `value="..."` and `group="..."`')
        heads = self.cells(head)
        table = [(self.cells(r) + [''] * len(heads))[: len(heads)] for r in rows]
        if 'value' in opts:
            if opts['value'] not in heads[1:]:
                fail(f'<!-- chart -->: no column {opts["value"]!r} in {heads}')
            col = heads.index(opts['value'], 1)
        else:
            col = next((k for k in range(1, len(heads)) if all(chart_number(r[k]) is not None for r in table)), 0)
            if not col:
                fail(f'<!-- chart -->: no column of numbers in {heads}')
        try:
            group_rx = re.compile(opts.get('group', r'[^\s,]+'))
        except re.error as e:
            fail(f'<!-- chart -->: group {opts["group"]!r}: {e}')
        groups, out = {}, []
        top = max((chart_number(r[col]) or 0 for r in table), default=0)
        for r in table:
            label, value = re.sub(r'[`*]', '', r[0]), chart_number(r[col])
            m = group_rx.search(label)
            group = (m.group(1) if m.groups() else m.group(0)) if m else label
            n = groups.setdefault(group, len(groups))
            color = f'var(--s{n + 1})' if n < SERIES else 'var(--s-other)'
            width = round(max(value or 0, 0) / top * 100, 2) if top > 0 else 0
            tip = html.escape(f'{label}: {re.sub(r"[`*]", "", r[col])}')
            out.append(f'<div class="row" title="{tip}"><span class="lbl">{self.inline_md(r[0], base)}</span>'
                       f'<span class="track"><i style="width: {width}%; background: {color}"></i></span>'
                       f'<span class="val">{self.inline_md(r[col], base)}</span></div>')  # fmt: skip
        legend = ''
        if len(groups) > 1:
            names = list(groups)[:SERIES] + (['Other'] if len(groups) > SERIES else [])
            legend = '<div class="legend">' + ''.join(
                f'<span><i style="background: var(--s{n + 1 if n < SERIES else "-other"})"></i>{html.escape(g)}</span>'
                for n, g in enumerate(names)
            ) + '</div>'  # fmt: skip
        bars = ''.join(out)
        return (f'<figure class="chart">{legend}<div class="bars">{bars}</div>'
                f'<figcaption>{self.inline_md(heads[col], base)}</figcaption></figure>')  # fmt: skip

    def list_block(self, lines, i, base, toc):
        '''The list starting at `lines[i]`: `(html, next line)`.'''
        first = LIST_ITEM.match(lines[i])
        indent, ordered = len(first.group(1)), first.group(2)[0].isdigit()
        items, j = [], i
        while j < len(lines):
            line = lines[j]
            m = LIST_ITEM.match(line)
            depth = len(line) - len(line.lstrip(' '))
            if m and len(m.group(1)) == indent and m.group(2)[0].isdigit() == ordered:
                items.append([m.group(3)])
            elif not line.strip():
                k = j + 1
                while k < len(lines) and not lines[k].strip():
                    k += 1
                if k == len(lines) or (len(lines[k]) - len(lines[k].lstrip(' ')) <= indent and not (
                    (n := LIST_ITEM.match(lines[k])) and len(n.group(1)) == indent
                )):  # fmt: skip
                    break
                items[-1].append('')
            elif depth > indent or not self.starts_block(line):
                items[-1].append(line)
            else:
                break
            j += 1
        out = []
        for item in items:
            rest = textwrap.dedent('\n'.join(item[1:])).splitlines()
            lead = [item[0]]
            while rest and rest[0].strip() and not self.starts_block(rest[0]):
                lead.append(rest.pop(0).strip())
            body = self.inline_md(' '.join(lead), base)
            if any(line.strip() for line in rest):
                body += self.blocks(rest, base, toc)
            out.append(f'<li>{body}</li>')
        tag = 'ol' if ordered else 'ul'
        return f'<{tag}>{"".join(out)}</{tag}>', j

    def blocks(self, lines, base, toc, parts=None):
        '''Markdown block text (a list of lines) as HTML; level 2 and 3 headings go into `toc`.

        With `parts` (the open levels; a page's top level only), a level 2 or 3 heading opens a `<section
        class="part">` that carries its id and holds everything up to the next heading of its level or higher, so a
        selected heading gets the side bars of a selected entry.
        '''
        out, i = [], 0
        while i < len(lines):
            line = lines[i]
            if not line.strip():
                i += 1
            elif m := FENCE.match(line):
                indent, fence, lang = m.groups()
                j = i + 1
                while j < len(lines) and not lines[j].strip().startswith(fence):
                    j += 1
                code = '\n'.join(c[len(indent) :] if c.startswith(indent) else c.lstrip() for c in lines[i + 1 : j])
                out.append(self.code_block(code, lang))
                i = j + 1
            elif m := HEADING.match(line):
                level, title = len(m.group(1)), m.group(2)
                plain = re.sub(r'[`*]', '', title)
                anchor = self.anchor(plain)
                if level in (2, 3):
                    toc.append((anchor, plain))
                while parts and parts[-1] >= level:
                    out.append('</section>')
                    parts.pop()
                if parts is not None and level in (2, 3):
                    out.append(f'<section class="part" id="{anchor}">')
                    parts.append(level)
                    head = f'<h{level}>'
                else:
                    head = f'<h{level} id="{anchor}">'
                out.append(f'{head}{self.inline_md(title, base)}<a class="anchor" href="#{anchor}">#</a></h{level}>')
                i += 1
            elif RULE.fullmatch(line):
                out.append('<hr>')
                i += 1
            elif line.lstrip().startswith('|') and i + 1 < len(lines) and TABLE_SEP.fullmatch(lines[i + 1]):
                j = i + 2
                while j < len(lines) and lines[j].lstrip().startswith('|'):
                    j += 1
                out.append(self.table(line, lines[i + 1], lines[i + 2 : j], base))
                i = j
            elif m := CHART.fullmatch(line):
                if not (i + 2 < len(lines) and lines[i + 1].lstrip().startswith('|')
                        and TABLE_SEP.fullmatch(lines[i + 2])):  # fmt: skip
                    fail(f'{line.strip()} is not followed by a table')
                j = i + 3
                while j < len(lines) and lines[j].lstrip().startswith('|'):
                    j += 1
                out.append(self.chart(m.group(1), lines[i + 1], lines[i + 3 : j], base))
                i = j
            elif line.lstrip().startswith('>'):
                j = i
                while j < len(lines) and lines[j].lstrip().startswith('>'):
                    j += 1
                inner = [re.sub(r'^\s*> ?', '', q) for q in lines[i:j]]
                out.append(f'<blockquote>{self.blocks(inner, base, toc)}</blockquote>')
                i = j
            elif (m := LIST_ITEM.match(line)) and len(m.group(1)) < 4:
                text, i = self.list_block(lines, i, base, toc)
                out.append(text)
            elif HTML_BLOCK.match(line):
                j = i
                while j < len(lines) and lines[j].strip():
                    j += 1
                out.append('\n'.join(lines[i:j]))
                i = j
            else:
                j = i + 1
                while j < len(lines) and lines[j].strip() and not self.starts_block(lines[j]):
                    j += 1
                out.append(f'<p>{self.inline_md(" ".join(p.strip() for p in lines[i:j]), base)}</p>')
                i = j
        out.extend('</section>' for _ in parts or ())
        return ''.join(out)

    def markdown(self, text, base=None):
        '''Markdown `text` (from a file in `base`) as `(html, toc)`.'''
        toc = []
        return self.blocks(text.splitlines(), base, toc, []), toc

    # -- docstring sections

    def type_table(self, text):
        rows = []
        for line in text.splitlines():
            m = re.match(r'\s*(\w+):\s*(.*?)\s*(?:(?:#|\s-\s)\s*(.*))?$', line)
            if not m:
                if rows and line.strip():
                    rows[-1][2] += ' ' + line.strip()
                continue
            rows.append([m.group(1), m.group(2), m.group(3) or ''])
        body = ''.join(
            f'<tr><td><code>{html.escape(n)}</code></td><td><code>{html.escape(t)}</code></td>'
            f'<td>{self.inline(note)}</td></tr>'
            for n, t, note in rows
        )
        return f'<table class="types"><tbody>{body}</tbody></table>'

    def bullets(self, text):
        items = []
        for line in text.splitlines():
            if line.lstrip().startswith('- '):
                items.append(line.lstrip()[2:])
            elif items and line.strip():
                items[-1] += ' ' + line.strip()
            elif line.strip():
                items.append(line.strip())
        return '<ul>' + ''.join(f'<li>{self.inline(i)}</li>' for i in items) + '</ul>'

    def flags(self, text):
        '''A `Flags` section: one entry per line, a name (as code, linked when it is an export) and an optional
        `# comment` after it, shown as text (`IORING_TIMEOUT_ABS  # ts is a point in time`). With comments the
        entries stack, else they wrap as a row.
        '''
        entries = [re.split(r'\s+#\s*', line.strip(), maxsplit=1) for line in text.splitlines() if line.strip()]
        items = ''.join(
            f'<li>{self.code(e[0])}' + (f' {self.inline(e[1])}' if len(e) > 1 else '') + '</li>' for e in entries
        )
        described = ' described' if any(len(e) > 1 for e in entries) else ''
        return f'<ul class="flags{described}">{items}</ul>'

    def doc(self, name, obj):
        '''A docstring as HTML: description, Type, Example (+ fixture and Run; each block its own), Note,
        others.'''
        split = parts(obj.__doc__)
        blocks = len(example_blocks(obj.__doc__))
        out, k = [self.paragraphs(split[0][1])], 0
        for header, text in split[1:]:
            if not text.strip():
                continue
            out.append(f'<h4>{html.escape(header)}</h4>')
            if header == 'Type':
                out.append(self.type_table(text))
            elif EXAMPLE.fullmatch(header):
                k += 1
                out.append(self.session(text))
                if k == 1 and (setup := self.project.fixtures.get(name)):  # the same for every block: shown once
                    with contextlib.suppress(OSError, TypeError):
                        src = re.sub(r'^@.*\n', '', inspect.getsource(setup))  # without the decorator
                        out.append(
                            '<details class="fixture"><summary>Setup used to run this example</summary>'
                            f'{code_box(self.highlight(src.rstrip()))}</details>'
                        )
                needs = self.project.needs(name, text)
                out.append(_needs(needs) if needs else _run_box(name if blocks == 1 else f'{name}:{k}'))
            elif header in ('Note', 'Warning'):
                out.append(self.bullets(text))
            elif header == 'Flags':
                out.append(self.flags(text))
            else:
                out.append(f'<pre class="plain">{autolink(text)}</pre>')
        return ''.join(out)

    # -- entries

    def signature(self, name, obj):
        if sig := self.signatures.get(name):
            return sig
        sig = getattr(obj, '__text_signature__', None)
        if not sig:
            return '' if isinstance(obj, type) else '()'
        return re.sub(r'^\(\$\w+,?\s*', '(', sig)

    @staticmethod
    def is_async(obj):
        if inspect.iscoroutinefunction(obj):
            return True
        return 'Awaitable' in sections(getattr(obj, '__doc__', None)).get('Type', '').split('return:', 1)[-1][:40]

    def entry(self, name, obj):
        out = [f'<section class="entry" id="{name}">']
        if isinstance(obj, type):
            exc = issubclass(obj, BaseException)
            bases = [b.__name__ for b in obj.__bases__ if b is not object]
            base = f'({", ".join(self.link(b) for b in bases)})' if exc and bases else ''
            sig = '' if exc else html.escape(self.signature(name, obj))
            kind = 'exception' if exc else 'class'
            out.append(f'<h3><span class="kind">{kind}</span> <span class="nm">{name}</span>{sig}{base}'
                       f'<a class="anchor" href="#{name}">#</a></h3>')  # fmt: skip
            if not exc and bases:
                out.append(f'<p class="bases">Subclass of {", ".join(self.link(b) for b in bases)}.</p>')
            out.append(self.doc(name, obj))
            mem = members(obj) if not exc else []
            if mem:
                out.append('<div class="members">')
                for member, kind, mobj in mem:
                    full = f'{name}.{member}'
                    if kind == 'value':
                        sig, doc = html.escape(f' = {mobj!r}'), ''
                    else:
                        sig = self.signatures.get(full, '') if kind == 'property' else self.signature(full, mobj)
                        sig, doc = html.escape(sig), self.doc(full, mobj) if mobj.__doc__ else ''
                    badge = '<span class="badge">async</span>' if self.is_async(mobj) else ''
                    out.append(f'<div class="member" id="{full}"><h4 class="mh"><span class="kind">{kind}</span> '
                               f'<span class="nm">{member}</span>{sig}{badge}<a class="anchor" href="#{full}">#</a>'
                               f'</h4>{doc}</div>')  # fmt: skip
                out.append('</div>')
        else:
            badge = '<span class="badge">async</span>' if self.is_async(obj) else ''
            out.append(f'<h3><span class="nm">{name}</span>{html.escape(self.signature(name, obj))}{badge}'
                       f'<a class="anchor" href="#{name}">#</a></h3>')  # fmt: skip
            out.append(self.doc(name, obj))
        out.append('</section>')
        return ''.join(out)

    # -- pages

    def nav(self, current):
        def item(slug, title, cls=''):
            cls = ' '.join(c for c in (cls, 'on' if current == slug else '') if c)
            return f'<a href="{slug}.html"' + (f' class="{cls}"' if cls else '') + f'>{html.escape(title)}</a>'

        items = [item('index', 'Home')]
        section = None
        for page in self.markdown_pages:
            if page.get('section') != section:
                section = page.get('section')
                if section:
                    items.append(f'<div class="nav-h">{html.escape(section)}</div>')
            items.append(item(md_slug(page), page['title']))
            for slug, title, _text in self.chapters.get(md_slug(page), ('', ()))[1]:
                items.append(item(slug, re.sub(r'[`*]', '', title), 'sub'))
        items.append('<div class="nav-h">API reference</div>')
        items += [item(page['slug'], page['title']) for page, _names in self.pages]
        if self.constants_page:
            items.append(item(self.constants_page['slug'], self.constants_page['title']))
        if self.project.scripts():
            items.append(item('examples', 'Example scripts'))
        if self.coverage:
            items.append(item('coverage', 'Coverage'))
        if 'profile' in self.project.config:  # served by `serve` only: shown when the page is live (`can-run`)
            items.append(item('profile', 'Profile', 'live-only'))
        return '\n'.join(items)

    def page(self, current, title, body, toc=(), api=False):
        project = self.project
        toc_html = ''.join(  # a long name breaks after `_` / `.` instead of being cut off
            f'<a href="#{html.escape(a)}">{re.sub(r"([_.])", r"\1<wbr>", html.escape(t))}</a>' for a, t in toc
        )
        name, version = html.escape(project.name), html.escape(project.version)
        # API pages are mostly names, which Chrome takes for some other language and offers to translate
        meta = '\n<meta name="google" content="notranslate">' if api else ''
        url = project.homepage
        footer_name = f'<a href="{html.escape(url)}">{name}</a>' if url else name
        python = f' (CPython {html.escape(project.requires)})' if project.requires else ''
        repo = ''
        if project.repo:
            facts = ''.join(
                f'<span class="fact"><svg viewBox="0 0 16 16" aria-hidden="true">{svg}</svg><span data-fact="{k}">'
                f'</span></span>'
                for k, svg in ICON_FACT.items()
            )
            label = html.escape(project.repo_name or project.repo.split('//', 1)[-1])
            repo = (
                f'\n  <a class="repo" href="{html.escape(project.repo)}" title="Source on GitHub"'
                f' data-repo="{html.escape(project.repo_name)}">{ICON_GITHUB}<span class="repo-in">'
                f'<span class="repo-name">{label}</span><span class="facts" hidden>{facts}</span></span></a>'
            )
        page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">{meta}
<title>{html.escape(title)} · {name}</title>
<link rel="icon" href="{html.escape(project.favicon or letter_icon(project.name))}">
<link rel="stylesheet" href="style.css">
<script>try {{ const r = document.documentElement, t = localStorage.getItem('theme');
const p = localStorage.getItem('palette'); if (t) r.dataset.theme = t;
if (p && {THEME_NAMES!r}.includes(p)) r.dataset.palette = p; }} catch (e) {{}}</script>
</head>
<body>
<header class="top"><div class="top-in">
  <a class="brand" href="index.html">{name} <span class="ver">{version}</span></a>
  <div class="search"><input id="q" type="search" placeholder="Search needs a server" autocomplete="off" disabled>
  <div id="hits" hidden></div></div>
  <div class="tools">
  <span id="live" class="live" title="Run buttons need `setu_docs.py serve`">static</span>
  {THEME_MENU}{repo}
  <button class="menu" aria-label="Menu" onclick="document.body.classList.toggle('nav-open')">{ICON_MENU}</button>
  </div>
</div></header>
<div class="wrap">
<main>
{body}
<footer>Generated by <code>tools/setu_docs.py</code> from the docstrings of {footer_name} {version}{python}.</footer>
</main>
<nav class="side">
<div class="pages">{self.nav(current)}</div>
{f'<div class="toc"><div class="toc-h">On this page</div>{toc_html}</div>' if toc_html else ''}
</nav>
</div>
<script src="app.js"></script>
</body>
</html>
'''
        return EXTERNAL_LINK.sub(r'\g<0> target="_blank" rel="noopener"', page)

    def api_page(self, page, names):
        self.ids = set()
        body = [f'<h1>{html.escape(page["title"])}</h1><p class="lead">{self.inline(page["text"])}</p>']
        index = ''.join(f'<li><code>{self.link(n)}</code></li>' for n in names)
        body.append(f'<ul class="index">{index}</ul>')
        body += [self.entry(n, self.project.find(n)) for n in names]
        return self.page(page['slug'], page['title'], ''.join(body), [(n, n) for n in names], api=True)

    def constant_page(self):
        page = self.constants_page
        groups, other = {}, []
        for name in self.constants:
            groups.setdefault(constant_group(page, name), []).append(name)
        for group, names in list(groups.items()):  # a group of one goes under `Other` (unless in `groups`)
            if len(names) == 1 and not names[0].startswith(tuple(page.get('groups', ()))):
                other += groups.pop(group)
        if other:
            groups['Other'] = other
        body = [(f'<h1>{html.escape(page["title"])}</h1><p class="lead">{self.inline(page["text"])} '
                 f'{len(self.constants)} in all.</p>')]  # fmt: skip
        for group, names in groups.items():
            rows = []
            for n in names:
                value = getattr(self.project.module, n)
                hexa = hex(value) if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else ''
                rows.append(f'<tr id="{n}"><td><code>{n}</code></td><td><code>{html.escape(repr(value))}</code></td>'
                            f'<td><code>{hexa}</code></td></tr>')  # fmt: skip
            g = html.escape(group)
            body.append(f'<section class="group" id="g-{g}"><h2>{g}<a class="anchor" href="#g-{g}">#</a></h2>'
                        f'<table class="consts"><thead><tr><th>Name</th><th>Value</th><th>Hex</th></tr></thead>'
                        f'<tbody>{"".join(rows)}</tbody></table></section>')  # fmt: skip
        toc = [(f'g-{g}', g) for g in groups]
        return self.page(page['slug'], page['title'], ''.join(body), toc, api=True)

    def examples_page(self):
        folder = html.escape(self.project.config['scripts'])
        body = [
            (
                f'<h1>Example scripts</h1><p class="lead">The scripts in <code>{folder}/</code>. With '
                '<code>setu_docs.py serve</code> running, <b>Run</b> starts one in a temporary directory and shows '
                'its output.</p>'
            )
        ]
        toc = []
        for path, runnable in self.project.scripts():
            source = (self.project.root / path).read_text()
            anchor = pathlib.Path(path).stem
            toc.append((anchor, pathlib.Path(path).name))
            body.append(f'<section class="entry" id="{anchor}"><h3><span class="nm">{html.escape(path)}</span>'
                        f'<a class="anchor" href="#{anchor}">#</a></h3>'
                        f'{code_box(self.highlight(source.rstrip()))}'
                        f'{_run_box(path) if runnable else _not_runnable()}</section>')  # fmt: skip
        return self.page('examples', 'Example scripts', ''.join(body), toc)

    def coverage_page(self):
        '''A section per owner: the project's files (its donut and table), then each dependency's (how much of it the
        project's tests run, the total with the project's code, each interpreter's run, its files).'''
        report = self.coverage
        root = self.project.root
        self.sources = {}  # the site's `source/<path>` -> the file, for the viewer (copied by `write`)
        groups = {}  # '' (the project's own files), else a dependency's name -> [(path, covered, lines, missed, hit)]
        for path, counts in report['files'].items():
            top = path.split('/', 1)[0]
            owner = '' if '/' not in path or (root / top).is_dir() else top
            missed = sorted(int(n) for n, (hits, _possible) in counts['hits'].items() if hits == 0)
            hit = sorted(int(n) for n, (hits, _possible) in counts['hits'].items() if hits)
            groups.setdefault(owner, []).append((path, counts['covered'], counts['lines'], missed, hit))
        for files in groups.values():
            files.sort(key=lambda f: (f[1] / f[2], f[0]))
        own = groups.pop('', [])
        own_covered, own_lines = sum(f[1] for f in own), sum(f[2] for f in own)
        runs = report['interpreters']
        names = [f'CPython {n}' if 'python' in r else n for n, r in runs.items()]
        runs_text = names[0] if len(names) == 1 else f'{", ".join(names[:-1])} and {names[-1]}'
        lead = (
            f'<p class="lead">The lines of Zig code that ran while the tests ran (<code>zig build coverage</code>, '
            f'kcov) on {html.escape(runs_text)}, merged: a line ran if it ran on any. {self.coverage_date}.</p>'
        ) + src_hints('Click a file to see its source, the missed lines marked.')
        body = ['<h1>Coverage</h1>', lead]
        toc = []
        name = self.project.name
        own_name = html.escape(name)
        if own:
            anchor = slug(name)
            toc.append((anchor, name))
            pies = coverage_donut(name, own_covered, own_lines) + coverage_history_chart(self.coverage_history)
            body += [
                section_heading(anchor, name),
                f'<div class="cov-pies">{pies}</div>',
                self.coverage_table(own, root),
            ]
        for owner, files in groups.items():
            dep_root = dependency_root(root, owner)
            shown = display_name(dep_root, owner)
            covered, lines = sum(f[1] for f in files), sum(f[2] for f in files)
            mine = coverage_donut(f"{shown} run by {name}'s tests", covered, lines)
            both = coverage_donut(f'{name} + {shown}', own_covered + covered, own_lines + lines)
            dep = html.escape(shown)
            note = (
                f"<p>Not {dep}'s own coverage: how much of {dep} {own_name}'s tests run. The lines missed here are "
                f'parts of {dep} that {own_name} does not use; only the files of {dep} that {own_name} compiles in '
                'are counted.</p>'
            )
            anchor = f'dep-{slug(owner)}'
            toc.append((anchor, shown))
            body += [section_heading(anchor, shown), note, f'<div class="cov-pies">{mine}{both}</div>']
            if len(runs) > 1:  # every file of the run: the project's and each dependency's
                items = ''.join(
                    f'<li>{html.escape(n)}: {coverage_total(run["covered"], run["lines"])}</li>'
                    for n, run in zip(names, runs.values())
                )
                body.append(f'<p>Each run on its own, {own_name} + {dep}:</p><ul>{items}</ul>')
            body.append(self.coverage_table(files, dep_root, f'{owner}/'))
        return self.page('coverage', 'Coverage', ''.join(body), toc)

    def coverage_table(self, files, root, prefix=''):
        '''`coverage_table` of `files`, each row whose source (`root / path` without `prefix`) is there with what the
        viewer needs; a source whose CRC-32 is not the one `coverage`'s JSON has (changed since the run) is marked
        `changed`: its line marks can be off. Under each such row the viewer's row, hidden and empty. Its missed
        lines grouped by the function they are in (`missed_html`), and where the interpreters ran different lines of
        a file, each one's count (`runs_note`).'''
        table = coverage_table([f[:4] for f in files])
        for path, _covered, _lines, missed, hit in files:
            cell = f'<td><code>{html.escape(path)}</code>'
            if note := self.runs_note(path):
                table = table.replace(f'<tr>{cell}', f'<tr>{cell}{note}', 1)
                cell += note
            source = root / path.removeprefix(prefix) if root else None
            if not source or not source.is_file():
                continue
            crc = self.coverage['files'][path].get('crc32')
            stale = crc is not None and zlib.crc32(source.read_bytes()) != crc
            if missed:
                hits = {int(n): h for n, (h, _possible) in self.coverage['files'][path]['hits'].items()}
                grouped = missed_functions(source.read_text(errors='replace'), hits)
                url = self.blob_url(path) if not prefix and not stale else None
                at = table.index(f'<tr>{cell}')
                plain = f'<td class="missed">{line_ranges(missed)}</td>'
                end = table.index(plain, at)
                html_ = self.missed_html(grouped, url)
                table = table[:end] + f'<td class="missed">{html_}</td>' + table[end + len(plain) :]
            self.sources[path] = source
            flag = ' data-stale="1"' if stale else ''
            data = (
                f'<tr class="src-row" data-src="{SOURCE_DIR}/{html.escape(path)}" data-hit="{line_ranges(hit)}" '
                f'data-miss="{line_ranges(missed)}"{flag} title="Show the source">'
            )
            mark = ' <small class="stale" title="Changed since `zig build coverage`">changed</small>' if stale else ''
            at = table.index(f'<tr>{cell}')
            end = table.index('</tr>', at) + len('</tr>')
            view = '<tr class="src-view" hidden><td colspan="5"><pre class="cov-src"></pre></td></tr>'
            table = table[:at] + data + cell + mark + table[at + len(f'<tr>{cell}') : end] + view + table[end:]
        return table

    def runs_note(self, path):
        '''`<small class="runs">` with each interpreter's lines run of `path` when they differ (one ran a line another
        did not), else ''.'''
        runs = {
            name: run['files'][path]
            for name, run in self.coverage['interpreters'].items()
            if path in run.get('files', {})
        }
        if len({tuple(v) for v in runs.values()}) < 2:
            return ''
        names = {
            name: f'CPython {name}' if 'python' in run else name for name, run in self.coverage['interpreters'].items()
        }
        text = ', '.join(f'{html.escape(names[n])}: {c} / {t}' for n, (c, t) in runs.items())
        return f' <small class="runs" title="The interpreters ran different lines of this file">{text}</small>'

    def blob_url(self, path):
        '''The project's file `path` on GitHub at `coverage`'s `commit` (`<repo>/blob/<commit>/<path in the repo>`),
        or None: no commit (a run on a changed tree), no GitHub `repo`, or the project not in a git work tree.'''
        commit, repo = self.coverage.get('commit'), self.project.repo or ''
        if not commit or not repo.startswith('https://github.com/'):
            return None
        if not hasattr(self, 'repo_prefix'):  # the project's folder in the repository (`test/docs/`, or '')
            git = ['git', '-C', str(self.project.root), 'rev-parse', '--show-prefix']
            try:
                run = subprocess.run(git, check=False, capture_output=True, text=True)
            except OSError:  # no git
                run = None
            self.repo_prefix = run.stdout.strip() if run and run.returncode == 0 else None
        if self.repo_prefix is None:
            return None
        return f'{repo.rstrip("/")}/blob/{commit}/{self.repo_prefix}{path}'

    def missed_html(self, grouped, url=None):
        '''The missed lines of `missed_functions` as HTML: per function its name (linked to its API entry when Python
        has it) and line ranges (each linked to `url#La-Lb` with a `url`), `never run` when none of its lines ran.'''
        out = []
        for name, missed, never in grouped:
            label = self.link(name) if name in self.where else html.escape(name)
            head = f'<code>{label}</code> ' if name else ''
            flag = ' <small class="never">never run</small>' if never else ''
            ranges = line_ranges(missed)
            if url:
                ranges = ', '.join(
                    f'<a href="{html.escape(url)}#L{r.replace("-", "-L")}">{r}</a>' for r in ranges.split(', ')
                )
            out.append(f'<span class="miss-fn">{head}{ranges}{flag}</span>')
        return ' '.join(out)

    def profile_page(self):
        '''A row per case: a bar per interpreter (the instructions per call, the extension's part dark); a click on
        the case shows its files' sources under it (`profileHtml` in `docs.wasm`), each line with its cost, as on
        CPython `names[0]`: under the case's row a hidden row with a heading and an empty `<pre>` per file, the
        `<pre>` with what the view needs (`data-src`, `data-lines`). Only `serve` writes it (`self.sources`: the
        files it serves at `source/<path>`); without the file, a page that says how to make it.'''
        self.sources = {}
        if not self.profile:
            body = (
                f'<h1>Profile</h1><p class="lead">No profile yet: run <code>zig build profile</code> (it writes '
                f'<code>{html.escape(self.project.config["profile"])}</code>), then reload.</p>'
            )
            return self.page('profile', 'Profile', body)
        report = self.profile
        runs = report['interpreters']
        names = list(runs)
        first = names[0] if names else ''
        cases = list(dict.fromkeys(case for run in runs.values() for case in run['cases']))
        top = max((r['total'] for run in runs.values() for r in run['cases'].values()), default=0) or 1
        runs_text = ', '.join(f'CPython {n}' for n in names)
        lead = (
            f'<p class="lead">The instructions one call of each case costs (<code>zig build profile</code>, '
            f'callgrind; each case run {report["number"]} and {2 * report["number"]} times, the difference taken, '
            f'the loop around the call taken out) on {html.escape(runs_text)}. Instructions, not time: the count is '
            f'the same on every run, so a change of one shows. {self.profile_date}.</p>'
        )
        key = (
            '<p class="prof-key"><i class="ext"></i>the extension (its Zig code, Setu\'s and std\'s inlined there)'
            '<i class="py"></i>the interpreter (the call, the arguments, the objects)</p>'
        ) + src_hints(
            f'Click a case to see where its instructions in the extension go, on CPython {html.escape(first)}: each '
            'file\'s source, a line\'s instructions per call by it (line 0 is code the compiler added).'
        )
        head = ''.join(f'<th>CPython {html.escape(n)}</th>' for n in names)
        rows = []
        for case in cases:
            cells = ''.join(
                profile_bar(runs[n]['cases'][case], top) if case in runs[n]['cases'] else '<td>-</td>' for n in names
            )
            mine = runs.get(first, {'cases': {}})['cases'].get(case)
            files = self.profile_files(mine['files'], report['sources']) if mine else []
            data = ' class="prof-row" title="Show the sources"' if files else ''
            rows.append(f'<tr{data}><td><code>{html.escape(case)}</code></td>{cells}</tr>')
            if files:
                view = ''.join(
                    f'<div class="prof-file"><code>{html.escape(f["path"])}</code> {f["total"]} per call</div>'
                    f'<pre class="cov-src prof-src" data-src="{html.escape(f["src"])}" data-lines="{f["lines"]}"></pre>'
                    for f in files
                )
                rows.append(f'<tr class="src-view" hidden><td colspan="{1 + len(names)}">{view}</td></tr>')
        table = f'<thead><tr><th>Case</th>{head}</tr></thead><tbody>{"".join(rows)}</tbody>'
        body = ['<h1>Profile</h1>', lead, key, f'<div class="prof-wrap"><table class="prof">{table}</table></div>']
        return self.page('profile', 'Profile', ''.join(body))

    def profile_files(self, files, paths):
        '''What the view of a case needs, per file (costliest first): its path, its source in the site (`source/<path>`,
        copied by `write`; '' when not found), its instructions per call, and its lines' as `line:cost` pairs.'''
        out = []
        for path, f in files.items():
            where = paths.get(path)  # absolute (`check_profile.py`), else relative to the project
            source = self.project.root / where if where else None
            src = ''
            if source and source.is_file():
                self.sources[path] = source
                src = f'{SOURCE_DIR}/{path}'
            lines = ','.join(f'{n}:{cost:.1f}' for n, cost in sorted(f['lines'].items(), key=lambda kv: int(kv[0])))
            out.append({'path': path, 'src': src, 'total': f'{f["total"]:.1f}', 'lines': lines})
        return out

    def markdown_pages_of(self, page):
        '''The Markdown page `page` as `{slug: html}`: the page, or a `split` page and its chapters (with a list of
        them, and Previous / Next links).'''
        slug, title = md_slug(page), page['title']
        if slug not in self.chapters:
            path = self.project.root / page['file']
            return {slug: self.markdown_page(page, slug, title, include_files(path.read_text(), self.project.root))}
        intro, listed = self.chapters[slug]
        links = ''.join(f'<li><a href="{s}.html">{self.inline_md(t)}</a></li>' for s, t, _text in listed)
        out = {slug: self.markdown_page(page, slug, title, intro, f'<ul class="chapters">{links}</ul>')}
        order = [(slug, title)] + [(s, t) for s, t, _text in listed]
        for i, (s, t, text) in enumerate(listed, 1):
            pager = f'<a class="prev" href="{order[i - 1][0]}.html">← {self.inline_md(order[i - 1][1])}</a>'
            if i + 1 < len(order):
                pager += f'<a class="next" href="{order[i + 1][0]}.html">{self.inline_md(order[i + 1][1])} →</a>'
            out[s] = self.markdown_page(page, s, re.sub(r'[`*]', '', t), text, f'<nav class="pager">{pager}</nav>')
        return out

    def markdown_page(self, page, slug, title, text, end=''):
        '''One page of the Markdown file of `page`: `text` (its Markdown), then the HTML `end`.'''
        self.ids = set()
        path = self.project.root / page['file']
        body, toc = self.markdown(text, path.parent)
        if not body.startswith('<h1'):
            body = f'<h1>{html.escape(title)}</h1>' + body
        if edit := self.project.config.get('edit'):
            body = f'<a class="edit" href="{html.escape(edit + page["file"])}">Edit</a>' + body
        return self.page(slug, title, body + end, toc)

    def index_page(self):
        self.ids = set()
        project = self.project
        toc = []
        if 'home' in project.config:
            path = project.root / project.config['home']
            text, toc = self.markdown(include_files(path.read_text(), self.project.root), path.parent)
        else:
            text = f'<h1>{html.escape(project.name)}</h1>'
            if summary := project.config.get('summary'):
                text += f'<p class="lead">{self.inline(summary)}</p>'
            text += self.paragraphs(project.module.__doc__ or '')
        if featured := project.config.get('featured'):
            code = (project.root / featured).read_text()
            text += f'{code_box(self.highlight(code.rstrip()))}{_run_box(featured)}'
        return self.page('index', 'Home', text, toc)

    def search_index(self):
        out = []

        def summary(obj):
            return ' '.join(sections(getattr(obj, '__doc__', None)).get('', '').split('\n\n')[0].split())[:120]

        for page, names in self.pages:
            for name in names:
                obj = self.project.find(name)
                out.append({'n': name, 'h': self.where[name], 'p': page['title'], 's': summary(obj)})
                if isinstance(obj, type) and not issubclass(obj, BaseException):
                    for member, _kind, mobj in members(obj):
                        full = f'{name}.{member}'
                        out.append({'n': full, 'h': self.where[full], 'p': page['title'], 's': summary(mobj)})
        if self.constants_page:
            for name in self.constants:
                value = repr(getattr(self.project.module, name))
                out.append({'n': name, 'h': self.where[name], 'p': self.constants_page['title'], 's': value})
        return json.dumps(out, separators=(',', ':'))

    def write(self, out):
        '''Write the site into `out`; give the names of the files written.'''
        out.mkdir(parents=True, exist_ok=True)
        css = CSS
        if 'css' in self.project.config:
            css += '\n' + (self.project.root / self.project.config['css']).read_text()
        files = {'index.html': self.index_page(), 'search.json': self.search_index(), 'style.css': css, 'app.js': JS,
                 'llms.txt': llms_index(self.project.config, self.chapters)}  # fmt: skip
        for page in self.markdown_pages:
            files.update((f'{slug}.html', text) for slug, text in self.markdown_pages_of(page).items())
        for page, names in self.pages:
            files[f'{page["slug"]}.html'] = self.api_page(page, names)
        if self.constants_page:
            files[f'{self.constants_page["slug"]}.html'] = self.constant_page()
        if self.project.scripts():
            files['examples.html'] = self.examples_page()
        self.sources = {}
        if self.coverage:
            files['coverage.html'] = self.coverage_page()
        if self.project.stub:
            files['llms-full.txt'] = llms_full(self.project.stub, self.project.config['module'])
        for name, text in files.items():
            (out / name).write_text(pretty_html(text) if name.endswith('.html') else text)
        copied = ['docs.wasm']
        if self.project.favicon:
            shutil.copyfile(self.project.root / self.project.config['favicon'], out / self.project.favicon)
            copied.append(self.project.favicon)
        build_wasm(self.project.root, out / 'docs.wasm')
        # the Coverage page's sources, as they are, for its viewer (`source/<path>`); old ones go in `forget_old_files`
        for path, source in self.sources.items():
            dest = out / SOURCE_DIR / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, dest)
            copied.append(f'{SOURCE_DIR}/{path}')
        written = sorted([*files, *copied])
        forget_old_files(out, written)
        return written


MANIFEST = '.setu-docs-files'  # in the site's folder: the files the last build wrote, one per line


def forget_old_files(out, written):
    '''Remove the files the previous build of `out` wrote (its `MANIFEST`) that this one did not (a page or source
    gone), and folders left empty by that; then record `written`. Files the builder never wrote stay.'''
    manifest = out / MANIFEST
    try:
        before = manifest.read_text().splitlines()
    except OSError:
        before = []
    for name in sorted(set(before) - set(written)):
        path = out / name
        if '..' in pathlib.PurePosixPath(name).parts or not path.is_file():
            continue  # never outside `out`
        path.unlink()
        for folder in path.parents:
            if folder == out or any(folder.iterdir()):
                break
            folder.rmdir()
    manifest.write_text(''.join(f'{name}\n' for name in written))


# `pretty_html`: block tags go on their own line and indent what is inside; in a text block (`TEXT_TAGS`) the text
# and inline tags stay on the opening tag's line.
BLOCK_TAGS = frozenset({
    'html', 'head', 'body', 'header', 'main', 'nav', 'footer', 'section', 'article', 'aside', 'div', 'h1', 'h2', 'h3',
    'h4', 'h5', 'h6', 'p', 'ul', 'ol', 'li', 'dl', 'dt', 'dd', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td',
    'blockquote', 'details', 'summary', 'figure', 'figcaption', 'title', 'meta', 'link', 'hr',
})  # fmt: skip
TEXT_TAGS = frozenset({
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'li', 'dt', 'dd', 'th', 'td', 'summary', 'figcaption', 'title', 'footer',
})  # fmt: skip
VOID_TAGS = frozenset(
    {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr'}
)
RAW_TAGS = frozenset({'pre', 'script', 'style', 'textarea'})
ATTRS = r'''(?:"[^"]*"|'[^']*'|[^'">])*'''  # up to a tag's `>`, which may be inside a quoted attribute value
HTML_SPACE = ' \t\n\r\f'  # HTML's whitespace; not Python's `\s`, which takes in a no-break space (it renders)
# a comment, `<!doctype>`, a tag (`/`, name), a word, a run of whitespace, a lone `<`
HTML_TOKEN = re.compile(
    rf'<!--.*?-->|<!{ATTRS}>|<(/?)([a-zA-Z][\w-]*){ATTRS}>|[^<{HTML_SPACE}]+|[{HTML_SPACE}]+|<', re.DOTALL
)


def pretty_html(text):
    '''`text` with every block tag on its own line, indented 2 spaces per open block.

    Only whitespace that does not render changes, so the page looks the same: next to a block tag, or a line
    break between inline parts (one space however it is indented). Inline parts that touch stay together. A text
    block (`<p>`, `<li>`, `<td>`, headings, ...; or any block with only inline content) keeps its text and inline
    tags on the opening tag's line, with its closing tag; so does an empty element. `<script>` / `<style>` /
    `<textarea>` are copied as they are (a `<textarea>` with content gets a line break after its opening tag, which
    the parser drops). A `<pre>` with content is split into lines, one `<span class="ln">` each (`pre_lines`),
    each on its own line, not indented: the only whitespace between them is the line break, so the `<pre>`'s
    `textContent` is the code (the CSS drops that line break and keeps the whitespace inside a `.ln`).

    Example
        >>> print(pretty_html('<div><p>Hi <b>there</b></p><a>x</a><a>y</a><div>z</div></div>'), end='')
        <div>
          <p>Hi <b>there</b></p>
          <a>x</a><a>y</a>
          <div>z</div>
        </div>

        >>> print(pretty_html('<div><pre>if x:\\n    y()</pre></div>'), end='')
        <div>
          <pre>
        <span class="ln">if x:</span>
        <span class="ln">    y()</span></pre>
        </div>
    '''
    out, stack, pos, after_block, space, opened = [], [], 0, True, '', ''
    while pos < len(text):
        m = HTML_TOKEN.match(text, pos)
        pos, token = m.end(), m.group(0)
        tag, closing = (m.group(2) or '').lower(), bool(m.group(1))
        if tag in RAW_TAGS and not closing:  # through its closing tag, as is
            end = re.compile(rf'</{tag}\s*>', re.IGNORECASE).search(text, pos)
            body_end, pos = (end.start(), end.end()) if end else (len(text), len(text))
            token = text[m.start() : pos]
            if tag == 'pre' and text[m.end() : body_end]:
                lines = ''.join(f'\n{LINE_OPEN}{line}</span>' for line in pre_lines(text[m.end() : body_end]))
                token = f'{m.group(0)}{lines}{text[body_end:pos]}'
            elif tag == 'textarea' and m.end() < body_end and text[m.end()] not in '\r\n':
                # the parser drops one line break right after `<textarea>`: the content starts on its own line
                token = text[m.start() : m.end()] + '\n' + text[m.end() : pos]
        elif not token.strip(HTML_SPACE):
            space += token
            continue
        in_text = bool(stack) and stack[-1][1]
        if tag in BLOCK_TAGS or tag in RAW_TAGS or token.startswith(('<!D', '<!d')):
            if closing and any(t == tag for t, _ in stack):
                while stack.pop()[0] != tag:
                    pass
            # `<div></div>` and `<p>text</p>` keep their closing tag on the line
            same_line = closing and not space and (tag == opened or (not after_block and in_text))
            out.append(token if same_line else '\n' + '  ' * len(stack) + token)
            if not closing and tag in BLOCK_TAGS and tag not in VOID_TAGS:
                stack.append((tag, tag in TEXT_TAGS or inline_only(text, pos, tag)))
            after_block, opened = True, '' if closing else tag
        else:
            newline = (after_block and (space or not in_text)) or '\n' in space
            out.append(('\n' + '  ' * len(stack) if newline else space) + token)
            after_block, opened = False, ''
        space = ''
    return ''.join(out).strip('\n') + '\n'


LINE_OPEN = '<span class="ln">'
LINE_SPLIT = re.compile(rf'</span>[{HTML_SPACE}]*{LINE_OPEN}')


def pre_lines(body):
    '''The lines of a `<pre>`'s `body` (HTML), each whole: a tag open at a line break is closed at the end of the
    line and opened again on the next. A `body` already in `<span class="ln">` lines (`pretty_html`'s own output)
    gives those lines back.

    Example
        >>> pre_lines('<b>a\\nb</b>\\nc\\n')
        ['<b>a</b>', '<b>b</b>', 'c']
    '''
    inner = body.strip(HTML_SPACE)
    if inner.startswith(LINE_OPEN) and inner.endswith('</span>'):
        return LINE_SPLIT.split(inner[len(LINE_OPEN) : -len('</span>')])
    body = body.removeprefix('\n')  # the parser drops it
    lines, line, opened = [], [], []
    for m in HTML_TOKEN.finditer(body):
        token, name = m.group(0), (m.group(2) or '').lower()
        if not name:
            *done, rest = token.split('\n')
            for part in done:
                lines.append(''.join([*line, part, *(f'</{n}>' for n, _ in reversed(opened))]))
                line = [t for _, t in opened]
            line.append(rest)
            continue
        line.append(token)
        if m.group(1):
            if opened:
                opened.pop()
        elif name not in VOID_TAGS:
            opened.append((name, token))
    lines.append(''.join(line))
    if len(lines) > 1 and not lines[-1]:  # a last line break shows no line
        lines.pop()
    return lines


def inline_only(text, pos, tag):
    '''Whether `text` from `pos` reaches `</tag>` before any block tag (the open `tag`'s content is all inline).'''
    for m in HTML_TOKEN.finditer(text, pos):
        name = (m.group(2) or '').lower()
        if name in BLOCK_TAGS or name in RAW_TAGS:
            return bool(m.group(1)) and name == tag
    return False


def autolink(text):
    '''Escape `text`, turning bare `http(s)://` URLs into links. Trailing `.,;:!?)]` stays text, except a `)` that
    closes a `(` in the URL (as GFM does).

    Example
        >>> autolink('(see https://en.wikipedia.org/wiki/Io_(moon).)')
        '(see <a href="https://en.wikipedia.org/wiki/Io_(moon)">https://en.wikipedia.org/wiki/Io_(moon)</a>.)'
    '''
    out, pos = [], 0
    for m in BARE_URL.finditer(text):
        url = m.group(0)
        while url[-1] in '.,;:!?)]' and not (url[-1] == ')' and url.count('(') >= url.count(')')):
            url = url[:-1]
        if url.endswith('//'):  # nothing after the scheme
            continue
        out.append(f'{html.escape(text[pos : m.start()])}<a href="{html.escape(url)}">{html.escape(url)}</a>')
        pos = m.start() + len(url)
    out.append(html.escape(text[pos:]))
    return ''.join(out)


SOURCE_DIR = 'source'  # the site's folder of the Coverage page's sources


def slug(text):
    '''`text` as an anchor id: lower case, a run of anything but letters, digits, `_` and `.` as `-`.

    Example
        >>> slug('Liburing + Setu')
        'liburing-setu'
    '''
    return re.sub(r'[^\w.]+', '-', text.lower()).strip('-')


def section_heading(anchor, title):
    '''An `<h2>` with its anchor link.'''
    anchor = html.escape(anchor)
    return f'<h2 id="{anchor}">{html.escape(title)}<a class="anchor" href="#{anchor}">#</a></h2>'


def dependency_root(root, name):
    '''Where the dependency `name` of `root/build.zig.zon` is: its `.path`, else `zig-pkg/<.hash>` (where `zig
    build` puts a fetched package), else None.'''
    try:
        zon = re.sub(r'//.*', '', (root / 'build.zig.zon').read_text())
    except OSError:
        return None
    entry = re.search(rf'\.{re.escape(name)}\s*=\s*\.\{{(.*?)\}}', zon, re.DOTALL)
    if not entry:
        return None
    if path := re.search(r'\.path\s*=\s*"([^"]+)"', entry[1]):
        return (root / path[1]).resolve()
    if digest := re.search(r'\.hash\s*=\s*"([^"]+)"', entry[1]):
        return root / 'zig-pkg' / digest[1]
    return None


def display_name(root, name):
    '''A dependency's name as shown: `name` in the `[tool.setu_docs]` of its own `pyproject.toml` (Setu's: `Setu`),
    else its package name `name`.'''
    if root is None:
        return name
    try:
        with open(root / 'pyproject.toml', 'rb') as f:
            shown = tomllib.load(f).get('tool', {}).get('setu_docs', {}).get('name')
    except OSError:
        return name
    except tomllib.TOMLDecodeError:
        return name
    return shown if isinstance(shown, str) and shown else name


def coverage_level(percent):
    '''kcov's high / medium / low color for `percent` (`ok` / `warn` / `bad`), at 95 / 90 % (kcov's 75 / 25 would
    make every file green).'''
    return 'ok' if percent >= 95 else 'warn' if percent >= 90 else 'bad'


def coverage_total(covered, lines):
    percent = 100 * covered / lines if lines else 100
    return f'<b>{percent:.1f}%</b>, {covered} / {lines} lines'


def coverage_donut(name, covered, lines):
    '''A donut of `covered` / `lines` in the level's color, the percent inside; hovering a part names its lines.'''
    percent = 100 * covered / lines if lines else 100
    ring = 'cx="50" cy="50" r="40" fill="none" stroke-width="12"'
    name = html.escape(name)
    return (
        f'<figure><svg viewBox="0 0 100 100" role="img" aria-label="{name}: {percent:.1f}% covered">'
        f'<circle {ring} stroke="var(--line)"><title>missed: {lines - covered} lines</title></circle>'
        f'<circle {ring} stroke="var(--{coverage_level(percent)})" pathLength="100" stroke-dasharray="{percent:.2f} '
        f'100" transform="rotate(-90 50 50)"><title>covered: {covered} of {lines} lines</title></circle>'
        f'<text x="50" y="50" text-anchor="middle" dominant-baseline="central">{percent:.1f}%</text></svg>'
        f'<figcaption><strong>{name}</strong><br>{covered} / {lines} lines, {lines - covered} missed</figcaption>'
        '</figure>'
    )


def coverage_history_chart(runs):
    '''A line of the total per version (`coverage_history`, oldest first), from the lowest percent (rounded down)
    to 100%; hovering a point names its version. '' without runs.'''
    if not runs:
        return ''
    percents = [100 * r['covered'] / r['lines'] for r in runs]
    low = min(int(min(percents)), 99)  # at least 1% of height
    x = [20 + 260 * i / (len(runs) - 1) if len(runs) > 1 else 150 for i in range(len(runs))]
    y = [20 + 100 * (100 - p) / (100 - low) for p in percents]
    points = ' '.join(f'{a:.1f},{b:.1f}' for a, b in zip(x, y))
    dots = ''.join(
        f'<circle cx="{a:.1f}" cy="{b:.1f}" r="4" fill="var(--{coverage_level(p)})"><title>'
        f'{html.escape(r["version"])}: {p:.1f}% ({r["covered"]} / {r["lines"]} lines)</title></circle>'
        for a, b, p, r in zip(x, y, percents, runs)
    )
    first, last = html.escape(runs[0]['version']), html.escape(runs[-1]['version'])
    span = f'{len(runs)} versions, {first} to {last}' if len(runs) > 1 else f'1 version, {first}'
    return (
        f'<figure><svg class="cov-history" viewBox="0 0 300 144" role="img" aria-label="Coverage history: {span}">'
        '<line x1="20" y1="20" x2="280" y2="20" stroke="var(--line)"/>'
        '<line x1="20" y1="120" x2="280" y2="120" stroke="var(--line)"/>'
        '<text x="20" y="14">100%</text>'
        f'<text x="20" y="136">{low}%</text>'
        f'<polyline points="{points}" fill="none" stroke="var(--muted)" stroke-width="2"/>{dots}</svg>'
        f'<figcaption><strong>History</strong><br>{span}</figcaption></figure>'
    )


def line_ranges(numbers):
    '''Sorted line numbers as ranges.

    Example
        >>> line_ranges([3, 4, 5, 9, 11, 12])
        '3-5, 9, 11-12'
    '''
    out = []
    for n in numbers:
        if out and out[-1][1] == n - 1:
            out[-1][1] = n
        else:
            out.append([n, n])
    return ', '.join(f'{a}' if a == b else f'{a}-{b}' for a, b in out)


FN_DECL = re.compile(r'^\s*(?:pub\s+)?(?:export\s+)?(?:inline\s+|noinline\s+)?fn\s+(\w+)\s*\(')


def missed_functions(source, hits):
    '''The missed lines of the Zig `source` grouped by the function they are in: `(name, missed, never_run)` per
    function with one, in order; `name` '' for lines before any function, `never_run` when none of the function's
    code lines ran. `hits`: each code line's hit count. A line belongs to the last `fn` above it.

    Example
        >>> missed_functions('fn a() void {\\n  x();\\n}\\nfn b() void {\\n  y();\\n  z();\\n}', {2: 0, 5: 1, 6: 0})
        [('a', [2], True), ('b', [6], False)]
    '''
    starts = [(i + 1, m.group(1)) for i, line in enumerate(source.splitlines()) if (m := FN_DECL.match(line))]
    groups = {}  # first line of the function -> (name, lines, missed)
    for n in sorted(hits):
        start, name = max(((s, fn) for s, fn in starts if s <= n), default=(0, ''))
        group = groups.setdefault(start, (name, [], []))
        group[1].append(n)
        if hits[n] == 0:
            group[2].append(n)
    return [
        (name, missed, bool(name) and len(missed) == len(lines)) for name, lines, missed in groups.values() if missed
    ]


def coverage_table(files):
    '''A row per `(path, covered, lines, missed)`: the percent in its level's color, a bar, the counts and the missed
    lines.'''
    rows = []
    for path, covered, lines, missed in files:
        percent = 100 * covered / lines if lines else 100
        level = coverage_level(percent)
        rows.append(
            f'<tr><td><code>{html.escape(path)}</code></td><td class="pct {level}">{percent:.1f}%</td>'
            f'<td><span class="bar"><span class="{level}" style="width:{percent:.1f}%"></span></span></td>'
            f'<td class="num">{covered} / {lines}</td><td class="missed">{line_ranges(missed)}</td></tr>'
        )
    return (
        '<table class="cov"><thead><tr><th>File</th><th>Coverage</th><th></th><th>Lines</th><th>Missed lines</th>'
        f'</tr></thead><tbody>{"".join(rows)}</tbody></table>'
    )


def profile_bar(result, top):
    '''A table cell: the case's instructions per call as a bar (scaled to `top`), the extension's part dark.'''
    total, ext = result['total'], result['ext']
    share = 100 * ext / total if total > 0 else 0
    tip = f'{total:.1f} per call: {ext:.1f} in the extension ({share:.0f}%), {total - ext:.1f} in the interpreter'
    return (
        f'<td class="prof-cell" title="{html.escape(tip)}"><span class="pnum"><b>{total:.0f}</b> / {ext:.0f}</span>'
        f'<span class="ptrack"><span class="pbar" style="width:{max(0, 100 * total / top):.1f}%">'
        f'<i style="width:{min(100, share):.1f}%"></i></span></span></td>'
    )


def build_wasm(root, dest):
    '''Build the site's Wasm module (`zig build docs-web` in `root`, from Setu's `tools/setu_docs_web.zig`)
    into `dest`.

    Note
        - `ZIG=/path/to/zig` picks the compiler (default: `zig` on PATH).
    '''
    with tempfile.TemporaryDirectory(prefix='setu-docs-') as prefix:
        zig = [os.environ.get('ZIG', 'zig'), 'build', 'docs-web', '--prefix', prefix]
        subprocess.run(zig, cwd=root, check=True)
        shutil.copyfile(pathlib.Path(prefix) / 'web' / 'docs.wasm', dest)


def src_hints(text):
    '''The viewer's hint `text` (HTML), hidden, and the one a page without `docs.wasm` (opened from disk) shows instead;
    `docs.wasm` swaps them.'''
    return (
        f'<p class="src-hint" hidden>{text}</p>'
        '<p class="src-hint">The sources need a server: python3 -m http.server in the site, or setu_docs.py serve.</p>'
    )


def code_box(body, cls='code', attrs=''):
    '''A `<pre>` of the HTML `body` in its `.codebox` with its Copy button, hidden (`docs.wasm` shows it).'''
    return (
        f'<div class="codebox"><pre class="{cls}"{attrs}>{body}</pre>'
        '<button class="copy" type="button" hidden>Copy</button></div>'
    )


def _run_box(target):
    return (
        f'<div class="run" data-target="{html.escape(target)}"><button type="button">Run</button>'
        '<span class="status"></span><pre class="result" hidden></pre></div>'
    )


def _not_runnable():
    return '<p class="muted">Not run from the page: start it from a terminal.</p>'


def _needs(names):
    '''In place of a Run box (shown only where Run would be): the example reads `names`, which no fixture gives.'''
    names = ', '.join(f'<code>{html.escape(n)}</code>' for n in names)
    return f'<p class="needs">No Run: nothing defines {names} (a fixture in the hooks would).</p>'


def chart_number(cell):
    '''The number a chart cell shows (`627,427`, `**627k**`, `48 ns`), or None.

    Example
        >>> [chart_number(c) for c in ('627,427', '**1.5k**', '48 ns', '-')]
        [627427.0, 1500.0, 48.0, None]
    '''
    m = CHART_NUMBER.match(re.sub(r'[`*_]', '', cell).strip())
    if not m:
        return None
    return float(m.group(1).replace(',', '')) * {'': 1, 'k': 1e3, 'M': 1e6, 'G': 1e9}[m.group(2)]


CSS = '''
/* Tokyo Night colors (tokyonight.nvim): light = Tokyo Night Day, with Tokyo Night Light's darker text (Day's
   `#3760bf` is hard to read in long text; code keeps it, `--code-fg`); dark = Tokyo Night. A plain `:root`, so the
   dark blocks below (more specific) win in dark mode. Until a theme is picked in the ◐ menu (no `data-theme`) it is
   Tokyo Day, or Nord Night (`setu_docs_web.zig`'s `default_theme`) when the system is dark. */
:root {
  --bg: #e1e2e7; --panel: #d0d5e3; --line: #c4c8da; --text: #343b58; --muted: #68709a;
  --accent: #2e7de9; --accent-soft: #b7c1e3; --code-bg: #e9e9ed; --ok: #587539; --bad: #f52a65; --warn: #8c6c3e;
  --kw: #9854f1; --str: #587539; --num: #b15c00; --com: #848cb5; --bi: #188092; --ref: #007197;
  --code-fg: #3760bf; --fn: #2e7de9;
  --con: #b15c00; --slf: #f52a65; --ty: #188092; --attr: #387068; --dec: #007197; --op: #006a83;
  --arg: #8c6c3e;
  --s1: #2e7de9; --s2: #b15c00; --s3: #587539; --s4: #8c6c3e; --s5: #9854f1; --s6: #118c74; --s7: #007197;
  --s8: #f52a65; --s-other: #a8aecb;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) {
    --bg: #2e3440; --panel: #3b4252; --line: #434c5e; --text: #e5e9f0; --muted: #a0a8b7;
    --accent: #88c0d0; --accent-soft: #434c5e; --code-bg: #3b4252; --ok: #a3be8c; --bad: #bf616a; --warn: #ebcb8b;
    --kw: #81a1c1; --str: #a3be8c; --num: #b48ead; --com: #616e88; --bi: #88c0d0; --ref: #88c0d0;
    --code-fg: #d8dee9; --fn: #88c0d0;
    --con: #81a1c1; --slf: #d08770; --ty: #8fbcbb; --attr: #d8dee9; --dec: #d08770; --op: #81a1c1;
    --arg: #ebcb8b;
    --s1: #88c0d0; --s2: #d08770; --s3: #a3be8c; --s4: #ebcb8b; --s5: #b48ead; --s6: #8fbcbb; --s7: #5e81ac;
    --s8: #bf616a; --s-other: #4c566a;
  }
  :root:not([data-theme]) .run button { color: #2e3440; }
}
:root[data-theme="dark"] {
  --bg: #1a1b26; --panel: #16161e; --line: #292e42; --text: #c0caf5; --muted: #737aa2;
  --accent: #7aa2f7; --accent-soft: #283457; --code-bg: #16161e; --ok: #9ece6a; --bad: #f7768e; --warn: #e0af68;
  --kw: #bb9af7; --str: #9ece6a; --num: #ff9e64; --com: #565f89; --bi: #2ac3de; --ref: #7dcfff;
  --code-fg: #a9b1d6; --fn: #7aa2f7;
  --con: #ff9e64; --slf: #f7768e; --ty: #2ac3de; --attr: #73daca; --dec: #7dcfff; --op: #89ddff;
  --arg: #e0af68;
  --s1: #7aa2f7; --s2: #ff9e64; --s3: #9ece6a; --s4: #e0af68; --s5: #bb9af7; --s6: #73daca; --s7: #7dcfff;
  --s8: #f7768e; --s-other: #565f89;
}
:root[data-theme="dark"] .run button { color: #1a1b26; }
/* The other themes, picked in the header's ◐ menu (`<html data-palette="...">`, kept in localStorage); no
   `data-palette` is Tokyo. Each has a light and a dark set, switched by `data-theme` as above (a picked palette
   always comes with its `data-theme`). */
/* Nord (nordtheme.com): light = Snow Storm with Polar Night text (Aurora darkened to read on it), dark = Polar
   Night with Snow Storm text. */
:root[data-palette="nord"] {
  --bg: #eceff4; --panel: #e5e9f0; --line: #d8dee9; --text: #2e3440; --muted: #4c566a;
  --accent: #5e81ac; --accent-soft: #c9d4e5; --code-bg: #e5e9f0; --ok: #5a7a3a; --bad: #b0444e; --warn: #8a6d1f;
  --kw: #5e81ac; --str: #5a7a3a; --num: #8f5f88; --com: #7b88a1; --bi: #3f7f8a; --ref: #3e6a99;
  --code-fg: #2e3440; --fn: #3b7b8c;
  --con: #5e81ac; --slf: #b0573a; --ty: #3f7f7e; --attr: #3b4252; --dec: #b0573a; --op: #5e81ac;
  --arg: #8a6d1f;
  --s1: #5e81ac; --s2: #b0573a; --s3: #5a7a3a; --s4: #8a6d1f; --s5: #8f5f88; --s6: #3f7f7e; --s7: #3e6a99;
  --s8: #b0444e; --s-other: #c0c8d6;
}
:root[data-palette="nord"][data-theme="dark"] {
  --bg: #2e3440; --panel: #3b4252; --line: #434c5e; --text: #e5e9f0; --muted: #a0a8b7;
  --accent: #88c0d0; --accent-soft: #434c5e; --code-bg: #3b4252; --ok: #a3be8c; --bad: #bf616a; --warn: #ebcb8b;
  --kw: #81a1c1; --str: #a3be8c; --num: #b48ead; --com: #616e88; --bi: #88c0d0; --ref: #88c0d0;
  --code-fg: #d8dee9; --fn: #88c0d0;
  --con: #81a1c1; --slf: #d08770; --ty: #8fbcbb; --attr: #d8dee9; --dec: #d08770; --op: #81a1c1;
  --arg: #ebcb8b;
  --s1: #88c0d0; --s2: #d08770; --s3: #a3be8c; --s4: #ebcb8b; --s5: #b48ead; --s6: #8fbcbb; --s7: #5e81ac;
  --s8: #bf616a; --s-other: #4c566a;
}
:root[data-palette="nord"][data-theme="dark"] .run button { color: #2e3440; }
* { box-sizing: border-box; }
html { scroll-padding-top: 64px; }
body { margin: 0; background: var(--bg); color: var(--text);
  font: 17px/1.6 system-ui, -apple-system, "Segoe UI", sans-serif; }
a { color: var(--ref); text-decoration: none; }
a:hover { text-decoration: underline; }
code, pre { font-family: ui-monospace, "JetBrains Mono", "Cascadia Code", Menlo, monospace; font-size: 15px; }
:not(pre) > code { background: var(--code-bg); border: 1px solid var(--line); border-radius: 4px; padding: 0 4px; }
.top { position: sticky; top: 0; z-index: 10; height: 52px; background: var(--panel);
  border-bottom: 1px solid var(--line); }
/* The bar's row is as wide as `.wrap`: the brand starts where `main`'s text does, the tools end where the nav's
   links do, and the search sits in the middle column, so it is centered whatever the two sides hold. */
.top-in { display: grid; grid-template-columns: 1fr minmax(0, 420px) 1fr; align-items: center; gap: 16px;
  max-width: 1280px; height: 100%; margin: 0 auto; padding: 0 24px 0 40px; }
.brand { justify-self: start; font-weight: 700; font-size: 21px; color: var(--text); white-space: nowrap; }
.tools { justify-self: end; display: flex; align-items: center; gap: 12px;
  --icon: 20px; }  /* the height of every header icon (◐, the GitHub mark, ☰) */
.ver { font-weight: 400; color: var(--muted); font-size: 13px; }
.menu, .theme { display: flex; background: none; border: 0; padding: 0; color: var(--text); cursor: pointer; }
.menu { display: none; }
.menu svg, .theme svg { height: var(--icon); width: auto; }
.search { position: relative; }
.search input { width: 100%; padding: 6px 10px; border: 1px solid var(--line); border-radius: 6px;
  background: var(--bg); color: var(--text); font: inherit; }
#hits { position: absolute; top: 38px; left: 0; right: 0; max-height: 60vh; overflow: auto; background: var(--bg);
  border: 1px solid var(--line); border-radius: 6px; box-shadow: 0 8px 24px rgba(0,0,0,.15); }
#hits a { display: block; padding: 6px 10px; color: var(--text); border-bottom: 1px solid var(--line); }
#hits a.sel, #hits a:hover { background: var(--accent-soft); text-decoration: none; }
#hits small { display: block; color: var(--muted); }
.live { font-size: 12px; color: var(--muted); border: 1px solid var(--line); border-radius: 99px;
  padding: 1px 8px; white-space: nowrap; }
.live.on { color: var(--ok); border-color: var(--ok); }
/* The ◐ button's theme menu, under it at the right, boxed like the search hits; ✓ marks the theme shown. */
.themes { position: relative; display: flex; }
.theme-menu { position: absolute; top: calc(100% + 12px); right: 0; z-index: 20; display: flex;
  flex-direction: column; padding: 4px; background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
  box-shadow: 0 8px 24px rgba(0,0,0,.15); }
.theme-menu[hidden] { display: none; }
.theme-menu button { position: relative; font: 13px system-ui, sans-serif; text-align: left; white-space: nowrap;
  color: var(--text); background: none; border: 0; border-radius: 4px; padding: 5px 12px 5px 24px; cursor: pointer; }
.theme-menu button:hover, .theme-menu button:focus-visible { background: var(--accent-soft); outline: none; }
.theme-menu button[aria-checked="true"]::before { content: "✓"; position: absolute; left: 8px; color: var(--accent); }
.repo { display: flex; align-items: center; gap: 8px; color: var(--text); line-height: 1.25; white-space: nowrap; }
.repo:hover { text-decoration: none; opacity: .8; }
.repo .gh { height: var(--icon); width: auto; flex: none; }
.repo-in { display: flex; flex-direction: column; align-items: flex-start; }
.repo-name { font-size: 14px; font-weight: 600; }
.facts { display: flex; gap: 10px; font-size: 12px; color: var(--muted); }
.facts[hidden] { display: none; }
.fact { display: inline-flex; align-items: center; gap: 3px; }
.fact svg { width: 12px; height: 12px; fill: none; stroke: currentColor; stroke-width: 1.3; stroke-linejoin: round; }
.fact:has(> span:empty) { display: none; }
.wrap { display: flex; max-width: 1280px; margin: 0 auto; }
.side { position: sticky; top: 52px; align-self: flex-start; width: 240px; flex: none; height: calc(100vh - 52px);
  overflow: auto; padding: 16px 16px 32px 8px; border-left: 1px solid var(--line); }
.side a { display: block; padding: 3px 8px; border-radius: 4px; color: var(--text); font-size: 16px; }
.side a.on { background: var(--accent-soft); color: var(--accent); font-weight: 600; }
.side a.live-only { display: none; } body.can-run .side a.live-only { display: block; }
.nav-h { font-size: 14px; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); margin: 14px 8px 2px; }
.side a.sub { padding-left: 20px; font-size: 15px; }
.toc { margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--line); }
.toc a { font-family: ui-monospace, monospace; font-size: 14.5px; color: var(--muted); overflow-wrap: anywhere;
  padding-left: calc(8px + 2ch); text-indent: -2ch; }  /* a wrapped name lines up after its `- ` */
.toc a::before { content: '-'; display: inline-block; width: 2ch; text-indent: 0; }  /* inline-block: no underline */
.toc-h { font-size: 14px; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); margin: 0 8px 4px; }
main { flex: 1; min-width: 0; padding: 24px 40px 64px; }
h1 { margin: 8px 0 4px; font-size: 30px; }
h2 { margin-top: 36px; border-bottom: 1px solid var(--line); padding-bottom: 4px; }
h3 { font-size: 22px; }
h1:hover .anchor, h2:hover .anchor, h3:hover .anchor { color: var(--muted); }
.lead { color: var(--muted); font-size: 16px; margin-top: 4px; }
.edit { float: right; font-size: 13px; margin-top: 14px; }
.pager { display: flex; gap: 16px; margin-top: 40px; padding-top: 12px; border-top: 1px solid var(--line); }
.pager .next { margin-left: auto; text-align: right; }
.index { display: flex; flex-wrap: wrap; gap: 6px 14px; padding: 0; list-style: none; margin: 16px 0 8px; }
.entry { border-top: 1px solid var(--line); padding: 20px 0 8px; }
.entry h3 { margin: 0 0 8px; font: 600 15px/1.5 ui-monospace, monospace; word-break: break-word; }
.nm { color: var(--accent); }
.kind { color: var(--muted); font-weight: 400; font-style: italic; }
.badge { margin-left: 8px; font: 600 11px system-ui, sans-serif; color: var(--bi); border: 1px solid var(--bi);
  border-radius: 99px; padding: 0 6px; vertical-align: 2px; }
.anchor { margin-left: 8px; color: var(--line); font-weight: 400; }
.entry:hover .anchor, .member:hover .anchor { color: var(--muted); }
h4 { margin: 14px 0 4px; font-size: 15px; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); }
h4.mh { text-transform: none; letter-spacing: 0; font: 600 14px/1.5 ui-monospace, monospace; color: var(--text); }
.members { margin: 12px 0 0 0; padding-left: 16px; border-left: 3px solid var(--panel); }
.member { padding: 4px 0 8px; }
.bases { color: var(--muted); margin: 0; }
/* `pretty_html` puts a `<pre>`'s lines in `.ln` blocks, a line break between them: that one goes, the whitespace in
   them stays; an empty line keeps its height. */
pre:has(> .ln) { white-space: normal; } pre > .ln { display: block; white-space: pre; }
pre > .ln:empty::before { content: "\\200b"; }
pre.code, pre.plain, pre.result { background: var(--code-bg); border: 1px solid var(--line); border-radius: 6px;
  padding: 10px 12px; overflow-x: auto; line-height: 1.5; margin: 6px 0; }
.codebox { position: relative; }
.codebox .copy { position: absolute; top: 6px; right: 6px; opacity: 0; font: 12px system-ui, sans-serif;
  padding: 1px 8px; border: 1px solid var(--line); border-radius: 4px; background: var(--panel); color: var(--muted);
  cursor: pointer; }
.codebox:hover .copy, .codebox .copy:focus { opacity: 1; } .codebox .copy[hidden] { display: none; }
.kw { color: var(--kw); } .str { color: var(--str); } .num { color: var(--num); } .com { color: var(--com); }
.bi { color: var(--bi); } a.ref { color: var(--ref); } .pr { color: var(--muted); user-select: none; }
/* Token kinds a `css` file may leave out (`--fn`, ...); without one they fall back to a color above or the text's. */
.fn { color: var(--fn, inherit); } .con { color: var(--con, var(--num)); } .slf { color: var(--slf, inherit); }
.ty { color: var(--ty, var(--bi)); } .attr { color: var(--attr, inherit); } .dec { color: var(--dec, var(--kw)); }
.op { color: var(--op, inherit); } .arg { color: var(--arg, inherit); }
/* Code blocks as in the Tokyo Night editor: API names (`a.ref`) in the function blue, comments italic, the rest
   in the editor's foreground; inline `code` keeps the text color. */
pre.code { color: var(--code-fg, var(--text)); } pre.code a.ref { color: var(--fn, var(--ref)); }
pre.code .com { font-style: italic; }
.out { color: var(--muted); }
table { border-collapse: collapse; margin: 4px 0; }
td, th { padding: 3px 14px 3px 0; text-align: left; vertical-align: top; border-bottom: 1px solid var(--line); }
th { font-size: 12px; text-transform: uppercase; color: var(--muted); }
table.md { margin: 12px 0; display: block; overflow-x: auto; }
table.md th { text-transform: none; font-size: 14px; color: var(--text); }
.consts td:nth-child(2), .consts td:nth-child(3) { font-variant-numeric: tabular-nums; }
.consts tr:target { background: var(--accent-soft); }
/* The selected entry (or constants group): a 1px dashed bar on each side, centered in `main`'s left / right padding.
   A border, not a 1px wide background: borders snap to whole device pixels, so a bar on a half pixel (`.wrap` is
   centered) is not drawn 2px. The dashes (8px, 6px gap; `dashed` can not set a length) are a `border-image`, which
   snaps the same way. */
:is(.entry, .member, .group, .part):target { position: relative; }
:is(.entry, .member, .group, .part):target::before, :is(.entry, .member, .group, .part):target::after { content: "";
  position: absolute; top: 11px; bottom: 11px; width: 0; border-left: 1px solid var(--accent);
  border-image: repeating-linear-gradient(to bottom, var(--accent) 0 8px, transparent 8px 14px) 1; }
:is(.entry, .member, .group, .part):target::before { left: -20px; }
:is(.entry, .member, .group, .part):target::after { right: -20px; }
ul, ol { padding-left: 20px; } li { margin: 2px 0; }
ul.flags { list-style: none; padding: 0; display: flex; gap: 8px; flex-wrap: wrap; }
ul.flags.described { display: block; }
blockquote { margin: 12px 0; padding: 2px 14px; border-left: 3px solid var(--accent); border-radius: 6px;
  background: var(--panel); }
hr { border: 0; border-top: 1px solid var(--line); margin: 24px 0; }
img { max-width: 100%; }
details.fixture summary { cursor: pointer; color: var(--muted); font-size: 13px; }
.run { margin: 4px 0 8px; }
.run button { display: none; font: 600 13px system-ui, sans-serif; padding: 3px 12px; border-radius: 5px;
  border: 1px solid var(--accent); background: var(--accent); color: #fff; cursor: pointer; }
.run button:disabled { opacity: .6; cursor: progress; }
body.can-run .run button { display: inline-block; }
.run .status { margin-left: 10px; font-size: 13px; }
.status.ok { color: var(--ok); } .status.fail { color: var(--bad); }
.result .st-fail { color: var(--bad); } .result .st-skip, .result .st-loose { color: var(--warn); }
.result .exp { color: var(--bad); }
.muted { color: var(--muted); }
.needs { display: none; margin: 4px 0 8px; color: var(--muted); font-size: 13px; }
body.can-run .needs { display: block; }
.chart { margin: 12px 0 16px; }
.chart .legend { display: flex; flex-wrap: wrap; gap: 2px 16px; margin-bottom: 8px; font-size: 13px; }
.chart .legend i { display: inline-block; width: 10px; height: 10px; margin-right: 6px; border-radius: 2px; }
.chart .bars { display: grid; grid-template-columns: max-content minmax(80px, 1fr) max-content; gap: 2px 10px;
  align-items: center; font-size: 13.5px; }
.chart .row { display: contents; }
.chart .row:hover > span { background: var(--panel); }
.chart .track { height: 16px; }
.chart .track i { display: block; height: 100%; min-width: 2px; border-radius: 0 4px 4px 0; }
.chart .val { text-align: right; font-variant-numeric: tabular-nums; }
.chart figcaption { margin-top: 4px; color: var(--muted); font-size: 12px; text-align: right; }
.cov-pies { display: flex; flex-wrap: wrap; gap: 40px; margin: 16px 0; }
.cov-pies figure { margin: 0; text-align: center; }
.cov-pies svg { width: 144px; height: 144px; } .cov-pies svg.cov-history { width: 300px; }
.cov-pies svg.cov-history text { font: 11px system-ui, sans-serif; fill: var(--muted); }
.cov-pies text { font: bold 16px system-ui, sans-serif; fill: var(--text); }
.cov-pies figcaption { color: var(--muted); font-size: 13px; } .cov-pies strong { color: var(--text); }
table.cov td.pct { text-align: right; font-weight: bold; } table.cov td.num { text-align: right; white-space: nowrap; }
table.cov td.pct.ok { color: var(--ok); } table.cov td.pct.warn { color: var(--warn); }
table.cov td.pct.bad { color: var(--bad); } table.cov td.missed { color: var(--muted); font-size: 13px; }
table.cov .miss-fn { white-space: nowrap; margin-right: 10px; } table.cov small.never { color: var(--bad); }
table.cov small.runs { color: var(--warn); }
table.cov .bar { display: inline-block; width: 160px; height: 9px; border-radius: 3px; background: var(--line);
  overflow: hidden; vertical-align: middle; }
table.cov .bar > span { display: block; height: 100%; } table.cov .bar > .ok { background: var(--ok); }
table.cov .bar > .warn { background: var(--warn); } table.cov .bar > .bad { background: var(--bad); }
table.cov { width: 100%; } table.cov td:first-child > code { white-space: nowrap; }
table.cov td.num { color: inherit; } table.cov th:nth-child(2), table.cov th:nth-child(4) { text-align: right; }
/* The Coverage page's source viewer: a click on a file's row shows its source in a row under it, covered lines with a
   green bar, missed ones red; a file changed since the coverage run is flagged in the warning color. */
.src-hint { color: var(--muted); font-size: 13px; }
table.cov tr.src-row { cursor: pointer; } table.cov tr.src-row:hover td { background: var(--panel); }
table.cov tr.src-row code { color: var(--ref); } table.cov tr.src-view > td { padding: 0; }
pre.cov-src { margin: 0; max-height: 70vh; overflow: auto; padding: 6px 0; background: var(--code-bg);
  color: var(--code-fg, var(--text)); font-size: 13px; line-height: 1.45; position: relative; }
pre.cov-src > span { display: block; padding-right: 12px; border-left: 3px solid transparent; white-space: pre; }
/* A source under a row must not widen the table (its longest line would push the other columns out of view): no
   width of its own, it fills the cell the columns give it and scrolls inside. */
tr.src-view pre.cov-src { width: 0; min-width: 100%; box-sizing: border-box; }
pre.cov-src > span::before { content: attr(data-n); display: inline-block; width: 5ch; margin-right: 12px;
  padding-right: 6px; text-align: right; color: var(--muted); user-select: none; }
pre.cov-src > span.hit { border-left-color: var(--ok); }
table.cov small.stale, pre.cov-src > span.stale { color: var(--warn); }
pre.cov-src > span.miss { border-left-color: var(--bad); background: color-mix(in srgb, var(--bad) 16%, transparent); }
/* The Profile page: a bar per case and interpreter under its numbers (the extension's part dark); a click on a case
   shows its files' sources under it (`pre.cov-src`'s look), each costly line shaded with its cost in a gutter. */
.prof-wrap { overflow-x: auto; } table.prof { width: 100%; } table.prof td { vertical-align: middle; }
table.prof tr.prof-row { cursor: pointer; } table.prof tr.prof-row:hover td { background: var(--panel); }
table.prof tr.prof-row code { color: var(--ref); } table.prof tr.src-view > td { padding: 0 0 8px; }
.prof-cell { min-width: 84px; } .pnum { display: block; white-space: nowrap; }
.ptrack { display: block; height: 8px; margin-top: 3px; }
.pbar { display: block; height: 100%; min-width: 2px; border-radius: 3px; background: var(--accent-soft);
  overflow: hidden; } .pbar > i { display: block; height: 100%; background: var(--accent); }
.pnum { font-variant-numeric: tabular-nums; font-size: 13px; color: var(--muted); } .pnum b { color: var(--text); }
.prof-key { font-size: 13px; color: var(--muted); }
.prof-key i { display: inline-block; width: 12px; height: 10px; margin: 0 6px 0 14px; border-radius: 2px; }
.prof-key i:first-child { margin-left: 0; } .prof-key .ext { background: var(--accent); }
.prof-key .py { background: var(--accent-soft); }
.prof-file { margin: 10px 12px 4px; font-size: 13.5px; color: var(--muted); } .prof-file code { color: var(--text); }
pre.prof-src { max-height: 50vh; } pre.prof-src b.pc { display: inline-block; width: 5ch; margin-right: 10px;
  text-align: right; color: var(--text); }
footer { margin-top: 48px; color: var(--muted); font-size: 13px; border-top: 1px solid var(--line); padding-top: 12px; }
@media (max-width: 860px) {
  .menu { display: flex; }
  .side { position: fixed; right: 0; top: 52px; z-index: 9; background: var(--panel); transform: translateX(100%);
    transition: transform .15s; width: 260px; }
  body.nav-open .side { transform: none; }
  main { padding: 16px 16px 48px; }
  .top-in { padding: 0 16px; }
  :is(.entry, .member, .group, .part):target::before { left: -8px; }
  :is(.entry, .member, .group, .part):target::after { right: -8px; }
  .live { display: none; }
  .repo-in { display: none; }
}
'''
THEMES = {'': 'Tokyo', 'nord': 'Nord'}  # `data-palette` -> its name in the ◐ menu; '' (no attribute): Tokyo
THEME_NAMES = [k for k in THEMES if k]  # what the head's script accepts from localStorage
THEME_ORDER = ['nord', '']  # the menu's order: each palette's Day, then its Night
THEME_MENU = (
    '<div class="themes"><button id="theme" class="theme" type="button" aria-label="Theme"'
    f' title="Themes need a server" aria-haspopup="menu" aria-expanded="false" disabled>{ICON_THEME}</button>'
    '<div id="themes" class="theme-menu" role="menu" hidden>'
    + ''.join(
        f'<button type="button" role="menuitemradio" aria-checked="false" data-palette="{k}" data-mode="{mode}">'
        f'{html.escape(THEMES[k])} {label}</button>'
        for k in THEME_ORDER
        for mode, label in (('light', 'Day'), ('dark', 'Night'))
    )
    + '</div></div>'
)

JS = r'''
// The binding for docs.wasm (Setu's tools/setu_docs_web.zig, `zig build docs-web`), where all of the site's
// behaviour lives. This is a fixed loop: every call into the module returns a list of commands (its `Op`s, in
// this order: `ops` below), run here in order; events, fetch answers and timers go back into the module. It knows
// no element, selector or feature. The page is written for no docs.wasm (opened from disk): without it, nothing
// here runs and the page stays as written.
(async function () {
  let w;
  try {
    w = (await WebAssembly.instantiateStreaming(fetch('docs.wasm'))).instance.exports;
  } catch (e) {  // opened from disk (file://): browsers do not fetch .wasm there
    return;
  }
  const enc = new TextEncoder(), dec = new TextDecoder();
  const dark = matchMedia('(prefers-color-scheme: dark)');
  const nodes = new Map([[0, document], [1, document.documentElement], [2, document.body], [3, dark]]);
  const areas = [localStorage, sessionStorage];
  const payload = { input: e => e.target.value, keydown: e => e.key, click: () => String(getSelection()),
    change: e => String(e.matches) };
  let event = null;  // the event being handled (`prevent`)

  // A zero-length Zig slice's pointer is a sentinel (-1 as a wasm32 i32): never view memory through it.
  function send(fn, ...args) {  // fn(args), each string as [ptr, len] in the module's memory; then its commands
    const strings = [];
    const flat = args.flatMap(a => {
      if (typeof a !== 'string') return [a];
      const bytes = enc.encode(a), ptr = w.alloc(bytes.length);
      if (!ptr && bytes.length) throw new Error('docs.wasm: out of memory');
      if (bytes.length) new Uint8Array(w.memory.buffer, ptr, bytes.length).set(bytes);
      strings.push([ptr, bytes.length]);
      return [ptr, bytes.length];
    });
    try { fn(...flat); } finally { strings.forEach(([ptr, len]) => w.free(ptr, len)); }
    run(new Uint8Array(new Uint8Array(w.memory.buffer, w.outPtr(), w.outLen())));  // a copy: run may call back
  }

  async function get(url, id, init) {
    const sent = performance.now();
    let status = 0, text = '';
    try {
      const reply = await fetch(url, init);
      status = reply.status;
      text = await reply.text();
    } catch (e) {}
    send(w.onFetched, id, status, sent, performance.now(), text);
  }

  function run(bytes) {
    const view = new DataView(bytes.buffer), answers = [];
    let at = 0;
    const n = () => { at += 4; return view.getUint32(at - 4, true); };
    const s = () => { const len = n(); at += len; return dec.decode(bytes.subarray(at - len, at)); };
    const node = () => nodes.get(n());
    const ops = [
      () => { const parent = node(), h = n(); nodes.set(h, parent.querySelector(s())); },  // bind
      () => {  // bind_all
        const parent = node(), first = n(), id = n(), found = [...parent.querySelectorAll(s())];
        const names = s().split(' ');
        found.forEach((e, i) => nodes.set(first + i, e));
        const values = found.flatMap(e => names.map(name => e.getAttribute(name) ?? '')).join('\x1f');
        answers.push(() => send(w.onEvent, id, found.length, values));
      },
      () => {  // read
        const h = n(), text = nodes.get(h).textContent, id = n();
        answers.push(() => send(w.onEvent, id, h, text));
      },
      () => { node().innerHTML = s(); },  // html
      () => { node().textContent = s(); },  // text
      () => { node().setAttribute(s(), s()); },  // attr: the element, then name and value, in order
      () => { node().removeAttribute(s()); },  // unattr
      () => { node().classList.toggle(s(), n() === 1); },  // class
      () => { node().focus(); },  // focus
      () => {  // listen
        const h = n(), target = nodes.get(h), type = s(), id = n(), value = payload[type] ?? (() => '');
        target.addEventListener(type, e => {
          const outer = event;
          event = e;
          try { send(w.onEvent, id, h, value(e)); } finally { event = outer; }
        });
      },
      () => { event.preventDefault(); },  // prevent
      () => { get(s(), n()); },  // get
      () => {  // post
        const url = s(), id = n();
        get(url, id, { method: 'POST', body: s(), headers: { 'Content-Type': 'text/plain' } });
      },
      () => { const id = n(); setTimeout(() => send(w.onTimer, id), n()); },  // timer
      () => {  // store
        const area = areas[n()], key = s(), value = s();
        try { area.setItem(key, value); } catch (e) {}
      },
      () => {  // recall
        const area = areas[n()], key = s(), id = n();
        let value = '';
        try { value = area.getItem(key) ?? ''; } catch (e) {}
        answers.push(() => send(w.onEvent, id, 0, value));
      },
      () => {  // copy
        const id = n();
        navigator.clipboard.writeText(s()).then(() => send(w.onEvent, id, 0, ''), () => {});
      },
      () => {  // scroll: the line a third down
        const box = node(), line = box.querySelector('[data-n="' + n() + '"]');
        if (line) box.scrollTop = line.offsetTop - box.clientHeight / 3;
      },
      () => { location.href = s(); },  // go
    ];
    while (at < bytes.length) ops[bytes[at++]]();
    answers.forEach(answer => answer());
  }

  send(w.onStart, dark.matches, location.hostname);
})();
'''


# --- llms.txt / llms-full.txt (from the stub) -------------------------------------------------


def convert(text):
    '''A Zig doc `text` (a docstring) as Markdown: each section's header bold, `Example` (and a bare `>>>`
    session) a `pycon` block, `Note` / `Warning` plain text, any other section a `text` block.

    Example
        >>> convert('Adds.\\n\\nExample\\n    >>> add(1)\\n    1')
        'Adds.\\n\\n**Example**\\n\\n```pycon\\n>>> add(1)\\n1\\n```'
    '''
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if HEADER.fullmatch(line) and i + 1 < len(lines) and lines[i + 1].startswith(' '):
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j].startswith(' ')):
                j += 1
            block = textwrap.dedent('\n'.join(lines[i + 1 : j])).strip('\n')
            if line in ('Note', 'Warning'):
                out += [f'**{line}**', '', block, '']
            else:
                out += [f'**{line}**', '', '```pycon' if EXAMPLE.fullmatch(line) else '```text', block, '```', '']
            i = j
        elif line.startswith('>>>'):  # a bare session, no `Example` header: up to the next blank line
            j = i
            while j < len(lines) and lines[j].strip():
                j += 1
            out += ['```pycon', *lines[i:j], '```']
            i = j
        else:
            out.append(line)
            i += 1
    return '\n'.join(out).strip('\n')


def raw_docstring(node):
    '''The docstring of a stub node as written (`ast.get_docstring(clean=False)` keeps the indent of every
    line after the first; the node's own indent is taken off, the section indent stays).'''
    raw = ast.get_docstring(node, clean=False)
    if raw is None:
        return None
    first, *rest = raw.split('\n')
    base = ' ' * (getattr(node, 'col_offset', -4) + 4)  # the docstring's own indent (a module has no offset)
    return '\n'.join([first, *(line.removeprefix(base) for line in rest)])


def signature(stub, node):
    '''`def name(args) -> R` of a stub function, as the stub writes it (the `def` line, or the lines of a
    parameter-per-line one joined), without the `:` and the body.'''
    text = '\n'.join(stub[node.lineno - 1 : node.body[0].lineno])
    body = re.search(r":(\s*#[^\n]*)?\s*(\.\.\.|''')", text)
    text = text[: body.start()] if body else text.rstrip().removesuffix(':')
    return re.sub(r', \)', ')', re.sub(r'\( ', '(', re.sub(r'\s*\n\s*', ' ', text.strip())))


def entry(stub, node, level):
    '''The Markdown of one declaration of the stub (its `lines`): a heading of `level` with the signature, the
    converted docstring, and for a class the same for each member.'''
    head = '#' * level
    decorators = ''.join(f'@{ast.unparse(d)} ' for d in getattr(node, 'decorator_list', ()))
    if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
        return [f'{head} {node.target.id}: {ast.unparse(node.annotation)}', '']
    if isinstance(node, ast.FunctionDef):
        lines = [f'{head} {decorators}{signature(stub, node)}', '']
    elif isinstance(node, ast.ClassDef):
        params = ', '.join(ast.unparse(p) for p in node.type_params)
        bases = ', '.join(ast.unparse(b) for b in node.bases)
        name = node.name + (f'[{params}]' if params else '') + (f'({bases})' if bases else '')
        lines = [f'{head} {decorators}class {name}', '']
    else:
        return []
    raw = raw_docstring(node)
    if raw:
        lines += [convert(raw), '']
    if isinstance(node, ast.ClassDef):
        for member in node.body:
            lines += entry(stub, member, level + 1)
    return lines


def llms_full(stub, module):
    '''`llms-full.txt`: every declaration of the stub text `stub`, in order, with signature and docstring.'''
    lines = [f'# {module}', '', 'Every class, function and constant of the module, with its signature and docstring',
             '(from the type stubs Setu generates from the `///` docs in the Zig source).', '']  # fmt: skip
    source = stub.splitlines()
    for node in ast.parse(stub).body:
        lines += entry(source, node, 2)
    return '\n'.join(lines).rstrip('\n') + '\n'


def llms_index(config, chapters=None):
    '''`llms.txt` (the llms.txt convention): the module, its summary, the pages (`chapters`: `Site.chapters`, a
    `split` page's) and `llms-full.txt`.'''
    module = config['module']
    summary = config.get('summary', f'The Python API of `{module}`.')
    lines = [f'# {module}', '', f'> {summary}', '']
    if config.get('markdown'):
        lines += ['## Guide', '']
        for p in config['markdown']:
            lines.append(f'- [{p["title"]}]({md_slug(p)}.html)')
            lines += [f'  - [{t}]({s}.html)' for s, t, _text in (chapters or {}).get(md_slug(p), ('', ()))[1]]
        lines.append('')
    lines += ['## API reference', '']
    lines += [f'- [{p["title"]}]({p["slug"]}.html): {p["text"]}' for p in config['pages']]
    if 'stub' in config:
        lines += ['', '## Full text', '', '- [llms-full.txt](llms-full.txt): every signature and docstring on one page']
    return '\n'.join(lines) + '\n'


# --- the server -------------------------------------------------------------------------------

TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json',
    '.txt': 'text/plain; charset=utf-8',
    '.wasm': 'application/wasm',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.ico': 'image/x-icon',
}
FREE_THREADED = not getattr(sys, '_is_gil_enabled', lambda: True)()
PYTHON = f'{sys.version_info.major}.{sys.version_info.minor}{"t" if FREE_THREADED else ""}'


def serve(project, port):
    '''Serve the site on http://127.0.0.1:`port`; Run buttons `POST /api/run`, which runs the example in a
    child process (`setu_docs.py run --json <target>`). With `profile`, `/profile.html` is made per request (the
    Profile page is live only) and its sources are served at `source/<path>`.

    Note
        - Listens on 127.0.0.1 only, and answers only requests whose `Host` (and, for POST, `Origin`) is this
          server, so other websites can not use it. Run only accepts documented example names and scripts.
        - With `serial` (the default) one example runs at a time; a second Run gets `409 busy`.
        - A Run may take `timeout` s per example block (`Sqe`: each block, `Sqe:2`: one) plus 15 s to start.
    '''
    site = project.out().resolve()
    hosts = {f'127.0.0.1:{port}', f'localhost:{port}'}
    scripts = re.escape(project.config.get('scripts', 'example'))
    target_rx = re.compile(rf'[A-Za-z_][\w.]{{0,80}}(?::[0-9]{{1,3}})?|{scripts}/[\w-]{{1,80}}\.py')
    lock = threading.Lock() if project.config.get('serial', True) else None
    ping = json.dumps({'module': project.config['module'], 'version': project.version, 'python': PYTHON}).encode()
    live = Site(project) if 'profile' in project.config else None  # the Profile page, made per request
    live_sources = {}  # what the last Profile page shows at `source/<path>`
    examples = set(project.examples())

    def runs(target):
        '''How many example blocks `run target` runs: every block of a bare documented name, else one.'''
        return len(project.blocks(target)) if target in examples else 1

    class Handler(http.server.BaseHTTPRequestHandler):
        def reply(self, status, kind, data, head=False):
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            if not head:
                self.wfile.write(data)

        def json(self, status, value):
            self.reply(status, 'application/json', json.dumps(value).encode())

        def allowed(self):
            if self.headers.get('Host') not in hosts:
                self.reply(403, 'text/plain', b'Unknown Host\n')
                return False
            return True

        def do_GET(self, head=False):
            if not self.allowed():
                return
            path = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
            if path == '/api/ping':
                return self.reply(200, 'application/json', ping, head)
            if live and path == '/profile.html':
                live.load_profile()
                text = pretty_html(live.profile_page())
                live_sources.clear()
                live_sources.update(live.sources)
                return self.reply(200, TYPES['.html'], text.encode(), head)
            if (source := live_sources.get(path.removeprefix(f'/{SOURCE_DIR}/'))) and source.is_file():
                return self.reply(200, TYPES.get(source.suffix, 'text/plain; charset=utf-8'), source.read_bytes(), head)
            file = (site / path.lstrip('/')).resolve()
            if file.is_dir():
                file = file / 'index.html'
            if not file.is_relative_to(site) or not file.is_file():
                return self.reply(404, 'text/plain', b'Not Found\n', head)
            self.reply(200, TYPES.get(file.suffix, 'application/octet-stream'), file.read_bytes(), head)

        def do_HEAD(self):
            self.do_GET(head=True)

        def do_POST(self):
            if not self.allowed():
                return
            if urllib.parse.urlsplit(self.path).path != '/api/run':
                return self.reply(405, 'text/plain', b'GET only\n')
            if self.headers.get('Origin') not in {f'http://{h}' for h in hosts}:
                return self.reply(403, 'text/plain', b'Cross-origin request refused\n')
            length = int(self.headers.get('Content-Length') or 0)
            if length > 4096:
                return self.reply(413, 'text/plain', b'Too large\n')
            target = self.rfile.read(length).decode('utf-8', 'replace').strip()
            if not target_rx.fullmatch(target):
                return self.json(400, {'error': 'not an example name'})
            if lock and not lock.acquire(blocking=False):
                return self.json(409, {'error': 'busy: another example is running'})
            try:
                cmd = [sys.executable, str(SETU_DOCS), '--config', str(project.pyproject), 'run', '--json', target]
                limit = project.timeout * runs(target) + 15  # every block of a bare name has its own `timeout`
                p = subprocess.run(cmd, cwd=project.root, env=project.env(), capture_output=True, text=True,
                                   stdin=subprocess.DEVNULL, timeout=limit, check=False)  # fmt: skip
            except subprocess.TimeoutExpired:
                return self.json(500, {'error': 'the example did not finish'})
            finally:
                if lock:
                    lock.release()
            try:
                result = json.loads((p.stdout.splitlines() or [''])[-1])
            except ValueError:
                message = (p.stdout + p.stderr).strip().splitlines()
                return self.json(400 if p.returncode == 2 else 500,
                                 {'error': message[-1] if message else f'exit code {p.returncode}'})  # fmt: skip
            self.json(200, result)

        def log_message(self, format, *args):
            if not (self.command == 'POST' and args[1:2] == ('200',)):
                super().log_message(format, *args)

    server = http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler)
    print(f'Serving {site} on http://127.0.0.1:{port}  (Python {PYTHON}; Ctrl+C stops)', flush=True)
    with server:
        server.serve_forever()


# --- command line -----------------------------------------------------------------------------


def _print_session(result):
    if 'steps' not in result:
        print(result['output'], end='')
        return
    several = result['steps'] and result['steps'][-1]['block'] > 1
    for i, s in enumerate(result['steps']):
        if several and (not i or s['block'] != result['steps'][i - 1]['block']):
            print(('\n' if i else '') + f'# Example #{s["block"]}')  # the header Setu gives the block
        print('>>> ' + s['source'].replace('\n', '\n... '))
        if s['got']:
            print(s['got'])
        if s['status'] == 'fail':
            print(f'# !! docs say: {s["expected"] or "(nothing)"}')
        elif s['status'] == 'loose':
            print('# (output differs per run; not compared)')


def check(project):
    '''Run every docstring example block that can run (`Project.needs`); print the mismatches and the names the
    others read; give how many blocks failed.'''
    todo, missing, skipped = [], collections.Counter(), 0
    for name in project.examples():
        blocks = project.blocks(name)
        for k, block in enumerate(blocks, 1):
            if needs := project.needs(name, block):
                missing.update(needs)
                skipped += 1
            else:
                todo.append((name if len(blocks) == 1 else f'{name}:{k}', name, block))
    bad = 0
    for target, name, block in todo:
        failed = [s for s in run_example(project, name, block) if s.status == 'fail']
        bad += bool(failed)
        for s in failed:
            print(f'{target}: {s.source!r}\n    docs: {s.expected!r}\n    got:  {s.got!r}')
    print(f'{len(todo) - bad}/{len(todo)} examples match')
    if missing:
        print(f'{skipped} not run, no fixture defines: ' + ', '.join(f'{n} ({c})' for n, c in missing.most_common()))
    return bad


def main(argv=None):
    parser = argparse.ArgumentParser(description='Build a Setu project\'s docs site, serve it, or run its examples.')
    parser.add_argument('--config', default='pyproject.toml', help='the pyproject.toml with [tool.setu_docs]')
    sub = parser.add_subparsers(dest='cmd')
    build = sub.add_parser('build', help='write the HTML site (the default)')
    build.add_argument('--out', help='the site directory (default: `out` of the settings)')
    run = sub.add_parser('run', help="run one example: a name ('read', 'File.read') or a script")
    run.add_argument('target')
    run.add_argument('--json', action='store_true')
    sub.add_parser('check', help='run every docstring example')
    srv = sub.add_parser('serve', help='serve the site on 127.0.0.1, Run buttons enabled')
    srv.add_argument('--port', type=int, default=8000)
    srv.add_argument('--build', action='store_true', help='rebuild the site first')
    args = parser.parse_args(argv)
    project = Project(args.config)

    if args.cmd == 'run':
        try:
            result = run_target(project, args.target)
        except LookupError as e:
            parser.error(str(e))
        if args.json:
            print(json.dumps(result))
        else:
            _print_session(result)
        return 0 if result['ok'] else 1
    if args.cmd == 'check':
        return 1 if check(project) else 0
    if args.cmd == 'serve':
        if args.build or not (project.out() / 'index.html').exists():
            Site(project).write(project.out())
        try:
            serve(project, args.port)
        except KeyboardInterrupt:
            print('\nstopped')
        return 0
    out = pathlib.Path(args.out) if getattr(args, 'out', None) else project.out()
    files = Site(project).write(out)
    print(f'wrote {len(files)} files to {out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
