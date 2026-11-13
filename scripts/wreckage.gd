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

var _tiles: Array = []
var _entries: Array = []         # per wrecked route index: {p, axis, t0, seed, bridge}
var _dying: Array = []           # removed entries fading out: {e, t1}
var _t := 0.0
## The first this-many entries have settled (torn and cooled): drawn on this node, not the live layer.
var _settled_n := 0
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
	# The live layer: redrawn while anything moves, and once more to clear when it all settles.
	var busy := _settled_n < _entries.size() or not _dying.is_empty() or (_burns() and _settled_n > 0)
	if (busy or _live_busy) and _live:
		_live.queue_redraw()
	_live_busy = busy


## How old a torn tile is when it stops changing: torn, and cooled to its lasting glow.
func _settle_age() -> float:
	if momentum <= 0:
		return TEAR
	var life := 1.2 + 0.45 * mini(momentum, 10)
	return maxf(TEAR, life * (1.0 - _rest_heat()))


func _rest_heat() -> float:
	return 0.0 if momentum < 3 else (0.22 if momentum < 6 else 0.4)


## Hot enough that settled tiles keep burning (their flames flicker, so they're drawn live).
func _burns() -> bool:
	return momentum >= 3 and _rest_heat() > 0.3


func center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * tile


## Settled tiles: still, so drawn only when that set changes.
func _draw() -> void:
	_ci = self
	for i in mini(_settled_n, _entries.size()):
		_draw_entry(_entries[i], i, 1.0, true)


## Everything that moves: tiles tearing or cooling, tiles fading out (undo), and flames on settled ones.
func _draw_live() -> void:
	_ci = _live
	for d in _dying:
		_draw_entry(d["e"], -1, 1.0 - (_t - d["t1"]) / 0.3)
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
