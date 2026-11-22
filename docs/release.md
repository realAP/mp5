# Release

## Einmalig einrichten

1. **Projekt auf CurseForge anlegen.** <https://legacy.curseforge.com/wow/addons>
   → *Start Project*. Das erste Upload prüft ein Mensch, das dauert ein bis
   zwei Tage. Dort gehören auch Beschreibung und Bilder hin.
2. **Projekt-ID eintragen.** Steht auf der Projektseite. In `MP5/MP5.toc`
   unter `## X-Curse-Project-ID:` die `0` ersetzen.
3. **API-Token setzen.** <https://legacy.curseforge.com/account/api-tokens>
   → Token erzeugen, dann im Repo unter *Settings ▸ Secrets and variables ▸
   Actions ▸ Secrets* als `CF_API_KEY` ablegen.
4. **Spielversion** (optional). Das Interface im TOC ist `16001` – die Nummer
   des privaten Clients, die CurseForge nicht kennt. Die Pipeline lädt
   deshalb als `1.15.7` hoch. Andere Version: unter *Variables* eine
   Repository-Variable `GAME_VERSION` setzen. Kennt CurseForge den Namen
   nicht, bricht der Lauf ab und zeigt die Liste der gültigen Namen.

## Trockenlauf

*Actions ▸ release ▸ Run workflow.* Baut nur das Zip und hängt es an den
Lauf – nichts wird veröffentlicht. Damit lässt sich prüfen, ob Tests und
Paket stimmen, ohne einen Tag zu verbrennen.

## Veröffentlichen

Version in `MP5/MP5.toc` und Abschnitt in `CHANGELOG.md` müssen dieselbe
Nummer tragen; der Tag auch, sonst bricht der Lauf ab.

```
git tag v0.1.0
git push origin v0.1.0
```

Der Tag löst `.github/workflows/release.yml` aus:

1. Tests (`tests/run.sh`) – ohne grün geht nichts weiter
2. Version aus dem TOC gegen den Tag prüfen
3. Beschreibung aus `CHANGELOG.md` holen (`tools/changelog.py`)
4. Zip bauen (`tools/package.py`) und an den Lauf hängen
5. zu CurseForge hochladen (`tools/cf_metadata.py` + `curl`)
6. GitHub-Release mit demselben Zip und derselben Beschreibung

Ein Tag **auf `main`**, nicht auf `work` – sonst steckt im Release Arbeit,
die noch nicht gemerged ist. Ein Tag mit Bindestrich (`v0.2.0-beta`) geht
als Vorabversion raus, alles andere als fertiges Release.

## Warum von Hand gepackt

Üblich wäre der BigWigs-Packager. Hier liegt das Addon in einem
Unterordner, das Interface ist die Nummer eines privaten Clients, und das
Changelog ist gepflegt statt generiert – drei Sonderfälle, bei denen der
Packager jeweils konfiguriert werden müsste. Die drei kleinen Skripte in
`tools/` tun stattdessen genau das, was hier gebraucht wird, und
`tests/test_release.py` prüft sie, damit der Tag nicht die erste Probe ist.
