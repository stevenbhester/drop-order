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
