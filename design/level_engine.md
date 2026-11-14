# The level engine

How Last Mile's levels are planned, generated and scored. Built on 14–15 Nov 2026 to replace the old
route-first generator, whose levels were mostly connect-the-dots (the map allowed one way to drive, and
the packages just went along with it).

The goal, in Steven's words: a quick brainteaser you open for a minute and are still playing 30 minutes
later. "We are not playing connect-the-dots here." Not every level hard: an occasional easy one is welcome,
as long as it isn't trivial. Different kinds of difficulty should get their turn (holding a long path in
your head, thinking outside the box, finding one little trick), and levels in a row shouldn't feel alike.

## The pieces

| File | What it is |
|---|---|
| `tools/make_plan.py` → `tools/level_plan.json` | **The plan**: what each of the 100 levels is for (flavour, tier, difficulty wanted, mechanics, which mechanics must matter, size, present or key) |
| `tools/gen_levels.gd` | **The generator**: fills one slot of the plan with candidates |
| `tools/level_metrics.gd` | **The scoring**: every measure and the four scores (shared by the generator and the report) |
| `tools/level_report.gd`, `tools/score_all.sh` | **The scorecard**: scores levels.json (all 100 in about 10 seconds) |
| `tools/gen_all.sh` | runs the generator for many slots side by side |
| `tools/assemble_levels.py` | picks the best candidate per slot and writes `levels/levels.json` |
| `tools/level_review.py` → `design/level_scores.md` | the table of every level's flavour and scores, and the series checks |

To regenerate everything:

```
python3 tools/make_plan.py
tools/gen_all.sh 120 1            # seconds per slot, seed; candidates land in build/levelgen/
python3 tools/assemble_levels.py
godot --headless --path . --script res://tools/validate_levels.gd
tools/score_all.sh > build/levelgen/scores.jsonl && python3 tools/level_review.py build/levelgen/scores.jsonl
tools/autotest_all.sh
```

To redo a few slots, edit their rows in `make_plan.py`, run it, then `tools/gen_all.sh 120 2 37 38 39`
(a new seed gives new candidates; the assembler takes the best across every seed's files).

## Two ideas everything rests on

### 1. Plans, not routes

A **route** is the exact tiles you drive. A **plan** is what happens in what order: which house gets its
package when, which pickup is collected when, when the hub swaps. In an open town many routes drive the
same plan (round a block either way).

The old rule was "1–3 winning routes". That forces the map into a single corridor, which is exactly
connect-the-dots. The new rule is **1–2 winning plans**, driven by as many routes as the town allows
(capped at about 50 so the game's solver stays quick). The thinking is the same; the driving is forgiving.

**Route choice** is measured the same way: turn every house into a locker (colours stop mattering) and
count the distinct orders the buildings can be visited in. That's what the *map* allows. If it's three or
fewer, the map has decided the order and the packages are along for the ride: the report flags it DOTS.
Floors: easy 4+, medium 6+, hard 10+, endgame 12+ (tutorials and Knot levels are exempt). Then the colours
cut that down to one or two plans: the packages decide.

### 2. The greedy driver

Scores need a model of a player. Ours is the **greedy driver**: someone who always heads for the nearest
place the top package can go, can see when a move obviously strands a house (the road to it is cut off),
and otherwise doesn't plan. At every step of a winning route we ask how likely that driver was to make
the right move.

- Where they'd certainly have got it right (one legal move, or the right move is the nearest delivery),
  the level asks nothing.
- Where the right move heads *away* from the nearest delivery, the level is asking for thought.
- Add it up over the route and you get how many tries the greedy driver would need: **bits** (log2 of
  the tries). Zero bits: they win first time, every time.

It's a model, not a player. Real players plan, so read the scores as a way to compare levels, and
calibrate them against tester data (attempts, retries, time per level) when there is some.

## What gets measured

| Measure | Meaning |
|---|---|
| `solutions`, `plans` | winning routes; distinct plans among them |
| `free`, `free_orders` | colour-blind winning routes; the distinct visiting orders among them (route choice) |
| `bits` | how surprising the win is to the greedy driver |
| `effort` | log2 of the moves the greedy driver wastes on failed tries before a win |
| `decisions` | steps with a real choice (two or more moves that aren't obviously dead) |
| `anti` | decisions where the right move is not toward the nearest delivery ("outside the box") |
| `trick` | the most surprising single step ("the little trick") |
| `traps` | tempting wrong moves that don't look wrong yet |
| `late` | after a wrong turn, how many moves until it's obvious (foresight: "a long path in your head") |
| `early_doom` | the longest such run from a wrong turn in the first third of the route |
| `late_drops` | deliveries made on a later pass of a house, not the first ("come back to it") |
| `dumps` | packages a locker took that a house still wanted |
| `pickup_anti` | pickups reached by going against the greedy pull (fetching early, or holding off) |
| `swaps`, `pickups`, `gate_passes`, `works_passes`, `ice_slides`, `bridge_double`, `oneway_used` | whether each mechanic is actually used on the winning route |
| `matters`, `idle` | which mechanic families change the answer; how many single tiles change nothing |
| `cover`, `longest_forced` | share of the road the route uses; the longest run of steps with no choice |
| `overlap` | how much two winning routes share (for Twin levels) |
| `nodes` | what the game's own solver has to search (it runs when a level opens and for every hint) |

## The four scores (0–10)

- **Difficulty**: mostly `effort` (the greedy driver's wasted moves), plus a little for sheer load.
- **Cleverness**: anti-greedy moves, the size of the trick, coming back to houses, locker dumps, hub
  swaps, and whether the pure greedy driver fails early.
- **Complexity**: how much there is to hold: decisions, route length, packages, kinds of mechanic,
  foresight, stack juggling.
- **Fun**: a hypothesis, made of six parts:
  - *choice* (26%): how many delivery orders the map allows;
  - *agency* (20%): 18–55% of the steps are real decisions (fewer is a corridor, more is a slog);
  - *aha* (20%): one to four counter-intuitive moments;
  - *fairness* (12%): wrong turns show themselves within about six moves;
  - *economy* (12%): the route uses the map, and has no long stretch without a choice;
  - *purpose* (10%): mechanic tiles that change the answer.

And a **profile** saying which kind of difficulty a level leans on, each 0–1: **foresight** (how late
mistakes show), **lateral** (anti-greedy moves), **trick** (one surprising step), **juggling** (stack
work: hubs, lockers, pickups, a full van, many colours), **search** (many decisions and traps). The plan
rotates flavours so these take turns.

## Flavours

What a level asks of you. Internal: players never see the names. Each has a signature the generator
checks, so a level tagged with a flavour really has it.

| Flavour | What it asks | Signature the generator requires |
|---|---|---|
| intro | learn one rule | the mechanic is used; it changes the answer; **the natural answer without it doesn't win** (the mechanic-intro rule) |
| fork | one real choice | 1 plan, 1–4 decisions |
| freerun | enjoy an open town | 3–14 plans, low bits |
| decoy | don't take the obvious first stop | the first decision is anti-greedy, or the greedy driver fails in the first half |
| sorter | get the order right | a swap or pickup, plus an anti-greedy move or a real trick |
| twodoor | pass a house now, deliver later | 2+ deliveries on a later pass |
| dump | choose what the locker eats | a locker takes a package some house still wanted |
| restock | time the pickup | a pickup reached against the greedy pull |
| knot | one long winding drive | 72%+ of the road used; mistakes take 2+ moves to show; low route choice is allowed here |
| longcon | an early turn decides the ending | a wrong turn in the first third runs 7+ moves before it's obvious |
| twin | two different answers | exactly 2 plans whose routes share under 70% of their tiles |
| hoard | make room first | the van reaches 8+ aboard, with warehouses |
| districts | neighbourhoods and doors | the town is built as 2–3 districts joined by door tiles; a door is used |

Rules for the series: no flavour twice running; three or four flavours per zone; an easy flavour (fork,
freerun) after each spike; Knot at most about one level in four, because it is the old corridor style,
kept as one taste among many.

## How a level is generated

1. **A town.** Streets on a lattice two or three apart, with most loops kept. For districts, the lattice
   is cut into neighbourhoods joined by one or two door tiles.
2. **Fixtures** that shape driving whatever's aboard: bridges at crossroads, some ice (only at junctions,
   where turning is the tempting move), some one-way streets.
3. **Buildings** on cells beside the streets, preferring cells that touch two or more streets. The town's
   route choice is checked here; towns under the floor are thrown away before any more work.
4. **A drive**: a random route passing every building at least once, usually carrying on a few tiles so
   some are passed twice. Return-to-depot levels keep a way home open.
5. **The load, backwards from the drive.** Buildings get their roles now (pickups early on the drive).
   Each house gets its package on one of the passes, not always the first; pickups hand over whatever is
   needed next; lockers take a package of a chosen colour, usually one a house also wants. What's left
   at the start is the stack. The real rules then confirm the drive wins.
6. **Repainting.** If there are too many plans, houses change colour (the roads stay as open as they
   were) until the plans come down.
7. **Doors that depend on the load**: gates and roadworks on the drive, set to what the van has on top
   or has delivered by then.
8. **Narrowing and pruning.** If plans are still too many, an allowed road mechanic goes where it removes
   some. A mechanic the slot is about is placed where it changes the answer. Then every mechanic tile
   that changes nothing is removed.
9. **Judging.** The solver's cost, plans, route choice, the four scores, the flavour's signature, the
   intro rule, the present's spot, and how close the difficulty is to what the plan asked for.

The current level in each slot is judged the same way and kept if nothing new beats it.

### Decoration

Mechanic tiles that change nothing are removed by default. Three exceptions, all deliberate:

- **Red herrings**: about one idle tile in eight is left in.
- **Guides**: a gate or roadworks on the only door between two districts doesn't change the answer (you
  couldn't come back anyway) but tells the player "finish this side first". District doors are kept.
- **Themed levels**: a slot can ask for mood tiles (`"theme": "ice", "theme_n": 3`: a winter town with
  extra ice). Used sparingly.

A level never has more than a third of its mechanic tiles idle outside those cases.

## Presents and keys

A slot with a present or key gets it placed by the generator: on a winning route other than the plain
(shortest) one if there is one, else a few tiles past the finish. Hints follow the plain route, so the
present is never on it. Present levels are mostly Twin and Free run, where a second way exists.

## The plan

`tools/make_plan.py` holds a table with one row per level: flavour, tier, the zone's mechanics, and which of
them must matter. From the tier come the size of the job (houses, colours), the route-choice floor, the
solver budget, a minimum drive length (easy isn't trivial) and a minimum share of the town used. From the
part of the game and the tier comes the difficulty wanted:

| | Easy | Medium | Hard |
|---|---|---|---|
| Part 1 (1–20) | 0.8–2.8 | 2.8–4.6 | 4.6–6.2 |
| Part 2 (21–40) | 1.8–3.4 | 3.6–5.4 | 5.6–7.0 |
| Part 3, first half (41–68) | 2.4–3.8 | 4.2–6.0 | 6.2–7.8 |
| Part 3, second half (69–90) | 2.6–4.0 | 4.6–6.4 | 6.6–8.2 |

The last ten have a band each, climbing from 7.4 to the finale: 95 and 100 are the two peaks (8.6–9.6 and
9.0–10). Each zone's challenge level is its hard-tier spike; a fork or free run follows most spikes.

A zone's signature mechanic must be present and change the answer on the levels that are about it. Its
other mechanics are optional: they appear where they earn their place. Three levels are pinned to what
their in-game text says (53 mentions ice, 76 ice and roadworks, 83 ice, lockers and roadworks).

Kept as they were: levels 1–4, the first four taps of the game (one house; top goes first; the road tears
up; plan the loop). Everything else competes, old level included.

## First run: 15 Nov 2026

Levels 5–100 were regenerated (96 new levels; no old level won its slot). From the scorecard, old set
against new (`design/level_scores.md` has every level):

| | Before | Now |
|---|---|---|
| Connect-the-dots levels (the map allows 3 or fewer delivery orders) | 59 of 100 | 5 of 100: the four kept tutorials and the one-way intro |
| Delivery orders the map allows, median | 3 | 11 |
| Real decisions per level, average | 3.2 | 4.8 |
| Share of steps that are a real decision | 15% | 25% |
| Mechanic tiles that change nothing | 67 of 127 | 3 of 57, all on the themed winter level (45) |
| Fun (model), average | 5.9 | 8.5 |
| Cleverness, average | 2.8 | 3.4 |
| Complexity, average | 5.3 | 5.3 |
| Difficulty, average | 4.8 | 4.9 |

Average difficulty and complexity are where they were, on purpose: the levels have more choice in them,
not more punishment. By the kind of difficulty each level leans on most: 32 foresight, 30 lateral, 17
search, 9 one trick, 7 juggling, 5 gentle (the first levels).

No red herrings made it in outside the themed level: the generator leaves some, but the fun score marks
idle tiles down ("purpose"), so levels with them lost their slots. To have a few on purpose, give a slot
`"decor": 1.0` and lower the weight of purpose in `_scores`, or add them by hand. The search the game's solver does stayed small (under 1,300 nodes on every level, about a
tenth of a second at worst), so opening a level and asking for a hint are as quick as before. The assembler
marks candidates down once they pass 2,000 nodes: the first pick for level 96 took the solver 0.7 seconds,
and a lighter candidate that scored almost the same replaced it.

Presents and keys were re-placed on the new maps (presents on 5, 6, 8, 13, 14, 16, 21, 26, 34, 38, 94; keys
on 15, 33, 43), each off the plain route. A save that beat the old levels shows them as UPDATED on the map
until they're beaten again (`Progress`, `levels_v` 3).

Compute: about 25 minutes on ten cores for everything (75 seconds a slot for 5–90, five to seven minutes a
slot for 91–100).

## Limits to know about

- **The game solves every level on the main thread** when it opens, and again for each hint. That's why
  the generator caps the solver's search per tier (`nodes_max`: 1,500 easy to 8,000 endgame). A faster or
  background solver in the game would allow bigger, denser towns.
- **The scores are a model.** Nothing here has been checked against real players yet.
- **Staged districts** (diner checkpoints, zoom-out) need game support first; district levels today use
  doors the game already has.
- **The generator only uses existing mechanics.** Cowcatcher, paint station and the rest are in
  `design/todo.md`.

## Follow-ups

- **Play them.** Everything above is judged by the model. A play-through will find levels that score well
  and feel wrong; redo those slots with a new seed (`tools/gen_all.sh 120 5 <slot>`), or change the slot's
  row in the plan.
- **Calibrate the scores** against testers' attempts, retries and time per level, then retune the weights
  in `level_metrics.gd` (`_scores`) and the difficulty bands in the plan.
- **Presents and keys in the back half.** The generator can place them (`"gift"` in a slot); what's missing
  is cosmetics to give and locked detours to open. The brief (§4–§7) has the plan for more detours and
  bosses; a `boss` tier in the plan (bigger, denser, 1 plan) would generate their maps.
- **Dailies, side roads and speedrun levels** still come from the old generator. Give them plans of their
  own.
- **A faster solver in the game** (or solving off the main thread) would lift the budget and allow bigger,
  denser towns late on.
- **Staged districts** (diners, zoom-out) once the game can play them: each stage is an ordinary slot, so
  the generator needs only the "roads nest, start at the last diner" rule.
- **New mechanics** (cowcatcher, paint station): each needs Sim rules first, then a fixture or door step
  here and a "used" counter in the metrics.
- **The trick line.** `tools/level_review.py` has one line per flavour ("what it asks"); a line per level,
  written from the measures (which house is the decoy, which package the locker should eat), would feed
  the finish card idea in `design/todo.md`.
