#!/usr/bin/env python3
"""Writes assets/emoji.txt, the emoji picker's list, from Python's own Unicode database.

One emoji per line: the character, a tab, its group, a tab, its name in lower case (what the search matches).
Only single-character emoji (no flags or joined sequences): the Unicode blocks below, named characters only.

    python3 scripts/build-emoji.py
"""

import os
import unicodedata

GROUPS = [
    ("smileys", [(0x1F600, 0x1F64F), (0x1F910, 0x1F92F), (0x1F970, 0x1F97F), (0x1FAE0, 0x1FAEF)]),
    ("people", [(0x1F466, 0x1F4AF), (0x1F930, 0x1F94F), (0x1F9D0, 0x1F9FF), (0x1F44A, 0x1F465)]),
    ("nature", [(0x1F330, 0x1F37F), (0x1F400, 0x1F43F), (0x1F980, 0x1F9AF), (0x1FAB0, 0x1FABF)]),
    ("food", [(0x1F950, 0x1F96F), (0x1FAD0, 0x1FADF)]),
    ("activities", [(0x1F380, 0x1F3FF), (0x1F93A, 0x1F94F), (0x1FA70, 0x1FA7F)]),
    ("travel", [(0x1F680, 0x1F6FF)]),
    ("objects", [(0x1F4B0, 0x1F4FF), (0x1F500, 0x1F5FF), (0x1FA80, 0x1FAAF), (0x1F9F0, 0x1F9FF)]),
    ("symbols", [(0x2600, 0x26FF), (0x2700, 0x27BF), (0x1F300, 0x1F32F), (0x2190, 0x21FF), (0x2B00, 0x2BFF)]),
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "emoji.txt")
    seen = set()
    lines = []
    for group, ranges in GROUPS:
        for lo, hi in ranges:
            for cp in range(lo, hi + 1):
                ch = chr(cp)
                if ch in seen:
                    continue
                name = unicodedata.name(ch, "")
                if not name or unicodedata.category(ch) not in ("So", "Sm"):
                    continue
                seen.add(ch)
                lines.append(f"{ch}\t{group}\t{name.lower()}")
    with open(out, "w") as f:
        f.write("# The emoji picker's list (SUPER+semicolon), built by scripts/build-emoji.py. char<TAB>group<TAB>name\n")
        f.write("\n".join(lines) + "\n")
    print(len(lines), "emoji in", out)


if __name__ == "__main__":
    main()
