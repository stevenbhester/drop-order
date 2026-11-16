# Last Mile: to-do list (things agreed or liked, not yet built)

Details and reasoning for most of these are in `design/game_plan.md`. The ad scripts, the Baron's boss
offers and the residents' reaction pool are in the review doc:
https://claude.ai/artifact/KxmfbsdURLeJeAGxMVm9wc

## Agreed, in suggested build order

1. **Undo as reverse miles.** A per-level budget of tiles you can take back (tap = one segment, hold =
   tile by tile), no star cost, base and bonus miles shown apart on the Undo button, and an "Undo style"
   option (Distance allowance by default, or Segment allowance).
2. **Residents.** Tiny people at each house who react to your route (cheer, wait at the door, slump when
   you drive past with the wrong colour) and to your trail (three gags per trail).
3. **The Baron marks new rules.** A two-second, skippable sting on each level that introduces a mechanic.
   Try it on build 23, internal testers only.
4. **Fake ads.** Thirteen Hoardly Inc. spots are scripted; one tap skips, an option turns them off. Built 15 Nov
   (`scripts/baron_ad.gd`): about a third of pretend ads, Options > Extras > Hoardly ads.
5. **The Offer.** The Baron opens each boss with an out-of-touch offer; the van honks; he promises a hard
   day. The "offer" ad changes as bosses fall.
6. **Diner checkpoints** for staged district maps (finish a district with an empty van, park at the diner,
   roads are repaired, the next load is waiting; sometimes the camera zooms out). Needs game support
   before the level generator can make these.
7. **Dispatch.** A late, opt-in reward: one yes/no "can this still win?" call per level, no star cost.
8. **Go Independent.** One purchase removes real ads and gas limits. The purchase screen is plain; the
   Baron never sells anything real.
9. **Fuel as the Baron's gas stations, hints as GPS** (naming and art), and a boss win removes a friction.

## Done since this list was started

- Levels 5–100 regenerated twice. The first engine's levels (build 23) were trivial; the second engine
  (`tools/engine/`, in C) makes one-answer levels with many convincing wrong plans, calibrated on Steven's
  verdicts on sample levels (`design/level_engine.md`, `design/level_scores.md`).
- Drop-offs stand on a plain pale pad with a thin coloured rim and faint waves drifting in; pickups have
  waves going out to their square outline (so buildings pop off their pads).
- The cancel zone follows the finger even where it overlaps the Hint and Undo buttons.
- The OG 100: the pre-engine levels as an easter egg on the title once all 100 are beaten.
- The green building is a flat-ridged barn with a silo (its old roof ran along the pad's rim).

## Liked from the brainstorm (small, none depends on the level redesign)

- Express mode: on a streak, slide straight into the next level with fewer taps.
- Zone-coloured boards (snow, sand, neon) so 100 levels don't all sit on the same grass.
- Each delivery plays the next note of a scale; the last package gets a beat of slow motion.
- Tap a package in the queue to light up its houses, and the other way round.
- Make failing funny (tyres go pffft, residents shake their heads).
- The stack as the liveliest thing on screen (packages slide and thunk).
- Name the trick on the finish card (the generator now writes a one-line trick per level).
- "2 ★ to Cobblestones" on the finish screen; a peek at the next map behind Next.
- Music that builds with momentum.
- Your finished route as a shareable postcard.
- Hold to fast-forward the drive.
- Pencil marks (pin 1, 2, 3 on houses) for hard maps.
- A quiet "one take" badge for a single-stroke solution.

## Proposed (Steven, 15 Nov), not built

- **The map redesign.** Three swings in `design/map_redesign.md` (road atlas, dispatch board, the road seen
  from the van). Pick one.
- **A "find them all" detour.** One map with exactly N different ways to win (as plans: different stops
  or order, not the same idea wiggled); the detour shows "1 of 3 found" and a ghost of each route found,
  and is won when all N are. The level engine can make these (aim the search at N plans, each hard to
  see). The game needs: telling two winning routes apart by their stops (Solver already can), a
  tally on the card, and replays that keep what was found.

## Bosses (Steven, 14 Nov): the rule

- A boss fight that guards something the game leans on is a **core level on the main road, early, and
  can't be skipped**: no "skip for now", and the jobs after it stay locked until he's beaten
  (`Boss.CORE`, `Boss.blocker`). Today: levels 6 and 11.
- **The last level of every zone is a boss fight** (`Boss.is_level`): the Baron's intro and outro, his
  black-and-gold ticket on the map, the 500 bonus. Zones were re-cut so each ends on its hardest job
  (1–8, 9–14, 15–20, 21–28, 29–32, 33–40, then as before), and four pairs of levels swapped places
  (53/54, 58/61, 67/68, 73/75) in the plan, the captions and `levels.json`.
- **Detours are for the optional things**: cosmetics, temporary power-ups, coins and less vital upgrades.
- **The story is said out loud by the Baron**, one line going into each main-road fight and one as he
  loses it (`Boss.STORY`): we're the last independent courier in town, and he wants the town's deliveries
  to himself. Level 5's line is the introduction. Keep them short; each follows that zone's board clues.
- **On the map, what can be tapped is a pinned ticket** (jobs, detours, chests: same paper, band, tab and
  pin); scenery and the lore clippings are faint and pencil-outlined (`RoadMap._bg`, `PENCIL`).

## Gas (Steven, 14–15 Nov)

- Playing and retrying levels is free. Gas buys help past the free allotment (each level's free hints,
  `Progress.hint_slots()`, and each try's free undos, `Progress.undo_slots()`). On a level (kept across
  retries, for the session: `Game.gas_bought`): one tank makes undos and hints both unlimited for the
  rest of the level. (Before: a tank bought a few undos or one hint, and only a second made them unlimited.)
- Tanks come back on their own, one an hour (was 30 minutes), up to 3. Bonus tanks (`reserve_gas`: chests,
  detours, the ad) sit on top, never come back, and are spent first. Out of gas, the pretend ad pays 2
  bonus tanks (unlimited help on two levels) and then does the hint or undo. The Dollaroo station refills.
- The first time help would cost gas, `GasExplainer` shows how (a can pours into the button), with the
  beta's note that the ads are pretend and skippable and that Testers → Unlimited gas turns it off.
- Old saves' banked undos (from the undo ad) became bonus tanks. Skips are unchanged (free).
- **Dollaroos are switched off** (Steven, 15 Nov: "For now let's cut them, we can always bring back"):
  `Progress.COINS := false`. Nothing earns, shows or spends them; the balance stays in the save. The gas
  station offers the pretend ad (+2) instead of selling a tank. Turning COINS on restores all of it.

## Being tried (tester option)

- **Headlights** (Steven, 14 Nov; on by default since the same day). Options → Testers → Headlights:
  Earned (the default), Off (the game as it was), or fixed at 1, 2, 3 or 5. Self-tests play with them
  off unless given `--foresight=N`. With them on, the route can only be plotted as far ahead of the van as its lights
  reach: draw further and the van follows behind, delivering as it goes, and what it's driven can't be
  undrawn. Lifting the finger sends it the rest of the way. The aim: stop players solving the whole level
  as a ghost route before the van moves.
  - **Earning them** (`Progress.headlights()`): Dim headlights (1), found on job 2's road (jobs 1 and 2 are driven in the dark); Headlights (2) and High beams
    (3) from the two core boss fights on the main road, levels 6 and 11 (`Boss.CORE`); Rally lights (4)
    from the Hostile Takeover detour; Lighthouse (5) for finishing every speedrun course. Capped at 5.
  - **Undo** in this mode goes back to the last stop (a delivery, pickup or swap) and costs no star.
    Undos per level (`Progress.undo_slots()`, both modes): 1, plus two from each core boss (levels 6 and 11), so 5.
  - The chute shows what's really aboard, there's no crusher, and a finger sliding back over driven road
    only drops the plan ahead.
  - `BuffCard` is the reward moment and the first-time explanation. Ratings carry `foresight`,
    `seconds_before_first_move`, `longest_pause` and `seconds_thinking` in their stats (never shown).
  - In `scripts/game.gd` it's everything named `_fs…`; the self-test is `--autosight --foresight=N`
    (`--foresight=-1` is Earned).
  - Not done: levels re-tuned for it (the engine's road view, not its plan view, is the measure of a
    player who can't plan with the ghost); strict detours (no undos) and speedruns are harsh with one
    bulb; target times for the speedruns so Lighthouse is more than "finished them".

## Tabled

- **Overtime**, an endless shift on one tank of miles (undo is free but doesn't refund miles). Possibly
  with roguelike elements, daily seeds and older seeds playable; possibly the main mode one day.
- **Special requests**: an optional second goal per level ("deliver the red one last"), generated from
  the solver. Needs maps with several solutions.
- **Level codes and an editor** for sharing levels with friends.
- **New mechanics**: cowcatcher (cross your own track once), paint station, roundabouts.
- **Per-level tester stats** (attempts, retries, time), with a privacy policy line, to calibrate the
  level scores against real players.

## Future ideas (Steven, 15 Nov): parked, no action yet

Monetization, if the game ever goes beyond friends (everything is pretend until then):

- **Checkpoints: built 15 Nov** (`scripts/checkpoint.gd`). One at the entrance to each zone after the
  first, the first time you start any job in it (tied to the zone, not a level, since levels can be
  skipped). One pretend ad, then +1 gas. Waved through if you've watched an ad since the last one. Senator
  Crumb's Committee on Roads in the fine print, a gold H on the inspector's clipboard. The tester option
  "Full license" stands in for premium.
- **The premium version** (not built: needs a decision on what it costs and does with gas ads) removes
  every ad, checkpoints included, branded as getting legal: a full
  commercial license, or hiring a lawyer who knows your rights and waves the van through. Fits the 14 Nov
  rule (the Baron never sells anything real): the lawyer sells it, not him. App Review needs the purchase
  screen to say plainly what it buys.
- **Leave a legacy.** After level 100, and/or for the top 1% furthest along, a chance to pay (about $10)
  to name and describe a cosmetic that gets added to an existing category, credited to them. Moderated:
  nothing offensive, and we draw it.

## Level engine follow-ups

See the end of `design/level_engine.md`. The first one matters most: after each build, note which levels
felt too easy or like a wall, and redo those slots (`python3 tools/engine/gen_all.py --seed 2 <slots>`).
