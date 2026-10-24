# Changelog

## 2.3.2
- The scale bar is pinned to the bottom right of the window and no longer scrolls away with the content.

## 2.3.1
- Immanence charges are drawn as glowing magic orbs (empty rings for spent charges).

## 2.3.0
- Immanence charges shown big at the top of both windows (X / max, with pips; green = enough, amber = fewer than the chain needs, red = none). Estimated from the stratagem recast like the Windower Scholar scripts, so it can be off by one if you have recharge gifts.
- The scale control only accepts numbers (typed values are clamped to 25-150).
- Not tested in game.

## 2.2.0
- Smart timing fix: the Immanence command is re-sent (up to 3 times, every 2 s) if the buff does not appear, the wait before giving up is 7 s (was 4), and the pause after a spell is 1.2 s (was 0.6).
- A failed Immanence now reports how many times it was sent, whether Light/Dark Arts is active, and your current status effect ids.
- New `/sch detect` (use Immanence by hand and it learns the right status effect id), `/sch buffs`, and the id is now remembered between sessions (`/sch buff <id>` is saved).
- Not tested in game.

## 2.1.0
- New Aurora look (aurora.lua) and a 25-150% font scale slider at the bottom right of the window (live, remembered in config\addons\reimmanence\ui.cfg). Not tested in game.

## 2.0.0
- New addon based on Immanence 1.2.
- Smart timing, safety stops, Genbu II day tracking and burst spell list.
