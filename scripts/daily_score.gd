class_name DailyScore
extends CanvasLayer
## The daily's win: the score, and the badges that made it, dealt in one at a time (Daily.earn /
## Daily.badge). Each slides in with its picture, flashes, and its points pop and roll onto the big number,
## a note higher each time; green ones carry points, gold ones are achievements (a star and a sparkle). When
## the last one's in, the total lands with a flourish. Quick, but each gets its moment (EVERY apart); a tap
## deals the rest at once. Then Share (the game asking you to brag over it, until today's has been shared),
## a big Get back to work (`done_pressed`: back to the map, the card up for the job your van's at) with
## Stats beside it ("How everyone did": DailyStats). A red X on the card's corner is the same way out, there
## from the start. `animate = false` shows it all straight away (opening it again from the daily screen).

signal share_pressed
signal stats_pressed
signal done_pressed

const FIRST_AT := 0.5
const EVERY := 0.36
const GREEN := Color("2f9e63")
const GOLD := Color("e0a420")
const FOOT := 350.0          # room at the card's foot for the buttons

var day := 0
var animate := true

var _root: Control
var _fx: Fx
var _rows: Array = []        # badges, as Daily.badge() gives them
var _score := 0
var _rolled := 0.0           # the number showing, rolling up to what's landed
var _t := 0.0
var _dealt := 0
var _landed := -1.0          # when the total landed (-1: not yet)
var _beg_room := 0.0         # room kept over Share for the brag bubble (decided once: the card never jumps)
var _share: JuicyButton
var _stats: JuicyButton
var _done: JuicyButton
var _x: CloseX
var _buttons_in := false
var _closing := false


func _ready() -> void:
	layer = 72
	var r := Progress.daily_record(day)
	for id in r.get("badges", []):
		_rows.append(Daily.badge(str(id), int(r.get("streak", 0))))
	_score = int(r.get("score", 0))
	_beg_room = 130.0 if not r.get("shared", false) else 0.0
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_card)
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _dealt < _rows.size():
			_root.accept_event()
			_t = FIRST_AT + EVERY * _rows.size())
	add_child(_root)
	_share = _button("Share", "share", Color("4d8dff"), Color.WHITE, 56)
	_share.pressed.connect(func():
		Sfx.play("click")
		Progress.daily_shared(day)
		share_pressed.emit())
	_stats = _button("Stats", "grid", Color.WHITE, Palette.TEXT, 40)
	_stats.pressed.connect(func():
		Sfx.play("click")
		stats_pressed.emit())
	_done = _button("Get back to work", "", Palette.GOOD, Color.WHITE, 50)
	_done.pressed.connect(_close)
	_x = CloseX.new()
	_x.pressed.connect(_close)
	_root.add_child(_x)
	_fx = Fx.new()
	_root.add_child(_fx)
	if not animate:
		_t = FIRST_AT + EVERY * _rows.size() + 0.6
		_dealt = _rows.size()
		_rolled = _score
		_landed = 0.0
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)


func _button(text: String, icon: String, bg: Color, fg: Color, px: int) -> JuicyButton:
	var b := JuicyButton.new()
	b.label = text
	b.icon_name = icon
	b.bg = bg
	b.fg = fg
	b.font_px = px
	b.visible = false
	_root.add_child(b)
	return b


## The card, sized to fit its rows (and the brag bubble's room, kept even once it's gone).
func _layout() -> Dictionary:
	var v := _root.get_viewport_rect().size
	var ins := UiTheme.insets(_root.get_viewport())
	var w := minf(960.0, v.x - 50.0)
	var avail := v.y - ins.x - ins.y - 80.0 - 300.0 - FOOT - _beg_room
	var row_h := clampf(avail / maxf(_rows.size(), 1), 56.0, 86.0)
	var h := 300.0 + row_h * _rows.size() + _beg_room + FOOT
	var top := ins.x + maxf(40.0, (v.y - ins.x - ins.y - h) / 2.0)
	return {"card": Rect2((v.x - w) / 2.0, top, w, h), "row_h": row_h}


## Where row `i` sits, once it's in.
func _row_rect(i: int, L: Dictionary) -> Rect2:
	var card: Rect2 = L["card"]
	var row_h: float = L["row_h"]
	return Rect2(card.position.x + 40.0, card.position.y + 300.0 + i * row_h, card.size.x - 80.0, row_h - 10.0)


func _process(delta: float) -> void:
	if _closing:
		return
	_t += delta
	var L := _layout()
	var card: Rect2 = L["card"]
	var hurried := _t >= FIRST_AT + EVERY * _rows.size() and _dealt < _rows.size() - 1
	while _dealt < _rows.size() and _t >= FIRST_AT + _dealt * EVERY:
		var b: Dictionary = _rows[_dealt]
		var rr := _row_rect(_dealt, L)
		_dealt += 1
		if animate and not hurried:
			# Its moment: a rising note (a chime for a gold one), a tap, a puff of its colour.
			if int(b["pts"]) > 0:
				Sfx.play("pickup", 0.9 + 0.07 * _dealt, -3.0)
				_fx.burst(Vector2(rr.end.x - 60.0, rr.get_center().y), GREEN, 8, 380.0, 12.0)
			else:
				Sfx.play("star", 1.0 + 0.05 * _dealt, -3.0)
				_fx.burst(Vector2(rr.end.x - 46.0, rr.get_center().y), Palette.STAR_GOLD, 14, 520.0, 14.0)
			Sfx.haptic(12, 0.5)
	# The number rolls up to what's landed.
	var landed := 0
	for i in _dealt:
		landed += int(_rows[i]["pts"])
	_rolled = move_toward(_rolled, float(landed), delta * maxf(140.0, (landed - _rolled) * 9.0))
	if _landed < 0.0 and _dealt >= _rows.size() and _rolled >= float(landed) - 0.5 and _t >= FIRST_AT + (_rows.size() - 1) * EVERY + 0.45:
		# The total lands: a flourish.
		_landed = _t
		_rolled = _score
		Sfx.play("kaching", 1.0, -2.0)
		Sfx.play("win", 1.1, -8.0)
		Sfx.haptic(35, 0.9)
		var c := Vector2(card.get_center().x, card.position.y + 190.0)
		_fx.ring(c, Palette.STAR_GOLD, 220.0)
		for col in [Palette.STAR_GOLD, GREEN, Color("4d8dff")]:
			_fx.burst(c, col, 12, 700.0, 16.0)
	if _landed >= 0.0 and not _buttons_in and _t >= _landed + 0.25:
		_buttons_in = true
		for b in [_share, _stats, _done]:
			b.visible = true
			b.scale = Vector2.ZERO if animate else Vector2.ONE
			if animate:
				b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_share.breathe(true)
	# The buttons keep to the card's foot, the X to its corner (wherever the card is).
	var y := card.end.y - FOOT + 30.0
	_share.size = Vector2(card.size.x - 80.0, 140)
	_share.position = Vector2(card.position.x + 40.0, y)
	var sw := floorf((card.size.x - 100.0) * 0.3)
	_stats.size = Vector2(sw, 130)
	_stats.position = Vector2(card.position.x + 40.0, y + 160.0)
	_done.size = Vector2(card.size.x - 100.0 - sw, 130)
	_done.position = Vector2(card.position.x + 60.0 + sw, y + 160.0)
	for b in [_share, _stats, _done]:
		b.pivot_offset = b.size / 2.0
	_x.position = Vector2(card.end.x - _x.size.x + 22.0, card.position.y - 26.0)
	_root.queue_redraw()


func _close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		done_pressed.emit()
		queue_free())


func _text(text: String, at: Vector2, px: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w := -1.0) -> void:
	var f := UiTheme.font()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := at.x - tw / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else (at.x - tw if align == HORIZONTAL_ALIGNMENT_RIGHT else at.x)
	_root.draw_string(f, Vector2(x, at.y + px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, w, px, col)


static func _out_back(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


func _draw_card() -> void:
	var v := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.1, 0.08, 0.16, 0.7))
	var L := _layout()
	var card: Rect2 = L["card"]
	var row_h: float = L["row_h"]
	DrawUtil.rrect(_root, Rect2(card.position + Vector2(0, 14), card.size), Color(0, 0, 0, 0.3), 56)
	DrawUtil.rrect(_root, card, Palette.CARD, 56)
	var cx := card.get_center().x
	var lv := Daily.puzzle_for(day)
	_text("DAILY #%d%s" % [Daily.number(day), ("  ·  “%s”" % lv.title) if lv and lv.title != "" else ""], Vector2(cx, card.position.y + 60.0), 32, Palette.TEXT_SOFT)
	# The score: it jumps a little as each badge lands, and pops (and turns gold) when the total's in.
	var bump := 1.0
	if _landed >= 0.0:
		bump = 1.0 + (0.3 * clampf(1.0 - (_t - _landed) / 0.3, 0.0, 1.0) if animate else 0.0)
	elif _dealt > 0:
		bump = 1.0 + 0.14 * clampf(1.0 - (_t - FIRST_AT - (_dealt - 1) * EVERY) / 0.16, 0.0, 1.0)
	var f := UiTheme.font()
	var px := int(150 * bump)
	var num := str(int(round(_rolled)))
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_string(f, Vector2(cx - nw / 2.0, card.position.y + 200.0 + px * 0.3), num, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		GOLD.darkened(0.12) if _landed >= 0.0 else Palette.TEXT)
	_text("points", Vector2(cx, card.position.y + 268.0), 30, Palette.TEXT_SOFT)
	# The rows: each overshoots in from the right, flashes white, and its points pop.
	for i in _dealt:
		var b: Dictionary = _rows[i]
		var age := (_t - FIRST_AT - i * EVERY) if animate else 9.0
		var e := _out_back(age / 0.22)
		var gold := int(b["pts"]) == 0
		var col := GOLD if gold else GREEN
		var r := _row_rect(i, L)
		r.position.x += (1.0 - e) * 420.0
		DrawUtil.rrect(_root, r, Color(col, 0.13), 20)
		DrawUtil.rrect(_root, Rect2(r.position, Vector2(10, r.size.y)), col, 6)
		var mid := r.position.y + r.size.y / 2.0
		var tpx := int(clampf(row_h * 0.4, 24.0, 34.0))
		Daily.draw_badge_icon(_root, str(b["id"]), Vector2(r.position.x + 56.0, mid), minf(r.size.y - 18.0, 56.0), _t)
		_root.draw_string(f, Vector2(r.position.x + 100.0, mid + tpx * 0.36), str(b["text"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 230.0, tpx, Palette.TEXT)
		var pop := (1.0 + 0.7 * clampf(1.0 - (age - 0.1) / 0.22, 0.0, 1.0)) if age > 0.1 else 0.0
		if pop > 0.0 and not gold:
			_text("+%d" % int(b["pts"]), Vector2(r.end.x - 26.0, mid), int((tpx + 4) * pop), col, HORIZONTAL_ALIGNMENT_RIGHT)
		elif pop > 0.0:
			Icons.star(_root, Vector2(r.end.x - 46.0, mid), 18.0 * pop, GOLD, age * 3.0 if age < 0.5 else 0.0)
		var flash := clampf(1.0 - age / 0.3, 0.0, 1.0)
		if flash > 0.0:
			DrawUtil.rrect(_root, r, Color(1, 1, 1, 0.75 * flash), 20)
	# Not shared yet today: the game, asking you to brag, over Share.
	if _buttons_in and not Progress.daily_record(day).get("shared", false):
		Daily.draw_beg(_root, _share.position + Vector2(_share.size.x / 2.0, 0), Daily.beg(day), _t, clampf((_t - _landed - 0.6) / 0.3, 0.0, 1.0) if animate else 1.0)
