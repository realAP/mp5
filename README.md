# MP5

<p align="center">
  <img src="docs/logo/mp5-logo.png" alt="MP5 – five mana cartridges in a magazine" width="408">
</p>

## Overview

The mana bar tells you how much mana you have. MP5 tells you how fast it
comes back, and how many casts that is.

- Regeneration per 5 seconds, both tiers: `12 / 47` – while casting and at
  rest. Plus the five-second rule as a bar.
- Up to five spells of your choice, each with the number of times your mana
  still pays for it.
- **Beta** – if the client won't hand out your current mana, MP5 works it out
  itself: from spell costs, regeneration and the buffs that grant mana. A
  tilde (`~847`) means "at least this much"; without it the value is exact.
  This part is still under development and testing – it can be wrong. The
  button in the corner of the display sets it straight, `/mp5 debug` shows
  how it got there, `/mp5 estimate off` turns it off.

Tested on WoW Classic (interface 16001).

## Installation

1. Copy the `MP5/` folder into `Interface/AddOns/`.
2. Restart the client (or `/reload`).
3. Enable MP5 under *AddOns* on the character selection screen.

```
World of Warcraft/_classic_era_/Interface/AddOns/MP5/
```

The display starts in the middle of the screen: drag it where you want it,
then `/mp5 lock`.

## Configuration

In game under *Interface ▸ AddOns ▸ MP5* or with `/mp5 options`: the five
spell slots, sliders for width, icon size, overall size and font, checkboxes
for the rest.

| Command | Effect |
|---|---|
| `/mp5 lock` · `unlock` | pin the position / make it draggable |
| `/mp5 scale <0.5-2>` | overall size |
| `/mp5 font <8-32>` | font size, independent of the overall size |
| `/mp5 width <80-400>` | width – a minimum; the spell row may grow wider |
| `/mp5 bar off\|thin\|full` | no bar, thin 5s line, or a status bar |
| `/mp5 bardir fill\|drain` | bar fills up or drains |
| `/mp5 backdrop blizzard\|thin\|off` | frame |
| `/mp5 full on\|off` | both tiers, `12 / 47` |
| `/mp5 countdown on\|off` | remaining time under the bar |
| `/mp5 label on\|off` | the „MANA / 5“ caption (default: off) |
| `/mp5 tooltip on\|off` | breakdown on mouseover |
| `/mp5 animate on\|off` | smooth counting (default: off) |
| `/mp5 decimals 0\|1` | one decimal place |
| `/mp5 show always\|combat\|notfull` | when the display is visible |
| `/mp5 hide` · `unhide` | switch it off and on entirely |
| `/mp5 reset` | back to the defaults |

### Spell row

```
/mp5 spells on                turn the row on
/mp5 spell 1 Flash Heal       highest rank you know
/mp5 spell 2 Renew(Rank 4)    exactly this rank
/mp5 spell 3 clear            empty the slot
/mp5 spell list               show which slots are taken
/mp5 icon <16-48>             icon size
/mp5 count topright|center    where the number sits on the icon
/mp5 logo on|off              the mark on the left of the display
```

### Computed mana

```
/mp5 mana off|value|full|percent  current mana as a row in the display
/mp5 voll                     "my mana is full now" – anchors the model
/mp5 button on|off            the same button in the corner of the display
/mp5 estimate on|off|reset    turn the computation on and off
/mp5 buffs on|off             count Blessing of Wisdom / Mana Spring
```

### Diagnostics

```
/mp5 why       why the number on screen is what it is
/mp5 debug     window: what the addon thinks your mana is
/mp5 probe     what this client hands out about mana
/mp5 errors    recorded errors
```

## Release

Tag `v<version>` on `main` builds the zip and uploads it to CurseForge and
the GitHub release – see [docs/release.md](docs/release.md). Tests run on
every push: `tests/run.sh`.

## License

MIT, see [LICENSE](LICENSE).
