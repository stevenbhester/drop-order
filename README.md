# Last Mile (prototype)

One-thumb portrait puzzle: draw a route from the van and it drives it, delivering the **top**
package of its stack to each matching house it passes. Deliver everything to win.

Godot 4.7, GDScript, 1080×1920 portrait. 40 levels in two parts.
- **Part 1 · The Suburbs (1–20):** stack order (1–2), driving in segments (3), each road only
  once (4), undo (5), ×2 houses (7), one-way streets (9), bridges (13), then combinations.
- **Part 2 · The City (21–40):** parcel shops that load a parcel onto your stack (21), colour
  gates that only lift for the matching top package (25), finishing back at the depot (29),
  sorting hubs that swap your top two packages (33), then combinations.

## Run
- **Editor:** open `project.godot` in Godot 4.7 and press Play (F5).
- **Command line:**
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path .
  ```
  Add `-- --level=13` to jump straight to a level, `-- --select` to open the level select, or
  `-- --no-intro` to skip the studio card.
- **Mac app:** Project → Export → macOS writes `build/Last Mile.app` (preset in `export_presets.cfg`).
- **iPhone (by cable):** plug it in, unlock it, then run `tools/install_ios.sh`. It exports the Xcode
  project, builds and signs it with team 7FR35W6Q64 (Xcode must be signed in to that account), installs
  it and opens it. The phone needs Developer Mode on (Settings → Privacy & Security).

The game opens with the Door Bowl studio card (once a launch; tap to skip), which dives through its
little door into the title screen. Play continues from the first level you haven't completed.

Progress is saved to `user://save.json`; "Reset progress" is on the level-select screen.

### How to play
- Press on the van and drag along roads. Drag back to shorten the segment you're drawing.
- **Lift your finger and the van drives that segment.** Then press the van again to keep going
  from where it stopped. Roads already driven show a dark trail.
- **Undo** (bottom right) rewinds your last segment, including its deliveries. **Once per attempt.**
- If the van has nowhere left to go before the level is done, you're stuck: Undo (if unused) or Retry.
- Part 2: **parcel shops** (striped awning) put their parcel on top of your stack as you pass;
  **colour gates** lift only while your top package matches (they react as you draw);
  on **depot** levels (garage icon) you must finish parked where you started;
  **sorting hubs** (turntable) swap your top two packages.
- Keys: `R` retry, `Z`/`U` undo, `Enter`/`N` next, `Esc` level select.
- Debug builds: `D`/`F3` toggles the solver overlay; `S` auto-drives the shortest solution.

## Layout
| Path | What |
|---|---|
| `levels/levels.json` | Level data; format in [`levels/README.md`](levels/README.md) |
| `scripts/level_data.gd` | Parses one level (data only) |
| `scripts/sim.gd` | The rules: legal moves (one-way, bridges, gates, no-revisit, depot), deliveries, pickups, swaps. Shared by game and solver |
| `scripts/solver.gd` | DFS solver: solvability and number of winning routes |
| `scripts/board.gd`, `house.gd` | Rendering of the map (roads, arrows, bridges, trail) and houses |
| `scripts/shop.gd`, `gate.gd`, `hub.gd`, `depot_glow.gd` | Part 2 pieces: parcel shops, colour gates, sorting hubs, depot |
| `scripts/van.gd`, `stack_view.gd`, `package_box.gd` | Van, its load, packages |
| `scripts/game.gd` | Input, segments, driving, undo, juice, win/stuck, in-level UI |
| `scripts/main.gd`, `title_screen.gd`, `level_select.gd` | Screen switching, title (with its little delivery loop), level grid |
| `scripts/studio_card.gd`, `assets/fonts/Fredoka.ttf`, `audio/studio_*.wav` | Door Bowl studio intro, ported from Frontiers Celestia |
| `scripts/sfx.gd`, `sfx_synth.gd`, `audio/` | Sounds (synthesised placeholders) |
| `scripts/debug_auto.gd` | Command-line self-tests that play levels with injected mouse input |
| `tools/` | Headless scripts: level validator, single-level checker, generator, stack-order explorer, SFX generator, autotest runner, iOS icon maker, iPhone installer |

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
#        --autoundo (drive, undo, then finish), --autostuck (wander until stuck), --autoplay
godot --headless --path . -- --level=12 --autoundo

# Regenerate placeholder sounds into audio/ (replace any .wav with a real one, same name)
godot --headless --path . --script res://tools/gen_sfx.gd
```

## Phone
iPhone: see Run above (`tools/install_ios.sh`). The iOS icon is `assets/icon/ios_1024.png`, made from
`icon.svg` by `tools/make_ios_icon.gd`. Android would need its own preset and the Android SDK.
For Android haptics, enable the `VIBRATE` permission in the preset. Touch is handled via
Godot's mouse emulation, so there's no separate touch code path.
