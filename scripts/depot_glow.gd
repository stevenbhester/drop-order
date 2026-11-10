class_name DepotGlow
extends Node2D
## Return-to-depot levels: marks the depot as "home", and pulses once everything is
## delivered to call the van back.

var tile := 180.0
var calling := false:
	set(v):
		calling = v
		queue_redraw()
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if calling:
		queue_redraw()


func _draw() -> void:
	var r := tile * 0.36
	DrawUtil.rrect(self, Rect2(-Vector2(r, r), Vector2(r, r) * 2.0), Color(Palette.DEPOT, 0.35 if calling else 0.22), tile * 0.12)
	# little garage roof above the pad
	var roof := PackedVector2Array([Vector2(-r * 0.55, -r * 0.55), Vector2(0, -r * 0.95), Vector2(r * 0.55, -r * 0.55)])
	draw_polyline(roof, Palette.DEPOT, tile * 0.06, true)
	for p in roof:
		draw_circle(p, tile * 0.03, Palette.DEPOT)
	if calling:
		for k0 in [0.0, 0.5]:
			var k := fmod(_t / 1.1 + k0, 1.0)
			draw_arc(Vector2.ZERO, r * (1.0 + 0.6 * k), 0, TAU, 48, Color(Palette.DEPOT, 0.9 * (1.0 - k)), tile * 0.05, true)
