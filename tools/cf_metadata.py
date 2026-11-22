#!/usr/bin/env python3
"""Die Beschreibung des Uploads fuer CurseForge bauen.

    tools/cf_metadata.py --version 0.1.0 --game-version 1.15.7 \
        --channel release --notes release-notes.md > metadata.json

CurseForge will die *ID* der Spielversion, nicht ihren Namen. Die Liste
kommt aus der API; dafuer wird CF_API_KEY gebraucht. Mit --versions-file
laesst sich eine gespeicherte Liste verwenden - so ist der Teil, auf den es
ankommt (Name -> ID), ohne Netz pruefbar.

Kennt CurseForge den Namen nicht, bricht das Programm ab und zeigt, was es
zur Auswahl gibt. Das ist der wahrscheinlichste Fehler hier: das Interface
im TOC ist die Nummer eines privaten Clients und taucht dort nie auf.
"""
import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

API = "https://wow.curseforge.com/api/game/versions"


def fetch_versions(token: str) -> list:
    req = urllib.request.Request(API, headers={"X-Api-Token": token})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def resolve(versions: list, name: str) -> int:
    for v in versions:
        if v.get("name") == name:
            return int(v["id"])
    choices = sorted({str(v.get("name")) for v in versions})
    raise SystemExit(
        f"CurseForge kennt die Spielversion '{name}' nicht.\n"
        "Zur Auswahl: " + ", ".join(choices[-40:])
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--game-version", required=True)
    ap.add_argument("--channel", default="release",
                    choices=["release", "beta", "alpha"])
    ap.add_argument("--notes", required=True)
    ap.add_argument("--versions-file")
    args = ap.parse_args()

    if args.versions_file:
        versions = json.loads(Path(args.versions_file).read_text(encoding="utf-8"))
    else:
        token = os.environ.get("CF_API_KEY", "")
        if not token:
            raise SystemExit("CF_API_KEY fehlt - siehe docs/release.md")
        versions = fetch_versions(token)

    meta = {
        "changelog": Path(args.notes).read_text(encoding="utf-8"),
        "changelogType": "markdown",
        "displayName": f"MP5 {args.version}",
        "gameVersions": [resolve(versions, args.game_version)],
        "releaseType": args.channel,
    }
    json.dump(meta, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
