class_name ChestCard
extends Control
## A milestone chest opening over the map: it drops in, rattles, and bursts open in a shower of coins and
## gas cans, with what it held called out ("+400 Dollaroos", "+3 gas", "and a hat!"). "Sweet!" closes it
## (a hat then gets its own UnlockCard). Progress has already been paid (Progress.open_chest).

signal closed

const OPEN_AT := 0.85
const WOOD := Color("b8733a")
const BAND := Color("ffcf4d")

## What the chest gave: {gas, coins, hat}.
var got := {}
var level_number := 0

var _t := 0.0
var _c := Vector2.ZERO
var _fx: Fx
var _ok: JuicyButton
var _opened := false
var _closing := false


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	_c = Vector2(size.x / 2.0, size.y * 0.42)
	_fx = Fx.new()
	add_child(_fx)
	_ok = JuicyButton.new()
	_ok.label = "Sweet!"
	_ok.font_px = 60
	_ok.bg = Palette.GOOD
	_ok.fg = Color.WHITE
	_ok.size = Vector2(520, 140)
	_ok.position = Vector2((size.x - 520) / 2.0, size.y * 0.76)
	_ok.visible = false
	_ok.pressed.connect(_close)
	add_child(_ok)
	Sfx.play("whoosh", 0.8, -4.0)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < 0.35 and _t >= 0.35:
		Sfx.play("thunk", 0.8)
		Sfx.haptic(20)
	if not _opened and _t >= OPEN_AT:
		_opened = true
		Sfx.play("kaching", 1.0, -2.0)
		Sfx.play("sparkle")
		Sfx.haptic(40, 1.0)
		_fx.burst(_c + Vector2(0, -40), BAND, 30, 1100.0, 26.0)
		_fx.burst(_c + Vector2(0, -40), Color("fff1b8"), 18, 800.0, 18.0)
	if not _ok.visible and _t >= OPEN_AT + 0.7:
		_ok.visible = true
		_ok.pivot_offset = _ok.size / 2.0
		_ok.scale = Vector2.ZERO
		var tw := _ok.create_tween()
		tw.tween_property(_ok, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_ok.breathe.bind(true))
	queue_redraw()


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
	if e is InputEventMouseButton and e.pressed and _t > OPEN_AT + 0.7:
		accept_event()


static func _out(u: float) -> float:
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
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.14, 0.86 * clampf(_t / 0.15, 0.0, 1.0)))
	# Light pours out once it's open.
	if _opened:
		var k := _out((_t - OPEN_AT) / 0.4)
		for i in 14:
			var a := TAU * i / 14.0 + _t * 0.4
			var p2 := _c + Vector2(cos(a + 0.12), sin(a + 0.12)) * 900.0 * k
			var p3 := _c + Vector2(cos(a - 0.12), sin(a - 0.12)) * 900.0 * k
			draw_colored_polygon(PackedVector2Array([_c + Vector2(0, -40), p2, p3]), Color("ffe08a", 0.16))
	# The chest drops in, lands with a squash, rattles, then the lid flies open.
	var drop := _out(_t / 0.35)
	var c := _c + Vector2(0, -700.0 * (1.0 - drop))
	var rattle := 0.0
	if _t > 0.45 and _t < OPEN_AT:
		rattle = sin(_t * 70.0) * 0.06
	var sq := 1.0 + (0.18 * maxf(0.0, 1.0 - (_t - 0.35) / 0.15) if _t > 0.35 else 0.0)
	draw_set_transform(c, rattle, Vector2(sq, 1.0 / sq) * 2.4)
	draw_circle(Vector2(0, 52), 58.0, Color(0, 0, 0, 0.2))
	DrawUtil.rrect(self, Rect2(-56, -10, 112, 62), WOOD.darkened(0.3), 12)
	DrawUtil.rrect(self, Rect2(-56, -16, 112, 62), WOOD, 12)
	if _opened:
		var lid := _out((_t - OPEN_AT) / 0.25)
		DrawUtil.rrect(self, Rect2(-50, -20, 100, 16), Color("3a2418"), 6)
		DrawUtil.rrect(self, Rect2(-58, -18 - 52.0 * lid, 116, 40 * (1.0 - 0.4 * lid)), WOOD.lightened(0.06), 16)
	else:
		DrawUtil.rrect(self, Rect2(-60, -50, 120, 40), WOOD.lightened(0.08), 16)
		draw_rect(Rect2(-60, -20, 120, 6), BAND)
		DrawUtil.rrect(self, Rect2(-14, -28, 28, 32), BAND.darkened(0.1), 6)
	for x in [-38.0, 38.0]:
		draw_rect(Rect2(x - 6, -16, 12, 62), BAND)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# What was in it: coins and gas cans pop up out of it, then the tally.
	if _opened:
		var k := _out((_t - OPEN_AT) / 0.5)
		var coins: int = got.get("coins", 0)
		var gas: int = got.get("gas", 0)
		var items := []
		for i in mini(gas, 5):
			items.append("gas")
		for i in 5:
			items.append("coin")
		for i in items.size():
			var a := -PI / 2.0 + (i - (items.size() - 1) / 2.0) * 0.32
			var at := _c + Vector2(0, -60) + Vector2(cos(a), sin(a)) * 320.0 * k
			Icons.draw(self, items[i], at, 74.0, GasChip.FUEL if items[i] == "gas" else Palette.STAR_GOLD)
		var y := _c.y + 250.0
		_text("LEVEL %d CHEST" % level_number, Vector2(v.x / 2.0, _c.y - 470.0), 46, Color.WHITE)
		if coins > 0:
			_text("+%s Dollaroos" % Progress.commas(coins), Vector2(v.x / 2.0, y), int(64 * k), Color("ffe08a"), 12)
			y += 86.0
		if gas > 0:
			_text("+%d gas" % gas, Vector2(v.x / 2.0, y), int(58 * k), Color("9fe6ff"), 12)
			y += 80.0
		var cashed: int = got.get("cashed", 0)
		if cashed > 0:
			_text("(tank's full: %d gas can%s cashed in)" % [cashed, "" if cashed == 1 else "s"], Vector2(v.x / 2.0, y - 18.0), int(32 * k), Color(1, 1, 1, 0.75), 6)
			y += 50.0
		if str(got.get("hat", "")) != "":
			_text("and a ride!" if Cosmetics.kind_of(str(got["hat"])) == "ride" else "and a hat!", Vector2(v.x / 2.0, y), int(58 * k), Color("ffb3d9"), 12)
