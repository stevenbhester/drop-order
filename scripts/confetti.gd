class_name Confetti
extends Node2D
## Cheap hand-rolled confetti: fast burst, gravity, flutter, fade.

var parts: Array = []


func burst(at: Vector2, angle: float, spread: float, n := 60) -> void:
	var cols := Palette.confetti()
	for i in n:
		var a := angle + randf_range(-spread, spread)
		parts.append({
			"p": at,
			"v": Vector2(cos(a), sin(a)) * randf_range(1300.0, 2700.0),
			"r": randf() * TAU,
			"w": randf_range(-14.0, 14.0),
			"c": cols.pick_random(),
			"s": randf_range(16.0, 28.0),
			"life": randf_range(1.1, 1.7),
			"t": 0.0,
		})


func _process(delta: float) -> void:
	if parts.is_empty():
		return
	for p in parts:
		var v: Vector2 = p["v"]
		v.y += 2600.0 * delta
		v *= 1.0 - 1.3 * delta
		p["v"] = v
		p["p"] += v * delta
		p["r"] += p["w"] * delta
		p["t"] += delta
	parts = parts.filter(func(p): return p["t"] < p["life"])
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var a := 1.0 - clampf((p["t"] - p["life"] + 0.35) / 0.35, 0.0, 1.0)
		var s: float = p["s"]
		draw_set_transform(p["p"], p["r"], Vector2(1.0, 0.35 + 0.65 * absf(sin(p["t"] * 12.0 + p["w"]))))
		draw_rect(Rect2(-s / 2, -s * 0.3, s, s * 0.6), Color(p["c"], a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
