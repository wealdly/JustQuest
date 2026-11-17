"""Run every JustQuest check: Tests/*.lua (Lua 5.1) plus tools/*_check.lua (Lua 5.4) and
tools/*_check.py. Needs `pip install lupa`.

Client coverage: the Tests and checks build their own WoW stubs and run each client-dependent
case as Retail and as WoW Forever themselves (WOW_PROJECT_ID / IS_FOREVER per case), so each
file runs once here. Tests/ForeverGearScoring.lua also loads JustJunk, which must sit next to
this checkout (..\\JustJunk).

Run: python tools/run_lua_tests.py
"""
import glob
import os
import subprocess
import sys

try:
    import lupa.lua51 as lua51
    import lupa.lua54 as lua54
except ImportError:
    sys.exit("needs Lua bindings: pip install lupa")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JUNK = os.path.join(os.path.dirname(ROOT), "JustJunk")


def first_line(err):
    return (str(err).splitlines() or [""])[0][:400]


def main():
    os.chdir(ROOT)
    failures = 0
    for test in sorted(glob.glob(os.path.join("Tests", "*.lua"))):
        run = lua51.LuaRuntime().eval("function(path, ...) return assert(loadfile(path))(...) end")
        try:
            run(test, ROOT, JUNK)
            print(f"PASS {test}")
        except Exception as err:  # noqa: BLE001 - report every Lua error
            failures += 1
            print(f"FAIL {test}: {first_line(err)}")
    for check in sorted(glob.glob(os.path.join("tools", "*_check.lua"))):
        try:
            with open(check, encoding="utf-8") as f:
                lua54.LuaRuntime().execute(f.read())
            print(f"PASS {check}")
        except Exception as err:  # noqa: BLE001
            failures += 1
            print(f"FAIL {check}: {first_line(err)}")
    for check in sorted(glob.glob(os.path.join("tools", "*_check.py"))):
        done = subprocess.run([sys.executable, check], capture_output=True, text=True)
        if done.returncode == 0:
            print(f"PASS {check}")
        else:
            failures += 1
            tail = (done.stdout + done.stderr).strip().splitlines()[-1:] or [""]
            print(f"FAIL {check}: {tail[0][:400]}")
    print(f"{failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
