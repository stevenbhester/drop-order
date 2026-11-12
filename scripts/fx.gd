class_name Fx
extends Node2D
## Small one-shot effects: sparkle bursts, expanding rings and floating words.
## Add one over whatever it decorates and call burst / ring / say with positions in its own space.

var _parts: Array = []
var _rings: Array = []
var _words: Array = []


## A puff of little stars and dots in `col` (plus a few white ones).
func burst(at: Vector2, col: Color, n := 14, speed := 460.0, size := 16.0) -> void:
	for i in n:
		var a := randf() * TAU
		_parts.append({
			"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(0.35, 1.0) * speed + Vector2(0, -speed * 0.25),
			"c": Color.WHITE if i % 4 == 0 else col.lerp(Color.WHITE, randf_range(0.0, 0.35)),
			"s": randf_range(0.6, 1.2) * size, "star": i % 2 == 0, "spin": randf() * TAU, "w": randf_range(-6.0, 6.0),
			"t": 0.0, "life": randf_range(0.45, 0.8),
		})


func ring(at: Vector2, col: Color, radius: float) -> void:
	_rings.append({"p": at, "c": col, "r": radius, "t": 0.0, "life": 0.4})


## A word that pops up, drifts and fades ("Nice!").
func say(at: Vector2, text: String, col: Color, px := 60) -> void:
	_words.append({"p": at, "text": text, "c": col, "px": px, "t": 0.0, "life": 0.9, "tilt": randf_range(-0.12, 0.12)})


func _process(delta: float) -> void:
	if _parts.is_empty() and _rings.is_empty() and _words.is_empty():
		return
	for q in _parts:
		q["t"] += delta
		q["v"] = q["v"] * (1.0 - 2.2 * delta) + Vector2(0, 900.0 * delta)
		q["p"] += q["v"] * delta
		q["spin"] += q["w"] * delta
	for q in _rings:
		q["t"] += delta
	for q in _words:
		q["t"] += delta
	_parts = _parts.filter(func(q): return q["t"] < q["life"])
	_rings = _rings.filter(func(q): return q["t"] < q["life"])
	_words = _words.filter(func(q): return q["t"] < q["life"])
	queue_redraw()


func _draw() -> void:
	for q in _rings:
		var k: float = q["t"] / q["life"]
		var e := 1.0 - pow(1.0 - k, 3.0)
		draw_arc(q["p"], q["r"] * (0.3 + 0.9 * e), 0, TAU, 40, Color(q["c"], 0.8 * (1.0 - k)), q["r"] * 0.16 * (1.0 - k) + 1.0, true)
	for q in _parts:
		var k: float = q["t"] / q["life"]
		var s: float = q["s"] * (1.0 - k * k)
		if s < 1.5:
			continue
		if q["star"]:
			draw_colored_polygon(Icons.star_points(q["p"], s, s * 0.45, q["spin"]), q["c"])
		else:
			draw_circle(q["p"], s * 0.45, q["c"])
	var f := UiTheme.font()
	for q in _words:
		var k: float = q["t"] / q["life"]
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - k * 7.0)
		var grow := minf(k * 9.0, 1.0)
		var px := maxi(int(q["px"] * pop * grow), 4)
		var alpha := 1.0 - smoothstep(0.6, 1.0, k)
		var pos: Vector2 = q["p"] + Vector2(0, -90.0 * (1.0 - pow(1.0 - k, 2.0)))
		var w := f.get_string_size(q["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_set_transform(pos, q["tilt"], Vector2.ONE)
		draw_string_outline(f, Vector2(-w / 2.0, px * 0.35), q["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(px / 4, 6), Color(1, 1, 1, alpha))
		draw_string(f, Vector2(-w / 2.0, px * 0.35), q["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(q["c"], alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
