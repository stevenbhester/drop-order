# Last Mile (prototype)

One-thumb portrait puzzle: draw a route from the van and it drives it, delivering the **top**
package of its stack to each matching house it passes. Deliver everything to win.

Godot 4.7, GDScript, 1080×1920 portrait. 100 levels in three parts plus an endgame, 38 daily puzzles,
side roads, and a speedrun mode.
- **Part 1 · The Suburbs (1–20):** stack order (1–2), the road tears up behind you so you can't cross
  your own tracks (3), planning a loop (4), undo (5), ×2 houses (7), one-way streets (9), bridges (13),
  then combinations.
- **Part 2 · The City (21–40):** parcel shops that load a parcel onto your stack (21), colour
  gates that only lift for the matching top package (25), finishing back at the depot (29),
  sorting hubs that swap your top two packages (33), then combinations.
- **Part 3 · The Long Road (41–90):** seven zones, each with a small, capped roster of mechanics: a new
  idea comes in and an old one steps out, so small maps keep feeling fresh instead of everything just
  getting bigger. **Ice** (no turning on it), **parcel lockers** (take whatever package is on top) and
  **roadworks** (open after N deliveries) arrive here.

  | Zone | Levels | Roster |
  |---|---|---|
  | Frostbite Pass | 41–47 | ice (new), one-way, ×N houses |
  | Harbour Lights | 48–54 | ice, pickups, bridges |
  | Neon Alley | 55–61 | lockers (new), gates, one-way |
  | Orchard Hills | 62–68 | lockers, pickups, back to the pit stop |
  | Detour City | 69–75 | roadworks (new), one-way, spinners |
  | Thunder Mesa | 76–83 | roadworks, ice, lockers |
  | Skyline Summit | 84–90 | roadworks, gates, pickups/warehouses, bridges |

  Every level is rated (`tools/twist_levels.gd --rate`: search size, route length, mechanics) and each
  zone is ordered like a training load rather than a straight ramp: a moderate intro for the new idea,
  mid-tier runs, a spike (the zone's challenge level), then a cooldown; easy ones as breathers. Not
  always in that order: Harbour Lights ends on a breather, Thunder Mesa saves its spike for last.
- **Endgame · The Long Haul (91–95):** huge, very hard levels, everything at once.
- **Insane · Death Valley (96–100):** 25+ packages each. The van never holds more than 12 at once: the
  rest wait in **warehouses** along the way (a pickup with a "+N" that loads all its parcels as you pass),
  so you have to make room before you collect. (These were 41–50 before Part 3; old saves move across.)
- **Daily puzzle:** one a day from `levels/daily.json` (38, repeating), each with its own spice (one to
  three chillies on the Daily screen: Mild, Medium, Spicy!). Daily #1 was 2026-11-10.
- **Speedrun** (title screen; opens after level 18): three courses of small puzzles against the clock.
  A course is a run of 3–5 zones: clear one, drive into its exit, the camera pans on and the next zone
  loads its own packages; the clock runs from 3-2-1-GO to the last delivery. No hints, no undos; Retry
  starts the course over. Each course keeps its best time. Courses are in `levels/speedrun.json`.

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
  `-- --notes` to open the patch notes, `-- --colorblind` for colorblind mode, `-- --side=small_tank`
  to play a side road, `-- --select --chest=20` to open a chest on the map, or `-- --no-intro` to
  skip the studio card.
- **Mac app:** Project → Export → macOS writes `build/Last Mile.app` (preset in `export_presets.cfg`).
- **iPhone (by cable):** plug it in, unlock it, then run `tools/install_ios.sh`. It exports the Xcode
  project, builds and signs it with team 7FR35W6Q64 (Xcode must be signed in to that account), installs
  it and opens it. The phone needs Developer Mode on (Settings → Privacy & Security).
- **TestFlight:** `tools/testflight.sh` exports, archives and uploads to App Store Connect, for
  internal testers only (`--external` allows outside testers, which needs Beta App Review;
  `--no-upload` just checks the archive builds). Create the app in App Store Connect first, with
  bundle ID `com.stevenhester.lastmile`. After each successful upload the script raises the build
  number in `export_presets.cfg`, since Apple won't accept the same one twice.
- **"A new version is out!":** each archive also writes `release/latest.json` (the build, version,
  name and up to three notes, via `tools/release_note.gd`): `Version.BUILD_NOTES` if it has any (what
  changed since the last build; the card then says "A fresh build is out!"), else the version's top
  patch notes. Once that's pushed, players' games
  read it from GitHub at launch (and when they come back after half an hour or more). If it's a newer
  build than theirs, the title shows an update card with an **Update in TestFlight** button, and the
  version badge wears an UPDATE sticker. A build is only offered an hour after its archive, so Apple has
  time to process the upload. If you archive a build and *don't* upload it, revert
  `release/latest.json`, or players get offered a build that isn't there. `-- --latest-file=<path>`
  tries the card with a local file.

The game opens with the Door Bowl studio card (once a launch; tap to skip), which dives through its
little door into the title screen. Play continues from the first level you haven't completed.
The version badge in the title's top corner (with a NEW sticker after an update) opens the patch notes.
When TestFlight has a newer build, the title offers it once a launch, and the badge wears an UPDATE
sticker and opens that offer instead.

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
- Title → **Garage** to wear what you've found: 5 rides (**Kuma's Monster Truck** from level 6's
  present; Zippy Scooter, Mr. Frosty, Rocket Van and Hover Van from the side roads), 6 paint jobs and 9
  toppers, mostly from Frontiers Celestia (Deep Field, Gloaming, Duskwood, Mosaic Moth, Drizzlet,
  Bonkle Ears, Sprout & Orbit, Rivet, Puffball), plus Racing Stripes, a Door Bowl soup bowl and the
  chest hats (Party Hat, Hard Hat, Gold Crown). Paint jobs work on every ride (Classic Cream leaves
  a ride in its own colours).

### Side roads and treasure chests
Little spurs branch off the road-trip map (all in `scripts/side_roads.gd` and `levels/side.json`):
- **Side roads** (a DETOUR sign showing the ride it wins) open once the level they branch off is beaten.
  Each is a short level with a twist, free to play and retry, with no hints or undos; the top bar
  shows how the twist stands. Beat it to win its ride:
  - **Small Tank** (after 6, the Zippy Scooter): the tank holds just the shortest route.
  - **Before It Melts** (after 17, Mr. Frosty): every delivery within 50 seconds.
  - **No Brakes** (after 24, the Rocket Van): plan the whole run, one drive, no stopping.
  - **Fog Bank** (after 33, the Hover Van): the load's shown for 6 seconds, then fog hides all but the
    next package.
- **Mega routes** (a MEGA ROUTE sign with a little grid of its parts): big deliveries in parts, like a
  big puzzle made of small ones. Each part is a level of its own: deliver everything, then finish on
  the exit, where the road carries on off the map through a red and white gate (shut until everything's
  delivered, then it swings open and chevrons run out along the road; the first one gets a tip). The van
  drives off through it and the camera pans on to the next part. Progress is
  saved after every part (come back later and you pick up there); the top bar shows "Part 2 of 4" over a
  mini-map of the parts. Hints and undos are allowed. **Twin Towns** (after 12, 2 parts side by side,
  wins the Blueprint paint) and **The Big Map** (after 27, a 2×2 loop of 4, wins Gold Rush).
- **Power-ups:** every side road (mega routes too) hands one out once a day when you win it: spare gas
  tanks (up to 3, shown as little cans by the gauge, used only when the tank's empty), or free hints or
  free undos for 10–15 minutes ("FREE" on the button; they cost no star).
- **Treasure chests** every ten levels (10–100): once that level's beaten, tap the chest to open
  it for gas and Dollaroos (a gas can that won't fit a full tank is cashed in), and at 20, 40, 70 and
  100 a hat (Party Hat, Hard Hat, Traffic Cone, Gold Crown).

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
- **What's this?** Tap (or hold) any symbol on the board (a one-way arrow, bridge, gate, spinner,
  pickup, house, exit, pit stop, present, torn-up road) for a one-line reminder with a little looping
  picture of the rule. Any tap or drag closes it. The second level with one-way streets says so
  ("Forgot what a symbol does? Tap it for a reminder").
- **The load** rides in a **package chute**. Auto (the default) puts it wherever gives the map the most
  room: beside the board on most small maps, along the top on wide ones like Death Valley (the first
  time it moves, a tip points it out). Standing up beside the board, it reads like a puzzle game's
  "next" column: NEXT and the next package at the top, level with the board's
  top, and the rest queued down under it in the order they'll go out. Along the top or bottom of the
  board it lies on its side with its mouth at the right end (Options → Package chute: Auto, or pin it left,
  right, top or bottom; sideways play always has it on top). The next package sits in a gold-framed window with a gold NEXT tag (half
  again as big as the rest in the side chute).
  It works like a real van: the last one in is first out, so a collected parcel comes in at the mouth
  and pushes the others along. On delivery the next package drops out of the mouth into the van, then
  flies on to the house. Packages are longer than they're wide, the long side along the chute (so
  it stays thin beside the board), and each colour is its own class with a faint
  stamp, just for flavour (the colour is what matters): red gifts (a pale ribbon), yellow biohazard,
  blue caution, purple mystery, green organic, orange hot. The places that want them match: red
  homes (a bow over the door), yellow labs (an observatory dome), blue factories (caution stripes on
  the door), purple towers (a crescent moon), green barns, orange diners (steam off the grill). A
  place wanting several shows a big "×N". Places next in line glow softly in their colour.
- **Colorblind mode** (Options; "aka Paul mode", for our colorblind playtester): the package marks go
  bold and white, and every building and colour gate gets the same mark on a round sign (on the
  building itself, never out over the road), so everything can be matched by shape alone. Tap a package and the houses waiting for
  that colour wave. No level starts with more than 12 aboard or needs more than 12 at once; if a wrong
  turn past a warehouse overloads the van, the extra wait behind a "+N" at the back of the chute, and
  you can drag along the chute to scroll through them.
- **Package trail** (Options; on by default): the next three packages after the one on the van's roof
  follow it on little drones, like a short snake's tail. They hover, so there's nothing to run into, and
  the trail is short and tight enough never to fold over itself. A glance at what's coming; the chute
  has the whole queue.
- **While you plot a route** the line is tinted with the package that'll be on top along each stretch,
  and houses the route will deliver to show a ghost tick. The chute shows the load as it'll be at the
  end of the route so far (so its mouth holds what's next from there). With **Route preview** on
  (Options; off by default) a little chip above the board's corner also shows the next three. Undraw,
  and the packages hop back aboard.
- **The start is a pit stop** (painted bay, tyre stacks, checkered line). On levels where you must end
  there, a checkered flag rides in the chute behind the last package.
- **Challenge levels** (5, 14, 20, 28, 32, 36, 47, 53, 58, 67, 73, 83, 90, 95, 100) are a big step up from their neighbours. They
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
- **Feedback / Bug report** (bottom of Options): "Tell Steven". Bug or idea, a few words, and
  "Include a screenshot" (ticked, with a preview of what was on screen). **Submit to Steven** sends it,
  with the game's recent log (file logging is on, iOS included) and device and game details, to the
  sign-up server (`POST /lm/feedback`), which files it as an issue in the private repo
  `stevenbhester/last-mile-feedback` (screenshot and full log stored alongside). The game never holds a
  GitHub token. A parcel hops to a mailbox until the server confirms; then "Got it!" with the report id,
  or what went wrong and Try again. `-- --feedback` opens it straight away; `--feedback-url=` points it
  at a test server. Under it, a **Privacy policy** link (https://www.stevenhester.com/last-mile/privacy/,
  in the `stevenhester-com` repo) and the version and build number.
- **Options** (the gear: bottom left in a level, top corner of the title and map): steering (draw or
  D-pad), which hand the D-pad is for, where the package chute goes, the route preview, **unlimited hints** (no ads), colorblind mode, **night mode**, **play sideways** (landscape: the board in the
  middle, the controls beside it; menus and pop-ups sit in a portrait column), sound volume, and haptic
  strength from none to max. Everything is saved and applies straight away.
- **Undo** (bottom right) rewinds your last segment, including its deliveries. **Once per attempt.**
- **Hint** shows the next stretch to drive (and costs a star). At a dead end it says so instead
  ("no way to win from here: Retry") and costs nothing; it never restarts anything itself. Each level
  comes with **3 hints** (the count is on the button). Out of them, Hint plays a pretend ad instead: one of
  the three trailers (`assets/ads/video/*.ogv`, rendered with `OGV=1 tools/ads/render.sh` and
  `OGV=1 tools/ads/render_gta.sh`), at random, with Skip there from the first frame. Watched or skipped,
  hints are then unlimited for the rest of the level. When the last hint goes, a tip by the button says
  so (only the first three times, and never once they've watched an ad). **Unlimited hints** in Options
  skips all that (a hint still costs a star). `-- --video-ad[=0|1|2]` plays one straight away.
- If the van has nowhere left to go before the level is done, you're stuck: Undo (if unused) or Retry.
- Part 2: **pickups** put their parcel on top of your stack as you pass. They look nothing like houses: a
  plain dark loading dock inside a chunky dashed outline in the parcels' colour, with big bouncing
  parcels out front, one for each it'll hand over, and a green "+N" (houses show "×N" for what they
  want). Planned to be collected, they hold still and fade; once collected, the dock's empty with a tick;
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
| `scripts/challenge_intro.gd` | The hazard-tape intro before an unbeaten challenge level (and its bonus) or a side road |
| `scripts/side_roads.gd`, `chest_card.gd` | Side roads (twist levels and mega routes from `levels/side.json`) and milestone chests; the chest opening |
| `scripts/exit_zone.gd`, `convoy.gd` | A mega route part's (or speedrun zone's) exit: the road on off the map and its gate; the package trail (drones behind the van) |
| `scripts/video_ad.gd`, `assets/ads/video/` | The pretend video ads that unlock unlimited hints |
| `scripts/update_check.gd`, `update_card.gd` | "A new version is out!": reads `release/latest.json` from GitHub and offers a newer TestFlight build |
| `scripts/feedback.gd`, `feedback_card.gd` | Feedback / Bug report: what a report carries (log, device, screenshot) and the card that sends it |
| `scripts/speedrun.gd`, `speedrun_screen.gd`, `countdown.gd` | Speedrun mode: courses, the course list, 3-2-1-GO |
| `scripts/roadworks.gd` | Roadworks on a road tile (counts down deliveries, then clears) |
| `tools/twist_levels.gd`, `make_mega.gd` | Design aids: add ice/lockers/roadworks to generated levels and rate difficulty (`--rate`); add exits for parted routes |
| `scripts/symbol_card.gd`, `tip_bubble.gd` | "What's this?" explainers for board symbols; one-time tips pointing at things |
| `ads/playable/` | The playable ad (one MRAID 2.0 HTML file for Tapjoy and co.; see its README) |
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
| `scripts/cosmetics.gd`, `gift.gd`, `garage.gd`, `unlock_card.gd` | Rides (monster truck, scooter, ice cream truck, rocket van, hover van), paints and toppers; presents on the road; the garage; the "NEW RIDE!" card |
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
#        --autoside (move the chute to each spot mid-level: on screen, clear of the board and words?),
#        --autotwist with --side=<id> (does that side road's twist bite? for a mega route: is part 1
#        saved once it's done?). A mega route's parts all run in one go (--side=big_map --autoplay).
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
