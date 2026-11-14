# Level redesign brief: Part 3 (levels 41–90), and a look at 91–100

Steven's playtest verdict on Part 3, in his words: too often the ice just stands in for one-way tiles; most
of the map never gets touched; back-to-back easy levels, especially 40–60. "I should not be able to
regularly look at a map and solve it right away just based on its layout almost ever at this point. Like I
don't even look at the packages, because it's obvious there's only one good way to drive." Small maps are
fine, but they should be tricky and use the new mechanics in ways that change how you think about winning.

## Where it stands (measured)

`tools/level_report.gd -- --from=41 --to=100` (run it first; it takes a few minutes):

- **Every level from 41 to 90 is EASY.** The solver cracks them in 19–130 search nodes. The endgame
  (91–100) takes 480–2,200, which is the bar to aim near.
- **Mechanics that do nothing.** In 26 levels a whole mechanic family can be turned into plain road and no
  new way to win appears: roadworks in most of 69–90, ice in most of 41–54 and 76–83 (ice was moved onto
  junctions by `tools/fix_ice.gd`, but it still doesn't constrain anything, because the layout already
  forces the route).
- Coverage is mostly fine (55–90% of the road used), but the routes are forced by the layout, not by the
  packages.

## What "done" means

Run `tools/level_report.gd` over 41–100. For every level in 41–90:

1. **Not EASY:** score ≥ 9, under 6 solutions, and at least ~300 search nodes. Ramp up through each zone,
   reaching about 800–2,000 nodes by the late 80s.
2. **No two EASY levels in a row anywhere.** A breather is allowed, but never twice running, and a
   breather should still need a look at the packages.
3. **No DECOR:** every mechanic on the map changes the answer. Turning it into plain road must open up
   new solutions, or make the level unwinnable. Ice especially: each ice tile should matter on its own
   (the report's "ice idle" count is 0). Ice must not just do a one-way's job; a one-way limits direction,
   ice limits turning, so use it where turning would be the tempting move.
4. **The packages decide the route:** with the stack in a different order the layout should suggest a
   different route. A level you can solve without reading the stack fails, however many nodes it takes.
5. **Coverage** of at least 60% of the road, unless a small map uses its emptiness as the trick.
6. 1–3 solutions (one is best).

And for the whole set:

- `tools/validate_levels.gd -- --ablate` passes: everything solvable, presents reachable.
- `tools/autotest_all.sh` passes: every level won in every mode.
- 91–100 keep their size, but look at the LOW-COVER ones (91, 94, 95).
- Each zone keeps its roster (the README's Part 3 table) and its training-load shape (intro, mid-tier,
  a spike for the zone's challenge level, a cooldown), but nothing in it is trivial.

## Keep

- The level count, numbers and titles (saves and the map are keyed by level number; don't renumber).
  Retitle only if a new level really needs it, and keep the zone's theme.
- `challenge: true` on the zone spikes; presents (`gift`) only where they are now (level 94's
  `deep_field`), reachable on a winning route (the validator checks).
- Hints (`hint`) that say what's new in a level: rewrite them if the trick changes.
- Map sizes that fit a phone: about 5–7 wide and 7–10 tall in Part 3.
- The van never holds more than 12 packages at once (`LevelData.MAX_LOAD`; the validator checks).

## Tools

- `tools/generate.gd`: route-first procedural generator (street grid, random self-avoiding drive,
  stack built from the drive). Flags for size, colours, shops, gates, bridges, return, `--maxsol`,
  `--minnodes`, `--tries`. Use `--minnodes` high and `--maxsol=1`.
- `tools/twist_levels.gd`: adds ice, lockers and roadworks to generated levels, keeping them winnable.
  **Its weakness is the cause of the DECOR problem:** it accepts a twist whenever it doesn't add solutions,
  so twists that change nothing get through. Make it require that the twist *removes* solutions, or
  raises the search size a lot.
- `tools/fix_ice.gd`: moves useless ice onto junctions (already run).
- `tools/check_level.gd`, `tools/stack_orders.gd`: check one level, explore stack orders.
- `tools/level_report.gd`: the scorecard above.
- `-- --level=N` runs the game straight into a level, for a look (renders: `--write-movie`).

Level tokens (`scripts/level_data.gd`): `#` road, `S` start, `r b g y p o` houses (`r2` wants two),
`P`-style pickups and warehouses (see the README's token table), `> < ^ v` one-ways, `=`/`H` bridges,
gates, hubs, `~` ice, `w`/`wN` lockers, `cN` roadworks (open after N deliveries), `E` exit (mega parts),
`return: true` to finish at the start.

## Deliver

A branch with the new `levels/levels.json` (and `daily.json` if any dailies get the same fix), the report
before and after, and a short table: each level's trick in one line ("you must pick up blue before
the gate", "the ice at the crossroads stops the obvious left").
