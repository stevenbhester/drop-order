class_name NotifyPrefs
extends CanvasLayer
## "Real quick... what do you want to hear from us?" Asked once, a few jobs after the first daily's solved
## (LEVELS_LATER more: Progress.notify_after; the map asks before the next job's card, LevelSelect.advance),
## so it doesn't pile onto the first daily's score, stats and share. Someone who only plays dailies gets it
## after their third instead. Three ticks, all on to start: the streak saver, the fresh-daily nudge, and big
## news. Saving them asks iOS for permission (Notify writes "ask" once any is on); with none ticked it never
## asks.
##
## Saying no to everything (all three unticked, or "Don't talk to me or my notification tray ever again")
## doesn't just close: the card turns to a second page, where the van takes it badly. "Got it..." and where
## to find this again, one loud button back to the game, and a quiet link under it for a change of heart
## (back to the ticks).
##
## The same card is "Notifications" in Options (`from_options`): it opens on what's set now. `closed` when
## it's done. NotifyPrefs.ask_if_needed(parent, then) shows it when it's due, then carries on with `then`.

signal closed

## How many more jobs after the first solved daily before it's asked.
const LEVELS_LATER := 3

## [pref field, icon (drawn: emoji don't show on the phone), its colour, what it is, the small print]
const CHOICES := [
	["notify_streak", "flame", "ff7a1a", "Save my streak", "A nudge in the evening if my streak's about to burn out."],
	["notify_fresh", "box", "c98a4b", "New daily's here", "When a fresh daily lands and I've got no streak going."],
	["notify_updates", "megaphone", "4d8dff", "Big news", "Major updates only: new jobs, new rides. Rare."],
]

## Opened from Options: it shows what's set now, under a plainer heading.
var from_options := false

var _root: Control
var _card: PanelContainer
var _col: VBoxContainer
var _go: JuicyButton
var _on := {"notify_streak": true, "notify_fresh": true, "notify_updates": true}
var _closing := false
var _t := 0.0
var _sad: Control


## Whether it's time to ask: not chosen yet, a daily's been solved, and LEVELS_LATER jobs done since (or,
## `after_daily`, this is their third daily solved).
static func due(after_daily := false) -> bool:
	if OS.get_cmdline_user_args().has("--notify-prefs"):
		return not Progress.notify_chosen
	if Progress.notify_chosen or Progress.auto or Progress.notify_after < 0:
		return false
	if Progress.completed.size() >= Progress.notify_after:
		return true
	if not after_daily:
		return false
	var solved := 0
	for k in Progress.daily:
		if Progress.daily[k] is Dictionary and Progress.daily[k].get("done", false):
			solved += 1
	return solved >= 3


## Shows the card if it's due (see due()), then calls `then`.
static func ask_if_needed(parent: Node, then: Callable, after_daily := false) -> void:
	if not due(after_daily):
		then.call()
		return
	var card := NotifyPrefs.new()
	parent.add_child(card)
	card.closed.connect(then)


func _ready() -> void:
	layer = 86
	if from_options and Progress.notify_chosen:
		for k in _on:
			_on[k] = bool(Progress.get(k))
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.65)))
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(56)
	sb.set_content_margin_all(46)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(920.0, _root.get_viewport_rect().size.x - 60.0), 0)
	_root.add_child(_card)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 24)
	_card.add_child(_col)
	_build_choices()
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)
	if OS.get_cmdline_user_args().has("--notify-sad"):
		_show_sad.call_deferred()          # (debug: straight to the second page, for screenshots)


func _clear() -> void:
	_sad = null
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()


## The first page: the three ticks, the button that saves them, and the one that turns it all off.
func _build_choices() -> void:
	_clear()
	_col.add_child(_label("Notifications" if from_options else "Real quick…", 64, Palette.TEXT))
	_col.add_child(_label("What do you want to hear from us?", 38, Palette.TEXT_SOFT))
	for c in CHOICES:
		_col.add_child(_choice(c))
	_go = JuicyButton.new()
	_go.font_px = 46
	_go.bg = Palette.ACCENT
	_go.fg = Color.WHITE
	_go.custom_minimum_size = Vector2(0, 130)
	_go.pressed.connect(_save)
	_col.add_child(_go)
	var never := JuicyButton.new()
	never.label = "Don't talk to me or my notification tray ever again"
	never.icon_name = "monkey"
	never.icon_scale = 1.25
	never.font_px = 26
	never.bg = Palette.SURFACE
	never.fg = Palette.TEXT
	never.custom_minimum_size = Vector2(0, 96)
	never.pressed.connect(func():
		for k in _on:
			_on[k] = false
		_save())
	_col.add_child(never)
	_relabel()


func _label(t: String, px: int, c: Color, centred := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One tickable row: the box, its picture, the name and its small print. A tap anywhere on it flips it.
func _choice(c: Array) -> Control:
	var key: String = c[0]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := Control.new()
	box.custom_minimum_size = Vector2(64, 64)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func():
		var on: bool = _on[key]
		DrawUtil.rrect(box, Rect2(Vector2.ZERO, box.size), Palette.GOOD if on else Color(Palette.TEXT, 0.12), 16)
		if on:
			box.draw_polyline(PackedVector2Array([Vector2(16, 33), Vector2(28, 45), Vector2(49, 20)]), Color.WHITE, 8.0, true))
	row.add_child(box)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(64, 64)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func(): Icons.draw(pic, str(c[1]), pic.size / 2.0, 58.0, Color(str(c[2]))))
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := _label(str(c[3]), 40, Palette.TEXT)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var small := _label(str(c[4]), 30, Palette.TEXT_SOFT)
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name)
	words.add_child(small)
	row.add_child(words)
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			row.accept_event()
			_on[key] = not _on[key]
			Sfx.play("tick", 1.2 if _on[key] else 0.9, -6.0)
			Sfx.haptic(8, 0.4, "notify_prefs:_choice")
			box.queue_redraw()
			_relabel())
	return row


func _relabel() -> void:
	var any := false
	for k in _on:
		any = any or _on[k]
	_go.label = ("Save" if from_options else "Sounds good") if any else "Nothing, thanks"
	_go.icon_name = "caller" if any else ""
	_go.icon_scale = 1.2
	_go.bg = Palette.ACCENT if any else Palette.SURFACE
	_go.fg = Color.WHITE if any else Palette.TEXT
	if _go.is_inside_tree():
		_go.restyle()


func _process(delta: float) -> void:
	_t += delta
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.position = (v - sz) / 2.0
	_card.size = sz
	if is_instance_valid(_sad):
		_sad.queue_redraw()


## Saves the choices (and so, with any on, the permission prompt comes: Notify). With none on, it isn't over
## yet: the second page.
func _save() -> void:
	if _closing:
		return
	Sfx.play("click")
	var any := false
	for k in _on:
		Progress.set(k, _on[k])
		any = any or _on[k]
	Progress.set_option("notify_chosen", true)
	Notify.refresh(Progress)
	if any:
		_finish()
	else:
		_show_sad()


func _finish() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


## The second page: everything's off, and the van's not taking it well.
func _show_sad() -> void:
	_clear()
	Sfx.play("fail", 0.8, -10.0)
	_sad = Control.new()
	_sad.custom_minimum_size = Vector2(0, 360)
	_sad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sad.draw.connect(_draw_sad)
	_col.add_child(_sad)
	_col.add_child(_label("Got it…", 68, Palette.TEXT, true))
	_col.add_child(_label("We won't bother you. Not a peep.", 40, Palette.TEXT, true))
	_col.add_child(_label("If you change your mind, it's under Notifications in Options.", 30, Palette.TEXT_SOFT, true))
	var back := JuicyButton.new()
	back.label = "QUIET, YOU! BACK TO THE GAME!"
	back.font_px = 40
	back.bg = Palette.ACCENT
	back.fg = Color.WHITE
	back.custom_minimum_size = Vector2(0, 140)
	back.pressed.connect(func():
		Sfx.play("click")
		_finish())
	_col.add_child(back)
	# Quietly, under it: a change of heart goes back to the ticks.
	var wait := Button.new()
	wait.text = "Wait, I've changed my mind"
	wait.flat = true
	wait.focus_mode = Control.FOCUS_NONE
	wait.add_theme_font_size_override("font_size", 30)
	wait.add_theme_color_override("font_color", Color(Palette.TEXT_SOFT, 0.85))
	wait.add_theme_color_override("font_pressed_color", Palette.ACCENT)
	wait.add_theme_color_override("font_hover_color", Palette.TEXT)
	wait.custom_minimum_size = Vector2(0, 70)
	wait.pressed.connect(func():
		Sfx.play("click")
		for k in _on:
			_on[k] = true
		_build_choices())
	_col.add_child(wait)


## The van, head on, taking it like a kicked puppy: big wet headlight eyes looking up, brows knotted, a
## wobbling lip of a bumper, a tear that wells and drops into a little puddle, and a small rain cloud all of
## its own.
func _draw_sad() -> void:
	var s := _sad.size
	var c := Vector2(s.x / 2.0, s.y * 0.58 + 3.0 * sin(_t * 2.2))
	var body := Color("fffaf2")
	var ink := Color("2b2233")
	# Its own little cloud, raining on it.
	var cl := Vector2(s.x / 2.0 + 14.0 * sin(_t * 0.7), 44.0)
	for p in [Vector2(-52, 8), Vector2(-14, -12), Vector2(30, -4), Vector2(62, 10), Vector2(6, 14)]:
		_sad.draw_circle(cl + p, 34.0, Color("9aa1b4"))
	for i in 5:
		var k := fmod(_t * 0.9 + i * 0.23, 1.0)
		var rp := cl + Vector2(-70.0 + i * 36.0, 44.0 + 110.0 * k)
		_sad.draw_line(rp, rp + Vector2(-4, 18), Color(0.45, 0.62, 0.9, 0.7 * (1.0 - k)), 5.0, true)
	# Shadow, wheels, body, roof.
	_sad.draw_circle(c + Vector2(0, 118), 4.0, Color(0, 0, 0, 0.0))
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-150, 96), Vector2(300, 26)), Color(0, 0, 0, 0.12), 13)
	for wx in [-104.0, 104.0]:
		DrawUtil.rrect(_sad, Rect2(c + Vector2(wx - 30, 62), Vector2(60, 50)), ink, 14)
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-140, -40), Vector2(280, 134)), body.darkened(0.12), 40)
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-140, -46), Vector2(280, 134)), body, 40)
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-112, -112), Vector2(224, 96)), body.darkened(0.06), 34)
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-92, -98), Vector2(184, 62)), Color("3b4a6b"), 22)
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-80, -92), Vector2(70, 14)), Color(1, 1, 1, 0.18), 7)
	# The eyes: headlights, huge and wet, looking up at you.
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(72.0 * sx, 8)
		_sad.draw_circle(e, 46.0, ink)
		_sad.draw_circle(e, 40.0, Color.WHITE)
		_sad.draw_circle(e + Vector2(-4.0 * sx, -8), 25.0, Color("4a3323"))
		_sad.draw_circle(e + Vector2(-4.0 * sx, -8), 14.0, ink)
		_sad.draw_circle(e + Vector2(-12, -20), 9.0, Color.WHITE)
		_sad.draw_circle(e + Vector2(8, -2), 5.0, Color(1, 1, 1, 0.9))
		# Wet along the bottom lid, and a brow knotted up in the middle.
		_sad.draw_arc(e, 37.0, 0.15 * PI, 0.85 * PI, 16, Color(0.6, 0.78, 1.0, 0.75), 7.0, true)
		_sad.draw_line(e + Vector2(-40.0 * sx, -80), e + Vector2(30.0 * sx, -54), ink, 11.0, true)
	# The lip: a bumper, wobbling.
	var lip := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		lip.append(c + Vector2(-34.0 + 68.0 * u, 62.0 - 14.0 * sin(PI * u) + 2.5 * sin(_t * 18.0 + u * 9.0)))
	_sad.draw_polyline(lip, ink, 9.0, true)
	# One tear, welling under the left eye and dropping into its puddle.
	var k := fmod(_t / 1.9, 1.0)
	var grow := clampf(k / 0.45, 0.0, 1.0)
	var fall := clampf((k - 0.45) / 0.4, 0.0, 1.0)
	var tp := c + Vector2(-96, 44 + 70.0 * fall * fall)
	var tear := Color(0.45, 0.68, 1.0, 0.95 * (1.0 - clampf((k - 0.85) / 0.1, 0.0, 1.0)))
	_sad.draw_circle(tp, 11.0 * grow, tear)
	_sad.draw_colored_polygon(PackedVector2Array([tp + Vector2(-9.5 * grow, -4), tp + Vector2(0, -24.0 * grow), tp + Vector2(9.5 * grow, -4)]), tear)
	DrawUtil.rrect(_sad, Rect2(c + Vector2(-134, 108), Vector2(76, 12)), Color(0.45, 0.68, 1.0, 0.55), 6)
