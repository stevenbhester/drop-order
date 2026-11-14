class_name OgScreen
extends Control
## The OG 100: the first hundred levels exactly as they were before the level engine redrew the road
## (levels/og.json). An easter egg: its button only shows on the title once all 100 of today's levels are
## beaten. A plain grid of numbers; a tile goes green once that level's been won here. Free to play, and
## nothing in it touches the real road: no gas, no stars, no keys. Nothing tests these levels; if one breaks
## after a rule change, that's allowed.

signal level_chosen(index: int)
signal back_pressed

var levels: Array = []
var _top := 0.0


func setup(lvls: Array) -> void:
	levels = lvls


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	theme = UiTheme.theme()
	_top = UiTheme.insets(get_viewport()).x
	var v := size
	var back := JuicyButton.new()
	back.icon_name = "grid"
	back.size = Vector2(112, 102)
	back.position = Vector2(36, 40 + _top)
	back.pressed.connect(func():
		Sfx.play("click")
		back_pressed.emit())
	add_child(back)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 330 + _top)
	scroll.size = Vector2(v.x - 80, v.y - 330 - _top - 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for i in levels.size():
		var b := JuicyButton.new()
		b.label = str(i + 1)
		b.font_px = 52
		b.custom_minimum_size = Vector2(184, 150)
		if Progress.og_done.has(i + 1):
			b.bg = Palette.GOOD
			b.fg = Color.WHITE
		b.pressed.connect(func():
			Sfx.play("click")
			level_chosen.emit(i))
		grid.add_child(b)


func _draw() -> void:
	var f := UiTheme.font()
	var v := size
	var title := "The OG 100"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	draw_string(f, Vector2((v.x - tw) / 2.0, 120 + _top + 96 * 0.8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Palette.TEXT)
	var done := 0
	for n in Progress.og_done:
		done += 1
	for k in 2:
		var sub: String = ["The original routes, just as they were.", "Free to play. Nothing here counts.  %d / %d" % [done, levels.size()]][k]
		var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(f, Vector2((v.x - sw) / 2.0, 250 + _top + k * 44), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.TEXT_SOFT)
