# MP5

Zeigt die **tatsächliche** Mana-Regeneration pro 5 Sekunden in WoW Classic –
inklusive 5-Sekunden-Regel, Segen der Weisheit, Nahrung, Items und
Volksfähigkeiten. Steht dort 0, regeneriert gerade nichts.

## Installation

Ordner `MP5/` nach `Interface/AddOns/` kopieren.

## Wie der Wert zustande kommt

Die Anzeige **misst** die echten Mana-Ticks des Spielers, statt eine Formel
nachzubilden. Ein Zuwachs gilt nur dann als Regenerations-Tick, wenn zwei
gleich große Zuwächse im Abstand von ~2 Sekunden auftreten – Tränke,
Evokation oder Aderlass fallen damit heraus. Zwei Werte werden getrennt
geführt:

| Zustand | Enthält |
|---|---|
| innerhalb der 5-Sekunden-Regel | nur MP5-Effekte (Segen der Weisheit, Nahrung, Items, Volksfähigkeit) |
| außerhalb | zusätzlich die Geist-Regeneration |

Solange noch nichts gemessen wurde, dient `GetManaRegen()` als Überbrückung.
Diese API liefert in Classic für beide Rückgabewerte denselben Wert (immer
den des aktuellen Zustands) und ist bei Buffs nicht verlässlich – deshalb
hat die Messung Vorrang. Im Tooltip steht, welche Quelle gerade greift.

## Performance

Ereignisgesteuert. Der `OnUpdate` läuft ausschließlich während der 5 Sekunden
nach einem Zauber (und währenddessen auf 10 Aktualisierungen/Sekunde
gedrosselt) und schaltet sich danach selbst ab. Im Leerlauf passiert nichts.

Es werden ausschließlich offizielle Blizzard-Schnittstellen benutzt. Reine
Anzeige, keine Automatisierung.

## Einstellungen

Alles über `/mp5`:

```
/mp5 lock | unlock            Position fixieren / verschiebbar machen
/mp5 scale <0.5-2>            Gesamtgröße
/mp5 font <8-32>              Schriftgröße (unabhängig von der Größe)
/mp5 width <80-400>           Breite
/mp5 bar off|thin|full        kein Balken | dünner 5s-Strich | Statusbar
/mp5 backdrop blizzard|thin|off
/mp5 label on|off             Beschriftung "MANA / 5"
/mp5 full on|off              beide Stufen "12 / 47" (hell = gilt gerade)
/mp5 countdown on|off         Restzeit als Zahl im Balken
/mp5 tooltip on|off           Aufschlüsselung beim Drüberfahren
/mp5 animate on|off           weiches Hochzählen (Standard: aus)
/mp5 decimals 0|1
/mp5 show always|combat|notfull
/mp5 hide | /mp5 unhide
/mp5 reset
```

Position, Größe und Optionen werden pro Charakter gespeichert.

### Die Entwürfe aus dem Handout

| Entwurf | Einstellung |
|---|---|
| 1 – Nackte Zahl | `backdrop off`, `bar off`, `label off`, `full off` |
| 2 – Jetzt / Danach | `backdrop off`, `bar off`, `full on` |
| 3 – Klassisches Panel (Standard) | `backdrop blizzard`, `bar thin`, `countdown on`, `full on` |
| 4 – Balkenanzeige | `backdrop thin`, `bar full`, `countdown on` |
| 5 – Aufschlüsselung | `tooltip on` (beim Drüberfahren) |

Das Design-Handout liegt unter `docs/design-handout.html`.

## Tests

Die Messlogik ist gegen einen API-Stub testbar, ohne das Spiel zu starten:

```
lua5.1 tests/test_core.lua
```
