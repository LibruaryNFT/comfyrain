#!/usr/bin/env python3
"""Answer "which TOC flavour suffix does this client load?" empirically.

The question matters because getting it wrong on 4 November means the addon
does not load at all, and the beta client that can answer it is withdrawn on
21 October. Two reports named two mutually exclusive candidates and only one
cited any evidence, so this guesses nothing and tests every suffix at once.

How it works. WoW picks exactly ONE .toc per addon folder: the one whose
suffix matches the client's flavour, falling back to the unsuffixed file.
Each .toc here loads a DIFFERENT one-line Lua, so whichever line appears in
SavedVariables names the suffix this client chose. One launch, nothing typed.

Delete the folder afterwards; it ships to nobody.

Usage: make_flavour_probe.py <addons-dir>
"""
import sys
from pathlib import Path

# Every suffix the packager can emit, plus the ones the two reports named.
# Testing all of them costs nothing: only one file will ever load.
SUFFIXES = [
    "",            # no suffix, the fallback every client accepts
    "_Vanilla",
    "_Classic",
    "_Forever",
    "_Mists",
    "_Cata",
    "_Wrath",
    "_TBC",
    "_Standard",
    "_Mainline",
]

TOC = """## Interface: 16001
## Title: Duskfall flavour probe
## Notes: Answers which TOC suffix this client loads. Delete after reading.
## Version: 1.0
## SavedVariables: DuskfallFlavourDB

{lua}
"""

LUA = """-- Loaded only if the client chose the TOC suffix named below.
DuskfallFlavourDB = DuskfallFlavourDB or {{}}
DuskfallFlavourDB.loaded = {suffix!r}
DuskfallFlavourDB.build = select(2, GetBuildInfo())
DuskfallFlavourDB.interface = select(4, GetBuildInfo())
print("|cff7fb8ffDuskfall flavour|r: this client loaded " .. {suffix!r})
"""


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    dest = Path(sys.argv[1]) / "DuskfallFlavour"
    dest.mkdir(parents=True, exist_ok=True)

    for suffix in SUFFIXES:
        name = suffix or "_none"
        lua = "Flavour%s.lua" % name
        # Lua has no repr, but the suffix is a plain ASCII identifier, so
        # Python's repr of it is a valid Lua string literal.
        label = suffix if suffix else "(no suffix)"
        (dest / lua).write_text(LUA.format(suffix=label))
        (dest / ("DuskfallFlavour%s.toc" % suffix)).write_text(TOC.format(lua=lua))

    print("wrote %d TOCs to %s" % (len(SUFFIXES), dest))
    print("launch the client once; the answer lands in")
    print("  WTF/Account/<ACCOUNT>/SavedVariables/DuskfallFlavourDB.lua")


if __name__ == "__main__":
    main()
