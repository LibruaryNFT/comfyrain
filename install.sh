#!/usr/bin/env bash
# Build the AlwaysRain assets and install the addon into a WoW flavor.
#
#   ./install.sh                 -> _classic_beta_ (default)
#   ./install.sh _classic_era_
#   ./install.sh _retail_
#
# WoW only scans Interface/AddOns at launch, so the client must be fully
# restarted after a first install. Lua-only edits just need /reload.
set -euo pipefail

FLAVOR="${1:-_classic_beta_}"
WOW="/home/mycomputer/Games/battlenet/pfx/drive_c/Program Files (x86)/World of Warcraft"
DEST="${WOW}/${FLAVOR}/Interface/AddOns/AlwaysRain"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -d "${WOW}/${FLAVOR}" ] || { echo "no such flavor: ${FLAVOR}" >&2; exit 1; }

mkdir -p "$DEST"
cp "${HERE}/AlwaysRain/AlwaysRain.lua" "${HERE}/AlwaysRain/AlwaysRain.toc" "$DEST/"

# Assets are generated, not checked in - they are deterministic from these scripts.
# The addon prefers Blizzard's own weather audio by FileDataID; these files are
# only the fallback for a client that will not play them.
python3 "${HERE}/build/make_rain_tga.py" "$DEST"
python3 "${HERE}/build/make_rain_audio.py" "$DEST"

echo
echo "installed to ${DEST}"
ls -la "$DEST"
