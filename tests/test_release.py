#!/usr/bin/env python3
"""Prueft, was beim Veroeffentlichen schiefgehen kann, bevor es schiefgeht.

Die Pipeline laeuft nur bei einem Tag - also genau dann, wenn ein Fehler
teuer ist. Deshalb sind die drei Teile, die dort rechnen, hier einzeln
geprueft: das Zip, der Changelog-Abschnitt und die Spielversion.
"""
import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import cf_metadata  # noqa: E402
import changelog  # noqa: E402
import package  # noqa: E402

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    if not ok:
        fails += 1
    print(f"{name:<54} {str(got):<14} erwartet {want}", "OK" if ok else "FEHLER")


# Das Zip ---------------------------------------------------------------------

with tempfile.TemporaryDirectory() as tmp:
    target = package.build(ROOT, Path(tmp))
    names = zipfile.ZipFile(target).namelist()

    version = package.toc_version(ROOT / "MP5" / "MP5.toc")
    check("Zip ist nach der Version benannt", target.name, f"MP5-{version}.zip")
    check("TOC liegt im Ordner MP5", "MP5/MP5.toc" in names, True)
    check("Texturen sind dabei", "MP5/Textures/icon.tga" in names, True)
    check("Lizenz ist dabei", "MP5/LICENSE" in names, True)

    # Alles liegt unter MP5/ - sonst entpackt es neben den Addon-Ordner.
    stray = [n for n in names if not n.startswith("MP5/")]
    check("nichts liegt neben dem Ordner", stray, [])

    # Und nichts, was nur die Entwicklung braucht.
    unwanted = [n for n in names if "/tests/" in n or "/tools/" in n or "/docs/" in n]
    check("keine Tests oder Werkzeuge im Zip", unwanted, [])

    lua = [n for n in names if n.endswith(".lua")]
    toc_files = [
        line.strip()
        for line in (ROOT / "MP5" / "MP5.toc").read_text(encoding="utf-8").splitlines()
        if line.strip().endswith(".lua")
    ]
    check("so viele Lua-Dateien wie die TOC laedt", len(lua), len(toc_files))

# Der Changelog-Abschnitt ------------------------------------------------------

text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
check("Abschnitt zur Version wird gefunden", bool(changelog.section(text, version)), True)
check("v davor ist erlaubt", bool(changelog.section(text, "v" + version)), True)
check("fremde Version gibt nichts", changelog.section(text, "9.9.9"), "")

# Nur der eigene Abschnitt, nicht der naechste.
sample = "# Changelog\n\n## 2.0\n\nzwei\n\n## 1.0\n\neins\n"
check("Abschnitt endet beim naechsten", changelog.section(sample, "2.0"), "zwei")
check("auch der letzte Abschnitt geht", changelog.section(sample, "1.0"), "eins")

# Die Spielversion -------------------------------------------------------------

versions = [
    {"id": 517, "name": "1.13.2"},
    {"id": 11504, "name": "1.15.7"},
    {"id": 10220, "name": "11.0.2"},
]
check("Name wird zur ID", cf_metadata.resolve(versions, "1.15.7"), 11504)

try:
    cf_metadata.resolve(versions, "16001")
    check("unbekannte Version bricht ab", "nein", "ja")
except SystemExit as e:
    check("unbekannte Version bricht ab", "ja", "ja")
    check("und sagt, was es gibt", "1.15.7" in str(e), True)

# Dasselbe ueber die Kommandozeile, so wie die Pipeline es aufruft.
with tempfile.TemporaryDirectory() as tmp:
    vf = Path(tmp) / "versions.json"
    vf.write_text(json.dumps(versions), encoding="utf-8")
    notes = Path(tmp) / "notes.md"
    notes.write_text("Erste Veroeffentlichung.", encoding="utf-8")

    out = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "cf_metadata.py"),
         "--version", version, "--game-version", "1.15.7",
         "--channel", "beta", "--notes", str(notes),
         "--versions-file", str(vf)],
        capture_output=True, text=True, check=True,
    )
    meta = json.loads(out.stdout)
    check("Beschreibung nennt die Spielversion", meta["gameVersions"], [11504])
    check("Beschreibung nennt den Kanal", meta["releaseType"], "beta")
    check("Beschreibung traegt den Namen", meta["displayName"], f"MP5 {version}")
    check("Beschreibung enthaelt das Changelog",
          meta["changelog"].startswith("Erste"), True)

print()
if fails == 0:
    print("Alle Tests bestanden.")
else:
    print(f"{fails} Test(s) fehlgeschlagen.")
    sys.exit(1)
