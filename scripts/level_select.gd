class_name LevelSelect
extends Control
## Scrollable grid of level numbers in sections; completed ones are green.

signal level_chosen(index: int)

const SECTIONS := [
	{"title": "Part 1 · The Suburbs", "from": 1, "to": 20},
	{"title": "Part 2 · The City", "from": 21, "to": 40},
]

var levels: Array = []


func setup(lvls: Array) -> void:
	levels = lvls


func _ready() -> void:
	# Our parent is a plain Node, so anchors alone don't size us: track the viewport.
	_fit()
	get_viewport().size_changed.connect(_fit)
	theme = UiTheme.theme()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_top", 140)
	margin.add_theme_constant_override("margin_bottom", 100)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	margin.add_child(col)

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

	for sec in SECTIONS:
		if sec["from"] > levels.size():
			continue
		var head := Label.new()
		head.text = sec["title"]
		head.add_theme_font_size_override("font_size", 50)
		head.add_theme_color_override("font_color", Palette.TEXT_SOFT)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 26)
		grid.add_theme_constant_override("v_separation", 26)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(grid)
		for i in range(sec["from"] - 1, mini(sec["to"], levels.size())):
			grid.add_child(_level_button(i))
	var reset := Button.new()
	reset.text = "Reset progress"
	reset.add_theme_font_size_override("font_size", 32)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		Progress.reset()
		level_chosen.emit(0))
	col.add_child(reset)

	# Start scrolled to the section holding the next unfinished level.
	if Progress.first_incomplete(levels.size()) >= 20:
		scroll.set_deferred("scroll_vertical", 900)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _level_button(i: int) -> Button:
	var L: LevelData = levels[i]
	var b := Button.new()
	b.text = str(L.number)
	b.custom_minimum_size = Vector2(170, 170)
	b.add_theme_font_size_override("font_size", 64)
	if Progress.is_complete(L.number):
		UiTheme.button_style(b, Palette.GOOD, Color.WHITE)
	b.pressed.connect(func():
		Sfx.play("click")
		level_chosen.emit(i))
	return b

