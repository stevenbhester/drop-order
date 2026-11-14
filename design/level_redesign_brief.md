# Last Mile: level design prospectus (all levels, presents, keys, detours, bosses, new mechanics)

This is the brief for the level overhaul. It's written for a designer (Fable) who hasn't seen the
conversations behind it, so it says what the game is, what's wrong, what "good" means, what's already built,
and what's left to decide. Steven (the game's owner) will review the result on TestFlight.

Read in this order: §1 (what we're doing and why), §2 (rules every level must meet), then whatever section
your current step needs. §12 is the deliverable checklist.

---

## 0. The game in one minute

- Portrait, one thumb. Draw a route from the van; it drives it. It delivers the **top** package of its stack
  to each house of that package's colour it passes. Deliver everything to win.
- The road behind the van tears up (a "trail", cosmetic): **you can't cross your own route**. Most levels
  are `no_revisit`.
- 100 numbered levels on a road map (Part 1 · 1–20, Part 2 · 21–40, Part 3 · 41–90 in seven zones,
  Endgame 91–100), plus 38 daily puzzles, side roads ("detours") off the map, milestone chests every ten
  levels, and a speedrun mode.
- Mechanics (tokens in `scripts/level_data.gd`, full table in `levels/README.md`):
  one-ways `> < ^ v`, bridges `=`/`H`, ×N houses (`r2`), pickups and warehouses (uppercase colour + count,
  e.g. `B5`), colour gates (`=y`), sorting hubs `+` (swap the top two), return-to-depot (`return: true`),
  ice `~` (no turning on it), lockers `w`/`wN` (take whatever's on top), roadworks `cN` (open after N
  deliveries), mega-route exits `E`.
- Stars: 3, minus one for using a hint, minus one for using undo. Players start each level with **one
  hint** (two more come from the chests at 10 and 20). A hint shows the next straight stretch of the
  **plain (shortest) winning route**, ending in a pulsing ring.

## 1. Why this job exists (Steven's words and asks)

> "I should not be able to regularly look at a map and solve it right away just based on its layout
> almost ever at this point. Like I don't even look at the packages, because it's obvious there's only
> one good way to drive."

> Too often the ice just stands in for one-way tiles; most of the map never gets touched; back-to-back easy
> levels, especially 40–60. Small maps are fine, but they should be tricky and use the new mechanics in
> ways that change how you think about winning.

> "I really like how presents incentivize an alternate, trickier solution to maps, and would like if more
> maps had alternate routes/solutions that were more complicated to incentivize scooping a present."
> "Early on it's fine if it's as simple as taking a longer route where the short one works, later game it
> should have bigger impact."

> "Review all levels, starting at [the first], to be sure they are individually good levels and work well
> within their surrounding levels."

> "Levels that introduce a new mechanic should always be focused on having to understand that mechanic to
> complete a job in a way that is different from how you could/would have done it had the mechanic not
> been there."

> Detours can be locked; keys turn up more often deeper in the game. "There should always have been a key
> for a detour available prior to the detour's appearance."

> Make some side quests boss fights: extremely difficult, dense, a consistent villain (a satire of
> capitalism) who laughs at you as you enter and runs off dropping a very cool cosmetic when you win.

So the job is four things at once:

1. **Every level, 1 to 100, reviewed and fixed where it fails §2**, alone and in sequence.
2. **Presents (and keys) designed as alternate solutions**, ramping from "a longer way round" to "a whole
   different plan".
3. **More detours in the back half**, increasingly locked behind keys, with **boss fights** among them.
4. **Possibly new mechanics** (§9), only where they earn their place.

## 2. The bar for every level

A level passes when all of these hold. Most are measured by `tools/level_report.gd`.

1. **The packages decide the route.** Shuffle the stack and the layout should suggest a different route.
   A level you can solve without reading the stack fails, however many search nodes it takes.
2. **Not trivially easy**, scaled to where it sits (targets in §3). "EASY" in the report means score
   under 9, 6+ solutions, or under 400 search nodes.
3. **No decoration.** Every mechanic on the map changes the answer: turned into plain road, it must open up
   new solutions or make the level unwinnable (the report's DECOR flag; per-tile for ice, "ice idle").
   Ice especially: a one-way limits direction; ice limits *turning*. Use ice where turning is the
   tempting move.
4. **Introductions teach by necessity** (the mechanic-intro rule). The level that introduces a mechanic
   must be one where you *can't* win the way you would without it, and where the winning route uses it in
   the way the hint describes. Test: ablate the mechanic (turn it to road); the plain-road version must
   have a *different* winning route (or none), and the player's likely first plan on the real map must
   fail *because of* the mechanic. A gate intro should make you reorder; a hub intro should make you need
   the swap; ice should stop a turn you'd otherwise take.
5. **Coverage** of at least 60% of the road, unless a small map uses its emptiness as the trick.
6. **1–3 solutions** (one is best). More than that and the "aha" leaks away.
7. **In context**: never two EASY levels in a row anywhere; a breather still needs a look at the packages;
   each zone keeps its training-load shape (intro, mid-tier, the zone's challenge spike, a cooldown).
8. **Fits a phone**: about 5–7 wide and 7–10 tall in Part 3 (bigger only for the endgame and bosses).
   The van never holds more than 12 at once (`LevelData.MAX_LOAD`).
9. **Plays clean in every input mode**: `tools/autotest_all.sh` wins every level by drag, segments, undo,
   hints and D-pad.

## 3. Where it stands, and targets

`tools/level_report.gd -- --from=1 --to=100` (slow: minutes) gives, per level: solutions, search nodes,
route length, coverage, a score, and the flags. The last full run of 41–100 is in
`design/level_report_before.txt`:

- **Every level from 41 to 90 is EASY** (19–130 search nodes). The endgame (91–100) takes 480–2,200, which
  is the bar to aim near late on.
- **26 levels have a decorative mechanic**: roadworks in most of 69–90, ice in most of 41–54 and 76–83
  (`tools/fix_ice.gd` moved ice onto junctions, but the layouts still force the route).
- **1–40** (`design/level_report_1_40.txt`): no decorative mechanics, but all 40 are under the report's
  400-node EASY line (11–300 nodes; most of Part 2 is 80–300). The report's EASY line is calibrated for
  Part 3, so judge 1–40 against the table below instead. Part 1 can stay gentle as a tutorial; Part 2
  (21–40) mostly sits under its 200–700 target and is where the "solve it from the layout" feeling starts.
  Check every intro level against the mechanic-intro rule (§2.4): 1–2 stack order, 3 the torn road, 4
  loops, 7 ×2 houses, 9 one-ways, 13 bridges, 21 pickups, 25 gates, 29 return to the depot, 33 hubs, 41
  ice, 55 lockers, 69 roadworks.

Rough search-node targets (a guide, not a law; the packages-decide test matters more):

| Levels | Role | Nodes (typical) |
|---|---|---|
| 1–10 | tutorial: one idea each | 10–150 (fine to be small; must still teach by necessity) |
| 11–20 | combinations | 100–400 |
| 21–40 | Part 2: shops, gates, depot, hubs | 200–700 |
| 41–60 | Part 3 first half | 300–900 |
| 61–90 | Part 3 second half | 600–2,000 |
| 91–100 | endgame | 1,000–2,500 |
| bosses | optional, very hard | 1,500+ (and dense) |

## 4. Presents: alternate solutions worth chasing

A present (`"gift": {"at": [x, y], "item": "<cosmetic id>"}`) sits on a road tile. Drive over it on the
way to a win and its cosmetic is yours. Rules already enforced by `tools/validate_levels.gd`: it must be
reachable on some winning route, and **it must not lie on the plain (shortest) winning route**, because
hints follow that route and would walk players straight to it.

What we want is a ramp in how much a present asks of you:

| Stage | Levels | What the present asks |
|---|---|---|
| A | 1–20 | **A longer way round.** The plain route works; the present is down a side street, or one tile past the finish ("the extra mile"). |
| B | 21–50 | **A different order.** The present route needs the deliveries in another sequence: going for it changes which colour is on top when, so you have to re-plan (e.g. collect a pickup earlier, take the other side of a loop). |
| C | 51–80 | **Use a mechanic differently.** The present route uses a mechanic in a way the plain route doesn't: a second hub swap, passing a gate on a different colour, an ice slide the plain route avoids, waiting for roadworks to open. |
| D | 81–100 | **A whole other plan.** The present route shares little with the plain one past the first few moves; it's a second, harder solution to the same level. |

Targets: about one level in three carries a present (or key, §5) from Part 2 on; more in the back half.
Each should be a real temptation: visible from the start, plausibly near, and costly to get.

How to measure (please build this into `tools/place_gifts.gd`, which today finds "alt" spots on other
winning routes and "extra mile" spots past the finish): for each candidate tile, compare its best gift
route to the shortest route: extra tiles, the move where they first differ (later is sneakier), how many
deliveries happen in a different order, which mechanics the gift route uses that the plain one doesn't,
and the solver's node count with the gift required. Rank by stage. After level 20, prefer "alt" spots over
"extra mile".

Cosmetics budget: each present gives a cosmetic, and we don't want to invent dozens more. So beyond the
existing ones, **presents become keys** (§5): the same alternate-route design, with a key instead of a
cosmetic.

Current presents: 5, 6, 8, 13, 14, 16, 21, 26, 34, 38 (cosmetics), 94 (`deep_field`), and keys on 15, 33,
43. **Presents fade out after level 38.** Fix that (the brief's main ask after difficulty).

## 5. Keys and locked detours

Built and working (0.7 build 22):

- A key is a present with `"item": "key"`: `"gift": {"at": [x, y], "item": "key"}`. Picked up on a win,
  once per level (`Progress.keys_found`), it adds to the keys in hand (`Progress.keys`). It shows on the
  map pin and in the level like a present (a gold key).
- A side road with `"locked": true` (in `levels/side.json`) needs a key to open: tap its sign on the map
  (or the "Unlock detour" button after the level before it) and it's open for good
  (`Progress.sides_unlocked`).
- **The validator enforces "a key before every lock"**: by each locked detour's stop, the number of keys
  placed on levels up to that stop must be at least the number of locked detours up to it. Surplus keys
  are fine (players miss some).

Placed now (stopgaps, all "extra mile" spots, to be redesigned as real alternate routes):

| Key on | Opens (the lock at its stop) |
|---|---|
| 15 Spaghetti Junction | The Big Map (mega route, after 27) |
| 33 Turntable | Fog Bank (after 33) |
| 43 Snowplough | Hostile Takeover (boss, after 45) |

The ask: **keys more often the deeper you go**, and most detours past 40 locked. Aim for roughly one key
every 4–6 levels in 41–100, a few more than there are locks, placed per §4's stages. Keys keep the
present-style design: an alternate, trickier route. If a level is redesigned, move its key with it (the
validator will tell you if the budget breaks).

## 6. Detours (side roads)

Side roads branch off the map after a level; they're free to play and win a cosmetic. Twists
(`SideRoads.TWISTS`): `fuel` (small tank: the shortest route only), `melt` (beat the clock), `one_shot`
(one drive, no stops), `fog` (only the next few packages visible), `mega` (one big map in parts, saved as
you go), and now `boss` (§7). Twisted side roads allow no hints or undos; mega routes and bosses allow both.

Today there are only six side roads, all before level 34, plus a boss after 45. **The back half needs
detours**: propose one every 6–8 levels from 40 to 100 (8–10 more), mixing twists, most locked. Each wants
its own reward. Rewards can be existing cosmetics not yet placed, new ones from §7's list, or "looks"
(§8): check `Cosmetics.ITEMS` and `SideRoads.where()` so nothing is given twice.

## 7. Boss fights

Built (0.7 build 22): the framework and one boss.

- A boss is a side road with `"twist": "boss"`. Before it starts, **Baron Von Bottomline**, CEO of
  **Hoardly Inc.** ("We deliver. To shareholders."), rises on a gold lift over a night skyline, laughs
  (HAW HAW HAW) and delivers a line of corporate trash talk (`scripts/boss_intro.gd`, every time). When you
  win he panics ("My quarterly earnings!!"), drops his money bag (it bursts into the prize) and runs for it
  (`scripts/boss_outro.gd`). His art, taunts and defeat lines are in `scripts/boss.gd`; add more lines in
  the same voice: a cheerful satire of corporate greed (subscriptions, "synergy", layoffs, shareholder
  value), never mean to real people or brands.
- On the map his pad shows him (laughing now and then) under a red BOSS plate.
- Hints and undos are allowed (the maps are hard enough).
- The first boss, **Hostile Takeover** (after 45, locked, reward **Money to Burn**: a trail of burning cash
  stacks), is a placeholder: level 99 "Cyber Monday" mirrored and recoloured (1,113 nodes, 26 packages, one
  solution). It fills the slot but repeats a level's shape; design a proper one.

The ask:

- **4–6 bosses** across the back half (e.g. after 45, 60, 75, 90, and one past 100's stop), each the
  hardest thing near it: **1,500+ search nodes, one solution, dense** (lots of packages, or several
  mechanics interlocking), up to about 8×12. They're optional, so they can be much harder than the
  levels around them.
- Each boss map should feel like the Baron's turf (warehouses = his hoard, gates = toll booths, lockers =
  "premium" drop-offs) and have a one-line hint in his voice.
- Each drops **a very cool cosmetic**. Money to Burn is the first. Candidates to build (code-drawn like
  everything else): *Golden Parachute* (topper: a gold parachute that deploys on a win), *Corporate Jet*
  (ride: a tiny private jet taxiing the streets), *Stock Ticker* (queue look: an LED ticker scrolling the
  load), *Gold Card* (controls look: brushed-gold buttons), *Marble Road* (road look). Which you build is
  your call; say so in the deliverable so Steven can sanity-check the list.
- Bosses should normally be locked (keys, §5).

## 8. The cosmetics this feeds (for reward planning)

The garage now has three tabs: **Van & Road** (rides, paints, toppers, trails, roads), **Packages &
Buildings** (package shapes, building themes), **Queue & Controls** (the package queue's container, button
colours). A tab is greyed and padlocked until something in it is yours. The "looks" (`scripts/looks.gd`)
unlock with stars, deliberately late: roads at 110/235★, controls 75/165/245★, queues 120/215★, packages
135/195/270★, buildings 155/255★ (300★ is everything). Rewards from detours and bosses can be any kind.

## 9. New mechanic ideas (assess, then build only what earns it)

For each: a one-paragraph rule, why it changes thinking, what it costs to build. Steven's take is in
quotes. A new mechanic needs: tokens and parsing (`level_data.gd`), rules (`sim.gd`; the solver uses
Sim), drawing (`board.gd` + a node), a symbol-card line (`symbol_card.gd`), README and `levels/README.md`
entries, an intro level that meets §2.4, and enough levels after it to make it worth learning (at least
4–6).

1. **Cowcatcher pickup** (recommended). A one-use pickup on the road: after collecting it, the van may
   cross its own torn-up track **once**, straight across (perpendicular, not along it). It turns the core
   constraint inside out for one move, so the puzzle becomes *where to spend it*. Sim: a counter in state;
   `can_extend` allows entering a wrecked tile once if moving straight through and the next tile is also
   straight on. Solver cost: moderate (one more state bit). Visual: a plough on the van's nose; the crossing
   punches a gap in the trail. Good for the second half of Part 3 or a later zone.
2. **Roundabouts** (worth a look). A junction tile where the van may come back out the way it came in
   (a legal U-turn), or that forces a turn. Cheap in Sim and very readable. *Diagonal roads* are a much
   bigger change (drag input, drawing, the grid); recommend not now.
3. **Teleporters**: "I'm doubtful about the drag UX". Two linked pads; entering one puts you on the other.
   The route line would have to jump mid-drag, which reads badly with one thumb. Recommend skipping unless
   you find a clear UX (e.g. the drag snaps to the far pad with a visible arc, and the D-pad just works).
4. **Package storage** ("maybe too far"). A storage unit where the van drops its top package and picks it
   up later. Powerful (it's a second stack), which makes puzzles far harder to read and far harder to
   solve. Recommend at most a late-game twist on a few levels, or a boss gimmick.
5. **Paint station** ("use sparingly"). Repaints the top package once (to the station's colour). It changes
   what "the order" means, cheaply. Recommend a handful of late levels and maybe a boss.

If you only build one, build the cowcatcher.

## 10. Process

1. **Baseline.** Run `level_report.gd` over 1–100 and `validate_levels.gd -- --ablate`. Save both.
2. **Review table**, one row per level 1–100: its role in the zone, nodes/solutions/coverage, flags, does
   it pass §2 (each point), does its intro (if any) pass §2.4, its present/key and stage, verdict
   (keep / tweak / redesign) and why. Look at each level *and* at its neighbours: difficulty step from the
   last, whether it repeats the last level's trick, whether a breather is earned.
3. **Plan per zone**: the zone's roster, its training-load shape, where its challenge spike is, where its
   presents/keys/detours/boss go.
4. **Build.** Generate (`tools/generate.gd`), twist (`tools/twist_levels.gd`), or hand-design. Note: the
   generator struggles to hit high node counts. With `--minnodes` 900+ it rejected all of 6,000 tries at
   6×8. Two things help: hand-design the spine and let the tools vary it, or write a mutation search
   (`tools/mutate.gd`: start from a decent level, randomly swap house colours, move a one-way, add or remove
   a road tile, keep the change if nodes go up and solutions stay 1–3; repeat). The second is probably the
   best use of compute here. Also fix `twist_levels.gd`'s known flaw: it accepts a twist whenever it
   doesn't add solutions, which is how decorative mechanics got in; require that a twist *removes*
   solutions or raises nodes a lot.
5. **Check.** `validate_levels.gd -- --ablate` (solvable, presents reachable and off the plain route, keys
   before locks), `level_report.gd` (targets, no DECOR, no EASY streaks), `tools/autotest_all.sh` (wins in
   every input mode; about 15 minutes), and look at the hard ones: `-- --level=N` (with `--write-movie` to
   record). A few renders of new intro levels and bosses in the deliverable would help Steven review.
6. **Write up** (§12).

## 11. Things to keep (and one thing that's automatic)

- **Level numbers, count and titles.** Saves and the map are keyed by level number; don't renumber.
  Retitle only if a redesign really needs it, keeping the zone's theme.
- **Hints** (`hint`) say what's new or tricky in a level; rewrite them when the trick changes.
- **`challenge: true`** on each zone's spike.
- **Redesigns mark themselves.** The game fingerprints each level's puzzle (map, stack, rules; not the
  title, hint, present or key, and not the spacing inside map rows) and remembers which version a player
  beat. A level redesigned after they beat it shows on the map with a pale blue pin, hollow pulsing stars
  and an UPDATED tag until they beat it again (it re-earns its stars). So: change the puzzle when it needs
  changing, and *don't* make no-op edits to maps of levels that pass (they'd ask players to replay for
  nothing).
- Presents keep their cosmetic ids (players' "where is it" hints in the garage are generated from them).
- `MAX_LOAD` 12, phone-sized maps, `no_revisit` unless a level is built around revisiting.

## 12. Deliverable

On a branch (not main):

- `levels/levels.json` (and `side.json`, `daily.json` if touched) with the redesigned levels, presents,
  keys, detours and bosses.
- `design/level_review.md`: the review table (§10.2), the zone plans, and a one-line trick per level
  ("you must pick up blue before the gate"; "the ice at the crossroads stops the obvious left").
- `design/level_report_after.txt` next to the before, and the validator's output.
- Any new tool (`place_gifts.gd` ranking, `mutate.gd`), new mechanics, new cosmetics, each with its README
  section.
- A short note for Steven: what changed most, what you weren't sure about, and anything that needs his
  decision (mechanics built or skipped, boss rewards).

Acceptance: validator and autotests pass; the report shows no EASY level in 41–100 outside deliberate
breathers, no two EASY in a row, no DECOR; every intro level passes §2.4; presents/keys appear about one
level in three from Part 2 on, staged per §4; every locked detour has its key first; 4–6 bosses.

## Appendix: tools

| Tool | What it does |
|---|---|
| `tools/level_report.gd -- --from=1 --to=100` | per-level scorecard: solutions, nodes, length, coverage, score, EASY / LOW-COVER / DECOR / idle ice, EASY streaks |
| `tools/validate_levels.gd [-- --ablate]` | everything parses and is solvable; presents reachable and off the plain route; keys before locks; with `--ablate`, each mechanic family re-solved as plain road |
| `tools/generate.gd` | route-first generator (flags in its header: size, colours, shops, gates, bridges, hubs, return, `--maxsol`, `--minnodes`, `--run`, `--stock`, `--minpkg`, `--walks`) |
| `tools/twist_levels.gd` | adds ice, lockers, roadworks while keeping a level winnable (`--rate` rates levels) |
| `tools/place_gifts.gd [levels...]` | candidate present/key spots: "alt" (another winning route) and "extra mile" |
| `tools/fix_ice.gd`, `tools/check_level.gd`, `tools/stack_orders.gd` | ice clean-up, one level's solutions, exploring stack orders |
| `tools/check_scripts.gd -- res://scripts/x.gd` | quietly shows a script's parse errors (don't pass non-SceneTree scripts to `--script` directly on macOS: it pops a dialog) |
| `tools/autotest_all.sh` | the full self-test suite (every level, every input mode, ads, hints, cancel, keys, ghost path) |
| `-- --level=N`, `--side=<id>`, `--save=gas:5,done:N,keys:K,stale:S`, `--write-movie out/f.png` | jump into a level, a side road or a boss; a made-up save; record it |

Level tokens: see `levels/README.md`.
