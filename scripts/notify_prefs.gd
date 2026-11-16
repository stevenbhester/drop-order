class_name NotifyPrefs
extends CanvasLayer
## "Real quick... what do you want to hear from us?" Asked once, a few jobs after the first daily's solved
## (LEVELS_LATER more: Progress.notify_after; the map asks before the next job's card, LevelSelect.advance),
## so it doesn't pile onto the first daily's score, stats and share. Someone who only plays dailies gets it
## after their third instead. Three ticks, all on to start: the
## streak saver, the fresh-daily nudge, and big news. Saving them asks iOS for permission (Notify writes
## "ask" once any is on); with none ticked it never asks. Under it, in white, "Don't talk to me or my
## notification tray ever again" turns it all off in one go. `closed` when it's done.
## NotifyPrefs.ask_if_needed(parent, then) shows it when it's due, then carries on with `then` either way.

signal closed

## How many more jobs after the first solved daily before it's asked.
const LEVELS_LATER := 3

## [pref field, icon (drawn: emoji don't show on the phone), its colour, what it is, the small print]
const CHOICES := [
	["notify_streak", "flame", "ff7a1a", "Save my streak", "A nudge in the evening if my streak's about to burn out."],
	["notify_fresh", "box", "c98a4b", "New daily's here", "When a fresh daily lands and I've got no streak going."],
	["notify_updates", "megaphone", "4d8dff", "Big news", "Major updates only: new jobs, new rides. Rare."],
]

var _root: Control
var _card: PanelContainer
var _go: JuicyButton
var _on := {"notify_streak": true, "notify_fresh": true, "notify_updates": true}
var _closing := false


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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	_card.add_child(col)
	col.add_child(_label("Real quick…", 64, Palette.TEXT))
	col.add_child(_label("What do you want to hear from us?", 38, Palette.TEXT_SOFT))
	for c in CHOICES:
		col.add_child(_choice(c))
	_go = JuicyButton.new()
	_go.font_px = 46
	_go.bg = Palette.ACCENT
	_go.fg = Color.WHITE
	_go.custom_minimum_size = Vector2(0, 130)
	_go.pressed.connect(_save)
	col.add_child(_go)
	var never := JuicyButton.new()
	never.label = "Don't talk to me or my notification tray ever again"
	never.icon_name = "monkey"
	never.icon_scale = 1.25
	never.font_px = 26
	never.bg = Color.WHITE
	never.fg = Palette.TEXT
	never.custom_minimum_size = Vector2(0, 96)
	never.pressed.connect(func():
		for k in _on:
			_on[k] = false
		_save())
	col.add_child(never)
	_relabel()
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)


func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			Sfx.haptic(8, 0.4)
			box.queue_redraw()
			_relabel())
	return row


func _relabel() -> void:
	var any := false
	for k in _on:
		any = any or _on[k]
	_go.label = "Sounds good" if any else "Nothing, thanks"
	_go.icon_name = "caller" if any else ""
	_go.icon_scale = 1.2
	_go.bg = Palette.ACCENT if any else Color.WHITE
	_go.fg = Color.WHITE if any else Palette.TEXT
	if _go.is_inside_tree():
		_go.restyle()


func _process(_delta: float) -> void:
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.position = (v - sz) / 2.0
	_card.size = sz


## Saves the choices (and so, with any on, the permission prompt comes: Notify).
func _save() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	for k in _on:
		Progress.set(k, _on[k])
	Progress.set_option("notify_chosen", true)
	Notify.refresh(Progress)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())
