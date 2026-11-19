class_name ShareCard
extends CanvasLayer
## Today's daily result as one tile to show off: the card, and on its foot the two ways to send the emoji
## text (Daily.share_text). "Copy" puts it on the clipboard; "Send" opens the phone's own share sheet
## (ShareSheet: pick an app, or one of the chats iOS suggests), or off the phone falls back to Messages / the
## clipboard. A red X on the tile's corner closes it, as does a tap on the dark round it. The dark is nearly
## solid, so whatever was up before (the score card) doesn't show through.

signal closed

const SIZE := Vector2(900, 1250)

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
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.09, 0.06, 0.14, 1.0)))
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(_root)

	var v := _root.get_viewport_rect().size
	var ins := UiTheme.insets(_root.get_viewport())
	_card = Control.new()
	_card.size = SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.position = Vector2((v.x - SIZE.x) / 2.0, maxf(90.0 + ins.x, ins.x + (v.y - ins.x - ins.y - SIZE.y) / 2.0))
	_card.pivot_offset = _card.size / 2.0
	_card.draw.connect(_draw_card.bind(r))
	_root.add_child(_card)

	# On the tile's foot: Copy and Send.
	var copy := _button("Copy", "", Palette.SURFACE, Palette.TEXT, _copy)
	copy.position = Vector2(40, SIZE.y - 190.0)
	copy.size = Vector2(330, 150)
	_card.add_child(copy)
	var send := _button("Send", "share", Palette.GOOD, Color.WHITE, _send)
	send.position = Vector2(394, SIZE.y - 190.0)
	send.size = Vector2(SIZE.x - 434.0, 150)
	_card.add_child(send)
	var x := CloseX.new()
	x.size = Vector2(116, 116)
	x.position = Vector2(SIZE.x - 92.0, -28.0)
	x.pressed.connect(_close)
	_card.add_child(x)
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


## The phone's share sheet; without one, Messages with it filled in; failing that, the clipboard.
func _send() -> void:
	if ShareSheet.open(_text):
		Sfx.play("click")
		Sfx.haptic(12, 1.0, "share_card:_send")
		return
	DisplayServer.clipboard_set(_text)
	var err := OS.shell_open("sms:&body=" + _text.uri_encode()) if not DebugRemote.on() else ERR_UNAVAILABLE
	_say("Opening Messages…" if err == OK else "Copied! Paste it in a text.")


func _say(msg: String) -> void:
	_toast = msg
	_toast_t = 2.2
	Sfx.play("kaching", 1.2, -6.0)
	Sfx.haptic(12, 1.0, "share_card:_say")
	_fx.burst(_card.position + Vector2(_card.size.x / 2.0, _card.size.y - 260.0), Palette.STAR_GOLD, 16, 700.0, 20.0)


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
	# A row per try: a square per package, lit as far as that try got; a burst where it died, a parcel on the
	# one that made it (Daily.rows: never the colours or the order).
	var rows := Daily.rows(r, 5)
	var band := 210.0
	var row_h := minf(96.0, band / maxf(rows.size(), 1))
	var y0 := 450.0 - row_h * (rows.size() - 1) / 2.0
	for ri in rows.size():
		var row: Array = rows[ri]
		var n := maxi(int(row[1]), 1)
		var sq := minf(row_h - 16.0, (w - 220.0) / n - 10.0)
		var span := n * (sq + 10.0) - 10.0
		var x0 := (w - span - sq - 14.0) / 2.0
		var y := y0 + ri * row_h
		for i in n:
			var k := clampf((_t - ri * 0.18 - i * 0.04) / 0.3, 0.0, 1.0)
			var s := sq * (1.0 + 0.2 * sin(PI * k)) * k
			var lit := i < int(row[0])
			var at := Vector2(x0 + i * (sq + 10.0) + sq / 2.0, y)
			DrawUtil.rrect(c, Rect2(at - Vector2(s, s) / 2.0, Vector2(s, s)), Color("3ed27a") if lit else Color(0.12, 0.08, 0.22, 0.55), s * 0.22)
		var end := Vector2(x0 + span + 14.0 + sq / 2.0, y)
		var ke := clampf((_t - ri * 0.18 - n * 0.04) / 0.3, 0.0, 1.0)
		if bool(row[2]):
			Icons.draw(c, "box", end, sq * 1.1 * ke, Color.WHITE)
		elif ke > 0.0:
			c.draw_colored_polygon(Icons.star_points(end, sq * 0.55 * ke, sq * 0.26 * ke, 0.3), Color("ff5a3c"))
			c.draw_colored_polygon(Icons.star_points(end, sq * 0.3 * ke, sq * 0.14 * ke, 0.3), Color("ffd93d"))
	# Stats.
	var redos := maxi(int(r.get("attempts", 1)) - 1, 0)
	var stat := Daily.clock(float(r.get("time", 0.0)))
	if r.has("score"):
		stat += "   ·   %d points" % int(r["score"])
	elif Daily.untracked(r):
		stat += "   ·   %s" % ("no redos" if redos == 0 else ("1 redo" if redos == 1 else "%d redos" % redos))
	_centered(c, stat, Vector2(w / 2.0, 610), 52, Color.WHITE)
	# The most impressive badge, as a gold pill under it.
	var best := Daily.showoff(r)
	if best != "":
		var b := Daily.badge(best)
		var label := str(b["text"]).get_slice(" (", 0)
		var lw := UiTheme.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 130.0
		DrawUtil.rrect(c, Rect2(w / 2.0 - lw / 2.0, 660, lw, 76), Color("ffd166"), 38)
		Daily.draw_badge_icon(c, best, Vector2(w / 2.0 - lw / 2.0 + 50.0, 698), 54.0, _t)
		_centered(c, label, Vector2(w / 2.0 + 30.0, 698), 44, Color("2b2233"))
	# Streak, in fire.
	var streak := Progress.streak(day)
	if streak > 0:
		var flames := mini(streak, 7)
		for i in flames:
			var fx := w / 2.0 + (i - (flames - 1) / 2.0) * 70.0
			AnimeFire.draw_flame(c, Vector2(fx, 870), 56, 84 + 6.0 * i, _t, i * 1.7, AnimeFire.palette(streak + 2))
		_centered(c, "%d-day streak!" % streak, Vector2(w / 2.0, 925), 58, Color("fff3c4"), 10)
	else:
		_centered(c, "Solve tomorrow's to start a streak", Vector2(w / 2.0, 860), 40, Color(1, 1, 1, 0.8))
	_centered(c, "Think you can beat it?", Vector2(w / 2.0, 1000), 40, Color(1, 1, 1, 0.8))
	if _toast_t > 0.0:
		var a := minf(_toast_t * 3.0, 1.0)
		DrawUtil.rrect(c, Rect2(w / 2.0 - 330, h - 316, 660, 96), Color(Palette.BUBBLE, a), 48)
		_centered(c, _toast, Vector2(w / 2.0, h - 268), 40, Color(Palette.TEXT, a))


func _centered(c: CanvasItem, text: String, at: Vector2, px: int, col: Color, outline := 0) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if outline > 0:
		c.draw_string_outline(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0.3, 0.1, 0.4, 0.6))
	c.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
