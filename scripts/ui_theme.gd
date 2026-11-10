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
	return _font


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 44
	button_style(t, Color.WHITE, Palette.TEXT)
	t.set_color("font_color", "Label", Palette.TEXT)
	_theme = t
	return t


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
