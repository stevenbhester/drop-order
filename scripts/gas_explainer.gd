class_name GasExplainer
extends Control
## The first time a hint or an undo is wanted past the level's free ones: the level fades back with the gas
## gauge and the button still lit (like Spotlight's road hazards), and a gas can lifts off the gauge, swings
## over to the button, pours into it and vanishes in a puff, on a loop. The card says how gas works, that an
## ad refuels it, and (this is a beta) that the ads are pretend and the gas can be made unlimited.
## "Use 1 tank" (or "Watch an ad", with none left) goes ahead; "Not now" doesn't. Shown once (seen_new "gas").

signal chosen(go: bool)

const FUEL := GasChip.FUEL
const LOOP := 2.9

var what := "hint"               # "hint" or "undo"
var gauge := Vector2.ZERO        # where the gas gauge is (its can), on screen
var gauge_box := Rect2()         # the whole gauge, on screen (lit up), if known
var button := Rect2()            # the Hint or Undo button, on screen
var cost := 1
var undos_only := false          # the daily: no hints, so a tank's just undos

var _t := 0.0
var _closing := false
var _dim: ColorRect
var _fg: Control
var _card: PanelContainer
var _go: JuicyButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 rect_size;
uniform vec4 holes[2];
uniform float k = 0.0;
void fragment() {
	vec2 p = UV * rect_size;
	float lit = 0.0;
	for (int i = 0; i < 2; i++) {
		float d = distance(p, holes[i].xy);
		lit = max(lit, 1.0 - smoothstep(holes[i].z * 0.9, holes[i].z * 1.1, d));
	}
	COLOR = vec4(0.07, 0.05, 0.13, 0.8 * k * (1.0 - lit));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.material = mat
	add_child(_dim)
	_fg = Control.new()
	_fg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg.draw.connect(_draw_fg)
	add_child(_fg)
	_build_card()
	Sfx.play("sparkle", 1.0, -3.0)
	Sfx.haptic(16)


func _build_card() -> void:
	var v := get_viewport_rect().size
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(48)
	sb.set_content_margin_all(40)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 12)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(900.0, v.x - 60.0), 0)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_card.add_child(col)
	# Punchy: what it is, what a tank buys. The rest is small print under the card (_draw_fg).
	var thing := "hints" if what == "hint" else "undos"
	col.add_child(_label("Out of free %s!" % thing, 60, Palette.TEXT))
	var buys := "1 tank = unlimited undos" if undos_only else ("1 tank = unlimited undos + hints" if what == "undo" else "1 tank = unlimited hints + undos")
	col.add_child(_label(buys, 48, GasChip.FUEL))
	col.add_child(_label("for the rest of this job", 40, Palette.TEXT))
	_go = JuicyButton.new()
	var have := Progress.total_gas() >= cost
	_go.label = ("Use %s" % ("1 tank" if cost == 1 else "%d tanks" % cost)) if have else "Watch an ad (+%d gas)" % Progress.AD_TANKS
	_go.icon_name = "gas" if have else "ad"
	_go.font_px = 44
	_go.bg = FUEL if have else Color("ff3d9a")
	_go.fg = Color.WHITE
	_go.custom_minimum_size = Vector2(0, 120)
	_go.pressed.connect(_choose.bind(true))
	col.add_child(_go)
	var no := JuicyButton.new()
	no.label = "Not now"
	no.font_px = 36
	no.custom_minimum_size = Vector2(0, 96)
	no.pressed.connect(_choose.bind(false))
	col.add_child(no)
	_card.modulate.a = 0.0


func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choose(go: bool) -> void:
	if _closing:
		return
	_closing = true
	Progress.seen_new["gas"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		chosen.emit(go)
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	if Progress.auto and _t > 0.8 and not OS.get_cmdline_user_args().has("--gas-hold"):
		_choose(true)
	var v := size
	# The card in the middle of the board, clear of the gauge (top) and the buttons (bottom).
	_card.reset_size()
	_card.position = Vector2((v.x - _card.size.x) / 2.0, minf((v.y - _card.size.y) / 2.0 - 40.0, minf(gauge.y, button.position.y) - _card.size.y - 260.0))
	_card.modulate.a = clampf((_t - 0.15) / 0.25, 0.0, 1.0)
	var mat := _dim.material as ShaderMaterial
	var pulse := 1.0 + 0.04 * sin(_t * 4.0)
	mat.set_shader_parameter("rect_size", v)
	mat.set_shader_parameter("holes", PackedVector4Array([_gauge_hole(pulse), Vector4(button.get_center().x, button.get_center().y, button.size.x * 0.62 * pulse, 0)]))
	mat.set_shader_parameter("k", clampf(_t / 0.3, 0.0, 1.0))
	# A glug as it pours, each time round.
	var u := fmod(_t, LOOP)
	var was := fmod(_t - delta, LOOP)
	if was < 1.0 and u >= 1.0:
		Sfx.play("whoosh", 1.2, -10.0)
	if was < 1.9 and u >= 1.9:
		Sfx.play("pop", 1.4, -8.0)
	_fg.queue_redraw()


func _gauge_hole(pulse: float) -> Vector4:
	if gauge_box.size == Vector2.ZERO:
		return Vector4(gauge.x, gauge.y, 80.0 * pulse, 0)
	var c := gauge_box.get_center()
	return Vector4(c.x, c.y, gauge_box.size.x * 0.6 * pulse, 0)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The can: off the gauge, an arc over to the button, tips up and pours (drops falling into the button,
## which glows and swells), then a puff and it's gone.
func _draw_fg() -> void:
	var ci := _fg
	var u := fmod(_t, LOOP)
	var bc := button.get_center()
	var over := bc + Vector2(-button.size.x * 0.05, -button.size.y * 1.15)
	var a := 1.0
	var pos := gauge
	var rot := 0.0
	var s := 1.0
	if u < 0.25:
		s = 1.0 + 0.3 * sin(u / 0.25 * PI)          # it lifts off the gauge
	elif u < 0.95:
		var k := _ease((u - 0.25) / 0.7)
		pos = gauge.lerp(over, k) + Vector2(0, -180.0 * sin(PI * k))
		rot = 0.6 * k
		s = 1.3
	elif u < 1.85:
		pos = over
		rot = lerpf(0.6, 2.1, _ease((u - 0.95) / 0.3))
		s = 1.3
	elif u < 2.25:
		pos = over
		rot = 2.1
		s = 1.3
		a = 1.0 - (u - 1.85) / 0.4
	else:
		a = 0.0
	# The pour: fuel drops from the can's spout into the button.
	if u >= 1.1 and u < 1.95:
		var spout := pos + Vector2(28, -26).rotated(rot) * s
		for k in 7:
			var d := fmod(u * 3.0 + k / 7.0, 1.0)
			var p := spout.lerp(bc + Vector2(0, -10), d)
			ci.draw_circle(p, 9.0 * (1.0 - 0.4 * d), Color(FUEL, 0.95))
		var glow := clampf((u - 1.2) / 0.5, 0.0, 1.0)
		ci.draw_arc(bc, button.size.x * 0.56 + 10.0 * glow, 0, TAU, 48, Color(FUEL, 0.8 * glow), 10.0, true)
	if u >= 1.85 and u < 2.5:
		# The puff where the can was: it's spent.
		var k := (u - 1.85) / 0.65
		for q in 6:
			var ang := TAU * q / 6.0
			ci.draw_circle(over + Vector2(cos(ang), sin(ang)) * 60.0 * k, 22.0 * (1.0 - k) + 4.0, Color(0.92, 0.9, 0.95, 0.8 * (1.0 - k)))
		var f := UiTheme.font()
		var minus := "−%d" % cost
		ci.draw_string_outline(f, bc + Vector2(-26, -button.size.y * 0.7 - 70.0 * k), minus, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, 12, Color(1, 1, 1, 1.0 - k))
		ci.draw_string(f, bc + Vector2(-26, -button.size.y * 0.7 - 70.0 * k), minus, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(FUEL, 1.0 - k))
	# The small print, faint, under the card: how gas comes back, and the beta's aside.
	if _card:
		var f2 := UiTheme.font()
		var k2 := _card.modulate.a * 0.55
		var y0 := _card.position.y + _card.size.y + 56.0
		for line in ["A tank refills every %s. Out? An ad gives %d." % [Progress.refill_every(), Progress.AD_TANKS],
				"Beta: the ads are pretend and skippable. Options → Testers → Unlimited gas."]:
			var lw := f2.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			ci.draw_string(f2, Vector2(size.x / 2.0 - lw / 2.0, y0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.85, 0.82, 0.9, k2))
			y0 += 42.0
	if a > 0.0:
		ci.draw_set_transform(pos, rot, Vector2.ONE * s)
		Icons.draw(ci, "gas", Vector2.ZERO, 66.0, Color(FUEL, a))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
