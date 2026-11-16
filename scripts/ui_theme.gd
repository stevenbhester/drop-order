class_name UiTheme
extends RefCounted
## Shared font + button styling.

static var _font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Avenir Next", "SF Pro Rounded", "Helvetica Neue", "Roboto", "Arial", "sans-serif"])
		sf.font_weight = 700
		_font = sf
		# Fredoka (bundled) everywhere: round and friendly, and the same on every device.
		var path := "res://assets/fonts/Fredoka.ttf"
		if ResourceLoader.exists(path):
			var fv := FontVariation.new()
			fv.base_font = load(path)
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
			fv.fallbacks = [sf]
			_font = fv
	return _font


## Room to leave for a phone's notch and home bar, in viewport units: Vector2(top, bottom).
static func insets(vp: Viewport) -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return Vector2.ZERO
	var k := vp.get_visible_rect().size.x / float(win.x)
	return Vector2(safe.position.y * k, maxf(0.0, (win.y - safe.end.y) * k))


## Room to leave at the left and right in sideways play (the notch), in viewport units: Vector2(left, right).
static func side_insets(vp: Viewport) -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return Vector2.ZERO
	var k := vp.get_visible_rect().size.x / float(win.x)
	return Vector2(safe.position.x * k, maxf(0.0, (win.x - safe.end.x) * k))


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 44
	_theme = t
	refresh()
	return t


## Night mode flipped: re-colour the shared theme in place (everything using it updates).
static func refresh() -> void:
	if _theme == null:
		return
	button_style(_theme, Palette.SURFACE, Palette.TEXT)
	_theme.set_color("font_color", "Label", Palette.TEXT)


## Applies a chunky rounded style to Button, either on a Theme or as overrides on one Button.
static func button_style(target: Object, bg: Color, fg: Color) -> void:
	var states := {"normal": bg, "hover": bg.lightened(0.06), "pressed": bg.darkened(0.08), "disabled": bg.lerp(Color.GRAY, 0.5)}
	for st in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[st]
		sb.set_corner_radius_all(30)
		sb.border_width_bottom = 2 if st == "pressed" else 8
		sb.border_color = bg.darkened(0.2)
		sb.content_margin_left = 32
		sb.content_margin_right = 32
		sb.content_margin_top = 18
		sb.content_margin_bottom = 18 + (6 if st != "pressed" else 0)
		sb.anti_aliasing = true
		if target is Theme:
			target.set_stylebox(st, "Button", sb)
		else:
			target.add_theme_stylebox_override(st, sb)
	if target is Theme:
		target.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			target.set_color(c, "Button", fg)
		target.set_color("font_disabled_color", "Button", Color(fg, 0.45))
	else:
		target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			target.add_theme_color_override(c, fg)
		target.add_theme_color_override("font_disabled_color", Color(fg, 0.45))


## A text box you can see where you are in: a thick blinking caret in the accent colour (Godot's is a pale
## hairline, lost on these cards), put wherever it's tapped, and a selection you can see.
static func text_caret(box: TextEdit) -> void:
	box.caret_blink = true
	box.caret_blink_interval = 0.5
	box.caret_type = TextEdit.CARET_TYPE_LINE
	box.caret_move_on_right_click = true
	box.add_theme_color_override("caret_color", Palette.ACCENT)
	box.add_theme_constant_override("caret_width", 6)
	box.add_theme_color_override("selection_color", Color(Palette.ACCENT, 0.3))
	box.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))


## Something that's coming but isn't here yet: a greyed button with `title` (and a small `note`) on it and
## yellow WIP tape stuck across it at a slant. Drawn into `r` on `ci`. (The garage's toppers; "Buy Last Mile
## Premium" at checkpoints.)
static func draw_wip(ci: CanvasItem, r: Rect2, title: String, note := "") -> void:
	var f := font()
	DrawUtil.rrect(ci, Rect2(r.position + Vector2(0, 8), r.size), Color(0, 0, 0, 0.12), 30)
	DrawUtil.rrect(ci, r, Color("e7e2ea"), 30)
	# The words keep clear of the tape (which crosses the right-hand corner): to the left, sized to fit.
	var room := r.size.x - 290.0
	var tpx := int(clampf(r.size.y * 0.3, 26.0, 46.0))
	while tpx > 20 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > room:
		tpx -= 2
	var ty := r.get_center().y + (tpx * 0.1 if note == "" else -tpx * 0.25)
	ci.draw_string(f, Vector2(r.position.x + 40.0, ty + tpx * 0.3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Color(0.35, 0.32, 0.4, 0.8))
	if note != "":
		ci.draw_string(f, Vector2(r.position.x + 40.0, ty + tpx * 0.3 + 34.0), note, HORIZONTAL_ALIGNMENT_LEFT, room, 24, Color(0.35, 0.32, 0.4, 0.55))
	# The tape: slapped across the right-hand corner, black chevrons on yellow, WIP along it.
	var a := Vector2(r.end.x - 250.0, r.position.y - 14.0)
	var b := Vector2(r.end.x + 18.0, r.position.y + r.size.y * 0.86)
	var dir := b - a
	var ln := dir.length()
	var wd := 40.0
	ci.draw_set_transform(a, dir.angle(), Vector2.ONE)
	ci.draw_rect(Rect2(0, -wd / 2.0 + 5, ln, wd), Color(0, 0, 0, 0.2))
	ci.draw_rect(Rect2(0, -wd / 2.0, ln, wd), Color("ffc93c"))
	var x := 0.0
	while x < ln:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -wd / 2.0), Vector2(minf(x + 14, ln), -wd / 2.0), Vector2(minf(x + 6, ln), -wd / 2.0 + 8), Vector2(maxf(x - 8, 0), -wd / 2.0 + 8)]), Color("2b2233"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, wd / 2.0 - 8), Vector2(minf(x + 14, ln), wd / 2.0 - 8), Vector2(minf(x + 6, ln), wd / 2.0), Vector2(maxf(x - 8, 0), wd / 2.0)]), Color("2b2233"))
		x += 30.0
	var word := "WIP · COMING SOON · "
	var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var tx := 10.0
	while tx < ln - 30.0:
		ci.draw_string(f, Vector2(tx, 7), word, HORIZONTAL_ALIGNMENT_LEFT, ln - tx, 20, Color("2b2233"))
		tx += ww
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
