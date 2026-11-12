class_name AnimeFire
extends Node2D
## Cel-shaded "anime" fire: hard-edged flame tongues in three or four flat layers, flickering and licking
## upward, with embers. Hotter with momentum: orange, then red-gold, then blue, then violet "supernova".
##
## As a node it's the momentum trail: emit() drops flames where the van drives, and they burn down.
## The static helpers draw single flames and whole auras for anything else (the level finish).

## [outer, middle, core, hot centre] per heat tier.
const TIERS := [
	[Color("ff8a1f"), Color("ffc23d"), Color("fff1a8"), Color("ffffff")],
	[Color("ff3b2f"), Color("ff9a1f"), Color("ffe14d"), Color("fffbe0")],
	[Color("1f6bff"), Color("35c6ff"), Color("b8f3ff"), Color("ffffff")],
	[Color("8a2bff"), Color("ff4fd8"), Color("ffc2f5"), Color("ffffff")],
]
const TIER_NAMES := ["", "Warming up", "On a roll", "Heating up", "On fire!", "Blazing!", "Blue flame!", "Unstoppable!", "SUPERNOVA"]

## Momentum this trail burns at (0: no flames).
var momentum := 0
var tile := 100.0

var _flames: Array = []
var _embers: Array = []
var _t := 0.0
var _since := 0.0


static func tier(m: int) -> int:
	if m >= 8:
		return 3
	if m >= 6:
		return 2
	if m >= 3:
		return 1
	return 0


static func palette(m: int) -> Array:
	return TIERS[tier(m)]


static func title(m: int) -> String:
	return TIER_NAMES[clampi(m, 0, TIER_NAMES.size() - 1)]


## One flame standing on `base`, `w` wide and `h` tall, pointing along `up` (a unit vector; screen-up is
## Vector2(0, -1)). `t` animates it, `seed` makes each one different. Layers are drawn outside-in.
static func draw_flame(ci: CanvasItem, base: Vector2, w: float, h: float, t: float, seed: float, pal: Array, up := Vector2(0, -1), alpha := 1.0) -> void:
	if w < 2.0 or h < 3.0:
		return
	var layers := [[1.0, 1.0], [0.74, 0.8], [0.48, 0.58], [0.24, 0.34]]
	for li in pal.size():
		var k: float = layers[li][0]
		var kh: float = layers[li][1]
		var pts := _tongue(base + up * h * (1.0 - kh) * 0.08, w * k, h * kh, t, seed + li * 0.37, up, li == 0)
		if pts.size() >= 3:
			ci.draw_colored_polygon(pts, Color(pal[li], alpha))


## The outline of one tongue: a rounded base, wobbling sides that narrow to a pointed, leaning tip, and
## (outer layer only) two sharp side licks.
static func _tongue(base: Vector2, w: float, h: float, t: float, seed: float, up: Vector2, licks: bool) -> PackedVector2Array:
	var side := Vector2(-up.y, up.x)
	var lean := sin(t * 7.0 + seed * 11.0) * 0.22 + sin(t * 13.0 + seed * 5.0) * 0.08
	var stretch := 1.0 + 0.12 * sin(t * 10.0 + seed * 3.0)
	var n := 9
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var half0 := w * 0.4
	for i in n:
		var u := float(i) / n
		var half := w * 0.5 * pow(1.0 - u, 0.85) * (0.8 + 0.35 * sin(PI * u * 0.9))
		var sway := (lean * u * u + 0.06 * sin(t * 16.0 + u * 7.0 + seed * 9.0) * u) * h
		var along := base + up * (u * h * stretch) + side * sway
		left.append(along - side * half)
		right.append(along + side * half)
	if licks:
		for spec in [[3, -1.0, 0.0], [5, 1.0, 1.7]]:
			var i: int = spec[0]
			var dir: float = spec[1]
			var flick := 0.7 + 0.3 * sin(t * 9.0 + seed * 4.0 + spec[2])
			var at: Vector2 = left[i].lerp(left[i + 1], 0.5) if dir < 0.0 else right[i].lerp(right[i + 1], 0.5)
			var tip := at + (side * dir * w * 0.3 + up * h * 0.14) * flick
			if dir < 0.0:
				left.insert(i + 1, tip)
			else:
				right.insert(i + 1, tip)
	var tip_pt := base + up * h * stretch * 1.04 + side * lean * h * 1.05
	var pts := PackedVector2Array()
	for k in 7:
		var a := PI * (1.0 - k / 6.0)
		pts.append(base - up * half0 * 0.5 * sin(a) + side * half0 * cos(a))
	for i in range(1, right.size()):
		pts.append(right[i])
	pts.append(tip_pt)
	for i in range(left.size() - 1, 0, -1):
		pts.append(left[i])
	# A wild flicker can fold the outline over itself; fall back to its hull rather than draw nothing.
	if Geometry2D.triangulate_polygon(pts).is_empty():
		pts = Geometry2D.convex_hull(pts)
	return pts


## A ring of big flames around `c` (a w-by-h box), licking upward: the momentum aura.
static func draw_aura(ci: CanvasItem, c: Vector2, size: Vector2, t: float, m: int, behind: bool) -> void:
	if m <= 0:
		return
	var pal := palette(m)
	var count := 5 + mini(m, 8) * 2
	var height := size.y * (0.7 + 0.18 * mini(m, 8))
	for i in count:
		var u := (i + 0.5) / count
		var x := c.x - size.x * 0.62 + size.x * 1.24 * u
		var edge := 1.0 - pow(absf(u - 0.5) * 2.0, 2.0)
		var hh := height * (0.45 + 0.55 * edge) * (0.85 + 0.15 * sin(t * 5.0 + i * 1.7))
		var ww := size.x * 1.4 / count * 2.2
		var y := c.y + size.y * 0.42 - (0.0 if behind else size.y * 0.05)
		if behind or i % 3 == 1:
			var s := 1.0 if behind else 0.55
			draw_flame(ci, Vector2(x, y), ww * s, hh * s, t, i * 1.31 + (0.0 if behind else 7.0), pal)


func emit(at: Vector2) -> void:
	if momentum <= 0:
		return
	var m := mini(momentum, 10)
	_flames.append({"p": at + Vector2(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12)) * tile, "t": 0.0,
		"life": 0.35 + 0.16 * m, "w": tile * (0.26 + 0.05 * m), "h": tile * (0.36 + 0.09 * m), "seed": randf() * 10.0})
	if randf() < 0.25 + 0.06 * m:
		_embers.append({"p": at, "v": Vector2(randf_range(-60.0, 60.0), -randf_range(120.0, 260.0)) * tile / 100.0, "t": 0.0, "life": randf_range(0.5, 1.0)})


func _process(delta: float) -> void:
	_t += delta
	if _flames.is_empty() and _embers.is_empty():
		return
	for f in _flames:
		f["t"] += delta
	for e in _embers:
		e["t"] += delta
		e["p"] += e["v"] * delta
	_flames = _flames.filter(func(f): return f["t"] < f["life"])
	_embers = _embers.filter(func(e): return e["t"] < e["life"])
	queue_redraw()


func _draw() -> void:
	var pal := palette(momentum)
	for f in _flames:
		var k: float = f["t"] / f["life"]
		var grow := minf(k * 6.0, 1.0)
		var fade := 1.0 - k
		draw_flame(self, f["p"], f["w"] * grow * (0.4 + 0.6 * fade), f["h"] * grow * fade, _t, f["seed"], pal, Vector2(0, -1), 0.95)
	for e in _embers:
		var k: float = e["t"] / e["life"]
		draw_circle(e["p"], tile * 0.035 * (1.0 - k), Color(pal[2], 1.0 - k))
