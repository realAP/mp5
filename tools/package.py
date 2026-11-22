#!/usr/bin/env python3
"""Das Zip bauen, das nach Interface/AddOns/ gehoert.

    tools/package.py [--out dist]

Im Zip liegt genau ein Ordner MP5 mit den Lua-Dateien, den Texturen und der
TOC - also das, was man entpackt und fertig. Dazu Lizenz, Changelog und
README, damit das auch im Nachhinein auffindbar ist.

Gebaut wird mit der Standardbibliothek und nicht mit dem Programm "zip":
eine Abhaengigkeit weniger, und es laeuft hier genauso wie in der Pipeline.
"""
import argparse
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "MP5"
EXTRA = ["LICENSE", "CHANGELOG.md", "README.md"]
# Was im Addon-Ordner liegen kann, aber nicht ins Spiel gehoert.
SKIP = {".DS_Store"}


def toc_version(toc: Path) -> str:
    for line in toc.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^##\s*Version:\s*(.+?)\s*$", line)
        if m:
            return m.group(1)
    raise SystemExit(f"Keine '## Version:' in {toc}")


def files(addon_dir: Path) -> list[Path]:
    out = []
    for p in sorted(addon_dir.rglob("*")):
        if p.is_dir() or p.name in SKIP:
            continue
        out.append(p)
    return out


def build(root: Path, out_dir: Path) -> Path:
    addon_dir = root / ADDON
    version = toc_version(addon_dir / f"{ADDON}.toc")
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"{ADDON}-{version}.zip"

    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files(addon_dir):
            z.write(p, f"{ADDON}/{p.relative_to(addon_dir)}")
        for name in EXTRA:
            src = root / name
            if src.exists():
                z.write(src, f"{ADDON}/{name}")
    return target


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="dist")
    ap.add_argument("--root", default=str(ROOT))
    args = ap.parse_args()

    root = Path(args.root).resolve()
    target = build(root, Path(args.out).resolve())
    with zipfile.ZipFile(target) as z:
        for name in z.namelist():
            print(name)
    print(f"\n{target}  ({target.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
