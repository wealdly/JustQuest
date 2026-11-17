# Regenerate WEAPON_SPECS in Services/ClassWeights.lua from WoW Forever DB2 CSV exports.
#
#   python tools/gen_weapon_specs.py <folder with SpellName, SpellEffect, SpellEquippedItems,
#                                     SkillLine, SkillLineAbility CSVs> [build]
#
# Picks every racial (skill category 9) and class-talent (7) passive that is restricted to weapon
# types (SpellEquippedItems, item class 2) and raises crit (auras 52 / 290) or damage (aura 79),
# and prints Lua table rows: [spellID] = { item-subclass mask, crit %, damage % }.
# Paste the output over the rows of WEAPON_SPECS.

import csv, glob, os, sys, collections

folder = sys.argv[1]
build = sys.argv[2] if len(sys.argv) > 2 else "*"

def rows(name):
    path = sorted(glob.glob(os.path.join(folder, f"{name}.{build}.csv")))[-1]
    return list(csv.DictReader(open(path, encoding="utf-8", errors="replace")))

names = {r["ID"]: r["Name_lang"] for r in rows("SpellName")}
skills = {r["ID"]: r for r in rows("SkillLine")}
effects = collections.defaultdict(list)
for r in rows("SpellEffect"):
    effects[r["SpellID"]].append(r)
spell_skills = collections.defaultdict(list)
for r in rows("SkillLineAbility"):
    spell_skills[r["Spell"]].append(r["SkillLine"])

CRIT_AURAS, DAMAGE_AURAS = {"290", "52"}, {"79"}
out = []
for e in rows("SpellEquippedItems"):
    sid = e["SpellID"]
    if e.get("EquippedItemClass") != "2":
        continue
    cats = {skills.get(s, {}).get("CategoryID") for s in spell_skills.get(sid, [])}
    if not cats & {"7", "9"}:
        continue
    crit = sum(float(x["EffectBasePointsF"] or 0) for x in effects[sid] if x["EffectAura"] in CRIT_AURAS)
    dmg = sum(float(x["EffectBasePointsF"] or 0) for x in effects[sid] if x["EffectAura"] in DAMAGE_AURAS)
    if not (crit or dmg):
        continue
    line = ", ".join(skills[s]["DisplayName_lang"] for s in spell_skills[sid] if s in skills)
    out.append((int(sid), int(e["EquippedItemSubclass"] or 0), crit, dmg, names.get(sid, "?"), line))

for sid, mask, crit, dmg, name, line in sorted(out):
    print(f"    [{sid}] = {{ {mask}, {crit:g}, {dmg:g} }},  -- {name} ({line})")
