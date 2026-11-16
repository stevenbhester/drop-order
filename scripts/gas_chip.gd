class_name GasChip
extends Control
## The gas gauge: a jerrycan, a pip per tank that comes back (Progress.MAX_GAS), the countdown to the next,
## and any bonus tanks as a "+N" after the pips.
## When it's empty a bright "+" pulses on its corner and tapping the chip asks for the shop.
## In a level it sits down by Hint and Undo, narrower (`wide`), and `drain` shows a tank going out of it.

signal shop_requested

const H := 110.0
const W := 252.0
const FUEL := Color("ff6b57")
const PLUS := Color("2fc46e")

var wide := W                    # its width (a level's bottom row has less room than the top bars)
var _t := 0.0
var _drain := 0.0                # 1 → 0 as a spent tank empties out of the gauge
var _drain_i := -1               # the pip draining (-1: a bonus tank, the "+N")
var _shown_sec := -1
var _wiggle := 0.0
var _poll := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(wide, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Progress.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	_poll += delta
	if _poll >= 0.5:
		_poll = 0.0
		Progress.tick()
	_wiggle = maxf(0.0, _wiggle - delta * 2.5)
	_drain = maxf(0.0, _drain - delta / 0.7)
	var sec := Progress.seconds_to_next()
	if sec != _shown_sec or _wiggle > 0.0 or _drain > 0.0 or Progress.gas == 0:
		_shown_sec = sec
		queue_redraw()


## A little shake, when a tank is spent or the chip is tapped.
func bump() -> void:
	_wiggle = 1.0


## A tank was just spent: the gauge shakes and that tank empties out of it (a pip drains, or the bonus
## "+N" blinks). `bonus`: it was a bonus tank (they go first).
func drain(bonus: bool) -> void:
	bump()
	_drain = 1.0
	_drain_i = -1 if bonus else Progress.gas


## Where the can on the gauge is, on screen (a spent tank flies off it).
func can_pos() -> Vector2:
	return global_position + Vector2(_can_x(), (H - 8.0) / 2.0)


func _can_x() -> float:
	return 50.0 if wide >= W else 42.0


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
	var narrow := wide < W
	var x0 := 92.0 if not narrow else 78.0          # where the pips start
	var step := 29.0 if not narrow else 26.0
	var pw := 22.0 if not narrow else 20.0
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 8), r.size), Color(0.36, 0.29, 0.2, 0.16), 40)
	DrawUtil.rrect(self, r, Palette.SURFACE, 40)
	var empty := Progress.gas == 0 and Progress.reserve_gas == 0
	var tilt := sin(_wiggle * 22.0) * 0.25 * _wiggle
	draw_set_transform(Vector2(_can_x(), r.size.y / 2.0), tilt, Vector2.ONE * (1.0 + 0.15 * _wiggle))
	Icons.draw(self, "gas", Vector2.ZERO, 54.0 if not narrow else 48.0, FUEL if not empty else Color("b9b1a6"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in Progress.MAX_GAS:
		var pip := Rect2(x0 + i * step, 16.0, pw, 40.0)
		var full := i < Progress.gas
		DrawUtil.rrect(self, pip, FUEL if full else Color(Palette.TEXT, 0.12), 9)
		if full:
			DrawUtil.rrect(self, Rect2(pip.position + Vector2(4, 5), Vector2(6, 12)), Color(1, 1, 1, 0.5), 3)
		elif i == _drain_i and _drain > 0.0:
			# The tank just spent, emptying: its fuel sinks out the bottom, and the pip flashes.
			var h := pip.size.y * _drain
			DrawUtil.rrect(self, Rect2(pip.position.x, pip.end.y - h, pip.size.x, h), FUEL, 9)
			draw_rect(pip.grow(4.0), Color(FUEL, 0.8 * _drain), false, 4.0)
	# Bonus tanks (chests, detours, the ad): "+N" after the pips.
	var bx := x0 + Progress.MAX_GAS * step + 4.0
	if Progress.reserve_gas > 0 or (_drain_i == -1 and _drain > 0.0):
		var k := 1.0 + 0.35 * (_drain if _drain_i == -1 else 0.0)
		var txt := "+%d" % Progress.reserve_gas
		draw_set_transform(Vector2(bx, 48.0), 0.0, Vector2.ONE * k)
		draw_string(f, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30 if not narrow else 26, FUEL.darkened(0.1).lerp(Color.WHITE, 0.6 * (_drain if _drain_i == -1 else 0.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sec := Progress.seconds_to_next()
	var t2 := "Full tank" if sec <= 0 else "+1 in %d:%02d" % [sec / 60, sec % 60]
	draw_string(f, Vector2(x0, 86), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if not narrow else 22, FUEL.darkened(0.15) if empty else Palette.TEXT_SOFT)
	if empty:
		var c := Vector2(size.x - 10.0, 12.0)
		var rad := 31.0 * (1.0 + 0.12 * sin(_t * 6.0))
		draw_circle(c, rad + 5.0, Color.WHITE)
		draw_circle(c, rad, PLUS)
		Icons.draw(self, "plus", c, rad * 1.1, Color.WHITE)
