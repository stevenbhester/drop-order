# Last Mile (prototype)

One-thumb portrait puzzle: drag a route from the van, release, and it drives — delivering the
**top** package of its stack to each matching house it passes. Empty the van to win.

Godot 4.7, GDScript, 1080×1920 portrait. Status: core loop + levels 1–5.

## Run
- **Editor:** open `project.godot` in Godot 4.7 and press Play (F5).
- **Command line:**
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path .
  ```
  Add `-- --level=3` to jump straight to a level.

The game opens on the first level you haven't completed. Progress is saved to
`user://save.json`; "Reset progress" is on the level-select screen.

### Controls
- Press on the van and drag along roads; drag back over your route to retract it. Release to drive.
- Top bar: **Levels**, **Retry**. Keys: `R` retry, `Enter`/`N` next, `Esc` level select.
- Debug builds: `D`/`F3` toggles the solver overlay, `S` auto-drives the shortest solution.

## Layout
| Path | What |
|---|---|
| `levels/levels.json` | Level data — format in [`levels/README.md`](levels/README.md) |
| `scripts/level_data.gd` | Parses one level (data only) |
| `scripts/sim.gd` | The rules: route validity, deliveries, "nope"s. Used by both game and solver |
| `scripts/solver.gd` | DFS solver: solvability + number of winning routes |
| `scripts/board.gd`, `house.gd` | Rendering of the map and houses |
| `scripts/van.gd`, `stack_view.gd`, `package_box.gd` | Van, its load, packages |
| `scripts/game.gd` | Input, driving, juice, win/fail, in-level UI |
| `scripts/main.gd`, `level_select.gd` | Screen switching, level grid |
| `scripts/sfx.gd`, `sfx_synth.gd`, `audio/` | Sounds (synthesised placeholders) |
| `tools/` | Headless scripts: level validator, stack-order explorer, SFX generator |

## Tools
```
# Check every level parses and is solvable; prints solution counts
godot --headless --path . --script res://tools/validate_levels.gd

# Regenerate placeholder sounds into audio/ (replace any .wav with a real one, same name)
godot --headless --path . --script res://tools/gen_sfx.gd
```

## Phone
Uses Godot's standard export (Project → Export, add iOS/Android presets and templates).
For Android haptics, enable the `VIBRATE` permission in the preset. Touch is handled via
Godot's mouse emulation, so there's no separate touch code path.
