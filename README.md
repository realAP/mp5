# MP5

<p align="center">
  <img src="docs/logo/mp5-logo.png" alt="MP5 – fünf Manapatronen im Magazin" width="408">
</p>

## Overview

Die Manaleiste sagt, wie viel Mana da ist. MP5 sagt, wie schnell es
zurückkommt und wie viele Zauber das noch sind.

- Regeneration pro 5 Sekunden, in beiden Stufen: `12 / 47` – beim Zaubern und
  in Ruhe. Dazu die 5-Sekunden-Regel als Balken.
- Bis zu fünf eigene Zauber mit der Zahl, wie oft das Mana dafür noch reicht.
- Gibt der Client das aktuelle Mana nicht heraus, rechnet MP5 es selbst mit –
  aus Kosten, Regeneration und den Buffs, die Mana geben. Eine Tilde (`~847`)
  heißt „mindestens so viel", ohne Tilde ist der Wert exakt.

Getestet auf WoW Classic (Interface 16001).

## Installation

1. Den Ordner `MP5/` nach `Interface/AddOns/` kopieren.
2. Den Spielclient neu starten (oder `/reload`).
3. MP5 im Charakterauswahl-Bildschirm unter *AddOns* aktivieren.

```
World of Warcraft/_classic_era_/Interface/AddOns/MP5/
```

Die Anzeige erscheint in der Bildschirmmitte: mit der Maus verschieben, dann
`/mp5 lock`.

## Configuration

Im Spiel unter *Interface ▸ AddOns ▸ MP5* oder mit `/mp5 options`: die fünf
Zauberplätze, Schieber für Breite, Icon-Größe, Gesamtgröße und Schrift, Haken
für den Rest.

| Befehl | Wirkung |
|---|---|
| `/mp5 lock` · `unlock` | Position fixieren / verschiebbar machen |
| `/mp5 scale <0.5-2>` | Gesamtgröße |
| `/mp5 font <8-32>` | Schriftgröße, unabhängig von der Gesamtgröße |
| `/mp5 width <80-400>` | Breite – Mindestbreite, die Zauber-Reihe darf breiter werden |
| `/mp5 bar off\|thin\|full` | kein Balken, dünner 5s-Strich oder Statusbar |
| `/mp5 bardir fill\|drain` | Balken füllt sich auf oder läuft leer |
| `/mp5 backdrop blizzard\|thin\|off` | Rahmen |
| `/mp5 full on\|off` | beide Stufen `12 / 47` |
| `/mp5 countdown on\|off` | Restzeit unter dem Balken |
| `/mp5 label on\|off` | Beschriftung „MANA / 5“ (Standard: aus) |
| `/mp5 tooltip on\|off` | Aufschlüsselung beim Drüberfahren |
| `/mp5 animate on\|off` | weiches Hochzählen (Standard: aus) |
| `/mp5 decimals 0\|1` | Nachkommastelle |
| `/mp5 show always\|combat\|notfull` | wann die Anzeige sichtbar ist |
| `/mp5 hide` · `unhide` | ganz aus- und einschalten |
| `/mp5 reset` | zurück auf die Standardwerte |

### Zauber-Leiste

```
/mp5 spells on                Leiste einschalten
/mp5 spell 1 Blitzheilung     höchster gelernter Rang
/mp5 spell 2 Erneuern(Rang 4) genau dieser Rang
/mp5 spell 3 clear            Platz leeren
/mp5 spell list               belegte Plätze zeigen
/mp5 icon <16-48>             Icon-Größe
/mp5 count topright|center    wo die Zahl auf dem Icon sitzt
/mp5 logo on|off              das Zeichen links in der Anzeige
```

### Mitgerechnetes Mana

```
/mp5 mana off|value|full|percent  aktuelles Mana als Zeile in der Anzeige
/mp5 voll                     „mein Mana ist jetzt voll“ – setzt das Modell
/mp5 button on|off            derselbe Knopf in der Ecke der Anzeige
/mp5 estimate on|off|reset    Mitrechnen ein- und ausschalten
/mp5 buffs on|off             Segen der Weisheit / Manaquelle mitrechnen
```

### Diagnose

```
/mp5 why       warum gerade welche Zahl angezeigt wird
/mp5 debug     Fenster: was denkt das Addon über den Manazustand?
/mp5 probe     was dieser Client an Mana-Daten hergibt
/mp5 errors    mitgeschriebene Fehler
```

## Lizenz

MIT, siehe [LICENSE](LICENSE).
