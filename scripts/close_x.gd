class_name CloseX
extends Control
## A big red X in a white ring, for the corner of a card: "close this, take me back". Hard to miss, easy to
## hit (its tap area is a touch bigger than it looks). Emits `pressed`. Set its size; it draws to fit.

signal pressed

const RED := Color("ef4034")

var _down := false


func _init() -> void:
	custom_minimum_size = Vector2(104, 104)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if e.pressed:
			_down = true
			queue_redraw()
		elif _down:
			_down = false
			queue_redraw()
			if Rect2(Vector2.ZERO, size).grow(20.0).has_point(e.position):
				Sfx.play("click")
				Sfx.haptic(10, 0.5, "close_x:_gui_input")
				pressed.emit()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 8.0
	var k := 0.9 if _down else 1.0
	draw_circle(c + Vector2(0, 6), r * k, Color(0, 0, 0, 0.25))
	draw_circle(c, r * k, Color.WHITE)
	draw_circle(c, (r - 7.0) * k, RED.darkened(0.12) if _down else RED)
	var a := r * 0.36 * k
	draw_line(c + Vector2(-a, -a), c + Vector2(a, a), Color.WHITE, r * 0.24, true)
	draw_line(c + Vector2(a, -a), c + Vector2(-a, a), Color.WHITE, r * 0.24, true)
	for p in [Vector2(-a, -a), Vector2(a, a), Vector2(a, -a), Vector2(-a, a)]:
		draw_circle(c + p, r * 0.12, Color.WHITE)
