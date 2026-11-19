# The level engine

How levels 5–100 are made, and how a level is judged. Levels 1–4 are the hand-made tutorial.

The engine is a C program (`tools/engine/lm.c`, `gen.c`) that copies the game's rules exactly, measures how
hard a level is for a model of a player, and searches for levels that fit a plan. It replaced the first
engine (GDScript, build 23), whose levels Steven found trivial: see "What we learned" below, which is the
part to read before changing anything.

## The pieces

| File | What it is |
|---|---|
| `tools/engine/lm.c` | The rules (a mirror of `scripts/sim.gd`), the solver (a mirror of `scripts/solver.gd`), and the two measures: the road view and the plan view |
| `tools/engine/gen.c` | The generator (compiled into `lm.c`) |
| `tools/engine/build.sh` | Builds `build/lm` |
| `tools/engine/crosscheck.sh`, `reference.gd` | Checks the C solver against the game's on every level file (routes, search size, shortest route). **Run after touching the rules on either side** |
| `tools/engine/lv.py` | Level JSON → the one-line text format `lm` reads |
| `tools/engine/plan.py` → `tools/level_plan.json` | **The plan**: what each of the 100 levels is for |
| `tools/engine/gen_all.py` | Runs the generator for many slots, ten at a time; candidates land in `build/engine/` |
| `tools/engine/assemble.py` | Picks the best candidate per slot and writes `levels/levels.json` |
| `tools/engine/review.py` → `design/level_scores.md` | Every level's numbers, and the series checks |

```bash
tools/engine/build.sh
python3 tools/engine/plan.py
python3 tools/engine/gen_all.py --seed 1          # about ten minutes on ten cores
python3 tools/engine/assemble.py                  # -v lists what was picked; --dry writes nothing
python3 tools/engine/review.py
godot --headless --path . --script res://tools/validate_levels.gd
tools/engine/crosscheck.sh && tools/autotest_all.sh
```

To redo a few slots: edit their rows in `plan.py`, run it, then `gen_all.py --seed 2 37 38 39` and assemble.
To look at one level: `python3 tools/engine/lv.py levels/levels.json | sed -n 37p | build/lm explain` prints
the answer junction by junction: what tempts, how often, and what it costs.

## What we learned (read this first)

Three rounds of playtest feedback, each of which proved a measure wrong.

1. **"We massively overcorrected."** The first engine asked for many winning plans, an open town and a
   load that could go several ways. Result: follow the queue by the shortest road and you win. A level
   needs **one answer (or very few) and many wrong roads that don't look wrong**.
2. **Counting wrong roads isn't enough.** A measure that counted failed *drives* rated two samples at
   seven tries each. Steven solved one in his head and called the other easy. Why:
   - He thinks in **plans** (which building next, through which door), not road tiles. Thirty wrong drives
     were two ideas.
   - He **rules things out by argument**: "that pickup is far from the houses and I can't come back for it"
     kills a family of attempts without trying one.
   - He **repairs locally**: a wrong door costs a tweak, not a restart.
   - **A house with one door is a signal**: don't pass it until its colour is on top. One holding the last
     package says where the drive ends, and he works backwards from it.
   - **Houses along one street** have their order fixed by geometry. No decision there.
3. **What he says is hard**: choosing which building takes the top package when several could (more so
   with pickups, lockers and hubs that could come first instead), and choosing a road there when each
   road blocks something different later. "When these two things intersect a few times in a row you reach
   a very complicated state where you kind of have to just experiment because it's too hard to hold in
   your head." That is the target.

So there are two views of a level, and a level is fitted to both.

## The road view: someone who has to drive it to find out

A model player ("the explorer") who heads for the next delivery, sees some dead ends coming, and learns
from the rest:

- What draws them down a road is **how soon it delivers something**, by the best line down it that isn't a
  dead end they can see. A road three tiles slower is tried first about a third as often.
- They can read two kinds of dead end off the map and don't drive into them: a road with nowhere to go,
  and a move that uses up **the last door** of a building that still needs a package.
- Everything else costs a **try**. A dead branch costs less than its size (people give up on an idea before
  exhausting it) and more if it delivers packages before it dies (it looked like it was working).

Three players, because the door signal is learned: **new** (hasn't learned it), **regular** (uses it, sees
it two tiles down a forced road), **expert** (sees it however far). Levels up to 12 are scored for new
players, to 60 for regulars, after that for experts.

| Number | Meaning |
|---|---|
| `tries` | failed drives to expect before the win |
| `first` | chance an unthinking first drive wins |
| `twists` | junctions on the answer that cost about a try or more; `forks` cost a fraction |
| `nears` | wrong roads that deliver everything but one package |
| `away`, `gap` | the right move leads away from the next delivery while something more direct is on offer, and by how many tiles |

This view is right about beginners. It badly overrates levels for experienced players, because in an open
grid one idea can be driven a dozen ways.

## The plan view: someone who thinks it through

Every drive the solver would consider (it gives up the moment something needed can't be reached),
collapsed to its sequence of **stops**: which building, through which door. Two drives that make the same
stops are the same plan, however the road between them wiggles. That gives a tree of plans, and the same
explorer walks it.

| Number | Meaning |
|---|---|
| `pnodes` | partial plans that survive an expert's pruning: what there is to hold in your head |
| `plans` | complete wrong plans (dead ends that needed thinking through), plus the answers |
| `ptries` | wrong plans to expect to work through before the answer |
| `pfirst` | chance the first plan that comes to mind is the answer |
| `pdec`, `ptwists` | stops on the answer with a real alternative; those that cost a plan or more |

### Calibration (the anchors)

| Level | Verdict | Partial plans | Wrong plans to work through | Road tries (regular) |
|---|---|---|---|---|
| Build 23, levels 5–20 (median) | trivial | about 9 | under 1 | 0.6 |
| OG 41–60 (median) | connect-the-dots | 9 | 0.8 | 0.6 |
| Sample B (houses on one street, far pickup) | "trivial, solved in my head" | 18 | 2.0 | 7 |
| Sample A (which red, then green, then which red) | "fairly okay as an easy level" | 18 | 2.6 | 7 |
| OG 22 "Pick Up, Drop Off" | "seemed impossible" (a new player) | 15 | 1.4 | 1.7 (3.2 for a new player) |
| OG 23 "Corner Shops" | "thought it was bugged" (two days in, arrow rule in doubt) | 14 | 2.3 | 3.0 |
| Calibration 11 (6×8, 6 packages) | "fun, pretty tricky but solvable in my head" | 37 | 4.6 | 10 |
| Calibration 12 (6×8, 7 packages) | "a little easier; my most likely path was pretty correct first time" | 70 | 7.4 | 10 |
| Calibration 13 (6×7, 7 packages, two hubs, a locker, a pickup) | "don't see an immediate path, pretty great!" | 98 | 10.6 | 12 |
| Calibration 14 (7×9, 8 packages) | "don't see an immediate path, pretty great!" | 198 | 10.5 | 16 |
| OG 96–100 | hard, by sheer size | 200–330 | 12–18 | 20 |

The plan view puts both samples and OG 23 in the same place (about fifteen partial plans, two wrong ones),
which is how Steven ranks them now, and it ranks five of his six verdicts on new levels correctly. The
road view explains why OG 22 and 23 stumped people who were new.

**The miss (calibration 12)** scored harder than 11 and played easier. Its answer has the fewest "which
building next?" choices of the four (2 of 7 deliveries, against 3–5) and a one-door house. One case isn't
proof, but those are the things Steven names as what makes a level hard, so medium and harder slots now
require them (`pickmin`, `d1max`, `open_end`).

**The bands** (`BANDS` in `plan.py`) are set from these: easy about 2–3 wrong plans and 15–20 partial plans;
medium 4–7 and 35–50 (calibration 11); hard and mind-melters 7–14 and 70–120 (calibration 13 and 14); the
last ten 12–18 and 180 or more.

## The scores (0–10)

In `build/lm score` output and `design/level_scores.md`. They're a model's opinion: good for comparing
levels with each other.

- **Difficulty**: road tries for the level's player.
- **Complexity**: how much there is to hold: length, packages, colours, kinds of mechanic, roads.
- **Devious**: difficulty that comes from misdirection rather than size (difficulty, marked down for bulk).
- **Melt**: the mind-melter signature: one answer, an unthinking attempt never wins, near misses, and a
  small plain level.
- **Fun**: a hypothesis: enough tries to bite but not grind, surprises spread along the drive, "so close"
  moments, a clean board.

## How a level is generated

1. **A town.** Streets on a lattice two or three tiles apart (so no fat blocks of road), with some stretches
   cut and a few stubs left.
2. **The answer.** A drive from a start tile that uses most of the town.
3. **Buildings** scattered along it, each with a colour and a note of which pass delivers to it.
4. **The load is worked out, not chosen.** The answer is driven with an unknown load; each delivery that
   comes off the starting load settles what colour that package must have been. Then the real rules check
   the answer wins. Gates and roadworks on the answer take whatever lets it through.
5. **Search.** That first level is far too easy. Thousands of small edits follow (recolour a house, swap
   two, move one, deliver on a different pass, add or remove a building, a pickup, a locker, a piece of
   road, an arrow, ice, a gate, roadworks, a hub), each time re-deriving the load so the answer still wins,
   keeping edits that take the level towards its slot. It's simulated annealing: early on it accepts some
   edits that make things worse. The answer itself never changes, so every level visited is solvable.
6. **Tidy.** Any arrow, gate, hub, ice or roadworks the level fits just as well without is removed.
7. **A present**, where the slot has one, goes on plain road no winning line needs, a few tiles on from
   where the drive ends.

The search tries about 20,000–60,000 levels a second per core.

## The plan

`tools/engine/plan.py` has one row per level: flavour, tier, the zone's mechanics, and which must matter.

**Tiers.** easy (a breather that still costs something), medium, hard, **melter** (a mind-melter: as many
ideas as a hard level on a smaller board with fewer packages), end (the last ten, bigger maps). Each
tier's targets are set per part of the game in `BANDS`, in plan-view units, with a road-view ceiling so a
level that's fair to an expert isn't a wall for whoever is actually playing it. Levels 5–12 are an on-ramp:
their ceiling is tight, because whoever plays them has just finished the tutorial.

**What the harder tiers ask for**, from the feedback above: several houses of the same colour to choose
between (never two of them beside one road tile: that's a guess, not a choice, so `level_valid` refuses it) (and no one colour hogging the van), few one-door houses, no one-door house for the last package,
and deliveries spread along the drive instead of saved for one street.

**Flavours** are a wish, not a requirement: decoy (the obvious first stop is wrong), twodoor (drive past a
house, deliver later from another street), longcon (an early turn decides the ending), gauntlet, knot,
park (the answer parks a package in a parking locker and delivers something else before fetching it back;
parking one and taking it straight back doesn't count), restock, sorter, twin, hoard, breather. The assembler takes the best candidate with the flavour,
else the best without.

**Mechanics.** A level that introduces a mechanic must use it on the answer, and the answer set must change
without it. Every level in a zone shows the zone's own mechanic doing a job.

**Rhythm.** A mind-melter about every six levels (14 in all), the hazard-tape challenge levels as the hard
ones, so a spike every three or four levels, and no flavour twice running.

**Retired: the long way round.** The first search loved one trick: put the houses on one street and a
pickup far away, so the answer loops round the outside and delivers everything at the end. It scored very
high in the road view and Steven solved it in his head ("only two obvious paths"). Deliveries must now be
spread along the drive (`qmax`).

## Checks

- `tools/engine/crosscheck.sh`: the C solver agrees with the game's on every level in every level file.
- `tools/validate_levels.gd`: the game loads and solves every level; presents can be collected and aren't
  on the hint route; keys come before locks.
- `tools/autotest_all.sh`: every level won in every input mode.

## Limits to know about

- **The measures are models.** The road view has been checked against two anecdotes, the plan view against
  three. Every time Steven has played samples, the model has needed fixing. Expect that to continue, and
  prefer his verdict on five levels to any number here.
- **The game solves every level on the main thread** when it opens and for each hint, so the plan caps the
  solver's search per tier (`nodes_max`).
- **Dailies, side roads, speedrun courses and the OG 100** are not made by this engine.

## Follow-ups

- **Play them and say which were wrong.** After each build, the levels that felt too easy or like a wall
  are the most useful thing there is: redo those slots with a new seed
  (`python3 tools/engine/gen_all.py --seed 2 <slots>`), and if several miss the same way, fix the measure.
- **Fit the model to the ratings.** The Rate levels option (off by default, offered after level 5) sends a
  rating and the level's stats after each win; `python3 tools/ratings.py` pulls them, sets them beside
  the plan and the model's numbers, lists the levels that played easier or harder than planned, and says
  how well the model's order agrees with the players'. The model's weights are few (`TAU`, the 0.6 power
  on dead branches, the three players' sight) and easy to fit once there's data.
- **A themed decoration pass** (extra ice in Frostbite and the like): the tidy step currently removes
  anything that isn't doing a job.
- **Region reasoning.** An expert also thinks in neighbourhoods ("once I'm in there I'm not coming back
  out"). The plan view doesn't model that yet; it would mark down levels whose buildings sit in clusters.
- **Dailies and side roads** from this engine, with plans of their own.
- **Diner checkpoints, new mechanics**: see `design/todo.md`.
