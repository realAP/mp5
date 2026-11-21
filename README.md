# MP5

<p align="center">
  <img src="docs/logo/mp5-logo.png" alt="MP5 – fünf Manapatronen im Magazin" width="408">
</p>

## Overview

Als Heiler verbringt man den Kampf mit einer einzigen Frage: **reicht das
Mana noch?** Die Manaleiste des Spiels beantwortet nur die Hälfte davon. Sie
sagt, wie viel noch da ist – aber nicht, wie schnell es zurückkommt, und
schon gar nicht, wie viele Zauber das noch ergibt. Ob der Segen der Weisheit
noch läuft, ob das Essen noch wirkt, ob der Geist-Buff eben abgelaufen ist:
all das verändert die Regeneration erheblich, und man merkt es erst, wenn das
Mana plötzlich schneller weg ist als gedacht.

MP5 beantwortet die andere Hälfte. Es misst mit, wie viel Mana pro fünf
Sekunden wirklich zurückkommt, und rechnet daraus aus, wie oft deine Zauber
davon noch bezahlt werden können.

### Was auf der Anzeige steht

```
        MP5
     12 / 47          ← Regeneration: im Kampf / in Ruhe
   ~ 847 / 1435       ← aktuelles Mana (abschaltbar)
  ▬▬▬▬▬▬▬▬▬▬▬         ← die 5-Sekunden-Regel
       2.4s           ← bis die Regeneration wieder anspringt
   [ 8 ] [ 5 ] [ 3 ]  ← so oft reichen diese Zauber noch
```

**Die zwei Zahlen oben** sind die beiden Stufen der Regeneration. Links, was
du gerade bekommst, solange du zauberst; rechts, was du bekämst, wenn du fünf
Sekunden die Hände still hältst. Die gerade gültige Zahl steht hell, die
andere gedämpft. Steht links eine `0`, kommt im Moment nichts nach – dann ist
der Unterschied zwischen „weiterheilen" und „einmal durchatmen" genau diese
zweite Zahl.

**Der Balken** ist die Fünf-Sekunden-Regel: nach jedem Zauber steht die
Regeneration kurz, und erst wenn der Balken durchgelaufen ist, geht es wieder
los. Die Zahl darunter sagt, wie lange noch. Wer ein Mana-Tick mitnehmen
will, bevor er den nächsten Zauber anfängt, schaut hierauf.

**Die Icons** sind bis zu fünf Zauber deiner Wahl, und die Zahl darauf ist
die Antwort auf die Frage von oben: so oft kannst du diesen Zauber mit dem
Mana, das du jetzt hast, noch wirken. Dabei ist mitgerechnet, dass während
des Zauberns ja auch Mana nachkommt – ein Zauber, der langsamer ist als deine
Regeneration teuer, steht deshalb auf `∞`.

### Gemessen, nicht geschätzt

Die meisten Mana-Anzeigen bauen die Blizzard-Formel nach: Geist, Stufe,
Klasse, dazu ein paar bekannte Buffs. Das geht gut, solange man alle
Sonderfälle kennt – und daneben, sobald einer dabei ist, den die Formel nicht
kennt.

MP5 rechnet nichts nach. Es schaut zu, wie sich dein Mana zwischen zwei
Ticks tatsächlich ändert, und zeigt das an. Segen der Weisheit, Nahrung,
Manasteine, Items mit „Mana pro 5 Sek.", Volksfähigkeiten, der Trank, den du
gerade getrunken hast: alles automatisch enthalten, weil es im gemessenen
Wert ohnehin schon drin steckt. Steht dort eine `0`, dann regeneriert
wirklich nichts.

### Wenn der Client das Mana nicht verrät

Manche Clients geben Addons den aktuellen Manawert nicht heraus – er ist
geschützt. MP5 gibt dann nicht auf, sondern führt selbst Buch: Es kennt dein
Maximum, es sieht jeden Zauber, den du wirkst, und es kennt die Kosten. Also
zieht es ab, was du ausgibst, und addiert, was nachkommt.

Wichtig ist dabei nicht nur *wie viel*, sondern *wann*: Mana kommt nicht
gleichmäßig, sondern in Sprüngen – alle zwei Sekunden ein Tick, während der
5-Sekunden-Regel keiner. Wer die Regeneration gleichmäßig hochrechnet,
bekommt vielleicht die Summe hin, läuft dem echten Wert aber ständig voraus
und hinterher. MP5 schreibt das Mana deshalb genau dann gut, wenn das Spiel
es gutschreibt: *dass* sich das Mana geändert hat, ist nämlich kein
geschützter Wert, nur der Betrag ist es. Und gutgeschrieben wird immer der
Tick davor – der liegt sicher in der Vergangenheit. Im Debug-Fenster steht
unter „Zufuhr", ob es im Takt läuft.

Diese Rechnung ist absichtlich vorsichtig: sie zählt nur, was sie sicher
weiß, und liegt deshalb nie zu hoch – eher zu niedrig. Genau das zeigt die
**Tilde** an: `~847` heißt „mindestens so viel", `847` ohne Tilde heißt
„genau so viel". Sobald das Addon einen festen Punkt hat – weil du lange
genug nichts getan hast und der Tank voll sein muss, oder weil du es ihm mit
dem Knopf in der Ecke gesagt hast – verschwindet die Tilde und die Zahlen
sind exakt.

### Mana, das in keiner Formel steht

Eine Falle, die vor allem in der Gruppeninstanz zuschnappt: **Segen der
Weisheit** und die **Manaquelle** des Schamanen tauchen in der
Regenerationsauskunft des Spiels überhaupt nicht auf. Sie sind keine
Regeneration im Sinne des Spiels, sondern periodische Effekte, die alle paar
Sekunden einen festen Betrag gutschreiben – und sie ticken auch *während*
der 5-Sekunden-Regel weiter.

Das fällt solo nicht auf, weil man diese Buffs dort nicht hat. In der Gruppe
wäre es der größte Posten überhaupt: wer durchheilt, bekommt vom Spiel die
Auskunft „es kommt nichts nach“, während in Wirklichkeit ständig Mana
eintrifft. MP5 liest deshalb die Buffs mit – welche Buffs auf einem liegen,
ist nicht geschützt – und rechnet ihren Betrag dazu. `/mp5 why` zeigt, was
davon erkannt wurde; `/mp5 buffs off` schaltet es ab, falls dein Client sie
doch mitzählt.

Unregelmäßiges bleibt draußen: Richturteil der Weisheit, Tränke, Manasteine,
Innervieren. Dafür gibt es den Knopf.

Du kannst dem Addon also jederzeit mit einem Klick sagen: *mein Mana ist
jetzt voll.* Und wenn dich interessiert, wie es zu seiner Zahl kommt, zeigt
`/mp5 debug` ein Fenster mit dem ganzen Gedankengang.

### Noch dazu

- **Frei platzierbar und skalierbar**, alle Einstellungen pro Charakter.
- **Reine Anzeige** über die offiziellen Blizzard-Schnittstellen, keine
  Automatisierung. Die laufende Aktualisierung läuft nur in den fünf Sekunden
  nach einem Zauber, sonst schläft das Addon.

Getestet auf WoW Classic (Interface 16001).

## Installation

1. Den Ordner `MP5/` nach `Interface/AddOns/` kopieren.
2. Den Spielclient neu starten (oder `/reload`).
3. MP5 im Charakterauswahl-Bildschirm unter *AddOns* aktivieren.

Der Pfad sieht je nach Installation so aus:

```
World of Warcraft/_classic_era_/Interface/AddOns/MP5/
```

## Die ersten fünf Minuten

Beim ersten Start erscheint die Anzeige in der Bildschirmmitte – noch leer,
denn sie weiß nichts über dich. Drei Dinge lohnen sich gleich:

1. **Hinschieben, wo du im Kampf sowieso hinschaust.** Mit der Maus
   verschieben, dann `/mp5 lock`, damit sie dort bleibt. Bewährt hat sich
   direkt unter dem Spielerfenster, bei der Manaleiste.
2. **Deine Zauber eintragen.** `/mp5 options` öffnen und in die fünf Felder
   die Zauber schreiben, die dein Mana verbrauchen – bei einem Priester etwa
   Blitzheilung, Große Heilung, Erneuern. Jedes Feld zeigt sofort, welche
   Kosten und Zauberzeit es erkannt hat; steht dort nichts, ist der Name
   falsch geschrieben.
3. **Einmal volltanken.** Setz dich hin, trink, und wenn die Manaleiste voll
   ist, klick den Knopf in der Ecke der Anzeige. Ab da weiß das Addon, wo es
   steht – falls dein Client das Mana nicht herausgibt.

Dann einmal in einen Kampf. Nach dem ersten Zauber füllen sich die Zahlen.

## Configuration

Alles lässt sich im Spiel einstellen, unter *Interface ▸ AddOns ▸ MP5* oder
mit `/mp5 options`: die fünf Zauberplätze, Schieber für Breite, Icon-Größe,
Gesamtgröße und Schrift, und Haken für alles, was man ein- und ausschalten
kann – Balken, Restzeit, beide Stufen, Manazeile, Logo und das Mitrechnen.

Wer lieber tippt, kommt mit Chatbefehlen an dieselben Schalter:

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

Die Leiste mit den Icons und den Stückzahlen. Reihenfolge und Ränge bestimmst
du: `Blitzheilung` nimmt immer den höchsten gelernten Rang mit, `Erneuern(Rang
4)` genau diesen – praktisch, wenn du einen günstigeren Rang bewusst spielst.

```
/mp5 spells on                Leiste einschalten
/mp5 spell 1 Blitzheilung     höchster gelernter Rang
/mp5 spell 2 Erneuern(Rang 4) genau dieser Rang
/mp5 spell 3 clear            Platz leeren
/mp5 spell list               belegte Plätze zeigen
/mp5 icon <16-48>             Icon-Größe
/mp5 count topright|center    wo die Zahl auf dem Icon sitzt
/mp5 estimate on|off|reset    Mana mitrechnen, wenn der Client es schützt
/mp5 logo on|off              das Zeichen links in der Anzeige
/mp5 buffs on|off             Segen der Weisheit / Manaquelle mitrechnen
/mp5 voll                     „mein Mana ist jetzt voll“ – setzt das Modell
/mp5 button on|off            Knopf „Mana ist voll“ in der Ecke der Anzeige
/mp5 mana off|value|full|percent  aktuelles Mana als Zeile in der Anzeige
/mp5 debug                    Fenster: was denkt das Addon gerade?
```

### Diagnose

Wenn eine Zahl nicht plausibel aussieht, musst du nicht raten. Diese Befehle
fragen das Addon, wie es darauf gekommen ist – und sie zeigen auch, was dein
Client überhaupt hergibt, denn das ist von Client zu Client verschieden.

```
/mp5 probe     was der eigene Client an Mana-Daten hergibt
/mp5 why       warum gerade welche Zahl angezeigt wird
/mp5 voll      dem Modell sagen, dass das Mana gerade voll ist
/mp5 debug     Fenster mit dem gerechneten Mana und den letzten Ereignissen
/mp5 errors    mitgeschriebene Fehler
```

## Layout

Fünf Entwürfe, wie die Anzeige unter dem Spielerfenster sitzen kann, mit
maßstäblichen Vorschauen: `docs/layout/index.html` im Browser öffnen.

## Logo

Das Hauptzeichen: im Magazin stecken fünf Manapatronen – eine je Sekunde der
Regel – und das Trommelvisier ist das Zifferblatt. Die Entwürfe liegen als
Handout in `docs/logo/index.html`, jedes Zeichen als SVG (dunkel und hell)
und als PNG daneben.

Im Spiel steckt es in `MP5/Textures/` als TGA – das einzige Bildformat neben
BLP, das WoW lädt. `logo.tga` (128×64) steht über den Interface-Optionen,
`icon.tga` (64×64, das Trommelvisier) ist das Symbol in der AddOn-Liste und
lässt sich mit `/mp5 logo on` links in die Anzeige holen. `refill.tga` ist der
Pfeil auf dem Knopf „Mana ist voll“.

## Tests

Die Messlogik läuft gegen einen API-Stub, ohne das Spiel zu starten:

```
lua5.1 tests/test_core.lua      # Messung der Mana-Ticks, 5-Sekunden-Regel
lua5.1 tests/test_auras.lua     # Mana aus Segen der Weisheit und Manaquelle
lua5.1 tests/test_ticks.lua     # Gutschrift im Takt des Spiels, gegen eine Simulation
lua5.1 tests/test_spells.lua    # die Zauber-Rechnung, gegen eine Simulation
lua5.1 tests/test_apiregen.lua  # GetManaRegen als Quelle
lua5.1 tests/test_manabar.lua   # Mana aus dem Text der Standardleiste
lua5.1 tests/test_estimate.lua  # das Mana-Modell, gegen eine Simulation
lua5.1 tests/test_tainted.lua   # geschützte Werte im Kampf
lua5.1 tests/test_options.lua   # das Optionen-Panel
lua5.1 tests/test_ui.lua        # Anzeige, Knopf und Debug-Fenster
lua5.1 tests/test_slash.lua     # alle Chatbefehle
```

## Lizenz

MIT, siehe [LICENSE](LICENSE).
