class_name GhostFinger
extends Node2D
## Tutorial: a translucent fingertip that traces a route on loop.

const SPEED := 3.6   # tiles per second

var pts: Array = []  # Vector2, board-local
var radius := 44.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var n := pts.size()
	if n < 2:
		return
	var travel := (n - 1) / SPEED
	var cycle := 0.45 + travel + 0.45 + 0.7
	var t := fmod(_t, cycle)
	var alpha := 1.0
	var press := 1.0
	var v := 0.0
	if t < 0.45:
		alpha = t / 0.45
		press = 1.0 + (1.0 - alpha) * 0.4
	elif t < 0.45 + travel:
		v = (t - 0.45) * SPEED
	elif t < 0.9 + travel:
		v = n - 1
		alpha = 1.0 - (t - 0.45 - travel) / 0.45
	else:
		return
	var i := mini(int(floor(v)), n - 1)
	var pos: Vector2 = pts[i] if i >= n - 1 else pts[i].lerp(pts[i + 1], v - i)
	var trail := PackedVector2Array()
	for k in i + 1:
		trail.append(pts[k])
	trail.append(pos)
	var tc := Color(1, 1, 1, 0.4 * alpha)
	draw_polyline(trail, tc, radius * 0.8, true)
	for p in trail:
		draw_circle(p, radius * 0.4, tc)
	draw_circle(pos + Vector2(5, 10), radius * press, Color(0, 0, 0, 0.15 * alpha))
	draw_circle(pos, radius * press, Color(1, 1, 1, 0.9 * alpha))
	draw_arc(pos, radius * press, 0, TAU, 40, Color(Palette.TEXT, 0.35 * alpha), 4.0, true)
