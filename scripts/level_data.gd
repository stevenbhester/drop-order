class_name LevelData
extends RefCounted
## Parsed description of one level. Pure data: no rendering, no rules.
## The text encoding is documented in levels/README.md.

enum Cell { BLOCK, ROAD, HOUSE }

const COLOR_CODES := {
	"r": "red", "b": "blue", "g": "green", "y": "yellow", "p": "purple", "o": "orange",
}
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var number := 0
var title := ""
var hint := ""
var width := 0
var height := 0
var cells: Array = []            # Cell per index (y * width + x)
var houses: Array = []           # [{ "pos": Vector2i, "color": String, "order": int }]
var start := Vector2i.ZERO
var stack: Array = []            # colour names; first = bottom, last = top
var no_revisit := false
var adjacent_houses := {}        # road Vector2i -> Array[int] of house indices
var errors: Array = []


static func from_dict(d: Dictionary, num: int) -> LevelData:
	var L := LevelData.new()
	L.number = num
	L.title = str(d.get("title", ""))
	L.hint = str(d.get("hint", ""))
	L.no_revisit = bool(d.get("no_revisit", false))
	var rows: Array = d.get("map", [])
	L.height = rows.size()
	var starts := 0
	for y in rows.size():
		var toks: PackedStringArray = str(rows[y]).split(" ", false)
		if y == 0:
			L.width = toks.size()
			L.cells.resize(L.width * L.height)
		elif toks.size() != L.width:
			L.errors.append("row %d has %d cells, expected %d" % [y, toks.size(), L.width])
		for x in L.width:
			var t: String = toks[x] if x < toks.size() else "."
			var i := y * L.width + x
			match t:
				".":
					L.cells[i] = Cell.BLOCK
				"#":
					L.cells[i] = Cell.ROAD
				"S":
					L.cells[i] = Cell.ROAD
					L.start = Vector2i(x, y)
					starts += 1
				_:
					var code := t.substr(0, 1)
					if COLOR_CODES.has(code):
						L.cells[i] = Cell.HOUSE
						var order := 1
						if t.length() > 1:
							order = maxi(1, t.substr(1).to_int())
						L.houses.append({"pos": Vector2i(x, y), "color": COLOR_CODES[code], "order": order})
					else:
						L.cells[i] = Cell.BLOCK
						L.errors.append("unknown token '%s' at %d,%d" % [t, x, y])
	if starts != 1:
		L.errors.append("expected exactly one S, found %d" % starts)

	for c in d.get("stack", []):
		var s := str(c)
		L.stack.append(COLOR_CODES.get(s, s))

	# Road tile -> adjacent houses.
	for hi in L.houses.size():
		var hp: Vector2i = L.houses[hi].pos
		var touches_road := false
		for dir in DIRS:
			var rp := hp + dir
			if L.is_road(rp):
				touches_road = true
				if not L.adjacent_houses.has(rp):
					L.adjacent_houses[rp] = []
				L.adjacent_houses[rp].append(hi)
		if not touches_road:
			L.errors.append("house at %s touches no road" % hp)
	if L.adjacent_houses.has(L.start):
		L.errors.append("a house touches the start tile (ambiguous: van doesn't deliver before moving)")

	# Orders must match the stack exactly.
	var need := {}
	for h in L.houses:
		need[h.color] = need.get(h.color, 0) + h.order
	var have := {}
	for c in L.stack:
		have[c] = have.get(c, 0) + 1
	if need != have:
		L.errors.append("house orders %s don't match stack %s" % [need, have])
	return L


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func cell(p: Vector2i) -> int:
	return cells[p.y * width + p.x] if in_bounds(p) else Cell.BLOCK


func is_road(p: Vector2i) -> bool:
	return cell(p) == Cell.ROAD


func road_count() -> int:
	return cells.count(Cell.ROAD)
