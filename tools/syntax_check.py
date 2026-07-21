# Compile every addon Lua file with a real Lua parser and report syntax errors.
#
#   python tools/syntax_check.py [ROOT]
#
# Catches the whole class of edit mistakes that only surface as a load failure in-game:
# unbalanced end/paren/brace, a stray keyword, a truncated table. Libs/ is skipped —
# it's vendored third-party code, not ours to fix.
#
# Requires: pip install lupa
# Exits non-zero if anything fails to compile, so it works as a pre-commit gate.

import glob
import os
import sys

try:
    import lupa.lua54 as lupa
except ImportError:
    sys.exit("lupa not installed — run: pip install lupa")

L = lupa.LuaRuntime()
# Return only the error (nil on success) so lupa hands back a scalar rather than a tuple.
compile_lua = L.eval(
    "function(src, name)"
    "  local fn, err = load(src, name)"
    "  if fn then return nil end"
    "  return err or 'unknown error'"
    "end"
)

root = sys.argv[1] if len(sys.argv) > 1 else "."
files = [
    f for f in glob.glob(os.path.join(root, "**", "*.lua"), recursive=True)
    if os.sep + "Libs" + os.sep not in f
]

failed = []
for path in sorted(files):
    with open(path, encoding="utf-8") as handle:
        src = handle.read()
    err = compile_lua(src, "@" + os.path.basename(path))
    rel = os.path.relpath(path, root)
    if err is not None:
        failed.append(rel)
        print("FAIL  %s: %s" % (rel, err))

print("\nchecked %d files, %d failed" % (len(files), len(failed)))
sys.exit(1 if failed else 0)
