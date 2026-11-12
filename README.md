# Last Mile (prototype)

One-thumb portrait puzzle: draw a route from the van and it drives it, delivering the **top**
package of its stack to each matching house it passes. Deliver everything to win.

Godot 4.7, GDScript, 1080×1920 portrait. 40 levels in two parts, 5 sneak-peek levels, and 10 daily puzzles.
- **Part 1 · The Suburbs (1–20):** stack order (1–2), the road tears up behind you so you can't cross
  your own tracks (3), planning a loop (4), undo (5), ×2 houses (7), one-way streets (9), bridges (13),
  then combinations.
- **Part 2 · The City (21–40):** parcel shops that load a parcel onto your stack (21), colour
  gates that only lift for the matching top package (25), finishing back at the depot (29),
  sorting hubs that swap your top two packages (33), then combinations.
- **Sneak Peek · The Long Haul (41–45):** huge, very hard levels showing what later chapters could feel
  like. Flagged `"preview": true`; a real release would hold these back.
- **Insane · Death Valley (46–50):** 25+ packages each. The van never holds more than 12 at once: the
  rest wait in **warehouses** along the way (a shop with a "×N" that loads all its parcels as you pass),
  so you have to make room before you collect.
- **Daily puzzle:** one a day from `levels/daily.json` (ten, repeating). Daily #1 was 2026-11-10.

## Run
- **Editor:** open `project.godot` in Godot 4.7 and press Play (F5).
- **Command line:**
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path .
  ```
  Add `-- --level=13` to jump straight to a level, `-- --select` to open the road-trip map
  (`--map-scroll=N` centres it on level N), `-- --dpad` to steer with the D-pad (`--lefty` for the
  left-hand pad), `-- --night` / `-- --landscape` to try those modes, `-- --stack=left|right|top|bottom`
  to put the chute there, `-- --peek` for the route preview, `-- --options` to open the options,
  `-- --notes` to open the patch notes, or `-- --no-intro` to skip the studio card.
- **Mac app:** Project → Export → macOS writes `build/Last Mile.app` (preset in `export_presets.cfg`).
- **iPhone (by cable):** plug it in, unlock it, then run `tools/install_ios.sh`. It exports the Xcode
  project, builds and signs it with team 7FR35W6Q64 (Xcode must be signed in to that account), installs
  it and opens it. The phone needs Developer Mode on (Settings → Privacy & Security).
- **TestFlight:** `tools/testflight.sh` exports, archives and uploads to App Store Connect, for
  internal testers only (`--external` allows outside testers, which needs Beta App Review;
  `--no-upload` just checks the archive builds). Create the app in App Store Connect first, with
  bundle ID `com.stevenhester.lastmile`. After each successful upload the script raises the build
  number in `export_presets.cfg`, since Apple won't accept the same one twice.

The game opens with the Door Bowl studio card (once a launch; tap to skip), which dives through its
little door into the title screen. Play continues from the first level you haven't completed.
The version badge in the title's top corner (with a NEW sticker after an update) opens the patch notes.

### Daily puzzle, streak and sharing
- Title → **Daily** shows today's puzzle, your streak (in fire) and the last week.
- A day counts toward the streak if you solve it with **at most 1 redo** (two attempts). Leaving and
  coming back counts as a redo too.
- Once solved, **Share** shows a card and copies an emoji summary (delivery order as coloured squares,
  time, stars, redos, streak) ending with an invite to ask you for a playtest. "Text it" opens Messages
  with it filled in.
- **Reminders** (iPhone, local notifications, nothing goes through a server): after your first daily
  solve the game asks once for permission. Then each day's puzzle gets a reminder at about the time of
  day you solved your last one (kept between 8am and 9pm), and, while a streak is alive, an evening
  "last call" a few hours later (7:30pm, or 3 hours after the reminder, never after 9:30pm). Solving
  today's clears today's. Rules: `scripts/notify.gd`; it writes `user://lastmile_notify.json`, which the
  native plugin `ios/plugins/LastMileNotify` (source in `ios/plugins/src`, rebuilt by
  `tools/build_notify_plugin.sh`, which `tools/testflight.sh` runs) hands to iOS.

### Presents and the garage
- Some levels have a **present** on the road. Drive over it and it's yours when you finish. The obvious
  route never touches it: it needs the other winning route, or driving on past your last delivery in the
  same drag ("the extra mile"). Undoing the drive that grabbed it puts it back.
- Map stops with a present still waiting show a little gift icon.
- Finding one pops up a big **NEW RIDE / PAINT JOB / TOPPER!** card over the finish screen, with
  **Wear it now** or **Keep my look**. Nothing is worn unless you pick it.
- Title → **Garage** to wear what you've found: **Kuma's Monster Truck** (a whole ride, level 6), 5 paint
  jobs and 6 toppers, mostly from Frontiers Celestia (Deep Field, Gloaming, Duskwood, Mosaic Moth,
  Drizzlet, Bonkle Ears, Sprout & Orbit, Rivet, Puffball), plus Racing Stripes and a Door Bowl soup bowl.

### Momentum and the finish
- Every win in a row this session (hints and undos are fine) adds **momentum**. A retry, or walking away
  from a level you've started, resets it. It isn't saved.
- The road the van has driven is **wreckage**: it drives so hard the asphalt tears up behind it
  (a gouged trench, a crater, flipped slabs and grit, with a crunch). With momentum the cracks glow in the
  fire's colours, and hot runs leave it burning.
- With momentum the van leaves a trail of anime fire as it drives: bigger, longer-lasting and hotter
  the higher it gets (orange, then red-gold at ×3, blue at ×6, violet "supernova" at ×8).
- Winning freezes the frame: focus lines, a slashed banner, the van punched in big, "DELIVERED!", then
  panels for time, stars and momentum, with the van engulfed in flames to match.

### Stars, gas, Dollaroos and the "ad" (all pretend)
- **Stars:** every win earns up to 3: one is lost for using a hint, one for using an undo. Best stars
  show on the level select (gold tile = all three).
- **Hint** (bottom row) shows your next move: a golden arrow from the van to the next turn of a winning
  route, or tells you there's no way through from where you are.
- **Gas tanks:** starting a level you haven't beaten costs one, and beating it hands it back. Retry
  costs one too, until the level's been beaten: after that, replaying it neither costs gas nor earns
  any. You hold up to 5 and one comes back every 20 minutes (by the clock, even while the game is
  closed). Restarting a level you haven't touched is free. The daily works the same way: a tank to start
  or retry until it's solved today.
- **Door Bowl Dollaroos** are play money: 100 per star the first time you earn it, 10 for a replay.
  Out of gas? The **+** by the gauge (or Retry) opens the gas station: a full tank for 1,500
  Dollaroos. If you're short it goes on your tab (a negative balance). **No real money is involved
  anywhere:** there's no store, payment or network code, only two numbers in the save file.
- **Undo:** one free per attempt, plus any spares. When you're out, the button greys out with a
  "+3 undos" badge: tapping it plays a **made-up ad for Frontiers Celestia** (drawn in code, no ad
  network, nobody is paid), skippable after 3 seconds, and you get 3 spare undos either way.

Progress is saved to `user://save.json`; "Reset progress" is under the depot at the start of the map.

### The map
Levels are stops on a road trip, from the depot up through Maple Suburbs, Downtown, Sunflower Farms,
Cactus Canyon, Pine Peaks and Seaside Lights, past a ROAD CLOSED barrier into the Long Haul sneak peek.
Your van waits at the next stop. Daily and Garage sit in the dock at the bottom; your daily streak burns
as a little flame inside the Daily button.

### How to play
- Press on the van and drag along roads. Drag back along the line to undraw it (a quick swipe back
  undraws several tiles).
- **Lift your finger and the van drives that segment.** Then press the van again to keep going
  from where it stopped.
- **The load** rides in a **package chute**: standing up beside the board (left by default) with its
  mouth at the bottom, or lying along the top or bottom of the board with its mouth at the right end
  (Options → Package chute; sideways play always has it on top). The **next** package sits in the
  mouth, a little bigger, lit gold, over "NEXT"; the rest queue up the tube in the order they'll go out.
  It works like a real van: the last one in is first out, so a collected parcel comes in at the mouth
  and pushes the others back. On delivery the next package drops out of the mouth into the van, then
  flies on to the house. Packages are wider than tall, and each colour is its own class with its own
  mark: red gifts (ribbon and bow), yellow biohazard, blue caution, purple mystery, green organic,
  orange hot. Houses next in line glow softly in their colour. Tap a package and the houses waiting for
  that colour wave. No level starts with more than 12 aboard or needs more than 12 at once; if a wrong
  turn past a warehouse overloads the van, the extra wait behind a "+N" at the back of the chute, and
  you can drag along the chute to scroll through them.
- **While you plot a route** the line is tinted with the package that'll be on top along each stretch,
  and houses the route will deliver to show a ghost tick. The chute shows the load as it'll be at the
  end of the route so far (so its mouth holds what's next from there). With **Route preview** on
  (Options; off by default) a little chip above the board's corner also shows the next three. Undraw,
  and the packages hop back aboard.
- **The start is a pit stop** (painted bay, tyre stacks, checkered line). On levels where you must end
  there, a checkered flag rides in the chute behind the last package.
- **Challenge levels** (5, 14, 20, 28, 32, 36, 45, 50) are a big step up from their neighbours. They
  wear a hazard-striped rim and a flame badge on the map, open with a hazard-tape "CHALLENGE!" intro
  (once a session, until beaten), and the first win goes big: "CHALLENGE CRUSHED!" and a 500 Dollaroo
  bonus. Each region's rhythm runs easy (a new idea, feel smart), moderate, then the spike.
- **You can't drive over your own wreckage** (or cross the route you're plotting). The line simply
  stops there with a red **X**; nothing you've drawn is lost. If you send the van off while pushing
  into the X, it drives your route and brakes hard just short of the wreckage ("WHOA!"), and the
  level carries on: if that drive delivered the last package, you've won.
- **Bridges:** across a bridge tile the line is dotted: that tile can still be crossed the other way.
- **D-pad option** (Options → Steering): a big pad in the corner of your thumb's hand (Options →
  D-pad hand, for lefties), with **DRIVE BABY DRIVE** just above it. Tap an arrow to plot one tile, hold
  it to keep going, roll your thumb onto another arrow to turn, press the way you came to undraw, the
  small **x** to clear; a ghost van shows where the route ends. The keys sink when pressed, ripple and
  tick on the phone, and a way that's blocked shakes and buzzes twice. Hint/Undo/Retry sit on the far
  side, and Hint takes two taps there ("Sure?") so a stray thumb can't spend a star. Arrow keys and
  Enter do the same on a keyboard.
- **Options** (the gear: bottom left in a level, top corner of the title and map): steering (draw or
  D-pad), which hand the D-pad is for, where the package chute goes, the route preview, **night mode**, **play sideways** (landscape: the board in the
  middle, the controls beside it; menus and pop-ups sit in a portrait column), sound volume, and haptic
  strength from none to max. Everything is saved and applies straight away.
- **Undo** (bottom right) rewinds your last segment, including its deliveries. **Once per attempt.**
- If the van has nowhere left to go before the level is done, you're stuck: Undo (if unused) or Retry.
- Part 2: **parcel shops** (striped awning, their stock bouncing in the window) put their parcel on top
  of your stack as you pass;
  **colour gates** lift only while your top package matches (they react as you draw);
  on **depot** levels (garage icon) you must finish parked where you started;
  **sorting hubs** (turntable) swap your top two packages.
- **One-way arrows:** you can turn onto an arrow tile from the side, but you must leave it the way it
  points, and you can never drive onto it against the arrow.
- Keys: `R` retry, `Z`/`U` undo, `H` hint, `Enter`/`N` next, `Esc` level select.
- Debug builds: `D`/`F3` toggles the solver overlay (or start with `-- --debug`); `S` auto-drives the shortest solution.

## Layout
| Path | What |
|---|---|
| `levels/levels.json` | Level data; format in [`levels/README.md`](levels/README.md) |
| `scripts/level_data.gd` | Parses one level (data only) |
| `scripts/sim.gd` | The rules: legal moves (one-way, bridges, gates, no-revisit, depot), deliveries, pickups, swaps. Shared by game and solver |
| `scripts/solver.gd` | DFS solver: solvability and number of winning routes |
| `scripts/board.gd`, `house.gd` | Rendering of the map (roads, arrows, bridges) and houses (with their queue-number tags) |
| `scripts/route_line.gd` | The route being plotted: tinted by the package on top, dotted across bridges |
| `scripts/wreckage.gd`, `crash_mark.gd` | The torn-up road behind the van, and the red X where a route runs into it |
| `scripts/dpad.gd` | The thumb pad for D-pad steering: keycaps, rolling between arrows, press feel (the ghost van and DRIVE button live in `game.gd`) |
| `scripts/options_menu.gd` | The options card: steering, hand, chute position, route preview, night mode, sideways play, sound, haptics |
| `scripts/version.gd`, `patch_notes.gd` | The version (title screen badge) and its patch notes card |
| `scripts/challenge_intro.gd` | The hazard-tape intro before an unbeaten challenge level (and its bonus) |
| `scripts/portrait_host.gd` | Sideways play: a portrait column in the middle of the screen for menus and pop-ups |
| `scripts/shop.gd`, `gate.gd`, `hub.gd`, `depot_glow.gd` | Part 2 pieces: parcel shops, colour gates, sorting hubs, depot |
| `scripts/van.gd`, `stack_view.gd`, `package_box.gd` | Van, its load (the package chute, next package in its mouth), packages |
| `scripts/peek_bubble.gd` | The route preview chip (an option): the next three packages at the end of the route |
| `scripts/game.gd` | Input, segments, driving, undo, juice, win/stuck, in-level UI |
| `scripts/main.gd`, `title_screen.gd`, `level_select.gd`, `road_map.gd` | Screen switching, title (with its little delivery loop), the road-trip level map |
| `scripts/progress.gd` | The save: completed levels, stars, gas tanks and their refill clock, spare undos, Dollaroos |
| `scripts/gas_chip.gd`, `coin_chip.gd`, `gas_shop.gd` | Gas gauge, wallet, and the pretend gas station |
| `scripts/fake_ad.gd`, `assets/ads/`, `audio/ad_chirp*.wav` | The made-up Frontiers Celestia ad (mark and chirps copied from that repo) |
| `scripts/finish_screen.gd`, `anime_fire.gd` | The freeze-frame level finish, and cel-shaded fire (the momentum trail and aura) |
| `scripts/daily.gd`, `daily_screen.gd`, `share_card.gd`, `levels/daily.json` | Daily puzzle: which is today's, the streak screen, the share card and its emoji text |
| `scripts/cosmetics.gd`, `gift.gd`, `garage.gd`, `unlock_card.gd` | Rides (the monster truck), paints and toppers; presents on the road; the garage; the "NEW RIDE!" card |
| `scripts/fx.gd`, `backdrop.gd`, `juicy_button.gd`, `icons.gd` | Sparkles and floating words, the drifting background, squashy buttons, code-drawn icons |
| `scripts/studio_card.gd`, `assets/fonts/Fredoka.ttf`, `audio/studio_*.wav` | Door Bowl studio intro, ported from Frontiers Celestia |
| `scripts/sfx.gd`, `sfx_synth.gd`, `audio/` | Sounds (synthesised placeholders) |
| `scripts/debug_auto.gd` | Command-line self-tests that play levels with injected mouse input |
| `tools/` | Headless scripts: level validator, single-level checker, generator, stack-order explorer, SFX generator, autotest runner, iOS icon maker, iPhone installer, TestFlight uploader |

## Tools and tests
```
# Every level parses and is solvable; --ablate shows whether arrows/bridges/gates/hubs matter
godot --headless --path . --script res://tools/validate_levels.gd -- --ablate

# Play every level (or a range) with injected input in several modes; prints a summary
tools/autotest_all.sh            # or: tools/autotest_all.sh 21 40 autoundo

# Generate candidate levels (see levels/README.md for options)
godot --headless --path . --script res://tools/generate.gd -- --w=6 --h=8 --n=5 --oneway=2

# Play one level with injected mouse drags; prints an AUTOTEST line and quits.
# (Autotests never write to your save file.)
# Modes: --autodrag (one drag per segment), --autoseg (extra segment breaks),
#        --autoundo (drive, undo, then finish), --autostuck (wander until stuck), --autoplay,
#        --autohint (press Hint and follow it until the level is won),
#        --autoshop (run dry, press Retry, buy a pretend tank), --autoad (open and skip the pretend ad),
#        --autogift (collect the level's present), --autochain=N (win N in a row via Next: momentum, gas),
#        --autodpad (plot with the D-pad, press DRIVE), --autobrake (drag into the wreckage: the line
#        stops, nothing's lost; send it anyway: the van brakes), --autoreplay (does Retry take gas?),
#        --autoscroll (drag along the chute; try with --load-demo=18)
#        --autoside (move the chute to each spot mid-level: on screen, clear of the board and words?)
#        Add --daily to play today's daily instead (--day=+N pretends it's N days later).
godot --headless --path . -- --level=12 --autoundo

# The gas refill sums
godot --headless --path . --script res://tools/test_gas.gd

# The daily-reminder schedule (times, evening last call, permission prompt)
godot --headless --path . --script res://tools/test_notify.gd

# Start from a made-up save without touching the real one (for screenshots and poking about)
# (`--load-demo=N` draws a pretend load of N packages in the chute, for looking at big loads.)
# keys: gas, coins, bank (spare undos), done (levels finished), momentum, streak (past dailies), owned:1,
#       wear:<item id> (own it and put it on, e.g. wear:monster_truck)
godot --path . -- --level=24 --save=gas:0,coins:350,bank:2,done:22

# Where presents could go on a level (alternate routes, or the extra mile)
godot --headless --path . --script res://tools/place_gifts.gd -- [levels/daily.json] [level numbers]

# Regenerate placeholder sounds into audio/ (replace any .wav with a real one, same name)
godot --headless --path . --script res://tools/gen_sfx.gd
```

## Phone
iPhone: see Run above (`tools/install_ios.sh`). The iOS icon is `assets/icon/ios_1024.png`, made from
`icon.svg` by `tools/make_ios_icon.gd`. Android would need its own preset and the Android SDK.
For Android haptics, enable the `VIBRATE` permission in the preset. Touch is handled via
Godot's mouse emulation, so there's no separate touch code path.
