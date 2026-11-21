# MP5

<p align="center">
  <img src="docs/logo/nachladen.gif" alt="MP5 – fünf Schuss, dann nachladen" width="285">
</p>

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

Solange noch nichts gemessen wurde, dient `GetManaRegen()` als Quelle.
Die Funktion liefert Mana pro Sekunde, und zwar zwei Werte: außerhalb der
5-Sekunden-Regel und während des Zauberns. Unterscheiden sie sich, werden
beide Stufen daraus gelesen; gibt der Client zweimal denselben Wert zurück,
ist nur der gerade aktive Zustand bekannt und die andere Stufe bleibt leer,
statt geraten zu werden. Im Tooltip steht, welche Quelle gerade greift.

## Clients, die den Manawert schützen

Manche Clients geben das aktuelle Mana als *secret value* zurück – lesbar
für das Spiel, aber Addon-Code darf damit nicht rechnen. Das Addon erkennt
das beim Start und schaltet um:

| | |
|---|---|
| Messung der Mana-Ticks | entfällt |
| Zahlen | kommen aus `GetManaRegen()` |
| 5-Sekunden-Regel | läuft über `UNIT_SPELLCAST_SUCCEEDED` statt über sinkendes Mana |
| Zauber-Leiste | über den Text der Standard-Manaleiste, siehe unten |

### Das aktuelle Mana doch bekommen

Die Standard-Manaleiste zeigt den Wert als **Text** an, sobald die Statustexte
eingeschaltet sind (*Interface ▸ Statustext*) – und ein Text ist keine
geschützte Zahl. Drei Formen werden gelesen:

| Anzeige | Ergebnis |
|---|---|
| `1234 / 1435` | der Wert direkt, genau |
| `1234` | der Wert direkt, genau |
| `47%` | mit dem lesbaren Maximalmana umgerechnet, gerundet |

Stammt der Wert aus einem Prozentwert, steht vor der Stückzahl eine Tilde
(`~5`) – die Anzeige ist dann auf etwa ein Prozent des Maximalmanas genau.
Mit numerischem Statustext fällt die Tilde weg.

Gibt der Text gar nichts her, bleibt als Ersatz die Frage, ob ein Zauber
überhaupt bezahlbar ist (`IsUsableSpell`): dann wird das Icon grau, statt
eine Zahl zu zeigen.

`/mp5 probe` zeigt, was der eigene Client hergibt; das Ergebnis landet auch
in den SavedVariables. Fehler werden mit `/mp5 errors` angezeigt und in
derselben Datei mitgeschrieben.

## Wie oft reicht das Mana noch?

Unter dem Balken stehen bis zu fünf frei wählbare Zauber mit ihrem Icon und
einer Zahl: **so oft kann man diesen Zauber noch am Stück wirken.**

Beim Durchcasten läuft die 5-Sekunden-Regel permanent, es gilt also die
Regeneration *innerhalb* der Regel. Mit Mana `M`, Kosten `c`, Zauberzeit `t`
(mindestens globaler Cooldown) und Regeneration `r` pro Sekunde muss vor dem
`k`-ten Zauber gelten

```
M + r·t·(k-1) >= c·k      ->      k = 1 + (M - c) / (c - r·t)
```

`c - r·t` sind die **Nettokosten** eines Zaubers: was er kostet, abzüglich
dessen, was während seiner Zauberzeit zurückkommt. Ist dieser Wert ≤ 0,
trägt sich der Zauber selbst und es steht ∞ da.

Die Manakosten kommen über `GetSpellPowerCost` aus dem Spiel und enthalten
damit Talente und Buffs; fehlt die Funktion, wird die Zauberbeschreibung
ausgelesen. Ohne Rangangabe gilt der höchste gelernte Rang, mit Rangangabe
genau dieser – geschrieben wie im Makro:

```
/mp5 spell 1 Blitzheilung
/mp5 spell 2 Erneuern(Rang 4)
/mp5 spell 3 Machtwort: Schild
/mp5 spell list
/mp5 spell 3 clear
```

Oder in den Interface-Optionen unter *MP5* (`/mp5 options`), dort zeigt jedes
Feld direkt Kosten und Zauberzeit des erkannten Rangs an.

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
/mp5 bardir fill|drain        Balken füllt sich auf / läuft leer
/mp5 backdrop blizzard|thin|off
/mp5 label on|off             Beschriftung "MANA / 5" (Standard: aus)
/mp5 full on|off              beide Stufen "12 / 47" (hell = gilt gerade)
/mp5 countdown on|off         Restzeit unter dem Balken
/mp5 spells on|off            Zauber-Leiste
/mp5 spell <1-5> <Zauber>     Zauber auf einen Platz legen
/mp5 spell <1-5> clear        Platz leeren
/mp5 spell list               belegte Plätze zeigen
/mp5 icon <16-48>             Größe der Zauber-Icons
/mp5 count topright|center    wo die Zahl auf dem Icon sitzt
/mp5 options                  Interface-Optionen öffnen
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
| 3 – Klassisches Panel (Standard) | `backdrop blizzard`, `bar thin`, `bardir fill`, `countdown on`, `full on`, `spells on` |
| 4 – Balkenanzeige | `backdrop thin`, `bar full`, `countdown on` |
| 5 – Aufschlüsselung | `tooltip on` (beim Drüberfahren) |

Das Design-Handout liegt unter `docs/design-handout.html`.

## Logo

Sechs Entwürfe in Anlehnung an die MP5, als Mana-Waffe mit Zeitmesser:
`docs/logo/index.html` im Browser öffnen. Jeder Entwurf hat eine Einzelseite
und liegt als SVG daneben, dunkel und hell.

Das Hauptzeichen ist die Kombination aus Silhouette und Patronen: im Magazin
stecken fünf Manapatronen, eine je Sekunde, und das Trommelvisier ist das
Zifferblatt. Die Animation oben zeigt genau die 5-Sekunden-Regel – fünf Schuss,
dann wird nachgeladen und man hat wieder fünf.

Noch ist keines davon im Addon eingebaut. Neu erzeugen:

```
python3 tools/logo/gen.py docs/logo     # Entwürfe, Handout, SVG und PNG
python3 tools/logo/anim.py docs/logo    # die Animation
```

## Tests

Die Messlogik ist gegen einen API-Stub testbar, ohne das Spiel zu starten:

```
lua5.1 tests/test_core.lua      # Messung der Mana-Ticks, 5-Sekunden-Regel
lua5.1 tests/test_spells.lua    # die Zauber-Rechnung, u.a. gegen eine Simulation
lua5.1 tests/test_apiregen.lua  # GetManaRegen als Quelle bei geschütztem Mana
lua5.1 tests/test_manabar.lua   # Mana aus dem Text der Standardleiste
```
