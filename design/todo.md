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
4. **Fake ads.** Thirteen Hoardly Inc. spots are scripted; one tap skips, an option turns them off.
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

- Levels 5–100 regenerated with the new level engine (`design/level_engine.md`, `design/level_scores.md`).
- Drop-offs stand on a plain pale pad with a thin coloured rim and faint waves drifting in; pickups have
  waves going out to their square outline (so buildings pop off their pads).
- The cancel zone follows the finger even where it overlaps the Hint and Undo buttons.

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

## Tabled

- **Overtime**, an endless shift on one tank of miles (undo is free but doesn't refund miles). Possibly
  with roguelike elements, daily seeds and older seeds playable; possibly the main mode one day.
- **Special requests**: an optional second goal per level ("deliver the red one last"), generated from
  the solver. Needs maps with several solutions.
- **Level codes and an editor** for sharing levels with friends.
- **New mechanics**: cowcatcher (cross your own track once), paint station, roundabouts.
- **Per-level tester stats** (attempts, retries, time), with a privacy policy line, to calibrate the
  level scores against real players.

## Level engine follow-ups

See the end of `design/level_engine.md`.
