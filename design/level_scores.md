# Level scores

Written by `tools/level_review.py` from the scorecard (`tools/score_all.sh`). What the numbers mean is in
`design/level_engine.md`. Scores are 0–10 and come from a model of a player, not from players: treat them
as a way to compare levels with each other until tester data can calibrate them.

## The whole set

| | Before | Now |
|---|---|---|
| Connect-the-dots levels (3 or fewer delivery orders the map allows) | 59 of 100 | 5 of 100 |
| Delivery orders the map allows, median | 3 | 11 |
| Real decisions per level, average | 3.2 | 4.8 |
| Share of steps that are a real decision | 15% | 25% |
| Fun, average | 5.9 | 8.5 |
| Cleverness, average | 2.8 | 3.4 |
| Complexity, average | 5.3 | 5.3 |
| Difficulty, average | 4.8 | 4.9 |
| Mechanic tiles that change nothing | 67 of 127 | 3 of 57 |

## By zone

| Zone | Levels | Fun | Clever | Complex | Difficulty | Flavours |
|---|---|---|---|---|---|---|
| Part 1 · The Suburbs | 1–20 | 7.6 | 1.1 | 3.8 | 2.8 | intro, decoy, freerun, twin, fork, twodoor, knot, longcon |
| Part 2 · The City | 21–40 | 8.8 | 2.9 | 5.2 | 4.7 | intro, restock, fork, sorter, twin, districts, freerun, decoy, longcon, twodoor |
| Frostbite Pass | 41–47 | 8.0 | 2.9 | 5.0 | 4.6 | intro, fork, twodoor, knot, freerun, decoy, longcon |
| Harbour Lights | 48–54 | 8.6 | 3.1 | 5.2 | 5.1 | restock, twin, sorter, fork, twodoor, knot, freerun |
| Neon Alley | 55–61 | 8.9 | 4.2 | 5.4 | 4.5 | intro, dump, fork, districts, twodoor, freerun |
| Orchard Hills | 62–68 | 8.8 | 5.7 | 5.9 | 5.4 | decoy, sorter, twin, fork, restock, dump, knot |
| Detour City | 69–75 | 8.6 | 4.3 | 5.0 | 4.5 | intro, districts, sorter, decoy, longcon, freerun, twodoor |
| Thunder Mesa | 76–83 | 8.6 | 4.4 | 5.3 | 5.4 | fork, dump, twin, districts, decoy, freerun, knot, longcon |
| Skyline Summit | 84–90 | 9.1 | 3.8 | 6.0 | 5.8 | restock, twodoor, hoard, fork, sorter, twin, districts |
| The Long Haul | 91–95 | 9.3 | 6.3 | 7.5 | 8.4 | decoy, knot, districts, sorter, longcon |
| Death Valley | 96–100 | 8.9 | 6.0 | 8.4 | 8.5 | hoard, districts, twodoor, sorter |

## Series checks

Nothing flagged: no flavour twice running, no connect-the-dots level outside the tutorial and Knot levels, every level within reach of its planned difficulty.

## Every level

Kind is the sort of difficulty the level leans on most. Routes are winning routes; plans are the distinct
ideas among them; orders is how many delivery orders the map would allow if colours didn't matter.

| # | Title | Flavour | What it asks | Fun | Clever | Complex | Difficulty | Kind | Routes / plans / orders |
|---|---|---|---|---|---|---|---|---|---|
| 1 | First Drop | intro | Introduces a rule: the way you'd go without it doesn't work | 3.8 | 0.0 | 0.7 | 0.1 | gentle | 1 / 1 / 1 |
| 2 | Top Goes First | intro | Introduces a rule: the way you'd go without it doesn't work | 3.8 | 0.0 | 0.8 | 0.1 | gentle | 1 / 1 / 1 |
| 3 | Burning Rubber | intro | Introduces a rule: the way you'd go without it doesn't work | 5.3 | 0.0 | 1.5 | 0.4 | gentle | 1 / 1 / 2 |
| 4 | One Pass | intro | Introduces a rule: the way you'd go without it doesn't work | 5.3 | 0.0 | 1.7 | 0.4 | gentle | 1 / 1 / 2 |
| 5 | Rush Hour ★ | decoy | The obvious first stop is the wrong one | 8.7 | 3.0 | 3.6 | 4.1 | lateral | 10 / 1 / 6 |
| 6 | Side Streets | freerun | Open town, several ways to win | 8.8 | 0.5 | 3.9 | 1.8 | search | 39 / 3 / 12 |
| 7 | Double Order | intro | Introduces a rule: the way you'd go without it doesn't work | 8.3 | 0.0 | 4.0 | 3.6 | foresight | 8 / 1 / 8 |
| 8 | Bulk Buyer | twin | Two different answers | 8.9 | 0.0 | 4.9 | 4.1 | foresight | 19 / 2 / 17 |
| 9 | One Way | intro | Introduces a rule: the way you'd go without it doesn't work | 7.0 | 3.4 | 3.0 | 3.2 | lateral | 1 / 1 / 3 |
| 10 | Against Traffic | fork | One real choice; the top few packages settle it | 8.2 | 0.0 | 4.4 | 2.8 | foresight | 15 / 1 / 9 |
| 11 | Downtown | twodoor | Drive past a house now, deliver from another street later | 8.8 | 0.4 | 4.8 | 3.3 | search | 14 / 2 / 16 |
| 12 | Long Haul | knot | One long winding drive; don't box yourself in | 8.2 | 1.7 | 4.2 | 4.2 | foresight | 5 / 1 / 9 |
| 13 | Overpass | intro | Introduces a rule: the way you'd go without it doesn't work | 7.5 | 1.2 | 3.4 | 1.6 | search | 3 / 1 / 6 |
| 14 | Flyover ★ | longcon | An early, innocent turn decides the ending | 9.2 | 2.7 | 4.9 | 5.3 | foresight | 10 / 1 / 12 |
| 15 | Spaghetti Junction | freerun | Open town, several ways to win | 8.4 | 0.8 | 4.7 | 2.3 | search | 11 / 3 / 10 |
| 16 | Suburbs | twin | Two different answers | 9.0 | 1.2 | 5.2 | 3.8 | search | 38 / 2 / 16 |
| 17 | Rainbow Row | decoy | The obvious first stop is the wrong one | 8.3 | 3.4 | 4.0 | 4.4 | lateral | 2 / 1 / 6 |
| 18 | Crosstown | twodoor | Drive past a house now, deliver from another street later | 8.8 | 2.4 | 5.5 | 3.8 | search | 20 / 2 / 18 |
| 19 | Gridlock | fork | One real choice; the top few packages settle it | 8.4 | 0.4 | 3.7 | 0.9 | search | 10 / 1 / 10 |
| 20 | Last Mile ★ | knot | One long winding drive; don't box yourself in | 7.5 | 0.0 | 6.2 | 6.0 | foresight | 2 / 1 / 9 |
| 21 | Return to Sender | intro | Introduces a rule: the way you'd go without it doesn't work | 7.9 | 4.2 | 3.8 | 3.5 | one trick | 4 / 1 / 4 |
| 22 | Pick Up, Drop Off | restock | Fetch the pickup when you want it on top, not before | 9.4 | 3.3 | 5.3 | 5.4 | foresight | 8 / 1 / 11 |
| 23 | Corner Shops | fork | One real choice; the top few packages settle it | 8.3 | 0.4 | 5.1 | 2.7 | juggling | 10 / 1 / 8 |
| 24 | High Street | sorter | Open roads; the order is the puzzle | 8.7 | 3.4 | 5.6 | 5.1 | foresight | 4 / 1 / 6 |
| 25 | Checkpoint | intro | Introduces a rule: the way you'd go without it doesn't work | 7.5 | 0.4 | 3.3 | 3.6 | gentle | 6 / 1 / 4 |
| 26 | Toll Road | twin | Two different answers | 9.8 | 2.3 | 4.8 | 4.6 | lateral | 26 / 2 / 18 |
| 27 | Key Delivery | restock | Fetch the pickup when you want it on top, not before | 9.6 | 3.3 | 5.7 | 5.5 | foresight | 12 / 1 / 16 |
| 28 | Border Control ★ | districts | Neighbourhoods and doors: clear one, leave the right way | 9.5 | 4.2 | 5.8 | 6.6 | search | 6 / 1 / 18 |
| 29 | Clocking Off | intro | Introduces a rule: the way you'd go without it doesn't work | 7.6 | 0.0 | 3.8 | 3.1 | foresight | 4 / 1 / 5 |
| 30 | Round Trip | freerun | Open town, several ways to win | 8.2 | 1.3 | 4.2 | 2.7 | search | 27 / 3 / 9 |
| 31 | Overtime | decoy | The obvious first stop is the wrong one | 8.8 | 4.2 | 5.7 | 5.1 | lateral | 6 / 1 / 6 |
| 32 | Night Shift ★ | longcon | An early, innocent turn decides the ending | 8.5 | 1.6 | 6.7 | 7.1 | foresight | 8 / 1 / 24 |
| 33 | Turntable | intro | Introduces a rule: the way you'd go without it doesn't work | 8.2 | 0.8 | 4.2 | 3.7 | foresight | 4 / 1 / 8 |
| 34 | Mix-Up | sorter | Open roads; the order is the puzzle | 9.4 | 3.9 | 4.9 | 4.3 | foresight | 6 / 1 / 12 |
| 35 | Shuffle | twodoor | Drive past a house now, deliver from another street later | 9.5 | 5.7 | 5.9 | 5.4 | lateral | 14 / 1 / 12 |
| 36 | Sorting Office ★ | sorter | Open roads; the order is the puzzle | 9.3 | 5.6 | 5.6 | 6.6 | foresight | 4 / 1 / 19 |
| 37 | Rush Order | fork | One real choice; the top few packages settle it | 6.6 | 0.0 | 5.2 | 2.2 | foresight | 3 / 1 / 5 |
| 38 | Mixed Bag | twin | Two different answers | 9.7 | 3.8 | 5.6 | 5.3 | foresight | 50 / 2 / 21 |
| 39 | Black Friday | restock | Fetch the pickup when you want it on top, not before | 9.2 | 5.1 | 6.5 | 6.8 | lateral | 4 / 2 / 32 |
| 40 | Christmas Eve | districts | Neighbourhoods and doors: clear one, leave the right way | 9.6 | 4.2 | 6.8 | 5.6 | foresight | 16 / 1 / 14 |
| 41 | First Frost | intro | Introduces a rule: the way you'd go without it doesn't work | 7.4 | 0.0 | 4.2 | 3.5 | foresight | 6 / 1 / 4 |
| 42 | Black Ice | fork | One real choice; the top few packages settle it | 8.4 | 4.5 | 4.3 | 3.8 | lateral | 4 / 1 / 6 |
| 43 | Snowplough | twodoor | Drive past a house now, deliver from another street later | 8.4 | 4.3 | 4.9 | 5.3 | lateral | 4 / 1 / 6 |
| 44 | Avalanche | knot | One long winding drive; don't box yourself in | 7.1 | 1.7 | 5.8 | 4.4 | foresight | 2 / 1 / 6 |
| 45 | Hot Chocolate | freerun | Open town, several ways to win | 6.8 | 1.6 | 4.6 | 2.9 | search | 5 / 3 / 6 |
| 46 | Unmarked | decoy | The obvious first stop is the wrong one | 8.9 | 3.4 | 5.5 | 5.1 | foresight | 7 / 1 / 8 |
| 47 | Whiteout ★ | longcon | An early, innocent turn decides the ending | 9.0 | 5.0 | 5.5 | 7.0 | one trick | 2 / 1 / 15 |
| 48 | Low Tide | restock | Fetch the pickup when you want it on top, not before | 8.5 | 3.3 | 4.8 | 5.5 | juggling | 4 / 1 / 7 |
| 49 | Fish Market | twin | Two different answers | 9.0 | 4.4 | 5.3 | 5.9 | lateral | 3 / 2 / 17 |
| 50 | Lighthouse Keeper | sorter | Open roads; the order is the puzzle | 8.7 | 5.0 | 5.6 | 6.0 | one trick | 4 / 1 / 7 |
| 51 | Seagulls | fork | One real choice; the top few packages settle it | 8.4 | 0.0 | 4.2 | 3.2 | search | 8 / 1 / 8 |
| 52 | Ferry Crossing | twodoor | Drive past a house now, deliver from another street later | 8.8 | 4.1 | 5.4 | 5.3 | lateral | 6 / 2 / 9 |
| 53 | Storm Surge ★ | knot | One long winding drive; don't box yourself in | 8.3 | 4.5 | 6.2 | 6.5 | one trick | 2 / 1 / 13 |
| 54 | Same Street, Again | freerun | Open town, several ways to win | 8.5 | 0.4 | 4.7 | 3.6 | search | 14 / 3 / 14 |
| 55 | Any Colour | intro | Introduces a rule: the way you'd go without it doesn't work | 7.9 | 3.5 | 4.8 | 0.9 | juggling | 10 / 1 / 6 |
| 56 | Arcade | dump | A locker takes a package a house wanted: choose which | 9.3 | 5.2 | 5.2 | 5.7 | juggling | 5 / 1 / 13 |
| 57 | Night Owls | fork | One real choice; the top few packages settle it | 8.5 | 0.4 | 5.0 | 2.5 | search | 12 / 1 / 13 |
| 58 | Neon Nightmare ★ | districts | Neighbourhoods and doors: clear one, leave the right way | 9.0 | 6.4 | 6.0 | 6.4 | lateral | 2 / 1 / 20 |
| 59 | Vending Machine | twodoor | Drive past a house now, deliver from another street later | 9.6 | 4.6 | 5.3 | 5.4 | lateral | 12 / 1 / 15 |
| 60 | Karaoke | freerun | Open town, several ways to win | 8.5 | 2.3 | 5.4 | 2.9 | search | 26 / 3 / 11 |
| 61 | Last Train | dump | A locker takes a package a house wanted: choose which | 9.2 | 7.3 | 6.1 | 7.7 | lateral | 2 / 1 / 20 |
| 62 | Apple Cart | decoy | The obvious first stop is the wrong one | 9.1 | 5.3 | 5.8 | 6.0 | lateral | 8 / 1 / 7 |
| 63 | Cider Run | sorter | Open roads; the order is the puzzle | 9.0 | 6.6 | 6.1 | 4.6 | juggling | 12 / 1 / 8 |
| 64 | Scarecrow | twin | Two different answers | 8.9 | 4.1 | 5.2 | 4.6 | lateral | 7 / 2 / 10 |
| 65 | Hay Bales | fork | One real choice; the top few packages settle it | 8.7 | 5.5 | 5.2 | 4.0 | juggling | 4 / 1 / 8 |
| 66 | Pumpkin Patch | restock | Fetch the pickup when you want it on top, not before | 9.1 | 5.8 | 6.1 | 6.0 | one trick | 6 / 1 / 8 |
| 67 | Harvest Moon ★ | dump | A locker takes a package a house wanted: choose which | 9.0 | 6.4 | 6.6 | 6.9 | one trick | 6 / 2 / 11 |
| 68 | No Return Address | knot | One long winding drive; don't box yourself in | 7.8 | 6.0 | 6.0 | 6.0 | foresight | 2 / 1 / 4 |
| 69 | Men at Work | intro | Introduces a rule: the way you'd go without it doesn't work | 7.3 | 1.6 | 2.8 | 0.8 | lateral | 12 / 1 / 4 |
| 70 | Diversion | districts | Neighbourhoods and doors: clear one, leave the right way | 8.2 | 4.2 | 4.7 | 4.8 | lateral | 2 / 1 / 6 |
| 71 | Rush Hour, Again | sorter | Open roads; the order is the puzzle | 9.4 | 4.8 | 5.1 | 4.9 | lateral | 9 / 1 / 16 |
| 72 | Traffic Cone | decoy | The obvious first stop is the wrong one | 8.7 | 6.2 | 5.6 | 5.9 | one trick | 3 / 1 / 8 |
| 73 | Gridlock Deluxe ★ | longcon | An early, innocent turn decides the ending | 8.5 | 5.4 | 6.2 | 6.9 | foresight | 2 / 1 / 10 |
| 74 | Lunch Break | freerun | Open town, several ways to win | 9.1 | 3.8 | 5.2 | 3.2 | lateral | 16 / 4 / 12 |
| 75 | The Other Van | twodoor | Drive past a house now, deliver from another street later | 8.9 | 4.1 | 5.6 | 5.3 | lateral | 3 / 1 / 14 |
| 76 | Dust Devil | fork | One real choice; the top few packages settle it | 7.4 | 0.4 | 4.7 | 3.5 | foresight | 5 / 1 / 4 |
| 77 | Flash Flood | dump | A locker takes a package a house wanted: choose which | 9.5 | 6.4 | 5.5 | 5.9 | lateral | 10 / 2 / 16 |
| 78 | Tumbleweed | twin | Two different answers | 8.2 | 4.7 | 4.0 | 4.9 | lateral | 2 / 2 / 7 |
| 79 | Cactus Mail | districts | Neighbourhoods and doors: clear one, leave the right way | 8.8 | 4.6 | 5.3 | 6.3 | lateral | 8 / 2 / 7 |
| 80 | Lightning Rod | decoy | The obvious first stop is the wrong one | 9.4 | 5.5 | 5.9 | 5.8 | lateral | 5 / 1 / 14 |
| 81 | Siesta | freerun | Open town, several ways to win | 8.5 | 1.6 | 5.1 | 2.8 | search | 10 / 3 / 14 |
| 82 | Mirage | knot | One long winding drive; don't box yourself in | 8.3 | 5.0 | 5.3 | 6.9 | one trick | 1 / 1 / 10 |
| 83 | Thunderclap ★ | longcon | An early, innocent turn decides the ending | 8.9 | 7.2 | 6.3 | 7.4 | foresight | 4 / 1 / 12 |
| 84 | Cloud Nine | restock | Fetch the pickup when you want it on top, not before | 9.1 | 4.4 | 5.8 | 5.9 | lateral | 10 / 1 / 8 |
| 85 | Penthouse | twodoor | Drive past a house now, deliver from another street later | 9.1 | 5.4 | 5.5 | 5.8 | one trick | 4 / 1 / 17 |
| 86 | Crane Lift | hoard | Make room before the warehouse | 8.8 | 1.3 | 7.5 | 5.2 | juggling | 27 / 2 / 20 |
| 87 | Thin Air | fork | One real choice; the top few packages settle it | 8.5 | 0.4 | 5.4 | 3.8 | foresight | 7 / 1 / 12 |
| 88 | Window Washer | sorter | Open roads; the order is the puzzle | 9.6 | 6.2 | 6.3 | 8.0 | foresight | 12 / 1 / 31 |
| 89 | Mile Zero | twin | Two different answers | 9.1 | 4.4 | 5.1 | 4.9 | lateral | 9 / 2 / 15 |
| 90 | Top of the World ★ | districts | Neighbourhoods and doors: clear one, leave the right way | 9.3 | 4.2 | 6.5 | 6.9 | foresight | 4 / 1 / 19 |
| 91 | Needle in a Haystack | decoy | The obvious first stop is the wrong one | 9.0 | 6.2 | 6.3 | 8.3 | foresight | 3 / 1 / 16 |
| 92 | Last Orders | knot | One long winding drive; don't box yourself in | 8.8 | 5.4 | 7.8 | 7.7 | foresight | 4 / 1 / 22 |
| 93 | The Long Way Round | districts | Neighbourhoods and doors: clear one, leave the right way | 9.7 | 5.7 | 7.8 | 8.0 | search | 16 / 1 / 18 |
| 94 | Night Freight | sorter | Open roads; the order is the puzzle | 9.5 | 7.4 | 7.6 | 8.9 | lateral | 8 / 1 / 16 |
| 95 | Grand Tour ★ | longcon | An early, innocent turn decides the ending | 9.6 | 6.6 | 8.1 | 8.9 | search | 5 / 1 / 31 |
| 96 | Bulk Order | hoard | Make room before the warehouse | 9.2 | 6.1 | 8.3 | 8.5 | lateral | 4 / 2 / 34 |
| 97 | Peak Season | districts | Neighbourhoods and doors: clear one, leave the right way | 8.4 | 5.5 | 8.5 | 7.6 | foresight | 1 / 1 / 14 |
| 98 | Overstock | twodoor | Drive past a house now, deliver from another street later | 8.5 | 6.5 | 8.3 | 8.7 | lateral | 2 / 1 / 26 |
| 99 | Cyber Monday | sorter | Open roads; the order is the puzzle | 9.0 | 5.3 | 8.7 | 8.6 | foresight | 4 / 1 / 44 |
| 100 | The Last Mile ★ | hoard | Make room before the warehouse | 9.3 | 6.4 | 8.4 | 9.1 | lateral | 8 / 2 / 33 |

★ marks a challenge level (the spike of its zone).
