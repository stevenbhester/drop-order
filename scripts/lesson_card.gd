class_name LessonCard
extends CanvasLayer
## Job 4's lesson, for when it's gone wrong ("Save the Road": the quick way to the first stop tears up the
## only road to the second). Up comes what just happened, on a little map of the job: the roads driven in
## rubble, the stop that can't be reached any more ringed in red. Then the idea in three short lines (roads
## don't grow back; that drive tore up one you needed; think through every stop first), and two ways on:
## "Try again", or "Show me a hint" (the job restarts with the first stretch of the way that works pointed
## out, free). `chosen(hint)` says which.

signal chosen(hint: bool)

var level: LevelData
var route: Array = []             # the tiles driven, in order
var stranded: Array = []          # indices of the houses still owed a package

var _root: Control
var _card: PanelContainer
var _map: Control
var _t := 0.0
var _done := false


func _ready() -> void:
	layer = 84
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.62)))
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
	_card.custom_minimum_size = Vector2(minf(940.0, _root.get_viewport_rect().size.x - 60.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)
	col.add_child(_label("Roads don't grow back!", 60, Palette.TEXT, true))
	_map = Control.new()
	_map.custom_minimum_size = Vector2(0, 430)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	col.add_child(_map)
	col.add_child(_label(_what_happened(), 40, Palette.ACCENT.darkened(0.15), true))
	col.add_child(_label("Try the long way round.", 34, Palette.TEXT_SOFT, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var again := JuicyButton.new()
	again.label = "Try again"
	again.icon_name = "retry"
	again.font_px = 38
	again.custom_minimum_size = Vector2(0, 124)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_finish.bind(false))
	row.add_child(again)
	var hint := JuicyButton.new()
	hint.label = "Show me a hint"
	hint.icon_name = "bulb"
	hint.font_px = 38
	hint.bg = Palette.ACCENT
	hint.fg = Color.WHITE
	hint.custom_minimum_size = Vector2(0, 124)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_stretch_ratio = 1.3
	hint.pressed.connect(_finish.bind(true))
	row.add_child(hint)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.18)
	Sfx.play("pop", 0.9, -6.0)


## What that drive did, in a line: which stop it cut off.
func _what_happened() -> String:
	if stranded.size() == 1:
		return "Oops. You flattened the only road to the %s stop." % str(level.houses[int(stranded[0])].color)
	return "Oops. You flattened a road you still needed."


func _label(t: String, px: int, c: Color, centred := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _process(delta: float) -> void:
	_t += delta
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.position = (v - sz) / 2.0
	_card.size = sz
	_map.queue_redraw()


## The job, small: grass, its roads, the ones driven in rubble (the van where it stopped), each stop in its
## colour (a tick on the ones delivered, a red ring pulsing round the ones cut off).
func _draw_map() -> void:
	var s := _map.size
	var t := minf(minf(s.x / (level.width + 0.5), s.y / (level.height + 0.2)), 96.0)
	var o := Vector2((s.x - t * level.width) / 2.0, (s.y - t * level.height) / 2.0)
	DrawUtil.rrect(_map, Rect2(o - Vector2(10, 10), Vector2(t * level.width + 20, t * level.height + 20)), Palette.GRASS, 22)
	var driven := {}
	for p in route:
		driven[p] = true
	for y in level.height:
		for x in level.width:
			var p := Vector2i(x, y)
			if not level.is_road(p):
				continue
			var r := Rect2(o + Vector2(x, y) * t, Vector2(t, t)).grow(1.0)
			if driven.has(p) and p != route.back():
				# Torn up: dark, with rubble.
				_map.draw_rect(r, Color("2f2b38"))
				for k in 3:
					var c := r.position + Vector2(fposmod(x * 37.0 + k * 53.0, t * 0.7) + t * 0.15, fposmod(y * 29.0 + k * 41.0, t * 0.7) + t * 0.15)
					_map.draw_rect(Rect2(c - Vector2(t, t) * 0.09, Vector2(t, t) * 0.18), Color("5d5868"))
			else:
				_map.draw_rect(r, Palette.ROAD)
	# The van, where it stopped.
	if not route.is_empty():
		var vc := o + (Vector2(route.back()) + Vector2(0.5, 0.5)) * t
		DrawUtil.rrect(_map, Rect2(vc - Vector2(t, t) * 0.3, Vector2(t, t) * 0.6), Color("fffaf2"), t * 0.14)
		DrawUtil.rrect(_map, Rect2(vc - Vector2(t, t) * 0.18, Vector2(t, t) * 0.36), Color("3b4a6b"), t * 0.08)
	for i in level.houses.size():
		var h = level.houses[i]
		var c := o + (Vector2(h.pos) + Vector2(0.5, 0.5)) * t
		_map.draw_circle(c, t * 0.4, Color.WHITE)
		_map.draw_circle(c, t * 0.33, Palette.pkg(str(h.color)))
		if stranded.has(i):
			var k := fmod(_t * 0.9, 1.0)
			_map.draw_arc(c, t * (0.5 + 0.35 * k), 0, TAU, 32, Color("ff3b30", 1.0 - k), 6.0, true)
			_map.draw_arc(c, t * 0.5, 0, TAU, 32, Color("ff3b30"), 5.0, true)
			var b := c + Vector2(t * 0.36, -t * 0.36)
			_map.draw_circle(b, t * 0.2, Color("ff3b30"))
			_map.draw_line(b + Vector2(-1, -1) * t * 0.09, b + Vector2(1, 1) * t * 0.09, Color.WHITE, 4.0, true)
			_map.draw_line(b + Vector2(1, -1) * t * 0.09, b + Vector2(-1, 1) * t * 0.09, Color.WHITE, 4.0, true)
		else:
			_map.draw_polyline(PackedVector2Array([c + Vector2(-0.14, 0) * t, c + Vector2(-0.04, 0.1) * t, c + Vector2(0.16, -0.12) * t]), Color.WHITE, 5.0, true)


func _finish(hint: bool) -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		chosen.emit(hint)
		queue_free())
