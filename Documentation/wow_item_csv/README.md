# Container DB2 data

At runtime the addon detects openable containers **live** from `C_Container.GetContainerItemInfo`
(`info.hasLoot` = the openable flag, `info.isLocked` = lockbox), so no list is normally needed.
The generated `Database/ContainerData.lua` is only a **fallback**, used if that live read ever
comes back nil/unreadable. So regenerating is optional — do it when you want the fallback fresh.

Source CSVs are exported from **https://wago.tools** (pick the live retail build, "Export → CSV").
This folder and `tools/` are excluded from the packaged addon (`.pkgmeta` ignore).

Regenerate the fallback list:

```
python tools/gen_containers.py --csv-dir Documentation/wow_item_csv
```

## Which CSVs to pull

| CSV | Needed? | Used for |
|-----|---------|----------|
| **ItemSparse** | **required** | `Flags_0 & 0x4` (ITEM_FLAG_OPENABLE) — the authoritative "opens to give loot" signal — plus `LockID`, `StartQuestID`, `ContainerSlots`, name, expansion. |
| **Item** | **required** | `ClassID` / `SubclassID` (reporting / optional filtering). |
| **Lock** | optional | Would split lockboxes into rogue-**pickable** vs **key-required** + required skill. Not required: rogue auto-pick is attempt-based at runtime (a box that won't pick just burns its retry budget). Pull it only if you later want to pre-filter picks precisely. |
| ItemEffect + ItemXItemEffect | optional | Catches the handful of "bags" that give loot via an on-use spell instead of the flag. |
| ItemClass / ItemSubClass | optional | Human-readable class names in reports. |

ItemSparse is ~50 MB, so keep the big raws wherever you export them (or in JustAC's
`Documentation/wow_spell_csv/`) and point `--csv-dir` at that folder. Only the slim,
derived `containers.<version>.csv` (openable items + lock info, a few hundred KB) is worth
committing here as provenance.

## The classification signal

`ItemSparse.Flags_0 & 0x4` is set by the game on every item that opens to give loot and on
nothing else. Validated against the old hand-curated list: 99% of its real containers carry
the flag; 0% of its "not a container" blacklist does. `LockID == 0` → free to auto-open;
`LockID != 0` → a lockbox (the client reports it locked until a key/pick is applied).
