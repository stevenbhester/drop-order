class_name LevelSelect
extends Control
## Grid of level numbers; completed ones are green.

signal level_chosen(index: int)

var levels: Array = []


func setup(lvls: Array) -> void:
	levels = lvls


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 60
	col.offset_right = -60
	col.offset_top = 160
	col.add_theme_constant_override("separation", 30)
	add_child(col)

	var title := Label.new()
	title.text = "Last Mile"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 120)
	col.add_child(title)

	var done := 0
	for L in levels:
		if Progress.is_complete(L.number):
			done += 1
	var sub := Label.new()
	sub.text = "%d / %d delivered" % [done, levels.size()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	col.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	col.add_child(spacer)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 34)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for i in levels.size():
		var L: LevelData = levels[i]
		var b := Button.new()
		b.text = str(L.number)
		b.custom_minimum_size = Vector2(190, 190)
		b.add_theme_font_size_override("font_size", 72)
		if Progress.is_complete(L.number):
			UiTheme.button_style(b, Palette.GOOD, Color.WHITE)
		b.pressed.connect(func():
			Sfx.play("click")
			level_chosen.emit(i))
		grid.add_child(b)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer2)

	var reset := Button.new()
	reset.text = "Reset progress"
	reset.add_theme_font_size_override("font_size", 32)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		Progress.reset()
		level_chosen.emit(0))
	col.add_child(reset)
	var pad := Control.new()
	pad.custom_minimum_size.y = 80
	col.add_child(pad)
