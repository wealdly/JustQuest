# Container DB2 data

At runtime the addon detects openable containers **live** from `C_Container.GetContainerItemInfo`
(`info.hasLoot` = the openable flag), so no list is shipped. The generated
`Database/ContainerData.lua` was removed from the addon — it was built from the same flag the
live read returns, so it could never know anything the live read didn't. This folder is kept as
**provenance and analysis only**; nothing here is loaded by the addon.

> `info.isLocked` is **not** a lockbox test — it is the transient "item is in use" state the game
> uses to grey out an icon and block pickup, and a lockbox at rest reports `false`. There is no
> runtime lockbox signal. Reading it as one is what made the engine report opening lockboxes it
> had not opened.

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
| **Lock** | optional | Splits lockboxes into **pickable** vs **key-required** + required skill. Analysis only — the addon never opens a lockbox, because that needs a spell cast and a spell cast needs a hardware event. |
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
`LockID != 0` → a lockbox. Note this is the *only* place lockbox-ness is knowable: `LockID` is
not exposed to Lua, which is why the engine handles unopenable boxes by confirming the open
rather than by trying to identify them.
