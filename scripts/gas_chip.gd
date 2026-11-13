class_name GasChip
extends Control
## The gas gauge: a jerrycan, five pips and the countdown to the next free tank.
## When it's empty a bright "+" pulses on its corner and tapping the chip asks for the shop.

signal shop_requested

const H := 110.0
const W := 252.0
const FUEL := Color("ff6b57")
const PLUS := Color("2fc46e")

var _t := 0.0
var _shown_sec := -1
var _wiggle := 0.0
var _poll := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Progress.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	_poll += delta
	if _poll >= 0.5:
		_poll = 0.0
		Progress.tick()
	_wiggle = maxf(0.0, _wiggle - delta * 2.5)
	var sec := Progress.seconds_to_next()
	if sec != _shown_sec or _wiggle > 0.0 or Progress.gas == 0:
		_shown_sec = sec
		queue_redraw()


## A little shake, when a tank is spent or the chip is tapped.
func bump() -> void:
	_wiggle = 1.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		bump()
		Sfx.play("click")
		if Progress.gas == 0:
			shop_requested.emit()


func _draw() -> void:
	var f := UiTheme.font()
	var r := Rect2(0, 0, size.x, H - 8.0)
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 8), r.size), Color(0.36, 0.29, 0.2, 0.16), 40)
	DrawUtil.rrect(self, r, Palette.SURFACE, 40)
	var empty := Progress.gas == 0
	var tilt := sin(_wiggle * 22.0) * 0.25 * _wiggle
	draw_set_transform(Vector2(50, r.size.y / 2.0), tilt, Vector2.ONE * (1.0 + 0.15 * _wiggle))
	Icons.draw(self, "gas", Vector2.ZERO, 54.0, FUEL if not empty else Color("b9b1a6"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in Progress.MAX_GAS:
		var pip := Rect2(92.0 + i * 29.0, 16.0, 22.0, 40.0)
		DrawUtil.rrect(self, pip, FUEL if i < Progress.gas else Color(Palette.TEXT, 0.12), 9)
		if i < Progress.gas:
			DrawUtil.rrect(self, Rect2(pip.position + Vector2(4, 5), Vector2(6, 12)), Color(1, 1, 1, 0.5), 3)
	# Spare tanks (from side roads): little cans after the gauge.
	for i in Progress.reserve_gas:
		var cc := Vector2(92.0 + Progress.MAX_GAS * 29.0 + 14.0 + i * 22.0, 36.0)
		DrawUtil.rrect(self, Rect2(cc - Vector2(8, 13), Vector2(16, 26)), Color(FUEL, 0.55), 5)
		draw_rect(Rect2(cc - Vector2(4, 17), Vector2(8, 5)), Color(FUEL, 0.55))
	var sec := Progress.seconds_to_next()
	var txt := "Full tank" if sec <= 0 else "+1 in %d:%02d" % [sec / 60, sec % 60]
	draw_string(f, Vector2(92, 86), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, FUEL.darkened(0.15) if empty else Palette.TEXT_SOFT)
	if empty:
		var c := Vector2(size.x - 10.0, 12.0)
		var rad := 31.0 * (1.0 + 0.12 * sin(_t * 6.0))
		draw_circle(c, rad + 5.0, Color.WHITE)
		draw_circle(c, rad, PLUS)
		Icons.draw(self, "plus", c, rad * 1.1, Color.WHITE)
