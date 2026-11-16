class_name GasPour
extends Control
## A tank spent on an undo or a hint, shown: a gas can hops off the gauge, arcs over to the button, tips up
## and pours into it (the button glows and pops), then it's gone in a puff with a "−1". Quick (under a
## second) and it doesn't block anything: the undo or hint goes ahead underneath it.

const FUEL := GasChip.FUEL
const TIME := 0.95

var from := Vector2.ZERO          # the gauge's can, on screen
var button: Control               # the Hint or Undo button

var _t := 0.0
var _popped := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("whoosh", 1.3, -8.0)
	Sfx.haptic(12)


func _process(delta: float) -> void:
	_t += delta
	if not _popped and _t >= 0.5:
		_popped = true
		Sfx.play("pop", 1.3, -5.0)
		Sfx.haptic(18)
		if is_instance_valid(button) and button.has_method("pop"):
			button.pop()
	if _t >= TIME:
		queue_free()
	queue_redraw()


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _draw() -> void:
	if not is_instance_valid(button):
		return
	var r := button.get_global_rect()
	var bc := r.get_center()
	# Over the button's top-left corner, so the pour lands on it without hiding its label.
	var over := bc + Vector2(-r.size.x * 0.18, -r.size.y * 0.95)
	var pos := from
	var rot := 0.0
	var s := 1.0
	var a := 1.0
	var u := _t
	if u < 0.32:
		var k := _ease(u / 0.32)
		pos = from.lerp(over, k) + Vector2(0, -150.0 * sin(PI * k))
		rot = 0.7 * k
		s = lerpf(0.9, 1.25, k)
	elif u < 0.72:
		pos = over
		rot = lerpf(0.7, 2.0, _ease((u - 0.32) / 0.15))
		s = 1.25
	else:
		pos = over
		rot = 2.0
		s = 1.25
		a = 1.0 - (u - 0.72) / 0.15
	# The pour: fuel drops from the spout into the button, which lights up.
	if u >= 0.38 and u < 0.74:
		var spout := pos + Vector2(28, -26).rotated(rot) * s
		for k in 6:
			var d := fmod(u * 4.0 + k / 6.0, 1.0)
			draw_circle(spout.lerp(bc + Vector2(0, -12), d), 9.0 * (1.0 - 0.4 * d), Color(FUEL, 0.95))
	if u >= 0.4:
		var g := clampf((u - 0.4) / 0.15, 0.0, 1.0) * clampf((TIME - u) / 0.3, 0.0, 1.0)
		DrawUtil.rrect(self, r.grow(6.0 + 8.0 * g), Color(FUEL, 0.28 * g), 34)
	if u >= 0.72:
		# The puff where the can was, and the "−1" rising out of it.
		var k := clampf((u - 0.72) / 0.23, 0.0, 1.0)
		for q in 6:
			var ang := TAU * q / 6.0
			draw_circle(over + Vector2(cos(ang), sin(ang)) * 50.0 * k, 18.0 * (1.0 - k) + 3.0, Color(0.92, 0.9, 0.95, 0.8 * (1.0 - k)))
	if u >= 0.5:
		var k := clampf((u - 0.5) / 0.45, 0.0, 1.0)
		var f := UiTheme.font()
		var at := Vector2(r.end.x - 70.0, r.position.y - 20.0 - 60.0 * k)
		var c := Color(FUEL, 1.0 - k * k)
		draw_string_outline(f, at, "−1", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 12, Color(1, 1, 1, 1.0 - k * k))
		draw_string(f, at, "−1", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, c)
	if a > 0.0:
		draw_set_transform(pos, rot, Vector2.ONE * s)
		Icons.draw(self, "gas", Vector2.ZERO, 62.0, Color(FUEL, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
