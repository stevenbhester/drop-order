# Last Mile: level design prospectus (all levels, presents, keys, detours, bosses, new mechanics)

> **Status, 15 Nov 2026.** The engine this brief asked for is built, and levels 1–100 have been
> regenerated with it: see `design/level_engine.md` (how it works) and `design/level_scores.md` (every
> level's flavour and scores). This brief stays as the reasoning behind it. Two things changed in the
> building: answers are counted as **plans** (the order things happen), not routes, so "1–3 solutions"
> below now reads "1–2 plans, driven any of several ways"; and route choice is counted as the delivery
> **orders** the map allows. Still open from this brief: more detours and bosses (§6, §7), more presents and
> keys in the back half (§4, §5), staged districts with diners (§14), and the new mechanics (§9).

This is the brief for the level overhaul. It's written for a designer (Fable) who hasn't seen the
conversations behind it, so it says what the game is, what's wrong, what "good" means, what's already built,
and what's left to decide. Steven (the game's owner) will review the result on TestFlight.

Read in this order: §1 (what we're doing and why), §13 (the north star: not connect-the-dots), §2 (rules
every level must meet), then whatever section your current step needs. §12 is the deliverable checklist.
§13–§18 were added last (14 Nov) after measuring route choice; where they disagree with an earlier
section, they win. In particular the search-node targets in §3 are secondary to route choice.

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
   A level you can solve without reading the stack fails, however many search nodes it takes. Measured as
   **route choice** ("free" in `level_report.gd`): how many winning routes there are if colours didn't
   matter. Three or fewer is connect-the-dots (flag DOTS). Floors: easy 4+, medium 12+, hard 30+; the stack
   then cuts those to 1–3 (§13).
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
- **Half of levels 1–90 are connect-the-dots.** With colours ignored, 45 of 90 have three or fewer winning
  routes, and 18 of the 20 in levels 41–60 (exactly where Steven said it feels solved on sight). No level
  has more than 27 (level 14). The map leaves a handful of routes and the stack just picks one.
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

If you only build one, build the cowcatcher (it adds routes). If two, add the paint station: it acts on
the stack, and stack mechanics add decisions where road mechanics (roundabouts, more one-ways) remove
routes (§13).

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

Acceptance: validator and autotests pass; no DOTS past level 4 except levels tagged as the Knot flavour;
every level tagged with a flavour (§15) and no flavour twice running; the report shows no EASY level in 41–100 outside deliberate
breathers, no two EASY in a row, no DECOR; every intro level passes §2.4; presents/keys appear about one
level in three from Part 2 on, staged per §4; every locked detour has its key first; 4–6 bosses.

## 13. North star: we are not playing connect-the-dots

Steven: "the type of thing you open on the toilet for a quick brainteaser distraction then realize you're
still sitting there 30 minutes later." And: "We are not playing connect-the-dots here."

- **Why it's connect-the-dots today:** the generator draws a drive first and derives the stack from it, on
  sparse street grids. So the stack is a consequence of the one route the map allows, never a choice
  between routes (§3's numbers).
- **The fix:** the map offers many routes; the stack chooses. Route choice (free routes) is the number to
  push up, then the stack, pickups and houses cut it to 1–3.
- **Stack mechanics add decisions** (pickups, warehouses, hubs, lockers, ×N houses, a paint station).
  **Road mechanics remove routes** (one-ways, ice, roadworks, gates). Use road mechanics as doors between
  parts of a map (§14) and to take away the *obvious* route, never to narrow a map to one path.
- **Easy levels stay**, as breathing room. They get freedom instead of force: several routes work, or
  there's one clear fork. Easy must not mean "only one way to drive".
- Search size is secondary. Empty space inflates it without adding a single decision.

## 14. Try-and-see play: build bigger maps out of districts

The worry: small levels ask you to solve the whole thing before the first move. That doesn't scale to big
maps, and it isn't the loop that keeps people playing (start, see how it goes, back up, try again).

1. **Districts.** A medium or hard map is 2–4 neighbourhoods, each a small puzzle of its own, joined by
   **doors**. Roadworks are progress doors (open after N deliveries: this gives roadworks a real job).
   Gates are state doors (the right colour on top). Bridges and one-ways are no-way-back doors. A hub at a
   junction re-orders you on the way through.
2. **What crosses a door is small and nameable:** which door, what's on top, what's still aboard. The
   player's plan becomes "clear this block, leave by the east bridge with blue on top", not a 40-move line.
3. **Districts interact continuously, not only in sequence.** A pickup in one feeds another; a house
   faces streets in two districts (deliver from either side); leaving by a different door changes how
   the next one starts.
4. **Safe openers.** On medium and harder maps at least two first segments keep a win alive, so starting
   is not a commitment to a full plan. Commitments happen at doors.
5. **Mistakes show early.** A wrong choice should fail inside its district, within a few moves, not 30
   moves later. Keep "doomed depth" (how long a route with no win left can keep driving) short, except in
   the Long con flavour.
6. **Size by districts, not tiles:** hard = 3–4 districts on up to 7×10; a boss = 4–6.

Measures to add to the report: districts (pieces of the road graph with door tiles removed), safe openers,
doomed depth.

**Two kinds of district map.**

- **Open districts:** the whole map is visible from the start and the doors are roadworks, gates, bridges
  and one-ways (points 1–3 above). Carrying state across a door is fair here, because the player can see
  where it's going.
- **Staged districts, with diner checkpoints** (agreed with Steven; not built yet). The rules:
  1. A stage ends when every delivery in it is done, the van is empty, and it parks on the diner tile.
  2. At the diner the game saves, the road crew repairs every road, and the next stage's load is waiting.
     Nothing is carried across (it would be guesswork: the next stage can't be seen yet).
  3. So every player starts a stage in the same state: at the diner, fresh roads, that stage's stack. A
     checkpoint can never save a lost position, **provided each stage is winnable from that state**.
  4. Old streets stay drivable in later stages (as through-roads; their houses are done), so later
     stages have more route choice.
  5. **Zoom-out stages** (use sometimes): stage 1 is a small map in the middle; at the diner the camera
     zooms out and stage 2 adds roads round the edges and new buildings throughout, old streets
     included. Three stages at most on a phone (about 3×3, then 5×7, then 7×10).

  For the designer, each stage is an ordinary level: its own map, stack and start. The only extra rules
  are that a stage's roads include all of the previous stage's, its start is the previous stage's diner,
  and it ends on its own diner. Suggested format: the mega routes' `parts`, each part carrying its full
  map. The validator should solve every stage on its own and check the road sets nest. Reverse miles
  (`design/game_plan.md`) refill at each diner.

## 15. Level flavours (internal; players never see these)

A level's flavour is what it asks of you. Tag each level `"flavor": "<name>"` in levels.json (the game
ignores it, and it's excluded from the redesign fingerprint). Signatures are how the tools recognise one.

| Tier | Flavour | Why it's fun | Why it's hard | Signature |
|---|---|---|---|---|
| Easy | **Fork** | one real choice; two routes look right | reading the top three packages | free 2–6, 1 solution |
| Easy | **Free run** | open map, big loops, several ways to win | nothing for the win; the present is the puzzle | free 20+, 4+ solutions on purpose, a present on one |
| Easy | **Decoy** | the "aha" of one trick | the nearest house is the wrong first stop | free 4+; the obvious opener dies within 5 moves |
| Medium | **Sorter** | open map; the order is the whole puzzle | sequencing with hubs and pickups | free 12+, 1–2 solutions, needs a stack mechanic |
| Medium | **Two-door** | driving past a house on purpose | which pass counts | 2+ houses facing two streets, both sides used |
| Medium | **Dump** | throwing a package away feels naughty | spotting the one that's in the way | unwinnable without its locker |
| Medium | **Restock** | "not yet" is a move | holding off on the obvious pickup | a pickup the solution drives past first |
| Medium | **Knot** | the loop itself (today's standard level) | spatial: the self-avoiding path | free ≤ 6; allowed, at most one level in four |
| Hard | **Districts** | progress you can bank | carrying state across doors | 3+ districts (§14) |
| Hard | **Hoard** | juggling a full van | making room before collecting | load reaches 12 |
| Hard | **Long con** | the reveal | an early, innocent choice decides the end | high doomed depth by design; rare |
| Hard | **Twin** | finding the second answer | the harder one carries the present or key | 2 solutions sharing under half their tiles |
| Boss | **Bulk order** | absurd volume | Hoard at three times the size | 25+ packages through warehouses |
| Boss | **Toll roads** | paying the Baron in colours | a gate at every district door | every door a gate |
| Boss | **Roadworks racket** | he dug the city up | districts open only by deliveries | every door roadworks |
| Boss | **Rush hour** | a Knot at city scale | one-ways and ice, in districts | 4+ districts, road mechanics only |
| Boss | **The works** | everything he's got | all of it, with checkpoints | 5–6 districts |

Rhythm: never the same flavour twice running; 3–4 flavours per zone; an easy flavour after each spike;
Knot at most one in four. The report should print the flavour and flag repeats.

## 16. The story behind it (never spelled out to players)

We're the last independent courier in the city. Baron Von Bottomline (Hoardly Inc.) wants to buy us out,
so he places orders rigged to be undeliverable: awkward loads, dug-up roads, toll gates. Every job we
finish, all he's done is pay us for extra work, which is why he's furious. Boss levels are his biggest
efforts yet.

It's background, to keep motives and tone consistent. Hint at it where it lands: boss lines, the odd
level hint or title ("Somebody ordered 26 parcels to one street. Wonder who."), chest notes. The
frictions are his too: fuel comes from his gas stations, and hints are the GPS.

## 17. Generator changes (to build, most valuable first)

1. **Map first, stack second.** Today: route, then stack. Instead: make the map, count free routes, then
   search house colours, the stack and pickups for a set that cuts them to 1–3. Reject maps under the
   tier's floor.
2. **Aim at route choice and safe openers, not search size**, in the generator and in the mutation search
   (§10.4): score = free routes ÷ solutions, plus safe openers.
3. **Denser maps:** more loops, fewer dead ends, one-tile blocks with houses inside so they face two
   streets.
4. **District mode:** generate small maps, stitch them with door tiles, carry the stack across, and check
   each district can be won from each state it can be entered in.
5. **Flavour presets** (`--flavor=sorter`): floors and required mechanics from §15's signatures.
6. **Twists must earn it:** keep a road-restricting twist only if it removes solutions *and* leaves free
   routes above the floor.
7. **Report:** flavour, districts, safe openers, doomed depth; flag flavour repeats.
8. **Presents and keys by stage** (§4), using the Twin signature for stage D.
9. **Calibrate against people** once testers' per-level attempts and times exist; all of the above are
   proxies until then.

## 18. Game changes these designs lean on (not built; Steven's call)

Decided since; the detail is in `design/game_plan.md`:

- **Undo as reverse miles:** a per-level budget of tiles you can take back, in as many goes as you like,
  with no star cost. Design maps so short probes are worth making.
- **No automatic dead-end signal.** Noticing you're doomed is part of the puzzle, so keep doomed depth
  short by design. (Dispatch, a once-a-level yes/no check, is a late, opt-in reward.)
- **Diner checkpoints** on staged district maps (§14).
- **Fuel as the Baron's gas stations, hints as GPS**; beating a boss removes one friction for good.
- **Per-level tester stats** (attempts, retries, time), with a line in the privacy policy.

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
