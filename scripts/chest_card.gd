class_name ChestCard
extends Control
## A milestone chest opening over the map. It drops in and lands with a squash, then rattles harder and
## harder, light leaking from under the lid, "Tap to open!" bobbing over it; a tap (or AUTO_OPEN seconds)
## and the lid blows off spinning in a flash and a shower of sparks. Then what it held comes out one thing
## at a time, each hopping out of the chest to its own line with a pop a note higher: gas, a hint for every
## job, the jump jets, a hat or a ride. "Sweet!" closes it (the jets and a hat then get their own cards:
## LevelSelect). Progress has already been paid (Progress.open_chest).

signal closed

const AUTO_OPEN := 2.2          # it opens by itself this long after it lands, if nobody taps
const LANDS := 0.35
const EACH := 0.4               # between one thing coming out and the next
const WOOD := Color("b8733a")
const BAND := Color("ffcf4d")

## What the chest gave: {gas, coins, hat, cashed, hints, jets}.
var got := {}
var level_number := 0

var _t := 0.0
var _c := Vector2.ZERO
var _fx: Fx
var _ok: JuicyButton
var _open_t := -1.0             # when it opened (-1: not yet)
var _loot: Array = []           # what comes out, in order: {icon, col, text, ink}
var _out := 0                   # how many are out
var _closing := false


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	_c = Vector2(size.x / 2.0, size.y * 0.36)
	if int(got.get("gas", 0)) > 0:
		_loot.append({"icon": "gas", "col": GasChip.FUEL, "text": "Tank filled up!", "ink": Color("9fe6ff")})
	if int(got.get("radio", 0)) > 0:
		_loot.append({"icon": "radio", "col": Color("9fe6ff"), "text": "+%d calls" % int(got["radio"]), "ink": Color("9fe6ff")})
	if int(got.get("coins", 0)) > 0:
		_loot.append({"icon": "coin", "col": Palette.STAR_GOLD, "text": "+%s Dollaroos" % Progress.commas(int(got["coins"])), "ink": Color("ffe08a")})
	if int(got.get("hints", 0)) > 0:
		_loot.append({"icon": "bulb", "col": Color("fff3a0"), "text": "+%d hint%s" % [int(got["hints"]), "" if int(got["hints"]) == 1 else "s"], "ink": Color("fff3a0")})
	if got.get("jets", false):
		_loot.append({"icon": "jump", "col": Color("ff9d5c"), "text": "JUMP JETS!", "ink": Color("ffb37a")})
	if str(got.get("hat", "")) != "":
		_loot.append({"icon": "gift", "col": Color("ffb3d9"), "text": "and a ride!" if Cosmetics.kind_of(str(got["hat"])) == "ride" else "and a hat!", "ink": Color("ffb3d9")})
	_fx = Fx.new()
	add_child(_fx)
	_ok = JuicyButton.new()
	_ok.label = "Sweet!"
	_ok.font_px = 60
	_ok.bg = Palette.GOOD
	_ok.fg = Color.WHITE
	_ok.size = Vector2(520, 140)
	_ok.position = Vector2((size.x - 520) / 2.0, size.y * 0.8)
	_ok.visible = false
	_ok.pressed.connect(_close)
	add_child(_ok)
	Sfx.play("whoosh", 0.8, -4.0)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < LANDS and _t >= LANDS:
		Sfx.play("thunk", 0.8)
		Sfx.haptic(20, 1.0, "chest_card:_process")
	if _open_t < 0.0:
		# Rattling: a knock now and then, quicker as it goes.
		if _t > LANDS + 0.2 and fmod(_t, 0.42) < delta:
			Sfx.play("tick", 0.7 + 0.2 * (_t - LANDS), -10.0)
			Sfx.haptic(6, 0.3, "chest_card:_process")
		if _t >= LANDS + AUTO_OPEN:
			_open()
	else:
		while _out < _loot.size() and _t >= _open_t + 0.35 + _out * EACH:
			var it: Dictionary = _loot[_out]
			Sfx.play("pickup", 0.9 + 0.12 * _out, -3.0)
			Sfx.play("pop", 1.0 + 0.08 * _out, -8.0)
			Sfx.haptic(14, 0.5, "chest_card:_process")
			_fx.burst(_row_at(_out) + Vector2(-200, 0), it["col"], 10, 420.0, 14.0)
			_out += 1
		if not _ok.visible and _t >= _open_t + 0.35 + _loot.size() * EACH + 0.3:
			_ok.visible = true
			_ok.pivot_offset = _ok.size / 2.0
			_ok.scale = Vector2.ZERO
			var tw := _ok.create_tween()
			tw.tween_property(_ok, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_ok.breathe.bind(true))
	queue_redraw()


## The lid goes.
func _open() -> void:
	if _open_t >= 0.0:
		return
	_open_t = _t
	Sfx.play("punch", 1.2, -2.0)
	Sfx.play("kaching", 1.0, -2.0)
	Sfx.play("sparkle")
	Sfx.haptic(45, 1.0, "chest_card:_open")
	_fx.ring(_c + Vector2(0, -40), BAND, 300.0)
	_fx.burst(_c + Vector2(0, -40), BAND, 34, 1200.0, 26.0)
	_fx.burst(_c + Vector2(0, -40), Color("fff1b8"), 20, 850.0, 18.0)


## Where the `i`th thing's line sits.
func _row_at(i: int) -> Vector2:
	return Vector2(size.x / 2.0, _c.y + 290.0 + i * 96.0)


func _close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		accept_event()
		if _open_t < 0.0 and _t >= LANDS:
			_open()                 # a tap opens it there and then
		elif _open_t >= 0.0 and _out < _loot.size():
			_open_t = _t - 0.35 - _loot.size() * EACH        # (a tap while it's emptying: all out at once)


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _text(text: String, at: Vector2, px: int, col: Color, outline := 10) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := at + Vector2(-w / 2.0, px * 0.36)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color("2b2233"))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw() -> void:
	var v := size
	var f := UiTheme.font()
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.14, 0.88 * clampf(_t / 0.15, 0.0, 1.0)))
	var opened := _open_t >= 0.0
	var since := _t - _open_t if opened else 0.0
	# Open: light pours out, turning.
	if opened:
		var k := _ease(since / 0.4)
		for i in 14:
			var a := TAU * i / 14.0 + _t * 0.4
			var p2 := _c + Vector2(cos(a + 0.12), sin(a + 0.12)) * 1000.0 * k
			var p3 := _c + Vector2(cos(a - 0.12), sin(a - 0.12)) * 1000.0 * k
			draw_colored_polygon(PackedVector2Array([_c + Vector2(0, -40), p2, p3]), Color("ffe08a", 0.16))
		var flash := clampf(1.0 - since / 0.25, 0.0, 1.0)
		if flash > 0.0:
			draw_circle(_c, 520.0, Color(1, 1, 0.9, 0.18 * flash))
	_text("JOB %d CHEST" % level_number, Vector2(v.x / 2.0, _c.y - 330.0), 46, Color.WHITE)
	# The chest: drops in, lands with a squash, rattles harder and harder, light under the lid.
	var drop := _ease(_t / LANDS)
	var c := _c + Vector2(0, -700.0 * (1.0 - drop))
	var wind := clampf((_t - LANDS) / AUTO_OPEN, 0.0, 1.0) if not opened else 0.0
	var rattle := sin(_t * (50.0 + 40.0 * wind)) * (0.02 + 0.09 * wind) * (1.0 if _t > LANDS + 0.1 and not opened else 0.0)
	var hop := absf(sin(_t * 9.0)) * 14.0 * wind
	var sq := 1.0 + (0.18 * maxf(0.0, 1.0 - (_t - LANDS) / 0.15) if _t > LANDS else 0.0)
	draw_set_transform(c + Vector2(0, -hop), rattle, Vector2(sq, 1.0 / sq) * 2.6)
	draw_circle(Vector2(0, 52), 58.0, Color(0, 0, 0, 0.2))
	DrawUtil.rrect(self, Rect2(-56, -10, 112, 62), WOOD.darkened(0.3), 12)
	DrawUtil.rrect(self, Rect2(-56, -16, 112, 62), WOOD, 12)
	if opened:
		DrawUtil.rrect(self, Rect2(-50, -20, 100, 16), Color("3a2418"), 6)
		DrawUtil.rrect(self, Rect2(-46, -22, 92, 10), Color("ffe9a0"), 5)
	else:
		# Light leaking from under the lid, brighter as it winds up.
		if wind > 0.0:
			DrawUtil.rrect(self, Rect2(-62, -26, 124, 14), Color(1.0, 0.92, 0.55, 0.25 + 0.6 * wind * (0.6 + 0.4 * sin(_t * 14.0))), 7)
		DrawUtil.rrect(self, Rect2(-60, -50 - 5.0 * wind * absf(sin(_t * 11.0)), 120, 40), WOOD.lightened(0.08), 16)
		draw_rect(Rect2(-60, -20, 120, 6), BAND)
		DrawUtil.rrect(self, Rect2(-14, -28, 28, 32), BAND.darkened(0.1), 6)
	for x in [-38.0, 38.0]:
		draw_rect(Rect2(x - 6, -16, 12, 62), BAND)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if opened and since < 1.1:
		# The lid, blown off: up and away, spinning.
		var lk := since / 1.1
		var lp := _c + Vector2(260.0 * lk, -130.0 - 900.0 * lk + 900.0 * lk * lk)
		draw_set_transform(lp, lk * 9.0, Vector2.ONE * 2.6)
		DrawUtil.rrect(self, Rect2(-60, -20, 120, 40), Color(WOOD.lightened(0.08), 1.0 - lk), 16)
		draw_rect(Rect2(-60, 10, 120, 6), Color(BAND, 1.0 - lk))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not opened and _t > LANDS + 0.3:
		_text("Tap to open!", Vector2(v.x / 2.0, _c.y + 250.0 + 8.0 * sin(_t * 5.0)), 54, Color("fff3a0"))
	# What was in it: each thing hops out of the chest to its line.
	for i in _out:
		var it: Dictionary = _loot[i]
		var age := _t - (_open_t + 0.35 + i * EACH)
		var k := _ease(age / 0.32)
		var row := _row_at(i)
		var tw := f.get_string_size(str(it["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
		var icon_to := row + Vector2(-tw / 2.0 - 54.0, 0)
		var from := _c + Vector2(0, -80)
		var p := from.lerp(icon_to, k) + Vector2(0, -220.0 * sin(PI * k))
		var pop := 1.0 + 0.5 * clampf(1.0 - (age - 0.3) / 0.2, 0.0, 1.0) if age > 0.3 else 1.0
		Icons.draw(self, str(it["icon"]), p, 84.0 * pop, it["col"])
		if age > 0.22:
			var tk := _ease((age - 0.22) / 0.2)
			_text(str(it["text"]), row + Vector2(36.0, 0), int(58 * (0.6 + 0.4 * tk) * pop), it["ink"], 12)
	if int(got.get("cashed", 0)) > 0 and _out >= _loot.size():
		var cashed := int(got["cashed"])
		_text("(bonus gas full: %d can%s cashed in)" % [cashed, "" if cashed == 1 else "s"], _row_at(_loot.size()) + Vector2(0, -20), 30, Color(1, 1, 1, 0.75), 6)
