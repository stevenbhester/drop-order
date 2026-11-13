class_name ExitZone
extends Node2D
## The way on to the next part of a mega route (or the next speedrun zone). The exit tile's road carries on
## past the edge of the map, and where it leaves there's a barrier: red and white, shut, until everything in
## this part is delivered. Then it swings open, the exit tile glows, and chevrons run out along the road:
## finish the route here and the van drives off to the next part. (Tap it for what it is; the first one
## gets a tip.) Origin at the exit tile's centre.

## Drawn by Board: tile size, which way the road leaves, and how far the map's green edge reaches past
## the tiles.
var tile := 100.0
var dir := Vector2i(1, 0)
var pad := 14.0
## Everything in this part's delivered: the barrier's open.
var open := false:
	set(v):
		if v != open:
			open = v
			if open and _t > 0.5:
				Sfx.play("gate", 1.1, -4.0)
				Sfx.haptic(14, 0.5)
			queue_redraw()
var _t := 0.0
## 0 shut, 1 open; it swings between them.
var _lift := 0.0

const TEAL := Color("38d9a9")
const BAR_RED := Color("ff5d5d")


func _process(delta: float) -> void:
	_t += delta
	_lift = move_toward(_lift, 1.0 if open else 0.0, delta * 3.2)
	queue_redraw()


## How far from the exit tile's centre the road runs solid (Board draws that much, with its other roads);
## past it, ExitZone fades it out.
static func solid_reach(tile_px: float, pad_px: float) -> float:
	return tile_px * 0.5 + pad_px + tile_px * 0.2


## Where the barrier stands (the map's edge), from the tile's centre: for tips that point at it.
func gate_offset() -> Vector2:
	return Vector2(dir) * (tile * 0.5 + pad)


func _draw() -> void:
	var d := Vector2(dir)
	var m := tile * 0.12
	var rw := tile - m * 2.0
	var edge := tile * 0.5 + pad
	var far := edge + tile * 0.9
	# The road on past the edge, fading out: the way to the next part.
	# (Board draws the road solid out to here, joined on with the rest; this fades it away.)
	var shadow := Vector2(0, tile * 0.045)
	var solid := solid_reach(tile, pad)
	_fade(solid, far, rw, Palette.ROAD_EDGE, shadow)
	_fade(solid, far, rw, Palette.ROAD)
	draw_dashed_line(Vector2.ZERO, d * (edge + tile * 0.45), Palette.ROAD_MARK, tile * 0.035, tile * 0.11, true, true)
	# Open: the exit tile glows (end the route here), and chevrons run out through the gate.
	if _lift > 0.0:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var r := Rect2(Vector2(-tile, -tile) * 0.5 + Vector2(m, m), Vector2(rw, rw))
		DrawUtil.rrect(self, r.grow(tile * 0.03 * pulse), Color(TEAL, 0.3 * _lift), tile * 0.22)
		draw_rect(r.grow(-tile * 0.04), Color(TEAL, 0.9 * _lift), false, tile * 0.05, true)
		var side := Vector2(-d.y, d.x)
		for k in 3:
			var u := fmod(k / 3.0 + _t * 0.55, 1.0)
			var c := d * lerpf(tile * 0.05, far - tile * 0.2, u)
			var w := tile * 0.15
			var al := sin(PI * u) * _lift
			draw_polyline(PackedVector2Array([c - d * w * 0.6 + side * w, c + d * w * 0.4, c - d * w * 0.6 - side * w]),
				Color(Color.WHITE, al), tile * 0.07, true)
	draw_gate(self, d * edge, d, rw, _lift, tile)


## Road from `a` to `b` fading to nothing, as it leaves the map.
func _fade(a: float, b: float, w: float, col: Color, off := Vector2.ZERO) -> void:
	var d := Vector2(dir)
	var side := Vector2(-d.y, d.x) * w * 0.5
	var pts := PackedVector2Array([d * a + side + off, d * b + side + off, d * b - side + off, d * a - side + off])
	draw_polygon(pts, PackedColorArray([col, Color(col, 0.0), Color(col, 0.0), col]))


## The barrier across a road `rw` wide, centred at `at`, the road leading off along `d`: two posts and a
## red and white bar from one to the other. `lift` 0 is shut; 1 has it swung right round to lie along the
## roadside, out of the way. Also drawn by the symbol card's picture.
static func draw_gate(ci: CanvasItem, at: Vector2, d: Vector2, rw: float, lift: float, tile: float) -> void:
	var side := Vector2(-d.y, d.x)
	var reach := rw * 0.5 + tile * 0.07
	var hinge := at + side * reach
	var other := at - side * reach
	# Swing from across the road (towards the other post) to along it (outwards, away from the map).
	var shut := -side
	var swung := shut.rotated(shut.angle_to(d) * smoothstep(0.0, 1.0, lift))
	var length := reach * 2.0
	var th := tile * 0.1
	var stripes := 6
	for k in stripes:
		var a := hinge + swung * length * k / stripes
		var b := hinge + swung * length * (k + 1) / stripes
		ci.draw_line(a + Vector2(0, th * 0.35), b + Vector2(0, th * 0.35), Color(0, 0, 0, 0.18), th, true)
	for k in stripes:
		var a := hinge + swung * length * k / stripes
		var b := hinge + swung * length * (k + 1) / stripes
		ci.draw_line(a, b, BAR_RED if k % 2 == 0 else Color.WHITE, th, true)
	ci.draw_circle(hinge + swung * length, th * 0.5, BAR_RED if (stripes - 1) % 2 == 0 else Color.WHITE)
	for p in [hinge, other]:
		ci.draw_circle(p + Vector2(0, tile * 0.03), tile * 0.085, Color(0, 0, 0, 0.2))
		ci.draw_circle(p, tile * 0.085, Color("3b3346"))
		ci.draw_circle(p, tile * 0.045, TEAL if lift > 0.5 else Color("ffd166"))
