#!/usr/bin/env python3
"""Turn the Description block in docs/curseforge-page.md into paste-ready HTML.

CurseForge's description editor takes HTML in its </> source view, and Markdown
pasted there renders as literal ## and - characters. The Markdown in
curseforge-page.md stays the master copy; this writes the HTML a person pastes,
so the conversion is never done by hand.

Handles exactly what the description uses: ## headings (with an <hr> before
every one but the first, as on the live page), - bullets, paragraphs,
**bold**, `code` and [links](url). Anything else is a new construct and should
be added here before it goes in the description.

Usage: cf_description.py [out.html]   (default docs/curseforge-description.html)
"""
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "curseforge-page.md"


def block():
    text = PAGE.read_text()
    after = text.split("\n## Description\n", 1)[1]
    m = re.search(r"\n```\n(.*?)\n```\n", after, re.S)
    return m.group(1)


def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"`(.+?)`", r"<code>\1</code>", s)
    s = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', s)
    return s


def convert(md):
    out = []
    for para in re.split(r"\n\s*\n", md.strip()):
        lines = para.splitlines()
        if lines[0].startswith("## "):
            # The live page has a rule between sections, hand-added when it was
            # first pasted. Leaving it out would quietly strip them on re-paste.
            if out:
                out.append("<hr>")
            out.append(f"<h2>{inline(lines[0][3:])}</h2>")
            lines = lines[1:]
            if not lines:
                continue
        if all(line.startswith("- ") for line in lines):
            out.append("<ul>")
            out.extend(f"<li>{inline(line[2:])}</li>" for line in lines)
            out.append("</ul>")
        else:
            out.append(f"<p>{inline(' '.join(lines))}</p>")
    return "\n".join(out) + "\n"


def main():
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else \
        ROOT / "docs" / "curseforge-description.html"
    dest.write_text(convert(block()))
    print(f"wrote {dest}")


if __name__ == "__main__":
    main()
