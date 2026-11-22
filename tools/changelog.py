#!/usr/bin/env python3
"""Den Abschnitt einer Version aus CHANGELOG.md holen.

    tools/changelog.py 0.1.0

Wird beim Release gebraucht: derselbe Text geht an CurseForge und an das
GitHub-Release, damit nicht zwei Beschreibungen auseinanderlaufen. Findet
sich die Version nicht, ist das ein Fehler - lieber kein Release als eines
ohne Beschreibung.
"""
import re
import sys
from pathlib import Path


def section(text: str, version: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    inside = False
    for line in lines:
        head = re.match(r"^##\s+(\S+)", line)
        if head:
            if inside:
                break
            inside = head.group(1).lstrip("v") == version.lstrip("v")
            continue
        if inside:
            out.append(line)
    return "\n".join(out).strip("\n")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    version = sys.argv[1]
    path = Path(__file__).resolve().parent.parent / "CHANGELOG.md"
    body = section(path.read_text(encoding="utf-8"), version)
    if not body:
        print(f"CHANGELOG.md hat keinen Abschnitt '## {version}'", file=sys.stderr)
        return 1
    print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
