class_name DailyIntro
extends CanvasLayer
## The daily, just unlocked: the map goes dim except the ribbon (`ribbon`, followed as it's placed), a ring pulses round
## it, and a card hanging under it with an arrow up at it says what the daily is. "Try it" or "Later";
## `closed(tried)` says which.

signal closed(tried: bool)

var ribbon: DailyRibbon
var target := Rect2()

var _root: Control
var _card: PanelContainer
var _t := 0.0
var _done := false


func _ready() -> void:
	layer = 75
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_dim)
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(44)
	sb.set_content_margin_all(40)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 24
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	var v := _root.get_viewport_rect().size
	_card.custom_minimum_size = Vector2(minf(820.0, v.x - 60.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)
	col.add_child(_label("NEW!  THE DAILY", 34, Palette.ACCENT))
	col.add_child(_label("One new puzzle a day. Everyone gets the same one.", 40, Palette.TEXT))
	col.add_child(_label("Six tries, no hints. Solve it every day to build a streak.", 32, Palette.TEXT_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var later := JuicyButton.new()
	later.label = "Later"
	later.font_px = 38
	later.custom_minimum_size = Vector2(0, 120)
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	later.pressed.connect(_finish.bind(false))
	row.add_child(later)
	var go := JuicyButton.new()
	go.label = "Try it"
	go.icon_name = "play"
	go.font_px = 44
	go.bg = Palette.ACCENT
	go.fg = Color.WHITE
	go.custom_minimum_size = Vector2(0, 120)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_finish.bind(true))
	go.ready.connect(go.breathe.bind(true), CONNECT_DEFERRED)
	row.add_child(go)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)
	Sfx.play("sparkle", 1.0, -4.0)
	Sfx.play("pop", 1.1, -6.0)


func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _process(delta: float) -> void:
	_t += delta
	if ribbon and is_instance_valid(ribbon):
		target = Rect2(ribbon.global_position, Vector2(ribbon.size.x, DailyRibbon.H))
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.size = sz
	_card.position = Vector2(clampf(target.get_center().x - sz.x * 0.75, 30.0, v.x - sz.x - 30.0), target.end.y + 60.0)
	_root.queue_redraw()


## Dark everywhere but round the ribbon, a ring pulsing on it, and the card's arrow up at it.
func _draw_dim() -> void:
	var v := _root.size
	var hole := target.grow(18.0)
	var dim := Color(0.08, 0.06, 0.14, 0.72)
	_root.draw_rect(Rect2(0, 0, v.x, hole.position.y), dim)
	_root.draw_rect(Rect2(0, hole.end.y, v.x, v.y - hole.end.y), dim)
	_root.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), dim)
	_root.draw_rect(Rect2(hole.end.x, hole.position.y, v.x - hole.end.x, hole.size.y), dim)
	var k := fmod(_t * 0.9, 1.0)
	var c := target.get_center()
	_root.draw_arc(c, 100.0 + 50.0 * k, 0, TAU, 48, Color(1, 0.85, 0.3, 0.9 * (1.0 - k)), 8.0, true)
	var tip := Vector2(target.get_center().x, target.end.y + 22.0)
	_root.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-26, 40), tip + Vector2(26, 40)]), Palette.CARD)


func _finish(tried: bool) -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit(tried)
		queue_free())
