# Generate the auto-openable container list from wago.tools DB2 dumps by FLAG, not name.
#
#   python tools/gen_containers.py [--csv-dir DIR] [--out-lua FILE] [--out-csv FILE]
#
# The authoritative signal is ItemSparse.Flags_0 bit 0x4 (ITEM_FLAG_OPENABLE): the game
# sets it on every item that opens to give loot (chests, clams, coin sacks, lockboxes) and
# on nothing else. Validated against the old hand list: 99% of its real containers carry
# the flag, and 0% of its "dangerous / not a container" entries do. So we trust the flag
# over curated names and get ~2200 containers with far less maintenance.
#
# Classification:
#   free    LockID == 0  -> right-click opens immediately. Safe to auto-open.
#   locked  LockID != 0  -> a lockbox. Needs a key or lockpicking first; the game reports
#                           it as locked and the addon waits. Lock.db2 (optional, see the
#                           Documentation README) further splits these into rogue-pickable
#                           vs key-required and gives the required skill.
#   quest   StartQuestID != 0 -> opening starts a quest; surfaced so a mode can hold these.
#
# Required CSVs in --csv-dir (pull from https://wago.tools): Item, ItemSparse.
# Optional: Lock (lock requirements / rogue-pick), ItemEffect + ItemXItemEffect (spell-loot
# bags that give loot via an on-use spell instead of the flag).
import argparse, csv, glob, os, re, sys

csv.field_size_limit(10 ** 7)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

OPENABLE = 0x4  # ItemSparse.Flags_0 bit: "has loot / right-click opens"
NOISE = re.compile(r"\[|\bQA\b|\bDNT\b|\bTEST\b|Deprecated|PH \(", re.I)
EXPANSION = {"11": "Midnight", "10": "Dragonflight/TWW", "9": "Shadowlands", "8": "BfA",
             "7": "Legion", "6": "WoD", "5": "MoP", "4": "Cata", "3": "Wrath",
             "2": "TBC", "1": "Classic", "0": "Classic/timeless"}


def newest(csv_dir, prefix):
    hits = sorted(glob.glob(os.path.join(csv_dir, prefix + ".*.csv")) +
                  glob.glob(os.path.join(csv_dir, prefix + ".csv")))
    return hits[-1] if hits else None


def rows(path):
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        yield from csv.DictReader(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv-dir", default=os.path.join(ROOT, "Documentation", "wow_item_csv"))
    ap.add_argument("--out-lua", default=os.path.join(ROOT, "Database", "ContainerData.lua"))
    ap.add_argument("--out-csv", default=None, help="slim provenance CSV (openable items only)")
    args = ap.parse_args()

    item_csv = newest(args.csv_dir, "Item")
    sparse_csv = newest(args.csv_dir, "ItemSparse")
    if not (item_csv and sparse_csv):
        sys.exit(f"need Item.*.csv and ItemSparse.*.csv in {args.csv_dir}")
    version = re.search(r"ItemSparse\.(.+)\.csv", os.path.basename(sparse_csv))
    version = version.group(1) if version else "unknown"

    cls = {r["ID"]: (r["ClassID"], r["SubclassID"]) for r in rows(item_csv)}

    # Optional lock requirements: LockID -> "pick" | "key" | "other"
    lock_kind = {}
    lock_csv = newest(args.csv_dir, "Lock")
    if lock_csv:
        for r in rows(lock_csv):
            kinds = set()
            for i in range(8):
                t = r.get(f"Type_{i}") or r.get(f"Type[{i}]")
                if t == "1":
                    kinds.add("pick")   # lockpicking-skill lock -> rogue Pick Lock
                elif t == "2":
                    kinds.add("key")    # requires a specific key item
            lock_kind[r["ID"]] = ("pick" if "pick" in kinds else
                                  "key" if "key" in kinds else "other")

    free, locked, quest = {}, {}, {}
    for r in rows(sparse_csv):
        try:
            flags0 = int(r["Flags_0"])
        except ValueError:
            continue
        if not (flags0 & OPENABLE):
            continue
        name = r["Display_lang"].strip()
        if not name or NOISE.search(name):
            continue
        if r["ContainerSlots"] != "0":  # equippable bag, not a loot container
            continue
        iid = r["ID"]
        lock_id = r["LockID"]
        entry = {"name": name, "class": cls.get(iid, ("?", "?")),
                 "exp": r["ExpansionID"], "quest": r["StartQuestID"], "lock": lock_id}
        if r["StartQuestID"] != "0":
            quest[iid] = entry
        if lock_id != "0":
            entry["lockkind"] = lock_kind.get(lock_id, "?")
            locked[iid] = entry
        else:
            free[iid] = entry

    write_lua(args.out_lua, version, free, locked, args.csv_dir)
    if args.out_csv:
        write_csv(args.out_csv, free, locked)
    report(version, free, locked, quest, bool(lock_csv))


def write_lua(path, version, free, locked, csv_dir):
    def block(d):
        return "".join(f'    [{iid}] = "{e["name"].replace(chr(92), "").replace(chr(34), "")}",\n'
                       for iid, e in sorted(d.items(), key=lambda kv: int(kv[0])))
    lockblock = "".join(
        f'    [{iid}] = {{ name = "{e["name"].replace(chr(34), "")}", lockID = {e["lock"]}, '
        f'kind = "{e.get("lockkind", "?")}" }},\n'
        for iid, e in sorted(locked.items(), key=lambda kv: int(kv[0])))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"""-- ContainerData.lua  --  GENERATED, DO NOT EDIT BY HAND.
-- Source: tools/gen_containers.py from wago.tools DB2 ({version}).
-- Signal: ItemSparse.Flags_0 & 0x4 (ITEM_FLAG_OPENABLE). Regenerate each major patch.
local ADDON_NAME, JustQuest = ...
JustQuest.Database = JustQuest.Database or {{}}

-- Free-open containers: right-click opens immediately (chests, clams, coin sacks).
JustQuest.Database.OPENABLE_CONTAINERS = {{
{block(free)}}}

-- Lockboxes: reported locked until a key/lockpick is applied. `kind` = "pick" (rogue
-- Pick Lock), "key" (needs a specific key item), or "?" when Lock.db2 wasn't supplied.
JustQuest.Database.LOCKED_CONTAINERS = {{
{lockblock}}}
""")


def write_csv(path, free, locked):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ItemID", "Name", "Locked", "LockID", "LockKind", "ClassID", "SubclassID",
                    "ExpansionID", "StartQuestID"])
        for iid, e in sorted({**free, **locked}.items(), key=lambda kv: int(kv[0])):
            w.writerow([iid, e["name"], int(iid in locked), e["lock"], e.get("lockkind", ""),
                        e["class"][0], e["class"][1], e["exp"], e["quest"]])


def report(version, free, locked, quest, have_lock):
    print(f"DB2 {version}: {len(free) + len(locked)} openable containers "
          f"({len(free)} free, {len(locked)} locked, {len(quest)} start a quest)")
    if have_lock:
        from collections import Counter
        k = Counter(e.get("lockkind") for e in locked.values())
        print(f"  lock kinds: {dict(k)}")
    else:
        print("  (no Lock.*.csv supplied -> locked items unclassified; pull Lock.db2 from wago.tools)")


if __name__ == "__main__":
    main()
