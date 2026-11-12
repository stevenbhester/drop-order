class_name DailyScreen
extends Control
## Today's puzzle: its number and name, the streak (in fire), the last week as a row of days, and Play (one
## gas tank, refunded when you solve it) or Share once it's done. A day counts toward the streak if it's
## solved with at most Daily.MAX_REDOS redos.

signal play_pressed
signal back_pressed

var _t := 0.0
var _play: JuicyButton
var _share: JuicyButton
var _modal: Node
var _day := 0
var _top := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	theme = UiTheme.theme()
	_day = Daily.today()
	_top = UiTheme.insets(get_viewport()).x
	var v := size

	var bar := HBoxContainer.new()
	bar.position = Vector2(36, 40 + _top)
	bar.size = Vector2(v.x - 72, 110)
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	var back := JuicyButton.new()
	back.icon_name = "grid"
	back.custom_minimum_size = Vector2(112, 102)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func():
		Sfx.play("click")
		back_pressed.emit())
	bar.add_child(back)
	var gas := GasChip.new()
	gas.shop_requested.connect(_open_shop)
	bar.add_child(gas)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(CoinChip.new())

	var r := Progress.daily_record(_day)
	var done: bool = r.get("done", false)
	_play = JuicyButton.new()
	_play.font_px = 72
	_play.bg = Palette.ACCENT if not done else Color.WHITE
	_play.fg = Color.WHITE if not done else Palette.TEXT
	_play.label = "Play" if int(r.get("attempts", 0)) == 0 else ("Play again" if done else "Keep going")
	_play.icon_name = "play"
	if not done:
		_play.badge = "1"
		_play.badge_icon = "gas"
		_play.badge_color = GasChip.FUEL
	_play.size = Vector2(620, 170)
	_play.position = Vector2((v.x - 620) / 2.0, v.y * 0.62)
	_play.pressed.connect(func():
		Sfx.play("click")
		play_pressed.emit())
	add_child(_play)
	if done:
		_share = JuicyButton.new()
		_share.font_px = 72
		_share.bg = Color("4d8dff")
		_share.fg = Color.WHITE
		_share.label = "Share"
		_share.icon_name = "share"
		_share.size = Vector2(620, 170)
		_share.position = Vector2((v.x - 620) / 2.0, v.y * 0.62)
		_share.pressed.connect(_open_share)
		add_child(_share)
		_play.position.y += 200.0
		_play.size = Vector2(620, 130)
		_play.font_px = 52
	else:
		_play.ready.connect(_play.breathe.bind(true), CONNECT_DEFERRED)
	if done and OS.get_cmdline_user_args().has("--share"):
		_open_share.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _open_shop() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	_modal = GasShop.new()
	add_child(_modal)


func _open_share() -> void:
	Sfx.play("click")
	if _modal != null and is_instance_valid(_modal):
		return
	var card := ShareCard.new()
	card.day = _day
	_modal = card
	add_child(card)


func _text(text: String, at: Vector2, px: int, col: Color, outline := 0) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if outline > 0:
		draw_string_outline(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color.WHITE)
	draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw() -> void:
	var v := size
	var cx := v.x / 2.0
	var y0 := 230.0 + _top
	var L := Daily.puzzle_for(_day)
	var r := Progress.daily_record(_day)
	_text("DAILY PUZZLE", Vector2(cx, y0), 46, Palette.TEXT_SOFT)
	_text("#%d" % Daily.number(_day), Vector2(cx, y0 + 120), 170, Palette.TEXT, 14)
	if L:
		_text("“%s”" % L.title, Vector2(cx, y0 + 250), 54, Palette.TEXT)
		_text("%d × %d · %d packages" % [L.width, L.height, L.total_orders()], Vector2(cx, y0 + 320), 38, Palette.TEXT_SOFT)

	# Streak, with fire that grows with it.
	var streak := Progress.streak(_day)
	var sy := y0 + 520.0
	var flames := clampi(streak, 1, 7)
	for i in flames:
		var x := cx + (i - (flames - 1) / 2.0) * 84.0
		if streak > 0:
			AnimeFire.draw_flame(self, Vector2(x, sy + 30), 70, 110 + 8.0 * i + 10.0 * sin(_t * 3.0 + i), _t, i * 1.3, AnimeFire.palette(streak + 2))
		else:
			AnimeFire.draw_flame(self, Vector2(x, sy + 30), 70, 90, _t, 0.0, [Color(Palette.TEXT, 0.12), Color(Palette.TEXT, 0.08)])
	_text("%d-day streak" % streak if streak != 1 else "1-day streak", Vector2(cx, sy + 100), 60, Palette.TEXT, 10)
	var note := "Best: %d" % Progress.best_streak
	var redos := int(r.get("attempts", 0)) - 1
	if r.get("done", false):
		note = "Solved today%s! Come back tomorrow." % ("" if r.get("ok", false) else " (too many redos for the streak)")
	elif redos >= Daily.MAX_REDOS + 1:
		note = "Over %d redo today: no streak this time." % Daily.MAX_REDOS
	elif redos == Daily.MAX_REDOS:
		note = "Last redo used: this one counts!"
	else:
		note = "Solve it with no more than %d redo to keep the streak." % Daily.MAX_REDOS
	_text(note, Vector2(cx, sy + 170), 36, Palette.TEXT_SOFT)

	# The last seven days.
	var dy := sy + 280.0
	for i in 7:
		var day := _day - 6 + i
		var x := cx + (i - 3) * 120.0
		var rec := Progress.daily_record(day)
		var col := Color(Palette.TEXT, 0.1)
		if rec.get("ok", false):
			col = Palette.GOOD
		elif rec.get("done", false):
			col = Palette.STAR_GOLD
		DrawUtil.rrect(self, Rect2(x - 46, dy - 46, 92, 92), col, 26)
		if day == _day:
			draw_arc(Vector2(x, dy), 60, 0, TAU, 40, Palette.ACCENT, 6.0, true)
		if rec.get("ok", false):
			Icons.star(self, Vector2(x, dy), 26.0, Color.WHITE)
		var label := Daily.key(day).substr(8, 2)
		var f := UiTheme.font()
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(f, Vector2(x - w / 2.0, dy + 90), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.TEXT_SOFT)
