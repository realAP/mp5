# Bilder für die README

Fehlen noch. Gebraucht werden Aufnahmen aus dem Spiel, jeweils eng um das
Spielerfenster herum beschnitten (nicht der ganze Bildschirm).

| Datei | Was drauf sein soll |
|---|---|
| `01-anzeige.png` | die Anzeige im Ruhezustand: beide Stufen, Zauber-Leiste, unter dem Spielerfenster |
| `02-fsr.png` | direkt nach einem Zauber: Balken läuft, Restzeit sichtbar |
| `03-mana-aus.png` | **ohne** die Beta: `/mp5 mana off` – nur Regeneration und Stückzahlen |
| `04-mana-an.png` | **mit** der Beta: `/mp5 mana full` – dieselbe Situation, eine Zeile mehr |
| `05-tilde.png` | gerechneter Wert mit Tilde (`~847`), also bevor der Tank einmal voll war |
| `06-exakt.png` | derselbe Wert ohne Tilde, nach dem Knopf „mein Mana ist jetzt voll" |
| `07-debug.png` | `/mp5 debug` neben der eigenen Manaleiste – zum Vergleich |
| `08-optionen.png` | *Interface ▸ AddOns ▸ MP5*, Schieber und Haken |

03 und 04 sind das Paar, auf das es ankommt: gleiche Situation, gleicher
Bildausschnitt, einmal mit und einmal ohne das mitgerechnete Mana.

PNG, unskaliert aus dem Spiel. Liegen sie hier, werden sie in die README
eingebaut.

## Wenn die Bilder da sind

Dann wird in der README dieser Block eingebaut – zwei Bilder
nebeneinander, damit der Unterschied in einem Blick zu sehen ist:

```markdown
## Screenshots

| Without the computed mana | With it (beta) |
|---|---|
| ![](docs/screenshots/03-mana-aus.png) | ![](docs/screenshots/04-mana-an.png) |
```
