class_name DailyStats
extends CanvasLayer
## "How everyone did" on day `day`'s daily: today's totals from the server (DailyResults.fetch), on pages
## flipped with arrows or the dots. Each bar chart marks where you landed (YOU).
##   How it went     first try, second, 3-5 tries, last try, didn't finish
##   Today's scores  everyone's winning scores, and the average against yours
##   Solve times     how long the winning try took
##   Badges          how many earned each (rarest first), yours ticked
## Loading, it says so; if the numbers can't be had (offline, or the server's not taking them), it says that.

signal closed

const PAGES := ["How it went", "Today's scores", "Solve times", "Badges"]
const BAR := Color("8b7fd8")
const BAR_SOFT := Color("b7a98f")
const MISS := Color("d98f86")

var day := 0

var _root: Control
var _close: JuicyButton
var _prev: JuicyButton
var _next: JuicyButton
var _page := 0
var _stats := {}
var _state := "loading"      # loading, ready, empty (nobody's in yet), failed
var _t := 0.0
var _closing := false


func _ready() -> void:
	layer = 80
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_card)
	_root.gui_input.connect(_on_input)
	add_child(_root)
	_close = _button("", "x")
	_close.pressed.connect(_on_close)
	_prev = _button("‹", "")
	_prev.font_px = 64
	_prev.pressed.connect(func(): _flip(-1))
	_next = _button("›", "")
	_next.font_px = 64
	_next.pressed.connect(func(): _flip(1))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stats-page="):
			_page = clampi(a.trim_prefix("--stats-page=").to_int(), 0, PAGES.size() - 1)     # (debug: screenshots)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	DailyResults.fetch(_root, day, func(real: Dictionary):
		# (With the thirty simulated drivers' runs added in: DailyResults.with_sim.)
		var d := DailyResults.with_sim(day, real)
		_stats = d
		_state = "failed" if d.is_empty() else ("ready" if int(d.get("players", 0)) > 0 else "empty"))


func _button(text: String, icon: String) -> JuicyButton:
	var b := JuicyButton.new()
	b.label = text
	b.icon_name = icon
	b.size = Vector2(110, 110)
	_root.add_child(b)
	return b


func _flip(by: int) -> void:
	var to := clampi(_page + by, 0, PAGES.size() - 1)
	if to != _page:
		_page = to
		Sfx.play("click", 1.1)


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		# A tap on a dot goes to its page.
		var r := _card_rect()
		var dots_y := r.end.y - 80.0
		for i in PAGES.size():
			var c := Vector2(r.get_center().x + (i - (PAGES.size() - 1) / 2.0) * 44.0, dots_y)
			if e.position.distance_to(c) < 22.0:
				_page = i
				Sfx.play("click", 1.1)


func _on_close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _card_rect() -> Rect2:
	var v := _root.get_viewport_rect().size
	var ins := UiTheme.insets(_root.get_viewport())
	var w := minf(980.0, v.x - 40.0)
	var h := minf(1080.0, v.y - ins.x - ins.y - 80.0)
	return Rect2((v.x - w) / 2.0, ins.x + (v.y - ins.x - ins.y - h) / 2.0, w, h)


func _process(delta: float) -> void:
	_t += delta
	var r := _card_rect()
	_close.position = Vector2(r.end.x - 130.0, r.position.y + 20.0)
	_prev.position = Vector2(r.get_center().x - 260.0, r.end.y - 135.0)
	_next.position = Vector2(r.get_center().x + 150.0, r.end.y - 135.0)
	_prev.visible = _state == "ready"
	_next.visible = _state == "ready"
	_prev.dim = _page == 0
	_next.dim = _page == PAGES.size() - 1
	_root.queue_redraw()


func _text(text: String, at: Vector2, px: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := at.x if align == HORIZONTAL_ALIGNMENT_LEFT else (at.x - w / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else at.x - w)
	_root.draw_string(f, Vector2(x, at.y + px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_card() -> void:
	var v := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.1, 0.08, 0.16, 0.72))
	var r := _card_rect()
	DrawUtil.rrect(_root, Rect2(r.position + Vector2(0, 14), r.size), Color(0, 0, 0, 0.3), 50)
	DrawUtil.rrect(_root, r, Palette.CARD, 50)
	var x0 := r.position.x + 50.0
	var y := r.position.y + 70.0
	_text("HOW EVERYONE DID", Vector2(x0, y), 34, Palette.TEXT)
	_root.draw_line(Vector2(x0, y + 34), Vector2(r.end.x - 50.0, y + 34), Palette.TEXT, 4.0)
	var lv := Daily.puzzle_for(day)
	var sub := "Daily #%d%s" % [Daily.number(day), ("  ·  “%s”" % lv.title) if lv and lv.title != "" else ""]
	if _state == "ready":
		var players := int(_stats.get("players", 0))
		var solved := int(_stats.get("solved", 0))
		sub = "%s players  ·  %d%% solved it" % [Progress.commas(players), roundi(100.0 * solved / maxf(players, 1))]
	_text(sub, Vector2(x0, y + 84), 32, Palette.TEXT_SOFT)
	if _state == "loading":
		_text("Fetching everyone's results" + ".".repeat(int(_t * 3.0) % 4), Vector2(r.get_center().x, r.get_center().y), 38, Palette.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if _state == "empty":
		_text("You're one of the first today!", Vector2(r.get_center().x, r.get_center().y - 30), 40, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_text("Check back later to see how everyone did.", Vector2(r.get_center().x, r.get_center().y + 30), 34, Palette.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if _state == "failed":
		_text("Couldn't get today's numbers just now.", Vector2(r.get_center().x, r.get_center().y - 30), 38, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_text("Try again in a bit.", Vector2(r.get_center().x, r.get_center().y + 30), 34, Palette.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_text(str(PAGES[_page]).to_upper(), Vector2(x0, y + 170), 38, Palette.TEXT_SOFT)
	var top := y + 240.0
	match _page:
		0:
			_page_tries(r, top)
		1:
			_page_scores(r, top)
		2:
			_page_times(r, top)
		3:
			_page_badges(r, top)
	# The dots.
	for i in PAGES.size():
		var c := Vector2(r.get_center().x + (i - (PAGES.size() - 1) / 2.0) * 44.0, r.end.y - 80.0)
		_root.draw_circle(c, 10.0 if i == _page else 8.0, Palette.TEXT if i == _page else Color(Palette.TEXT, 0.2))


## Bars: [[label, count, mine]] as shares of `total`, from `top` down.
func _bars(r: Rect2, top: float, rows: Array, total: int, col: Color, last_col := Color(0, 0, 0, 0)) -> float:
	var lw := 250.0
	var x := r.position.x + 50.0 + lw
	var bw := r.size.x - 100.0 - lw - 230.0
	var y := top
	for i in rows.size():
		var row: Array = rows[i]
		var pct := 100.0 * int(row[1]) / maxf(total, 1)
		_text(str(row[0]), Vector2(x - 24.0, y), 32, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		DrawUtil.rrect(_root, Rect2(x, y - 20, bw, 40), Color(Palette.TEXT, 0.08), 12)
		var c := last_col if (last_col.a > 0.0 and i == rows.size() - 1) else col
		if pct > 0.0:
			DrawUtil.rrect(_root, Rect2(x, y - 20, maxf(bw * pct / 100.0, 18.0), 40), c, 12)
		_text("%d%%" % roundi(pct), Vector2(x + bw + 100.0, y), 32, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		if bool(row[2]):
			DrawUtil.rrect(_root, Rect2(x + bw + 116.0, y - 22, 96, 44), Palette.TEXT, 12)
			_text("YOU", Vector2(x + bw + 164.0, y), 24, Palette.CARD, HORIZONTAL_ALIGNMENT_CENTER)
		y += 76.0
	return y


func _mine() -> Dictionary:
	return Progress.daily_record(day)


func _page_tries(r: Rect2, top: float) -> void:
	var tries: Dictionary = _stats.get("tries", {})
	var players := int(_stats.get("players", 0))
	var solved := int(_stats.get("solved", 0))
	var me := _mine()
	var mine := int(me.get("attempts", 0)) if me.get("done", false) else -1
	var mid := 0
	for k in [3, 4, 5]:
		mid += int(tries.get(str(k), 0))
	var rows := [["First try", int(tries.get("1", 0)), mine == 1], ["Second try", int(tries.get("2", 0)), mine == 2],
		["3 to 5 tries", mid, mine >= 3 and mine <= 5], ["Last try", int(tries.get("6", 0)), mine >= 6],
		["Didn't finish", players - solved, mine < 0 and Daily.out_of_tries(me)]]
	var y := _bars(r, top, rows, players, BAR_SOFT, MISS)
	var first := 100.0 * int(tries.get("1", 0)) / maxf(players, 1)
	_text("%d%% got it first go." % roundi(first), Vector2(r.position.x + 50.0, y + 30.0), 34, Palette.TEXT_SOFT)


func _page_scores(r: Rect2, top: float) -> void:
	var scores: Dictionary = _stats.get("scores", {})
	var solved := int(_stats.get("solved", 0))
	var me := _mine()
	var mine := int(me.get("score", -1)) if me.get("done", false) else -1
	var edges := [0, 125, 150, 175, 200, 250, 100000]
	var names := ["Under 125", "125 to 149", "150 to 174", "175 to 199", "200 to 249", "250+"]
	var rows := []
	for i in names.size():
		var n := 0
		for k in scores:
			if int(k) >= edges[i] and int(k) < edges[i + 1]:
				n += int(scores[k])
		rows.append([names[i], n, mine >= edges[i] and mine < edges[i + 1]])
	var y := _bars(r, top, rows, solved, BAR)
	var avg := int(_stats.get("scoreAvg", 0))
	var line := "Average winning score: %d" % avg
	if mine >= 0:
		line += ". You're %d %s it." % [absi(mine - avg), "above" if mine >= avg else "below"] if mine != avg else ". Bang on it."
	_text(line, Vector2(r.position.x + 50.0, y + 30.0), 32, Palette.TEXT_SOFT)


func _page_times(r: Rect2, top: float) -> void:
	var secs: Dictionary = _stats.get("secs", {})
	var solved := int(_stats.get("solved", 0))
	var me := _mine()
	var mine := float(me.get("time", -1.0)) if me.get("done", false) else -1.0
	var edges := [0, 15, 30, 60, 120, 300, 100000]
	var names := ["Under 15s", "15 to 30s", "30 to 60s", "1 to 2 min", "2 to 5 min", "5+ min"]
	var rows := []
	for i in names.size():
		var n := 0
		for k in secs:
			if int(k) >= edges[i] and int(k) < edges[i + 1]:
				n += int(secs[k])
		rows.append([names[i], n, mine >= edges[i] and mine < edges[i + 1]])
	_bars(r, top, rows, solved, BAR_SOFT)


func _page_badges(r: Rect2, top: float) -> void:
	var counts: Dictionary = _stats.get("badges", {})
	var solved := int(_stats.get("solved", 0))
	var got: Array = _mine().get("badges", [])
	var ids := []
	for id in Daily.BADGES:
		if id != "delivered" and id != "streak" and id != "best" and id != "above":
			ids.append(id)
	ids.sort_custom(func(a, b): return int(counts.get(a, 0)) < int(counts.get(b, 0)))
	var f := UiTheme.font()
	var y := top
	var rarest := ""
	for id in ids:
		var b := Daily.badge(id)
		var pct := 100.0 * int(counts.get(id, 0)) / maxf(solved, 1)
		var mine := got.has(id)
		if mine and rarest == "":
			rarest = id
		var row := Rect2(r.position.x + 50.0, y - 30, r.size.x - 100.0, 60)
		if mine:
			DrawUtil.rrect(_root, row, Color(Palette.GOOD, 0.14), 14)
		Daily.draw_badge_icon(_root, str(b["id"]), Vector2(row.position.x + 34, y), 40.0, _t)
		_root.draw_string(f, Vector2(row.position.x + 70, y + 11), str(b["text"]).get_slice(" (", 0), HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 260, 30, Palette.TEXT)
		_text("%d%%" % roundi(pct), Vector2(row.end.x - 70.0, y), 30, Palette.TEXT_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		if mine:
			var tc := Vector2(row.end.x - 30.0, y)
			_root.draw_polyline(PackedVector2Array([tc + Vector2(-11, 0), tc + Vector2(-3, 9), tc + Vector2(12, -10)]), Palette.GOOD, 6.0, true)
		y += 66.0
	if rarest != "":
		var b := Daily.badge(rarest)
		_text("Your rarest: %s, %d%% got it." % [str(b["text"]).get_slice(" (", 0), roundi(100.0 * int(counts.get(rarest, 0)) / maxf(solved, 1))],
			Vector2(r.position.x + 50.0, y + 16.0), 30, Palette.TEXT_SOFT)
