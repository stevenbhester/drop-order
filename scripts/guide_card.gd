class_name GuideCard
extends CanvasLayer
## A nudge on a job that's known to stump people (Game.GUIDE_JOBS: the first boss), once a player's been at it
## half a minute or failed twice: "Sometimes you have to think outside the box… want a hand getting
## started?" `answered(yes)`. Yes: Game shows the first half of the way that works, free.

signal answered(yes: bool)

## Its words (the job 6 guide's, unless set: the Small Tank detour's reminder sets its own).
var icon := "bulb"
var title := "Sometimes you have to think outside the box…"
var body := "Want a hand getting started? I'll show you the first half."
var yes_text := "Yes, show me"
var no_text := "I've got this"

var _root: Control
var _card: PanelContainer
var _closing := false


func _ready() -> void:
	layer = 84
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.55)))
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
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 120)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func():
		var c := Vector2(pic.size.x / 2.0, 60.0)
		pic.draw_circle(c, 58.0, Color(Color("ffc93c"), 0.25))
		Icons.draw(pic, icon, c, 96.0, Palette.TEXT))
	col.add_child(pic)
	col.add_child(_label(title, 52, Palette.TEXT))
	col.add_child(_label(body, 38, Palette.TEXT_SOFT))
	var yes := JuicyButton.new()
	yes.label = yes_text
	yes.font_px = 46
	yes.bg = Palette.GOOD
	yes.fg = Color.WHITE
	yes.custom_minimum_size = Vector2(0, 128)
	yes.pressed.connect(_choose.bind(true))
	col.add_child(yes)
	var no := JuicyButton.new()
	no.label = no_text
	no.font_px = 36
	no.custom_minimum_size = Vector2(0, 100)
	no.pressed.connect(_choose.bind(false))
	col.add_child(no)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.18)
	Sfx.play("sparkle", 1.0, -6.0)


func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _process(_delta: float) -> void:
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.size = sz
	_card.position = (v - sz) / 2.0


func _choose(yes: bool) -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		answered.emit(yes)
		queue_free())
