# Roadmap

Four milestones. Each one closes on a condition that can be checked, not on
a feeling – so it is clear when the next one starts.

## 0.1.0 – First release

Everything the addon already does, on CurseForge.

**Done when** the zip is on CurseForge, the project page has the two
comparison screenshots, and installing it from there works on a fresh
client.

**Open, and only you can do it:** create the project, put its id in the TOC,
set `CF_API_KEY`, take the screenshots. See [release.md](release.md).

## 0.2.0 – Mana model out of beta

The computed mana is the one part that can be wrong, and the only way to
find out is to play with it. This milestone is measurement, then repair –
not new features.

- calibrate the buff table: are the ranks and ids in `MP5/Auras.lua` right?
  `/mp5 why` prints what it recognised
- list buffs it does *not* recognise, so the gaps are visible instead of
  silent
- account for what arrives in lumps: mana potions, mana stones, Innervate,
  Judgement of Wisdom (all seen as casts, all with known amounts)
- drop the beta markers in options, tooltip, debug window, TOC and README

**Done when** over a whole dungeon run the computed value never deviates
from the real mana bar by more than 10 % of maximum mana, and the display
says "exact" only when it is.

**Needs from you:** play a few dungeons with `/mp5 debug` open next to your
mana bar, and tell me where it drifts.

## 0.3.0 – Layout

Five proposals are drawn to scale in [layout/index.html](layout/index.html);
recommended are 1 (strip) and 5 (anchor). Implementing one means the
options panel needs rework too – it is full, and the next checkbox falls off
the bottom.

**Done when** the display sits under the player frame in classic styling
without covering the spell icons, and the options panel scrolls.

**Needs from you:** a screenshot of your player frame together with MP5, and
one decision – how much height the display may have.

## 0.4.0 – English

The interface and the chat output are German, the README is English.
CurseForge is international, so this is the first thing a stranger trips
over.

**Done when** every string the player sees comes from one table, English by
default, German still available.

## Not planned

Profiles, per-class presets, automation of any kind. The addon shows
numbers; that is the whole job.
