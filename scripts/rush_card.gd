class_name RushCard
extends CanvasLayer
## A detour just paid out a rush (Progress.side_power_up): the big card for it. A stopwatch in a burst of
## light, what it is ("2:00 of free undos"), and how it's started: on the button it belongs to, held down,
## once you're out (a little picture of that button with the stopwatch on its corner). "Got it!" closes.
##
##   kind  "undos" or "hints"
##   secs  how long it will run

signal done

const INK := Color(0.1, 0.07, 0.16)

var kind := "undos"
var secs := 120.0

var _root: Control
var _go: JuicyButton
var _t := 0.0
var _closing := false


func _ready() -> void:
	layer = 82
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_it)
	add_child(_root)
	_go = JuicyButton.new()
	_go.label = "Got it!"
	_go.font_px = 60
	_go.bg = RushRing.GOLD
	_go.fg = Color("2b2233")
	_go.size = Vector2(620, 150)
	_go.modulate.a = 0.0
	_go.pressed.connect(_close)
	_root.add_child(_go)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)
	Sfx.play("whoomp", 0.9, -6.0)
	Sfx.play("sparkle", 1.0, -4.0)
	Sfx.haptic(30, 1.0, "rush_card:_ready")


func _process(delta: float) -> void:
	_t += delta
	var v := _root.get_viewport_rect().size
	_go.position = Vector2((v.x - _go.size.x) / 2.0, v.y * 0.84)
	if _t > 0.9 and _go.modulate.a <= 0.0:
		create_tween().tween_property(_go, "modulate:a", 1.0, 0.2)
		_go.breathe(true)
	if Progress.auto and _t > 1.6 and not OS.get_cmdline_user_args().has("--card-hold"):
		_close()
	_root.queue_redraw()


func _close() -> void:
	if _closing or _go.modulate.a < 0.5:
		return
	_closing = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		done.emit()
		queue_free())


func _draw_it() -> void:
	var v := _root.get_viewport_rect().size
	var f := UiTheme.font()
	var gold := RushRing.GOLD
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.07, 0.05, 0.13, 0.94))
	var c := Vector2(v.x / 2.0, v.y * 0.33)
	var pop := clampf(_t / 0.35, 0.0, 1.0)
	pop = 1.0 - pow(1.0 - pop, 3.0)
	# Rays, turning slowly.
	for k in 14:
		var a := _t * 0.25 + k * TAU / 14.0
		var d1 := Vector2(cos(a - 0.09), sin(a - 0.09))
		var d2 := Vector2(cos(a + 0.09), sin(a + 0.09))
		_root.draw_colored_polygon(PackedVector2Array([c, c + d1 * v.x * 0.9 * pop, c + d2 * v.x * 0.9 * pop]), Color(gold, 0.1))
	_root.draw_circle(c, 300.0 * pop, Color(gold, 0.16))
	# The stopwatch, its hand racing, and what it's for on its face's rim.
	var s := 210.0 * pop * (1.0 + 0.02 * sin(_t * 5.0))
	RushRing.draw_watch(_root, c + Vector2(0, 26), s, gold, INK, _t * 4.0)
	# The band with its name.
	var head := "%s!" % str(Progress.RUSH_NAME.get(kind, "Rush")).to_upper()
	_root.draw_set_transform(Vector2(v.x / 2.0, v.y * 0.105), deg_to_rad(-4.0), Vector2(pop, pop))
	_root.draw_rect(Rect2(-v.x * 0.7, -88.0, v.x * 1.4, 176.0), gold)
	var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 124).x
	_root.draw_string_outline(f, Vector2(-hw / 2.0, 44.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 124, 20, INK)
	_root.draw_string(f, Vector2(-hw / 2.0, 44.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 124, Color.WHITE)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var a1 := clampf((_t - 0.3) / 0.25, 0.0, 1.0)
	var big := "%s of free %s" % [Progress.clock(secs), kind]
	_mid(big, v.y * 0.535, 84, Color(1, 1, 1, a1))
	_mid("Yours to start when you need it.", v.y * 0.575, 44, Color(1, 1, 1, 0.75 * a1))
	# How: the button, with the stopwatch on its corner.
	var a2 := clampf((_t - 0.6) / 0.25, 0.0, 1.0)
	var word := "Undo" if kind == "undos" else "Hint"
	var br := Rect2(v.x / 2.0 - 190.0, v.y * 0.625, 380.0, 150.0)
	DrawUtil.rrect(_root, Rect2(br.position + Vector2(0, 10), br.size), Color(0, 0, 0, 0.3 * a2), 44.0)
	DrawUtil.rrect(_root, br, Color(1, 1, 1, a2), 44.0)
	Icons.draw(_root, "undo" if kind == "undos" else "bulb", br.position + Vector2(96, 75), 78.0, Color(INK, a2))
	_root.draw_string(f, br.position + Vector2(160, 97), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(INK, a2))
	if a2 > 0.0:
		var wc := br.position + Vector2(8, 4 + sin(_t * 2.6) * 4.0)
		_root.draw_circle(wc, 62.0, Color(gold, 0.22 * a2))
		RushRing.draw_watch(_root, wc, 44.0, Color(gold, a2), Color(INK, a2), _t * 2.2)
	_mid("Out of %s on a job? Hold %s." % [kind, word], v.y * 0.625 + 228.0, 48, Color(gold.lightened(0.2), a2))
	_mid("The clock only runs while you're driving a job.", v.y * 0.625 + 290.0, 38, Color(1, 1, 1, 0.7 * a2))


func _mid(text: String, y: float, px: int, col: Color) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_string(f, Vector2((_root.get_viewport_rect().size.x - w) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
