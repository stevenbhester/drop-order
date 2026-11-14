# Last Mile: agreed rule and feature changes (none built yet)

Agreed with Steven on 14 Nov 2026. What these mean for level design is in `level_redesign_brief.md`
§13–§18. Suggested build order: 1, 5, 6, 7, 3, 2, 4, 8.

The writing for sections 5–7 (ad scripts, the Baron's offers at each boss, the residents' reaction pool)
and two big swings awaiting Steven's decision are in a doc he is reviewing:
https://claude.ai/artifact/KxmfbsdURLeJeAGxMVm9wc. Read it (and his comments) before building any of them.

## 1. Undo becomes reverse miles

- One road tile is one mile. Each level has a budget of miles you can take back, in as many goes as you
  like. Tap Undo: back one segment. Hold Undo: the van reverses tile by tile, the road repairing, until
  you let go.
- Starting budget scales with the level (about half its winning route; tune by playtest). Chests, keys and
  bosses add bonus miles for good. The ad still gives unlimited for that level.
- **The meter shows base and bonus apart**, so pickups feel like they matter: a bar on the Undo button,
  base in blue, bonus in gold, with the miles left as the badge. At level start the gold pops on after the
  base ("+3 mi" with the icon of where it came from). Base is spent first; dipping into gold sparkles, so
  the bonus is felt at the moment it saves you.
- Reversing costs no star. Hints and the ad top-up still do.
- **Option "Undo style":** Distance allowance (default) or Segment allowance (a number of undos per
  level; each bonus tier adds one undo instead of miles).
- Build notes: `Sim.run(level, route_prefix)` gives the state at any tile; the rewind animation and
  putting a present back already exist (`game.gd`, REWINDING).

## 2. Dispatch (earned late, opt-in)

- One call per level: "can this route still win?" Dispatch answers yes or no in one line and never shows
  the way. No star cost. That's its edge over a hint.
- UI: a small radio chip above the Hint button, only once it's earned and switched on in Options; greyed
  after use. The answer is a speech bubble from the radio ("You're good, keep going." / "No way through
  from there. Back it up.").
- Explained once, on the card that awards it: "Dispatch radio. Once a level, ask if your route can still
  win. It costs no star, and it won't tell you the way."
- Dispatch is our own dispatcher: a friendly voice, the opposite of the Baron.
- No automatic dead-end signal. Noticing you're doomed stays part of the puzzle.

## 3. Diner checkpoints (staged districts)

Spec for the level designer is in the brief, §14. In short: finish every delivery in a district with an
empty van, park at the diner, the road crew repairs the roads, the next load is waiting there. Sometimes
the camera zooms out and the next district is a ring of new roads and buildings round the old one. No
carrying packages past a diner (it would be guesswork: you can't see where they're going).

## 4. Overtime, an endless shift (Steven's version; still to workshop)

- One tank of fuel for the whole run, measured in miles. Every tile driven burns one. Undo is free and
  unlimited but only moves the van back: the miles stay spent. The run ends on your last mile.
- Maps are open, with many ways to win: obvious long ones and clever short ones (the Free run flavour,
  brief §15). Any win moves you on; a better win keeps you going longer. There's no single right answer,
  so no need to solve the whole map before starting.
- Ideas to test: each job pays its shortest route in miles, quoted up front (waste comes out of your
  tank); the Baron raises the price of gas every few jobs, so every run ends eventually; reuse Small
  Tank's fuel gauge; a daily run on one seed for everyone, to compare with friends.
- Generator needs: many solutions, with a wide spread between the shortest and the typical length.
- Steven is tempted to make more of this later (roguelike elements, daily seeds, older seeds still
  playable, perhaps as the main way to play), but it's tabled: no big builds for now.

## 5. Residents

Tiny code-drawn people at each house, moving only on events (cheap). They react to your route:
- delivered: out the door, cheering;
- your plan will deliver here: at the door early;
- you drive past with the wrong colour on top: a hopeful look, then a slump (this also teaches the rule);
- the road outside turns into your trail: one small gag per trail, once per house (fishing in the river,
  a marshmallow over the lava, a scorecard for the meteor, a slammed door for zombies, a butterfly net
  for the burning money). Delivery reactions come first, because they carry information; trail gags are
  for houses that are done, and never cover the road or the house;
- level failed: heads shake.

## 6. The Baron, early, with a job to do

No story beats and no dialogue outside boss fights. His job early on is to **mark new rules**: the level
that introduces a mechanic opens with a two-second sting of him (or a Hoardly truck) planting it: a
one-way sign, a dug-up road, a toll gate. Players learn "the Baron showed up, so there's a new rule here."
Instantly skippable. His logo also sits on the frictions (gas pumps, the GPS, the ads). **Slated for build
23 as a test on a build that isn't published** (internal testers only).

## 7. Fake ads

- More of them, worth watching: deadpan corporate spots for Hoardly Inc., in the spirit of Better Off
  Ted's Veridian Dynamics ads (original writing, not copies). "Hoardly Gas. It's the only gas. We made
  sure." "Hoardly Roadworks. We dig so you can't."
- One tap anywhere skips, straight away. An option turns fake ads off (the reward is then instant).

## 8. Go Independent (one purchase)

Free to start; one purchase removes real ads and gas limits for good. Rewarded real ads for everyone else
at the moments that already exist (hints, reverse miles, gas). Fake ads stay for buyers who want them.
Needs App Store setup and a privacy policy rewrite; decide before a public release. The purchase screen
is plain and never in the Baron's voice: he doesn't sell anything real (Steven, 14 Nov).

## 9. Long term

Level codes to share with friends, then perhaps an editor.
