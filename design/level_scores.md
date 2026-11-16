# Level scores

Written by `tools/engine/review.py` from `build/lm score`. What the numbers mean is in `design/level_engine.md`.
They come from a model of a player, not from players: use them to compare levels with each other.

## Before and after

Medians. **Partial plans**: what an experienced player has to hold in their head. **Wrong plans**: how many they'd work
through before the answer. **First plan**: how often the first idea is right. **Drives**: failed drives for the player
the level is scored for (someone who has to drive it to find out).

| Levels | OG 100: answers | partial plans | wrong plans | first plan | drives | Now: answers | partial plans | wrong plans | first plan | drives |
|---|---|---|---|---|---|---|---|---|---|---|
| 5–20 | 1 | 8 | 0.6 | 38% | 1.2 | 1 | 16 | 1.8 | 14% | 2.8 |
| 21–40 | 1 | 16 | 1.8 | 25% | 2.9 | 1 | 44 | 4.5 | 4% | 8.1 |
| 41–68 | 1 | 11 | 0.8 | 39% | 0.8 | 1 | 48 | 5.1 | 4% | 7.2 |
| 69–90 | 1 | 13 | 1.2 | 27% | 0.9 | 1 | 57 | 6.6 | 3% | 8.7 |
| 91–100 | 1 | 196 | 11.8 | 2% | 19.5 | 1 | 256 | 15.5 | 0% | 23.8 |

## By zone

| Zone | Levels | Difficulty | Devious | Complexity | Fun | Flavours |
|---|---|---|---|---|---|---|
| The Suburbs | 1–20 | 2.5 | 2.5 | 3.5 | 5.2 | intro, decoy, breather, twodoor, melter, longcon, knot, gauntlet |
| The City | 21–40 | 4.7 | 4.4 | 4.6 | 7.5 | intro, restock, melter, decoy, twodoor, gauntlet, longcon, sorter, twin |
| Frostbite Pass | 41–47 | 5.0 | 4.4 | 5.3 | 6.8 | intro, decoy, twodoor, melter, breather, longcon |
| Harbour Lights | 48–54 | 5.5 | 5.1 | 4.9 | 7.5 | restock, twodoor, melter, longcon, knot, breather |
| Neon Alley | 55–61 | 5.4 | 5.1 | 4.6 | 8.0 | intro, dump, melter, gauntlet, twodoor, breather |
| Orchard Hills | 62–68 | 5.5 | 4.9 | 5.3 | 8.1 | decoy, melter, twin, restock, dump, knot |
| Detour City | 69–75 | 5.8 | 5.3 | 5.0 | 7.1 | intro, longcon, melter, sorter, gauntlet, breather, twodoor |
| Thunder Mesa | 76–83 | 6.0 | 5.3 | 5.4 | 8.0 | decoy, dump, melter, twodoor, breather, longcon |
| Skyline Summit | 84–90 | 6.1 | 5.3 | 5.5 | 7.8 | restock, longcon, hoard, twodoor, melter, twin, gauntlet |
| The Long Haul | 91–95 | 8.9 | 7.1 | 6.6 | 8.8 | decoy, longcon, melter, sorter, gauntlet |
| Death Valley | 96–100 | 9.0 | 6.2 | 8.1 | 7.4 | hoard, gauntlet, twodoor, sorter |

## Series checks

Nothing flagged: every level within reach of its planned difficulty, none a wall for its player, none where the first idea is right more than half the time, a spike at least every 8 levels, and nothing costly for the game's solver.

## Every level

Drives are failed drives for a new player / a regular / an expert who each have to drive it to find out.
Doors: houses with a single door, of all houses. ★ is a hazard-tape challenge level; ◆ a mind-melter.

| # | Title | Tier | Kind | Answers | Partial plans | Wrong plans | First plan | Drives (new / regular / expert) | Doors | Packages | Difficulty | Devious | Complexity | Fun | Melt |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Drop | tutorial | intro | 1 | 2 | 0.0 | 100% | 0.0 / 0.0 / 0.0 | 1 of 1 | 1 | 0.0 | 0.0 | 1.0 | 1.4 | 0.0 |
| 2 | Top Goes First | tutorial | intro | 1 | 3 | 0.0 | 100% | 0.0 / 0.0 / 0.0 | 2 of 2 | 2 | 0.0 | 0.0 | 1.0 | 1.4 | 0.0 |
| 3 | Burning Rubber | tutorial | intro | 1 | 3 | 0.0 | 100% | 0.1 / 0.0 / 0.0 | 2 of 2 | 2 | 0.0 | 0.0 | 1.6 | 1.4 | 0.0 |
| 4 | One Pass | tutorial | intro | 1 | 4 | 0.0 | 100% | 0.1 / 0.0 / 0.0 | 2 of 3 | 3 | 0.0 | 0.0 | 2.1 | 1.3 | 0.0 |
| 5 | Rush Hour ★ | easy | decoy | 2 | 11 | 1.1 | 28% | 1.3 / 1.3 / 1.3 | 1 of 4 | 4 | 1.6 | 1.8 | 2.4 | 5.2 | 0.0 |
| 6 | Side Streets | easy | breather | 2 | 9 | 1.6 | 14% | 2.1 / 2.1 / 2.1 | 0 of 4 | 4 | 2.2 | 2.4 | 2.7 | 4.9 | 0.0 |
| 7 | Double Order | easy | intro | 2 | 7 | 0.5 | 50% | 1.5 / 1.5 / 1.5 | 0 of 4 | 7 | 0.7 | 0.8 | 3.6 | 4.3 | 0.0 |
| 8 | Bulk Buyer | medium | twodoor | 1 | 16 | 1.8 | 13% | 2.9 / 2.9 / 2.9 | 1 of 5 | 6 | 2.4 | 2.4 | 4.0 | 5.8 | 0.0 |
| 9 | One Way | easy | intro | 2 | 11 | 1.3 | 25% | 1.7 / 1.7 / 1.5 | 1 of 4 | 4 | 1.8 | 1.9 | 3.1 | 6.2 | 0.0 |
| 10 | Second Thoughts ◆ | melter | melter | 1 | 30 | 2.8 | 6% | 4.6 / 4.5 / 2.8 | 2 of 6 | 6 | 3.5 | 3.5 | 4.2 | 7.4 | 0.0 |
| 11 | Downtown | medium | longcon | 1 | 16 | 1.6 | 22% | 2.7 / 2.7 / 2.2 | 0 of 5 | 6 | 2.1 | 2.0 | 4.6 | 5.1 | 0.0 |
| 12 | Long Haul | medium | knot | 1 | 16 | 2.3 | 14% | 2.8 / 2.6 / 2.6 | 1 of 5 | 5 | 2.9 | 3.1 | 3.4 | 4.8 | 0.0 |
| 13 | Overpass | easy | intro | 1 | 8 | 1.5 | 16% | 2.1 / 1.8 / 1.6 | 2 of 4 | 4 | 2.0 | 2.1 | 3.4 | 5.3 | 0.0 |
| 14 | Flyover ★ | hard | gauntlet | 1 | 45 | 5.6 | 1% | 8.2 / 7.8 / 7.5 | 0 of 8 | 8 | 5.8 | 5.3 | 5.0 | 8.2 | 4.3 |
| 15 | Spaghetti Junction | easy | breather | 2 | 15 | 1.7 | 19% | 2.6 / 2.2 / 2.2 | 1 of 5 | 5 | 2.4 | 2.3 | 4.3 | 5.5 | 0.0 |
| 16 | Suburbs | medium | decoy | 1 | 25 | 3.5 | 6% | 4.6 / 4.6 / 4.4 | 1 of 6 | 10 | 4.1 | 3.9 | 4.7 | 7.2 | 0.5 |
| 17 | Rainbow Row ◆ | melter | melter | 1 | 41 | 6.2 | 3% | 10.6 / 9.7 / 9.5 | 0 of 7 | 7 | 6.2 | 5.9 | 4.5 | 8.4 | 4.8 |
| 18 | Crosstown | medium | twodoor | 1 | 25 | 3.8 | 3% | 4.7 / 4.7 / 4.7 | 1 of 6 | 10 | 4.5 | 4.2 | 4.9 | 6.8 | 1.2 |
| 19 | Gridlock | easy | decoy | 2 | 16 | 1.8 | 15% | 2.0 / 2.0 / 2.0 | 1 of 5 | 5 | 2.4 | 2.6 | 3.1 | 5.6 | 0.0 |
| 20 | Last Mile ★ | hard | knot | 1 | 46 | 5.6 | 2% | 12.4 / 10.8 / 9.0 | 0 of 8 | 10 | 5.8 | 5.2 | 5.4 | 8.2 | 3.7 |
| 21 | Return to Sender | easy | intro | 2 | 13 | 1.8 | 19% | 2.2 / 1.8 / 1.5 | 1 of 4 | 4 | 2.4 | 2.6 | 3.2 | 6.5 | 0.0 |
| 22 | Pick Up, Drop Off | medium | restock | 1 | 47 | 5.5 | 3% | 9.9 / 8.9 / 8.8 | 1 of 7 | 7 | 5.7 | 5.3 | 4.9 | 8.2 | 3.9 |
| 23 | Corner Shops ◆ | melter | melter | 1 | 53 | 6.7 | 1% | 8.8 / 8.3 / 8.3 | 1 of 7 | 7 | 6.5 | 6.0 | 5.0 | 8.4 | 6.2 |
| 24 | High Street | easy | decoy | 1 | 19 | 2.3 | 8% | 3.5 / 3.5 / 3.2 | 0 of 4 | 4 | 3.0 | 3.0 | 4.0 | 7.2 | 0.0 |
| 25 | Checkpoint | easy | intro | 2 | 11 | 1.2 | 36% | 1.6 / 1.6 / 1.4 | 2 of 4 | 4 | 1.6 | 1.8 | 2.9 | 5.6 | 0.0 |
| 26 | Toll Road | medium | twodoor | 1 | 44 | 5.3 | 4% | 8.1 / 7.3 / 7.1 | 2 of 7 | 7 | 5.6 | 5.3 | 4.5 | 7.9 | 2.9 |
| 27 | Key Delivery | medium | restock | 1 | 40 | 4.4 | 4% | 8.2 / 8.1 / 7.5 | 2 of 7 | 7 | 4.9 | 4.4 | 5.2 | 7.9 | 1.6 |
| 28 | Border Control ★ | hard | gauntlet | 1 | 80 | 8.1 | 0% | 11.7 / 11.3 / 11.0 | 0 of 8 | 11 | 7.1 | 5.9 | 6.4 | 7.9 | 3.9 |
| 29 | Clocking Off | easy | intro | 1 | 11 | 1.4 | 19% | 2.0 / 2.0 / 2.0 | 0 of 4 | 4 | 2.0 | 2.1 | 3.5 | 5.3 | 0.0 |
| 30 | Round Trip | easy | twodoor | 1 | 16 | 2.6 | 7% | 3.6 / 3.0 / 3.0 | 1 of 5 | 5 | 3.3 | 3.4 | 3.7 | 7.0 | 0.0 |
| 31 | Overtime ◆ | melter | melter | 1 | 58 | 6.1 | 2% | 12.6 / 12.4 / 12.4 | 0 of 6 | 6 | 6.1 | 5.6 | 5.1 | 8.8 | 4.7 |
| 32 | Night Shift ★ | hard | longcon | 1 | 88 | 9.6 | 1% | 15.2 / 15.2 / 14.1 | 0 of 8 | 8 | 7.7 | 6.9 | 5.5 | 8.7 | 8.1 |
| 33 | Turntable | easy | intro | 1 | 12 | 1.1 | 31% | 2.6 / 2.6 / 2.2 | 1 of 4 | 4 | 1.5 | 1.6 | 3.5 | 5.0 | 0.0 |
| 34 | Mix-Up | medium | sorter | 1 | 39 | 3.8 | 2% | 6.9 / 6.7 / 5.7 | 0 of 7 | 7 | 4.4 | 4.2 | 4.8 | 7.7 | 1.3 |
| 35 | Shuffle | medium | twodoor | 1 | 41 | 4.5 | 4% | 8.5 / 8.5 / 8.4 | 1 of 6 | 6 | 5.0 | 4.6 | 5.2 | 7.9 | 2.0 |
| 36 | Sorting Office ★ | hard | sorter | 1 | 81 | 7.6 | 2% | 12.3 / 11.4 / 10.8 | 1 of 8 | 8 | 6.9 | 6.4 | 5.0 | 8.5 | 7.6 |
| 37 | Rush Order | easy | decoy | 1 | 16 | 2.0 | 12% | 4.2 / 3.9 / 3.9 | 1 of 4 | 4 | 2.7 | 2.6 | 4.2 | 6.5 | 0.0 |
| 38 | Mixed Bag | medium | twin | 2 | 45 | 4.2 | 10% | 5.2 / 5.2 / 4.9 | 1 of 7 | 7 | 4.8 | 4.4 | 5.1 | 7.3 | 0.2 |
| 39 | Black Friday ◆ | melter | melter | 1 | 62 | 6.1 | 1% | 9.1 / 8.4 / 8.4 | 0 of 7 | 7 | 6.1 | 5.6 | 5.0 | 8.3 | 5.2 |
| 40 | Christmas Eve | hard | gauntlet | 1 | 91 | 7.8 | 1% | 16.6 / 16.4 / 16.2 | 1 of 8 | 8 | 7.0 | 5.9 | 6.1 | 8.4 | 4.6 |
| 41 | First Frost | easy | intro | 2 | 11 | 1.5 | 21% | 3.7 / 3.5 / 3.0 | 0 of 4 | 4 | 2.1 | 2.1 | 3.8 | 5.8 | 0.0 |
| 42 | Black Ice | easy | decoy | 2 | 22 | 3.3 | 2% | 3.8 / 3.8 / 3.0 | 0 of 5 | 8 | 4.0 | 3.5 | 5.6 | 6.5 | 0.2 |
| 43 | Snowplough | medium | twodoor | 1 | 51 | 6.1 | 5% | 6.6 / 6.5 / 4.4 | 1 of 7 | 8 | 6.1 | 5.3 | 5.8 | 7.2 | 2.4 |
| 44 | Avalanche ◆ | melter | melter | 1 | 70 | 7.0 | 6% | 9.2 / 8.5 / 8.5 | 0 of 7 | 7 | 6.6 | 6.0 | 5.3 | 8.1 | 3.7 |
| 45 | Hot Chocolate | easy | breather | 2 | 23 | 2.5 | 6% | 3.9 / 3.7 / 3.4 | 0 of 5 | 7 | 3.2 | 3.1 | 4.7 | 5.9 | 0.0 |
| 46 | Unmarked | medium | decoy | 1 | 51 | 5.1 | 4% | 9.7 / 8.6 / 8.4 | 1 of 7 | 10 | 5.5 | 4.7 | 5.8 | 7.0 | 2.0 |
| 47 | Whiteout ★ | hard | longcon | 1 | 72 | 8.6 | 1% | 9.4 / 8.8 / 6.7 | 0 of 8 | 12 | 7.3 | 6.0 | 6.4 | 7.2 | 3.1 |
| 48 | Low Tide | medium | restock | 1 | 45 | 4.8 | 3% | 6.4 / 6.4 / 6.4 | 0 of 7 | 7 | 5.3 | 4.8 | 5.2 | 7.7 | 2.7 |
| 49 | Fish Market | easy | twodoor | 2 | 26 | 3.2 | 8% | 3.4 / 3.2 / 2.7 | 2 of 5 | 5 | 3.9 | 3.7 | 4.6 | 6.6 | 0.1 |
| 50 | Lighthouse Keeper ◆ | melter | melter | 1 | 91 | 9.1 | 1% | 16.2 / 15.8 / 13.2 | 0 of 7 | 7 | 7.5 | 7.0 | 4.8 | 8.2 | 10.0 |
| 51 | Seagulls | medium | longcon | 1 | 47 | 6.1 | 1% | 5.4 / 4.9 / 4.8 | 2 of 7 | 7 | 6.1 | 5.6 | 5.0 | 7.8 | 5.1 |
| 52 | Ferry Crossing | medium | twodoor | 1 | 45 | 4.5 | 5% | 8.6 / 8.3 / 7.9 | 2 of 7 | 7 | 5.0 | 4.7 | 4.9 | 7.9 | 1.8 |
| 53 | Storm Surge ★ | hard | knot | 1 | 88 | 8.4 | 0% | 8.4 / 8.0 / 6.9 | 1 of 7 | 7 | 7.3 | 6.4 | 5.5 | 7.6 | 5.4 |
| 54 | Same Street, Again | easy | breather | 4 | 20 | 2.9 | 6% | 4.6 / 3.9 / 3.8 | 2 of 5 | 5 | 3.6 | 3.5 | 4.2 | 6.5 | 0.0 |
| 55 | Any Colour | easy | intro | 2 | 19 | 1.8 | 12% | 3.0 / 3.0 / 1.3 | 0 of 5 | 5 | 2.4 | 2.4 | 4.1 | 6.9 | 0.0 |
| 56 | Arcade | medium | dump | 1 | 43 | 4.5 | 5% | 6.0 / 6.0 / 5.8 | 0 of 7 | 7 | 5.0 | 4.8 | 4.4 | 8.0 | 1.7 |
| 57 | Night Owls ◆ | melter | melter | 1 | 88 | 11.2 | 1% | 15.5 / 14.3 / 13.6 | 0 of 7 | 7 | 8.2 | 7.8 | 4.7 | 8.9 | 10.0 |
| 58 | Neon Nightmare ★ | hard | gauntlet | 1 | 101 | 9.6 | 0% | 15.6 / 15.0 / 14.9 | 0 of 9 | 9 | 7.7 | 6.6 | 6.0 | 9.1 | 6.0 |
| 59 | Vending Machine | medium | twodoor | 1 | 60 | 5.1 | 6% | 8.2 / 6.9 / 6.2 | 0 of 7 | 7 | 5.4 | 5.3 | 4.4 | 7.6 | 2.2 |
| 60 | Karaoke | easy | breather | 2 | 21 | 2.7 | 9% | 3.7 / 3.1 / 2.7 | 2 of 6 | 6 | 3.4 | 3.5 | 3.7 | 7.4 | 0.0 |
| 61 | Last Train | medium | dump | 1 | 48 | 5.7 | 2% | 10.4 / 9.2 / 8.7 | 1 of 8 | 8 | 5.9 | 5.5 | 4.9 | 8.2 | 4.5 |
| 62 | Apple Cart | medium | decoy | 1 | 45 | 4.4 | 4% | 6.1 / 5.9 / 5.9 | 0 of 8 | 8 | 4.9 | 4.5 | 5.1 | 7.9 | 1.8 |
| 63 | Cider Run ◆ | melter | melter | 1 | 76 | 7.8 | 2% | 12.6 / 12.4 / 12.4 | 1 of 6 | 6 | 7.0 | 6.4 | 5.1 | 8.6 | 7.8 |
| 64 | Scarecrow | medium | twin | 2 | 59 | 4.5 | 3% | 7.4 / 7.4 / 7.4 | 2 of 8 | 8 | 5.0 | 4.5 | 5.4 | 8.4 | 1.0 |
| 65 | Hay Bales | easy | decoy | 1 | 18 | 2.0 | 12% | 3.9 / 3.9 / 3.7 | 1 of 5 | 5 | 2.7 | 2.7 | 3.8 | 7.1 | 0.0 |
| 66 | Pumpkin Patch | medium | restock | 1 | 50 | 5.2 | 3% | 8.1 / 7.8 / 7.2 | 2 of 8 | 8 | 5.5 | 4.6 | 6.1 | 8.0 | 1.8 |
| 67 | Harvest Moon ★ | hard | dump | 1 | 100 | 9.4 | 1% | 14.2 / 13.9 / 13.9 | 0 of 8 | 8 | 7.7 | 6.5 | 6.0 | 8.6 | 5.9 |
| 68 | No Return Address | medium | knot | 1 | 45 | 5.5 | 3% | 12.1 / 11.9 / 11.9 | 0 of 8 | 8 | 5.7 | 5.1 | 5.5 | 8.1 | 3.1 |
| 69 | Men at Work | easy | intro | 2 | 11 | 1.4 | 19% | 1.2 / 0.7 / 0.7 | 0 of 4 | 4 | 1.9 | 1.9 | 3.7 | 4.7 | 0.0 |
| 70 | Diversion | medium | longcon | 1 | 53 | 6.7 | 4% | 7.5 / 7.4 / 6.0 | 0 of 6 | 6 | 6.4 | 6.0 | 5.0 | 8.4 | 5.3 |
| 71 | Rush Hour, Again ◆ | melter | melter | 1 | 92 | 10.4 | 1% | 10.9 / 9.9 / 8.7 | 0 of 7 | 7 | 8.0 | 7.3 | 5.1 | 7.3 | 7.3 |
| 72 | Traffic Cone | medium | sorter | 1 | 57 | 6.0 | 6% | 11.9 / 11.0 / 10.8 | 0 of 7 | 7 | 6.1 | 5.4 | 5.4 | 6.2 | 1.2 |
| 73 | Gridlock Deluxe ★ | hard | gauntlet | 1 | 124 | 12.9 | 1% | 24.0 / 23.6 / 23.6 | 0 of 7 | 7 | 8.6 | 7.4 | 5.8 | 8.8 | 6.7 |
| 74 | Lunch Break | easy | breather | 2 | 30 | 3.0 | 14% | 3.6 / 3.4 / 2.7 | 0 of 5 | 5 | 3.7 | 3.5 | 4.6 | 6.5 | 0.0 |
| 75 | The Other Van | medium | twodoor | 1 | 53 | 6.1 | 2% | 9.6 / 8.4 / 7.7 | 1 of 7 | 7 | 6.1 | 5.5 | 5.3 | 7.5 | 4.6 |
| 76 | Dust Devil | easy | decoy | 1 | 28 | 3.5 | 6% | 5.0 / 5.0 / 4.0 | 0 of 6 | 6 | 4.2 | 3.8 | 5.4 | 7.6 | 0.4 |
| 77 | Flash Flood | medium | dump | 1 | 52 | 6.8 | 2% | 9.1 / 8.9 / 8.1 | 1 of 8 | 8 | 6.5 | 5.8 | 5.5 | 8.4 | 5.1 |
| 78 | Tumbleweed ◆ | melter | melter | 1 | 92 | 7.5 | 5% | 10.4 / 10.4 / 9.0 | 0 of 8 | 8 | 6.9 | 6.2 | 5.4 | 8.0 | 4.5 |
| 79 | Cactus Mail | medium | twodoor | 1 | 56 | 5.4 | 3% | 8.1 / 7.9 / 7.6 | 2 of 8 | 8 | 5.7 | 5.1 | 5.3 | 8.6 | 3.1 |
| 80 | Lightning Rod | medium | decoy | 1 | 64 | 5.4 | 2% | 9.3 / 9.2 / 8.7 | 1 of 8 | 8 | 5.7 | 5.0 | 5.6 | 8.1 | 3.1 |
| 81 | Siesta | easy | breather | 2 | 24 | 2.3 | 8% | 3.9 / 3.9 / 3.9 | 0 of 6 | 6 | 3.0 | 2.9 | 4.6 | 7.1 | 0.0 |
| 82 | Mirage ◆ | melter | melter | 1 | 85 | 9.2 | 2% | 12.8 / 11.5 / 10.3 | 0 of 7 | 7 | 7.6 | 6.8 | 5.3 | 7.7 | 8.7 |
| 83 | Thunderclap ★ | hard | longcon | 1 | 111 | 10.8 | 0% | 12.3 / 11.7 / 10.9 | 0 of 10 | 10 | 8.1 | 6.6 | 6.4 | 8.7 | 4.2 |
| 84 | Cloud Nine | medium | restock | 1 | 56 | 5.4 | 5% | 7.4 / 7.1 / 7.1 | 0 of 7 | 7 | 5.6 | 5.1 | 5.3 | 8.1 | 2.5 |
| 85 | Penthouse | medium | longcon | 1 | 57 | 5.8 | 2% | 8.9 / 7.8 / 7.8 | 0 of 7 | 7 | 5.9 | 5.4 | 5.1 | 8.2 | 4.4 |
| 86 | Crane Lift | medium | hoard | 1 | 59 | 6.6 | 3% | 13.3 / 12.4 / 12.4 | 0 of 6 | 13 | 6.4 | 5.1 | 6.7 | 7.6 | 1.8 |
| 87 | Thin Air | easy | twodoor | 2 | 20 | 2.1 | 15% | 2.4 / 2.4 / 2.0 | 1 of 5 | 5 | 2.8 | 2.7 | 4.3 | 5.7 | 0.0 |
| 88 | Window Washer ◆ | melter | melter | 1 | 90 | 8.7 | 3% | 14.2 / 13.4 / 13.2 | 0 of 7 | 7 | 7.4 | 6.4 | 5.7 | 8.1 | 5.7 |
| 89 | Mile Zero | medium | twin | 2 | 76 | 7.1 | 6% | 9.8 / 9.6 / 9.1 | 1 of 7 | 7 | 6.7 | 5.9 | 5.6 | 7.6 | 1.6 |
| 90 | Top of the World ★ | hard | gauntlet | 1 | 123 | 9.6 | 0% | 14.8 / 14.8 / 14.8 | 0 of 7 | 7 | 7.7 | 6.8 | 5.5 | 9.2 | 7.9 |
| 91 | Needle in a Haystack | end | decoy | 1 | 242 | 16.1 | 1% | 21.9 / 19.8 / 18.8 | 2 of 10 | 10 | 9.2 | 7.7 | 6.1 | 8.9 | 5.4 |
| 92 | Last Orders | end | longcon | 1 | 253 | 15.8 | 0% | 33.4 / 31.6 / 31.4 | 0 of 11 | 11 | 9.1 | 6.8 | 7.4 | 8.7 | 0.4 |
| 93 | The Long Way Round ◆ | melter | melter | 1 | 130 | 12.1 | 0% | 24.2 / 23.8 / 23.8 | 0 of 6 | 6 | 8.4 | 7.5 | 5.6 | 9.3 | 7.8 |
| 94 | Night Freight | end | sorter | 1 | 184 | 13.2 | 0% | 23.5 / 21.7 / 21.2 | 0 of 10 | 10 | 8.7 | 7.0 | 6.5 | 8.8 | 3.9 |
| 95 | Grand Tour ★ | end | gauntlet | 1 | 256 | 15.5 | 0% | 28.3 / 26.5 / 24.9 | 1 of 10 | 13 | 9.1 | 6.6 | 7.6 | 8.2 | 0.0 |
| 96 | Bulk Order | end | hoard | 1 | 280 | 16.3 | 0% | 27.3 / 24.4 / 23.5 | 0 of 11 | 25 | 9.2 | 6.3 | 8.2 | 7.4 | 0.0 |
| 97 | Peak Season | end | gauntlet | 2 | 196 | 13.2 | 1% | 23.9 / 20.9 / 20.4 | 3 of 11 | 25 | 8.7 | 6.1 | 8.0 | 7.3 | 0.0 |
| 98 | Overstock | end | twodoor | 2 | 277 | 18.2 | 0% | 28.7 / 28.7 / 28.2 | 0 of 11 | 28 | 9.4 | 6.5 | 8.1 | 7.6 | 0.0 |
| 99 | Cyber Monday | end | sorter | 2 | 270 | 14.3 | 0% | 22.7 / 19.2 / 19.1 | 1 of 11 | 26 | 8.9 | 6.1 | 8.1 | 7.6 | 0.0 |
| 100 | The Last Mile ★ | end | hoard | 1 | 261 | 14.5 | 1% | 27.1 / 26.7 / 26.3 | 0 of 11 | 25 | 8.9 | 6.2 | 8.0 | 7.2 | 0.0 |
