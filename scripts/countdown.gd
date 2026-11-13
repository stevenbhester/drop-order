class_name Countdown
extends Control
## 3, 2, 1, GO! Big numbers punching in over the board before a speedrun's clock starts. Emits `done` on GO.

signal done

var _t := 0.0
var _said := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	var k := int(floor(_t / 0.7))
	if k != _said and k <= 3:
		_said = k
		Sfx.play("tick" if k < 3 else "kaching", 1.0 + k * 0.15, -2.0)
		Sfx.haptic(20 if k < 3 else 40, 0.8)
		if k == 3:
			done.emit()
	if _t > 0.7 * 3 + 0.5:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var v := size
	var k := int(floor(_t / 0.7))
	var u := fmod(_t, 0.7) / 0.7
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.14, 0.45 * (1.0 if k < 3 else maxf(0.0, 1.0 - u * 2.0))))
	var txt: String = ["3", "2", "1", "GO!"][mini(k, 3)]
	var px := int(lerpf(320.0, 220.0, minf(u * 3.0, 1.0)))
	var f := UiTheme.font()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var a := 1.0 if u < 0.7 else (1.0 - (u - 0.7) / 0.3)
	var p := v / 2.0 + Vector2(-w / 2.0, px * 0.35)
	draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 22, Color(0.17, 0.13, 0.2, a))
	draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Color("fff3c4") if k < 3 else Color("9ff0c4"), a))
