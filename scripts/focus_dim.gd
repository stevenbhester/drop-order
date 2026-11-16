class_name FocusDim
extends Control
## Dims the whole screen a little, except one thing (`hole`, a rect on screen, kept up to date by whoever
## made it), with a soft ring pulsing round it: "this one". Taps go straight through. Used to make a tip
## impossible to miss (job 7's Undo lesson; the dead-end sign).

var hole := Rect2()
var strength := 0.4
var ring := Color("ffc93c")

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var v := get_viewport_rect().size
	var h := hole.grow(14.0)
	var c := Color(0.08, 0.06, 0.14, strength)
	draw_rect(Rect2(0, 0, v.x, h.position.y), c)
	draw_rect(Rect2(0, h.end.y, v.x, v.y - h.end.y), c)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), c)
	draw_rect(Rect2(h.end.x, h.position.y, v.x - h.end.x, h.size.y), c)
	var k := fmod(_t / 1.1, 1.0)
	draw_rect(h.grow(6.0 + 26.0 * k), Color(ring, 0.8 * (1.0 - k)), false, 8.0)
	draw_rect(h.grow(4.0), Color(ring, 0.9), false, 6.0)
