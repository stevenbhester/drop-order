# Level format

Levels 1–100 are made by the level engine: plan in `tools/make_plan.py`, generator `tools/gen_levels.gd`,
scores in `design/level_scores.md`. See `design/level_engine.md` before editing them by hand; a hand edit
is fine, but run the scorecard after (`tools/level_report.gd`).

All levels live in `levels.json` as `{"levels": [ ... ]}`. Order in the file = level number.

```json
{
  "title": "Overpass",
  "hint": "Bridges cross twice: once each way. Drive straight over.",
  "no_revisit": true,
  "map": [
    "# . # # S",
    "# . # y #",
    "# # + # #",
    "# y # . #",
    "# # # . #",
    ". . b . ."
  ],
  "stack": ["blue", "yellow", "yellow"]
}
```

## `map`
One string per row, top to bottom. Cells are **space-separated tokens** (extra spaces are fine,
so rows can be aligned when some tokens are two characters). Every row needs the same number of tokens.

| Token | Meaning |
|---|---|
| `.` | Block (grass; decorative trees are added automatically) |
| `#` | Road |
| `S` | Road where the van starts (exactly one) |
| `^` `>` `v` `<` | One-way road: you must **leave** it moving the way the arrow points. You can turn onto it from the side, but never drive onto it head-on against the arrow. Point it at road |
| `+` | Bridge: crossable once horizontally and once vertically, always straight across. Needs road on all four sides |
| `r` `b` `g` `y` `p` `o` | House: red, blue, green, yellow, purple, orange. Wants 1 package |
| `r2`, `b3`, ... | House wanting that many packages of its colour (shows "×2") |
| `R` `B` `G` `Y` `P` `O` | Parcel shop (uppercase colour): its parcel goes onto the **top** of the van's stack when the van drives past |
| `R4`, `B3`, ... | Warehouse: a pickup holding that many parcels of its colour (shows "+4"). Driving past loads them all, one by one onto the top, unless a house right there wants the one that just came aboard (then it's delivered in between) |
| `=r`, `=b`, ... | Colour gate (road): can only be entered while the top package is that colour. Put it on a straight piece of road |
| `@` | Sorting hub (road): swaps the top two packages when the van drives onto it |
| `E` | Exit (road, on the map's edge): a mega route's part is won by delivering everything and then finishing here |
| `~` | Ice (road): no turning on it; you leave it the way you drove on |
| `w`, `w2`, ... | Parcel locker: takes whatever package is on top (that many). Colour totals: every colour still needs enough packages, and the lockers take the spare ones |
| `c2`, `c3`, ... | Roadworks (road): closed until that many packages have been delivered |

The loader rejects levels where:
- a house or shop touches no road, touches a bridge or hub, or touches the `S` tile (the van
  only acts on tiles it drives *onto*);
- the start is anything but plain road;
- total house orders per colour don't exactly match the packages: stack plus shop parcels;
- the van starts with more than 12 packages (`LevelData.MAX_LOAD`). Bigger levels feed packages in
  from warehouses along the way instead, and `tools/validate_levels.gd` also fails a level whose
  winning route ever has more than 12 aboard at once.

## `stack`
Package colours, **first = bottom, last = top** (the top is delivered first). Full names
(`"red"`) or the single letters above both work.

## Side roads
`side.json` has `{"side": [ ... ]}`: levels in the same format plus `id`, `after` (the level whose map
stop it branches off, and which opens it), `reward` (the cosmetic it wins), and `twist`:
`fuel` (the tank holds exactly the shortest route), `melt` (finish within `seconds`), `one_shot` (one drive
for the whole run) or `fog` (the load's shown for `peek` seconds, then only the next package). Each side road also has a `bonus` (its once-a-day power-up:
`{"kind": "reserve" | "hints" | "undos", "amount": tanks or minutes}`). A **mega route**
has `twist: "mega"`, a `grid` ([columns, rows]) and `parts`: levels of their own, each with `at` (its cell
on the grid), played in order. Every part but the last needs an exit (`E`) on the edge toward the next
part (its direction comes from the grid). `tools/make_mega.gd` turns generator output into parts:
it tries each road tile on the wanted edge as the exit and keeps the ones that are still winnable. The
validator checks them; `tools/autotest_all.sh` drives each one and checks its twist bites.

## Daily puzzles
`daily.json` has the same format: `{"levels": [ ... ]}`. Today's puzzle is the next one in the list
each day, repeating (see `scripts/daily.gd`). The validator checks them too.

## Other fields
- `title`: shown under the board.
- `hint`: instruction shown under the board until the player starts drawing.
- `no_revisit`: each road tile can be used once per attempt (bridges: once per direction), because
  the van wrecks the road behind it. Default `true` (every level); `false` would allow revisits.
- `return`: `true` means the level is only won once everything is delivered **and** the van
  is parked back on `S`. Driving onto `S` ends the shift, ready or not.
- `gift`: `{"at": [x, y], "item": "drizzlet"}` puts a cosmetic present on a road tile (ids in
  `scripts/cosmetics.gd`). It isn't part of the rules; the validator checks it can be picked up on the way
  to a win (on some winning route, or by driving past the last delivery in the same drag).
  `tools/place_gifts.gd` lists good spots.
- `flavor`: what kind of puzzle the level is (`fork`, `decoy`, `sorter`, `twodoor`...). Written by the level
  engine (`design/level_engine.md`) and used only by the tools: the game ignores it, players never see it,
  and it isn't part of the "redesigned since you beat it" fingerprint.
- `preview`: `true` marks a sneak-peek level (shown with a PEEK tag).
- `challenge`: `true` marks a difficulty spike (much harder than its neighbours): a hazard rim and flame on
  the map, a "CHALLENGE!" intro until it's beaten, and a 500 Dollaroo bonus on the first win. One per
  region or so, after an easy level and a moderate one.

## Rules recap (implemented in `scripts/sim.gd`)
The player builds the route in segments, each driven when they lift their finger. On levels
that allow revisits, U-turns are possible between segments. The solver treats the whole route
as one path, since segment breaks can go anywhere.

When the van arrives on a tile: a hub swaps the top two packages first; then, repeatedly,
it delivers the top package to an adjacent house that still wants that colour, otherwise it
collects one waiting parcel from an adjacent shop (onto the top). Gates are checked against the
top package at the moment the van would enter them.

## Adding a level
1. Add an object to `levels.json` where you want it in the sequence.
2. Run the validator. It must say `ok` and show at least 1 solution. `--ablate` also re-solves
   without the level's arrows/bridges/gates/hubs, to show whether they actually matter:
   ```
   godot --headless --path . --script res://tools/validate_levels.gd -- --ablate
   ```
3. To tune difficulty, try every stack order for that map (fewer solutions usually means harder):
   ```
   godot --headless --path . --script res://tools/stack_orders.gd -- <level number>
   ```

## Repairing a level's arrows
If a rule change leaves a level with no solution or several, this searches single (or with `--pairs`,
double) arrow edits that leave exactly one, and prints the best with the solution drawn:
```
godot --headless --path . --script res://tools/arrow_edits.gd -- <level number> [--pairs] [--top=6]
```

## Checking a hand-made level
Put one or more level objects in a JSON array in a scratch file, then:
```
godot --headless --path . --script res://tools/check_level.gd -- path/to/draft.json
```
It prints the solution count, the shortest solution drawn onto the map as step numbers, and
the count with each mechanic (arrows, bridges, gates, hubs) removed.

## Generating candidates
`tools/generate.gd` makes random street-grid levels that are solvable by construction (it
builds them backwards from a random drive), keeps those with few solutions and a big search,
and prints the best as JSON. Levels 6, 8, 10–12, 14–20, 22–24, 26–28, 30–32 and 34–40 started
as generator output (hand-picked, border-cropped, titled). Levels 21, 25, 29 and 33, which
introduce the four Part 2 mechanics, are hand-made. Example:
```
godot --headless --path . --script res://tools/generate.gd -- \
    --w=7 --h=9 --n=6 --colors=4 --shops=1 --gates=1 --hubs=1 --ret=1 --needhub=1 \
    --maxsol=1 --minnodes=120 --loops=85 --tries=4000 --seed=3
```
Options: `w h` grid size, `n` deliveries, `colors`, `multi=1` (require a ×2 house),
`shops=k` parcel shops, `gates=k` colour gates, `hubs=k` sorting hubs, `ret=1` return to depot,
`oneway=k` arrows, `bridges=1`, `needbridge=1` / `needhub=1` (must be unsolvable without them),
`maxsol`, `minnodes` (minimum solver search size, a rough "how many tempting wrong turns"),
`loops` (% of extra streets kept: more = more choices), `open` (solutions allowed before
gates/arrows narrow the map), `minlen`, `tries`, `seed`, `top`. The first summary line lists
the most common reasons candidates were rejected.

On levels that allow revisits the number of routes is infinite, so the solver caps each
tile at 2 visits there. Treat those counts as rough.
