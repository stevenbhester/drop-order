class_name DepotGlow
extends Node2D
## The start: a little pit stop on the van's first tile. A checkered start line across the road, stacked
## tyres in two corners and a pit-board flag. On return levels it's also the finish: once everything's
## delivered it pulses gold to call the van home.

var tile := 180.0
## A return level: the pit stop is where the shift ends.
var returning := false
var calling := false:
	set(v):
		calling = v
		queue_redraw()
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var t := tile
	var rw := t * 0.76
	# The pit box: a painted bay under the van.
	DrawUtil.rrect(self, Rect2(-Vector2(rw, rw) / 2.0, Vector2(rw, rw)), Color(Palette.DEPOT, 0.18), t * 0.14)
	# Checkered start line across the middle.
	var n := 8
	var cell := rw / n
	for i in n:
		for j in 2:
			var col := Color("1d1f26") if (i + j) % 2 == 0 else Color(1, 1, 1, 0.92)
			draw_rect(Rect2(Vector2(-rw / 2.0 + i * cell, -cell + j * cell), Vector2(cell, cell)), col)
	# Stacked tyres in two corners.
	for corner in [Vector2(-0.43, 0.41), Vector2(0.43, -0.41)]:
		var c: Vector2 = corner * t
		for k in 2:
			var cc := c + Vector2(0, -k * t * 0.045)
			draw_circle(cc + Vector2(0, t * 0.02), t * 0.075, Color(0, 0, 0, 0.18))
			draw_circle(cc, t * 0.075, Color("23262e"))
			draw_circle(cc, t * 0.033, Color("8b93a6"))
	# The pit board: a little checkered flag in the top-left corner.
	Icons.finish_flag(self, Vector2(-0.38, -0.3) * t, t * 0.42, _t)
	if returning:
		var r := t * 0.42
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(Palette.DEPOT, 0.85), t * 0.035, true)
	if calling:
		for k0 in [0.0, 0.5]:
			var k := fmod(_t / 1.1 + k0, 1.0)
			draw_arc(Vector2.ZERO, t * 0.4 * (1.0 + 0.6 * k), 0, TAU, 48, Color(Palette.DEPOT, 0.9 * (1.0 - k)), t * 0.05, true)
