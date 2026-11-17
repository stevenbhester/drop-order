class_name LimitsScene
extends Control
## The Baron meters the helpers: the scripted scene at the start of the second boss job (Game._limits_tick;
## Progress.LIMITS_FROM). Until now hints and calls were unlimited (the tutorial, and job 6, the first time
## we beat him: he blames that). He runs in along the top of the button row and stamps Hint, then Call: each
## one's "∞" turns into the count the player now carries, and a card over it says how many and that they
## carry over. Then he rips the padlock off the pump (GasChip.reveal: its cans fill up), and its card says
## how to get more of either. Then he runs off.
## Undo and Retry aren't his to meter and aren't mentioned. One tap moves it on a step.
##
## Game keeps the buttons honest: `stamped(kind)` ("hint", "radio", "pump") as he does each, and until then
## that one still shows as it was (Game._still_free). `finished` when he's gone.

signal stamped(kind: String)
signal finished

const RUN := 0.5                 # seconds he takes to get to the next one
const MIN_READ := 0.45           # ...and a card's up at least this long before a tap moves on

var game: Game

var _dim: FocusDim
var _stage: Control
var _bubble: PanelContainer
var _title: Label
var _body: Label
var _tap: Label
var _steps: Array = []
var _i := -1
var _t := 0.0                    # the scene's clock
var _st := 0.0                   # ...and this step's
var _from_x := 0.0
var _x := 0.0                    # where the Baron is
var _slam := -1.0                # seconds since the last stamp (for its ring and his hop)
var _slam_at := Vector2.ZERO
var _stamped := false
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	_dim = FocusDim.new()
	_dim.strength = 0.5
	add_child(_dim)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(40)
	sb.set_content_margin_all(34)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	sb.anti_aliasing = true
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(col)
	_title = _label(40, Palette.ACCENT)
	_body = _label(36, Palette.TEXT)
	_tap = _label(24, Color(Palette.TEXT_SOFT, 0.8))
	_tap.text = "tap to go on"
	for l in [_title, _body, _tap]:
		col.add_child(l)
	_bubble.modulate.a = 0.0
	var per := Progress.RADIO_PER_CAN
	_steps = [
		{"say": "Unlimited help? That's the ONLY reason you beat me last time.\nI'm not mad. I'm just taking it.", "at": "middle"},
		{"stamp": "hint", "title": "HINTS: %d. THAT'S IT." % Progress.hints,
			"body": "A hint shows your next move. Whatever you don't use carries over to the next job. They don't grow back."},
		{"stamp": "radio", "title": "CALLS: %d. MAKE THEM COUNT." % Progress.radio,
			"body": "A call asks Dispatch if you can still finish. Leftovers carry over too. And you get one for every job you deliver. (Not my idea.)"},
		{"stamp": "pump", "title": "WANT MORE? PAY UP.",
			"body": "Behold: MY gas pump. One can buys a hint or %d calls. It holds %d cans and drips back one an hour. Or win more as prizes, if you can." % [per, Progress.MAX_GAS]},
		{"say": "Now deliver THAT.\nIf you can.", "at": "middle"},
	]
	if game.radio_button == null:
		_steps.remove_at(2)
	_x = get_viewport_rect().size.x + 220.0
	_next()
	Sfx.play("laugh", 1.0, -6.0)


func _label(px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## What this step is about, on screen (an empty Rect2: nothing in particular).
func _target(step: Dictionary) -> Rect2:
	match str(step.get("stamp", step.get("at", ""))):
		"pump":
			return game.gas_chip.get_global_rect()
		"hint":
			return game.hint_button.get_global_rect()
		"radio":
			return game.radio_button.get_global_rect()
	return Rect2()


## The top of the button row: where he runs.
func _floor() -> float:
	return game.hint_button.get_global_rect().position.y - 14.0


## Where he stands for a step: beside what it's about (on the side with more room), or mid-screen.
func _stand(step: Dictionary) -> float:
	var v := get_viewport_rect().size
	var r := _target(step)
	if r.size == Vector2.ZERO:
		return v.x / 2.0
	var c := r.get_center().x
	return clampf(c + (150.0 if c < v.x / 2.0 else -150.0), 120.0, v.x - 120.0)


func _next() -> void:
	_i += 1
	_st = 0.0
	_stamped = false
	_from_x = _x
	_bubble.modulate.a = 0.0
	if _i >= _steps.size():
		_leaving = true
		return
	var step: Dictionary = _steps[_i]
	_title.visible = step.has("title")
	_title.text = str(step.get("title", ""))
	_body.text = str(step.get("body", step.get("say", "")))
	_body.add_theme_font_size_override("font_size", 52 if step.has("say") else 36)
	Sfx.play("whoosh", 1.2, -10.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _leaving or _i < 0 or _i >= _steps.size():
			return
		if _st < RUN:
			_st = RUN                # (a tap hurries him over)
		elif _st > RUN + MIN_READ:
			Sfx.play("click")
			_next()


func _process(delta: float) -> void:
	_t += delta
	_st += delta
	if _slam >= 0.0:
		_slam += delta
	var v := get_viewport_rect().size
	if _leaving:
		# Off to the left, and gone.
		_x = lerpf(_from_x, -260.0, clampf(_st / 0.7, 0.0, 1.0))
		_dim.hole = Rect2(-100, -100, 0, 0)
		modulate.a = 1.0 - clampf((_st - 0.5) / 0.25, 0.0, 1.0)
		if _st >= 0.75:
			finished.emit()
			queue_free()
		_stage.queue_redraw()
		return
	var step: Dictionary = _steps[_i]
	var u := clampf(_st / RUN, 0.0, 1.0)
	_x = lerpf(_from_x, _stand(step), 1.0 - pow(1.0 - u, 3.0))
	if u >= 1.0 and not _stamped:
		_stamped = true
		if step.has("stamp"):
			# Down comes the meter.
			stamped.emit(str(step["stamp"]))
			_slam = 0.0
			Sfx.play("slam", 1.1, -3.0)
			if str(step["stamp"]) == "pump":
				Sfx.play("sparkle", 0.8, -2.0)
				Sfx.haptic(45, 1.0)
			Sfx.play("thunk", 0.8, -4.0)
			Sfx.haptic(30, 0.8)
		elif step.has("say"):
			Sfx.play("laugh", 1.1, -8.0)
	var r := _target(step) if (_stamped or not step.has("stamp")) else Rect2()
	_dim.hole = r.grow(10.0) if r.size != Vector2.ZERO else Rect2(-100, -100, 0, 0)       # (nothing lit: all dim)
	if _slam >= 0.0 and _slam < 0.1:
		_slam_at = r.get_center()
	# The card: over his head, once he's there.
	var w := minf(920.0, v.x - 60.0)
	_bubble.custom_minimum_size = Vector2(w, 0)
	var sz := _bubble.get_combined_minimum_size()
	_bubble.size = sz
	_bubble.position = Vector2((v.x - w) / 2.0, maxf(40.0, _floor() - 250.0 - sz.y))
	_bubble.modulate.a = clampf((_st - RUN) / 0.18, 0.0, 1.0)
	_tap.modulate.a = clampf((_st - RUN - MIN_READ) / 0.3, 0.0, 1.0) * (0.6 + 0.4 * sin(_t * 4.0))
	_stage.queue_redraw()


func _draw_stage() -> void:
	if _i < 0:
		return
	var feet := Vector2(_x, _floor())
	var running := _leaving or _st < RUN
	var hop := 0.0
	if running:
		hop = absf(sin(_t * 18.0)) * 16.0
	elif _slam >= 0.0 and _slam < 0.35:
		hop = sin(_slam / 0.35 * PI) * 46.0
	var mood := "laugh" if (_slam >= 0.0 and _slam < 0.9) or (_i < _steps.size() and _steps[_i].has("say") and not running) else "smug"
	_stage.draw_circle(feet + Vector2(0, 4), 62.0, Color(0, 0, 0, 0.18))
	Boss.draw(_stage, feet + Vector2(0, -hop), 210.0, _t, mood)
	# A stamp's ring, off what he metered.
	if _slam >= 0.0 and _slam < 0.5:
		var k := _slam / 0.5
		_stage.draw_arc(_slam_at, 60.0 + 220.0 * k, 0.0, TAU, 40, Color(1, 1, 1, 0.9 * (1.0 - k)), 14.0 * (1.0 - k) + 2.0, true)
	# The pump's unveiling gets more: rays of light off it that turn slowly, and a second, fuel-red ring.
	if _i >= 0 and _i < _steps.size() and str(_steps[_i].get("stamp", "")) == "pump" and _slam >= 0.0:
		var k := clampf(_slam / 0.4, 0.0, 1.0)
		var fade := 1.0 - clampf((_slam - 1.6) / 0.6, 0.0, 1.0)
		for j in 12:
			var a := TAU * j / 12.0 + _t * 0.6
			var tip := _slam_at + Vector2(cos(a), sin(a)) * (120.0 + 260.0 * k)
			var side := Vector2(-sin(a), cos(a)) * 22.0
			_stage.draw_colored_polygon(PackedVector2Array([_slam_at + side * 0.3, _slam_at - side * 0.3, tip - side, tip + side]),
				Color(Color("ffd166"), 0.28 * fade))
		if _slam < 0.8:
			var u := _slam / 0.8
			_stage.draw_arc(_slam_at, 80.0 + 380.0 * u, 0.0, TAU, 48, Color(GasChip.FUEL, 0.8 * (1.0 - u)), 18.0 * (1.0 - u) + 2.0, true)
	# The card's tail: down toward what it's about (or to him, when he's talking).
	if _bubble.modulate.a > 0.0 and not _leaving:
		var step: Dictionary = _steps[_i]
		var r := _target(step)
		var to_x := _x if r.size == Vector2.ZERO else r.get_center().x
		var bx := clampf(to_x, _bubble.position.x + 70.0, _bubble.position.x + _bubble.size.x - 70.0)
		var by := _bubble.position.y + _bubble.size.y - 2.0
		_stage.draw_colored_polygon(PackedVector2Array([Vector2(bx - 28.0, by), Vector2(bx + 28.0, by), Vector2(lerpf(bx, to_x, 0.3), by + 44.0)]),
			Color(Palette.CARD, _bubble.modulate.a))
