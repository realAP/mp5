#!/usr/bin/env bash
# Alle Tests. Ohne Spiel, gegen nachgebaute Rahmen und eine Simulation.
#
#   tests/run.sh            aus dem Wurzelverzeichnis
#   LUA=lua5.1 tests/run.sh andere Lua-Version
#
# Die .lua-Dateien pruefen das Addon, die .py-Dateien das Verpacken.
set -u
cd "$(dirname "$0")/.."
LUA="${LUA:-lua5.1}"
fails=0
for t in tests/test_*.lua tests/test_*.py; do
    printf '%-28s ' "$(basename "$t")"
    case "$t" in
        *.py) runner=(python3) ;;
        *)    runner=("$LUA") ;;
    esac
    if out=$("${runner[@]}" "$t" 2>&1); then
        echo "$(echo "$out" | tail -1)"
    else
        fails=$((fails + 1))
        echo "FEHLGESCHLAGEN"
        echo "$out" | sed 's/^/    /'
    fi
done
echo
if [ "$fails" -eq 0 ]; then
    echo "Alle Dateien bestanden."
else
    echo "$fails Datei(en) fehlgeschlagen."
    exit 1
fi
