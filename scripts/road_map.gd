class_name RoadMap
extends Control
## The level select as the dispatch board: a cork board with a city map sheet pinned up for each district,
## a job ticket pinned where each level is, and red string from ticket to ticket for the route driven (pencil
## for the route still to come). Detours are sticky notes off to the side; a district still closed has the
## Baron's tape across the string and its sheets fade under paper. (It was a road trip; the class keeps its
## name and its layout: one route from the depot at the bottom, level 1, up through the districts.) Drag or fling to scroll (mouse wheel too); tap a stop to
## play it. The van waits at the next stop to play, and the road it has already travelled looks driven.
## Past the "road closed" barrier at the top are the sneak-peek levels.
##
## Everything is drawn in code in "world" space (1080 wide, y down, level 1 near the bottom); `scroll` is
## the world y shown at the top of this control.

signal stop_pressed(index: int)
signal reset_pressed
## A side road's sign (SideRoads) or a milestone chest was tapped.
signal side_pressed(id: String)
signal chest_pressed(level_number: int)
## The van's drive to the next stop (drive()) is over (or was tapped through).
signal drive_done
signal intro_done
signal reveal_done
## The zone-opening show's over (open_zone).
signal zone_open_done

const W := 1080.0
const SPACING := 245.0           # road distance between stops (vertically)
const REGION_GAP := 170.0        # extra room at a region border, for its sign
const BARRIER_GAP := 260.0       # extra room before the sneak peek
const SWING := 300.0             # how far the road winds left and right of centre
const PIN_R := 58.0
const ROAD_W := 74.0
const SUBDIV := 16
const SPUR_LEN := 215.0
const SPUR_W := 50.0
const SIDE_COL := Color("2fb49a")
const PEEK := Color("7b5cff")
## Challenge jobs' hazard colours (and the Baron's tape).
const HAZARD := Color("ffc93c")
const HAZARD_INK := Color("2b2233")

## Regions in order up the map. `ground` is the land colour, `kind` picks the scenery.
const REGIONS := [
	# Every zone ends on a boss fight (Boss.is_level), so each ends on its hardest job, and a zone's new
	# idea is introduced by its first.
	{"name": "Maple Suburbs", "from": 1, "to": 11, "kind": "suburbs", "ground": Color("bfe3a0")},
	{"name": "Downtown", "from": 12, "to": 16, "kind": "city", "ground": Color("d6dbe0")},
	{"name": "Sunflower Farms", "from": 17, "to": 20, "kind": "farm", "ground": Color("e9de94")},
	{"name": "Cactus Canyon", "from": 21, "to": 28, "kind": "canyon", "ground": Color("f4c993")},
	{"name": "Pine Peaks", "from": 29, "to": 32, "kind": "peaks", "ground": Color("b7dcc3")},
	{"name": "Seaside Lights", "from": 33, "to": 40, "kind": "sea", "ground": Color("f7e6b8")},
	# Part 3: each zone brings a new idea and retires an old one (see levels/README.md).
	{"name": "Frostbite Pass", "from": 41, "to": 47, "kind": "peaks", "ground": Color("e4eff8")},
	{"name": "Harbour Lights", "from": 48, "to": 54, "kind": "sea", "ground": Color("d2e9e6")},
	{"name": "Neon Alley", "from": 55, "to": 61, "kind": "city", "ground": Color("cfc8ea")},
	{"name": "Orchard Hills", "from": 62, "to": 68, "kind": "farm", "ground": Color("d3e8a8")},
	{"name": "Detour City", "from": 69, "to": 75, "kind": "city", "ground": Color("e4d8c6")},
	{"name": "Thunder Mesa", "from": 76, "to": 83, "kind": "canyon", "ground": Color("ebbd92")},
	{"name": "Skyline Summit", "from": 84, "to": 90, "kind": "peaks", "ground": Color("cbd9ea")},
	{"name": "The Long Haul", "from": 91, "to": 95, "kind": "night", "ground": Color("2c2457"),
		"title": "Endgame · The Long Haul", "note": "Everything at once. Very hard!"},
	{"name": "Death Valley", "from": 96, "to": 100, "kind": "night", "ground": Color("3b1426"),
		"title": "Insane · Death Valley", "note": "25+ packages each. Bring snacks."},
]

var levels: Array = []
## Room the overlays (top bar, bottom dock) cover, so the ends of the map can be scrolled clear of them.
var pad_top := 200.0
var pad_bottom := 300.0
var scroll := 0.0

var world_h := 0.0
var stops: Array = []            # Vector2 per level
var road := PackedVector2Array() # sampled centre line, depot first
var road_len := PackedFloat32Array()
var stop_sample: Array = []      # index into `road` of each stop
var regions: Array = []          # {def, first, last, y0 (top), y1 (bottom)}
var signs: Array = []            # {pos, region index}
var barrier := Vector2.INF
## Zone toll gates: {zone, pos, lift (0 down .. 1 up)}. A tapped locked stop flashes its gate's sign.
var gates: Array = []
var _gate_flash := -1
var _gate_flash_t := 0.0
## A zone being opened (open_zone): its tape strains, snaps and swings away, the fog rolls back up the map,
## a banner says so. `_opening_t` is when it started (map time); `_open_said` once it's told whoever's waiting.
var _opening := -1
var _opening_t := 0.0
var _open_said := true
## A zone kept shut whatever its checkpoint says (LevelSelect, from the checkpoint's end until open_zone,
## so the gate never blinks open under the card as it closes).
var held := -1
## The map's in the middle of a sequence (LevelSelect.advance): its tickets, chests and gates take no taps.
var busy := false
var _open_booth := false         # (a checkpoint stood at it: its boom swings up too)
var _open_puff := 0.0
var _fx: Fx
var _note := ""                  # a word about a tap that did nothing (a job not reached yet), by where it was
var _note_at := Vector2.ZERO
var _note_t := -10.0
var _cp_rect := Rect2()          # the held gate's sign, on screen (a tap on it pulls up to the checkpoint)
var _cp_first := -1              # ...and the first job past it
var _drive_pop := true           # the drive ends at a stop (its ticket pops)
var depot := Vector2.ZERO
var scenery: Array = []          # {kind, pos, s, seed, col}
var clutter: Array = []          # the board's odds and ends: {kind, pos, rot, seed}
## Side roads branching off at some stops: {kind ("side" or "chest"), n (the stop's level), a (the stop),
## b (the end), and for side roads id and def; shake (a locked one shakes its head)}.
var spurs: Array = []
var _pressed_spur := -1
var _intro := -1                 # the first detour's intro: which spur it's showing (-1: none)
var _intro_t := 0.0
## The intro was put away by a tap on the detour itself (LevelSelect: its card's coming, not the next job's).
var intro_took_detour := false
var _reveal := -1                # a detour just revealed: which spur is drawing itself in (-1: none)
var _reveal_t := 0.0
var next := 0                    # next level to play (index); -1 when every level is done
var here := 0                    # where the van waits: the last level played (Progress.map_here), else next
## "Back to level N": a chip at the top that brings the van (and the map) back to `next` when it's elsewhere.
var _back_rect := Rect2()
var _back_k := 0.0
var _chip: Control
var van: Van
# The drive to the next stop after a win: along the road from one distance to another.
var _drive_from := 0.0
var _drive_to := 0.0
var _drive_t := -1.0
var _drive_dur := 1.0
var _pop_stop := -1
var _pop_t0 := 0.0

var _t := 0.0
var _vel := 0.0
var _down := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _pressed := -1
var _last_motion := 0
var _reset_rect := Rect2()


func setup(lvls: Array) -> void:
	levels = lvls


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	next = Zones.frontier(levels)
	here = next
	if Progress.map_here >= 0 and Progress.map_here < levels.size() and Progress.map_here != next:
		here = Progress.map_here
	_layout_world()
	_scatter()
	_scatter_clutter()
	van = Van.new()
	van.size = 150.0
	van.inviting = next >= 0
	add_child(van)
	_fx = Fx.new()
	add_child(_fx)
	if Progress.zone_opened >= 0:
		# A zone just opened: the show, unless its checkpoint's still to pass (then that comes first, and
		# whoever takes them through it calls open_zone).
		var zk := Progress.zone_opened
		Progress.zone_opened = -1
		if not Checkpoint.holds(zk):
			open_zone(zk)
	_chip = Control.new()
	_chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.draw.connect(_draw_back_chip)
	add_child(_chip)
	_park_van()


## Where the stops, road, regions and signs go.
func _layout_world() -> void:
	var y := 0.0
	var phase := 0.6
	var ys: Array = []
	var prev_region := -1
	for i in levels.size():
		var r := _region_of(levels[i].number)
		if i > 0:
			y -= SPACING
			if r != prev_region:
				y -= REGION_GAP
				if REGIONS[r].has("title"):
					y -= BARRIER_GAP
		prev_region = r
		phase += 1.05
		stops.append(Vector2(W / 2.0 + SWING * sin(phase), y))
		ys.append(y)
	# Shift so the top of the world (the end of the road) is y = 0.
	var top: float = (ys.back() if not ys.is_empty() else 0.0) - 380.0
	for i in stops.size():
		stops[i] = Vector2(stops[i].x, stops[i].y - top)
	depot = Vector2(W / 2.0, (stops[0].y if not stops.is_empty() else 600.0) + 400.0)
	world_h = depot.y + 330.0

	# The road: depot, every stop, then on up off the top of the map. Catmull-Rom between them.
	var ctrl: Array = [depot, depot + Vector2(0, -120)]
	for p in stops:
		ctrl.append(p)
	var end_x: float = W / 2.0 + SWING * sin(phase + 1.05)
	ctrl.append(Vector2(end_x, 120.0))
	ctrl.append(Vector2(end_x, -200.0))
	road = PackedVector2Array()
	for j in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(j - 1, 0)]
		var p1: Vector2 = ctrl[j]
		var p2: Vector2 = ctrl[j + 1]
		var p3: Vector2 = ctrl[mini(j + 2, ctrl.size() - 1)]
		for k in SUBDIV:
			road.append(p1.lerp(p2, float(k) / SUBDIV))   # string runs straight from pin to pin
	road.append(ctrl.back())
	road_len = PackedFloat32Array()
	var acc := 0.0
	for i in road.size():
		if i > 0:
			acc += road[i].distance_to(road[i - 1])
		road_len.append(acc)
	stop_sample = []
	for i in stops.size():
		stop_sample.append((i + 2) * SUBDIV)

	# Regions and their signs.
	for r in REGIONS.size():
		var first := -1
		var last := -1
		for i in levels.size():
			if _region_of(levels[i].number) == r:
				if first < 0:
					first = i
				last = i
		if first < 0:
			continue
		regions.append({"def": REGIONS[r], "first": first, "last": last, "y0": 0.0, "y1": world_h})
	for k in regions.size():
		if k > 0:
			var below: Dictionary = regions[k - 1]
			var here: Dictionary = regions[k]
			var border: float = (stops[below["last"]].y + stops[here["first"]].y) / 2.0
			below["y0"] = border
			here["y1"] = border
	# A toll gate across the road where each zone starts (it's lifted once the zone's open).
	for k in regions.size():
		if k == 0:
			continue
		var reg0: Dictionary = regions[k]
		var zk := Zones.of(levels[reg0["first"]].number)
		gates.append({"zone": zk, "pos": _road_point_at_y(reg0["y1"] - 10.0), "lift": 1.0 if Zones.is_open(zk) else 0.0})
	for k in regions.size():
		var reg: Dictionary = regions[k]
		var def: Dictionary = reg["def"]
		# The sign stands just inside the region, beside the road (on whichever side is clear).
		var sy: float = (reg["y1"] if k > 0 else stops[reg["first"]].y + 150.0) - 95.0
		if def.has("title"):
			sy = reg["y1"] - 150.0
		if def.get("barrier", false):
			barrier = _road_point_at_y(reg["y1"] + 60.0)
		var rx := _road_point_at_y(sy).x
		var sx := 290.0 if rx > W / 2.0 else W - 290.0
		signs.append({"pos": Vector2(sx, sy), "region": k})
	_layout_spurs()


## A dirt road off the route for each side road and chest: it forks from the road halfway between the job
## that unlocks it and the next one (where the van drives past it, and the Next card offers it), and runs
## out sideways to its ticket, toward whichever side is clearer (out from the middle, back in from the
## edges), clear of both jobs' tickets and the region signs. `a` is the fork, `b` the ticket.
func _layout_spurs() -> void:
	var want := []
	for d in SideRoads.defs():
		want.append({"kind": "side", "id": str(d.get("id", "")), "def": d, "n": int(d.get("after", 0))})
	for n in SideRoads.CHESTS:
		want.append({"kind": "chest", "n": int(n)})
	for sp in want:
		var i: int = sp["n"] - 1
		if i < 0 or i >= stops.size():
			continue
		var at: Vector2 = stops[i]
		var a := at
		if i + 1 < stops.size():
			a = road[(int(stop_sample[i]) + int(stop_sample[i + 1])) / 2]
		var dx := a.x - W / 2.0
		var dir := signf(dx) if absf(dx) < 200.0 else -signf(dx)
		if dir == 0.0:
			dir = 1.0
		var b := Vector2.INF
		for d in [dir, -dir]:
			# Far enough out to clear the jobs either side of the fork (their tickets are ~200 wide).
			var bx: float = a.x + d * SPUR_LEN
			for j in [i, i + 1]:
				# (A chest stands well clear of both jobs, so it reads as on the road between them, not as part of
				# the next one: whose ticket is the big "next up" one more often than not.)
				var clear := 300.0 if sp["kind"] == "chest" else 215.0
				if j < stops.size() and absf((stops[j] as Vector2).y - a.y) < 190.0:
					bx = maxf(bx * d, ((stops[j] as Vector2).x + d * clear) * d) * d
			var cand := Vector2(bx, a.y - 10.0)
			var near_sign := false
			for sg in signs:
				if (sg["pos"] as Vector2).distance_to(cand) < 200.0:
					near_sign = true
			if bx >= 110.0 and bx <= W - 110.0 and not near_sign:
				b = cand
				break
		if b == Vector2.INF:
			# No room off the fork: beside the job itself, as before.
			a = at
			b = at + Vector2(dir * SPUR_LEN, -36.0)
			b.x = clampf(b.x, 110.0, W - 110.0)
		sp["a"] = a
		sp["b"] = b
		sp["shake"] = 0.0
		spurs.append(sp)


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _region_of(number: int) -> int:
	for r in REGIONS.size():
		if number >= REGIONS[r]["from"] and number <= REGIONS[r]["to"]:
			return r
	return 0 if number < REGIONS[0]["from"] else REGIONS.size() - 1


## The road point nearest height y.
func _road_point_at_y(y: float) -> Vector2:
	var best := road[0]
	var bd := INF
	for p in road:
		var d := absf(p.y - y)
		if d < bd:
			bd = d
			best = p
	return best


func _region_at_y(y: float) -> int:
	for k in regions.size():
		if y >= regions[k]["y0"] and y < regions[k]["y1"]:
			return k
	return 0 if y >= world_h / 2.0 else regions.size() - 1


## Seeded scenery for every region, kept clear of the road, the stops and the signs.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	# Road samples bucketed by height, for quick "too close to the road?" checks.
	var buckets := {}
	var pts: Array = Array(road)
	for sp in spurs:
		for k in 11:
			pts.append((sp["a"] as Vector2).lerp(sp["b"], k / 10.0))
	for p in pts:
		var b := int(p.y / 100.0)
		if not buckets.has(b):
			buckets[b] = []
		buckets[b].append(p)
	var cell := 128.0
	var gy := 40.0
	while gy < world_h - 40.0:
		var gx := 50.0
		while gx < W - 30.0:
			var pos := Vector2(gx + rng.randf_range(-40.0, 40.0), gy + rng.randf_range(-40.0, 40.0))
			gx += cell
			var k := _region_at_y(pos.y)
			var kind: String = regions[k]["def"]["kind"]
			var item := _pick(kind, rng)
			if item == "":
				continue
			var big := item in ["mountain", "mesa", "building", "field", "water", "skyline", "lighthouse"]
			var clear := 92.0 if big else 70.0
			if _near_road(pos, clear + ROAD_W * 0.5, buckets):
				continue
			var bad := false
			for s in stops:
				if pos.distance_to(s) < 120.0:
					bad = true
					break
			for sp in spurs:
				if pos.distance_to(sp["b"]) < 130.0:
					bad = true
			for sg in signs:
				var sp: Vector2 = sg["pos"]
				if absf(pos.x - sp.x) < 270.0 and pos.y > sp.y - 150.0 and pos.y < sp.y + 120.0:
					bad = true
			if barrier != Vector2.INF and pos.distance_to(barrier) < 200.0:
				bad = true
			if pos.distance_to(depot) < 230.0 or pos.y > world_h - 120.0:
				bad = true
			if bad:
				continue
			if rng.randf() < 0.78:
				continue      # the sheets are printed maps, not crowded with things: keep it sparse
			scenery.append({"kind": item, "pos": pos, "s": rng.randf_range(0.85, 1.2), "seed": rng.randf() * 100.0,
				"col": rng.randi_range(0, 5), "flip": rng.randf() < 0.5})
		gy += cell * 0.8
	scenery.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)


## The story, pinned up district by district: what we've found out about the Baron so far. One or two
## things per district, further in the further you get (the fog hides the rest until it's open). Kinds: a
## newspaper clipping (a headline), a sticky note (our handwriting), a letter (his), a photo (with a caption).
const LORE := [
	[["clip", "LOCAL COURIER OPENS: 'WE DELIVER'"], ["photo", "day 1", "van"]],
	[["clip", "HOARDLY INC. BUYS DOWNTOWN DEPOT"], ["note", "Baron called again. Said no."]],
	[["letter", "Dear Last Mile, Hoardly Inc. will pay one million for your van. Think it over. — B.V.B."]],
	[["clip", "TOLL BOOTHS APPEAR OVERNIGHT"], ["photo", "who's this?", "grey"]],
	[["note", "Grey van again. Same plate: HRDLY 1"]],
	[["photo", "his yacht", "yacht"], ["clip", "BARON BUYS THE FERRY"]],
	[["clip", "HOARDLY GAS: PRICES TRIPLE"], ["note", "Mr. Frosty says the Baron owns the roads up here too"]],
	[["note", "Harbour keeper: his ships carry nothing. Empty boxes. Why?"]],
	[["clip", "A HOARDLY LOCKER ON EVERY CORNER"], ["letter", "Every courier in this city works for me. Except one. — B.V.B."]],
	[["letter", "FINAL OFFER. Sell, or I'll make every order undeliverable. — B.V.B."]],
	[["clip", "ROADWORKS 'FOR YOUR OWN GOOD', SAYS BARON"], ["photo", "his trucks digging", "grey"]],
	[["note", "Found his order book. Every job we get, HE placed. He's paying us to fail."]],
	[["photo", "Hoardly Tower", "tower"], ["clip", "BARON: 'THE LAST MILE IS MINE'"]],
	[["note", "If we finish the route, he's out of moves."]],
	[["clip", "LAST INDEPENDENT COURIER REFUSES TO SELL"], ["photo", "still here", "van"]],
]


func _scatter_clutter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	for k in regions.size():
		var reg: Dictionary = regions[k]
		var items: Array = LORE[k] if k < LORE.size() else []
		var y0: float = reg["y0"] + 140.0
		var y1: float = reg["y1"] - 140.0
		for item in items:
			# Find a clear spot in the district: away from the tickets, the string, notes and signs.
			for attempt in 60:
				var pos := Vector2(rng.randf_range(150.0, W - 150.0), rng.randf_range(y0, y1))
				var ok := true
				for st in stops:
					if pos.distance_to(st) < 230.0:
						ok = false
				for sp in spurs:
					if pos.distance_to(sp["b"]) < 230.0:
						ok = false
				for sg in signs:
					if pos.distance_to(sg["pos"]) < 240.0:
						ok = false
				for cl in clutter:
					if pos.distance_to(cl["pos"]) < 260.0:
						ok = false
				for j in range(0, road.size(), 4):
					if pos.distance_to(road[j]) < 130.0:
						ok = false
						break
				if ok:
					clutter.append({"kind": item[0], "text": item[1], "extra": item[2] if item.size() > 2 else "", "pos": pos,
						"rot": rng.randf_range(-0.12, 0.12), "seed": rng.randi_range(0, 99)})
					break


func _draw_clutter(it: Dictionary) -> void:
	var c := _o(it["pos"])
	var f := UiTheme.font()
	var txt: String = it.get("text", "")
	draw_set_transform(c, float(it["rot"]), Vector2.ONE)
	match str(it["kind"]):
		"clip":
			draw_rect(Rect2(-120, -78, 240, 156), _bg(Color("efe9d8")))
			draw_rect(Rect2(-120, -78, 240, 156), PENCIL, false, 2.0)
			draw_string(f, Vector2(-110, -56), "THE DAILY ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.2, 0.3, 0.6))
			draw_multiline_string(f, Vector2(-110, -30), txt, HORIZONTAL_ALIGNMENT_LEFT, 220, 22, 3, _bg(Color("2b2233")))
			for k in 3:
				draw_line(Vector2(-110, 30 + k * 14), Vector2(96 - (k % 2) * 40, 30 + k * 14), Color(0, 0, 0, 0.2), 4.0)
		"note":
			draw_rect(Rect2(-100, -95, 200, 190), _bg(Color("fff3a3")))
			draw_rect(Rect2(-100, -95, 200, 190), PENCIL, false, 2.0)
			draw_multiline_string(f, Vector2(-86, -60), txt, HORIZONTAL_ALIGNMENT_LEFT, 172, 22, 6, _bg(Color("2d3a8c")))
			draw_rect(Rect2(-36, -105, 72, 22), Color(1, 0.97, 0.85, 0.7))
		"letter":
			draw_rect(Rect2(-120, -100, 240, 200), _bg(Color.WHITE))
			draw_rect(Rect2(-120, -100, 240, 200), PENCIL, false, 2.0)
			draw_rect(Rect2(-120, -100, 240, 34), _bg(Color("2b1f3d")))
			draw_string(f, Vector2(-120, -76), "HOARDLY INC.", HORIZONTAL_ALIGNMENT_CENTER, 240, 20, _bg(Color("ffd43b")))
			draw_multiline_string(f, Vector2(-108, -44), txt, HORIZONTAL_ALIGNMENT_LEFT, 216, 20, 6, _bg(Color("2b2233")))
		"photo":
			draw_rect(Rect2(-80, -94, 160, 188), _bg(Color.WHITE))
			draw_rect(Rect2(-80, -94, 160, 188), PENCIL, false, 2.0)
			var subj: String = it.get("extra", "")
			draw_rect(Rect2(-68, -82, 136, 124), _bg(Color("87b8e0")) if subj != "yacht" else _bg(Color("4d9be6")))
			match subj:
				"van", "grey":
					var body := _bg(Color("fffaf2")) if subj == "van" else _bg(Color("8d8f99"))
					draw_rect(Rect2(-44, -20, 72, 36), body)
					draw_rect(Rect2(16, -14, 26, 30), _bg(Color("596273")))
					draw_circle(Vector2(-28, 18), 9.0, _bg(Color("2b2233")))
					draw_circle(Vector2(24, 18), 9.0, _bg(Color("2b2233")))
					draw_rect(Rect2(-68, 26, 136, 16), _bg(Color("596273")))
				"yacht":
					draw_colored_polygon(PackedVector2Array([Vector2(-50, 10), Vector2(50, 10), Vector2(36, 30), Vector2(-40, 30)]), _bg(Color.WHITE))
					draw_rect(Rect2(-20, -16, 40, 26), _bg(Color.WHITE))
					draw_line(Vector2(0, -16), Vector2(0, -60), _bg(Color.WHITE), 4.0)
					draw_colored_polygon(PackedVector2Array([Vector2(0, -60), Vector2(26, -50), Vector2(0, -40)]), _bg(Color("ffd43b")))
				"tower":
					draw_rect(Rect2(-24, -76, 48, 118), _bg(Color("2b1f3d")))
					for wy in 6:
						draw_rect(Rect2(-16, -66 + wy * 18, 32, 8), _bg(Color("ffd43b", 0.8)))
					draw_string(f, Vector2(-24, -50), "H", HORIZONTAL_ALIGNMENT_CENTER, 48, 22, _bg(Color("ffd43b")))
			draw_string(f, Vector2(-80, 76), txt, HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color(0.2, 0.2, 0.3, 0.75))
			draw_rect(Rect2(-28, -104, 56, 20), Color(1, 0.97, 0.85, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _near_road(pos: Vector2, dist: float, buckets: Dictionary) -> bool:
	var b := int(pos.y / 100.0)
	for bb in range(b - 2, b + 3):
		for p in buckets.get(bb, []):
			if pos.distance_to(p) < dist:
				return true
	return false


func _pick(kind: String, rng: RandomNumberGenerator) -> String:
	var table := {
		"suburbs": [["house", 5], ["tree", 6], ["bush", 3], ["", 3]],
		"city": [["building", 5], ["tree", 3], ["lamp", 2], ["", 5]],
		"farm": [["field", 4], ["barn", 1], ["hay", 3], ["sunflower", 4], ["silo", 1], ["", 2]],
		"canyon": [["mesa", 2], ["cactus", 5], ["rock", 3], ["", 4]],
		"peaks": [["mountain", 3], ["pine", 7], ["water", 1], ["", 2]],
		"sea": [["water", 3], ["palm", 4], ["umbrella", 2], ["lighthouse", 1], ["", 3]],
		"night": [["skyline", 3], ["cone", 2], ["", 5]],
	}
	var opts: Array = table.get(kind, [["", 1]])
	var total := 0
	for o in opts:
		total += int(o[1])
	var roll := rng.randi_range(1, total)
	for o in opts:
		roll -= int(o[1])
		if roll <= 0:
			return o[0]
	return ""


# ---------------------------------------------------------------- scrolling and taps

func min_scroll() -> float:
	return -pad_top


func max_scroll() -> float:
	return maxf(min_scroll(), world_h - size.y + pad_bottom)


## After a win: the van starts at stop `from_i` and drives up the road to wait at stop `to_i`, the camera
## following; the stop pops as it arrives (it's just been unlocked). A tap hurries it. drive_done when it's
## there.
func drive(from_i: int, to_i: int) -> void:
	if stops.is_empty():
		drive_done.emit.call_deferred()
		return
	from_i = clampi(from_i, 0, stops.size() - 1)
	to_i = clampi(to_i, 0, stops.size() - 1)
	here = to_i
	focus(from_i)
	_drive_span(road_len[stop_sample[from_i]], road_len[stop_sample[to_i]] - 135.0, true)


## The van from stop `from_i` up to zone `zk`'s gate (where its checkpoint is), and no further.
func drive_to_gate(from_i: int, zk: int) -> void:
	if stops.is_empty() or _gate_len(zk) < 0.0:
		drive_done.emit.call_deferred()
		return
	from_i = clampi(from_i, 0, stops.size() - 1)
	here = _zone_first(zk)
	focus(from_i)
	_drive_span(road_len[stop_sample[from_i]], _gate_len(zk) - GATE_BACK, false)


## ...and on from the gate to stop `to_i`.
func drive_from_gate(zk: int, to_i: int) -> void:
	if stops.is_empty() or _gate_len(zk) < 0.0:
		drive_done.emit.call_deferred()
		return
	to_i = clampi(to_i, 0, stops.size() - 1)
	here = to_i
	_drive_span(_gate_len(zk) - GATE_BACK, road_len[stop_sample[to_i]] - 135.0, true)


func _drive_span(d0: float, d1: float, pop: bool) -> void:
	_drive_from = d0
	_drive_to = maxf(d1, d0)
	_drive_pop = pop
	_drive_dur = clampf((_drive_to - _drive_from) / 900.0, 0.8, 1.6)
	_drive_t = 0.0
	van.inviting = false
	Sfx.play("whoosh", 1.0, -6.0)


const GATE_BACK := 150.0         # how far short of a held gate the van waits

## How far along the road zone `zk`'s gate is (-1: it has none).
func _gate_len(zk: int) -> float:
	for g in gates:
		if int(g["zone"]) == zk:
			var best := 0
			for s in road.size():
				if absf(road[s].y - g["pos"].y) < absf(road[best].y - g["pos"].y):
					best = s
			return road_len[best]
	return -1.0


## The first stop (index) in zone `zk`.
func _zone_first(zk: int) -> int:
	for i in levels.size():
		if Zones.of(levels[i].number) == zk:
			return i
	return stops.size() - 1


## Is zone `zk`'s gate across the road? Locked, or open with its checkpoint still to pass.
func _shut(zk: int) -> bool:
	return not Zones.is_open(zk) or Checkpoint.holds(zk) or zk == held


const OPEN_SNAP := 0.75          # into the show, the tape snaps
const OPEN_TIME := 2.5           # ...and it's over (the banner lingers a little longer)

## Zone `zk` opens, with a show: the map glides to its gate, the tape strains, then snaps and swings away
## (a checkpoint's boom swings up), the fog rolls back up the map in a shower of sparks, and a banner says
## it's open. `zone_open_done` when it's over.
func open_zone(zk: int) -> void:
	_opening = zk
	_opening_t = _t
	held = -1
	_open_said = false
	_open_booth = Progress.checkpoints.has(zk)
	_open_puff = 0.0
	for g in gates:
		if int(g["zone"]) == zk:
			g["lift"] = 0.0
	Sfx.play("gate", 1.0, -6.0)
	get_tree().create_timer(OPEN_SNAP).timeout.connect(func():
		if not is_inside_tree():
			return
		Sfx.play("punch", 1.3, -3.0)
		Sfx.play("kaching", 1.0, -2.0)
		Sfx.play("jingle", 1.1, -4.0)
		Sfx.play("whoosh", 0.7, -4.0)
		Sfx.haptic(45, 1.0, "road_map:open_zone")
		for g in gates:
			if int(g["zone"]) == zk:
				var c := _o(g["pos"])
				_fx.ring(Vector2(W / 2.0, c.y), Palette.STAR_GOLD, 320.0)
				for col in [Palette.STAR_GOLD, HAZARD, Color.WHITE]:
					_fx.burst(Vector2(W / 2.0, c.y), col, 16, 900.0, 20.0))


## The opening show, each frame: the map glides to the gate, then up into the new zone; sparks along the
## fog's edge as it rolls back.
func _run_opening(delta: float) -> void:
	var ot := _t - _opening_t
	for g in gates:
		if int(g["zone"]) != _opening:
			continue
		if _drive_t < 0.0 and not _down:
			var visible := size.y - pad_top - pad_bottom
			var want: float = g["pos"].y - pad_top - visible * (0.5 if ot < OPEN_SNAP else 0.72)
			scroll = lerpf(scroll, clampf(want, min_scroll(), max_scroll()), 1.0 - exp(-5.0 * delta))
		if ot > OPEN_SNAP and ot < OPEN_SNAP + 1.3:
			_open_puff -= delta
			if _open_puff <= 0.0:
				_open_puff = 0.07
				_fx.burst(Vector2(randf_range(40.0, W - 40.0), _fog_line() - 150.0 - scroll), Color.WHITE if randf() < 0.5 else Palette.STAR_GOLD, 5, 300.0, 14.0)
	if not _open_said and ot >= OPEN_TIME:
		_open_said = true
		zone_open_done.emit()
	if ot > 4.2:
		_opening = -1


func driving() -> bool:
	return _drive_t >= 0.0


## Skip to the end of the drive.
func finish_drive() -> void:
	if _drive_t >= 0.0:
		_drive_t = _drive_dur


func _roll_van() -> void:
	var u := clampf(_drive_t / _drive_dur, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var d := lerpf(_drive_from, _drive_to, e)
	var s := 1
	while s < road.size() - 2 and road_len[s] < d:
		s += 1
	var a: Vector2 = road[s - 1]
	var b: Vector2 = road[s]
	var k := clampf((d - road_len[s - 1]) / maxf(road_len[s] - road_len[s - 1], 0.001), 0.0, 1.0)
	var wp := a.lerp(b, k)
	var dir := (b - a).angle()
	# Follow it: keep the van a little below the middle of the visible map.
	var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.6
	scroll = clampf(lerpf(scroll, wp.y - visible_mid, 0.25), min_scroll(), max_scroll())
	van.position = wp - Vector2(0, scroll) + Vector2(0, -6.0 * absf(sin(_t * 18.0)))
	van.target_rotation = dir
	if u >= 1.0:
		_drive_t = -1.0
		if _drive_pop:
			_pop_stop = here
			_pop_t0 = _t
			van.inviting = true
			Sfx.play("pop", 1.1, -2.0)
			Sfx.play("star", 1.2, -8.0)
		Sfx.haptic(16, 1.0, "road_map:_roll_van")
		drive_done.emit()


## The chip at the top: the van hops back to the furthest level, and the map glides there.
func back_to_next() -> void:
	if next < 0:
		return
	Sfx.play("whoosh", 1.2, -6.0)
	Progress.map_here = -1
	here = next
	_vel = 0.0
	var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.55
	var to := clampf(stops[next].y - visible_mid, min_scroll(), max_scroll())
	create_tween().tween_property(self, "scroll", to, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Is the furthest level off screen, or the van somewhere else? Then the chip shows.
func _back_wanted() -> bool:
	if next < 0 or stops.is_empty() or _drive_t >= 0.0:
		return false
	var y: float = stops[next].y - scroll
	return here != next or y < pad_top or y > size.y - pad_bottom * 0.6


func _draw_back_chip() -> void:
	var ci := _chip
	if _back_k <= 0.01:
		return
	var f := UiTheme.font()
	var up: bool = stops[next].y - scroll < size.y * 0.5
	var txt := "%s  Job %d" % ["↑" if up else "↓", levels[next].number]
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var w := tw + 70.0
	var h := 84.0
	var y := pad_top - 30.0 + (1.0 - _back_k) * -60.0
	_back_rect = Rect2((size.x - w) / 2.0, y, w, h)
	DrawUtil.rrect(ci, Rect2(_back_rect.position + Vector2(0, 6), _back_rect.size), Color(0, 0, 0, 0.16 * _back_k), h / 2.0)
	DrawUtil.rrect(ci, _back_rect, Color(Palette.ACCENT, _back_k), h / 2.0)
	ci.draw_string(f, _back_rect.position + Vector2(35, h / 2.0 + 13), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, _back_k))


## Scroll so level `i` sits a little below the middle of the visible map.
func focus(i: int) -> void:
	if stops.is_empty():
		return
	if i < 0 or i >= stops.size():
		i = stops.size() - 1
	var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.55
	scroll = clampf(stops[i].y - visible_mid, min_scroll(), max_scroll())


func _gui_input(event: InputEvent) -> void:
	if _intro >= 0:
		# The first detour's intro: a tap (once it's had a moment) puts it away. A tap on the detour itself
		# is for the detour: its own card opens (side_pressed), not the next job's.
		if event is InputEventMouseButton and event.pressed:
			var on_it: bool = _spur_at(event.position) == _intro
			if _intro_t > (0.9 if on_it else 1.4):
				var id := str(spurs[_intro].get("id", ""))
				intro_took_detour = on_it
				_end_intro()
				if on_it:
					side_pressed.emit(id)
		accept_event()
		return
	if _reveal >= 0:
		# A detour drawing itself in: a tap hurries it.
		if event is InputEventMouseButton and event.pressed:
			_end_reveal()
		accept_event()
		return
	if _drive_t >= 0.0:
		if event is InputEventMouseButton and event.pressed:
			finish_drive()
		accept_event()
		return
	if busy:
		# Something's playing out on the map (a win's drive on, a checkpoint, a zone opening): no taps.
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _back_k > 0.5 \
			and _back_rect.has_point(event.position):
		back_to_next()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_vel = 0.0
			scroll = clampf(scroll - 140.0 * mb.factor, min_scroll(), max_scroll())
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_vel = 0.0
			scroll = clampf(scroll + 140.0 * mb.factor, min_scroll(), max_scroll())
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_down = true
				_dragging = false
				_vel = 0.0
				_press_pos = mb.position
				_pressed = _stop_at(mb.position)
				_pressed_spur = _spur_at(mb.position) if _pressed < 0 else -1
				_last_motion = Time.get_ticks_msec()
			else:
				_down = false
				if not _dragging:
					var hit := _stop_at(mb.position)
					if hit >= 0 and hit == _pressed and Zones.is_open(Zones.of(levels[hit].number)) and Boss.blocker(levels[hit].number) > 0:
						# Behind a boss who has to be beaten first: his ticket jumps.
						Sfx.play("bonk", 0.9, -4.0)
						Sfx.play("laugh", 1.2, -10.0)
						Sfx.haptic(14, 1.0, "road_map:_gui_input")
						_pop_stop = Boss.blocker(levels[hit].number) - 1
						_pop_t0 = _t
					elif hit >= 0 and hit == _pressed and Zones.is_open(Zones.of(levels[hit].number)) and not Zones.reached(levels[hit].number):
						# Not got that far yet: the job in the way hops, and a note says which.
						Sfx.play("bonk", 0.9, -4.0)
						Sfx.haptic(14, 1.0, "road_map:_gui_input")
						var way := Zones.in_the_way(levels[hit].number)
						_pop_stop = way - 1
						_pop_t0 = _t
						_note = "Deliver or jump job %d first" % way
						_note_at = stops[hit]
						_note_t = _t
					elif hit >= 0 and hit == _pressed and not Zones.level_open(levels[hit].number):
						# A locked zone: the gate's sign says how many packages it wants.
						Sfx.play("bonk", 0.9, -4.0)
						Sfx.haptic(14, 1.0, "road_map:_gui_input")
						_gate_flash = Zones.of(levels[hit].number)
						_gate_flash_t = _t
					elif hit >= 0 and hit == _pressed:
						Sfx.play("click")
						stop_pressed.emit(hit)
					elif hit < 0 and _pressed < 0 and _cp_first >= 0 and _cp_rect.has_point(mb.position):
						# The held gate's sign: pull up to its checkpoint (as its first job would).
						Sfx.play("click")
						stop_pressed.emit(_cp_first)
					elif _pressed_spur >= 0 and _spur_at(mb.position) == _pressed_spur:
						_tap_spur(_pressed_spur)
					elif _reset_rect.has_point(mb.position + Vector2(0, scroll)):
						reset_pressed.emit()
				elif Time.get_ticks_msec() - _last_motion > 90:
					_vel = 0.0
				_pressed = -1
			accept_event()
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_press_pos) > 18.0:
			_dragging = true
			_pressed = -1
			_pressed_spur = -1
		if _dragging:
			var now := Time.get_ticks_msec()
			var dt := maxf((now - _last_motion) / 1000.0, 1.0 / 120.0)
			_last_motion = now
			scroll -= mm.relative.y
			_vel = lerpf(_vel, -mm.relative.y / dt, 0.5)
		accept_event()


func _stop_at(local: Vector2) -> int:
	var wp := local + Vector2(0, scroll)
	var best := -1
	var bd := PIN_R + 30.0
	for i in stops.size():
		var d: float = wp.distance_to(stops[i])
		if d < bd:
			bd = d
			best = i
	return best


func _process(delta: float) -> void:
	if _reveal >= 0:
		_reveal_t += delta
		if _reveal_t > REVEAL_TIME:
			_end_reveal()
	if _intro >= 0:
		_intro_t += delta
		if Progress.auto and _intro_t > 4.0 and not OS.get_cmdline_user_args().has("--card-hold"):
			_end_intro()
	_t += delta
	_back_k = move_toward(_back_k, 1.0 if _back_wanted() else 0.0, delta * 6.0)
	for g in gates:
		var want := 0.0 if _shut(int(g["zone"])) or (int(g["zone"]) == _opening and _t - _opening_t < OPEN_SNAP) else 1.0
		g["lift"] = move_toward(float(g["lift"]), want, delta * 2.2)
	if _opening >= 0:
		_run_opening(delta)
	if _chip:
		_chip.queue_redraw()
	if _drive_t >= 0.0:
		_drive_t += delta
	for sp in spurs:
		sp["shake"] = maxf(0.0, sp["shake"] - delta)
	if not _down:
		scroll += _vel * delta
		_vel *= exp(-3.2 * delta)
		if absf(_vel) < 5.0:
			_vel = 0.0
		# Ease back from past either end.
		var lo := min_scroll()
		var hi := max_scroll()
		if scroll < lo:
			scroll = lerpf(scroll, lo, 1.0 - exp(-14.0 * delta))
			_vel = 0.0
		elif scroll > hi:
			scroll = lerpf(scroll, hi, 1.0 - exp(-14.0 * delta))
			_vel = 0.0
	else:
		# Dragging past an end: resist.
		scroll = clampf(scroll, min_scroll() - 160.0, max_scroll() + 160.0)
	_park_van()
	queue_redraw()


## The van waits on the road just short of the next stop (or at the end of the road when all are done).
func _park_van() -> void:
	if van == null or stops.is_empty():
		return
	if _drive_t >= 0.0:
		_roll_van()
		return
	# A fixed distance back along the road from the stop, so it never sits on a sign or the barrier (or, its
	# zone's gate still held or mid-opening, short of the gate).
	var s: int = stop_sample[here] if here >= 0 else stop_sample[stops.size() - 1]
	if here >= 0:
		var want: float = road_len[s] - 135.0
		var zk := Zones.of(levels[here].number)
		if _gate_len(zk) >= 0.0 and (_shut(zk) or zk == _opening):
			want = minf(want, _gate_len(zk) - GATE_BACK)
		while s > 1 and road_len[s] > want:
			s -= 1
	else:
		# Every level done: it's carried on just past the last stop.
		var want: float = road_len[s] + 150.0
		while s < road.size() - 2 and road_len[s] < want:
			s += 1
	s = clampi(s, 1, road.size() - 2)
	var bob := sin(_t * 3.0) * 2.0
	van.position = road[s] - Vector2(0, scroll) + Vector2(0, bob)
	var dir := (road[s + 1] - road[s - 1]).angle()
	van.target_rotation = dir
	van.rotation = dir


# ---------------------------------------------------------------- drawing

func _o(p: Vector2) -> Vector2:
	return p - Vector2(0, scroll)


func _draw() -> void:
	var y0 := scroll - 200.0
	var y1 := scroll + size.y + 200.0
	_draw_ground(y0, y1)
	for it in scenery:
		var p: Vector2 = it["pos"]
		if p.y < y0 or p.y > y1:
			continue
		_draw_item(it)
	for k in spurs.size():
		var sp: Dictionary = spurs[k]
		var b: Vector2 = sp["b"]
		if b.y > y0 - 100.0 and b.y < y1 + 100.0:
			var grow := 1.0
			if k == _intro:
				grow = clampf((_intro_t - 0.25) / 0.8, 0.0, 1.0)
			elif k == _reveal:
				grow = clampf(_reveal_t / 0.55, 0.0, 1.0)
			_draw_spur_road(sp, grow)
	_draw_road(y0, y1)
	_draw_depot()
	for g in gates:
		var gp: Vector2 = g["pos"]
		if gp.y > y0 - 200.0 and gp.y < y1 + 200.0:
			_draw_gate(g)
	if barrier != Vector2.INF and barrier.y > y0 and barrier.y < y1:
		_draw_barrier()
	for sg in signs:
		var sp: Vector2 = sg["pos"]
		if sp.y > y0 - 100.0 and sp.y < y1 + 100.0:
			_draw_sign(sg)
	# (The next-up job last, so nothing pinned near it sits on top of it.)
	var front := -1
	for i in stops.size():
		if stops[i].y > y0 and stops[i].y < y1:
			if i == next or (i == here and not Progress.is_complete(levels[i].number)):
				front = i if front < 0 or i == next else front
				continue
			_draw_stop(i)
	for i in stops.size():
		if i != front and stops[i].y > y0 and stops[i].y < y1 and (i == next or (i == here and not Progress.is_complete(levels[i].number))):
			_draw_stop(i)
	if front >= 0:
		_draw_stop(front)
	_draw_other_van()
	_draw_fog(y0, y1)
	_cp_first = -1
	for g in gates:
		var gp: Vector2 = g["pos"]
		if gp.y > y0 - 400.0 and gp.y < y1 + 200.0:
			_draw_gate_sign(g)
	if y0 < 420.0:
		_draw_road_end()
	for sp in spurs:
		var b: Vector2 = sp["b"]
		if b.y > y0 - 100.0 and b.y < y1 + 100.0:
			if sp["kind"] == "side":
				_draw_side_sign(sp)
			else:
				_draw_chest(sp)
	if _note != "" and _t - _note_t < 2.4:
		_plate(_note, _o(_note_at) + Vector2(0, -118.0 - 20.0 * clampf((_t - _note_t) / 0.2, 0.0, 1.0)), HAZARD_INK, Color.WHITE, 26)
	if _intro >= 0:
		_draw_intro()


## Background things (scenery, the board's clippings and notes) are drawn faint and outlined in pencil,
## as if sketched on the map, so that what can be tapped (anything on a pinned ticket) stands out.
## (Night mode: a charcoal board instead of cork, charcoal sheets, chalk-grey pencil. The tickets stay paper,
## so what can be tapped is what's bright.)
var PENCIL := Color(0.25, 0.22, 0.3, 0.28) if not Palette.night else Color(0.85, 0.86, 0.92, 0.22)


static func _bg(c: Color) -> Color:
	if Palette.night:
		return Color.from_hsv(c.h, c.s * 0.3, lerpf(c.v, 0.42, 0.7), c.a * 0.8)
	return Color.from_hsv(c.h, c.s * 0.38, lerpf(c.v, 0.96, 0.42), c.a * 0.85)


var CORK := Color("c99560") if not Palette.night else Color("25272d")
const NIGHT_SHEET := Color("33363e")
const PAPER := Color("fbf6ea")
const STRING := Color("d6303d")


## The cork board, then each district's map sheet pinned over it: the district's colour as the print, a
## street grid, a fold line, tape at the corners, tilted a hair.
func _draw_ground(y0: float, y1: float) -> void:
	draw_rect(Rect2(Vector2(0, 0), size), CORK)
	# Cork grain.
	var start := int(floor(y0 / 46.0))
	for j in range(start, int(y1 / 46.0) + 1):
		for i in 12:
			var h := (j * 92821 + i * 6151) % 997
			var p := Vector2(fmod(h * 7.31 + i * 93.0, W), j * 46.0 + (h % 40))
			draw_circle(_o(p), 2.0 + (h % 3), CORK.darkened(0.06 + 0.04 * (h % 3)))
	for k in regions.size():
		var reg: Dictionary = regions[k]
		var top: float = reg["y0"] + 34.0
		var bot: float = reg["y1"] - 34.0
		if bot < y0 - 200.0 or top > y1 + 200.0:
			continue
		var def: Dictionary = reg["def"]
		var night: bool = def["kind"] == "night"
		var col: Color = (def["ground"] as Color).lerp(PAPER, 0.62) if not night else Color("2a3156")
		if Palette.night:
			col = NIGHT_SHEET.lerp(def["ground"] as Color, 0.1 if not night else 0.3)
		var rect := Rect2(Vector2(46, top - scroll), Vector2(W - 92, bot - top))
		var tilt := 0.006 * (1.0 if k % 2 == 0 else -1.0)
		draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
		var r := Rect2(-rect.size / 2.0, rect.size)
		draw_rect(Rect2(r.position + Vector2(8, 12), r.size), Color(0, 0, 0, 0.22))
		draw_rect(r, col)
		# The printed streets.
		var line := col.darkened(0.06) if not night else Color(0.55, 0.7, 1.0, 0.18)
		if Palette.night:
			line = Color(1, 1, 1, 0.06)
		var gx := r.position.x + 40.0
		while gx < r.end.x:
			draw_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y), line, 3.0)
			gx += 118.0
		var gy := r.position.y + 30.0
		while gy < r.end.y:
			draw_line(Vector2(r.position.x, gy), Vector2(r.end.x, gy), line, 3.0)
			gy += 104.0
		# A fold down the middle, and the sheet's edge.
		draw_line(Vector2(0, r.position.y), Vector2(0, r.end.y), Color(0, 0, 0, 0.06), 6.0)
		draw_rect(r, Color(0, 0, 0, 0.1), false, 3.0)
		# Tape at the corners.
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			draw_set_transform(rect.get_center() + c.rotated(tilt), tilt + (0.6 if c.x * c.y > 0 else -0.6), Vector2.ONE)
			draw_rect(Rect2(-46, -16, 92, 32), Color(1, 0.97, 0.85, 0.7 if not Palette.night else 0.3))
			draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Board clutter (a coffee ring, clippings, photos, stray pins).
	for it in clutter:
		var cp: Vector2 = it["pos"]
		if cp.y > y0 - 150.0 and cp.y < y1 + 150.0:
			_draw_clutter(it)

## The route: pencil, faint and dashed, ticket to ticket; red string over the part already driven.
func _draw_road(y0: float, y1: float) -> void:
	var lo := 0
	var hi := road.size() - 1
	while lo < road.size() - 1 and road[lo].y > y1:
		lo += 1
	while hi > 0 and road[hi].y < y0:
		hi -= 1
	lo = maxi(lo - 2, 0)
	hi = mini(hi + 2, road.size() - 1)
	if hi <= lo:
		return
	var done_to: int = stop_sample[next] if next >= 0 else road.size() - 1
	# Pencil for the whole route.
	var i := lo
	while i < hi:
		var j := mini(i + 3, hi)
		draw_line(_o(road[i]), _o(road[j]), Color(0.2, 0.18, 0.22, 0.45), 4.0, true)
		i += 6
	# Red string over the driven part, with a soft shadow and a little sag between pins.
	if done_to > lo:
		var drv := PackedVector2Array()
		var top := mini(done_to, hi)
		for k in range(lo, top + 1):
			var seg := k % SUBDIV
			var sag := sin(PI * seg / float(SUBDIV)) * 10.0
			drv.append(_o(road[k]) + Vector2(sag * 0.4, sag))
		if drv.size() >= 2:
			draw_polyline(_shift(drv, Vector2(4, 8)), Color(0, 0, 0, 0.18), 7.0, true)
			draw_polyline(drv, STRING, 6.0, true)
			draw_polyline(drv, STRING.lightened(0.25), 2.0, true)

func _shift(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


func _text(text: String, at: Vector2, px: int, col: Color, outline := 0, outline_col := Color.WHITE) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := at + Vector2(-w / 2.0, px * 0.35)
	if outline > 0:
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, outline_col)
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## Where the board starts: the dispatch desk's card, LAST MILE COURIERS, with the radio and the mug.
func _draw_depot() -> void:
	var c := _o(depot)
	if c.y < -300.0 or c.y > size.y + 300.0:
		return
	draw_set_transform(c, -0.03, Vector2.ONE)
	DrawUtil.rrect(self, Rect2(-232, -102 + 12, 464, 210), Color(0, 0, 0, 0.25), 10)
	DrawUtil.rrect(self, Rect2(-232, -102, 464, 210), PAPER, 10)
	draw_rect(Rect2(-232, -102, 464, 54), Palette.ACCENT)
	_text("LAST MILE COURIERS", Vector2(0, -74), 34, Color.WHITE)
	_text("DISPATCH", Vector2(0, -16), 46, Palette.INK)
	_text("the last independent courier in town", Vector2(0, 30), 22, Palette.INK_SOFT)
	draw_circle(Vector2(0, -102), 13.0, Color("e03131"))
	draw_circle(Vector2(-4, -106), 4.0, Color(1, 1, 1, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A coffee ring on the card, as is tradition.
	draw_arc(c + Vector2(170, 70), 48.0, 0.3, TAU - 0.4, 40, Color(0.45, 0.28, 0.12, 0.3), 7.0, true)
	# (Reset progress used to sit under it: one tap, no asking. It's in Options, under Testers.)
	_reset_rect = Rect2()

func _draw_barrier() -> void:
	var c := _o(barrier)
	# Cones either side, then a striped sawhorse across the road.
	for sx in [-1.0, 1.0]:
		_cone(c + Vector2(sx * 120.0, 18), 1.0)
	DrawUtil.rrect(self, Rect2(c + Vector2(-100, -4), Vector2(200, 50)), Color(0, 0, 0, 0.15), 10)
	for sx in [-80.0, 70.0]:
		draw_rect(Rect2(c + Vector2(sx, 0), Vector2(10, 40)), Color("6b5a4a"))
	DrawUtil.rrect(self, Rect2(c + Vector2(-100, -26), Vector2(200, 40)), Color.WHITE, 8)
	for k in 5:
		var x := -100.0 + k * 44.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(x + 8, -26), c + Vector2(x + 30, -26), c + Vector2(x + 12, 14), c + Vector2(x - 10, 14)]), Color("ff5d5d"))
	_text("ROAD CLOSED", c + Vector2(0, -64), 40, Color.WHITE, 12, Color("ff5d5d"))
	_text("coming soon · sneak peek ahead", c + Vector2(0, 74), 28, Color.WHITE, 8, Color("2c2457"))


## A district's name on a label-maker strip stuck to the top of its sheet: black tape, raised white
## capitals, the levels in it beside.
func _draw_sign(sg: Dictionary) -> void:
	var reg: Dictionary = regions[sg["region"]]
	var def: Dictionary = reg["def"]
	var c := _o(sg["pos"])
	var title: String = str(def.get("title", def["name"])).to_upper()
	var f := UiTheme.font()
	var px := 40
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var first: int = levels[reg["first"]].number
	var last: int = levels[reg["last"]].number
	var sub := "JOBS %d–%d" % [first, last]
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var w := tw + sw + 110.0
	c.x = clampf(c.x, w / 2.0 + 30.0, W - w / 2.0 - 30.0)
	draw_set_transform(c, -0.02, Vector2.ONE)
	DrawUtil.rrect(self, Rect2(-w / 2.0 + 6, -32 + 8, w, 64), Color(0, 0, 0, 0.25), 8)
	DrawUtil.rrect(self, Rect2(-w / 2.0, -32, w, 64), Color("1d1b22"), 8)
	draw_string(f, Vector2(-w / 2.0 + 30, 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, 0.95))
	draw_string(f, Vector2(w / 2.0 - sw - 26, 10), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.55))
	if def.has("note"):
		DrawUtil.rrect(self, Rect2(-w / 2.0 + 30, 38, w - 60, 40), Color("ffd93d"), 4)
		draw_string(f, Vector2(-w / 2.0 + 30, 66), str(def["note"]), HORIZONTAL_ALIGNMENT_CENTER, w - 60, 24, Color("2b2233"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_stop(i: int) -> void:
	var L: LevelData = levels[i]
	var done := Progress.is_complete(L.number)
	# Redesigned since it was beaten: the ticket turns blue and says so until it's beaten again.
	var stale := Progress.is_stale(L.number, L.fp)
	# Next up: the job the road's got to (and wherever the van's waiting, if that's not delivered yet).
	var is_next := i == next or (i == here and not done and Zones.level_open(L.number))
	var night := L.preview
	var c := _o(stops[i])
	var scale := 1.0
	if is_next:
		scale = 1.05 + 0.04 * sin(_t * 4.0)
	if i == _pressed:
		scale *= 0.92
	if i == _pop_stop:
		var pk := clampf((_t - _pop_t0) / 0.45, 0.0, 1.0)
		scale *= 1.0 + 0.4 * sin(PI * pk) * (1.0 - pk * 0.5)
	var open := Zones.level_open(L.number)
	# The job ticket. Four looks, so where you stand reads at a glance:
	#   untried     plain grey paper, dashed edge, faded ink: a job on the pile
	#   next up     bigger, bright orange, glowing, bobbing, a NEXT UP tab
	#   delivered   green, with a check
	# Each shows its packages along the bottom: what winning it adds to the count delivered.
	var untried := not done and not is_next
	var band := Color("b9b2a4")
	var ink := Palette.INK
	if stale:
		band = Color("4a7bd6")
	elif done:
		band = Palette.GOOD
	elif is_next:
		band = Palette.ACCENT
	elif night:
		band = PEEK
	var tilt := (float((L.number * 7919) % 11) - 5.0) * 0.012
	# Alive: each ticket sways a hair on its pin, out of step with its neighbours; the next one more.
	tilt += sin(_t * (1.3 + 0.1 * (L.number % 5)) + L.number * 1.7) * (0.035 if is_next else (0.014 if done else 0.006))
	var w := 196.0
	var h := 150.0
	if is_next:
		# The one that matters: a good deal bigger, hopping, on a turning burst of light, rings pulsing off
		# it, a gold rim. Nothing else on the board looks like it.
		scale *= 1.3
		c.y += -12.0 * absf(sin(_t * 2.4))
		draw_set_transform(c, _t * 0.35, Vector2.ONE)
		for ray in 10:
			var a0 := TAU * ray / 10.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a0 - 0.13), sin(a0 - 0.13)) * 250.0, Vector2(cos(a0 + 0.13), sin(a0 + 0.13)) * 250.0]),
				Color(1.0, 0.82, 0.3, 0.2))
		draw_circle(Vector2.ZERO, 150.0, Color(1.0, 0.86, 0.4, 0.2))
		for k0 in [0.0, 0.5]:
			var k := fmod(_t / 1.4 + k0, 1.0)
			draw_set_transform(c, tilt, Vector2.ONE * scale * (1.08 + 0.4 * k))
			DrawUtil.rrect(self, Rect2(-w / 2.0, -h / 2.0, w, h), Color(Palette.ACCENT, 0.45 * (1.0 - k)), 14)
		draw_set_transform(c, tilt, Vector2.ONE * scale)
		DrawUtil.rrect(self, Rect2(-w / 2.0 - 13, -h / 2.0 - 13, w + 26, h + 26), Palette.STAR_GOLD, 17)
	draw_set_transform(c, tilt, Vector2.ONE * scale)
	DrawUtil.rrect(self, Rect2(-w / 2.0 + 8, -h / 2.0 + 14, w, h), Color(0, 0, 0, 0.32 if not untried else 0.18), 10)
	var boss := Boss.is_level(L.number)
	if boss:
		# A boss fight: the Baron's own black and gold round the ticket.
		DrawUtil.rrect(self, Rect2(-w / 2.0 - 10, -h / 2.0 - 10, w + 20, h + 20), Boss.GOLD, 12)
		DrawUtil.rrect(self, Rect2(-w / 2.0 - 6, -h / 2.0 - 6, w + 12, h + 12), Color("2b1f3d"), 10)
	elif L.challenge:
		# Challenge jobs: hazard tape round the ticket.
		DrawUtil.rrect(self, Rect2(-w / 2.0 - 8, -h / 2.0 - 8, w + 16, h + 16), HAZARD_INK, 10)
		var x := -w / 2.0 - 8.0
		while x < w / 2.0 + 8.0:
			draw_colored_polygon(PackedVector2Array([Vector2(x, -h / 2.0 - 8), Vector2(x + 14, -h / 2.0 - 8), Vector2(x + 4, -h / 2.0), Vector2(x - 10, -h / 2.0)]), HAZARD)
			draw_colored_polygon(PackedVector2Array([Vector2(x, h / 2.0), Vector2(x + 14, h / 2.0), Vector2(x + 4, h / 2.0 + 8), Vector2(x - 10, h / 2.0 + 8)]), HAZARD)
			x += 28.0
	elif not untried:
		# A bold frame in the ticket's colour, so it stands off the board.
		DrawUtil.rrect(self, Rect2(-w / 2.0 - 7, -h / 2.0 - 7, w + 14, h + 14), band.darkened(0.15), 13)
	var paper := Color.WHITE if not untried else Color("ebe5d7")
	if night:
		paper = Color("e9e4ff")
	DrawUtil.rrect(self, Rect2(-w / 2.0, -h / 2.0, w, h), paper, 8)
	if untried:
		# A dashed edge: it's still on the pile.
		var dash := 14.0
		var pts := [Vector2(-w / 2.0, -h / 2.0), Vector2(w / 2.0, -h / 2.0), Vector2(w / 2.0, h / 2.0), Vector2(-w / 2.0, h / 2.0)]
		for e in 4:
			var p0: Vector2 = pts[e]
			var p1: Vector2 = pts[(e + 1) % 4]
			var ln := p0.distance_to(p1)
			var t0 := 0.0
			while t0 < ln:
				draw_line(p0.lerp(p1, t0 / ln), p0.lerp(p1, minf(t0 + dash, ln) / ln), Color(0, 0, 0, 0.25), 3.0)
				t0 += dash * 2.0
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, 34), band if not untried else Color(band, 0.6))
	var f := UiTheme.font()
	var head := "NEXT UP" if is_next and not done else ("DELIVERED" if done else ("BOSS" if boss else "JOB"))
	# (Clear of the sticker on a boss's or a challenge's corner.)
	draw_string(f, Vector2(-w / 2.0 + (52 if boss or L.challenge else 12), -h / 2.0 + 24), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE if not untried else Color(ink, 0.5))
	if done and not stale:
		# A check in the band's corner.
		var cc := Vector2(w / 2.0 - 22, -h / 2.0 + 17)
		draw_circle(cc, 12.0, Color.WHITE)
		draw_polyline(PackedVector2Array([cc + Vector2(-6, 0), cc + Vector2(-2, 5), cc + Vector2(7, -5)]), band.darkened(0.2), 3.5, true)
	var ink_a := 0.45 if untried else 1.0
	draw_string(f, Vector2(-w / 2.0, 18), str(L.number), HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(ink, ink_a))
	var title := L.title
	var tpx := 20
	while tpx > 14 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > w - 18:
		tpx -= 1
	draw_string(f, Vector2(-w / 2.0, 46), title, HORIZONTAL_ALIGNMENT_CENTER, w, tpx + 2, Color(ink, 0.65 * ink_a))
	# Its packages: a little box and the count.
	var pk := str(L.total_orders())
	var pw := f.get_string_size(pk, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var px0 := -(26.0 + 6.0 + pw) / 2.0
	Icons.draw(self, "box", Vector2(px0 + 13.0, h / 2.0 - 18.0), 26.0, Color(1, 1, 1, ink_a))
	draw_string(f, Vector2(px0 + 32.0, h / 2.0 - 9.0), pk, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(ink, 0.8 * ink_a))
	# The push-pin holding it up.
	draw_circle(Vector2(0, -h / 2.0 + 4), 15.0, Color(0, 0, 0, 0.2))
	draw_circle(Vector2(-2, -h / 2.0), 14.0, STRING if not is_next else Palette.ACCENT.darkened(0.2))
	draw_circle(Vector2(-6, -h / 2.0 - 4), 4.5, Color(1, 1, 1, 0.65))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var r := h / 2.0
	if stale:
		_plate("UPDATED", c + Vector2(0, r + 26.0), Color("4a7bd6"), Color.WHITE, 18)
	if not open:
		# A district not open yet: the ticket's under the Baron's notice paper, padlocked.
		draw_set_transform(c, tilt, Vector2.ONE)
		DrawUtil.rrect(self, Rect2(-w / 2.0, -h / 2.0, w, h), Color(0.86, 0.85, 0.88, 0.86), 8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_padlock(c, 46.0)
		return
	if Progress.skipped.has(L.number) and not done:
		_plate("SKIPPED", c + Vector2(0, r + 26.0), Color("f2a33a"), Color.WHITE, 18)
	# A present (or a key) still waiting on this job's road: a little sticker on the ticket's corner.
	var waiting := not Progress.keys_found.has(L.number) if L.gift_item == "key" else \
		(not Progress.is_complete(L.number) if L.gift_item == "headlights" else (L.gift_item != "" and not Progress.owns(L.gift_item)))
	if waiting:
		var g := c + Vector2(w * 0.46, -h * 0.4)
		draw_circle(g, 27.0, Color.WHITE)
		if L.gift_item == "key":
			Icons.draw(self, "key", g + Vector2(0, 2), 40.0, Icons.GOLD_DARK)
		else:
			Icons.draw(self, "gift", g + Vector2(0, 3), 36.0, Color("ff3d9a"))
	if boss:
		# ...and the Baron himself on the corner (laughing now and then, until he's beaten).
		var b := c + Vector2(-w * 0.46, -h * 0.4)
		draw_circle(b + Vector2(0, 4), 33.0, Color(0, 0, 0, 0.18))
		draw_circle(b, 33.0, Boss.GOLD)
		draw_circle(b, 28.0, Color("2b1f3d"))
		Boss.draw(self, b + Vector2(0, 24), 50.0, _t, "smug" if done or fmod(_t + L.number, 5.0) > 1.2 else "laugh")
	elif L.challenge:
		# ...and a flame sticker (it flickers until it's beaten).
		var b := c + Vector2(-w * 0.46, -h * 0.4)
		draw_circle(b + Vector2(0, 4), 29.0, Color(0, 0, 0, 0.18))
		draw_circle(b, 29.0, HAZARD_INK)
		draw_circle(b, 24.0, HAZARD)
		AnimeFire.draw_flame(self, b + Vector2(0, 15), 26.0, 38.0 + (4.0 * sin(_t * 9.0) if not done else 0.0), _t if not done else 0.0, 7.0, AnimeFire.palette(4))
	if L.preview and not done:
		_plate("PEEK", c + Vector2(0, -r - 22), PEEK, Color.WHITE, 22)

## Somebody else's van: grey, parked a few stops further up the road, facing away, a "?" parcel on its
## roof. However far you get, it's always a little further on. (Nobody's ever explained it.)
func _draw_other_van() -> void:
	if next < 3 or stops.size() < 5:
		return
	var i := mini(next + 3, stops.size() - 1)
	var s: Vector2 = stops[i]
	var dx := 1.0 if s.x < W / 2.0 else -1.0
	var at := s + Vector2(dx * 175.0, 70.0)
	for sp in spurs:
		if at.distance_to(sp["b"]) < 150.0:
			at = s + Vector2(-dx * 175.0, 70.0)
	var c := _o(at)
	var L := 92.0
	var Wd := 56.0
	draw_set_transform(c, -PI / 2.0 + 0.15 * dx, Vector2.ONE)
	DrawUtil.rrect(self, Rect2(-L / 2 - 3, -Wd / 2 + 2, L + 6, Wd + 6), Color(0, 0, 0, 0.18), Wd * 0.3)
	DrawUtil.rrect(self, Rect2(-L / 2, -Wd / 2, L, Wd), Color("8d8f99"), Wd * 0.28)
	DrawUtil.rrect(self, Rect2(L / 2 - L * 0.3, -Wd / 2, L * 0.3, Wd), Color("4a4c57"), Wd * 0.28)
	DrawUtil.parcel(self, Vector2(-L * 0.12, 0), Vector2(Wd * 0.62, Wd * 0.46), Palette.pkg("purple"), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Past the last stop the road runs on into fog, by a sign nobody has a number for.
func _draw_road_end() -> void:
	var top := _o(Vector2(0, 0))
	for k in 6:
		draw_rect(Rect2(Vector2(0, top.y - 200.0 + k * 50.0), Vector2(W, 60.0)), Color(1, 1, 1, 0.16 - k * 0.022))
	var rp := _road_point_at_y(110.0)
	var p := _o(rp + Vector2(-170.0 if rp.x > W / 2.0 else 170.0, 0))
	draw_line(p + Vector2(0, 40), p + Vector2(0, -30), Color("8a6a4a"), 8.0)
	DrawUtil.rrect(self, Rect2(p + Vector2(-80, -86), Vector2(160, 64)), Color("2fb49a"), 10)
	_text("MILE ???", p + Vector2(0, -54), 28, Color.WHITE)


# ---------------------------------------------------------------- side roads

func _spur_at(local: Vector2) -> int:
	var wp := local + Vector2(0, scroll)
	for k in spurs.size():
		var off: Vector2 = wp - spurs[k]["b"]
		if absf(off.x) < TICKET.x / 2.0 + 8.0 and absf(off.y) < TICKET.y / 2.0 + 8.0:
			return k
	return -1


func _tap_spur(k: int) -> void:
	var sp: Dictionary = spurs[k]
	var n: int = sp["n"]
	if sp["kind"] == "side":
		if Progress.side_open(sp["def"]):
			# Its own card (NextCard, detour_only): what it is, and one button in (unlocking it with a key
			# happens there, never on a stray tap).
			Sfx.play("click")
			side_pressed.emit(sp["id"])
			return
	elif Progress.is_complete(n) and not Progress.chest_open(n):
		Sfx.play("click")
		chest_pressed.emit(n)
		return
	elif Progress.chest_open(n):
		Sfx.play("tick", 0.8, -6.0)
		sp["shake"] = 0.2
		return
	# Not open yet: it shakes its head.
	Sfx.play("bonk", 1.1, -6.0)
	Sfx.haptic(14, 0.6, "road_map:_tap_spur")
	sp["shake"] = 0.35


func _shake_of(sp: Dictionary) -> Vector2:
	var k: float = sp["shake"]
	return Vector2(sin(k * 60.0) * 9.0 * (k / 0.35), 0)


const DIRT := Color("cfa874")
const DIRT_EDGE := Color("a47c4a")
const DIRT_DOT := Color("6e5030")

## The dirt road from the fork out to the detour or chest: a sandy track with a dotted line down it once the
## job before it is done; until then just a faint dotted pencil line. `grow` (0..1): how far out it's been
## drawn (the first detour's intro draws it in).
func _draw_spur_road(sp: Dictionary, grow := 1.0) -> void:
	var pts := _spur_path(sp)
	var open := Progress.is_complete(int(sp["n"]))
	if grow < 1.0:
		pts = _path_upto(pts, grow)
	if pts.size() < 2:
		return
	if open:
		draw_polyline(_shift(pts, Vector2(3, 7)), Color(0, 0, 0, 0.12), 34.0, true)
		draw_polyline(pts, DIRT_EDGE, 34.0, true)
		draw_polyline(pts, DIRT, 26.0, true)
		draw_circle(pts[pts.size() - 1], 17.0, DIRT_EDGE)
		draw_circle(pts[pts.size() - 1], 13.0, DIRT)
		_dots(pts, 22.0, 3.6, Color(DIRT_DOT, 0.75), 18.0)
	else:
		_dots(pts, 20.0, 3.4, Color(0.2, 0.18, 0.22, 0.4), 6.0)


## The first detour that opens: its dirt road draws itself out from the fork, a finger runs along it and
## taps the ticket, and a bubble says what a detour is. Once only (seen_new "detour"). False if there's no
## such spur (nothing shown).
func detour_intro(id: String) -> bool:
	for k in spurs.size():
		if spurs[k]["kind"] == "side" and spurs[k].get("id", "") == id:
			_intro = k
			_intro_t = 0.0
			Sfx.play("sparkle", 1.1, -6.0)
			var mid: float = ((spurs[k]["a"] as Vector2).y + (spurs[k]["b"] as Vector2).y) / 2.0
			var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.6
			scroll = clampf(mid - visible_mid, min_scroll(), max_scroll())
			return true
	return false


## A detour's just opened up off the road (not the first ever: that one gets the intro): a quick beat. Its
## dirt road draws itself out from the fork, then its ticket pops onto the end with a ring. REVEAL_TIME in
## all; a tap hurries it. False if there's no such spur (nothing shown); else `reveal_done` follows.
const REVEAL_TIME := 1.15

func reveal_detour(id: String) -> bool:
	for k in spurs.size():
		if spurs[k]["kind"] == "side" and spurs[k].get("id", "") == id:
			_reveal = k
			_reveal_t = 0.0
			Sfx.play("whoosh", 1.3, -8.0)
			get_tree().create_timer(0.5).timeout.connect(func():
				if _reveal == k:
					Sfx.play("pop", 1.1, -4.0)
					Sfx.play("sparkle", 1.2, -6.0)
					Sfx.haptic(16, 1.0, "road_map:reveal_detour"))
			var mid: float = ((spurs[k]["a"] as Vector2).y + (spurs[k]["b"] as Vector2).y) / 2.0
			var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.6
			scroll = clampf(mid - visible_mid, min_scroll(), max_scroll())
			return true
	return false


## The same beat for a chest just unlocked (the one after job `n`): its track draws out, the chest pops on.
func reveal_chest(n: int) -> bool:
	for k in spurs.size():
		if spurs[k]["kind"] == "chest" and int(spurs[k].get("n", 0)) == n:
			_reveal = k
			_reveal_t = 0.0
			Sfx.play("whoosh", 1.3, -8.0)
			get_tree().create_timer(0.5).timeout.connect(func():
				if _reveal == k:
					Sfx.play("pop", 1.1, -4.0)
					Sfx.play("sparkle", 1.2, -6.0)
					Sfx.haptic(16, 1.0, "road_map:reveal_chest"))
			var mid: float = ((spurs[k]["a"] as Vector2).y + (spurs[k]["b"] as Vector2).y) / 2.0
			var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.6
			scroll = clampf(mid - visible_mid, min_scroll(), max_scroll())
			return true
	return false


func _end_reveal() -> void:
	if _reveal < 0:
		return
	_reveal = -1
	queue_redraw()
	reveal_done.emit()


func _end_intro() -> void:
	if _intro < 0:
		return
	_intro = -1
	Progress.seen_new["detour"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	Sfx.play("click")
	queue_redraw()
	intro_done.emit()


func _draw_intro() -> void:
	var sp: Dictionary = spurs[_intro]
	var t := _intro_t
	var b := _o(sp["b"])
	var pts := _spur_path(sp)
	# The finger: along the dirt road from the fork, then a tap on the ticket; round again.
	if t > 1.0:
		var u := fmod(t - 1.0, 2.2)
		var tip: Vector2
		var press := 0.0
		if u < 1.2:
			var path := _path_upto(pts, _ease_io(u / 1.2))
			tip = path[path.size() - 1]
		else:
			tip = b + Vector2(10, 18)
			press = sin(clampf((u - 1.3) / 0.5, 0.0, 1.0) * PI)
			if press > 0.0:
				draw_arc(tip, 30.0 + 40.0 * (1.0 - press), 0, TAU, 40, Color(1, 1, 1, 0.7 * press), 6.0, true)
		var a := clampf((t - 1.0) / 0.25, 0.0, 1.0)
		DrawUtil.hand(self, tip, 120.0 * (1.0 - 0.12 * press), a)
	# The bubble: above the ticket (or under it, near the top of the screen).
	var k := clampf((t - 0.5) / 0.3, 0.0, 1.0)
	if k <= 0.0:
		return
	var lines := [["A DETOUR!", 40, SIDE_COL.darkened(0.15)], ["A bonus job off the main road.", 30, Palette.TEXT],
			["Optional, with a prize.", 30, Palette.TEXT], ["Take it now or come back later.", 26, Palette.TEXT_SOFT]]
	var bw := 560.0
	var bh := 230.0
	var bx := clampf(b.x - bw / 2.0, 24.0, W - 24.0 - bw)
	var by := b.y - TICKET.y / 2.0 - 40.0 - bh
	var below := by < pad_top + 10.0
	if below:
		by = b.y + TICKET.y / 2.0 + 40.0
	var s := 0.85 + 0.15 * _out_back(k)
	var r := Rect2(bx, by, bw, bh)
	var piv := Vector2(clampf(b.x, bx + 40.0, bx + bw - 40.0), by + bh if not below else by)
	draw_set_transform(piv, 0.0, Vector2.ONE * s)
	var rr := Rect2(r.position - piv, r.size)
	DrawUtil.rrect(self, Rect2(rr.position + Vector2(0, 8), rr.size), Color(0, 0, 0, 0.18 * k), 28)
	DrawUtil.rrect(self, rr.grow(3), Color(Palette.BUBBLE_RIM, Palette.BUBBLE_RIM.a * k), 31)
	DrawUtil.rrect(self, rr, Color(Palette.BUBBLE, k), 28)
	var tail := PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(0, 26)]) if not below else PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(0, -26)])
	draw_colored_polygon(tail, Color(Palette.BUBBLE, k))
	var y := rr.position.y + 58.0
	for ln in lines:
		_text(str(ln[0]), Vector2(rr.position.x + bw / 2.0, y), int(ln[1]), Color(ln[2] as Color, k))
		y += float(ln[1]) * 1.45
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 1.4:
		var hint_a := clampf((t - 1.4) / 0.4, 0.0, 1.0) * (0.55 + 0.25 * sin(t * 3.0))
		_text("Tap the detour for a look, or anywhere else to carry on", Vector2(W / 2.0, size.y - pad_bottom - 40.0), 26, Color(Palette.TEXT, hint_a), 8, Color(Palette.BG, hint_a))


func _ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _out_back(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3) + c * pow(x - 1.0, 2)


## The dirt road's centre line, on screen: out of the fork sideways, easing round to the ticket.
func _spur_path(sp: Dictionary) -> PackedVector2Array:
	var a := _o(sp["a"])
	var b := _o(sp["b"])
	var c1 := a + Vector2((b.x - a.x) * 0.45, 26.0)
	var c2 := b + Vector2((a.x - b.x) * 0.3, 22.0)
	var pts := PackedVector2Array()
	for k in 25:
		var t := k / 24.0
		var u := 1.0 - t
		pts.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return pts


## The first `k` (0..1) of a line, by length.
func _path_upto(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var want := total * clampf(k, 0.0, 1.0)
	var out := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in range(1, pts.size()):
		var d := pts[i - 1].distance_to(pts[i])
		if acc + d >= want:
			out.append(pts[i - 1].lerp(pts[i], (want - acc) / maxf(d, 0.001)))
			break
		acc += d
		out.append(pts[i])
	return out


## Dots every `gap` along a line, skipping the first `skip` of it (where it leaves the road).
func _dots(pts: PackedVector2Array, gap: float, r: float, col: Color, skip: float) -> void:
	var acc := 0.0
	var next_at := skip
	for i in range(1, pts.size()):
		var d := pts[i - 1].distance_to(pts[i])
		while next_at <= acc + d:
			draw_circle(pts[i - 1].lerp(pts[i], (next_at - acc) / maxf(d, 0.001)), r, col)
			next_at += gap
		acc += d


func _plate(text: String, at: Vector2, bg: Color, fg: Color, px := 24) -> void:
	var f := UiTheme.font()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	DrawUtil.rrect(self, Rect2(at + Vector2(-tw / 2.0 - 14, -px * 0.75), Vector2(tw + 28, px * 1.5)), bg, px * 0.75)
	draw_string(f, at + Vector2(-tw / 2.0, px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)

## A ticket for something off the main route (a detour, a chest). The same paper, band, tab and pin as a
## job's, so everything that can be tapped on the board is a pinned ticket and nothing else is. `live`:
## it can be played or opened now (bright, framed); otherwise it's grey with a dashed edge, like a job on the
## pile. Leaves the transform at the ticket's middle for the caller's picture; _ticket_pin() ends it.
const TICKET := Vector2(196, 150)

func _spur_ticket(c: Vector2, tilt: float, scale: float, band: Color, head: String, live: bool, done := false) -> void:
	var w := TICKET.x
	var h := TICKET.y
	draw_set_transform(c, tilt, Vector2.ONE * scale)
	DrawUtil.rrect(self, Rect2(-w / 2.0 + 8, -h / 2.0 + 14, w, h), Color(0, 0, 0, 0.32 if live else 0.18), 10)
	if live:
		DrawUtil.rrect(self, Rect2(-w / 2.0 - 7, -h / 2.0 - 7, w + 14, h + 14), band.darkened(0.15), 13)
	DrawUtil.rrect(self, Rect2(-w / 2.0, -h / 2.0, w, h), Color.WHITE if live else Color("ebe5d7"), 8)
	if not live:
		var dash := 14.0
		var pts := [Vector2(-w / 2.0, -h / 2.0), Vector2(w / 2.0, -h / 2.0), Vector2(w / 2.0, h / 2.0), Vector2(-w / 2.0, h / 2.0)]
		for e in 4:
			var p0: Vector2 = pts[e]
			var p1: Vector2 = pts[(e + 1) % 4]
			var ln := p0.distance_to(p1)
			var t0 := 0.0
			while t0 < ln:
				draw_line(p0.lerp(p1, t0 / ln), p0.lerp(p1, minf(t0 + dash, ln) / ln), Color(0, 0, 0, 0.25), 3.0)
				t0 += dash * 2.0
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, 34), band if live else Color(band, 0.6))
	var f := UiTheme.font()
	# (Dark ink on a light band, like a chest's gold; white on the rest.)
	var ink_on_band := Color("2b2233") if band.get_luminance() > 0.55 else Color.WHITE
	draw_string(f, Vector2(-w / 2.0 + 12, -h / 2.0 + 24), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink_on_band if live else Color(Color("2b2233"), 0.5))
	if done:
		var cc := Vector2(w / 2.0 - 22, -h / 2.0 + 17)
		draw_circle(cc, 12.0, Color.WHITE)
		draw_polyline(PackedVector2Array([cc + Vector2(-6, 0), cc + Vector2(-2, 5), cc + Vector2(7, -5)]), band.darkened(0.2), 3.5, true)


## The ticket's name along the bottom (shrunk to fit), then its push-pin; and the transform's put back.
func _ticket_pin(title: String, live: bool, pin: Color) -> void:
	var w := TICKET.x
	var h := TICKET.y
	var f := UiTheme.font()
	var tpx := 21
	while tpx > 14 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > w - 18:
		tpx -= 1
	draw_string(f, Vector2(-w / 2.0, h / 2.0 - 16), title, HORIZONTAL_ALIGNMENT_CENTER, w, tpx, Color(Palette.INK, 0.8 if live else 0.4))
	draw_circle(Vector2(0, -h / 2.0 + 4), 15.0, Color(0, 0, 0, 0.2))
	draw_circle(Vector2(-2, -h / 2.0), 14.0, pin)
	draw_circle(Vector2(-6, -h / 2.0 - 4), 4.5, Color(1, 1, 1, 0.65))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A detour's ticket, pinned beside the job it branches from. Grey ("after job N") until that job's
## done; then bright, with what it wins drawn on it (the ride, a mega route's parts, the Baron); a gold
## padlock while it needs a key; green and ticked once it's won.
func _draw_side_sign(sp: Dictionary) -> void:
	var d: Dictionary = sp["def"]
	var open := Progress.side_open(d)
	var won := Progress.side_done.has(sp["id"])
	var locked := Progress.side_locked(d)
	var opening := _t - float(sp.get("unlock", -9.0))
	var boss := Boss.is_boss(d)
	var mega := SideRoads.is_mega(d)
	var ready := open and not won and not locked
	var c := _o(sp["b"]) + _shake_of(sp)
	var tilt := 0.05 * (1.0 if int(sp["n"]) % 2 == 0 else -1.0) + sin(_t * 1.5 + int(sp["n"])) * (0.03 if ready else 0.008)
	var scale := 1.0
	if ready:
		scale = 1.03 + 0.03 * sin(_t * 4.0)
		c.y += -5.0 * absf(sin(_t * 2.4))
	if _reveal >= 0 and spurs[_reveal] == sp:
		# Just revealed: nothing until its road's drawn, then it pops on (overshooting), a ring going out.
		var u := clampf((_reveal_t - 0.5) / 0.35, 0.0, 1.0)
		if u <= 0.0:
			return
		scale *= _out_back(u)
		var ring := clampf((_reveal_t - 0.5) / 0.6, 0.0, 1.0)
		draw_arc(c, 90.0 + 130.0 * ring, 0, TAU, 48, Color(1, 0.9, 0.4, 0.9 * (1.0 - ring)), 10.0, true)
	var band := Palette.GOOD if won else (Color("2b1f3d") if boss else (Color("16a98f") if mega else SIDE_COL))
	var head := "DONE" if won else ("BOSS FIGHT" if boss else ("MEGA ROUTE" if mega else "DETOUR"))
	if ready:
		# Something to play: a ring pulses out from behind it.
		for k0 in [0.0, 0.5]:
			var k := fmod(_t / 1.6 + k0, 1.0)
			draw_set_transform(c, tilt, Vector2.ONE * scale * (1.06 + 0.35 * k))
			DrawUtil.rrect(self, Rect2(-TICKET / 2.0, TICKET), Color(band if not boss else Color("e03131"), 0.35 * (1.0 - k)), 14)
	_spur_ticket(c, tilt, scale, band, head, open, won)
	var pic := Vector2(0, 2)
	if open and boss:
		# (He sets his own transform as he shakes with laughter: drawn straight on the board, then back.)
		var mood := "laugh" if fmod(_t, 5.0) < 1.2 and not won else "smug"
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Boss.draw(self, c + Vector2(0, 42) * scale, 80.0 * scale, _t, mood)
		draw_set_transform(c, tilt, Vector2.ONE * scale)
	elif open and mega:
		_draw_parts_grid(d, pic)
	elif open:
		var xf := Transform2D(tilt - 0.35, c) * Transform2D(0.0, Vector2.ONE * scale, 0.0, Vector2.ZERO)
		draw_set_transform_matrix(xf * Transform2D(0.0, pic))
		Cosmetics.draw_ride(self, str(d.get("reward", "")), 86.0, 54.0, null, _t)
		draw_set_transform(c, tilt, Vector2.ONE * scale)
	else:
		_padlock_here(pic, 24.0)
	if open and locked:
		# A gold padlock over it until a key's used.
		DrawUtil.rrect(self, Rect2(-TICKET.x / 2.0, -TICKET.y / 2.0 + 34, TICKET.x, TICKET.y - 34), Color(1, 1, 1, 0.55), 8)
		var bounce := absf(sin(_t * 3.0)) * 6.0 if Progress.keys > 0 else 0.0
		_padlock_here(pic + Vector2(0, -bounce), 32.0, Icons.GOLD)
	elif opening >= 0.0 and opening < 0.9:
		# Just unlocked: the shackle flies up and the lock drops away.
		var u := opening / 0.9
		_padlock_here(pic + Vector2(0, 120.0 * u * u), 32.0 * (1.0 - 0.3 * u), Color(Icons.GOLD, 1.0 - u), 30.0 * minf(u * 4.0, 1.0))
	var title := str(d.get("title", "")) if open else "after job %d" % int(sp["n"])
	_ticket_pin(title, open, (Color("e03131") if boss else band.darkened(0.2)) if open else Color("9a94a6"))
	if open and locked:
		var asked := _t - float(sp.get("need_key", -9.0)) < 2.5
		var line := ("TAP TO USE A KEY (%d)" % Progress.keys) if Progress.keys > 0 else ("FIND A KEY ON AN EARLIER JOB" if asked else "NEEDS A KEY")
		_plate(line, c + Vector2(0, TICKET.y / 2.0 + 30.0), Icons.GOLD if Progress.keys > 0 or asked else Color(0, 0, 0, 0.45), HAZARD_INK if Progress.keys > 0 or asked else Color.WHITE, 20)


## A milestone chest's ticket: grey and padlocked ("after job N") until its level's beaten; then gold and
## bouncing, in a burst of light, waiting to be opened; once opened, its lid stands open and it's put by.
func _draw_chest(sp: Dictionary) -> void:
	var n: int = sp["n"]
	var done := Progress.is_complete(n)
	var opened := Progress.chest_open(n)
	var can_open := done and not opened
	var c := _o(sp["b"]) + _shake_of(sp)
	var tilt := (-0.04 if n % 20 == 0 else 0.04) + sin(_t * 1.5 + n) * (0.03 if can_open else 0.006)
	var scale := 0.86
	if can_open:
		c.y -= absf(sin(_t * 3.2)) * 10.0
		scale = 0.9 + 0.03 * sin(_t * 4.0)
		for k in 10:
			var a := TAU * k / 10.0 + _t * 0.6
			var p1 := c + Vector2(cos(a), sin(a)) * 70.0
			var p2 := c + Vector2(cos(a + 0.16), sin(a + 0.16)) * 170.0
			var p3 := c + Vector2(cos(a - 0.16), sin(a - 0.16)) * 170.0
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color("ffe08a", 0.35))
	var band := Color("e0a11a") if can_open else (Color("b9b2a4") if not opened else Color("a39a86"))
	_spur_ticket(c, tilt, scale, band, "OPENED" if opened else "CHEST", can_open, opened)
	# The chest itself.
	var cc := Vector2(0, 6)
	var wood := Color("b8733a") if done else Color("b3aeb9")
	var gold := Color("ffcf4d") if done else Color("d6d2dc")
	if opened:
		wood = wood.lerp(Color("ebe5d7"), 0.45)
		gold = gold.lerp(Color("ebe5d7"), 0.45)
	var k := 0.7
	var body := Rect2(cc + Vector2(-52, -14) * k, Vector2(104, 56) * k)
	DrawUtil.rrect(self, Rect2(body.position + Vector2(0, 5), body.size), wood.darkened(0.3), 9)
	DrawUtil.rrect(self, body, wood, 9)
	if opened:
		DrawUtil.rrect(self, Rect2(cc + Vector2(-50, -58) * k, Vector2(100, 40) * k), wood.darkened(0.15), 9)
		DrawUtil.rrect(self, Rect2(cc + Vector2(-44, -18) * k, Vector2(88, 14) * k), Color("3a2418", 0.6), 5)
	else:
		DrawUtil.rrect(self, Rect2(cc + Vector2(-56, -46) * k, Vector2(112, 36) * k), wood.lightened(0.08), 12)
		draw_rect(Rect2(cc + Vector2(-56, -18) * k, Vector2(112, 6) * k), gold)
	for x in [-36.0, 36.0]:
		draw_rect(Rect2(cc + Vector2(x - 6, -46 if not opened else -14) * k, Vector2(12, 88 if not opened else 56) * k), gold)
	if not opened:
		DrawUtil.rrect(self, Rect2(cc + Vector2(-13, -24) * k, Vector2(26, 30) * k), gold.darkened(0.1), 5)
		draw_circle(cc + Vector2(0, -12) * k, 4.0, wood.darkened(0.45))
	if not done:
		_padlock_here(cc + Vector2(0, -4), 15.0)
	_ticket_pin("Open me!" if can_open else ("after job %d" % n if not done else "Job %d" % n), can_open, Color("e0a11a") if can_open else Color("9a94a6"))


## A mega route's sign: its parts as a little grid, the ones done so far ticked green.
func _draw_parts_grid(d: Dictionary, c: Vector2) -> void:
	var grid: Array = d.get("grid", [2, 1])
	var parts: Array = d.get("parts", [])
	var done := SideRoads.part_count(d) if Progress.side_done.has(str(d.get("id", ""))) and Progress.mega_part(str(d.get("id", ""))) == 0 else Progress.mega_part(str(d.get("id", "")))
	var cell := 30.0
	var gap := 6.0
	var gsz := Vector2(grid[0] * cell + (grid[0] - 1) * gap, grid[1] * cell + (grid[1] - 1) * gap)
	var o := c - gsz / 2.0
	for k in parts.size():
		var at: Array = parts[k].get("at", [k, 0])
		var r := Rect2(o + Vector2(at[0], at[1]) * (cell + gap), Vector2(cell, cell))
		DrawUtil.rrect(self, r, Palette.GOOD if k < done else Color("d5d0de"), 7)
		if k < done:
			draw_polyline(PackedVector2Array([r.get_center() + Vector2(-7, 0), r.get_center() + Vector2(-2, 5), r.get_center() + Vector2(8, -6)]), Color.WHITE, 3.5, true)


## A padlock under whatever transform is set (on a ticket).
func _padlock_here(c: Vector2, sz: float, col := Color("4a4458"), lift := 0.0) -> void:
	_padlock(c, sz, col, lift)


## A padlock; `lift` raises the shackle (it's springing open).
func _padlock(c: Vector2, s: float, col := Color("4a4458"), lift := 0.0) -> void:
	if col.a <= 0.0:
		return
	var hole := Color("c9c4d4") if col == Color("4a4458") else col.darkened(0.45)
	draw_arc(c + Vector2(0, -s * 0.3 - lift), s * 0.5, PI, TAU, 16, col.darkened(0.15) if col != Color("4a4458") else col, s * 0.22, true)
	if lift > 0.0:
		draw_line(c + Vector2(-s * 0.5, -s * 0.3 - lift), c + Vector2(-s * 0.5, -s * 0.3), col.darkened(0.15), s * 0.22)
	DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.75, -s * 0.3), Vector2(s * 1.5, s * 1.2)), col, s * 0.25)
	draw_circle(c + Vector2(0, s * 0.25), s * 0.18, hole)


# ---------------------------------------------------------------- scenery

func _draw_item(it: Dictionary) -> void:
	var c := _o(it["pos"])
	var s: float = it["s"]
	var sd: float = it["seed"]
	var ci: int = it["col"]
	var shadow := Color(0, 0, 0, 0.05)
	match it["kind"]:
		"house":
			var walls := [_bg(Color("fff1e0")), _bg(Color("ffd9c2")), _bg(Color("dff0ff")), _bg(Color("fff6c9")), _bg(Color("e8dcff")), _bg(Color("ffe0ea"))]
			var roofs := [_bg(Color("ff7a59")), _bg(Color("c0605a")), _bg(Color("4d8dff")), _bg(Color("8a6bd1")), _bg(Color("e0941a")), _bg(Color("ff5d8f"))]
			var w := 74.0 * s
			var h := 52.0 * s
			DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0 - 4, -h * 0.2), Vector2(w + 8, h * 0.95)), shadow, 10)
			DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0, -h * 0.4), Vector2(w, h)), walls[ci], 8)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.62, -h * 0.35), c + Vector2(0, -h * 1.05), c + Vector2(w * 0.62, -h * 0.35)]), roofs[ci])
			DrawUtil.rrect(self, Rect2(c + Vector2(-w * 0.12, h * 0.1), Vector2(w * 0.24, h * 0.5)), roofs[ci].darkened(0.25), 4)
			DrawUtil.rrect(self, Rect2(c + Vector2(w * 0.2, -h * 0.15), Vector2(w * 0.2, h * 0.2)), _bg(Palette.VAN_GLASS), 3)
		"tree":
			draw_circle(c + Vector2(0, 26 * s), 30 * s, shadow)
			draw_rect(Rect2(c + Vector2(-5 * s, 0), Vector2(10 * s, 26 * s)), _bg(Color("8a5a3c")))
			draw_circle(c, 32 * s, _bg(Palette.TREE))
			draw_circle(c + Vector2(-10, -10) * s, 14 * s, _bg(Palette.TREE_HI))
		"bush":
			for k in 3:
				draw_circle(c + Vector2((k - 1) * 18.0, (k % 2) * -6.0) * s, 17 * s, _bg(Palette.TREE).lightened(0.1 * k))
		"building":
			var cols := [_bg(Color("8fa3c4")), _bg(Color("c98a6b")), _bg(Color("e6dccb")), _bg(Color("7c8fb0")), _bg(Color("b8c4d6")), _bg(Color("d6a77a"))]
			var w := (60.0 + (ci % 3) * 14.0) * s
			var h := (110.0 + fmod(sd * 13.0, 70.0)) * s
			var base := c + Vector2(0, 40 * s)
			DrawUtil.rrect(self, Rect2(base + Vector2(-w / 2.0 + 8, -h + 8), Vector2(w, h)), shadow, 6)
			DrawUtil.rrect(self, Rect2(base + Vector2(-w / 2.0, -h), Vector2(w, h)), cols[ci], 6)
			draw_rect(Rect2(base + Vector2(-w / 2.0, -h), Vector2(w, 10 * s)), cols[ci].darkened(0.2))
			var rows := int(h / (24.0 * s)) - 1
			for ry in rows:
				for rx in 3:
					var lit := fmod(sd + ry * 3.0 + rx, 5.0) < 1.0
					var wc := _bg(Color("ffe28a")) if lit else _bg(Color("eef4ff", 0.8))
					draw_rect(Rect2(base + Vector2(-w / 2.0 + w * (0.14 + rx * 0.27), -h + 22 * s + ry * 24 * s), Vector2(w * 0.16, 12 * s)), wc)
		"lamp":
			draw_line(c + Vector2(0, 30), c + Vector2(0, -30), _bg(Color("444b59")), 6.0)
			draw_circle(c + Vector2(0, -34), 10.0, _bg(Color("ffe28a")))
			draw_circle(c + Vector2(0, -34), 20.0, Color(1, 0.9, 0.5, 0.25))
		"field":
			var cols := [_bg(Color("d9c45a")), _bg(Color("9cc95a")), _bg(Color("e3b04f")), _bg(Color("b8d06a")), _bg(Color("cfa94a")), _bg(Color("a7cf6b"))]
			var r := Rect2(c + Vector2(-60, -36) * s, Vector2(120, 72) * s)
			DrawUtil.rrect(self, r, cols[ci], 14 * s)
			for k in 5:
				var y := r.position.y + r.size.y * (0.16 + k * 0.17)
				draw_line(Vector2(r.position.x + 10 * s, y), Vector2(r.end.x - 10 * s, y), cols[ci].darkened(0.14), 4.0 * s, true)
		"barn":
			var w := 80.0 * s
			var h := 60.0 * s
			DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0, -h * 0.4), Vector2(w, h)), _bg(Color("d9534f")), 6)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.58, -h * 0.35), c + Vector2(-w * 0.3, -h * 0.85), c + Vector2(w * 0.3, -h * 0.85), c + Vector2(w * 0.58, -h * 0.35)]), _bg(Color("8a3a36")))
			var d := Rect2(c + Vector2(-w * 0.2, -h * 0.05), Vector2(w * 0.4, h * 0.65))
			draw_rect(d, _bg(Color("fff6e8")))
			draw_rect(d.grow(-4 * s), _bg(Color("d9534f")))
			draw_line(d.position, d.end, _bg(Color("fff6e8")), 4 * s)
			draw_line(Vector2(d.end.x, d.position.y), Vector2(d.position.x, d.end.y), _bg(Color("fff6e8")), 4 * s)
		"hay":
			draw_circle(c + Vector2(0, 6), 24 * s, shadow)
			draw_circle(c, 22 * s, _bg(Color("e8c25a")))
			draw_arc(c, 13 * s, 0, TAU * 0.85, 16, _bg(Color("c99a35")), 3.0, true)
			draw_arc(c, 6 * s, 0, TAU * 0.8, 10, _bg(Color("c99a35")), 3.0, true)
		"sunflower":
			draw_line(c + Vector2(0, 30 * s), c, _bg(Color("4f9a45")), 5.0 * s)
			for k in 8:
				var a := TAU * k / 8.0 + sd
				draw_circle(c + Vector2(cos(a), sin(a)) * 13 * s, 8 * s, _bg(Color("ffc53d")))
			draw_circle(c, 9 * s, _bg(Color("7a4a1c")))
		"silo":
			DrawUtil.rrect(self, Rect2(c + Vector2(-22, -60) * s, Vector2(44, 100) * s), _bg(Color("c9ced8")), 20 * s)
			for k in 3:
				draw_line(c + Vector2(-22, -30 + k * 24) * s, c + Vector2(22, -30 + k * 24) * s, _bg(Color("a3a9b5")), 3.0)
		"mesa":
			var w := 150.0 * s
			var h := 80.0 * s
			var pts := PackedVector2Array([c + Vector2(-w / 2.0, h / 2.0), c + Vector2(-w * 0.32, -h / 2.0), c + Vector2(w * 0.3, -h / 2.0), c + Vector2(w / 2.0, h / 2.0)])
			draw_colored_polygon(pts, _bg(Color("d9774a")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.32, -h / 2.0), c + Vector2(w * 0.3, -h / 2.0), c + Vector2(w * 0.34, -h * 0.3), c + Vector2(-w * 0.36, -h * 0.3)]), _bg(Color("ee9a62")))
			draw_line(c + Vector2(-w * 0.42, h * 0.15), c + Vector2(w * 0.42, h * 0.15), _bg(Color("c0613c")), 5.0 * s)
		"cactus":
			var g := _bg(Color("4fa36a")) if ci % 2 == 0 else _bg(Color("5bb878"))
			draw_circle(c + Vector2(0, 34 * s), 16 * s, shadow)
			DrawUtil.rrect(self, Rect2(c + Vector2(-9, -40) * s, Vector2(18, 76) * s), g, 9 * s)
			var side := -1.0 if it["flip"] else 1.0
			DrawUtil.rrect(self, Rect2(c + Vector2(side * 9.0 - (14.0 if side < 0 else 0.0), -4) * s, Vector2(14, 10) * s), g, 5 * s)
			DrawUtil.rrect(self, Rect2(c + Vector2(side * 18.0 - 7.0, -26) * s, Vector2(13, 30) * s), g, 6 * s)
		"rock":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 14) * s, c + Vector2(-18, -10) * s, c + Vector2(6, -18) * s, c + Vector2(26, 0) * s, c + Vector2(20, 16) * s]), _bg(Color("b98a6a")))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -10) * s, c + Vector2(6, -18) * s, c + Vector2(0, -2) * s]), _bg(Color("d4a684")))
		"mountain":
			var w := 170.0 * s
			var h := 130.0 * s
			var base := c + Vector2(0, h * 0.4)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-w / 2.0, 0), base + Vector2(0, -h), base + Vector2(w / 2.0, 0)]), _bg(Color("8a9bb8")))
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -h), base + Vector2(w / 2.0, 0), base + Vector2(w * 0.1, 0)]), _bg(Color("72829f")))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.17, -h * 0.66), base + Vector2(0, -h), base + Vector2(w * 0.17, -h * 0.66), base + Vector2(w * 0.06, -h * 0.58), base + Vector2(-w * 0.05, -h * 0.7)]), _bg(Color.WHITE))
		"pine":
			var g := _bg(Color("3f8a5c"))
			draw_circle(c + Vector2(0, 32 * s), 18 * s, shadow)
			draw_rect(Rect2(c + Vector2(-4, 20) * s, Vector2(8, 14) * s), _bg(Color("7a5236")))
			for k in 3:
				var y := c.y + (14.0 - k * 18.0) * s
				var hw := (30.0 - k * 7.0) * s
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - hw, y + 12 * s), Vector2(c.x, y - 22 * s), Vector2(c.x + hw, y + 12 * s)]), g.lightened(0.08 * k))
		"water":
			var r := Rect2(c + Vector2(-70, -38) * s, Vector2(140, 76) * s)
			DrawUtil.rrect(self, r.grow(6), _bg(Color("f3ead9", 0.8)), 40 * s)
			DrawUtil.rrect(self, r, _bg(Color("6cc3ea")), 38 * s)
			for k in 2:
				var y := r.position.y + r.size.y * (0.35 + 0.3 * k)
				var off := sin(_t * 1.5 + sd + k) * 8.0
				draw_line(Vector2(r.position.x + 30 * s + off, y), Vector2(r.position.x + 60 * s + off, y), Color(1, 1, 1, 0.7), 4.0, true)
			if ci % 2 == 0:
				var b := r.get_center() + Vector2(24 * s, -4 * s + sin(_t * 2.0 + sd) * 3.0)
				draw_colored_polygon(PackedVector2Array([b + Vector2(-16, 8) * s, b + Vector2(16, 8) * s, b + Vector2(10, 16) * s, b + Vector2(-10, 16) * s]), _bg(Color("c0605a")))
				draw_colored_polygon(PackedVector2Array([b + Vector2(0, -22) * s, b + Vector2(0, 6) * s, b + Vector2(14, 6) * s]), _bg(Color.WHITE))
		"palm":
			draw_circle(c + Vector2(8, 34) * s, 20 * s, shadow)
			draw_line(c + Vector2(0, 34) * s, c + Vector2(8, -14) * s, _bg(Color("a8754a")), 8.0 * s, true)
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.7
				var tip := c + Vector2(8, -14) * s + Vector2(cos(a), sin(a) + 0.5) * 36 * s
				draw_line(c + Vector2(8, -14) * s, tip, _bg(Color("3fa66a")), 9.0 * s, true)
		"umbrella":
			draw_line(c + Vector2(0, 28) * s, c + Vector2(0, -16) * s, _bg(Color("8a6b4a")), 4.0)
			var cols := [_bg(Color("ff5d5d")), _bg(Color("4d8dff")), _bg(Color("ffc53d")), _bg(Color("a26bf5")), _bg(Color("2fbf71")), _bg(Color("ff9233"))]
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -10) * s, c + Vector2(0, -36) * s, c + Vector2(34, -10) * s]), cols[ci])
			DrawUtil.rrect(self, Rect2(c + Vector2(10, 18) * s, Vector2(40, 16) * s), _bg(Color("fff6e8")), 6)
		"lighthouse":
			var base := c + Vector2(0, 50 * s)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-26, 0) * s, base + Vector2(-16, -110) * s, base + Vector2(16, -110) * s, base + Vector2(26, 0) * s]), _bg(Color.WHITE))
			for k in 2:
				var yy := (-30.0 - k * 40.0)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-24 + k * 3.5, yy) * s, base + Vector2(-21 + k * 3.5, yy - 18) * s, base + Vector2(21 - k * 3.5, yy - 18) * s, base + Vector2(24 - k * 3.5, yy) * s]), _bg(Color("ff5d5d")))
			draw_rect(Rect2(base + Vector2(-14, -130) * s, Vector2(28, 20) * s), _bg(Color("ffe28a")))
			var beam := 0.5 + 0.5 * sin(_t * 2.0)
			draw_circle(base + Vector2(0, -120) * s, 34 * s, Color(1, 0.9, 0.5, 0.25 * beam))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -134) * s, base + Vector2(0, -150) * s, base + Vector2(16, -134) * s]), _bg(Color("c0605a")))
		"skyline":
			var w := 46.0 * s
			for k in 3:
				var h := (80.0 + fmod(sd * (k + 3), 70.0)) * s
				var x := c.x + (k - 1) * (w + 4)
				var r := Rect2(Vector2(x - w / 2.0, c.y + 40 * s - h), Vector2(w, h))
				draw_rect(r, _bg(Color("1d1840")))
				for ry in int(h / (20 * s)) - 1:
					for rx in 2:
						if fmod(sd * 7.0 + ry * 1.7 + rx + k, 3.0) < 1.2:
							draw_rect(Rect2(r.position + Vector2(w * (0.2 + rx * 0.4), 14 * s + ry * 20 * s), Vector2(w * 0.2, 9 * s)), _bg(Color("ffd166", 0.85)))
		"cone":
			_cone(c, s)


func _cone(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 14) * s, c + Vector2(20, 14) * s, c + Vector2(0, -34) * s]), Color("ff8a1f"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -6) * s, c + Vector2(12, -6) * s, c + Vector2(7, -18) * s, c + Vector2(-7, -18) * s]), Color.WHITE)
	DrawUtil.rrect(self, Rect2(c + Vector2(-26, 10) * s, Vector2(52, 10) * s), Color("e0701a"), 4)


## A zone's toll gate: a striped boom across the road between two booths, and a sign with the packages it
## wants (a meter, "23 / 25"). Lifted once the zone's open. The zone that just opened gets a banner.
func _draw_gate(g: Dictionary) -> void:
	var c := _o(g["pos"])
	var zk := int(g["zone"])
	var opening := zk == _opening
	var ot := (_t - _opening_t) if opening else 0.0
	# The Baron's tape across the board where the district starts: yellow and black, HOARDLY INC. —
	# NO ENTRY. As the district opens it strains, snaps in the middle, and each half swings down off its pin.
	var left := Vector2(30, c.y)
	var right := Vector2(W - 30, c.y + 20)
	for pin in [left, right]:
		draw_circle(pin + Vector2(2, 4), 13.0, Color(0, 0, 0, 0.2))
		draw_circle(pin, 12.0, Color("4a4458"))
	var shut := _shut(zk) or (opening and ot < OPEN_SNAP)
	# A checkpoint at it (the zone's open, its checkpoint not passed; or just passed, and opening): a booth,
	# its striped boom across the road, and its sign. The boom swings up as it opens.
	if (Zones.is_open(zk) and Checkpoint.holds(zk)) or (opening and _open_booth and ot < 3.6):
		var up := _out_back(clampf((ot - OPEN_SNAP) / 0.5, 0.0, 1.0)) if opening else 0.0
		var fade := clampf((3.6 - ot) / 0.4, 0.0, 1.0) if opening else 1.0
		var b := Vector2(W - 170.0, c.y - 30.0)
		DrawUtil.rrect(self, Rect2(b + Vector2(-46, -70), Vector2(92, 100)), Color(Color("e9e4f0"), fade), 10)
		DrawUtil.rrect(self, Rect2(b + Vector2(-56, -88), Vector2(112, 24)), Color(Color("23325c"), fade), 6)
		DrawUtil.rrect(self, Rect2(b + Vector2(-30, -52), Vector2(60, 40)), Color(Color("bfe3ff"), fade), 6)
		var ang := PI + up * 1.15                    # (pointing left across the road; up as it opens)
		var dir := Vector2(cos(ang), sin(ang))
		for j in 9:
			draw_line(b + Vector2(-50, 24) + dir * (j * 44.0), b + Vector2(-50, 24) + dir * ((j + 1) * 44.0), Color(Color("d7192a") if j % 2 == 0 else Color.WHITE, fade), 14.0)
		draw_circle(b + Vector2(-50, 24), 12.0, Color(Color("4a4458"), fade))
		if fade >= 1.0:
			_plate("CHECKPOINT", b + Vector2(0, 62), HAZARD, HAZARD_INK, 22)
	var half := left.distance_to(Vector2(W / 2.0, c.y + 28.0))
	if shut:
		# Up: sagging a little; straining (shaking, pulled tight) just before it snaps.
		var strain := clampf(ot / OPEN_SNAP, 0.0, 1.0) if opening else 0.0
		var mid := Vector2(W / 2.0 + sin(_t * 70.0) * 7.0 * strain, c.y + 10.0 + 18.0 * (1.0 - strain) + sin(_t * 55.0) * 5.0 * strain)
		_tape(left, mid, 54.0)
		_tape(mid, right, 54.0)
	elif opening and ot < OPEN_SNAP + 1.5:
		# Snapped: each half swings down round its pin, bounces, then slips off.
		var k := clampf((ot - OPEN_SNAP) / 0.8, 0.0, 1.0)
		var swing := (1.0 - absf(cos(k * PI * 2.5)) * (1.0 - k)) * PI * 0.46
		var keep := 1.0 - clampf((ot - OPEN_SNAP - 1.0) / 0.5, 0.0, 1.0)
		var ln := half * keep
		_tape(left, left + Vector2(cos(swing), sin(swing)) * ln, 54.0)
		_tape(right + Vector2(-cos(swing), sin(swing)) * ln, right, 54.0)
		# A flash across the board as it goes.
		var flash := clampf(1.0 - (ot - OPEN_SNAP) / 0.3, 0.0, 1.0)
		if flash > 0.0:
			draw_rect(Rect2(0, c.y - 120.0, W, 240.0), Color(1, 1, 0.9, 0.22 * flash))


## A strip of hazard tape from a to b: yellow, black diagonals, the words along it.
func _tape(a: Vector2, b: Vector2, w: float) -> void:
	var dir := (b - a)
	var ln := dir.length()
	if ln < 1.0:
		return
	draw_set_transform(a, dir.angle(), Vector2.ONE)
	draw_rect(Rect2(0, -w / 2.0 + 6, ln, w), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(0, -w / 2.0, ln, w), HAZARD)
	var x := 0.0
	while x < ln:
		draw_colored_polygon(PackedVector2Array([Vector2(x, -w / 2.0), Vector2(x + 18, -w / 2.0), Vector2(x + 8, -w / 2.0 + 10), Vector2(x - 10, -w / 2.0 + 10)]), HAZARD_INK)
		draw_colored_polygon(PackedVector2Array([Vector2(x, w / 2.0 - 10), Vector2(x + 18, w / 2.0 - 10), Vector2(x + 8, w / 2.0), Vector2(x - 10, w / 2.0)]), HAZARD_INK)
		x += 36.0
	var f := UiTheme.font()
	var word := "HOARDLY INC. · NO ENTRY · "
	var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var tx := 10.0
	while tx < ln - 40.0:
		draw_string(f, Vector2(tx, 8), word, HORIZONTAL_ALIGNMENT_LEFT, ln - tx, 22, HAZARD_INK)
		tx += ww
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Past the first shut gate the road runs into fog: thin at the gate, thick further on, so it's plain the
## trip stops here for now. (As a zone opens the fog's edge rolls back up the map to the next gate.)
func _draw_fog(y0: float, y1: float) -> void:
	var gy := _fog_line()
	if gy == -INF or gy < y0:
		return
	# (At night a dusk-dark fog over the charcoal board: a cream one washed the top of the map out.)
	var fog := Color(0.86, 0.83, 0.78) if not Palette.night else Color(0.12, 0.13, 0.16)
	var top := maxf(y0, -400.0)
	var y := top
	while y < gy - 130.0:
		var d := gy - 130.0 - y
		var a := clampf(0.35 + d / 900.0, 0.0, 0.97)
		draw_rect(Rect2(0, y - scroll, W, 41.0), Color(fog, a))
		y += 40.0
	# A soft, drifting edge just past the gate (churning harder while it's rolling back).
	var rolling := _opening >= 0 and _t - _opening_t > OPEN_SNAP and _t - _opening_t < OPEN_SNAP + 1.4
	var speed := 5.0 if rolling else 1.0
	for i in 14:
		var x := fmod(i * 97.0 + _t * (12.0 + 4.0 * (i % 3)) * speed, W + 200.0) - 100.0
		var r := 90.0 + 30.0 * sin(i * 1.7 + _t * 0.6 * speed)
		draw_circle(Vector2(x, gy - 150.0 - 20.0 * sin(i * 2.3) - scroll), r, Color(fog, 0.55))
		draw_circle(Vector2(x + 50.0, gy - 250.0 - 30.0 * cos(i * 1.3) - scroll), r * 1.2, Color(fog, 0.6))
	if rolling:
		# A bright rim along the retreating edge.
		draw_rect(Rect2(0, gy - 120.0 - scroll, W, 16.0), Color(1, 0.95, 0.7, 0.5))


## Where the fog starts: the first gate still shut (the lowest on the map), or -INF. While a zone's opening
## it starts at that zone's gate until the tape snaps, then rolls back to the next shut gate (or off the
## top of the map).
func _fog_line() -> float:
	var gy := -INF
	var open_y := -INF
	for g in gates:
		if int(g["zone"]) == _opening:
			open_y = g["pos"].y
		elif _shut(int(g["zone"])):
			gy = maxf(gy, g["pos"].y)
	if open_y == -INF or open_y < gy:
		return gy
	var ot := _t - _opening_t
	if ot < OPEN_SNAP:
		return open_y
	var k := clampf((ot - OPEN_SNAP) / 1.3, 0.0, 1.0)
	var to := gy if gy != -INF else open_y - 3200.0
	if k >= 1.0:
		return gy
	return lerpf(open_y, to, k * k * (3.0 - 2.0 * k))


## The gate's sign, over the fog: the zone's name, a meter (packages delivered against what it wants) and
## how many more. A tapped locked stop makes it bounce.
func _draw_gate_sign(g: Dictionary) -> void:
	var c := _o(g["pos"])
	var zk := int(g["zone"])
	var open := Zones.is_open(zk)
	if (not open or Checkpoint.holds(zk)) and g["pos"].y < _fog_line() - 1.0:
		return          # further on, in the fog: only the first gate's sign shows
	if open and Checkpoint.holds(zk) and zk != _opening:
		# Open, but for its checkpoint: the sign says so, and a tap on it pulls the van up.
		var f := UiTheme.font()
		var w := 560.0
		var h := 190.0
		var at := Vector2(W / 2.0, c.y - 250.0)
		var s := 1.0 + 0.03 * sin(_t * 4.0)
		draw_set_transform(at, 0.0, Vector2.ONE * s)
		DrawUtil.rrect(self, Rect2(Vector2(-w / 2.0, -h / 2.0 + 10), Vector2(w, h)), Color(0, 0, 0, 0.2), 30)
		DrawUtil.rrect(self, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), HAZARD_INK, 30)
		draw_string(f, Vector2(-w / 2.0, -h / 2.0 + 58), Zones.name_of(zk), HORIZONTAL_ALIGNMENT_CENTER, w, 44, Color.WHITE)
		DrawUtil.rrect(self, Rect2(Vector2(-200, -16), Vector2(400, 54)), HAZARD, 14)
		draw_string(f, Vector2(-200, 24), "CHECKPOINT AHEAD", HORIZONTAL_ALIGNMENT_CENTER, 400, 32, HAZARD_INK)
		# (Only once the road's got this far: every job before it delivered or jumped.)
		var first := _zone_first(zk)
		var way := Zones.in_the_way(levels[first].number)
		# (What stands in the way is said as the job that ends the zone before: its boss.)
		draw_string(f, Vector2(-w / 2.0, 76), "Tap to pull up" if way == 0 else "Beat the Baron at job %d first" % (levels[first].number - 1), HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color(1, 1, 1, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if way == 0:
			_cp_rect = Rect2(at - Vector2(w, h) / 2.0, Vector2(w, h)).grow(20.0)
			_cp_first = first
	elif not open:
		var flash := _gate_flash == zk and _t - _gate_flash_t < 1.6
		var s := 1.0 + (0.12 * sin(clampf((_t - _gate_flash_t) / 0.3, 0.0, 1.0) * PI) if flash else 0.0)
		var need := Zones.need(zk)
		var have := Progress.delivered()
		var f := UiTheme.font()
		var w := 560.0
		var h := 230.0
		var at := Vector2(W / 2.0, c.y - 260.0)
		draw_set_transform(at, 0.0, Vector2.ONE * s)
		DrawUtil.rrect(self, Rect2(Vector2(-w / 2.0, -h / 2.0 + 10), Vector2(w, h)), Color(0, 0, 0, 0.2), 30)
		DrawUtil.rrect(self, Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), Color("ff7a59") if flash else HAZARD_INK, 30)
		draw_string(f, Vector2(-w / 2.0, -h / 2.0 + 56), Zones.name_of(zk), HORIZONTAL_ALIGNMENT_CENTER, w, 44, Color.WHITE)
		# The meter: a bar filling with gold, a big parcel at its end, and the count.
		var bar := Rect2(-w / 2.0 + 40, -6, w - 150, 40)
		DrawUtil.rrect(self, bar, Color(1, 1, 1, 0.16), 20)
		var k := clampf(float(have) / maxf(need, 1), 0.0, 1.0)
		if k > 0.0:
			DrawUtil.rrect(self, Rect2(bar.position, Vector2(maxf(bar.size.x * k, 40.0), bar.size.y)), Palette.STAR_GOLD, 20)
		# Ticks every 25 packages.
		var t := 25
		while t < need:
			var x := bar.position.x + bar.size.x * t / float(need)
			draw_line(Vector2(x, bar.position.y + 8), Vector2(x, bar.end.y - 8), Color(HAZARD_INK, 0.35), 3.0)
			t += 25
		Icons.draw(self, "box", Vector2(bar.end.x + 52, bar.get_center().y), 80.0 + 8.0 * sin(_t * 3.0), Color.WHITE)
		draw_string(f, Vector2(-w / 2.0, bar.end.y + 50), "%d / %d" % [have, need], HORIZONTAL_ALIGNMENT_CENTER, w, 38, Palette.STAR_GOLD)
		draw_string(f, Vector2(-w / 2.0, bar.end.y + 88), "%d more package%s to open the gate" % [need - have, "" if need - have == 1 else "s"], HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color(1, 1, 1, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif zk == _opening and _t - _opening_t > OPEN_SNAP:
		var ot := _t - _opening_t
		var a := clampf((ot - OPEN_SNAP) / 0.2, 0.0, 1.0) * clampf((4.2 - ot) / 0.4, 0.0, 1.0)
		var txt := "%s is open!" % Zones.name_of(zk)
		var f := UiTheme.font()
		var px := 64
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := c + Vector2(0, -150)
		var pop := _out_back(clampf((ot - OPEN_SNAP) / 0.35, 0.0, 1.0)) * (1.0 + 0.04 * sin(_t * 7.0))
		draw_set_transform(at, -0.05, Vector2.ONE * pop)
		DrawUtil.rrect(self, Rect2(Vector2(-tw / 2.0 - 34, -62), Vector2(tw + 68, 92)), Color(Palette.STAR_GOLD, a), 24)
		draw_string_outline(f, Vector2(-tw / 2.0, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 12, Color(HAZARD_INK, a))
		draw_string(f, Vector2(-tw / 2.0, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
