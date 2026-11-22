# Release

## Einmalig einrichten

1. **Projekt auf CurseForge anlegen.** <https://legacy.curseforge.com/wow/addons>
   → *Start Project*. Das erste Upload wird von einem Menschen geprüft, das
   dauert ein bis zwei Tage.
2. **Projekt-ID eintragen.** Steht auf der Projektseite rechts. In
   `MP5/MP5.toc` unter `## X-Curse-Project-ID:` die `0` ersetzen.
3. **API-Token setzen.** <https://legacy.curseforge.com/account/api-tokens>
   → Token erzeugen, dann im GitHub-Repo unter *Settings ▸ Secrets and
   variables ▸ Actions* als Secret `CF_API_KEY` ablegen.
4. **Spielversion festlegen** (optional). Das Interface im TOC ist `16001` –
   die Nummer des privaten Clients, die CurseForge nicht kennt. Die Pipeline
   nimmt deshalb `1.15.7`. Andere Version: als Repository-*Variable*
   `GAME_VERSION` setzen.

## Veröffentlichen

```
# Version in MP5/MP5.toc und CHANGELOG.md müssen übereinstimmen
git tag v0.1.0
git push origin v0.1.0
```

Der Tag löst `.github/workflows/release.yml` aus: Tests, Version prüfen,
zippen, zu CurseForge und an das GitHub-Release hochladen. Schlägt einer
der Schritte fehl, wird nichts veröffentlicht.

Ein Tag auf `main`, nicht auf `work` – sonst steckt im Release Arbeit, die
noch nicht gemerged ist.
