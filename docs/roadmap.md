# Roadmap

Milestones and issues live on GitHub; this file says what they mean and when
one is finished. Each closes on a condition that can be checked.

| | | |
|---|---|---|
| [0.1.0 – First release](../../milestone/1) | on CurseForge | #16 #17 |
| 0.2.0 – Texts | README and every explanation reworked | #21 |
| [0.3.0 – Layout](../../milestone/2) | classic styling under the player frame | #18 #19 |
| [0.4.0 – English](../../milestone/3) | every visible string from one table | #20 |

## 0.1.0 – First release

Everything the addon already does, published. The code is done and the
pipeline is built; what is left is the CurseForge account side (#16) and the
screenshots (#17).

**Done when** installing from CurseForge works on a fresh client.

## 0.2.0 – Texts

Go through every text with one question: does this tell the reader something
they need? README, tooltips, options notes, `/mp5 why`, the debug window,
chat output, code comments (#21).

**Done when** someone who has never seen the addon can tell what a number
means without asking.

## 0.3.0 – Layout

Five proposals are drawn to scale in [layout/index.html](layout/index.html);
recommended are 1 (strip) and 5 (anchor). The options panel has to be
reworked with it – it is full, the next checkbox falls off the bottom (#19).

**Done when** the display sits under the player frame in classic styling
without covering the spell icons.

**Needs from you:** a screenshot of your player frame together with MP5, and
one decision – how much height the display may have.

## 0.4.0 – English

Interface and chat output are German, the README is English. CurseForge is
international, so this is the first thing a stranger trips over.

**Done when** the addon comes up in English on an English client and in
German on a German one, with nothing left hard-coded.

## Without a milestone

**Mana model out of beta** (#22). The computed mana is the one part that can
be wrong, and only playing with it shows where. This closes when the data
says so, not on a date: over a whole dungeon run the value must stay within
10 % of maximum mana of the real bar. Then the beta markers come out.

## Not planned

Profiles, per-class presets, automation of any kind. The addon shows
numbers; that is the whole job.
