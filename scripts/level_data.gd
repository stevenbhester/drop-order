class_name LevelData
extends RefCounted
## Parsed description of one level. Pure data: no rendering, no rules.
## The text encoding is documented in levels/README.md.

enum Cell { BLOCK, ROAD, HOUSE, SHOP }

const COLOR_CODES := {
	"r": "red", "b": "blue", "g": "green", "y": "yellow", "p": "purple", "o": "orange",
}
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const ARROWS := {"^": Vector2i(0, -1), ">": Vector2i(1, 0), "v": Vector2i(0, 1), "<": Vector2i(-1, 0)}

var number := 0
var title := ""
var hint := ""
var width := 0
var height := 0
var cells: Array = []            # Cell per index (y * width + x)
var houses: Array = []           # [{ "pos": Vector2i, "color": String, "order": int }]
var shops: Array = []            # parcel shops: [{ "pos": Vector2i, "color": String, "count": int }] (count > 1: a warehouse)
var start := Vector2i.ZERO
var stack: Array = []            # colour names; first = bottom, last = top
var no_revisit := false
var return_depot := false        # must finish parked back on the start tile
var exit := Vector2i(-1, -1)      # a part of a mega route: must finish on this edge tile (token E)
var exit_way := Vector2i.ZERO     # which way that exit leads (from the route's layout; else from its edge)
var oneway := {}                 # road Vector2i -> Vector2i: the only direction it may be left (never entered against)
var bridges := {}                # road Vector2i -> true: crossable once per axis, straight through
var gates := {}                  # road Vector2i -> colour: enterable only with that colour on top
var hubs := {}                   # road Vector2i -> true: swaps the top two packages
var adjacent_houses := {}        # road Vector2i -> Array[int] of house indices
var adjacent_shops := {}         # road Vector2i -> Array[int] of shop indices
var house_roads: Array = []      # per house: Array[Vector2i] of touching road tiles
var shop_roads: Array = []       # per shop: Array[Vector2i] of touching road tiles
var gift := Vector2i(-1, -1)     # a road tile with a cosmetic on it (optional; not part of the rules)
var gift_item := ""              # Cosmetics id
var preview := false             # a sneak-peek level (harder than the release would have yet)
var challenge := false           # a spike: much harder than its neighbours (an intro, a badge, a big win)
var errors: Array = []
## The most a level may start with aboard, and the most its winning route may ever carry (the truck's
## comfortable size; bigger levels get their packages from warehouses along the way).
const MAX_LOAD := 12


static func from_dict(d: Dictionary, num: int) -> LevelData:
	var L := LevelData.new()
	L.number = num
	L.title = str(d.get("title", ""))
	L.hint = str(d.get("hint", ""))
	L.no_revisit = bool(d.get("no_revisit", true))
	L.return_depot = bool(d.get("return", false))
	L.preview = bool(d.get("preview", false))
	L.challenge = bool(d.get("challenge", false))
	var ew = d.get("exit_dir", null)
	if ew is Array and ew.size() == 2:
		L.exit_way = Vector2i(int(ew[0]), int(ew[1]))
	var g = d.get("gift", null)
	if g is Dictionary and g.get("at", null) is Array and g["at"].size() == 2:
		L.gift = Vector2i(int(g["at"][0]), int(g["at"][1]))
		L.gift_item = str(g.get("item", ""))
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
			L._parse_token(t, Vector2i(x, y))
			if t == "S":
				starts += 1
	if starts != 1:
		L.errors.append("expected exactly one S, found %d" % starts)

	for c in d.get("stack", []):
		var s := str(c)
		L.stack.append(COLOR_CODES.get(s, s))

	L._index_neighbours()
	L._validate()
	if L.gift_item != "":
		if not Cosmetics.ITEMS.has(L.gift_item):
			L.errors.append("gift: unknown item '%s'" % L.gift_item)
		elif not L.is_road(L.gift) or L.gift == L.start:
			L.errors.append("gift must be on a road tile other than S")
	return L


func _parse_token(t: String, p: Vector2i) -> void:
	var i := p.y * width + p.x
	cells[i] = Cell.ROAD
	match t:
		".":
			cells[i] = Cell.BLOCK
		"#":
			pass
		"S":
			start = p
		"E":
			exit = p
		"+":
			bridges[p] = true
		"@":
			hubs[p] = true
		"^", ">", "v", "<":
			oneway[p] = ARROWS[t]
		_:
			var code := t.substr(0, 1)
			if code == "=" and t.length() == 2 and COLOR_CODES.has(t.substr(1)):
				gates[p] = COLOR_CODES[t.substr(1)]
			elif COLOR_CODES.has(code):
				cells[i] = Cell.HOUSE
				var order := 1
				if t.length() > 1:
					order = maxi(1, t.substr(1).to_int())
				houses.append({"pos": p, "color": COLOR_CODES[code], "order": order})
			elif COLOR_CODES.has(code.to_lower()) and code == code.to_upper() and (t.length() == 1 or t.substr(1).is_valid_int()):
				# A parcel shop; with a number, a warehouse holding that many parcels.
				cells[i] = Cell.SHOP
				var count := 1
				if t.length() > 1:
					count = maxi(1, t.substr(1).to_int())
				shops.append({"pos": p, "color": COLOR_CODES[code.to_lower()], "count": count})
			else:
				cells[i] = Cell.BLOCK
				errors.append("unknown token '%s' at %d,%d" % [t, p.x, p.y])


func _index_neighbours() -> void:
	for hi in houses.size():
		house_roads.append(_touching(houses[hi].pos, adjacent_houses, hi))
	for si in shops.size():
		shop_roads.append(_touching(shops[si].pos, adjacent_shops, si))


func _touching(p: Vector2i, index: Dictionary, id: int) -> Array:
	var out := []
	for dir in DIRS:
		var rp := p + dir
		if is_road(rp):
			out.append(rp)
			if not index.has(rp):
				index[rp] = []
			index[rp].append(id)
	return out


func _validate() -> void:
	for hi in houses.size():
		_check_building("house", houses[hi].pos, house_roads[hi])
	for si in shops.size():
		_check_building("shop", shops[si].pos, shop_roads[si])
	for b in bridges:
		for dir in DIRS:
			if not is_road(b + dir):
				errors.append("bridge at %s needs road on all four sides" % b)
				break
	if has_exit():
		if exit.x != 0 and exit.y != 0 and exit.x != width - 1 and exit.y != height - 1:
			errors.append("the exit (E) must be on the map's edge")
		if return_depot:
			errors.append("a level can't have both an exit and a return to the depot")
	if bridges.has(start) or oneway.has(start) or gates.has(start) or hubs.has(start):
		errors.append("the start tile must be plain road")
	if adjacent_houses.has(start) or adjacent_shops.has(start):
		errors.append("a house/shop touches the start tile (the van only acts on tiles it drives onto)")

	# House orders must match the packages that exist (van stack + shop parcels) exactly.
	var need := {}
	for h in houses:
		need[h.color] = need.get(h.color, 0) + h.order
	var have := {}
	for c in stack:
		have[c] = have.get(c, 0) + 1
	for s in shops:
		have[s.color] = have.get(s.color, 0) + s.count
	if need != have:
		errors.append("house orders %s don't match packages (stack + shops) %s" % [need, have])
	if stack.size() > MAX_LOAD:
		errors.append("starts with %d packages aboard; the most is %d (use warehouses for more)" % [stack.size(), MAX_LOAD])


func _check_building(kind: String, p: Vector2i, roads: Array) -> void:
	if roads.is_empty():
		errors.append("%s at %s touches no road" % [kind, p])
	for rp in roads:
		if bridges.has(rp) or hubs.has(rp):
			errors.append("%s at %s touches a bridge/hub" % [kind, p])


func has_exit() -> bool:
	return exit != Vector2i(-1, -1)


## Which way the exit leads off the map.
func exit_dir() -> Vector2i:
	if exit_way != Vector2i.ZERO:
		return exit_way
	if exit.x == 0:
		return Vector2i(-1, 0)
	if exit.x == width - 1:
		return Vector2i(1, 0)
	if exit.y == 0:
		return Vector2i(0, -1)
	return Vector2i(0, 1)


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func cell(p: Vector2i) -> int:
	return cells[p.y * width + p.x] if in_bounds(p) else Cell.BLOCK


func is_road(p: Vector2i) -> bool:
	return cell(p) == Cell.ROAD


func road_count() -> int:
	return cells.count(Cell.ROAD)


## Parcels waiting in shops and warehouses at the start.
func total_parcels() -> int:
	var n := 0
	for s in shops:
		n += s.count
	return n


func total_orders() -> int:
	var n := 0
	for h in houses:
		n += h.order
	return n
