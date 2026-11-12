class_name CrashMark
extends Node2D
## A pulsing red X where the route being drawn runs into the road already torn up (or into itself):
## the line stops here.

var tile := 100.0
var _t := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := tile * (0.2 + 0.02 * sin(_t * 12.0))
	draw_circle(Vector2(0, tile * 0.02), r * 1.22, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, r * 1.2, Color.WHITE)
	draw_circle(Vector2.ZERO, r, Palette.CRASH)
	for sx in [-1.0, 1.0]:
		var a := Vector2(-sx, -1) * r * 0.42
		var b := Vector2(sx, 1) * r * 0.42
		draw_line(a, b, Color.WHITE, r * 0.3, true)
		draw_circle(a, r * 0.15, Color.WHITE)
		draw_circle(b, r * 0.15, Color.WHITE)
