"""Flag file-level locals referenced above their declaration.

    python tools/scope_check.py Engines/*.lua Services/*.lua Core/*.lua Interface/*.lua

Lua resolves such a reference to a nil global instead of the local, so it compiles
cleanly and only fails at runtime, usually as "attempt to index a nil value" the first
time the function runs. syntax_check.py cannot see it. Only file-level (column-0) locals
are checked, and only uses at an indent (i.e. inside a function body), which keeps false
positives down. Quoted strings are stripped before matching so a name appearing in an
event-dispatch table doesn't read as a reference.

Exits non-zero on any finding, so it works as a pre-commit gate alongside syntax_check.py.
"""
import re, sys, os

files = sys.argv[1:]
DECL = re.compile(r"^local\s+(?:function\s+)?([A-Za-z_]\w*)")
STR = re.compile(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
bad = 0

for path in files:
    lines = open(path, encoding="utf-8").read().split("\n")
    decl = {}
    for i, line in enumerate(lines):
        m = DECL.match(line)
        if m and m.group(1) not in decl:
            decl[m.group(1)] = i

    for name, dline in decl.items():
        # Bare references only: `services.Debug` or `obj:Debug` is a field, not the local.
        word = re.compile(r"(?<![.:\w])" + re.escape(name) + r"\b")
        for i, line in enumerate(lines[:dline]):
            stripped = line.strip()
            if not line.startswith((" ", "\t")):
                continue  # only care about uses nested inside a body
            if stripped.startswith("--"):
                continue
            if word.search(STR.sub('""', line)):
                print("FAIL %s:%d uses '%s' declared at line %d"
                      % (os.path.basename(path), i + 1, name, dline + 1))
                bad = 1
                break

print("scope check: " + ("FAILURES" if bad else "clean"))
sys.exit(bad)
