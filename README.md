# Reimmanence

Scholar helper for Ashita v4. Pick a skillchain element, press **Go**, and it announces the chain, uses Immanence and casts each spell, then calls the magic burst.

- **Game-state timing:** waits for the Immanence buff and for each spell to land instead of fixed timers (`/sc timing fixed` restores the old behaviour).
- **Safety stops:** stops by itself when you zone, the target dies or changes, you are put out of action, MP runs low, or Immanence / a spell does not go off.
- **GENBU II** (`/sch genbu`): This was made solely to use against Genbu 2.0 on the CatseyeXI private server. It's untested against that boss (Yet to be approved), but the option itself works. 2-spell chains for the current Vana'diel day that never use a spell, or make a skillchain, of the day's element; day-change banner, countdown, and the best burst spell you know for each element.

## Install

1. Make sure no older copy of the addon is loaded (`/addon unload reimmanence`).
2. Clone (or download and unzip) this repository into your Ashita addons folder, **in a folder named `reimmanence`**:
   ```
   cd <Ashita>\addons
   git clone https://github.com/Adamantking/reimmanence.git reimmanence
   ```
3. In game: `/addon load reimmanence`  (add it to your default script to load it on startup).

> Everything here is tested to the best of my ability, changes/fixes will be made as necessary.
> Claude was used heavily in the creation of this addon.

> Reimmanence replaces the older (discontinued and removed) *Immanence* addon and uses the same `/sch` command - unload the old one first.

## Commands

`/sch <element> [steps]`, `/sch genbu [element]`, `/sch go <n>`, `/sch stop`, `/sch tier <1-6>`, `/sch timing smart|fixed`, `/sch buff <id>`, `/sch off`, `/sch help`.

The Immanence status effect id (470) was entered from memory: if smart timing says Immanence never activated, set the right id with `/sch buff <id>`.

## Notes

This sends normal game commands (`/ja`, `/ma`, `/p`) for you. Check your server's rules on automation before using it.

Skillchain data from Ivaar's Skillchains addon.

## 2.1.0 additions
- **Aurora look** and a **font scale slider** (25-150%) at the bottom right of each window. The scale is remembered in `config\addons\reimmanence\ui.cfg`. Not tested in game.
