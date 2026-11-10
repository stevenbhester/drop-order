class_name Hub
extends Node2D
## Sorting hub: a turntable that swaps the van's top two packages. Spins when used.

var tile := 180.0
var _tw: Tween


func spin(direction := 1.0) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "rotation", rotation + PI * direction, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var r := tile * 0.36
	draw_circle(Vector2(0, tile * 0.03), r * 1.04, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, r, Palette.HUB)
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Palette.HUB.lightened(0.25), tile * 0.03, true)
	# Two curved arrows chasing each other = "swap".
	var ar := r * 0.62
	var w := tile * 0.06
	for k in 2:
		var a0 := k * PI + 0.35
		var a1 := a0 + PI - 0.7
		draw_arc(Vector2.ZERO, ar, a0, a1, 24, Palette.ARROW, w, true)
		var tip := Vector2(cos(a1), sin(a1)) * ar
		var tangent := Vector2(-sin(a1), cos(a1))
		var normal := tip.normalized()
		var head := PackedVector2Array([
			tip + tangent * w * 1.5,
			tip - tangent * w * 0.4 + normal * w * 1.3,
			tip - tangent * w * 0.4 - normal * w * 1.3,
		])
		draw_colored_polygon(head, Palette.ARROW)
