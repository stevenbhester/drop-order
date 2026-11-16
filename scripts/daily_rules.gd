class_name DailyRules
extends CanvasLayer
## Shown once, at the start of your first daily: how the daily works. One puzzle a day (the same for
## everyone), no hints, Daily.MAX_TRIES tries, and solving it (in however many) keeps the streak.

signal closed

var _root: Control
var _card: PanelContainer
var _closing := false


func _ready() -> void:
	layer = 84
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.6)))
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(56)
	sb.set_content_margin_all(48)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(900.0, _root.get_viewport_rect().size.x - 60.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	_card.add_child(col)
	col.add_child(_label("The Daily", 72, Palette.TEXT, true))
	col.add_child(_row("calendar", "One new puzzle a day. The same one for everyone."))
	col.add_child(_row("bulb", "No hints. Just you and the map."))
	col.add_child(_row("retry", "%d tries a day. Solve it to keep your streak going." % Daily.MAX_TRIES))
	var go := JuicyButton.new()
	go.label = "Let's go"
	go.icon_name = "play"
	go.font_px = 50
	go.bg = Palette.ACCENT
	go.fg = Color.WHITE
	go.custom_minimum_size = Vector2(0, 136)
	go.pressed.connect(_close)
	col.add_child(go)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)


func _label(t: String, px: int, c: Color, centred := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A rule: its icon in a soft circle, and the words.
func _row(icon: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(88, 88)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.draw.connect(func():
		ic.draw_circle(Vector2(44, 44), 44.0, Color(Palette.ACCENT, 0.14))
		Icons.draw(ic, icon, Vector2(44, 44), 54.0, Palette.ACCENT.darkened(0.15)))
	row.add_child(ic)
	var l := _label(text, 38, Palette.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _process(_delta: float) -> void:
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.position = (v - sz) / 2.0
	_card.size = sz


func _close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())
