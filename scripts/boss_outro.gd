class_name BossOutro
extends CanvasLayer
## A boss detour won: Baron Von Bottomline pops up in a panic ("My quarterly earnings!!"), drops his money
## bag, which bursts open in a shower of gold (that's the prize; the unlock card follows on the finish
## screen), and he runs for it, hat flying. TIME seconds; Game holds the finish card back until it's done.

const TIME := 2.6

var _root: Control
var _t := 0.0
var _line := ""
var _dropped := false
var _ran := false


func _ready() -> void:
	layer = 65
	_line = Boss.defeat()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_it)
	add_child(_root)
	Sfx.play("bonk", 0.7, -2.0)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if not _dropped and _t >= 1.05:
		_dropped = true
		Sfx.play("kaching", 0.9, -2.0)
		Sfx.play("thunk", 0.8, -4.0)
		Sfx.haptic(30, 0.8)
	if not _ran and _t >= 1.3:
		_ran = true
		Sfx.play("whoosh", 0.7, -4.0)
		Sfx.play("screech", 1.6, -12.0)
	if before < TIME - 0.25 and _t >= TIME - 0.25:
		create_tween().tween_property(_root, "modulate:a", 0.0, 0.25)
	if _t >= TIME:
		queue_free()
	_root.queue_redraw()


func _draw_it() -> void:
	var v := _root.size
	var ins := UiTheme.insets(_root.get_viewport())
	var tall := 380.0
	var floor_y := v.y - 260.0 - ins.y
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.06, 0.04, 0.12, 0.35 * clampf(_t / 0.2, 0.0, 1.0)))
	# In from the right, panicking; off to the left at a sprint after the drop.
	var x := v.x * 0.62
	if _t < 0.3:
		x = lerpf(v.x + 240.0, v.x * 0.62, 1.0 - pow(1.0 - _t / 0.3, 3.0))
	elif _t > 1.3:
		var u := (_t - 1.3) / 0.9
		x = lerpf(v.x * 0.62, -320.0, u * u)
	var feet := Vector2(x, floor_y + (absf(sin(_t * 20.0)) * -18.0 if _t > 1.3 else 0.0))
	Boss.draw(_root, feet, tall, _t, "panic", -1.0 if _t > 1.3 else 1.0)
	# Dust kicked up as he runs.
	if _t > 1.3:
		for k in 6:
			var a := fmod(_t * 3.0 + k / 6.0, 1.0)
			var p := Vector2(x + 60.0 + a * 160.0, floor_y - 10.0 - a * 30.0)
			_root.draw_circle(p, 20.0 + 30.0 * a, Color(0.85, 0.8, 0.72, 0.5 * (1.0 - a)))
	# The money bag: dropped, bounces, bursts into gold.
	if _t >= 0.9:
		var bag_x := v.x * 0.62 + 120.0
		var u := clampf((_t - 0.9) / 0.15, 0.0, 1.0)
		var bag := Vector2(bag_x, lerpf(floor_y - tall * 0.5, floor_y - 30.0, u * u))
		if _t < 1.2:
			Boss.money_bag(_root, bag, 46.0)
		var b := _t - 1.05
		if b > 0.0:
			var k := clampf(b / 0.9, 0.0, 1.0)
			_root.draw_circle(bag, 60.0 + 240.0 * k, Color(1.0, 0.9, 0.5, 0.45 * (1.0 - k)))
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			for q in 22:
				var a := rng.randf_range(-PI, 0.0)
				var sp := rng.randf_range(300.0, 700.0)
				var p := bag + Vector2(cos(a), sin(a)) * sp * b + Vector2(0, 900.0 * b * b)
				if b < 1.4:
					Icons.draw(_root, "coin", p, 40.0 * (1.0 - 0.3 * k), Color.WHITE)
	# What he says.
	if _t > 0.15 and _t < 1.6:
		var px := 44
		var f := UiTheme.font()
		var w := f.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var lines: Array = BossIntro.wrap_text(_line, px, v.x - 200.0)
		var bw := minf(w, v.x - 200.0) + 64.0
		var bh := lines.size() * px * 1.25 + 44.0
		var bc := Vector2(clampf(feet.x, bw / 2.0 + 40.0, v.x - bw / 2.0 - 40.0), feet.y - tall * 1.38 - bh / 2.0)
		var s := 1.0 - pow(1.0 - clampf((_t - 0.15) / 0.18, 0.0, 1.0), 3.0)
		_root.draw_set_transform(bc, sin(_t * 30.0) * 0.02, Vector2.ONE * s)
		DrawUtil.rrect(_root, Rect2(Vector2(-bw / 2.0, -bh / 2.0) + Vector2(0, 8), Vector2(bw, bh)), Color(0, 0, 0, 0.3), 30.0)
		DrawUtil.rrect(_root, Rect2(Vector2(-bw / 2.0, -bh / 2.0), Vector2(bw, bh)), Color.WHITE, 30.0)
		for i in lines.size():
			var lw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			_root.draw_string(f, Vector2(-lw / 2.0, -bh / 2.0 + 22.0 + px + i * px * 1.25), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("d62839"))
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
