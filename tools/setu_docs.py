'''Documentation site for a Zig + Setu extension: static HTML built from the imported module's docstrings (the
`///` docs Setu turns into them), Markdown pages of the project, and a runner for the `>>>` examples.

Kept in Setu (`tools/setu_docs.py`) and copied unchanged into each project that uses Setu
(`zig build setu-docs-sync` / `setu-docs-check`, see `addSetuDocsSteps` in Setu's `build.zig`). Project settings
go in `pyproject.toml`, never in a copy. Python standard library only; the site's logic (search, the Run
transcript) is Zig compiled to WebAssembly (Setu's `tools/setu_docs_web.zig`, built by the project's `zig build
docs-web`), and `app.js` only binds it to the page. So the site needs a server: `file://` pages can not load
`.wasm`.

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

    [[tool.setu_docs.markdown]]     # Markdown pages, in nav order
    file = 'docs/install.md'
    title = 'Install'
    section = 'Guide'               # optional: a nav heading (consecutive pages with one share it)
    slug = 'install'                # optional: the page name (default: the file's stem)

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

The default theme is Tokyo Night: Day for light, Night for dark (the ◐ button, else the system's choice). A `css`
file can override any color: page `--bg`, `--panel`, `--line`, `--text`, `--muted`, `--accent`, ...; code `--kw`
(keywords), `--bi` (builtins), `--str`, `--num`, `--com` (comments), `--ref` (API names, linked), `--code-fg` (code
text; else `--text`), `--con` (`None` / `True` / ...; else `--num`), `--ty` (a `class` name; else `--bi`), `--dec`
(decorators; else `--kw`), `--fn` (a `def` name, a call, an API name in code), `--slf` (`self` / `cls` / a dunder),
`--attr` (attributes), `--arg` (`name=` in brackets), `--op` (operators; these last five else the text's).

Markdown: headings (with anchors), paragraphs, `-` / `1.` lists, `>` quotes, GFM tables, fenced code (python,
pycon and sh highlighted, every block with a Copy button), inline code, links (`page.md` -> its page), images,
`**bold**`, `*em*`, raw HTML blocks. An inline code span naming an export links to its entry.

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

The site also gets `llms.txt` (an index of the pages, for AI readers) and, with `stub`, `llms-full.txt` (every
class, function and constant with its signature and docstring, one Markdown page).

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

SETU_DOCS = pathlib.Path(__file__).resolve()
HEADER = re.compile(r'Example #\d+|[A-Z][A-Za-z ]*')  # Setu numbers repeated `Example` headers
EXAMPLE = re.compile(r'Example(?: #\d+)?')

# --- settings ---------------------------------------------------------------------------------

KEYS = {'module', 'path', 'stub', 'name', 'summary', 'out', 'home', 'css', 'favicon', 'edit', 'scripts',
        'scripts_skip', 'featured', 'runner', 'hooks', 'serial', 'timeout', 'markdown', 'pages'}  # fmt: skip
FAVICON_TYPES = ('.svg', '.png', '.ico')
PAGE_KEYS = {'slug', 'title', 'text', 'classes', 'functions', 'patterns', 'sources', 'default', 'constants', 'groups'}
MARKDOWN_KEYS = {'file', 'title', 'section', 'slug'}


def fail(msg):
    raise SystemExit(f'setu_docs: {msg}')


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
    if {'index', 'examples'} & set(slugs):
        fail('`index` and `examples` are taken (the home page, the example scripts)')
    if sum(bool(p.get('default')) for p in pages) != 1:
        fail('exactly one page needs `default = true`')
    if sum(bool(p.get('constants')) for p in pages) > 1:
        fail('at most one page can have `constants = true`')
    return config


def md_slug(page):
    return page.get('slug') or pathlib.Path(page['file']).stem


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
                failed = Step(f'# setup: {setup.__name__}(ns)', '', f'{type(e).__name__}: {e}', 'fail')
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
                step.got = f'{type(e).__name__}: {e}'
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
    '''Does `got` read like a raised exception (`NameError: ...`)? A loose step must still not raise.'''
    return re.match(r'[A-Z]\w*(?:Error|Exception|Interrupt): ', got) is not None


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
# The header's light / dark (◐) and menu (☰) buttons: SVG, so every header icon has the same height (`--icon`).
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
INLINE = re.compile(
    r'(?P<code>(?P<ticks>`+)(?P<ctext>.+?)(?<!`)(?P=ticks)(?!`))'
    r'|(?P<img>!\[(?P<ialt>[^\]]*)\]\((?P<isrc>[^)\s]+)\))'
    r'|(?P<link>\[(?P<ltext>(?:[^\[\]]|\[[^\]]*\])+)\]\((?P<lhref>[^)\s]+)(?: +"[^"]*")?\))'
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
        self.ids = set()  # the heading ids of the page being written

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
        return '<pre class="code session">' + '\n'.join(lines) + '</pre>'

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
        return f'<pre class="code"{attr}>{body}</pre>'

    # -- Markdown

    def anchor(self, title):
        '''A unique id for a heading of the page being written.'''
        base = re.sub(r'[\s]+', '-', re.sub(r'[^\w\s-]', '', title.lower()).strip()) or 'section'
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
        if base is not None and (slug := self.md_files.get((base / parts.path).resolve())):
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
                            f'<pre class="code">{self.highlight(src.rstrip())}</pre></details>'
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
        def item(slug, title):
            return f'<a href="{slug}.html"' + (' class="on"' if current == slug else '') + f'>{html.escape(title)}</a>'

        items = [item('index', 'Home')]
        section = None
        for page in self.markdown_pages:
            if page.get('section') != section:
                section = page.get('section')
                if section:
                    items.append(f'<div class="nav-h">{html.escape(section)}</div>')
            items.append(item(md_slug(page), page['title']))
        items.append('<div class="nav-h">API reference</div>')
        items += [item(page['slug'], page['title']) for page, _names in self.pages]
        if self.constants_page:
            items.append(item(self.constants_page['slug'], self.constants_page['title']))
        if self.project.scripts():
            items.append(item('examples', 'Example scripts'))
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
<script>try {{ const t = localStorage.getItem('theme'); if (t) document.documentElement.dataset.theme = t; }}
catch (e) {{}}</script>
</head>
<body>
<header class="top"><div class="top-in">
  <a class="brand" href="index.html">{name} <span class="ver">{version}</span></a>
  <div class="search"><input id="q" type="search" placeholder="Search the API…" autocomplete="off">
  <div id="hits" hidden></div></div>
  <div class="tools">
  <span id="live" class="live" title="Run buttons need `setu_docs.py serve`">static</span>
  <button id="theme" class="theme" type="button" aria-label="Light / dark">{ICON_THEME}</button>{repo}
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
                        f'<pre class="code">{self.highlight(source.rstrip())}</pre>'
                        f'{_run_box(path) if runnable else _not_runnable()}</section>')  # fmt: skip
        return self.page('examples', 'Example scripts', ''.join(body), toc)

    def markdown_page(self, page):
        self.ids = set()
        path = self.project.root / page['file']
        body, toc = self.markdown(path.read_text(), path.parent)
        if not body.startswith('<h1'):
            body = f'<h1>{html.escape(page["title"])}</h1>' + body
        if edit := self.project.config.get('edit'):
            body = f'<a class="edit" href="{html.escape(edit + page["file"])}">Edit</a>' + body
        return self.page(md_slug(page), page['title'], body, toc)

    def index_page(self):
        self.ids = set()
        project = self.project
        toc = []
        if 'home' in project.config:
            path = project.root / project.config['home']
            text, toc = self.markdown(path.read_text(), path.parent)
        else:
            text = f'<h1>{html.escape(project.name)}</h1>'
            if summary := project.config.get('summary'):
                text += f'<p class="lead">{self.inline(summary)}</p>'
            text += self.paragraphs(project.module.__doc__ or '')
        if featured := project.config.get('featured'):
            code = (project.root / featured).read_text()
            text += f'<pre class="code">{self.highlight(code.rstrip())}</pre>{_run_box(featured)}'
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
                 'llms.txt': llms_index(self.project.config)}  # fmt: skip
        for page in self.markdown_pages:
            files[f'{md_slug(page)}.html'] = self.markdown_page(page)
        for page, names in self.pages:
            files[f'{page["slug"]}.html'] = self.api_page(page, names)
        if self.constants_page:
            files[f'{self.constants_page["slug"]}.html'] = self.constant_page()
        if self.project.scripts():
            files['examples.html'] = self.examples_page()
        if self.project.stub:
            files['llms-full.txt'] = llms_full(self.project.stub, self.project.config['module'])
        for name, text in files.items():
            (out / name).write_text(pretty_html(text) if name.endswith('.html') else text)
        copied = ['docs.wasm']
        if self.project.favicon:
            shutil.copyfile(self.project.root / self.project.config['favicon'], out / self.project.favicon)
            copied.append(self.project.favicon)
        build_wasm(self.project.root, out / 'docs.wasm')
        return sorted([*files, *copied])


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
    the parser drops). A `<pre>` with content is split into lines, one `<span class="ln">` each (`pre_lines`), so
    its lines are indented like the rest: the CSS keeps the whitespace inside a `.ln` and drops it between them.

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
            <span class="ln">    y()</span>
          </pre>
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
                indent = '\n' + '  ' * (len(stack) + 1)
                lines = ''.join(f'{indent}{LINE_OPEN}{line}</span>' for line in pre_lines(text[m.end() : body_end]))
                token = f'{m.group(0)}{lines}\n{"  " * len(stack)}{text[body_end:pos]}'
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
   dark blocks below (more specific) win in dark mode; the dark block twice: for the system's dark mode (no
   choice made) and for the ◐ button's dark. */
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
  :root:not([data-theme="light"]) {
    --bg: #1a1b26; --panel: #16161e; --line: #292e42; --text: #c0caf5; --muted: #737aa2;
    --accent: #7aa2f7; --accent-soft: #283457; --code-bg: #16161e; --ok: #9ece6a; --bad: #f7768e; --warn: #e0af68;
    --kw: #bb9af7; --str: #9ece6a; --num: #ff9e64; --com: #565f89; --bi: #2ac3de; --ref: #7dcfff;
    --code-fg: #a9b1d6; --fn: #7aa2f7;
    --con: #ff9e64; --slf: #f7768e; --ty: #2ac3de; --attr: #73daca; --dec: #7dcfff; --op: #89ddff;
    --arg: #e0af68;
    --s1: #7aa2f7; --s2: #ff9e64; --s3: #9ece6a; --s4: #e0af68; --s5: #bb9af7; --s6: #73daca; --s7: #7dcfff;
    --s8: #f7768e; --s-other: #565f89;
  }
  :root:not([data-theme="light"]) .run button { color: #1a1b26; }
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
.nav-h { font-size: 14px; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); margin: 14px 8px 2px; }
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
/* `pretty_html` puts a `<pre>`'s lines in `.ln` blocks (indented like the rest): the whitespace between them goes,
   the whitespace in them stays; an empty line keeps its height. */
pre:has(> .ln) { white-space: normal; } pre > .ln { display: block; white-space: pre; }
pre > .ln:empty::before { content: "\\200b"; }
pre.code, pre.plain, pre.result { background: var(--code-bg); border: 1px solid var(--line); border-radius: 6px;
  padding: 10px 12px; overflow-x: auto; line-height: 1.5; margin: 6px 0; }
.codebox { position: relative; }
.codebox .copy { position: absolute; top: 6px; right: 6px; opacity: 0; font: 12px system-ui, sans-serif;
  padding: 1px 8px; border: 1px solid var(--line); border-radius: 4px; background: var(--panel); color: var(--muted);
  cursor: pointer; }
.codebox:hover .copy, .codebox .copy:focus { opacity: 1; }
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
blockquote { margin: 12px 0; padding: 2px 14px; border-left: 3px solid var(--accent); background: var(--panel); }
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

JS = r'''
// The binding for docs.wasm (Setu's tools/setu_docs_web.zig, `zig build docs-web`), where the logic lives:
// search ranking, the Run transcript, the server check, all HTML escaping. This file only copies strings in
// and out of the module's memory and does what Wasm can not: events, fetch, the clipboard, and putting the
// HTML on the page.
(async function () {
  // Light / dark: the button flips the theme and remembers it; with no choice the system's holds.
  const root = document.documentElement;
  document.getElementById('theme').addEventListener('click', () => {
    const dark = root.dataset.theme ? root.dataset.theme === 'dark'
      : matchMedia('(prefers-color-scheme: dark)').matches;
    root.dataset.theme = dark ? 'light' : 'dark';
    try { localStorage.setItem('theme', root.dataset.theme); } catch (e) {}
  });

  // Copy buttons; a session copies its statements only (no prompts, no output).
  document.querySelectorAll('pre.code').forEach(pre => {
    const box = document.createElement('div'), copy = document.createElement('button');
    box.className = 'codebox';
    copy.className = 'copy';
    copy.type = 'button';
    copy.textContent = 'Copy';
    pre.replaceWith(box);
    box.append(pre, copy);
    copy.addEventListener('click', () => {
      // lines from `pretty_html` are `.ln` blocks; the whitespace between them is not code
      const lines = pre.querySelectorAll(':scope > .ln');
      let text = lines.length ? [...lines].map(l => l.textContent).join('\n') : pre.textContent;
      if (pre.classList.contains('session')) {
        text = text.split('\n').filter(l => /^(>>>|\.\.\.)( |$)/.test(l)).map(l => l.slice(4)).join('\n');
      }
      navigator.clipboard.writeText(text).then(() => {
        copy.textContent = 'Copied';
        setTimeout(() => { copy.textContent = 'Copy'; }, 1200);
      });
    });
  });

  // The repository link: the latest release, stars and forks from GitHub's API, kept for the browser session
  // (the API allows 60 requests an hour per address without a token). Left out when GitHub does not answer.
  // The latest release is the newest that is not a pre-release (drafts need a token), as `releases/latest`
  // says, but a repository without releases gets `[]` instead of a 404 in the console.
  const repo = document.querySelector('.repo[data-repo]:not([data-repo=""])');
  if (repo) {
    const key = 'repo:' + repo.dataset.repo, api = 'https://api.github.com/repos/' + repo.dataset.repo;
    const short = n => n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, '') + 'k' : String(n);
    const show = facts => {
      for (const [k, v] of Object.entries(facts)) {
        const el = repo.querySelector(`[data-fact="${k}"]`);
        if (el && v !== '') el.textContent = v;
      }
      repo.querySelector('.facts').hidden = false;
    };
    let cached = null;
    try { cached = JSON.parse(sessionStorage.getItem(key)); } catch (e) {}
    if (cached) show(cached);
    else Promise.all([
      fetch(api).then(r => r.ok ? r.json() : Promise.reject()),
      fetch(api + '/releases?per_page=10').then(r => r.ok ? r.json() : []).catch(() => []),
    ]).then(([info, releases]) => {
      const release = (Array.isArray(releases) && releases.find(r => !r.prerelease)) || {};
      const facts = { tag: release.tag_name || '', stars: short(info.stargazers_count),
        forks: short(info.forks_count) };
      try { sessionStorage.setItem(key, JSON.stringify(facts)); } catch (e) {}
      show(facts);
    }).catch(() => {});
  }

  const q = document.getElementById('q'), hits = document.getElementById('hits');
  const live = document.getElementById('live');
  let w;
  try {
    w = (await WebAssembly.instantiateStreaming(fetch('docs.wasm'))).instance.exports;
  } catch (e) {  // opened from disk (file://): browsers do not fetch .wasm there
    q.disabled = true;
    q.placeholder = 'Search needs a server';
    return;
  }
  const enc = new TextEncoder(), dec = new TextDecoder();
  function call(fn, text, ...args) {  // fn(ptr, len, ...args) with `text` in the module's memory
    const bytes = enc.encode(text);
    const ptr = w.alloc(bytes.length);
    if (!ptr && bytes.length) throw new Error('docs.wasm: out of memory');
    new Uint8Array(w.memory.buffer, ptr, bytes.length).set(bytes);
    try { return fn(ptr, bytes.length, ...args); } finally { w.free(ptr, bytes.length); }
  }
  const out = () => dec.decode(new Uint8Array(w.memory.buffer, w.outPtr(), w.outLen()));

  // Search
  fetch('search.json').then(r => r.text()).then(text => call(w.loadIndex, text)).catch(() => {});
  q.addEventListener('input', () => {
    const count = call(w.search, q.value);
    hits.innerHTML = out();
    hits.hidden = count === 0;
  });
  q.addEventListener('keydown', ev => {
    if (ev.key === 'ArrowDown' || ev.key === 'ArrowUp') {
      ev.preventDefault();
      const sel = w.move(ev.key === 'ArrowDown' ? 1 : -1);
      hits.querySelectorAll('a').forEach((a, i) => a.classList.toggle('sel', i === sel));
    } else if (ev.key === 'Enter' && w.chosen()) {
      location.href = out();
      hits.hidden = true;
    } else if (ev.key === 'Escape') {
      hits.hidden = true;
    }
  });
  document.addEventListener('click', ev => { if (!ev.target.closest('.search')) hits.hidden = true; });
  document.addEventListener('keydown', ev => {
    if (ev.key === '/' && document.activeElement !== q) { ev.preventDefault(); q.focus(); }
  });

  // Run buttons: only when served by `setu_docs.py serve` (it answers /api/ping). It listens on 127.0.0.1 only,
  // so a published site (GitHub Pages) does not ask (a 404 in every page load's network log).
  const local = location.hostname === '127.0.0.1' || location.hostname === 'localhost';
  (local ? fetch('/api/ping') : Promise.reject()).then(r => r.ok ? r.text() : '').then(text => {
    if (!text || !call(w.ping, text)) return;
    document.body.classList.add('can-run');
    live.textContent = out();
    live.classList.add('on');
  }).catch(() => {});

  document.querySelectorAll('.run').forEach(box => {
    const button = box.querySelector('button'), status = box.querySelector('.status');
    const pre = box.querySelector('.result');
    button.addEventListener('click', async () => {
      button.disabled = true;
      status.className = 'status';
      status.textContent = 'running…';
      const start = performance.now();
      let kind;  // RunKind: 0 ok, 1 differs, 2 failed
      try {
        const r = await fetch('/api/run', { method: 'POST', body: box.dataset.target,
          headers: { 'Content-Type': 'text/plain' } });
        kind = call(w.renderRun, await r.text());
      } catch (e) {
        kind = call(w.renderRun, JSON.stringify({ error: String(e.message || e) }));
      }
      if (kind !== 2) {
        pre.innerHTML = out();
        pre.hidden = false;
      }
      w.runStatus(kind, Math.round(performance.now() - start));
      status.className = 'status ' + (kind === 0 ? 'ok' : 'fail');
      status.textContent = out();
      button.disabled = false;
    });
  });
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


def llms_index(config):
    '''`llms.txt` (the llms.txt convention): the module, its summary, the pages and `llms-full.txt`.'''
    module = config['module']
    summary = config.get('summary', f'The Python API of `{module}`.')
    lines = [f'# {module}', '', f'> {summary}', '']
    if config.get('markdown'):
        lines += ['## Guide', '']
        lines += [f'- [{p["title"]}]({md_slug(p)}.html)' for p in config['markdown']]
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
    child process (`setu_docs.py run --json <target>`).

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
