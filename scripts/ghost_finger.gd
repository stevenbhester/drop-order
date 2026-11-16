class_name GhostFinger
extends Node2D
## Tutorial: a hand that comes down on the van and drags the route out along the road, on a loop.

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
	# Where it's pressing, then the hand itself, its fingertip on the spot.
	draw_circle(pos, radius * 0.7 * press, Color(1, 1, 1, 0.35 * alpha))
	DrawUtil.hand(self, pos, radius * 2.6 * (0.92 if press <= 1.0 else press), alpha)
