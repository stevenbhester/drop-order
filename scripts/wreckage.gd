class_name Wreckage
extends Node2D
## The road the van has already driven, torn up: it drives so hard the asphalt behind it breaks into a
## gouged trench, a crater, cracks and flipped-up slabs, which is why a route can never cross itself.
## Each tile tears up with a little burst (slabs fly and land, dust, grit) as the van leaves it; with
## momentum the cracks glow in the fire's colours and the hottest runs leave it burning.
##
## Game calls set_route(tiles, upto): the first `upto` tiles of `tiles` (the route, in driving order)
## are wrecked; the rest (where the van is and the road ahead) aren't. Tiles that drop out (undo) fade.
##
## The trail's look is a cosmetic (`style`, Progress.wake): the torn-up road by default, or lava, a river,
## mountains, meteor strikes, zombies, hearts, or (beat the boss) money to burn; each tears in its own way and
## still reads as "not again".
##
## Drawn in two layers, so a long drive stays cheap: tiles that have finished tearing and cooling never
## change again, so this node draws them only when the route changes; a child layer redraws every frame
## just the tiles still tearing or fading, and the flames of a run hot enough to keep burning.

const DARK := Color("2e313b")
const DEEP := Color("1d1f26")
const SLAB := Color("6b7484")
const SLAB_TOP := Color("7d8697")
const DUST := Color("d9cdb8")
const TEAR := 0.45               # seconds a tile takes to tear up
const BURNING := 12              # on the hottest runs, how many settled tiles behind the van keep burning

var L: LevelData
var tile := 100.0
## Momentum of this run (from Progress): heat for the cracks.
var momentum := 0
## The tile that's never torn up (the depot on return levels), or (-99, -99).
var sturdy := Vector2i(-99, -99)
## Play a crunch as each tile tears (off while the level is being restored).
var loud := true
## The trail's look: "wreck" (torn-up road), "lava", "river", "mountains", "meteors", "zombies", "hearts".
var style := "wreck"

var _tiles: Array = []
var _entries: Array = []         # per wrecked route index: {p, axis, t0, seed, bridge}
var _dying: Array = []           # removed entries fading out: {e, t1}
var _t := 0.0
## The first this-many entries have settled (torn and cooled): drawn on this node, not the live layer.
var _settled_n := 0
## Where the live tail started last frame (the still layer redraws when it moves on).
var _tail_at := 0
var _live: Node2D
var _live_busy := false
## The canvas the entry drawing goes to (this node, or the live layer).
var _ci: CanvasItem


func _ready() -> void:
	_live = Node2D.new()
	_live.draw.connect(_draw_live)
	add_child(_live)


func set_route(tiles: Array, upto: int) -> void:
	_tiles = tiles.duplicate()
	upto = clampi(upto, 0, tiles.size())
	var keep := 0
	while keep < mini(upto, _entries.size()) and _entries[keep]["p"] == tiles[keep]:
		keep += 1
	for k in range(keep, _entries.size()):
		_dying.append({"e": _entries[k], "t1": _t})
	_entries.resize(keep)
	_settled_n = mini(_settled_n, keep)
	for i in range(keep, upto):
		var p: Vector2i = tiles[i]
		var d: Vector2i = (tiles[i + 1] - p) if i + 1 < tiles.size() else (p - tiles[i - 1] if i > 0 else Vector2i(1, 0))
		var e := {"p": p, "axis": 0 if d.x != 0 else 1, "t0": _t, "seed": absi(hash(p * 7 + Vector2i(i, i * 3))) % 100000,
			"bridge": L != null and L.bridges.has(p), "skip": p == sturdy}
		_entries.append(e)
		if loud and not e["skip"]:
			Sfx.play("crunch", randf_range(0.85, 1.15), -7.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_dying = _dying.filter(func(d): return _t - d["t1"] < 0.3)
	var sa := _settle_age()
	var n := _settled_n
	while n < _entries.size() and _t - float(_entries[n]["t0"]) >= sa:
		n += 1
	if n != _settled_n:
		_settled_n = n
		queue_redraw()
	if _tail_from() != _tail_at:
		_tail_at = _tail_from()
		queue_redraw()
	# The live layer: redrawn while anything moves, and once more to clear when it all settles.
	var busy := _settled_n < _entries.size() or not _dying.is_empty() or (_burns() and _settled_n > 0) or not _entries.is_empty()
	if (busy or _live_busy) and _live:
		_live.queue_redraw()
	_live_busy = busy


## How old a torn tile is when it stops changing: torn, and cooled to its lasting glow.
func _settle_age() -> float:
	if style != "wreck":
		return _tear_time()
	if momentum <= 0:
		return TEAR
	var life := 1.2 + 0.45 * mini(momentum, 10)
	return maxf(TEAR, life * (1.0 - _rest_heat()))


func _rest_heat() -> float:
	return 0.0 if momentum < 3 else (0.22 if momentum < 6 else 0.4)


## Hot enough that settled tiles keep burning (their flames flicker, so they're drawn live).
func _burns() -> bool:
	return momentum >= 3 and _rest_heat() > 0.3 and (style == "wreck" or style == "lava")


func center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * tile


## Settled tiles: still, so drawn only when that set changes. Themed looks draw their ground for every
## settled tile, then the figures (peaks, zombies, hearts) of the ones past the live tail, back to front.
func _draw() -> void:
	_ci = self
	var n := mini(_settled_n, _entries.size())
	if style == "wreck":
		for i in n:
			_draw_entry(_entries[i], i, 1.0, true)
		return
	for i in n:
		if not _entries[i]["skip"]:
			_themed_ground(_entries[i], i, 1.0, 1.0)
	var figs := []
	for i in mini(n, _tail_from()):
		if not _entries[i]["skip"]:
			figs.append(i)
	figs.sort_custom(func(x, y): return center(_entries[x]["p"]).y < center(_entries[y]["p"]).y)
	for i in figs:
		_themed_figure(_entries[i], i, 1.0, 1.0, 0.0)


## Everything that moves: tiles tearing or cooling, tiles fading out (undo), and flames on settled ones.
func _draw_live() -> void:
	_ci = _live
	for d in _dying:
		_draw_entry(d["e"], -1, 1.0 - (_t - d["t1"]) / 0.3)
	# The live tail behind the van: settled ground (on the still layer), but its figures move and its
	# effects play, calming down the further back they are.
	var settled := mini(_settled_n, _entries.size())
	var tail := []
	for i in range(_tail_from(), settled):
		if not _entries[i]["skip"]:
			tail.append(i)
	tail.sort_custom(func(x, y): return center(_entries[x]["p"]).y < center(_entries[y]["p"]).y)
	for i in tail:
		if style == "wreck":
			_themed_fx(_entries[i], i, 1.0, _life(i))
		else:
			_themed_figure(_entries[i], i, 1.0, 1.0, _life(i))
			_themed_fx(_entries[i], i, 1.0, _life(i))
	for i in range(_settled_n, _entries.size()):
		_draw_entry(_entries[i], i, 1.0)
	if _burns():
		var pal := AnimeFire.palette(momentum)
		var heat := _rest_heat()
		# The last stretch keeps burning; further back it's burnt out (so a long run costs no more).
		for i in range(maxi(0, mini(_settled_n, _entries.size()) - BURNING), mini(_settled_n, _entries.size())):
			var e: Dictionary = _entries[i]
			if not e["skip"] and not (e["bridge"] and e["axis"] == 0):
				_burn(e, heat, pal, 1.0)


## Heat of the cracks: 1 right after tearing, cooling over a few seconds (longer with momentum); hot runs
## keep a little glow for good.
func _heat(age: float) -> float:
	if momentum <= 0:
		return 0.0
	var life := 1.2 + 0.45 * mini(momentum, 10)
	var rest := 0.0 if momentum < 3 else (0.22 if momentum < 6 else 0.4)
	return maxf(rest, 1.0 - age / life)


## One torn tile. `settled`: drawn on the still layer, so without its flames (the live layer has those).
func _draw_entry(e: Dictionary, i: int, alpha: float, settled := false) -> void:
	if alpha <= 0.0:
		return
	if style != "wreck":
		_draw_themed(e, i, alpha)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = e["seed"]
	var c := center(e["p"])
	var age: float = _t - e["t0"]
	var k := clampf(age / TEAR, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var heat := _heat(age)
	var pal := AnimeFire.palette(momentum)
	var deck: bool = e["bridge"] and e["axis"] == 0   # driven under a bridge: the deck covers the middle
	# Trench halves toward the tile before and after it in the route.
	var nbrs := []
	if i > 0 and i - 1 < _tiles.size():
		nbrs.append(_tiles[i - 1])
	if i >= 0 and i + 1 < _tiles.size():
		nbrs.append(_tiles[i + 1])
	if not e["skip"]:
		for n in nbrs:
			var dir := (center(n) - c).normalized()
			var from := c + dir * (tile * 0.42 if deck else 0.0)
			_trench(from, c + dir * tile * 0.5, rng, alpha, grow, heat, pal)
	if e["skip"]:
		return
	if deck:
		return
	var squash: Vector2 = Vector2(0.62, 1.0) if e["bridge"] else Vector2.ONE
	# Crater.
	var crater := PackedVector2Array()
	var rad := tile * 0.36 * (0.35 + 0.65 * grow)
	for q in 11:
		var a := TAU * q / 11.0 + rng.randf_range(-0.15, 0.15)
		crater.append(c + Vector2(cos(a), sin(a)) * squash * rad * rng.randf_range(0.78, 1.08))
	_ci.draw_colored_polygon(crater, Color(DARK, alpha))
	var inner := PackedVector2Array()
	for q in crater:
		inner.append(c + (q - c) * 0.55)
	_ci.draw_colored_polygon(inner, Color(DEEP, alpha))
	# Cracks, growing out from the middle; glowing while hot.
	var crack_col := Color(DEEP, alpha)
	if heat > 0.0:
		crack_col = Color(pal[1].lerp(pal[2], heat * 0.6), alpha * (0.35 + 0.65 * heat))
	for q in 5:
		var a := TAU * q / 5.0 + rng.randf_range(-0.4, 0.4)
		var pts := PackedVector2Array([c])
		var p := c
		var len := tile * rng.randf_range(0.3, 0.46) * grow
		for s in 3:
			a += rng.randf_range(-0.5, 0.5)
			p += Vector2(cos(a), sin(a)) * squash * len / 3.0
			pts.append(p)
		_ci.draw_polyline(pts, crack_col, tile * (0.035 + 0.02 * heat), true)
	if heat > 0.0:
		_ci.draw_circle(c, tile * 0.13, Color(pal[2], alpha * 0.55 * heat))
		_ci.draw_circle(c, tile * 0.07, Color(pal[3], alpha * 0.6 * heat))
	# Gravel.
	for q in 8:
		var gp := c + Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.42, 0.42)) * squash * tile * grow
		_ci.draw_circle(gp, tile * rng.randf_range(0.012, 0.026), Color(DEEP if q % 2 == 0 else SLAB_TOP, alpha))
	# Slabs: flung up as it tears, then lying tilted around the crater.
	for q in 4:
		var a := TAU * (q + 0.5) / 4.0 + rng.randf_range(-0.5, 0.5)
		var rest := c + Vector2(cos(a), sin(a)) * squash * tile * rng.randf_range(0.26, 0.38)
		var fly := 4.0 * k * (1.0 - k) * tile * rng.randf_range(0.25, 0.45)
		var spin := rng.randf_range(-1.2, 1.2) + (1.0 - k) * rng.randf_range(-4.0, 4.0)
		var sz := tile * rng.randf_range(0.11, 0.17) * (1.0 + 0.4 * (1.0 - k) * float(k < 1.0))
		var at := rest + Vector2(0, -fly)
		var poly := PackedVector2Array()
		for corner in [Vector2(-1, -0.7), Vector2(1, -0.85), Vector2(0.9, 0.75), Vector2(-0.8, 0.8)]:
			poly.append(at + (corner * sz).rotated(spin))
		var shadow := PackedVector2Array()
		for v in poly:
			shadow.append(v + Vector2(0, tile * 0.03 + fly * 0.6))
		_ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.28 * alpha))
		_ci.draw_colored_polygon(poly, Color(SLAB, alpha))
		var top := PackedVector2Array([poly[0], poly[1], poly[1].lerp(poly[2], 0.4), poly[0].lerp(poly[3], 0.4)])
		_ci.draw_colored_polygon(top, Color(SLAB_TOP, alpha))
		if heat > 0.5 and momentum >= 6 and q % 2 == 0:
			AnimeFire.draw_flame(_ci, rest, tile * 0.16, tile * 0.24 * heat, _t, float(e["seed"] % 97) + q, pal, Vector2(0, -1), alpha * 0.9)
	# Tearing: dust puffs and flying grit.
	if k < 1.0:
		for q in 4:
			var a := TAU * q / 4.0 + rng.randf_range(0.0, 1.0)
			var dp := c + Vector2(cos(a), sin(a)) * tile * 0.3 * grow
			_ci.draw_circle(dp, tile * (0.08 + 0.16 * k), Color(DUST, 0.55 * (1.0 - k) * alpha))
		for q in 6:
			var a := rng.randf() * TAU
			var gp := c + Vector2(cos(a), sin(a)) * tile * (0.1 + 0.7 * k) + Vector2(0, tile * 0.5 * k * k)
			_ci.draw_circle(gp, tile * 0.025 * (1.0 - k), Color(DEEP, alpha))
	# The hottest runs keep burning a while.
	if not settled:
		_burn(e, heat, pal, alpha)


## How long a tile takes to change, per look (a meteor has to fall first).
func _tear_time() -> float:
	return {"meteors": 0.75, "mountains": 0.6, "zombies": 0.6, "hearts": 0.5, "lava": 0.5, "river": 0.5, "money": 0.55}.get(style, TEAR)


## Momentum, 0..1 (full at 8 wins running): how hard the trail hits and how lively it stays.
func _mo() -> float:
	return clampf(momentum / 8.0, 0.0, 1.0)


## How many tiles behind the van stay alive (figures moving, effects playing); further back they rest. More
## with momentum: a hot run leaves a longer stretch still bubbling, flowing, shambling or beating.
func _tail_n() -> int:
	return 5 + mini(momentum, 9)


## The first entry of the live tail.
func _tail_from() -> int:
	return maxi(0, _entries.size() - _tail_n())


## How alive entry `i` still is: 1 right behind the van, easing to 0 at the end of the tail (where its pose
## matches the still drawing, so it hands over without a jump).
func _life(i: int) -> float:
	var n := _tail_n()
	var back := _entries.size() - 1 - i
	return clampf(1.0 - float(back) / float(n), 0.0, 1.0)


func _rng(e: Dictionary, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(e["seed"]) * 31 + salt
	return r


## Directions from a tile toward the tiles before and after it on the route.
func _dirs(i: int, c: Vector2) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	if i > 0 and i - 1 < _tiles.size():
		dirs.append((center(_tiles[i - 1]) - c).normalized())
	if i >= 0 and i + 1 < _tiles.size():
		dirs.append((center(_tiles[i + 1]) - c).normalized())
	return dirs


## The way the van went through tile `i` (for things that flow along the trail).
func _flow(i: int, c: Vector2) -> Vector2:
	if i >= 0 and i + 1 < _tiles.size():
		return (center(_tiles[i + 1]) - c).normalized()
	if i > 0 and i - 1 < _tiles.size():
		return (c - center(_tiles[i - 1])).normalized()
	return Vector2.RIGHT


## A themed trail tile, whole (tearing, or fading out on an undo): ground, figures, and its burst.
func _draw_themed(e: Dictionary, i: int, alpha: float) -> void:
	if e["skip"]:
		return
	var age: float = _t - e["t0"]
	var k := clampf(age / _tear_time(), 0.0, 1.0)
	_themed_ground(e, i, alpha, k)
	_themed_figure(e, i, alpha, k, _life(i) if i >= 0 else 0.0)
	if i >= 0:
		_themed_fx(e, i, alpha * (1.0 - pow(1.0 - k, 2.0)), _life(i))
	if k < 1.0:
		_impact(e, i, alpha, k, age)


## A shape that's a little lumpy (lava pools, craters, pads), the same every time for the same rng state.
func _lumpy(c: Vector2, r: float, rng: RandomNumberGenerator, n := 12, wob := 0.12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in n:
		var a := TAU * q / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + rng.randf_range(-wob, wob)))
	return pts


## A hole cut into the road: a dark rim, the fill sitting lower (so the rim's upper wall shows as shadow),
## and a lit lip along the bottom edge.
func _pit(c: Vector2, r: float, rng: RandomNumberGenerator, rim: Color, fill: Color, lip: Color) -> void:
	if r < 1.0:
		return
	var outer := _lumpy(c, r, rng)
	_ci.draw_colored_polygon(outer, rim)
	var inner := PackedVector2Array()
	for q in outer:
		inner.append(c + (q - c) * 0.82 + Vector2(0, r * 0.1))
	_ci.draw_colored_polygon(inner, fill)
	_ci.draw_arc(c + Vector2(0, r * 0.04), r * 0.94, PI * 0.15, PI * 0.85, 12, lip, maxf(1.0, r * 0.07), true)


## A channel to the next tile: rim, fill set a little lower (shadow under the top edge), and a core.
func _channel(a: Vector2, b: Vector2, rim: Color, fill: Color, w: float) -> void:
	_ci.draw_line(a, b, rim, w, true)
	_ci.draw_line(a + Vector2(0, w * 0.1), b + Vector2(0, w * 0.1), fill, w * 0.72, true)


## Bits of broken road heaved up around whatever's come through it, each with its own little shadow.
func _chunks(c: Vector2, r: float, rng: RandomNumberGenerator, alpha: float, grow: float, n := 4, side := SLAB, top := SLAB_TOP) -> void:
	for q in n:
		var a := TAU * (q + rng.randf_range(0.1, 0.9)) / float(n)
		var at := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.95, 1.12)
		var sz := tile * rng.randf_range(0.05, 0.085) * grow
		if sz < 1.0:
			continue
		var spin := rng.randf_range(-1.0, 1.0)
		var poly := PackedVector2Array()
		for corner in [Vector2(-1, -0.7), Vector2(1, -0.85), Vector2(0.9, 0.75), Vector2(-0.8, 0.8)]:
			poly.append(at + (corner * sz).rotated(spin))
		var sh := PackedVector2Array()
		for v in poly:
			sh.append(v + Vector2(sz * 0.25, sz * 0.45))
		_ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.25 * alpha))
		_ci.draw_colored_polygon(poly, Color(side, alpha))
		_ci.draw_colored_polygon(PackedVector2Array([poly[0], poly[1], poly[1].lerp(poly[2], 0.45), poly[0].lerp(poly[3], 0.45)]), Color(top, alpha))


## The ground layer: what the road's turned into, cut into it. Still once settled.
func _themed_ground(e: Dictionary, i: int, alpha: float, k: float) -> void:
	var c := center(e["p"])
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var deck: bool = e["bridge"] and e["axis"] == 0
	var dirs := _dirs(i, c)
	var T := tile
	var mo := _mo()
	var rng := _rng(e, 1)
	match style:
		"lava":
			if not deck:
				_ci.draw_circle(c, T * 0.56 * grow, Color(1.0, 0.42, 0.08, (0.1 + 0.12 * mo) * alpha))
			for d in dirs:
				_channel(c + d * (T * 0.42 if deck else 0.0), c + d * T * 0.5, Color("2b1f1f", alpha), Color("ff6a1a", alpha), T * 0.48 * grow)
				_ci.draw_line(c + d * (T * 0.42 if deck else 0.0) + Vector2(0, T * 0.03), c + d * T * 0.5 + Vector2(0, T * 0.03), Color("ffd23f", alpha), T * (0.08 + 0.06 * mo) * grow, true)
			if not deck:
				_pit(c, T * 0.4 * grow, rng, Color("2b1f1f", alpha), Color("ff6a1a", alpha), Color(1.0, 0.8, 0.5, 0.5 * alpha))
				_ci.draw_circle(c + Vector2(0, T * 0.04), T * (0.13 + 0.06 * mo) * grow, Color("ffd23f", alpha))
				for q in 3:
					var p := c + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.16, 0.24)) * T * grow
					var crust := _lumpy(p, T * rng.randf_range(0.04, 0.075) * grow, rng, 7, 0.25)
					_ci.draw_colored_polygon(crust, Color("4a3434", alpha))
				_chunks(c, T * 0.42, rng, alpha, grow, 4, Color("3d3434"), Color("5a4a48"))
		"river":
			for d in dirs:
				var a := c + d * (T * 0.42 if deck else 0.0)
				var b := c + d * T * 0.5
				_channel(a, b, Color("cbb57f", alpha), Color("3f8fdc", alpha), T * 0.66 * grow)
				_ci.draw_line(a + Vector2(0, T * 0.04), b + Vector2(0, T * 0.04), Color("2f74bd", alpha), T * 0.16 * grow, true)
			if not deck:
				_pit(c, T * 0.34 * grow, rng, Color("cbb57f", alpha), Color("3f8fdc", alpha), Color(1, 1, 1, 0.4 * alpha))
				_ci.draw_circle(c + Vector2(0, T * 0.05), T * 0.12 * grow, Color("2f74bd", alpha))
				for q in 4:
					var a := rng.randf() * TAU
					_ci.draw_circle(c + Vector2(cos(a), sin(a)) * T * 0.36 * grow, T * rng.randf_range(0.018, 0.03) * grow, Color("a89870", alpha))
				_chunks(c, T * 0.44, rng, alpha, grow, 3)
		"mountains":
			for d in dirs:
				_channel(c + d * (T * 0.42 if deck else 0.0), c + d * T * 0.5, Color("54473a", alpha), Color("7a6a57", alpha), T * 0.4 * grow)
			if not deck:
				_pit(c, T * 0.36 * grow, rng, Color("54473a", alpha), Color("7a6a57", alpha), Color(1, 0.95, 0.85, 0.25 * alpha))
				for q in 4:
					var a := TAU * q / 4.0 + rng.randf_range(-0.4, 0.4)
					var pts := PackedVector2Array([c])
					var p := c
					for st in 3:
						a += rng.randf_range(-0.5, 0.5)
						p += Vector2(cos(a), sin(a)) * T * 0.15 * grow
						pts.append(p)
					_ci.draw_polyline(pts, Color("3a3028", alpha), T * 0.025, true)
				_chunks(c, T * 0.42, rng, alpha, grow, 5)
		"meteors":
			var fall := 0.35
			var age: float = _t - e["t0"]
			var g2 := clampf((age - fall) / 0.25, 0.0, 1.0)
			var gg := 1.0 - pow(1.0 - g2, 3.0)
			for d in dirs:
				_ci.draw_line(c + d * (T * 0.42 if deck else 0.0), c + d * T * 0.5, Color(0.1, 0.08, 0.1, 0.4 * alpha * g2), T * 0.24, true)
			if not deck and g2 > 0.0:
				# Ejecta: dark rays thrown out across the road (longer on a hot run).
				for q in 7:
					var a := TAU * q / 7.0 + rng.randf_range(-0.3, 0.3)
					var ln := T * rng.randf_range(0.36, 0.5) * (1.0 + 0.25 * mo) * gg
					_ci.draw_line(c, c + Vector2(cos(a), sin(a)) * ln, Color(0.12, 0.1, 0.12, 0.35 * alpha), T * 0.05, true)
				_pit(c, T * 0.36 * gg, rng, Color("4a4450", alpha), Color("1f1c25", alpha), Color(0.8, 0.75, 0.8, 0.5 * alpha))
				_ci.draw_circle(c + Vector2(0, T * 0.05), T * 0.17 * gg, Color(1.0, 0.45, 0.1, (0.18 + 0.2 * mo) * alpha))
				_chunks(c, T * 0.4, rng, alpha, gg, 5)
		"zombies":
			for d in dirs:
				_channel(c + d * (T * 0.42 if deck else 0.0), c + d * T * 0.5, Color("2a2c26", alpha), Color("3b3f36", alpha), T * 0.34 * grow)
			if not deck:
				_pit(c, T * 0.36 * grow, rng, Color("2a2c26", alpha), Color("3b3f36", alpha), Color(0.7, 0.8, 0.6, 0.25 * alpha))
				for q in 4:
					var a := TAU * q / 4.0 + rng.randf_range(-0.3, 0.3)
					_ci.draw_line(c, c + Vector2(cos(a), sin(a)) * T * 0.4 * grow, Color("1e201b", alpha), T * 0.03, true)
				# A cracked headstone at the back of the grave.
				var hs := c + Vector2(rng.randf_range(-0.12, 0.12) * T, -T * 0.16)
				var hw := T * 0.1 * grow
				DrawUtil.rrect(_ci, Rect2(hs + Vector2(-hw + T * 0.02, -hw * 1.4 + T * 0.02), Vector2(hw * 2.0, hw * 1.8)), Color(0, 0, 0, 0.25 * alpha), hw * 0.8)
				DrawUtil.rrect(_ci, Rect2(hs + Vector2(-hw, -hw * 1.4), Vector2(hw * 2.0, hw * 1.8)), Color("8a8f98", alpha), hw * 0.8)
				_ci.draw_line(hs + Vector2(-hw * 0.3, -hw * 0.9), hs + Vector2(hw * 0.1, -hw * 0.3), Color("5a5f68", alpha), T * 0.015, true)
				_chunks(c, T * 0.42, rng, alpha, grow, 4)
		"money":
			# Scorched road, a gold-edged channel full of loose notes, ash round the edges.
			if not deck:
				_ci.draw_circle(c, T * 0.52 * grow, Color(1.0, 0.6, 0.15, (0.08 + 0.1 * mo) * alpha))
			for d in dirs:
				_channel(c + d * (T * 0.42 if deck else 0.0), c + d * T * 0.5, Color("2a2420", alpha), Color("3f6b3a", alpha), T * 0.42 * grow)
				_ci.draw_line(c + d * (T * 0.42 if deck else 0.05) + Vector2(0, T * 0.03), c + d * T * 0.5 + Vector2(0, T * 0.03), Color(Boss.GOLD, 0.8 * alpha), T * 0.03 * grow, true)
			if not deck:
				_pit(c, T * 0.38 * grow, rng, Color("2a2420", alpha), Color("3f6b3a", alpha), Color(Boss.GOLD, 0.6 * alpha))
				for q in 4:
					var p := c + Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.14, 0.24)) * T * grow
					_bill(p, T * 0.11 * grow, rng.randf_range(-1.2, 1.2), alpha, rng.randf() < 0.5)
				_chunks(c, T * 0.42, rng, alpha, grow, 4, Color("3a3430"), Color("4e4640"))
		"hearts":
			for d in dirs:
				_channel(c + d * (T * 0.42 if deck else 0.0), c + d * T * 0.5, Color("f29bbd", alpha), Color("ffd6e6", alpha), T * 0.36 * grow)
				for q in 2:
					var p := c + d * T * (0.24 + 0.2 * q)
					if deck and q < 1:
						continue
					_heart(p + Vector2(0, T * 0.02), T * 0.055 * grow, Color("ff7aa8", alpha))
			if not deck:
				_pit(c, T * 0.38 * grow, rng, Color("f29bbd", alpha), Color("ffd6e6", alpha), Color(1, 1, 1, 0.6 * alpha))
				_chunks(c, T * 0.44, rng, alpha, grow, 3, Color("e88db0"), Color("ffc2d8"))


## The figures standing up out of the trail (peaks, zombies, the heart, the meteor). `live`: how alive it
## still is (0 = its resting pose, which is how the still layer draws it).
func _themed_figure(e: Dictionary, i: int, alpha: float, k: float, live: float) -> void:
	var deck: bool = e["bridge"] and e["axis"] == 0
	if deck:
		return
	var c := center(e["p"])
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var T := tile
	var mo := _mo()
	var ph := float(int(e["seed"]) % 628) / 100.0
	var rng := _rng(e, 2)
	match style:
		"mountains":
			# They shove up out of the ground with a little overshoot, then sit; a hot run raises them higher.
			var rise := grow
			if k < 1.0:
				rise = grow * (1.0 + 0.18 * sin(PI * clampf((k - 0.5) / 0.5, 0.0, 1.0)))
			var n := 2 + rng.randi() % 2
			var peaks := []
			for q in n:
				var base := c + Vector2(rng.randf_range(-0.17, 0.17), rng.randf_range(0.04, 0.2)) * T
				peaks.append([base, T * rng.randf_range(0.46, 0.66) * (1.0 + 0.2 * mo), T * rng.randf_range(0.18, 0.24)])
			peaks.sort_custom(func(x, y): return x[0].y < y[0].y)
			var shake := Vector2(sin(_t * 41.0 + ph), 0) * T * 0.012 * live * mo
			for pk in peaks:
				var base: Vector2 = pk[0] + shake
				var hgt: float = pk[1] * rise
				var hw: float = pk[2]
				var top := base + Vector2(0, -hgt)
				# Shadow cast down-right.
				_ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-hw * 0.6, 0), base + Vector2(hw * 1.4, T * 0.05), top + Vector2(hgt * 0.5, hgt * 0.75)]), Color(0, 0, 0, 0.22 * alpha))
				_ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-hw, 0), top, base]), Color("a3aab6", alpha))
				_ci.draw_colored_polygon(PackedVector2Array([base, top, base + Vector2(hw, 0)]), Color("676c7a", alpha))
				var sn := 0.32
				_ci.draw_colored_polygon(PackedVector2Array([top, top.lerp(base + Vector2(-hw, 0), sn), top.lerp(base, sn) + Vector2(0, -T * 0.02), top.lerp(base + Vector2(hw, 0), sn)]), Color(1, 1, 1, alpha))
				_ci.draw_colored_polygon(PackedVector2Array([top, top.lerp(base, sn) + Vector2(0, -T * 0.02), top.lerp(base + Vector2(hw, 0), sn)]), Color(0.85, 0.9, 1.0, alpha))
		"meteors":
			var fall := 0.35
			var age: float = _t - e["t0"]
			if age < fall:
				return
			var gg := 1.0 - pow(1.0 - clampf((age - fall) / 0.25, 0.0, 1.0), 3.0)
			var rp := c + Vector2(T * 0.03, T * 0.02)
			var rock := _lumpy(rp, T * 0.12 * gg, rng, 9, 0.22)
			_ci.draw_colored_polygon(rock, Color("4a3f45", alpha))
			var glow := clampf(1.0 - (age - fall) / 2.5, 0.0, 1.0) * (0.4 + 0.6 * mo) + 0.25 * live * mo * (0.6 + 0.4 * sin(_t * 5.0 + ph))
			_ci.draw_circle(rp + Vector2(T * 0.02, T * 0.02), T * 0.06 * gg, Color(1.0, 0.55, 0.15, clampf(glow, 0.0, 1.0) * alpha))
			_ci.draw_circle(rp + Vector2(-T * 0.04, -T * 0.04), T * 0.03 * gg, Color(1, 1, 1, 0.3 * alpha))
		"zombies":
			var count := 2 + (1 if momentum >= 6 else 0)
			for q in count:
				var foot := c + Vector2((q - (count - 1) / 2.0) * T * (0.36 if count == 2 else 0.27), T * 0.2 + (T * 0.04 if q == 1 and count == 3 else 0.0))
				var hh := T * 0.46 * grow * (0.9 if count == 3 else 1.0)
				var sway := sin(_t * (2.2 + 1.3 * mo) + ph + q * 2.1) * 0.16 * live
				var reach := 0.5 + 0.5 * sin(_t * (3.0 + 2.0 * mo) + ph + q)
				_ci.draw_set_transform(foot, sway, Vector2.ONE)
				# Shadow at its feet (not tilted).
				_ci.draw_set_transform(foot, 0.0, Vector2(1.0, 0.4))
				_ci.draw_circle(Vector2(T * 0.03, 0), T * 0.11 * grow, Color(0, 0, 0, 0.3 * alpha))
				_ci.draw_set_transform(foot, sway, Vector2.ONE)
				for sd in [-1.0, 1.0]:
					var hand := Vector2(sd * T * 0.05 + T * 0.16, -hh * (0.92 + 0.12 * reach * live * (1.0 if sd > 0 else -0.6)))
					_ci.draw_line(Vector2(sd * T * 0.07, -hh * 0.7), hand, Color("8fbf6a", alpha), T * 0.05, true)
				DrawUtil.rrect(_ci, Rect2(Vector2(-T * 0.09, -hh * 0.78), Vector2(T * 0.18, hh * 0.78)), Color("5a4a6b", alpha), T * 0.04)
				_ci.draw_line(Vector2(-T * 0.09, -hh * 0.2), Vector2(T * 0.09, -hh * 0.26), Color("3a2e48", alpha), T * 0.025)
				var hc := Vector2(sin(_t * 1.7 + q) * T * 0.015 * live, -hh * 0.78 - T * 0.09)
				_ci.draw_circle(hc, T * 0.12 * maxf(grow, 0.01), Color("8fbf6a", alpha))
				if grow > 0.6:
					for sd in [-1.0, 1.0]:
						_ci.draw_circle(hc + Vector2(sd * T * 0.045, -T * 0.02), T * 0.03, Color("1a1a1a", alpha))
						if mo > 0.3:
							_ci.draw_circle(hc + Vector2(sd * T * 0.045, -T * 0.02), T * 0.012, Color(0.8, 1.0, 0.4, alpha * mo))
					var jaw := T * (0.03 + 0.02 * live * absf(sin(_t * 4.0 + q)))
					_ci.draw_circle(hc + Vector2(0, T * 0.05), jaw, Color("3a1a1a", alpha))
				_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"money":
			# Stacks of banded notes, piled up out of the pit, burning; a hot run piles them higher.
			var n := 2 + (1 if momentum >= 4 else 0)
			for q in n:
				var base := c + Vector2((q - (n - 1) / 2.0) * T * 0.2, T * (0.12 - 0.05 * absf(q - (n - 1) / 2.0)))
				var layers := int((3 + rng.randi() % 3) * (1.0 + 0.4 * mo) * grow)
				var bw := T * 0.17
				var bh := T * 0.045
				DrawUtil.rrect(_ci, Rect2(base + Vector2(-bw / 2.0 + T * 0.03, -bh * layers + T * 0.03), Vector2(bw, bh * layers)), Color(0, 0, 0, 0.25 * alpha), T * 0.015)
				for l in layers:
					var y := base.y - bh * (l + 1)
					var sx := sin(l * 1.7 + q) * T * 0.008
					DrawUtil.rrect(_ci, Rect2(Vector2(base.x - bw / 2.0 + sx, y), Vector2(bw, bh * 0.92)), Color("6fbf73" if l % 2 == 0 else "5aa85f", alpha), T * 0.01)
					_ci.draw_rect(Rect2(Vector2(base.x - bw * 0.12 + sx, y), Vector2(bw * 0.24, bh * 0.92)), Color(Boss.GOLD, 0.9 * alpha))
				var top := Vector2(base.x, base.y - bh * layers)
				var flicker := 1.0 + 0.15 * sin(_t * 9.0 + q * 2.0) * live
				AnimeFire.draw_flame(_ci, top + Vector2(0, T * 0.01), T * 0.14, T * (0.12 + 0.1 * mo) * flicker * grow, _t if live > 0.0 else 0.0, ph * 10.0 + q, AnimeFire.palette(mini(momentum, 4)), Vector2(0, -1), alpha * (0.6 + 0.4 * live))
		"hearts":
			var rate := 1.1 + 0.9 * mo
			var u := fmod(_t * rate + ph, 1.0)
			var beat := maxf(exp(-pow((u - 0.08) / 0.05, 2.0)), 0.7 * exp(-pow((u - 0.26) / 0.05, 2.0))) * live
			var pop := 1.0 + 0.25 * sin(PI * k) if k < 1.0 else 1.0
			var sc := grow * pop * (1.0 + 0.16 * beat)
			_heart(c + Vector2(T * 0.04, T * 0.07), T * 0.26 * sc, Color(0.5, 0.0, 0.2, 0.25 * alpha))
			_heart(c, T * 0.26 * sc, Color("c2185b", alpha))
			_heart(c + Vector2(0, -T * 0.015 * sc), T * 0.22 * sc, Color("ff4d8d", alpha))
			_ci.draw_circle(c + Vector2(-T * 0.08, -T * 0.07) * sc, T * 0.045 * sc, Color(1, 1, 1, 0.65 * alpha))


## What keeps moving on the live tail: bubbles, current, dust, smoke, fog, floating hearts. Fades with
## `live`; busier and quicker on a hot run.
func _themed_fx(e: Dictionary, i: int, alpha: float, live: float) -> void:
	if live <= 0.0 or alpha <= 0.0:
		return
	var deck: bool = e["bridge"] and e["axis"] == 0
	var c := center(e["p"])
	var T := tile
	var mo := _mo()
	var ph := float(int(e["seed"]) % 628) / 100.0
	var rng := _rng(e, 3)
	var a := alpha * live
	match style:
		"lava":
			var flow := _flow(i, c)
			# Bright streaks riding the current, the way the van went.
			for q in 2:
				var u := fmod(_t * (0.5 + 0.6 * mo) + q * 0.5 + ph, 1.0)
				var p := c + flow * T * (u - 0.5)
				_ci.draw_line(p - flow * T * 0.08, p + flow * T * 0.08, Color(1.0, 0.95, 0.6, 0.7 * a * sin(PI * u)), T * 0.05, true)
			if deck:
				return
			# Bubbles: swell, pop into a ring.
			for q in 2 + int(mo * 2.0):
				var cyc := 1.4 - 0.5 * mo
				var u := fmod(_t / cyc + rng.randf(), 1.0)
				var bp := c + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.14, 0.22)) * T
				if u < 0.75:
					var r := T * 0.055 * (u / 0.75)
					_ci.draw_circle(bp, r, Color("ffb13b", a))
					_ci.draw_circle(bp + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 0.8, 0.8 * a))
				else:
					var w := (u - 0.75) / 0.25
					_ci.draw_arc(bp, T * (0.05 + 0.08 * w), 0, TAU, 12, Color(1.0, 0.8, 0.3, (1.0 - w) * a), T * 0.015, true)
			# Embers lifting off.
			for q in 2 + int(mo * 3.0):
				var u := fmod(_t * (0.6 + 0.4 * mo) + rng.randf(), 1.0)
				var p := c + Vector2(rng.randf_range(-0.25, 0.25) * T + sin(_t * 3.0 + q) * T * 0.04, -u * T * (0.5 + 0.3 * mo))
				_ci.draw_circle(p, T * 0.018 * (1.0 - u), Color(1.0, 0.6 + 0.3 * (1.0 - u), 0.2, (1.0 - u) * a))
			_ci.draw_circle(c + Vector2(0, T * 0.04), T * 0.2, Color(1.0, 0.85, 0.3, 0.18 * a * (0.5 + 0.5 * sin(_t * 3.0 + ph))))
			if momentum >= 5:
				AnimeFire.draw_flame(_ci, c + Vector2(0, T * 0.08), T * 0.18, T * (0.18 + 0.12 * mo), _t, ph * 10.0, AnimeFire.palette(momentum), Vector2(0, -1), a * 0.8)
		"river":
			var flow := _flow(i, c)
			var side := flow.orthogonal()
			# The current: little ripples carried along, quicker with momentum; white water on a hot run.
			for q in 3:
				var u := fmod(_t * (0.45 + 0.7 * mo) + q / 3.0 + ph, 1.0)
				var lane := (q - 1) * 0.12
				var p := c + flow * T * (u - 0.5) + side * T * lane + Vector2(0, T * 0.03)
				var bend := side * T * 0.04
				_ci.draw_polyline(PackedVector2Array([p - flow * T * 0.06 + bend, p, p - flow * T * 0.06 - bend]), Color(1, 1, 1, 0.55 * a * sin(PI * u)), T * 0.02, true)
			if mo > 0.35:
				for q in 3:
					var u := fmod(_t * 1.6 + rng.randf(), 1.0)
					var p := c + flow * T * (rng.randf() - 0.5) + side * T * 0.22 * (1.0 if q % 2 == 0 else -1.0)
					_ci.draw_circle(p, T * 0.03 * (1.0 - u) * mo, Color(1, 1, 1, 0.8 * a))
			if deck:
				return
			# Glints twinkling on the pool.
			for q in 2:
				var tw := maxf(0.0, sin(_t * 2.3 + q * 2.0 + ph))
				var gp := c + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.18)) * T
				_star(gp, T * 0.035 * tw, Color(1, 1, 1, 0.85 * a * tw))
			# The lily pad bobs.
			if int(e["seed"]) % 3 == 0:
				var lp := c + Vector2(T * 0.08, T * 0.12) + Vector2(0, sin(_t * 1.6 + ph) * T * 0.012)
				_ci.draw_circle(lp + Vector2(0, T * 0.01), T * 0.065, Color(0, 0, 0, 0.18 * a))
				_ci.draw_circle(lp, T * 0.06, Color("5fae5b", a))
				_ci.draw_line(lp, lp + Vector2(T * 0.06, 0).rotated(0.3), Color("3f8fdc", a), T * 0.015)
		"mountains":
			if deck:
				return
			# Dust blowing off the peaks; on a hot run, the odd rock tumbling down a slope.
			for q in 2 + int(mo * 2.0):
				var u := fmod(_t * 0.35 + rng.randf(), 1.0)
				var p := c + Vector2(rng.randf_range(-0.2, 0.1) * T + u * T * 0.4, -T * rng.randf_range(0.25, 0.5) - u * T * 0.1)
				_ci.draw_circle(p, T * (0.04 + 0.08 * u), Color(0.9, 0.86, 0.78, 0.35 * (1.0 - u) * a))
			if mo > 0.3:
				var u := fmod(_t * 0.8 + ph, 1.0)
				var from := c + Vector2(-T * 0.05, -T * 0.4)
				var p := from + Vector2(T * 0.25 * u, T * 0.5 * u * u)
				_ci.draw_circle(p, T * 0.025, Color("5a5048", a * (1.0 - u)))
		"meteors":
			# Smoke rolling up out of the crater, leaning with the wind; embers on a hot run.
			if deck:
				return
			for q in 3 + int(mo * 2.0):
				var u := fmod(_t * 0.4 + q / 4.0 + ph, 1.0)
				var p := c + Vector2(u * T * 0.25 + sin(_t + q) * T * 0.03, -u * T * (0.7 + 0.3 * mo))
				var grey := 0.25 + 0.3 * u
				_ci.draw_circle(p, T * (0.06 + 0.14 * u), Color(grey, grey, grey + 0.03, 0.4 * (1.0 - u) * a))
			for q in int(mo * 4.0):
				var u := fmod(_t * 0.9 + rng.randf(), 1.0)
				var p := c + Vector2(rng.randf_range(-0.15, 0.15) * T, -u * T * 0.45)
				_ci.draw_circle(p, T * 0.015 * (1.0 - u), Color(1.0, 0.65, 0.2, (1.0 - u) * a))
			if momentum >= 3:
				AnimeFire.draw_flame(_ci, c + Vector2(0, T * 0.06), T * 0.15, T * (0.12 + 0.14 * mo), _t, ph * 10.0, AnimeFire.palette(momentum), Vector2(0, -1), a * 0.75)
		"zombies":
			# Low green fog curling round the grave.
			for q in 2 + int(mo * 2.0):
				var u := fmod(_t * 0.25 + q / 3.0 + ph, 1.0)
				var p := c + Vector2((u - 0.5) * T * 0.8, T * 0.2 + sin(_t * 1.3 + q) * T * 0.04)
				_ci.draw_circle(p, T * (0.1 + 0.05 * sin(PI * u)), Color(0.6, 0.85, 0.5, 0.16 * sin(PI * u) * a))
		"hearts":
			if deck:
				return
			# Little hearts floating up, and sparkles on a hot run.
			for q in 1 + int(mo * 3.0):
				var u := fmod(_t * (0.4 + 0.3 * mo) + rng.randf(), 1.0)
				var p := c + Vector2(rng.randf_range(-0.25, 0.25) * T + sin(_t * 2.0 + q) * T * 0.05, -T * 0.1 - u * T * 0.6)
				_heart(p, T * 0.05 * (1.0 - 0.5 * u), Color(1.0, 0.45, 0.65, (1.0 - u) * a))
			if mo > 0.3:
				for q in 2:
					var tw := maxf(0.0, sin(_t * 3.1 + q * 2.4 + ph))
					var sp := c + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.2)) * T
					_star(sp, T * 0.05 * tw, Color(1, 1, 1, a * tw))
			var rate := 1.1 + 0.9 * mo
			var u := fmod(_t * rate + ph, 1.0)
			if u < 0.4:
				_ci.draw_arc(c, T * (0.28 + 0.3 * u), 0, TAU, 20, Color(1.0, 0.4, 0.6, 0.45 * (1.0 - u / 0.4) * a), T * 0.02, true)
		"money":
			if deck:
				return
			# Burning notes fluttering up and away, and smoke; more of them on a hot run.
			for q in 2 + int(mo * 3.0):
				var u := fmod(_t * (0.35 + 0.3 * mo) + rng.randf(), 1.0)
				var p := c + Vector2(rng.randf_range(-0.25, 0.25) * T + sin(_t * 2.5 + q) * T * 0.08 * u, -T * 0.15 - u * T * 0.7)
				_bill(p, T * 0.08 * (1.0 - 0.4 * u), sin(_t * 4.0 + q) * 1.2, a * (1.0 - u), true)
			for q in 2:
				var u := fmod(_t * 0.4 + q * 0.5 + ph, 1.0)
				var p := c + Vector2(u * T * 0.2, -T * 0.3 - u * T * 0.6)
				_ci.draw_circle(p, T * (0.06 + 0.12 * u), Color(0.3, 0.3, 0.3, 0.3 * (1.0 - u) * a))
		"wreck":
			# Dust and smoke still drifting off the torn road; it glows if the run's hot.
			if deck:
				return
			for q in 2 + int(mo * 2.0):
				var u := fmod(_t * 0.35 + q / 3.0 + ph, 1.0)
				var p := c + Vector2(u * T * 0.15 + sin(_t * 1.4 + q) * T * 0.04, -u * T * 0.5)
				var col := DUST.lerp(Color(0.35, 0.35, 0.38), mo)
				_ci.draw_circle(p, T * (0.05 + 0.1 * u), Color(col, 0.3 * (1.0 - u) * a))


## The moment a tile turns: something hits the road, scaled up by momentum.
func _impact(e: Dictionary, i: int, alpha: float, k: float, age: float) -> void:
	var c := center(e["p"])
	var T := tile
	var mo := _mo()
	var pw := 1.0 + 0.7 * mo
	var rng := _rng(e, 4)
	var start := 0.35 / _tear_time() if style == "meteors" else 0.0
	if k < start:
		# A meteor's still falling: its own drawing in _themed_ground/_impact below.
		var u := age / 0.35
		var from := c + Vector2(T * 0.9, -T * 1.4) * (1.0 + 0.3 * mo)
		var at := from.lerp(c, u)
		_ci.draw_line(from.lerp(c, maxf(u - 0.35, 0.0)), at, Color(1.0, 0.6, 0.2, 0.8 * alpha), T * 0.12 * pw, true)
		_ci.draw_line(from.lerp(c, maxf(u - 0.2, 0.0)), at, Color(1.0, 0.95, 0.7, 0.9 * alpha), T * 0.05 * pw, true)
		_ci.draw_circle(at, T * 0.1 * pw, Color("ffd23f", alpha))
		_ci.draw_circle(at, T * 0.05 * pw, Color.WHITE)
		return
	var w := clampf((k - start) / (1.0 - start), 0.0, 1.0)
	var palette: Array = {
		"lava": [Color("ff6a1a"), Color("ffd23f")], "river": [Color("8fc7ff"), Color.WHITE],
		"mountains": [Color("d9cdb8"), Color("7a6a57")], "meteors": [Color("ffb04a"), Color(0.25, 0.22, 0.26)],
		"zombies": [Color("4a4d3e"), Color("7a7f6a")], "hearts": [Color("ff4d8d"), Color("ffd6e6")],
		"money": [Color("6fbf73"), Boss.GOLD],
	}.get(style, [DUST, DEEP])
	# The shock ring.
	_ci.draw_arc(c, T * (0.2 + 0.55 * w) * pw, 0, TAU, 28, Color(palette[0], 0.6 * (1.0 - w) * alpha), T * 0.05 * (1.0 - w) + 1.0, true)
	if style == "meteors" and w < 0.3:
		_ci.draw_circle(c, T * 0.55 * pw, Color(1, 0.95, 0.8, 0.75 * (1.0 - w / 0.3) * alpha))
	if style == "mountains":
		# Dust rolling out round the foot of the new peaks.
		for q in 6:
			var a := TAU * q / 6.0 + rng.randf_range(-0.3, 0.3)
			var p := c + Vector2(cos(a), sin(a) * 0.6) * T * (0.2 + 0.4 * w) * pw + Vector2(0, T * 0.15)
			_ci.draw_circle(p, T * (0.08 + 0.1 * w), Color(DUST, 0.5 * (1.0 - w) * alpha))
	# Debris thrown up in arcs and landing: droplets, rocks, clods, confetti hearts.
	var n := 5 + int(mo * 6.0)
	for q in n:
		var a := rng.randf() * TAU
		var dist := T * rng.randf_range(0.25, 0.55) * pw
		var hgt := T * rng.randf_range(0.2, 0.45) * pw
		var p := c + Vector2(cos(a), sin(a) * 0.7) * dist * w + Vector2(0, -4.0 * hgt * w * (1.0 - w))
		var col: Color = palette[q % 2]
		var sz := T * rng.randf_range(0.025, 0.045) * (1.0 - 0.6 * w) * (1.0 + 0.3 * mo)
		if style == "hearts":
			_heart(p, sz * 1.3, Color(col, alpha * (1.0 - w * 0.5)))
		elif style == "money" and q % 2 == 0:
			_bill(p, sz * 2.4, rng.randf() * TAU + w * 6.0, alpha * (1.0 - w * 0.5), false)
		else:
			_ci.draw_circle(p, sz, Color(col, alpha * (1.0 - w * 0.5)))


## A banknote, `w` wide, turned by `rot`; `burning` singes one end.
func _bill(c: Vector2, w: float, rot: float, alpha: float, burning: bool) -> void:
	if w < 1.5 or alpha <= 0.0:
		return
	var h := w * 0.5
	var corners := [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]
	var pts := PackedVector2Array()
	for v in corners:
		pts.append(c + (v * 0.5).rotated(rot))
	_ci.draw_colored_polygon(pts, Color("7cc47f", alpha))
	_ci.draw_circle(c, h * 0.28, Color("3f7d43", alpha))
	if burning:
		var edge := PackedVector2Array([pts[1], pts[2], pts[2].lerp(pts[3], 0.3), pts[1].lerp(pts[0], 0.3)])
		_ci.draw_colored_polygon(edge, Color(0.15, 0.1, 0.08, alpha))
		_ci.draw_line(pts[1].lerp(pts[0], 0.3), pts[2].lerp(pts[3], 0.3), Color(1.0, 0.6, 0.15, alpha), maxf(1.0, w * 0.06), true)


## A four-point twinkle.
func _star(c: Vector2, r: float, col: Color) -> void:
	if r < 0.5:
		return
	_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0), c + Vector2(r * 0.25, r * 0.25),
		c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), col)


## An irregular round blob (a lava pool, a crater, a crust island).
func _blob(c: Vector2, r: float, rng: RandomNumberGenerator, col: Color) -> void:
	if r <= 0.5:
		return
	_ci.draw_colored_polygon(_lumpy(c, r, rng, 10, 0.13), col)


func _heart(c: Vector2, s: float, col: Color) -> void:
	if s <= 0.5:
		return
	_ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.2), s * 0.56, col)
	_ci.draw_circle(c + Vector2(s * 0.5, -s * 0.2), s * 0.56, col)
	_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, 0.0), c + Vector2(s * 1.02, 0.0), c + Vector2(0, s * 1.2)]), col)


## A torn tile's fire, if it's hot enough to burn.
func _burn(e: Dictionary, heat: float, pal: Array, alpha: float) -> void:
	if momentum >= 3 and heat > 0.3:
		var c := center(e["p"])
		AnimeFire.draw_flame(_ci, c + Vector2(0, tile * 0.08), tile * 0.22, tile * (0.18 + 0.2 * heat) * (1.0 + 0.06 * mini(momentum, 10)),
			_t, float(e["seed"] % 53), pal, Vector2(0, -1), alpha * minf(1.0, heat * 1.4))


## A jagged gouge from `a` to `b`.
func _trench(a: Vector2, b: Vector2, rng: RandomNumberGenerator, alpha: float, grow: float, heat: float, pal: Array) -> void:
	var dir := b - a
	var side := Vector2(-dir.y, dir.x).normalized()
	var pts := PackedVector2Array()
	for s in 4:
		var u := s / 3.0
		pts.append(a + dir * u * grow + side * tile * rng.randf_range(-0.045, 0.045))
	_ci.draw_polyline(pts, Color(DARK, alpha), tile * 0.4 * (0.5 + 0.5 * grow), true)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p + side * tile * rng.randf_range(-0.03, 0.03))
	var col := Color(DEEP, alpha)
	if heat > 0.0:
		col = Color(DEEP.lerp(pal[0], heat * 0.7), alpha)
	_ci.draw_polyline(inner, col, tile * 0.13, true)
