class_name ShareCard
extends CanvasLayer
## Today's daily result as a card to show off, plus the emoji text to send (Daily.share_text):
## "Copy" puts it on the clipboard, "Text it" opens Messages with it filled in. The text ends by inviting
## whoever gets it to ask for a playtest.

signal closed

var day := -1

var _root: Control
var _card: Control
var _text := ""
var _toast := ""
var _toast_t := 0.0
var _t := 0.0
var _fx: Fx


func _ready() -> void:
	layer = 75
	if day < 0:
		day = Daily.today()
	var r := Progress.daily_record(day)
	_text = Daily.share_text(day, r, Progress.streak(day))
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.12, 0.08, 0.18, 0.75)))
	add_child(_root)

	var v := _root.get_viewport_rect().size
	var top := UiTheme.insets(_root.get_viewport()).x
	_card = Control.new()
	_card.size = Vector2(900, 1080)
	_card.position = Vector2((v.x - 900) / 2.0, maxf(130.0 + top, v.y * 0.42 - 640.0))
	_card.pivot_offset = _card.size / 2.0
	_card.draw.connect(_draw_card.bind(r))
	_root.add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.position = Vector2((v.x - 900) / 2.0, _card.position.y + _card.size.y + 50.0)
	row.size = Vector2(900, 150)
	_root.add_child(row)
	var copy := _button("Copy", "plus", Color.WHITE, Palette.TEXT, _copy)
	copy.icon_name = ""
	row.add_child(copy)
	row.add_child(_button("Text it", "share", Palette.GOOD, Color.WHITE, _text_it))
	var close := Button.new()
	close.text = "Close"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 40)
	close.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	close.position = Vector2((v.x - 300) / 2.0, row.position.y + 175.0)
	close.size = Vector2(300, 80)
	close.pressed.connect(_close)
	_root.add_child(close)
	_fx = Fx.new()
	_root.add_child(_fx)

	_card.scale = Vector2(0.6, 0.6)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	Sfx.play("pop")


func _button(text: String, icon: String, bg: Color, fg: Color, cb: Callable) -> JuicyButton:
	var b := JuicyButton.new()
	b.label = text
	b.icon_name = icon
	b.bg = bg
	b.fg = fg
	b.font_px = 56
	b.custom_minimum_size = Vector2(438, 150)
	b.pressed.connect(cb)
	return b


func _process(delta: float) -> void:
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	_card.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _copy() -> void:
	DisplayServer.clipboard_set(_text)
	_say("Copied! Paste it in a text.")


func _text_it() -> void:
	DisplayServer.clipboard_set(_text)
	var err := OS.shell_open("sms:&body=" + _text.uri_encode())
	_say("Opening Messages…" if err == OK else "Copied! Paste it in a text.")


func _say(msg: String) -> void:
	_toast = msg
	_toast_t = 2.2
	Sfx.play("kaching", 1.2, -6.0)
	Sfx.haptic(12)
	_fx.burst(_card.position + Vector2(_card.size.x / 2.0, _card.size.y), Palette.STAR_GOLD, 16, 700.0, 20.0)


func _close() -> void:
	Sfx.play("click")
	closed.emit()
	queue_free()


func _draw_card(r: Dictionary) -> void:
	var c := _card
	var w := c.size.x
	var h := c.size.y
	var f := UiTheme.font()
	# Card: a bright gradient with a soft shine.
	DrawUtil.rrect(c, Rect2(Vector2(0, 16), c.size), Color(0, 0, 0, 0.3), 70)
	var top := Color("ff6fae")
	var bottom := Color("7b5cff")
	c.draw_polygon(PackedVector2Array([Vector2(60, 0), Vector2(w - 60, 0), Vector2(w, 60), Vector2(w, h - 60), Vector2(w - 60, h), Vector2(60, h), Vector2(0, h - 60), Vector2(0, 60)]),
		PackedColorArray([top, top, top.lerp(bottom, 0.1), top.lerp(bottom, 0.9), bottom, bottom, top.lerp(bottom, 0.9), top.lerp(bottom, 0.1)]))
	for i in 7:
		var a := _t * 0.2 + i * TAU / 7.0
		var p := Vector2(w * 0.5, h * 0.5) + Vector2(cos(a), sin(a)) * Vector2(w * 0.42, h * 0.4)
		c.draw_circle(p, 60.0 + 20.0 * sin(i), Color(1, 1, 1, 0.07))
	_centered(c, "LAST MILE · DAILY", Vector2(w / 2.0, 90), 44, Color(1, 1, 1, 0.85))
	_centered(c, "#%d" % Daily.number(day), Vector2(w / 2.0, 190), 130, Color.WHITE, 16)
	var L := Daily.puzzle_for(day)
	if L and L.title != "":
		_centered(c, "“%s”" % L.title, Vector2(w / 2.0, 290), 46, Color(1, 1, 1, 0.9))
	# Delivery chain: one rounded square per package, in the order delivered.
	var order: Array = r.get("order", [])
	var n := maxi(order.size(), 1)
	var sq := minf(96.0, (w - 120.0) / n - 12.0)
	var x0 := (w - (n * (sq + 12.0) - 12.0)) / 2.0
	for i in order.size():
		var k := clampf((_t - i * 0.06) / 0.3, 0.0, 1.0)
		var s := sq * (1.0 + 0.25 * sin(PI * k)) * k
		var at := Vector2(x0 + i * (sq + 12.0) + sq / 2.0, 410)
		DrawUtil.package(c, at, s, Palette.pkg(str(order[i])), true)
	# Stats.
	var stars := int(r.get("stars", 0))
	for i in 3:
		Icons.star(c, Vector2(w / 2.0 + (i - 1) * 110.0, 560), 46.0, Palette.STAR_GOLD if i < stars else Color(1, 1, 1, 0.25))
	var redos := maxi(int(r.get("attempts", 1)) - 1, 0)
	_centered(c, "⏱  %s      ↻  %s" % [Daily.clock(float(r.get("time", 0.0))), "no redos" if redos == 0 else ("1 redo" if redos == 1 else "%d redos" % redos)], Vector2(w / 2.0, 680), 52, Color.WHITE)
	# Streak, in fire.
	var streak := Progress.streak(day)
	if streak > 0:
		var flames := mini(streak, 7)
		for i in flames:
			var fx := w / 2.0 + (i - (flames - 1) / 2.0) * 70.0
			AnimeFire.draw_flame(c, Vector2(fx, 840), 56, 84 + 6.0 * i, _t, i * 1.7, AnimeFire.palette(streak + 2))
		_centered(c, "%d-day streak!" % streak, Vector2(w / 2.0, 900), 58, Color("fff3c4"), 10)
	else:
		_centered(c, "Solve tomorrow's to start a streak", Vector2(w / 2.0, 860), 40, Color(1, 1, 1, 0.8))
	_centered(c, "Think you can beat it?", Vector2(w / 2.0, 1000), 40, Color(1, 1, 1, 0.8))
	if _toast_t > 0.0:
		var a := minf(_toast_t * 3.0, 1.0)
		DrawUtil.rrect(c, Rect2(w / 2.0 - 330, h - 120, 660, 96), Color(1, 1, 1, a), 48)
		_centered(c, _toast, Vector2(w / 2.0, h - 72), 40, Color(Palette.TEXT, a))


func _centered(c: CanvasItem, text: String, at: Vector2, px: int, col: Color, outline := 0) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if outline > 0:
		c.draw_string_outline(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0.3, 0.1, 0.4, 0.6))
	c.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
