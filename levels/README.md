# Level format

All levels live in `levels.json` as `{"levels": [ ... ]}`. Order in the file = level number.

```json
{
  "title": "One Pass",
  "hint": "New rule: each road can only be used once!",
  "no_revisit": true,
  "map": [
    ". . . . .",
    ". # # # .",
    ". # y # .",
    "r # . # b",
    ". # # # .",
    ". . S . .",
    ". . . . ."
  ],
  "stack": ["blue", "yellow", "red"]
}
```

## `map`
One string per row, top to bottom. Cells are **space-separated tokens** (so multi-character
tokens like `r2` stay readable). Every row must have the same number of tokens.

| Token | Meaning |
|---|---|
| `.` | Block (grass; decorative trees are added automatically) |
| `#` | Road |
| `S` | Road where the van starts (exactly one) |
| `r` `b` `g` `y` `p` `o` | House: red, blue, green, yellow, purple, orange. Wants 1 package |
| `r2`, `b3`, ... | House wanting that many packages (multi-order; not used in levels 1–5 yet) |

Rules the loader checks (errors print at startup and in the validator):
- every house touches at least one road orthogonally;
- no house touches the `S` tile (the van only delivers on tiles it drives *onto*);
- total house orders per colour exactly match the stack.

## `stack`
Package colours, **first = bottom, last = top** (the top is delivered first). Full names
(`"red"`) or the single letters above both work.

## Other fields
- `title` — shown under the board.
- `hint` — one-line instruction shown under the board until the player starts drawing.
- `no_revisit` — `true` means each road tile can be used once per route. Default `false`.

## Adding a level
1. Add an object to `levels.json` where you want it in the sequence.
2. Run the validator — it must say `ok` and show ≥1 solution:
   ```
   godot --headless --path . --script res://tools/validate_levels.gd
   ```
3. To tune difficulty, try every stack order for that map (fewer solutions ≈ harder):
   ```
   godot --headless --path . --script res://tools/stack_orders.gd -- <level number>
   ```

On levels that allow revisits the number of possible routes is infinite, so the solver caps each
tile at 2 visits there; treat those counts as rough.
