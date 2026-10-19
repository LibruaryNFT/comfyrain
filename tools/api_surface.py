#!/usr/bin/env python3
"""Extract the COMPLETE Lua API surface from the client binary.

tools/api_audit.py answers "is each API we use really there?" - 111 names, a
guard against shipping a call that does not exist. This answers the opposite and
much larger question: what is there at all, whether or not we use it.

The client registers every Lua function with a usage string, and those survive
into the executable's strings verbatim:

    Usage: local info = C_HousingDecor.GetDecorDebugInfoForGUID(decorGUID)
    Usage: self:SetCameraOrientationByYawPitchRoll(yaw, pitch, roll)
    Usage: BuyTrainerService(index)

Three shapes, three different things. A `C_` prefix is a modern namespaced API.
A bare capitalised name is a legacy global. A `self:` prefix is a WIDGET method,
which matters more than it looks: those are methods on UI frames, and finding
SetCameraOrientationByYawPitchRoll in that group rather than in the globals is
exactly what proved the 3D-rain question (docs/3d-rain-feasibility.md). A camera
you can aim is useless if it is a model frame's camera and not the game's.

What this CANNOT tell you, and the reasons are different in each case:

  - whether a function is PROTECTED. The client marks blocked calls at runtime
    (ADDON_ACTION_BLOCKED is in here) but does not label them in the strings, so
    protection has to be established per function from documentation or a live
    call. Absence of a label is not evidence of being callable.
  - whether a function is permitted by the addon policy. That is a licence
    question, not a technical one, and this tool makes no claim about it.
  - whether a name is reachable from a normal addon at all. Some of these are
    internal or FrameXML-only.

Usage:
  tools/api_surface.py                 summary to stdout
  tools/api_surface.py --tsv OUT.tsv   every function, one per line
  tools/api_surface.py --namespaces    every C_ namespace with its count
  tools/api_surface.py --grep PATTERN  search the surface, with context
"""

import argparse
import os
import re
import subprocess
import sys

DEFAULT_EXE = os.path.expanduser(
    "~/Games/battlenet/pfx/drive_c/Program Files (x86)/"
    "World of Warcraft/_classic_beta_/WowB.exe")

# "Usage: " then an optional capture-assignment, then the call. The assignment
# half is thrown away; it names return values, not the API. Both shapes occur:
# "local info = C_Foo.Bar()" and "tank, healer = GetLFDRoleRestrictions(id)".
USAGE = re.compile(r"^Usage:\s+(.+)$")
ASSIGN = re.compile(r"^(?:local\s+)?[A-Za-z_][A-Za-z0-9_, ]*\s*=\s*(?!=)(.+)$")

# self:Method(args) - a widget method, not a global.
WIDGET = re.compile(r"^self:([A-Za-z_][A-Za-z0-9_]*)\s*\(")
# C_Namespace.Function(args)
NAMESPACED = re.compile(r"^(C_[A-Za-z0-9_]+)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
# Any other dotted library: Kiosk.*, and Blizzard's own additions to the Lua
# standard library (math.clamp, table.freeze, string.startswith). Those last are
# worth capturing rather than discarding - they are part of what an addon can
# do, and several of them do not exist in stock Lua 5.1.
LIBRARY = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
# bareGlobal(args). NOT capital-only: hooksecurefunc, issecurevariable,
# securerandom and pcallwithenv are all lowercase and all real, and an earlier
# capital-only rule dropped every one of them.
GLOBAL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(")
# The engine builds some usage strings with the function name as a printf
# argument, so the literal "%s" is what reaches the binary and the name is NOT
# recoverable from strings at all. Counted, never guessed at.
TEMPLATE = re.compile(r"^(%s|\()")


def load_usage_lines(exe):
    if not os.path.exists(exe):
        sys.exit("no client binary at %s\n"
                 "Pass --exe, or keep a copy: the beta client is withdrawn on\n"
                 "2026-10-21 and this tool needs only the file, not a login."
                 % exe)
    raw = subprocess.run(["strings", "-n", "4", exe],
                         capture_output=True, text=True, check=True).stdout
    out = []
    for line in raw.splitlines():
        m = USAGE.match(line.strip())
        if m:
            call = m.group(1).strip()
            a = ASSIGN.match(call)
            if a:
                call = a.group(1).strip()
            out.append(call)
    return out


def classify(calls):
    """-> (namespaced, globals, widgets, libraries, templates, unparsed)"""
    namespaced, libraries = {}, {}
    globals_, widgets = set(), set()
    templates, unparsed = [], []
    for call in calls:
        m = NAMESPACED.match(call)
        if m:
            namespaced.setdefault(m.group(1), set()).add(m.group(2))
            continue
        m = WIDGET.match(call)
        if m:
            widgets.add(m.group(1))
            continue
        if TEMPLATE.match(call):
            templates.append(call)
            continue
        m = LIBRARY.match(call)
        if m:
            libraries.setdefault(m.group(1), set()).add(m.group(2))
            continue
        m = GLOBAL.match(call)
        if m:
            globals_.add(m.group(1))
            continue
        unparsed.append(call)
    return namespaced, globals_, widgets, libraries, templates, unparsed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", default=DEFAULT_EXE)
    ap.add_argument("--tsv", help="write every function here, one per line")
    ap.add_argument("--namespaces", action="store_true",
                    help="list every C_ namespace with its function count")
    ap.add_argument("--grep", metavar="PATTERN",
                    help="case-insensitive search across the whole surface")
    args = ap.parse_args()

    calls = load_usage_lines(args.exe)
    (namespaced, globals_, widgets,
     libraries, templates, unparsed) = classify(calls)

    rows = []
    for ns in sorted(namespaced):
        for fn in sorted(namespaced[ns]):
            rows.append((ns, fn, "%s.%s" % (ns, fn)))
    for ns in sorted(libraries):
        for fn in sorted(libraries[ns]):
            rows.append((ns, fn, "%s.%s" % (ns, fn)))
    for fn in sorted(globals_):
        rows.append(("(global)", fn, fn))
    for fn in sorted(widgets):
        rows.append(("(widget)", fn, "self:%s" % fn))

    if args.grep:
        pat = re.compile(args.grep, re.I)
        hits = [r for r in rows if pat.search(r[2])]
        for ns, fn, full in hits:
            print("%-28s %s" % (ns, full))
        print("\n%d of %d" % (len(hits), len(rows)))
        # A search that finds nothing is only meaningful if the corpus loaded.
        if not hits:
            print("Zero hits. The corpus holds %d functions, so the search "
                  "works\nand this name is genuinely absent from the usage "
                  "strings. Note that\nFrameXML-only Lua never appears here at "
                  "all - see docs/." % len(rows))
        return

    if args.tsv:
        with open(args.tsv, "w") as fh:
            fh.write("kind\tnamespace\tname\tcall\n")
            for ns, fn, full in rows:
                kind = ("namespaced" if ns.startswith("C_")
                        else "widget" if ns == "(widget)" else "global")
                fh.write("%s\t%s\t%s\t%s\n" % (kind, ns, fn, full))
        print("wrote %d functions to %s" % (len(rows), args.tsv))

    if args.namespaces:
        for ns in sorted(namespaced, key=lambda n: (-len(namespaced[n]), n)):
            print("%-5d %s" % (len(namespaced[ns]), ns))
        return

    total_ns = sum(len(v) for v in namespaced.values())
    total_lib = sum(len(v) for v in libraries.values())
    print("Client: %s" % args.exe)
    print("%d usage strings parsed\n" % len(calls))
    print("  %-22s %5d functions across %d namespaces"
          % ("C_ namespaced", total_ns, len(namespaced)))
    print("  %-22s %5d" % ("legacy globals", len(globals_)))
    print("  %-22s %5d (methods on UI frames, NOT on the world)"
          % ("widget methods", len(widgets)))
    print("  %-22s %5d across %s"
          % ("library additions", total_lib, ", ".join(sorted(libraries))))
    print("  %-22s %5d" % ("TOTAL", len(rows)))

    # Both of these are losses, and saying so is the point. A parser that
    # quietly drops part of the surface makes every "no such API" answer
    # worthless, and "no such API" is the main thing this gets asked.
    if templates:
        print("\n  %d usage strings name the function with a runtime %%s, so the"
              % len(templates))
        print("  name is not in the binary at all and cannot be recovered from")
        print("  strings by any method. Not an omission, a hard limit:")
        for t in templates[:3]:
            print("    %s" % t)
    if unparsed:
        print("\n  %d usage strings matched no shape at all:" % len(unparsed))
        for u in unparsed[:5]:
            print("    %s" % u)


if __name__ == "__main__":
    main()
