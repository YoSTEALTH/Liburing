#!/usr/bin/env bash
# Runs every Liburing check: zig fmt, `tools/setu_build.py` against the pinned Setu, then for both
# 3.15 builds `zig build develop` and pytest, then `mypy --strict` + `stubtest` on `liburing.pyi`.
# Interpreters: PY_FT=... / PY_GIL=...; compiler: ZIG=...; extra pytest arguments after `--`.
set -euo pipefail

cd "$(dirname "$0")/.."
PY_FT=${PY_FT:-/opt/python/3.15t/bin/python3}
PY_GIL=${PY_GIL:-/opt/python/3.15/bin/python3}
ZIG=${ZIG:-zig}
[[ ${1:-} == -- ]] && shift
PYTEST_ARGS=("$@")

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

step "zig fmt"
"$ZIG" fmt --check src tools build.zig build.zig.zon

step "tools/setu_build.py is the pinned Setu's copy"
"$ZIG" build setu-build-check

for py in "$PY_FT" "$PY_GIL"; do
    if [[ $("$py" -c 'import sysconfig; print(sysconfig.get_config_var("Py_GIL_DISABLED") or 0)') == 1 ]]; then
        flag=-Dfree-threaded=true
    else
        flag=-Dfree-threaded=false
    fi
    step "$py ($flag)"
    "$ZIG" build develop "$flag"
    "$py" -m pytest "${PYTEST_ARGS[@]}"
done

step "mypy --strict + stubtest ($PY_FT)"
if "$PY_FT" -c 'import mypy' 2>/dev/null; then
    "$ZIG" build develop -Dfree-threaded=true
    (cd src && "$PY_FT" -m mypy --strict liburing/liburing.pyi)
    (cd src && PYTHONPATH=. "$PY_FT" -m mypy.stubtest liburing.liburing)
else
    echo "skipped: mypy is not installed for $PY_FT"
fi

step "all checks passed"
