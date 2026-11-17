class_name VanVerdict
extends Control
## What Dispatch said, kept over the van until it next moves (Game._on_radio_pressed): a little bubble, green
## "Clear road ahead!" or red "Dead end! Undo or retry", with a small red X to put it away. It sits beside the
## van on whichever side has no road still to drive (so it never covers the way on), and Game frees it the
## moment the van moves, or on an undo or a retry. `closed` when the X is tapped.

signal closed

var good := true
## Where the van is (screen space), and which way the bubble sits off it (a unit step: Game picks it).
var at := Vector2.ZERO
var dir := Vector2i(0, -1)
var tile := 120.0

var _t := 0.0
var _x: Control
var _box := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_x = Control.new()
	_x.mouse_filter = Control.MOUSE_FILTER_STOP
	_x.size = Vector2(64, 64)
	_x.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_x.accept_event()
			Sfx.play("untick", 1.0, -6.0)
			closed.emit()
			queue_free())
	add_child(_x)
	_place()


func _words() -> String:
	return "Clear road ahead!" if good else "Dead end! Undo or retry"


func _place() -> void:
	var f := UiTheme.font()
	var px := 30
	var w := f.get_string_size(_words(), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 104.0
	var h := 64.0
	var v := get_viewport_rect().size
	var off := Vector2(dir) * (tile * 0.62 + (h / 2.0 if dir.y != 0 else w / 2.0))
	var c := at + off
	_box = Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	_box.position.x = clampf(_box.position.x, 12.0, v.x - w - 12.0)
	_box.position.y = clampf(_box.position.y, 12.0, v.y - h - 12.0)
	_x.position = Vector2(_box.end.x - 34.0, _box.position.y - 28.0)


func _process(delta: float) -> void:
	_t += delta
	_place()
	queue_redraw()


func _draw() -> void:
	var f := UiTheme.font()
	var k := 1.0 - pow(1.0 - clampf(_t / 0.25, 0.0, 1.0), 3.0)
	var col := DispatchBox.GREEN.darkened(0.25) if good else DispatchBox.RED.darkened(0.1)
	var r := Rect2(_box.get_center() - _box.size * k / 2.0, _box.size * k)
	# A little pointer back at the van.
	var near := Vector2(clampf(at.x, r.position.x + 20.0, r.end.x - 20.0), clampf(at.y, r.position.y + 14.0, r.end.y - 14.0))
	var toward := (at - near).normalized()
	var side := toward.orthogonal() * 14.0
	draw_colored_polygon(PackedVector2Array([near + side, near - side, near + toward * 26.0]), Color.WHITE)
	DrawUtil.rrect(self, r.grow(5.0), Color.WHITE, 34.0)
	DrawUtil.rrect(self, r, col, 30.0)
	if k < 0.98:
		return
	var bob := sin(_t * 4.0) * 2.0
	var ic := Vector2(r.position.x + 36.0, r.get_center().y + bob)
	draw_circle(ic, 22.0, Color.WHITE)
	if good:
		draw_polyline(PackedVector2Array([ic + Vector2(-10, 0), ic + Vector2(-3, 8), ic + Vector2(11, -8)]), col, 6.0, true)
	else:
		draw_line(ic + Vector2(-8, -8), ic + Vector2(8, 8), col, 6.0, true)
		draw_line(ic + Vector2(8, -8), ic + Vector2(-8, 8), col, 6.0, true)
	draw_string(f, Vector2(r.position.x + 68.0, r.get_center().y + 11.0 + bob), _words(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	# The X: a small red circle on its corner.
	var xc := _x.position + _x.size / 2.0
	draw_circle(xc, 21.0, Color.WHITE)
	draw_circle(xc, 17.0, Color("e0453a"))
	draw_line(xc + Vector2(-7, -7), xc + Vector2(7, 7), Color.WHITE, 4.0, true)
	draw_line(xc + Vector2(7, -7), xc + Vector2(-7, 7), Color.WHITE, 4.0, true)
