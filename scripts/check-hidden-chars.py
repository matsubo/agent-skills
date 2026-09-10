#!/usr/bin/env python3
"""Report characters that render invisibly, in every file given on the command line.

    scripts/check-hidden-chars.py skills/release/SKILL.md ...

Prints one tab-separated `hidden-instruction<TAB>path:line<TAB>message` finding per
occurrence and exits 0 regardless; audit.sh counts the findings.

A skill is instructions that run on someone else's machine, and a reviewer approves it by
reading it. Any character that the model consumes but the reviewer cannot see breaks that
review: zero-width characters hide text outright, and bidirectional overrides reorder a
line so that what is displayed is not what is parsed (CVE-2021-42574, "Trojan Source").

This is a Python check rather than `grep -P` because BSD grep, which is what a stock macOS
clone of this repository has, does not support -P at all.
"""
import sys
import unicodedata
from pathlib import Path

# Zero-width and non-rendering.
INVISIBLE = {
    "​": "zero-width space",
    "‌": "zero-width non-joiner",
    "‍": "zero-width joiner",
    "⁠": "word joiner",
    "﻿": "zero-width no-break space (BOM)",
    "­": "soft hyphen",
}

# Bidirectional control characters: they reorder the rendering of a line without changing
# the bytes a parser or a model sees.
BIDI = {
    "‎": "left-to-right mark",
    "‏": "right-to-left mark",
    "‪": "left-to-right embedding",
    "‫": "right-to-left embedding",
    "‬": "pop directional formatting",
    "‭": "left-to-right override",
    "‮": "right-to-left override",
    "⁦": "left-to-right isolate",
    "⁧": "right-to-left isolate",
    "⁨": "first strong isolate",
    "⁩": "pop directional isolate",
}

SUSPECT = {**INVISIBLE, **BIDI}


def check(path: Path) -> list[tuple[str, str]]:
    """Return (location, message) for every invisible character in one file."""
    findings = []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return [(str(path), f"cannot read as UTF-8 text: {error}")]

    for line_number, line in enumerate(text.splitlines(), start=1):
        for column, character in enumerate(line, start=1):
            if character in SUSPECT:
                findings.append((
                    f"{path}:{line_number}",
                    f"column {column} is U+{ord(character):04X} "
                    f"({SUSPECT[character]}), which renders invisibly",
                ))
    return findings


def main(argv: list[str]) -> int:
    for argument in argv:
        for location, message in check(Path(argument)):
            print(f"hidden-instruction\t{location}\t{message}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
