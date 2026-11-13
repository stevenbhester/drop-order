class_name SpeedrunScreen
extends Control
## Speedrun: the three courses as cards (name, a line about it, its zones as a little grid, the best time)
## with a GO on each. A course runs its zones back to back against the clock.

signal course_chosen(id: String)
signal back_pressed

var _top := 0.0


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
	var col := VBoxContainer.new()
	col.position = Vector2(48, 330 + _top)
	col.size = Vector2(v.x - 96, v.y - 360 - _top)
	col.add_theme_constant_override("separation", 34)
	add_child(col)
	for d in Speedrun.defs():
		col.add_child(_card(d))


func _card(d: Dictionary) -> Control:
	var id := str(d.get("id", ""))
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 300)
	var go := JuicyButton.new()
	go.label = "GO"
	go.icon_name = "play"
	go.font_px = 48
	go.bg = Palette.ACCENT
	go.fg = Color.WHITE
	go.size = Vector2(230, 120)
	go.anchor_left = 1.0
	go.anchor_right = 1.0
	go.position = Vector2(-260, 150)
	go.pressed.connect(func():
		Sfx.play("click")
		course_chosen.emit(id))
	c.add_child(go)
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		DrawUtil.rrect(c, Rect2(r.position + Vector2(0, 10), r.size), Color(0, 0, 0, 0.12), 44)
		DrawUtil.rrect(c, r, Palette.SURFACE, 44)
		var f := UiTheme.font()
		c.draw_string(f, Vector2(40, 82), str(d.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 58, Palette.TEXT)
		c.draw_string(f, Vector2(40, 132), str(d.get("theme", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 32, Palette.TEXT_SOFT)
		# Its zones as a little grid.
		var grid: Array = d.get("grid", [3, 1])
		var parts: Array = d.get("parts", [])
		var cell := 24.0
		for k in parts.size():
			var at: Array = parts[k].get("at", [k, 0])
			DrawUtil.rrect(c, Rect2(Vector2(40, 158) + Vector2(at[0], at[1]) * (cell + 6.0), Vector2(cell, cell)), Palette.ACCENT if k == 0 else Color(Palette.TEXT, 0.16), 6)
		c.draw_string(f, Vector2(40 + grid[0] * (cell + 6.0) + 14.0, 182), "%d zones" % parts.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.TEXT_SOFT)
		var best := "Best  " + Speedrun.clock(float(Progress.speed_best[id])) if Progress.speed_best.has(id) else "No time yet"
		c.draw_string(f, Vector2(40, 268), best, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.STAR_GOLD.darkened(0.25) if Progress.speed_best.has(id) else Palette.TEXT_SOFT))
	return c


func _draw() -> void:
	var f := UiTheme.font()
	var v := size
	var title := "Speedrun"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	draw_string(f, Vector2((v.x - tw) / 2.0, 120 + _top + 96 * 0.8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Palette.TEXT)
	var sub := "Clear every zone as fast as you can. No hints, no undos."
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string(f, Vector2((v.x - sw) / 2.0, 290 + _top), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.TEXT_SOFT)
