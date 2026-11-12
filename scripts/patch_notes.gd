class_name PatchNotes
extends CanvasLayer
## What's new: the patch notes card the title screen's version badge opens. The newest release is up top
## in full colour; older ones follow, softer, for anyone scrolling back. Opening it marks the version seen.

signal closed

var _root: Control
var _card: PanelContainer


func _ready() -> void:
	layer = 80
	Progress.see_version(Version.NUMBER)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.62)))
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and not _card.get_global_rect().has_point(e.global_position):
			_close())
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	var vp := _root.get_viewport_rect().size
	_card.custom_minimum_size = Vector2(minf(920.0, vp.x - 60.0), minf(1420.0, vp.y - 120.0))
	center.add_child(_card)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(64)
	sb.set_content_margin_all(48)
	sb.content_margin_top = 40
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_card.add_child(col)
	var head := HBoxContainer.new()
	var title := _label("What's new", 72, Palette.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var done := JuicyButton.new()
	done.label = "Done"
	done.font_px = 42
	done.bg = Palette.GOOD
	done.fg = Color.WHITE
	done.custom_minimum_size = Vector2(220, 104)
	done.pressed.connect(_close)
	head.add_child(done)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for i in Version.NOTES.size():
		var rel: Dictionary = Version.NOTES[i]
		var latest := i == 0
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 26)
			list.add_child(gap)
		list.add_child(_heading(rel, latest))
		for n in rel["notes"]:
			list.add_child(_bullet(n, latest))
	_card.pivot_offset = _card.custom_minimum_size / 2.0
	_card.scale = Vector2.ONE * 0.85
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)


func _label(text: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	return l


## "v0.4  The Chute Update", the version in a little pill.
func _heading(rel: Dictionary, latest: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var pill := Control.new()
	pill.custom_minimum_size = Vector2(150, 64)
	var txt := "v" + str(rel["version"])
	pill.draw.connect(func():
		var bg := Palette.ACCENT if latest else Color(Palette.TEXT, 0.16)
		DrawUtil.rrect(pill, Rect2(Vector2(0, 4), pill.size), bg.darkened(0.2), 32)
		DrawUtil.rrect(pill, Rect2(Vector2.ZERO, pill.size), bg, 32)
		var f := UiTheme.font()
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		pill.draw_string(f, Vector2((pill.size.x - w) / 2.0, 45), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE if latest else Palette.TEXT))
	row.add_child(pill)
	var name := _label(str(rel["name"]), 46 if latest else 40, Palette.TEXT if latest else Palette.TEXT_SOFT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	return row


func _bullet(text: String, latest: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(36, 40)
	dot.draw.connect(func():
		if latest:
			Icons.star(dot, Vector2(18, 24), 12.0, Palette.STAR_GOLD)
		else:
			dot.draw_circle(Vector2(18, 24), 6.0, Color(Palette.TEXT, 0.3)))
	row.add_child(dot)
	var l := _label(text, 36 if latest else 32, Palette.TEXT if latest else Palette.TEXT_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _close() -> void:
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE * 0.9, 0.14)
	tw.tween_property(_card, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())
