# The whole addon API surface, extracted

**Asked 2026-10-19:** can we have a full understanding of everything an addon
can possibly do, approved or not? Partly - here is the technical half, complete.

`tools/api_audit.py` checks the **111** APIs this addon uses. That is a guard,
not a map. `tools/api_surface.py` extracts everything the client exposes.

| | count |
|---|---|
| `C_` namespaced functions | **2,917** across 245 namespaces |
| legacy globals | **1,268** |
| widget methods (on UI frames) | **1,161** |
| Blizzard additions to `math`/`table`/`string`, plus `Kiosk` | 32 |
| **total** | **5,378** |

- `docs/api-surface.tsv` - every one, with its kind and namespace.
- `docs/api-namespaces.txt` - the 245 namespaces by size. `C_Item` 113,
  `C_Commentator` 93, `C_TooltipInfo` 76, `C_QuestLog` 74.

Search it with `tools/api_surface.py --grep PATTERN`, which is how the
3D-rain and herb-recolour questions were answered. See
[3d-rain-feasibility.md](3d-rain-feasibility.md).

## What this does not tell you, and why each gap is different

**Which functions are protected.** `ADDON_ACTION_BLOCKED` is in the binary, so
the mechanism is there, but protection is not labelled in the strings. It has
to be established per function from documentation or a live call. An unlabelled
function is not a callable one.

**What the policy permits.** That is a licence question. This tool makes no
claim about it and the counts above include things no published addon may use.

**FrameXML Lua.** `ReloadUI`, `SlashCmdList`, `CreateColor`, `Settings.Register*`
and the rest are defined in Lua that ships alongside the executable, not in it.
They are absent here and that absence means nothing - the same trap
`api_audit.py` handles with its `LUA_SIDE` list.

**19 functions whose names do not exist in the binary at all.** The engine builds
their usage strings with a runtime `%s`, so what gets compiled in is literally
`%s("channel", "name")`. No strings-based method can recover these, by any tool.
They are counted and reported rather than quietly dropped, because the main
question this gets asked is "is there an API for X" and a parser that silently
loses part of the surface makes every "no" worthless.

Regenerate after any client patch:

```
python3 -I tools/api_surface.py --tsv docs/api-surface.tsv
python3 -I tools/api_surface.py --namespaces > docs/api-namespaces.txt
```
