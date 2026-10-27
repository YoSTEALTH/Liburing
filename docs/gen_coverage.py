"""Write `docs/coverage.md` from `zig-out/coverage.json` (Setu's `zig build coverage`, merged over every
interpreter it ran).

The page: the totals, one per interpreter, and one row per Zig file (lowest first) with a bar; no source lines (the
page is public, the missed lines are for `zig build coverage -- --missed`). Run it from the repo root after
`zig build coverage`, before `python3 tools/setu_docs.py`.
"""

import datetime
import json
from pathlib import Path

REPORT = Path("zig-out/coverage.json")
# kcov's high / medium / low colors in the site's Tokyo Day / Night palette (`--ok`, `--warn`, `--bad`).
STYLE = """<style>
.cov { --cov-run: var(--ok); --cov-part: var(--warn); --cov-miss: var(--bad); }
table.cov td.pct { text-align: right; font-weight: bold; }
table.cov td.pct.run { color: var(--cov-run); } table.cov td.pct.part { color: var(--cov-part); }
table.cov td.pct.miss { color: var(--cov-miss); }
.cov .bar { display: inline-block; width: 10em; height: .6em; border-radius: 3px; background: var(--line); overflow: hidden; }
.cov .bar > span { display: block; height: 100%; }
.cov.pies { display: flex; flex-wrap: wrap; gap: 2.5em; margin: 1em 0; }
.cov figure { margin: 0; text-align: center; }
.cov figure svg { width: 9em; height: 9em; }
.cov figcaption { color: var(--muted); font-size: .9em; }
.cov figcaption strong { color: var(--text); }
</style>"""

if not REPORT.is_file():
    raise SystemExit(f"gen_coverage: no {REPORT}: run `zig build coverage` first")
report = json.loads(REPORT.read_text())
date = datetime.datetime.fromtimestamp(REPORT.stat().st_mtime).strftime("%Y-%m-%d %H:%M")


files = []  # (name: `src/liburing/ring.zig`, Setu's `setu/src/raise.zig`; covered, total, missed)
for path, counts in report["files"].items():
    files.append((path, counts["covered"], counts["lines"], counts["lines"] - counts["covered"]))
files.sort(key=lambda f: (f[1] / f[2], f[0]))


def total(covered: int, lines: int) -> str:
    return f"**{100 * covered / lines:.1f}%**, {covered} / {lines} lines"


def level(percent: float) -> str:
    """kcov's high / medium / low color for a file; thresholds 95 / 90 % (kcov's 75 / 25 would make every file
    green)."""
    return "run" if percent >= 95 else "part" if percent >= 90 else "miss"


def pie(name: str, covered: int, lines: int) -> str:
    """A donut of `covered` / `lines`: the covered share in the level's color over a neutral ring of the missed
    lines, the percent in the middle; hovering a part names its lines."""
    percent = 100 * covered / lines
    ring = 'cx="50" cy="50" r="40" fill="none" stroke-width="12"'
    return (
        f'<figure><svg viewBox="0 0 100 100" role="img" aria-label="{name}: {percent:.1f}% covered">'
        f'<circle {ring} stroke="var(--line)"><title>missed: {lines - covered} lines</title></circle>'
        f'<circle {ring} stroke="var(--cov-{level(percent)})" pathLength="100" stroke-dasharray="{percent:.2f} 100"'
        f' transform="rotate(-90 50 50)"><title>covered: {covered} of {lines} lines</title></circle>'
        f'<text x="50" y="50" text-anchor="middle" dominant-baseline="central" font-size="16" font-weight="bold"'
        f' fill="var(--text)">{percent:.1f}%</text></svg>'
        f"<figcaption><strong>{name}</strong><br>{covered} / {lines} lines, {lines - covered} missed</figcaption>"
        "</figure>"
    )


table = [
    '<table class="cov">',
    "<thead><tr><th>File</th><th>Coverage</th><th></th><th>Lines</th><th>Missed</th></tr></thead>",
    "<tbody>",
]
for title, covered, lines, missed in files:
    percent = 100 * covered / lines
    bar = f'<span class="bar"><span style="width:{percent:.1f}%;background:var(--cov-{level(percent)})"></span></span>'
    table.append(
        f'<tr><td><code>{title}</code></td><td class="pct {level(percent)}">{percent:.1f}%</td><td>{bar}</td>'
        f'<td style="text-align:right">{covered} / {lines}</td><td style="text-align:right">{missed}</td></tr>'
    )
table += ["</tbody>", "</table>"]


ours = [f for f in files if not f[0].startswith("setu/")]
ours_covered, ours_lines = sum(f[1] for f in ours), sum(f[2] for f in ours)
runs = report["interpreters"]
page = [
    "# Coverage",
    "",
    f"Line coverage of the extension's Zig code while the test suite runs (`zig build coverage`: kcov under pytest on {', '.join(runs)}, merged, {date}).",
    "",
    STYLE,
    "",
    '<div class="cov pies">',
    pie("Liburing", ours_covered, ours_lines),
    pie("With Setu's code", report["total"]["covered"], report["total"]["lines"]),
    "</div>",
    "",
    f"- **Liburing** (`src/liburing`): {total(ours_covered, ours_lines)}",
    f"- **With Setu's code** as Liburing uses it: {total(report['total']['covered'], report['total']['lines'])}",
    *(f"  - CPython {version}: {total(run['covered'], run['lines'])}" for version, run in runs.items()),
    "",
    "## Files",
    "",
    *table,
]
Path("docs/coverage.md").write_text("\n".join(page) + "\n")
print("wrote docs/coverage.md")
