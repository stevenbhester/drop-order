class_name RatePrompt
extends CanvasLayer
## Asked once, after the fifth level: "Want to rate levels as you go?" Yes turns the Rate levels option on
## (Rating); either answer is remembered, and the option stays in Options for a change of mind.

signal answered(yes: bool)

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
	sb.set_content_margin_all(44)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(900.0, _root.get_viewport_rect().size.x - 60.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	_card.add_child(col)
	col.add_child(_label("Help shape the jobs?", 60, Palette.TEXT))
	col.add_child(_label("After each job, a quick card: a few stars, a tap or two, done in five seconds. It goes to Steven with how the job went for you (no name, nothing about you).", 34, Palette.TEXT_SOFT))
	col.add_child(_label("You can turn it off in Options any time.", 30, Palette.TEXT_SOFT))
	var yes := JuicyButton.new()
	yes.label = "Yes, I'll rate them"
	yes.icon_name = "star"
	yes.font_px = 46
	yes.bg = Palette.ACCENT
	yes.fg = Color.WHITE
	yes.custom_minimum_size = Vector2(0, 128)
	yes.pressed.connect(_answer.bind(true))
	col.add_child(yes)
	var no := JuicyButton.new()
	no.label = "Not now"
	no.font_px = 38
	no.custom_minimum_size = Vector2(0, 100)
	no.pressed.connect(_answer.bind(false))
	col.add_child(no)
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


func _process(_delta: float) -> void:
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.position = (v - sz) / 2.0
	_card.size = sz


func _answer(yes: bool) -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click", 1.1 if yes else 0.9)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		answered.emit(yes)
		queue_free())
