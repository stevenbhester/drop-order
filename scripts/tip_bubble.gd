class_name TipBubble
extends Control
## A little tutorial tip: a speech bubble with a line or two, pointing at what it's about (a tap
## animation on the spot when `tap` is set). It pops in, and any tap or drag anywhere (or `life` seconds)
## sends it away; the tap still goes through to the game.

signal gone

var text := ""
## Where it points, in this control's space (the screen); INF: nowhere.
var target := Vector2.INF
var tap := false
var life := 7.0

var _t := 0.0
var _closing := false
var _box := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place()
	scale = Vector2.ONE
	Sfx.play("pop", 1.2, -8.0)


func _place() -> void:
	var v := get_viewport_rect().size
	var f := UiTheme.font()
	var px := 36
	var lines := text.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var size2 := Vector2(w + 64.0, lines.size() * (px + 10.0) + 40.0)
	var at := v / 2.0 - size2 / 2.0
	if target != Vector2.INF:
		# Beside the target, on whichever side has room; above or below it otherwise.
		if target.x < v.x * 0.3:
			at = Vector2(target.x + 90.0, target.y - size2.y / 2.0)
		elif target.x > v.x * 0.7:
			at = Vector2(target.x - 90.0 - size2.x, target.y - size2.y / 2.0)
		elif target.y < v.y * 0.5:
			at = Vector2(target.x - size2.x / 2.0, target.y + 90.0)
		else:
			at = Vector2(target.x - size2.x / 2.0, target.y - 90.0 - size2.y)
	at.x = clampf(at.x, 20.0, v.x - size2.x - 20.0)
	at.y = clampf(at.y, 160.0, v.y - size2.y - 20.0)
	_box = Rect2(at, size2)


func _input(e: InputEvent) -> void:
	if _t > 0.4 and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		dismiss()


func dismiss() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		gone.emit()
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	if _t > life:
		dismiss()
	queue_redraw()


func _draw() -> void:
	var k := minf(_t / 0.25, 1.0)
	var pop := 1.0 + 0.12 * sin(PI * k) * (1.0 - k)
	var r := _box
	var c := r.get_center()
	draw_set_transform(c, 0.0, Vector2.ONE * pop * (0.7 + 0.3 * k))
	var lr := Rect2(-r.size / 2.0, r.size)
	# The tail toward the target.
	if target != Vector2.INF:
		var tl := target - c
		var dir := tl.normalized()
		var side := Vector2(-dir.y, dir.x)
		var edge := dir * minf(r.size.x, r.size.y) * 0.45
		draw_colored_polygon(PackedVector2Array([edge + side * 22.0, edge - side * 22.0, tl - dir * 46.0]), Palette.ACCENT)
	DrawUtil.rrect(self, Rect2(lr.position + Vector2(0, 8), lr.size), Color(0, 0, 0, 0.18), 30)
	DrawUtil.rrect(self, lr.grow(5), Palette.ACCENT, 34)
	DrawUtil.rrect(self, lr, Color.WHITE, 30)
	var f := UiTheme.font()
	var lines := text.split("\n")
	for i in lines.size():
		var tw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		draw_string(f, Vector2(-tw / 2.0, lr.position.y + 20.0 + 36.0 * 0.8 + i * 46.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.TEXT if i == 0 else Palette.TEXT_SOFT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A ring on the target, and a finger tapping it.
	if target != Vector2.INF:
		var u := fmod(_t, 1.2) / 1.2
		draw_arc(target, 40.0 + 30.0 * u, 0, TAU, 32, Color(Palette.ACCENT, 0.8 * (1.0 - u)), 6.0, true)
		if tap:
			var press := absf(sin(_t * 4.0))
			Icons.draw(self, "finger", target + Vector2(26, 46 + 10 * press), 70.0, Color(1, 1, 1, 0.95))
