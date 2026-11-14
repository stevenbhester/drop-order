class_name RoadMap
extends Control
## The level select as a road trip: one winding road from the depot at the bottom (level 1) up through
## themed regions, with every level a stop on it. Drag or fling to scroll (mouse wheel too); tap a stop to
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
const PERFECT := Color("ffcf4d")
const PERFECT_INK := Color("7a4a00")
const PEEK := Color("7b5cff")

## Regions in order up the map. `ground` is the land colour, `kind` picks the scenery.
const REGIONS := [
	{"name": "Maple Suburbs", "from": 1, "to": 7, "kind": "suburbs", "ground": Color("bfe3a0")},
	{"name": "Downtown", "from": 8, "to": 14, "kind": "city", "ground": Color("d6dbe0")},
	{"name": "Sunflower Farms", "from": 15, "to": 21, "kind": "farm", "ground": Color("e9de94")},
	{"name": "Cactus Canyon", "from": 22, "to": 28, "kind": "canyon", "ground": Color("f4c993")},
	{"name": "Pine Peaks", "from": 29, "to": 34, "kind": "peaks", "ground": Color("b7dcc3")},
	{"name": "Seaside Lights", "from": 35, "to": 40, "kind": "sea", "ground": Color("f7e6b8")},
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
var depot := Vector2.ZERO
var scenery: Array = []          # {kind, pos, s, seed, col}
## Side roads branching off at some stops: {kind ("side" or "chest"), n (the stop's level), a (the stop),
## b (the end), and for side roads id and def; shake (a locked one shakes its head)}.
var spurs: Array = []
var _pressed_spur := -1
var next := 0                    # next level to play (index); -1 when every level is done
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
	next = -1
	for i in levels.size():
		if not Progress.is_complete(levels[i].number):
			next = i
			break
	_layout_world()
	_scatter()
	van = Van.new()
	van.size = 150.0
	van.inviting = next >= 0
	add_child(van)
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
			road.append(_catmull(p0, p1, p2, p3, float(k) / SUBDIV))
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


## A short spur off the road at each side road's and chest's stop: sideways, toward whichever side is
## clearer (out from the middle, back in from the edges), dodging region signs.
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
		var a: Vector2 = stops[i]
		var dx := a.x - W / 2.0
		var dir := signf(dx) if absf(dx) < 200.0 else -signf(dx)
		if dir == 0.0:
			dir = 1.0
		var b := a + Vector2(dir * SPUR_LEN, -36.0)
		for sg in signs:
			if (sg["pos"] as Vector2).distance_to(b) < 200.0:
				b = a + Vector2(-dir * SPUR_LEN, -36.0)
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
			scenery.append({"kind": item, "pos": pos, "s": rng.randf_range(0.85, 1.2), "seed": rng.randf() * 100.0,
				"col": rng.randi_range(0, 5), "flip": rng.randf() < 0.5})
		gy += cell * 0.8
	scenery.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)


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
	next = to_i
	_drive_from = road_len[stop_sample[from_i]]
	_drive_to = road_len[stop_sample[to_i]] - 135.0
	_drive_dur = clampf((_drive_to - _drive_from) / 900.0, 0.8, 1.6)
	_drive_t = 0.0
	focus(from_i)
	van.inviting = false
	Sfx.play("whoosh", 1.0, -6.0)


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
		_pop_stop = next
		_pop_t0 = _t
		van.inviting = true
		Sfx.play("pop", 1.1, -2.0)
		Sfx.play("star", 1.2, -8.0)
		Sfx.haptic(16)
		drive_done.emit()


## Scroll so level `i` sits a little below the middle of the visible map.
func focus(i: int) -> void:
	if stops.is_empty():
		return
	if i < 0 or i >= stops.size():
		i = stops.size() - 1
	var visible_mid := pad_top + (size.y - pad_top - pad_bottom) * 0.55
	scroll = clampf(stops[i].y - visible_mid, min_scroll(), max_scroll())


func _gui_input(event: InputEvent) -> void:
	if _drive_t >= 0.0:
		if event is InputEventMouseButton and event.pressed:
			finish_drive()
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
					if hit >= 0 and hit == _pressed:
						Sfx.play("click")
						stop_pressed.emit(hit)
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
	_t += delta
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
	# A fixed distance back along the road from the stop, so it never sits on a sign or the barrier.
	var s: int = stop_sample[next] if next >= 0 else stop_sample[stops.size() - 1]
	if next >= 0:
		var want: float = road_len[s] - 135.0
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
	for sp in spurs:
		var b: Vector2 = sp["b"]
		if b.y > y0 - 100.0 and b.y < y1 + 100.0:
			_draw_spur_road(sp)
	_draw_road(y0, y1)
	_draw_depot()
	if barrier != Vector2.INF and barrier.y > y0 and barrier.y < y1:
		_draw_barrier()
	for sg in signs:
		var sp: Vector2 = sg["pos"]
		if sp.y > y0 - 100.0 and sp.y < y1 + 100.0:
			_draw_sign(sg)
	for i in stops.size():
		if stops[i].y > y0 and stops[i].y < y1:
			_draw_stop(i)
	_draw_other_van()
	if y0 < 420.0:
		_draw_road_end()
	for sp in spurs:
		var b: Vector2 = sp["b"]
		if b.y > y0 - 100.0 and b.y < y1 + 100.0:
			if sp["kind"] == "side":
				_draw_side_sign(sp)
			else:
				_draw_chest(sp)


func _draw_ground(y0: float, y1: float) -> void:
	var blend := 150.0
	for k in regions.size():
		var reg: Dictionary = regions[k]
		var top: float = maxf(reg["y0"], y0)
		var bot: float = minf(reg["y1"], y1)
		if bot <= top:
			continue
		var col: Color = reg["def"]["ground"]
		draw_rect(Rect2(Vector2(0, top - scroll), Vector2(size.x, bot - top)), col)
	# Soft blends across region borders.
	for k in range(1, regions.size()):
		var b: float = regions[k]["y1"]
		if b < y0 - blend or b > y1 + blend:
			continue
		var upper: Color = regions[k]["def"]["ground"]
		var lower: Color = regions[k - 1]["def"]["ground"]
		var a := Vector2(0, b - blend - scroll)
		var c := Vector2(size.x, b + blend - scroll)
		draw_polygon(PackedVector2Array([a, Vector2(c.x, a.y), c, Vector2(a.x, c.y)]),
			PackedColorArray([upper, upper, lower, lower]))
	# A few texture flecks so the ground isn't flat.
	var start := int(floor(y0 / 90.0))
	for j in range(start, int(y1 / 90.0) + 1):
		var h := (j * 92821) % 997
		var p := Vector2(fmod(h * 7.31, W), j * 90.0 + (h % 50))
		var k := _region_at_y(p.y)
		var gcol: Color = regions[k]["def"]["ground"]
		var fleck := gcol.darkened(0.06) if regions[k]["def"]["kind"] != "night" else Color(1, 1, 0.85, 0.5 + 0.5 * sin(_t * 2.0 + h))
		if regions[k]["def"]["kind"] == "night":
			Icons.star(self, _o(p), 6.0 + (h % 5), fleck, _t * 0.2 + h)
		else:
			DrawUtil.rrect(self, Rect2(_o(p), Vector2(46, 14)), fleck, 7)


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
	var pts := PackedVector2Array()
	for i in range(lo, hi + 1):
		pts.append(_o(road[i]))
	var done_to: int = stop_sample[next] if next >= 0 else road.size() - 1
	# Shadow, curb, then pale (untravelled) asphalt, then the travelled part over it.
	draw_polyline(_shift(pts, Vector2(0, 8)), Color(0, 0, 0, 0.12), ROAD_W + 22.0, true)
	draw_polyline(pts, Color("efe7d8"), ROAD_W + 18.0, true)
	draw_polyline(pts, Color("b9bfcb"), ROAD_W, true)
	if done_to > lo:
		var drv := PackedVector2Array()
		for i in range(lo, mini(done_to, hi) + 1):
			drv.append(_o(road[i]))
		if drv.size() >= 2:
			draw_polyline(drv, Palette.ROAD, ROAD_W, true)
	for i in [lo, hi]:
		draw_circle(pts[0] if i == lo else pts[pts.size() - 1], (ROAD_W + 18.0) / 2.0, Color("efe7d8"))
	# Centre dashes: gold where you've driven, white further on.
	var dash := 30.0
	var gap := 26.0
	var i0 := lo
	while i0 < hi:
		var d0 := road_len[i0]
		var phase := fmod(d0, dash + gap)
		if phase < dash:
			var j := i0
			while j < hi and road_len[j] - d0 < dash - phase:
				j += 1
			var col := Color("ffd166") if i0 < done_to else Color(1, 1, 1, 0.75)
			draw_line(_o(road[i0]), _o(road[j]), col, 7.0, true)
			i0 = j + 1
		else:
			i0 += 1


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


func _draw_depot() -> void:
	var c := _o(depot)
	if c.y < -300.0 or c.y > size.y + 300.0:
		return
	# The warehouse the trip starts from.
	DrawUtil.rrect(self, Rect2(c + Vector2(-190, -40), Vector2(380, 190)), Color(0, 0, 0, 0.12), 26)
	DrawUtil.rrect(self, Rect2(c + Vector2(-180, -60), Vector2(360, 190)), Color("fffaf2"), 24)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-200, -50), c + Vector2(0, -150), c + Vector2(200, -50)]), Palette.ACCENT)
	DrawUtil.rrect(self, Rect2(c + Vector2(-70, 10), Vector2(140, 120)), Color("596273"), 14)
	for k in 4:
		draw_line(c + Vector2(-62, 30 + k * 26), c + Vector2(62, 30 + k * 26), Color("444b59"), 5.0)
	_text("LAST MILE DEPOT", c + Vector2(0, -22), 34, Palette.TEXT)
	# Reset progress, small, under the depot.
	var rp := depot + Vector2(0, 200)
	_text("Reset progress", _o(rp), 30, Palette.TEXT_SOFT)
	_reset_rect = Rect2(rp - Vector2(150, 30), Vector2(300, 60))


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


func _draw_sign(sg: Dictionary) -> void:
	var reg: Dictionary = regions[sg["region"]]
	var def: Dictionary = reg["def"]
	var c := _o(sg["pos"])
	var night: bool = def["kind"] == "night"
	var title: String = def.get("title", def["name"])
	var px := 44 if title.length() < 18 else 36
	var f := UiTheme.font()
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var w := maxf(tw + 70.0, 380.0)
	var h := 128.0 if not def.has("note") else 176.0
	var wood := Color("c98a52") if not night else Color("7b5cff")
	var plank := Color("e8b07a") if not night else Color("9a82ff")
	# Posts, shadow, board.
	for sx in [-w * 0.32, w * 0.32]:
		draw_rect(Rect2(c + Vector2(sx - 9, 0), Vector2(18, h * 0.5 + 40)), wood.darkened(0.25))
	DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0, -h / 2.0 + 10), Vector2(w, h)), Color(0, 0, 0, 0.15), 22)
	DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0, -h / 2.0), Vector2(w, h)), wood, 22)
	DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0 + 8, -h / 2.0 + 8), Vector2(w - 16, h - 16)), plank, 16)
	var first: int = levels[reg["first"]].number
	var last: int = levels[reg["last"]].number
	var ink := Color("5a3418") if not night else Color.WHITE
	if def.has("note"):
		_text(title, c + Vector2(0, -48), px, ink)
		_text("Levels %d–%d" % [first, last], c + Vector2(0, 2), 30, Color(ink, 0.75))
		_text(def["note"], c + Vector2(0, 50), 24, Color(ink, 0.9))
	else:
		_text(title, c + Vector2(0, -18), px, ink)
		_text("Levels %d–%d" % [first, last], c + Vector2(0, 32), 30, Color(ink, 0.7))


## Challenge levels' hazard colours.
const HAZARD := Color("ffc93c")
const HAZARD_INK := Color("2b2233")


func _draw_stop(i: int) -> void:
	var L: LevelData = levels[i]
	var stars := Progress.stars_for(L.number)
	var done := Progress.is_complete(L.number)
	var is_next := i == next
	var night := L.preview
	var c := _o(stops[i])
	var scale := 1.0
	if is_next:
		scale = 1.06 + 0.05 * sin(_t * 4.0)
		c.y += -6.0 * absf(sin(_t * 2.0))
	if i == _pressed:
		scale *= 0.9
	if i == _pop_stop:
		var pk := clampf((_t - _pop_t0) / 0.45, 0.0, 1.0)
		scale *= 1.0 + 0.45 * sin(PI * pk) * (1.0 - pk * 0.5)
	var r := PIN_R * scale
	var bg := Color.WHITE
	var fg := Color(Palette.TEXT, 0.55)
	if stars >= 3:
		bg = PERFECT
		fg = PERFECT_INK
	elif done:
		bg = Palette.GOOD
		fg = Color.WHITE
	elif is_next:
		bg = Palette.ACCENT
		fg = Color.WHITE
	elif night:
		bg = Color("4a3c8c")
		fg = Color(1, 1, 1, 0.85)
	# Pulsing rings around the next stop.
	if is_next:
		for k0 in [0.0, 0.5]:
			var k := fmod(_t / 1.4 + k0, 1.0)
			draw_arc(c, r * (1.15 + 0.6 * k), 0, TAU, 48, Color(Palette.ACCENT, 0.7 * (1.0 - k)), 8.0, true)
	draw_circle(c + Vector2(0, 10), r + 10.0, Color(0, 0, 0, 0.18))
	draw_circle(c, r + 10.0, Color.WHITE)
	if L.challenge:
		# Challenge levels: a hazard-striped rim, turning slowly.
		var segs := 18
		for k in segs:
			var a0 := TAU * k / segs + _t * 0.4
			draw_arc(c, r + 5.0, a0, a0 + TAU / segs, 6, HAZARD if k % 2 == 0 else HAZARD_INK, 11.0, true)
	draw_circle(c, r, bg)
	draw_circle(c + Vector2(0, r * 0.12), r * 0.86, bg.darkened(0.06))
	draw_circle(c, r * 0.86, bg)
	_text(str(L.number), c + Vector2(0, -2), int(54 * scale), fg)
	# Stars on a little plate under the pin.
	if done or is_next:
		var plate := Rect2(c + Vector2(-66, r + 4), Vector2(132, 42))
		DrawUtil.rrect(self, plate, Color(1, 1, 1, 0.92), 21)
		for k in 3:
			var sc := plate.get_center() + Vector2((k - 1) * 40.0, 0)
			Icons.star(self, sc, 15.0, Palette.STAR_GOLD if k < stars else Color(Palette.TEXT, 0.14))
	# A present still waiting on this level's road.
	if L.gift_item != "" and not Progress.owns(L.gift_item):
		var g := c + Vector2(r * 0.78, -r * 0.78)
		draw_circle(g, 27.0, Color.WHITE)
		Icons.draw(self, "gift", g + Vector2(0, 3), 36.0, Color("ff3d9a"))
	if L.challenge:
		# ...and a flame badge on the pin's shoulder (it flickers until it's beaten).
		var b := c + Vector2(-r * 0.8, -r * 0.8)
		draw_circle(b + Vector2(0, 4), 29.0, Color(0, 0, 0, 0.18))
		draw_circle(b, 29.0, HAZARD_INK)
		draw_circle(b, 24.0, HAZARD)
		AnimeFire.draw_flame(self, b + Vector2(0, 15), 26.0, 38.0 + (4.0 * sin(_t * 9.0) if not done else 0.0), _t if not done else 0.0, 7.0, AnimeFire.palette(4))
	if L.preview and not done:
		var f := UiTheme.font()
		var tw := f.get_string_size("PEEK", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var t := c + Vector2(0, -r - 14)
		DrawUtil.rrect(self, Rect2(t + Vector2(-tw / 2.0 - 12, -16), Vector2(tw + 24, 32)), PEEK, 16)
		draw_string(f, t + Vector2(-tw / 2.0, 8), "PEEK", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


# ---------------------------------------------------------------- odd things

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
		if wp.distance_to(spurs[k]["b"]) < 80.0:
			return k
	return -1


func _tap_spur(k: int) -> void:
	var sp: Dictionary = spurs[k]
	var n: int = sp["n"]
	if sp["kind"] == "side":
		if Progress.side_open(sp["def"]):
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
	Sfx.haptic(14, 0.6)
	sp["shake"] = 0.35


func _shake_of(sp: Dictionary) -> Vector2:
	var k: float = sp["shake"]
	return Vector2(sin(k * 60.0) * 9.0 * (k / 0.35), 0)


## The spur itself: a narrower road, paved once it's open.
func _draw_spur_road(sp: Dictionary) -> void:
	var a := _o(sp["a"])
	var b := _o(sp["b"])
	var open := Progress.is_complete(int(sp["n"]))
	var pts := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		# A gentle bend: out level first, then up to the end.
		var ctrl := Vector2(b.x, a.y)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	draw_polyline(_shift(pts, Vector2(0, 8)), Color(0, 0, 0, 0.1), SPUR_W + 18.0, true)
	draw_polyline(pts, Color("efe7d8"), SPUR_W + 14.0, true)
	draw_polyline(pts, Palette.ROAD if open else Color("b9bfcb"), SPUR_W, true)
	for k in range(1, 8, 2):
		draw_line(pts[k], pts[k + 1], Color(1, 1, 1, 0.6), 5.0, true)


func _plate(text: String, at: Vector2, bg: Color, fg: Color, px := 24) -> void:
	var f := UiTheme.font()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	DrawUtil.rrect(self, Rect2(at + Vector2(-tw / 2.0 - 14, -px * 0.75), Vector2(tw + 28, px * 1.5)), bg, px * 0.75)
	draw_string(f, at + Vector2(-tw / 2.0, px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)


## A side road's end: a round pad with the ride it wins, under a DETOUR plate; padlocked until its stop's
## level is beaten; a tick once it's won.
func _draw_side_sign(sp: Dictionary) -> void:
	var d: Dictionary = sp["def"]
	var c := _o(sp["b"]) + _shake_of(sp)
	var open := Progress.side_open(d)
	var won := Progress.side_done.has(sp["id"])
	var r := 60.0
	if open and not won:
		for k0 in [0.0, 0.5]:
			var k := fmod(_t / 1.6 + k0, 1.0)
			draw_arc(c, r * (1.1 + 0.5 * k), 0, TAU, 40, Color(SIDE_COL, 0.6 * (1.0 - k)), 6.0, true)
	draw_circle(c + Vector2(0, 9), r + 8.0, Color(0, 0, 0, 0.18))
	draw_circle(c, r + 8.0, Color.WHITE)
	draw_circle(c, r, SIDE_COL if open else Color("c9c4d4"))
	var mega := SideRoads.is_mega(d)
	if open and mega:
		_draw_parts_grid(d, c)
	elif open:
		draw_set_transform(c + Vector2(0, 2), -0.35, Vector2.ONE)
		Cosmetics.draw_ride(self, str(d.get("reward", "")), 86.0, 54.0, null, _t)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_padlock(c, 26.0)
	if won:
		var tc := c + Vector2(r * 0.72, -r * 0.72)
		draw_circle(tc, 22.0, Color.WHITE)
		draw_circle(tc, 18.0, Palette.CHECK)
		draw_polyline(PackedVector2Array([tc + Vector2(-8, 0), tc + Vector2(-2, 6), tc + Vector2(9, -6)]), Color.WHITE, 4.0, true)
	var label := str(d.get("title", "")).to_upper() if open else "BEAT %d" % int(sp["n"])
	_plate(label, c + Vector2(0, r + 30.0), Color("2b2233") if open else Color(0, 0, 0, 0.35), Color.WHITE, 22)
	if mega:
		_plate("MEGA ROUTE", c + Vector2(0, -r - 22.0), Color("38d9a9"), HAZARD_INK, 20)
	else:
		_plate("DETOUR", c + Vector2(0, -r - 22.0), HAZARD, HAZARD_INK, 20)


## A milestone chest: grey and padlocked until its level's beaten; then it bounces in a burst of light,
## waiting to be opened; once opened, its lid stands open, empty.
func _draw_chest(sp: Dictionary) -> void:
	var n: int = sp["n"]
	var done := Progress.is_complete(n)
	var opened := Progress.chest_open(n)
	var can_open := done and not opened
	var c := _o(sp["b"]) + _shake_of(sp)
	if can_open:
		c.y -= absf(sin(_t * 3.2)) * 12.0
		for k in 10:
			var a := TAU * k / 10.0 + _t * 0.6
			var p1 := c + Vector2(cos(a), sin(a)) * 46.0
			var p2 := c + Vector2(cos(a + 0.16), sin(a + 0.16)) * 120.0
			var p3 := c + Vector2(cos(a - 0.16), sin(a - 0.16)) * 120.0
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color("ffe08a", 0.35))
	var wood := Color("b8733a") if done else Color("b3aeb9")
	var band := Color("ffcf4d") if done else Color("d6d2dc")
	draw_circle(_o(sp["b"]) + Vector2(0, 40), 52.0, Color(0, 0, 0, 0.15))
	var body := Rect2(c + Vector2(-52, -14), Vector2(104, 56))
	DrawUtil.rrect(self, Rect2(body.position + Vector2(0, 6), body.size), wood.darkened(0.3), 12)
	DrawUtil.rrect(self, body, wood, 12)
	if opened:
		# Lid flung back, the inside dark and empty.
		DrawUtil.rrect(self, Rect2(c + Vector2(-50, -58), Vector2(100, 40)), wood.darkened(0.15), 12)
		DrawUtil.rrect(self, Rect2(c + Vector2(-44, -18), Vector2(88, 14)), Color("3a2418"), 6)
	else:
		DrawUtil.rrect(self, Rect2(c + Vector2(-56, -46), Vector2(112, 36)), wood.lightened(0.08), 16)
		draw_rect(Rect2(c + Vector2(-56, -18), Vector2(112, 6)), band)
	for x in [-36.0, 36.0]:
		draw_rect(Rect2(c + Vector2(x - 6, -46 if not opened else -14), Vector2(12, 88 if not opened else 56)), band)
	if not opened:
		DrawUtil.rrect(self, Rect2(c + Vector2(-13, -24), Vector2(26, 30)), band.darkened(0.1), 6)
		draw_circle(c + Vector2(0, -12), 5.0, wood.darkened(0.45))
	if not done:
		_padlock(c + Vector2(0, -6), 18.0)
	var label := "OPEN ME!" if can_open else ("BEAT %d" % n if not done else "")
	if label != "":
		_plate(label, c + Vector2(0, 70.0), Color("ffcf4d") if can_open else Color(0, 0, 0, 0.35), HAZARD_INK if can_open else Color.WHITE, 22)


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
		DrawUtil.rrect(self, r, Palette.GOOD if k < done else Color(1, 1, 1, 0.9), 7)
		if k < done:
			draw_polyline(PackedVector2Array([r.get_center() + Vector2(-7, 0), r.get_center() + Vector2(-2, 5), r.get_center() + Vector2(8, -6)]), Color.WHITE, 3.5, true)


func _padlock(c: Vector2, s: float) -> void:
	draw_arc(c + Vector2(0, -s * 0.3), s * 0.5, PI, TAU, 16, Color("4a4458"), s * 0.22, true)
	DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.75, -s * 0.3), Vector2(s * 1.5, s * 1.2)), Color("4a4458"), s * 0.25)
	draw_circle(c + Vector2(0, s * 0.25), s * 0.18, Color("c9c4d4"))


# ---------------------------------------------------------------- scenery

func _draw_item(it: Dictionary) -> void:
	var c := _o(it["pos"])
	var s: float = it["s"]
	var sd: float = it["seed"]
	var ci: int = it["col"]
	var shadow := Color(0, 0, 0, 0.12)
	match it["kind"]:
		"house":
			var walls := [Color("fff1e0"), Color("ffd9c2"), Color("dff0ff"), Color("fff6c9"), Color("e8dcff"), Color("ffe0ea")]
			var roofs := [Color("ff7a59"), Color("c0605a"), Color("4d8dff"), Color("8a6bd1"), Color("e0941a"), Color("ff5d8f")]
			var w := 74.0 * s
			var h := 52.0 * s
			DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0 - 4, -h * 0.2), Vector2(w + 8, h * 0.95)), shadow, 10)
			DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0, -h * 0.4), Vector2(w, h)), walls[ci], 8)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.62, -h * 0.35), c + Vector2(0, -h * 1.05), c + Vector2(w * 0.62, -h * 0.35)]), roofs[ci])
			DrawUtil.rrect(self, Rect2(c + Vector2(-w * 0.12, h * 0.1), Vector2(w * 0.24, h * 0.5)), roofs[ci].darkened(0.25), 4)
			DrawUtil.rrect(self, Rect2(c + Vector2(w * 0.2, -h * 0.15), Vector2(w * 0.2, h * 0.2)), Palette.VAN_GLASS, 3)
		"tree":
			draw_circle(c + Vector2(0, 26 * s), 30 * s, shadow)
			draw_rect(Rect2(c + Vector2(-5 * s, 0), Vector2(10 * s, 26 * s)), Color("8a5a3c"))
			draw_circle(c, 32 * s, Palette.TREE)
			draw_circle(c + Vector2(-10, -10) * s, 14 * s, Palette.TREE_HI)
		"bush":
			for k in 3:
				draw_circle(c + Vector2((k - 1) * 18.0, (k % 2) * -6.0) * s, 17 * s, Palette.TREE.lightened(0.1 * k))
		"building":
			var cols := [Color("8fa3c4"), Color("c98a6b"), Color("e6dccb"), Color("7c8fb0"), Color("b8c4d6"), Color("d6a77a")]
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
					var wc := Color("ffe28a") if lit else Color("eef4ff", 0.8)
					draw_rect(Rect2(base + Vector2(-w / 2.0 + w * (0.14 + rx * 0.27), -h + 22 * s + ry * 24 * s), Vector2(w * 0.16, 12 * s)), wc)
		"lamp":
			draw_line(c + Vector2(0, 30), c + Vector2(0, -30), Color("444b59"), 6.0)
			draw_circle(c + Vector2(0, -34), 10.0, Color("ffe28a"))
			draw_circle(c + Vector2(0, -34), 20.0, Color(1, 0.9, 0.5, 0.25))
		"field":
			var cols := [Color("d9c45a"), Color("9cc95a"), Color("e3b04f"), Color("b8d06a"), Color("cfa94a"), Color("a7cf6b")]
			var r := Rect2(c + Vector2(-60, -36) * s, Vector2(120, 72) * s)
			DrawUtil.rrect(self, r, cols[ci], 14 * s)
			for k in 5:
				var y := r.position.y + r.size.y * (0.16 + k * 0.17)
				draw_line(Vector2(r.position.x + 10 * s, y), Vector2(r.end.x - 10 * s, y), cols[ci].darkened(0.14), 4.0 * s, true)
		"barn":
			var w := 80.0 * s
			var h := 60.0 * s
			DrawUtil.rrect(self, Rect2(c + Vector2(-w / 2.0, -h * 0.4), Vector2(w, h)), Color("d9534f"), 6)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.58, -h * 0.35), c + Vector2(-w * 0.3, -h * 0.85), c + Vector2(w * 0.3, -h * 0.85), c + Vector2(w * 0.58, -h * 0.35)]), Color("8a3a36"))
			var d := Rect2(c + Vector2(-w * 0.2, -h * 0.05), Vector2(w * 0.4, h * 0.65))
			draw_rect(d, Color("fff6e8"))
			draw_rect(d.grow(-4 * s), Color("d9534f"))
			draw_line(d.position, d.end, Color("fff6e8"), 4 * s)
			draw_line(Vector2(d.end.x, d.position.y), Vector2(d.position.x, d.end.y), Color("fff6e8"), 4 * s)
		"hay":
			draw_circle(c + Vector2(0, 6), 24 * s, shadow)
			draw_circle(c, 22 * s, Color("e8c25a"))
			draw_arc(c, 13 * s, 0, TAU * 0.85, 16, Color("c99a35"), 3.0, true)
			draw_arc(c, 6 * s, 0, TAU * 0.8, 10, Color("c99a35"), 3.0, true)
		"sunflower":
			draw_line(c + Vector2(0, 30 * s), c, Color("4f9a45"), 5.0 * s)
			for k in 8:
				var a := TAU * k / 8.0 + sd
				draw_circle(c + Vector2(cos(a), sin(a)) * 13 * s, 8 * s, Color("ffc53d"))
			draw_circle(c, 9 * s, Color("7a4a1c"))
		"silo":
			DrawUtil.rrect(self, Rect2(c + Vector2(-22, -60) * s, Vector2(44, 100) * s), Color("c9ced8"), 20 * s)
			for k in 3:
				draw_line(c + Vector2(-22, -30 + k * 24) * s, c + Vector2(22, -30 + k * 24) * s, Color("a3a9b5"), 3.0)
		"mesa":
			var w := 150.0 * s
			var h := 80.0 * s
			var pts := PackedVector2Array([c + Vector2(-w / 2.0, h / 2.0), c + Vector2(-w * 0.32, -h / 2.0), c + Vector2(w * 0.3, -h / 2.0), c + Vector2(w / 2.0, h / 2.0)])
			draw_colored_polygon(pts, Color("d9774a"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.32, -h / 2.0), c + Vector2(w * 0.3, -h / 2.0), c + Vector2(w * 0.34, -h * 0.3), c + Vector2(-w * 0.36, -h * 0.3)]), Color("ee9a62"))
			draw_line(c + Vector2(-w * 0.42, h * 0.15), c + Vector2(w * 0.42, h * 0.15), Color("c0613c"), 5.0 * s)
		"cactus":
			var g := Color("4fa36a") if ci % 2 == 0 else Color("5bb878")
			draw_circle(c + Vector2(0, 34 * s), 16 * s, shadow)
			DrawUtil.rrect(self, Rect2(c + Vector2(-9, -40) * s, Vector2(18, 76) * s), g, 9 * s)
			var side := -1.0 if it["flip"] else 1.0
			DrawUtil.rrect(self, Rect2(c + Vector2(side * 9.0 - (14.0 if side < 0 else 0.0), -4) * s, Vector2(14, 10) * s), g, 5 * s)
			DrawUtil.rrect(self, Rect2(c + Vector2(side * 18.0 - 7.0, -26) * s, Vector2(13, 30) * s), g, 6 * s)
		"rock":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 14) * s, c + Vector2(-18, -10) * s, c + Vector2(6, -18) * s, c + Vector2(26, 0) * s, c + Vector2(20, 16) * s]), Color("b98a6a"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -10) * s, c + Vector2(6, -18) * s, c + Vector2(0, -2) * s]), Color("d4a684"))
		"mountain":
			var w := 170.0 * s
			var h := 130.0 * s
			var base := c + Vector2(0, h * 0.4)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-w / 2.0, 0), base + Vector2(0, -h), base + Vector2(w / 2.0, 0)]), Color("8a9bb8"))
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -h), base + Vector2(w / 2.0, 0), base + Vector2(w * 0.1, 0)]), Color("72829f"))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.17, -h * 0.66), base + Vector2(0, -h), base + Vector2(w * 0.17, -h * 0.66), base + Vector2(w * 0.06, -h * 0.58), base + Vector2(-w * 0.05, -h * 0.7)]), Color.WHITE)
		"pine":
			var g := Color("3f8a5c")
			draw_circle(c + Vector2(0, 32 * s), 18 * s, shadow)
			draw_rect(Rect2(c + Vector2(-4, 20) * s, Vector2(8, 14) * s), Color("7a5236"))
			for k in 3:
				var y := c.y + (14.0 - k * 18.0) * s
				var hw := (30.0 - k * 7.0) * s
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - hw, y + 12 * s), Vector2(c.x, y - 22 * s), Vector2(c.x + hw, y + 12 * s)]), g.lightened(0.08 * k))
		"water":
			var r := Rect2(c + Vector2(-70, -38) * s, Vector2(140, 76) * s)
			DrawUtil.rrect(self, r.grow(6), Color("f3ead9", 0.8), 40 * s)
			DrawUtil.rrect(self, r, Color("6cc3ea"), 38 * s)
			for k in 2:
				var y := r.position.y + r.size.y * (0.35 + 0.3 * k)
				var off := sin(_t * 1.5 + sd + k) * 8.0
				draw_line(Vector2(r.position.x + 30 * s + off, y), Vector2(r.position.x + 60 * s + off, y), Color(1, 1, 1, 0.7), 4.0, true)
			if ci % 2 == 0:
				var b := r.get_center() + Vector2(24 * s, -4 * s + sin(_t * 2.0 + sd) * 3.0)
				draw_colored_polygon(PackedVector2Array([b + Vector2(-16, 8) * s, b + Vector2(16, 8) * s, b + Vector2(10, 16) * s, b + Vector2(-10, 16) * s]), Color("c0605a"))
				draw_colored_polygon(PackedVector2Array([b + Vector2(0, -22) * s, b + Vector2(0, 6) * s, b + Vector2(14, 6) * s]), Color.WHITE)
		"palm":
			draw_circle(c + Vector2(8, 34) * s, 20 * s, shadow)
			draw_line(c + Vector2(0, 34) * s, c + Vector2(8, -14) * s, Color("a8754a"), 8.0 * s, true)
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.7
				var tip := c + Vector2(8, -14) * s + Vector2(cos(a), sin(a) + 0.5) * 36 * s
				draw_line(c + Vector2(8, -14) * s, tip, Color("3fa66a"), 9.0 * s, true)
		"umbrella":
			draw_line(c + Vector2(0, 28) * s, c + Vector2(0, -16) * s, Color("8a6b4a"), 4.0)
			var cols := [Color("ff5d5d"), Color("4d8dff"), Color("ffc53d"), Color("a26bf5"), Color("2fbf71"), Color("ff9233")]
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -10) * s, c + Vector2(0, -36) * s, c + Vector2(34, -10) * s]), cols[ci])
			DrawUtil.rrect(self, Rect2(c + Vector2(10, 18) * s, Vector2(40, 16) * s), Color("fff6e8"), 6)
		"lighthouse":
			var base := c + Vector2(0, 50 * s)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-26, 0) * s, base + Vector2(-16, -110) * s, base + Vector2(16, -110) * s, base + Vector2(26, 0) * s]), Color.WHITE)
			for k in 2:
				var yy := (-30.0 - k * 40.0)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-24 + k * 3.5, yy) * s, base + Vector2(-21 + k * 3.5, yy - 18) * s, base + Vector2(21 - k * 3.5, yy - 18) * s, base + Vector2(24 - k * 3.5, yy) * s]), Color("ff5d5d"))
			draw_rect(Rect2(base + Vector2(-14, -130) * s, Vector2(28, 20) * s), Color("ffe28a"))
			var beam := 0.5 + 0.5 * sin(_t * 2.0)
			draw_circle(base + Vector2(0, -120) * s, 34 * s, Color(1, 0.9, 0.5, 0.25 * beam))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -134) * s, base + Vector2(0, -150) * s, base + Vector2(16, -134) * s]), Color("c0605a"))
		"skyline":
			var w := 46.0 * s
			for k in 3:
				var h := (80.0 + fmod(sd * (k + 3), 70.0)) * s
				var x := c.x + (k - 1) * (w + 4)
				var r := Rect2(Vector2(x - w / 2.0, c.y + 40 * s - h), Vector2(w, h))
				draw_rect(r, Color("1d1840"))
				for ry in int(h / (20 * s)) - 1:
					for rx in 2:
						if fmod(sd * 7.0 + ry * 1.7 + rx + k, 3.0) < 1.2:
							draw_rect(Rect2(r.position + Vector2(w * (0.2 + rx * 0.4), 14 * s + ry * 20 * s), Vector2(w * 0.2, 9 * s)), Color("ffd166", 0.85))
		"cone":
			_cone(c, s)


func _cone(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 14) * s, c + Vector2(20, 14) * s, c + Vector2(0, -34) * s]), Color("ff8a1f"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -6) * s, c + Vector2(12, -6) * s, c + Vector2(7, -18) * s, c + Vector2(-7, -18) * s]), Color.WHITE)
	DrawUtil.rrect(self, Rect2(c + Vector2(-26, 10) * s, Vector2(52, 10) * s), Color("e0701a"), 4)
