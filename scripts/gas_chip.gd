class_name GasChip
extends Control
## The gas gauge: a jerrycan, a pip per tank that comes back (Progress.MAX_GAS), the countdown to the next,
## and any bonus tanks as a "+N" after the pips.
## When it's empty a bright "+" pulses on its corner and tapping the chip asks for the shop.
## In a level it sits down by Hint and Undo, narrower (`wide`), and `drain` shows a tank going out of it.

signal shop_requested
signal locked_pressed            # tapped while it's padlocked (`locked`)

const H := 110.0
const W := 252.0
const FUEL := Color("ff6b57")
const PLUS := Color("2fc46e")

var wide := W                    # its width (a level's bottom row has less room than the top bars)
## In a job: drawn as a slim old gas pump (PUMP_W wide), standing in the row of buttons between Hint and the
## rest: a tall tile per can in the tank (Progress.MAX_GAS), "FULL" or the wait for the next can on the dial
## up top, and the hose and nozzle down its side.
var pump := false
const PUMP_W := 144.0
var _t := 0.0
var _drain := 0.0                # 1 → 0 as a spent tank empties out of the gauge
var _drain_i := -1               # the pip draining (-1: a bonus tank, the "+N")
var _shown_sec := -1
var _wiggle := 0.0
var _poll := 0.0
## Not open yet (the tutorial: the Baron installs it on job Progress.LIMITS_FROM): the pump in grey, a padlock
## hung on it. `reveal()` takes the lock off, big.
var locked := false:
	set(v):
		if v != locked:
			locked = v
			queue_redraw()
var _reveal := -1.0              # seconds since reveal() (-1: not revealing)


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
	if _reveal >= 0.0:
		_reveal += delta
		if _reveal > 1.6:
			_reveal = -1.0
		queue_redraw()
	_drain = maxf(0.0, _drain - delta / 0.7)
	var sec := Progress.seconds_to_next()
	if sec != _shown_sec or _wiggle > 0.0 or _drain > 0.0 or Progress.gas == 0 or (pump and Progress.reserve_gas > 0 and sec > 0):
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
	if pump:
		return 132.0           # (the nozzle)
	return 50.0 if wide >= W else 42.0


## The padlock comes off with a bang: it pops up and spins away, the pump flashes white, a ring goes out
## and the cans fill up one after another.
func reveal() -> void:
	locked = false
	_reveal = 0.0
	bump()
	Sfx.play("kaching", 1.0, -2.0)
	Sfx.play("whoomp", 1.3, -6.0)
	get_tree().create_timer(0.25).timeout.connect(func(): Sfx.play("pickup", 1.0, -6.0))
	get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play("pickup", 1.15, -6.0))
	get_tree().create_timer(0.65).timeout.connect(func(): Sfx.play("pickup", 1.3, -6.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		bump()
		if locked:
			locked_pressed.emit()
			return
		Sfx.play("click")
		if Progress.gas == 0:
			shop_requested.emit()


func _draw() -> void:
	if pump:
		_draw_pump()
		return
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


func _draw_pump() -> void:
	var f := UiTheme.font()
	var empty := Progress.gas == 0 and Progress.reserve_gas == 0 and not locked
	var red := FUEL if not (empty or locked) else Color("b9b1a6")
	var ink := Color("2b2233")
	# Revealing: the cans fill one after another (else what's in the tank).
	var shown := Progress.gas
	if _reveal >= 0.0:
		shown = mini(Progress.gas, int((_reveal - 0.15) / 0.2) + 1) if _reveal > 0.15 else 0
	var tilt := sin(_wiggle * 22.0) * 0.06 * _wiggle
	draw_set_transform(Vector2(size.x / 2.0, H), tilt, Vector2.ONE)
	var o := Vector2(-size.x / 2.0, -H)
	# The pump: a card-coloured cabinet with a red head that holds the dial.
	var body := Rect2(o + Vector2(6, 4), Vector2(106, 100))
	DrawUtil.rrect(self, Rect2(body.position + Vector2(0, 8), body.size), Color(0.36, 0.29, 0.2, 0.16), 20)
	DrawUtil.rrect(self, body, Palette.SURFACE, 20)
	DrawUtil.rrect(self, Rect2(body.position, Vector2(body.size.x, 36)), red, 16)
	# The dial (where the gallons would tick over): spare tanks, turn about with the wait for the next one.
	var dial := Rect2(body.position + Vector2(8, 6), Vector2(body.size.x - 16, 24))
	DrawUtil.rrect(self, dial, ink, 8)
	var sec := Progress.seconds_to_next()
	var wait := "%d:%02d" % [sec / 60, sec % 60]
	var txt := "FULL" if sec <= 0 else wait
	if locked:
		txt = "- - -"
	var gold := false
	var k := 1.0 + 0.3 * (_drain if _drain_i == -1 else 0.0)
	var px := int(22 * k)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, Vector2(dial.get_center().x - tw / 2.0, dial.get_center().y + px * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		Color("ffd166") if gold else (Color("9ff0c4") if sec <= 0 else Color(1, 1, 1, 0.85)))
	# A tall tile per tank that comes back.
	var n := Progress.MAX_GAS
	var gap := 6.0
	var bw := (dial.size.x - gap * (n - 1)) / n
	for i in n:
		var bar := Rect2(dial.position.x + i * (bw + gap), body.position.y + 42, bw, body.size.y - 50)
		var full := i < shown and not locked
		DrawUtil.rrect(self, bar, FUEL if full else Color(Palette.TEXT, 0.12), 7)
		if full:
			DrawUtil.rrect(self, Rect2(bar.position + Vector2(4, 5), Vector2(6, 14)), Color(1, 1, 1, 0.5), 3)
		elif locked:
			pass
		elif i == _drain_i and _drain > 0.0:
			var h := bar.size.y * _drain
			DrawUtil.rrect(self, Rect2(bar.position.x, bar.end.y - h, bar.size.x, h), FUEL, 7)
			draw_rect(bar.grow(3.0), Color(FUEL, 0.8 * _drain), false, 3.0)
	# The hose: out of the head, round and down to the nozzle hung on the cabinet's side.
	var a := Vector2(body.end.x - 2, body.position.y + 18)
	var b := Vector2(body.end.x + 30, body.position.y + 10)
	var c := Vector2(body.end.x + 20, body.position.y + 62)
	var pts := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	draw_polyline(pts, ink, 6.0, true)
	DrawUtil.rrect(self, Rect2(c + Vector2(-9, -4), Vector2(18, 28)), red, 6)
	draw_line(c + Vector2(-9, 2), c + Vector2(-17, 8), ink, 6.0, true)
	draw_line(c + Vector2(0, 24), c + Vector2(0, 34), ink, 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if locked:
		# A padlock hung on the front.
		var lc := Vector2(size.x / 2.0 - 12.0, H * 0.6)
		draw_circle(lc, 34.0, Color(1, 1, 1, 0.9))
		Icons.draw(self, "lock", lc, 50.0, Color("6b6478"))
	if _reveal >= 0.0:
		var rk := _reveal
		# A white flash off the pump, a ring going out, and the padlock flying up and away, spinning.
		if rk < 0.35:
			DrawUtil.rrect(self, Rect2(4, 2, size.x - 8.0, H - 4.0), Color(1, 1, 1, 0.85 * (1.0 - rk / 0.35)), 20)
		if rk < 0.9:
			var ru := rk / 0.9
			draw_arc(Vector2(size.x / 2.0, H / 2.0), 40.0 + 170.0 * ru, 0.0, TAU, 40, Color(FUEL, 0.9 * (1.0 - ru)), 12.0 * (1.0 - ru) + 2.0, true)
		if rk < 0.8:
			var lu := rk / 0.8
			var lp := Vector2(size.x / 2.0 - 12.0 + 60.0 * lu, H * 0.6 - 220.0 * lu + 260.0 * lu * lu)
			draw_set_transform(lp, lu * 7.0, Vector2.ONE * (1.0 + 0.4 * lu))
			Icons.draw(self, "lock", Vector2.ZERO, 50.0, Color("6b6478", 1.0 - lu))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for j in 10:
			var ang := TAU * j / 10.0 + 0.3
			var rr := 30.0 + 160.0 * minf(1.0, rk / 0.7)
			if rk < 0.7:
				draw_circle(Vector2(size.x / 2.0, H / 2.0) + Vector2(cos(ang), sin(ang)) * rr, 9.0 * (1.0 - rk / 0.7), Color("ffd166"))
	if empty:
		var cc := Vector2(size.x - 12.0, 12.0)
		var rad := 24.0 * (1.0 + 0.12 * sin(_t * 6.0))
		draw_circle(cc, rad + 5.0, Color.WHITE)
		draw_circle(cc, rad, PLUS)
		Icons.draw(self, "plus", cc, rad * 1.1, Color.WHITE)
