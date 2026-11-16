class_name DeadEndSign
extends Control
## "DEAD END": what a hint says when there's no way to win from where the van is. A yellow diamond road
## sign on a post drops in over the way out (`target`: the Undo button, or Retry), the rest of the screen
## dims a little (FocusDim), and a plate under the sign says how far back it went wrong (`line`). Any tap
## puts it away (and still does what it was a tap on).

var target := Rect2()
var line := ""

var _dim: FocusDim
var _t := 0.0
var _closing := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = FocusDim.new()
	_dim.hole = target
	_dim.strength = 0.32
	add_child(_dim)
	move_child(_dim, 0)
	Sfx.play("thunk", 0.9, -4.0)


func _input(e: InputEvent) -> void:
	if _t > 0.35 and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		dismiss()


func dismiss() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	if _t > 7.0:
		dismiss()
	queue_redraw()


func _draw() -> void:
	var f := UiTheme.font()
	var v := get_viewport_rect().size
	# The sign drops in over the button, lands with a wobble.
	var k := clampf(_t / 0.3, 0.0, 1.0)
	var drop := 1.0 - pow(1.0 - k, 3.0)
	var wob := sin(_t * 16.0) * 0.12 * maxf(0.0, 1.0 - (_t - 0.3) / 0.5) if _t > 0.3 else 0.0
	var foot := Vector2(clampf(target.get_center().x, 190.0, v.x - 190.0), target.position.y - 26.0)
	var c := foot + Vector2(0, -250.0 - 500.0 * (1.0 - drop))
	draw_line(foot, c + Vector2(0, 60), Color("8a8793"), 14.0)
	draw_line(foot, c + Vector2(0, 60), Color("b9b6c2"), 6.0)
	draw_set_transform(c, wob, Vector2.ONE)
	var r := 132.0
	var dia := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	var sh := PackedVector2Array()
	for p in dia:
		sh.append(p + Vector2(6, 10))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
	draw_colored_polygon(dia, Color("2b2233"))
	var inner := PackedVector2Array()
	for p in dia:
		inner.append(p * 0.92)
	draw_colored_polygon(inner, Color("ffc93c"))
	for i in 2:
		var word: String = ["DEAD", "END"][i]
		var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
		draw_string(f, Vector2(-w / 2.0, -6 + i * 56), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color("2b2233"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# What to do about it, on a plate over the sign.
	if line != "" and k >= 1.0:
		var a := clampf((_t - 0.3) / 0.2, 0.0, 1.0)
		var lw := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		var pw := minf(lw + 60.0, v.x - 40.0)
		var px := clampf(c.x - pw / 2.0, 20.0, v.x - pw - 20.0)
		var pr := Rect2(px, c.y - r - 96.0, pw, 76.0)
		DrawUtil.rrect(self, Rect2(pr.position + Vector2(0, 6), pr.size), Color(0, 0, 0, 0.2 * a), 26)
		DrawUtil.rrect(self, pr, Color(1, 1, 1, a), 26)
		draw_string(f, Vector2(pr.position.x + (pw - minf(lw, pw - 40.0)) / 2.0, pr.position.y + 50.0), line, HORIZONTAL_ALIGNMENT_LEFT, pw - 40.0, 36, Color(Color("2b2233"), a))
