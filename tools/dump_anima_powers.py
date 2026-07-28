# Dump every anima power the client knows about, with id and description, for curation.
#
#   python tools/dump_anima_powers.py [--csv-dir DIR] [--out FILE] [--uncurated-only]
#
# The roster comes from SpellLabel: LabelID 630 marks roguelike-run powers (Torghast and the
# 8.3 Horrific Visions share it). That is the enumeration the PlayerChoice DB2 tables would
# have given us if they shipped to the client, which they do not — see the notes in
# Database/AnimaPowerDB.lua.
#
# Two things make the raw list unusable, both handled here:
#   * a third of descriptions are "$@spelldescNNNNN" pointers at another spell. Resolved,
#     recursively, so every row reads on its own.
#   * rank variants and alternate IDs repeat the same power many times over. Rows with an
#     identical name+description are collapsed, listing every id that shares them.
import argparse, csv, glob, io, os, re, sys
from collections import defaultdict

csv.field_size_limit(10 ** 7)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ANIMA_LABEL = 630


def newest(csv_dir, prefix):
    hits = sorted(glob.glob(os.path.join(csv_dir, prefix + ".*.csv")) +
                  glob.glob(os.path.join(csv_dir, prefix + ".csv")))
    return hits[-1] if hits else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv-dir", default=r"r:\WOW\Interface\AddOns\JustAC\Documentation\wow_spell_csv")
    ap.add_argument("--out", default=os.path.join(ROOT, "Documentation", "anima_powers_reference.md"))
    ap.add_argument("--uncurated-only", action="store_true",
                    help="omit powers already in AnimaPowerDB")
    ap.add_argument("--class", dest="klass", default=None,
                    help="only powers referencing this class's abilities (Druid, Shaman, ...). "
                         "Class powers self-filter in play — you are only ever offered your own — "
                         "so curating one class is ~30-75 powers rather than the whole roster.")
    args = ap.parse_args()

    label_csv = newest(args.csv_dir, "SpellLabel")
    name_csv = newest(args.csv_dir, "SpellName")
    spell_csv = newest(args.csv_dir, "Spell")
    for f, n in ((label_csv, "SpellLabel"), (name_csv, "SpellName"), (spell_csv, "Spell")):
        if not f:
            sys.exit(f"need {n}.*.csv in {args.csv_dir} (pull it from https://wago.tools)")

    roster = set()
    for r in csv.DictReader(io.open(label_csv, encoding="utf-8", errors="replace", newline="")):
        if r.get("LabelID") == str(ANIMA_LABEL):
            try:
                roster.add(int(r["SpellID"]))
            except (ValueError, TypeError):
                pass

    # Names and descriptions for EVERY spell: a description can point at a spell outside the
    # roster, and an unresolved pointer is worse than no row at all.
    names, descs = {}, {}
    for r in csv.DictReader(io.open(name_csv, encoding="utf-8", errors="replace", newline="")):
        try:
            names[int(r["ID"])] = (r["Name_lang"] or "").strip()
        except (ValueError, TypeError):
            pass
    for r in csv.DictReader(io.open(spell_csv, encoding="utf-8", errors="replace", newline="")):
        try:
            d = (r.get("Description_lang") or "").strip()
            if d:
                descs[int(r["ID"])] = d
        except (ValueError, TypeError):
            pass

    ptr = re.compile(r"^\s*\$@spelldesc(\d+)\s*$")

    def resolve(sid, seen=None):
        seen = seen or set()
        d = descs.get(sid, "")
        m = ptr.match(d)
        if m and sid not in seen:
            seen.add(sid)
            return resolve(int(m.group(1)), seen)
        # inline pointers mid-text
        return re.sub(r"\$@spelldesc(\d+)",
                      lambda mm: descs.get(int(mm.group(1)), mm.group(0))[:200], d)

    src = io.open(os.path.join(ROOT, "Database", "AnimaPowerDB.lua"), encoding="utf-8").read()
    curated = set()
    for t in ("BLOCKED", "SCORES_NORMAL", "SCORES_FARMING"):
        m = re.search(r"AnimaPowerDB\.%s = \{(.*?)\n\}" % t, src, re.S)
        curated |= {int(i) for i in re.findall(r"^\s*\[(\d+)\]", m.group(1), re.M)}

    # Class attribution by the abilities a power's description names. There is no class column
    # for anima powers, and SpellClassOptions.SpellClassSet does not resolve cleanly for them —
    # but a Druid power says "Moonfire" and a Shaman one says "Flame Shock", which is enough.
    CLASS_MARKERS = {
        "Druid": ["moonfire", "rake", "rip", "starfall", "shapeshift", "bear form", "cat form",
                  "barkskin", "convoke", "ironbark", "entangling roots", "soulshape"],
        "Shaman": ["flame shock", "lava burst", "ghost wolf", "chain lightning", "earth elemental",
                   "storm elemental", "maelstrom weapon", "healing stream", "bloodlust", "heroism",
                   "earthquake", "earth shock", "stormkeeper"],
        "DeathKnight": ["death grip", "marrowrend", "death coil", "obliterate", "festering strike",
                        "frost fever", "blood plague", "virulent plague", "death strike", "raise dead",
                        "sacrificial pact", "death gate", "pillar of frost", "icebound fortitude",
                        "chains of ice", "dark transformation"],
        "DemonHunter": ["eye beam", "fel rush", "metamorphosis", "fel devastation", "infernal strike",
                        "disrupt", "immolation aura", "demon blades", "demon's bite", "fracture",
                        "shear", "glaive"],
        "Priest": ["shadow word", "mind blast", "flash heal", "power infusion", "mind bomb",
                   "psychic scream", "holy fire", "purge the wicked", "holy shock", "fade", "void flay"],
        "Paladin": ["hammer of wrath", "avenging wrath", "judgment", "crusade", "seraphim",
                    "holy power", "hammer of justice"],
        "Hunter": ["kill shot", "disengage", "aspect", "bestial wrath", "trueshot",
                   "coordinated assault", "misdirection", "concussive shot", "wing clip", "feign death"],
        "Mage": ["blink", "mirror image", "ice block", "arcane blast", "fireball", "frostbolt",
                 "invisibility", "time warp", "frost shock"],
        "Warlock": ["demonic tyrant", "soul shard", "chaos bolt", "darkglare", "summon infernal",
                    "demonic gateway", "corruption", "malefic rapture", "dreadstalkers",
                    "health funnel", "shadow bolt", "drain soul", "incinerate"],
        "Monk": ["chi torpedo", "faeline stomp", "roll ", "crane style", "tiger style", "touch of death"],
        "Rogue": ["vanish", "sepsis", "echoing reprimand", "combo point", "crimson vial", "feint",
                  "evasion", "adrenaline rush", "shadow blades", "vendetta", "animacharged",
                  "poisons and bleeds"],
        "Warrior": ["heroic leap", "charge", "whirlwind", "condemn", "shattering throw",
                    "victory rush", "ignore pain", "berserker rage", "overpower", "raging blow",
                    "revenge", "piercing howl", "demoralizing shout", "thunder clap"],
    }

    def classify(text):
        low = text.lower()
        for cls, marks in CLASS_MARKERS.items():
            if any(m in low for m in marks):
                return cls
        return None

    want_class = None
    if args.klass:
        want_class = next((c for c in CLASS_MARKERS if c.lower() == args.klass.lower()), None)
        if not want_class:
            sys.exit(f"unknown class {args.klass!r}; try one of: {', '.join(sorted(CLASS_MARKERS))}")

    # Collapse identical name+description into one row listing every id.
    groups = defaultdict(list)
    for sid in sorted(roster):
        nm = names.get(sid, "")
        d = resolve(sid)
        if not nm or not d:
            continue
        # strip rank suffix so "Foo" and "Foo x2" group together
        base = re.sub(r" x ?\d$", "", nm)
        groups[(base, d)].append(sid)

    rows = []
    for (nm, d), ids in groups.items():
        mine = [i for i in ids if i in curated]
        if args.uncurated_only and mine:
            continue
        cls = classify(nm + " " + d)
        if want_class and cls != want_class:
            continue
        rows.append((min(ids), nm, ids, mine, d, cls))
    rows.sort()

    out = ["# Anima power reference", "",
           f"Every spell carrying `SpellLabel.LabelID == {ANIMA_LABEL}` (the roguelike-run power "
           "marker) that has both a name and a description. `$@spelldesc` pointers are resolved; "
           "rank variants and alternate IDs are collapsed onto one row.", "",
           f"{len(roster)} labelled spells -> {len(rows)} distinct powers"
           f"{' (uncurated only)' if args.uncurated_only else ''}"
           f"{' — ' + want_class + ' only' if want_class else ''}.", "",
           "`ids` lists every spell id sharing this description — **all of them need a score**, "
           "since the game may offer any one. Bold ids are already in AnimaPowerDB.", "",
           "| ids | class | name | description |", "|---|---|---|---|"]
    for _, nm, ids, mine, d, cls in rows:
        shown = ", ".join(f"**{i}**" if i in mine else str(i) for i in ids)
        out.append(f"| {shown} | {cls or '—'} | {nm} | {d[:300].replace('|', chr(92)+'|')} |")

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    io.open(args.out, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")

    fully = sum(1 for _, _, ids, mine, _, _ in rows if len(mine) == len(ids))
    partly = sum(1 for _, _, ids, mine, _, _ in rows if mine and len(mine) != len(ids))
    print(f"labelled spells       : {len(roster)}")
    print(f"distinct powers       : {len(rows)}")
    print(f"  fully curated       : {fully}")
    print(f"  PARTLY curated      : {partly}   <- some ids scored, siblings not (the Obleron trap)")
    print(f"  uncurated           : {len(rows) - fully - partly}")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
