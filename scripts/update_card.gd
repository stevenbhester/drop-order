class_name UpdateCard
extends CanvasLayer
## "A new version is out!": offered over the title screen once a launch when TestFlight has a newer build
## (UpdateCheck), and again from the version badge. Shows what's in it and opens TestFlight, or Later.

signal closed

## The newer build, as UpdateCheck read it.
var info: Dictionary = {}

var _root: Control
var _card: PanelContainer
var _van: Van
var _t := 0.0


func _ready() -> void:
	layer = 80
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.62)))
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and not _card.get_global_rect().has_point(e.global_position):
			_later())
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	var vp := _root.get_viewport_rect().size
	var w := minf(900.0, vp.x - 60.0)
	_card.custom_minimum_size = Vector2(w, 0)
	center.add_child(_card)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(64)
	sb.set_content_margin_all(52)
	sb.content_margin_top = 30
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_card.add_child(col)

	# The van, loaded with the new version, driving along a strip of road (its lane marks slide by).
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 210)
	stage.draw.connect(func():
		var cx := stage.size.x / 2.0
		var road := Rect2(cx - 330, 50, 660, 130)
		DrawUtil.rrect(stage, Rect2(road.position + Vector2(0, 8), road.size), Palette.ROAD_EDGE, 65)
		DrawUtil.rrect(stage, road, Palette.ROAD, 65)
		var off := fmod(_t * 260.0, 90.0)
		for i in 9:
			var x := road.position.x + 50 + i * 90 - off
			if x > road.position.x + 30 and x + 44 < road.end.x - 30:
				DrawUtil.rrect(stage, Rect2(x, road.get_center().y - 5, 44, 10), Palette.ROAD_MARK, 5)
		for k in 3:
			var a := fmod(_t * 0.9 + k / 3.0, 1.0)
			Icons.star(stage, Vector2(cx - 200 + k * 200, 40 - 34 * a), 12.0 + 4.0 * (k % 2), Color(Palette.STAR_GOLD, 1.0 - a), _t + k))
	col.add_child(stage)
	# Sideways (a short screen), the card leaves the van out so it fits.
	stage.visible = vp.y >= 1300.0
	_van = Van.new()
	_van.size = 190.0
	stage.add_child(_van)
	_van.set_top("green")
	stage.resized.connect(func(): _van.position = Vector2(stage.size.x / 2.0, 115))

	var title := _label("A new version is out!", 64, Palette.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	col.add_child(_heading())
	var notes: Array = info.get("notes", [])
	for n in notes.slice(0, 3):
		col.add_child(_bullet(str(n)))
	var have := _label("You have v%s (build %d). The new one is waiting in TestFlight: tap Update next to Last Mile." % [Version.NUMBER, Version.BUILD], 32, Palette.TEXT_SOFT)
	have.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(have)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)

	var go := JuicyButton.new()
	go.icon_name = "next"
	go.label = "Update in TestFlight"
	go.font_px = 50
	go.bg = Palette.GOOD
	go.fg = Color.WHITE
	go.custom_minimum_size = Vector2(0, 150)
	go.pressed.connect(_update)
	go.ready.connect(go.breathe.bind(true), CONNECT_DEFERRED)
	col.add_child(go)
	var later := JuicyButton.new()
	later.label = "Later"
	later.font_px = 40
	later.custom_minimum_size = Vector2(0, 104)
	later.pressed.connect(_later)
	col.add_child(later)

	_card.pivot_offset = Vector2(w / 2.0, 500)
	_card.scale = Vector2.ONE * 0.85
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)
	Sfx.haptic(14, 0.6)
	print("[update] offered build %d" % int(info.get("build", 0)))


func _process(delta: float) -> void:
	_t += delta
	if _van:
		_van.rotation = 0.03 * sin(_t * 7.0)
		_van.scale = Vector2.ONE * (1.0 + 0.02 * absf(sin(_t * 3.5)))
		(_van.get_parent() as Control).queue_redraw()


func _label(text: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	return l


## "v0.8  The Long Road", the version in a little pill, centred.
func _heading() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var pill := Control.new()
	pill.custom_minimum_size = Vector2(150, 64)
	var txt := "v" + str(info.get("version", "?"))
	pill.draw.connect(func():
		DrawUtil.rrect(pill, Rect2(Vector2(0, 4), pill.size), Palette.ACCENT.darkened(0.2), 32)
		DrawUtil.rrect(pill, Rect2(Vector2.ZERO, pill.size), Palette.ACCENT, 32)
		var f := UiTheme.font()
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		pill.draw_string(f, Vector2((pill.size.x - tw) / 2.0, 45), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE))
	row.add_child(pill)
	var nm := _label(str(info.get("name", "")), 46, Palette.TEXT)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nm)
	return row


func _bullet(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(36, 40)
	dot.draw.connect(func(): Icons.star(dot, Vector2(18, 24), 12.0, Palette.STAR_GOLD))
	row.add_child(dot)
	var l := _label(text, 34, Palette.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _update() -> void:
	Sfx.play("click")
	UpdateCheck.open_testflight()
	_close()


func _later() -> void:
	Sfx.play("click")
	_close()


func _close() -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE * 0.9, 0.14)
	tw.tween_property(_card, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())
