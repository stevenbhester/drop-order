class_name BuffCard
extends CanvasLayer
## A permanent upgrade, shown big: brighter headlights (the van on a dark road, its beam reaching one tile
## further than before, the road beyond still dark) and/or an extra undo on every level. Bosses drop these
## (levels/side.json "buff"); the speedruns give the last headlight. With `intro` set it's the first ones
## (found in a present on job 2's road): what they do, and that better ones are out there. Short: it's the
## tutorial. With `wrapped`, it starts as that present: a parcel to tap open (UnlockCard.draw_parcel).
##
## What headlights do, in the card's words (_what): "The van now stays N tiles behind your finger." It
## answers the dark jobs' "it drives right under your finger... for now", and the line under it says what
## the gap is for: sliding back to change your mind before the van drives there.
##
##   lights: how far the headlights reach now (0: no change, or the headlights experiment is off)
##   undos:  undos per level now (0: no change)

signal done

const NIGHT := Color("14121f")
const BEAM := Color("ffe9a3")
const BLUE := Color("4d8dff")
const TILE := 150.0

var lights := 0
var undos := 0
var intro := false
## The intro, for the headlights just found on job 2 (else the intro's for an older save meeting them
## mid-game).
var first_delivery := false
## Still in its present: a parcel first, tapped open (the headlights found on job 2's road).
var wrapped := false
## One page of a run of rewards (RewardPager): no fade in or out (the pager pans it), `done` without freeing
## itself, and once it's all shown a tap anywhere is its button.
var paged := false

var _root: Control
var _van: Van
var _go: JuicyButton
var _t := 0.0
var _lit := 0
var _closing := false
var _box_t := -1.0               # the parcel: seconds since it dropped in (-1: none, or it's open)
var _box_wait := 0.0             # seconds since it was tapped open


func _ready() -> void:
	layer = 82
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_it)
	add_child(_root)
	if lights > 0:
		_van = Van.new()
		_van.size = TILE * 0.95
		_van.target_rotation = 0.0
		_root.add_child(_van)
	_go = JuicyButton.new()
	_go.label = "Lights on!" if lights > 0 else "Sweet!"
	_go.font_px = 46
	_go.bg = Palette.STAR_GOLD
	_go.fg = Color("2b2233")
	_go.custom_minimum_size = Vector2(460, 128)
	_go.size = _go.custom_minimum_size
	_go.modulate.a = 0.0
	_go.pressed.connect(_close)
	_root.add_child(_go)
	if not paged:
		_root.modulate.a = 0.0
		create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)
	_root.gui_input.connect(_on_tap)
	if wrapped:
		_box_t = 0.0
		if _van:
			_van.visible = false
		Sfx.play("thunk", 0.8, -4.0)
		Sfx.haptic(20)
	else:
		Sfx.play("whoomp", 0.9, -6.0)


## A tap off the button: opens the parcel; hurries the reveal along; and, as a page of rewards, once it's
## all shown, counts as the button.
func _on_tap(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	_root.accept_event()
	if _box_t >= 0.0:
		if _box_wait <= 0.0:
			_open_box()
	elif _go.modulate.a < 0.5:
		_t = maxf(_t, _reveal_at())
	elif paged:
		_close()


## The parcel's tapped: the lid flies, a blast of light, then the card.
func _open_box() -> void:
	_box_wait = 0.001
	Sfx.play("punch", 1.2, -2.0)
	Sfx.play("whoomp", 1.1, -4.0)
	Sfx.haptic(45, 1.0)


func _reveal_at() -> float:
	return 0.5 + 0.22 * maxi(lights, 1) + 0.3


func _process(delta: float) -> void:
	if _box_t >= 0.0:
		# Still wrapped: waiting for the tap (the self-tests open it themselves), then the lid's 0.35 s.
		_box_t += delta
		if _box_wait > 0.0:
			_box_wait += delta
			if _box_wait > 0.35:
				_box_t = -1.0
				_t = 0.0
				if _van:
					_van.visible = true
		elif Progress.auto and _box_t > 1.0:
			_open_box()
		_root.queue_redraw()
		return
	_t += delta
	# (Self-tests: it closes itself, unless asked to stay for a recording.)
	if Progress.auto and _t > _reveal_at() + 0.6 and not OS.get_cmdline_user_args().has("--card-hold"):
		_close()
	# The beam reaches out a tile at a time.
	var want := clampi(int(floor((_t - 0.5) / 0.22)) + 1, 0, lights) if _t >= 0.5 else 0
	while _lit < want:
		_lit += 1
		Sfx.play("tick", 0.9 + 0.12 * _lit, -4.0)
		Sfx.haptic(8)
		if _lit == lights:
			Sfx.play("sparkle", 1.0, -4.0)
			Sfx.haptic(22)
	_demo_tick()
	if _t >= _reveal_at() and _go.modulate.a == 0.0:
		if lights == 0:
			Sfx.play("sparkle", 1.0, -4.0)
		create_tween().tween_property(_go, "modulate:a", 1.0, 0.2)
		_go.breathe(true)
	var v := _root.size
	_go.position = Vector2((v.x - _go.size.x) / 2.0, v.y / 2.0 + 430.0)
	if _van:
		_van.position = _road_at(0).lerp(_road_at(1), _van_at)
		_van.target_rotation = 0.0
	_root.queue_redraw()


# ---------------------------------------------------------------- the demo
# How it plays, on a loop once the lights are on: a finger draws a route along the road, the line runs
# ahead of the van as far as its lights reach, and then the van sets off by itself and follows the finger,
# that many tiles behind; the finger lets go and the van drives the rest. (Positions are in tiles.)

const DRAW_SPEED := 1.2          # tiles a second the finger draws (slow: it has to be followed by eye)
const HOLD := 1.8                 # seconds it sits at the end before going again

var _finger := 0.0               # how far the finger has drawn
var _van_at := 0.0               # where the van is
var _demo_t := -1.0              # seconds into the current loop (-1: not started)
var _rolling := false
var _phase := 0.0                # seconds into this loop


func _road_len() -> int:
	return clampi(lights + 4, 5, 9)


func _demo_tick() -> void:
	if lights <= 0:
		return
	var start := _reveal_at() + 0.2
	if _t < start:
		return
	var dt := get_process_delta_time()
	_demo_t = (_t - start)
	var end := float(_road_len() - 1)
	var draw_for := end / DRAW_SPEED
	var loop := 0.4 + draw_for + float(lights) / (DRAW_SPEED * 1.4) + HOLD
	var u := fmod(_demo_t, loop)
	_phase = u
	var was_rolling := _rolling
	if u < 0.4:
		_finger = 0.0
		_van_at = 0.0
		_rolling = false
	else:
		_finger = minf(end, (u - 0.4) * DRAW_SPEED)
		if _finger < end:
			_van_at = maxf(0.0, _finger - float(lights))
		else:
			# Let go: the van drives the rest of the line.
			_van_at = minf(end, _van_at + DRAW_SPEED * 1.4 * dt)
		_rolling = _van_at > 0.01 and _van_at < end - 0.01
	if _rolling and not was_rolling:
		Sfx.play("whoosh", 1.3, -10.0)


## The words under the road change with what the demo's showing.
func _caption() -> String:
	# (No running commentary any more: four lines flashing by over the description read as noise. The
	# picture shows it, slowly; the two lines under it say it.)
	if true:
		return ""
	if _demo_t < 0.0 or _finger <= 0.0:
		return "Drag from the van..."
	if _van_at <= 0.0:
		return "Plan up to %d tile%s ahead..." % [lights, "" if lights == 1 else "s"]
	if _finger < float(_road_len() - 1):
		return "...and it starts driving, right behind you."
	return "Let go: it drives the rest."


func _close() -> void:
	if _closing or _go.modulate.a < 0.5:
		return
	_closing = true
	Sfx.play("click")
	if paged:
		done.emit()            # (the pager pans this page away and frees it)
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		done.emit()
		queue_free())


## The middle of tile k of the little road (0 is where the van sits).
func _road_at(k: float) -> Vector2:
	var v := _root.size
	var n := _road_len()
	var t := minf(TILE, (v.x - 80.0) / n)
	return Vector2(v.x / 2.0 - t * (n - 1) / 2.0 + k * t, v.y / 2.0 - 60.0)


func _out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


func _centered(text: String, at: Vector2, px: int, col: Color, k := 1.0) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_string_outline(f, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(6, px / 6), Color(NIGHT, k))
	_root.draw_string(f, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, k))


func _draw_it() -> void:
	var v := _root.size
	var c := v / 2.0
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(NIGHT, 0.94))
	if _box_t >= 0.0:
		UnlockCard.draw_parcel(_root, v, c + Vector2(0, -80), Palette.STAR_GOLD, _box_t, _box_wait)
		return
	var shown := _out((_t - _reveal_at() + 0.25) / 0.3)
	var y := c.y - 60.0
	if lights > 0:
		_draw_road()
		if intro and first_delivery:
			# The ones just found: what they do, and (small) that there are better. Short: it's the tutorial.
			_centered("YOU FOUND", Vector2(c.x, y - 345.0), 60, Color.WHITE, shown)
			_centered("HEADLIGHTS!", Vector2(c.x, y - 250.0), 104, Palette.STAR_GOLD, shown)
			var what := _what()
			_centered(what[0], Vector2(c.x, y + 285.0), 44, Color.WHITE, shown)
			_centered(what[1], Vector2(c.x, y + 345.0), 36, Color(1, 1, 1, 0.75), shown)
			var ins := UiTheme.insets(_root.get_viewport())
			_centered("Brighter ones are out there. The Baron's hoarding them.", Vector2(c.x, v.y - ins.y - 60.0), 28,
				Color(0.72, 0.68, 0.8), shown * 0.6)
		else:
			var title := Progress.light_name(lights).to_upper() + "!"
			_centered(title, Vector2(c.x, y - 250.0), 104, Palette.STAR_GOLD, shown)
			var what := _what()
			_centered(what[0], Vector2(c.x, y + 290.0), 44, Color.WHITE, shown)
			if intro:
				_centered(what[1], Vector2(c.x, y + 350.0), 36, Color(1, 1, 1, 0.75), shown)
				var ins := UiTheme.insets(_root.get_viewport())
				_centered("Brighter headlights are out there. The Baron's hoarding them.", Vector2(c.x, v.y - ins.y - 60.0), 28,
					Color(0.72, 0.68, 0.8), shown * 0.6)
	else:
		# Just the undo: a big one, in its blue.
		var s := lerpf(2.0, 1.0, _out((_t - 0.2) / 0.25))
		_root.draw_circle(Vector2(c.x, y - 40.0), 150.0 * s, Color(BLUE, 0.25))
		_root.draw_circle(Vector2(c.x, y - 40.0), 116.0 * s, BLUE)
		Icons.draw(_root, "undo", Vector2(c.x, y - 40.0), 150.0 * s, Color.WHITE)
		_centered("MORE UNDOS!", Vector2(c.x, y - 250.0), 104, Palette.STAR_GOLD, shown)
	if undos > 0:
		var line := "%d undos on every job, for good" % undos
		var py := y + (420.0 if lights > 0 else 190.0)
		if lights > 0:
			var f := UiTheme.font()
			var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 130.0
			var pill := Rect2(c.x - w / 2.0, py - 48.0, w, 76.0)
			DrawUtil.rrect(_root, pill, Color(BLUE, shown), 38.0)
			Icons.draw(_root, "undo", pill.position + Vector2(50, 38), 44.0, Color(1, 1, 1, shown))
			_root.draw_string(f, pill.position + Vector2(92, 52), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, shown))
		else:
			_centered(line, Vector2(c.x, py), 46, Color.WHITE, shown)


## What headlights do, in two lines: [the rule, what it's for]. The rule is the gap between the finger (or,
## with the D-pad, the end of the route) and the van; the second line is why you'd want one.
func _what() -> Array:
	var gap := "%d tile%s" % [lights, "" if lights == 1 else "s"]
	if Progress.drive_mode == "dpad":
		return ["Plan %s ahead before the van drives." % gap, "Tap back to change your mind."]
	return ["Plan %s ahead before the van drives." % gap, "Slide back to change your mind."]


## A strip of road in the dark: the van at one end, its beam over the tiles it can plan across, the rest
## of the road barely there.
func _draw_road() -> void:
	var a := _road_at(0)
	var t := _road_at(1).x - a.x
	var n := _road_len()
	DrawUtil.rrect(_root, Rect2(a.x - t * 0.5, a.y - t * 0.42, t * n, t * 0.84), Color("23212f"), 26.0)
	var vx := _van_at
	for k in range(1, n):
		var p := _road_at(k)
		var ahead := float(k) - vx
		var on := (k <= _lit) if _demo_t < 0.0 else (ahead > 0.0 and ahead <= float(lights) + 0.5)
		if on:
			var u := _out((_t - 0.5 - 0.22 * (k - 1)) / 0.2)
			DrawUtil.rrect(_root, Rect2(p.x - t * 0.5 + 5.0, p.y - t * 0.42 + 5.0, t - 10.0, t * 0.84 - 10.0), Color("4a4a5e").lerp(Color("6d6a78"), u), 18.0)
		_root.draw_line(p + Vector2(-t * 0.22, 0), p + Vector2(t * 0.22, 0), Color(1, 1, 1, 0.75 if on else 0.08), 7.0)
	var f := UiTheme.font()
	if _demo_t >= 0.0:
		# The road driven so far (grey trail), and the plan the finger's drawn, from the van to the finger.
		var van_p := _road_at(vx)
		if vx > 0.0:
			_root.draw_line(a, van_p, Color(1, 1, 1, 0.25), t * 0.2, true)
		if _finger > vx:
			var fp := _road_at(_finger)
			_root.draw_line(van_p, fp, Palette.ACCENT, t * 0.16, true)
			_root.draw_circle(fp, t * 0.08, Palette.ACCENT)
		_centered(_caption(), Vector2(a.x + t * (n - 1) / 2.0, a.y + t * 1.45), 38, BEAM)
	# The beam: bright at the lamps, thin air at the far end.
	if _lit > 0:
		var a0 := _road_at(vx)
		var reach := float(_lit) if _demo_t < 0.0 else float(lights)
		var far: float = a0.x + t * (minf(reach, float(n - 1) - vx) + 0.5)
		var near: float = a0.x + t * 0.42
		a = a0
		var flick := 0.92 + 0.08 * sin(_t * 9.0)
		var pts := PackedVector2Array([Vector2(near, a.y - t * 0.12), Vector2(far, a.y - t * 0.4), Vector2(far, a.y + t * 0.4), Vector2(near, a.y + t * 0.12)])
		var cols := PackedColorArray([Color(BEAM, 0.75 * flick), Color(BEAM, 0.06), Color(BEAM, 0.06), Color(BEAM, 0.75 * flick)])
		_root.draw_polygon(pts, cols)
	_draw_hand()


## The demo's hand: it comes down on the van, presses, drags the line along the road, and lifts off at the end.
func _draw_hand() -> void:
	if _demo_t < 0.0 or lights <= 0:
		return
	var t := _road_at(1).x - _road_at(0).x
	var end := float(_road_len() - 1)
	var at_end := 0.4 + end / DRAW_SPEED
	var u := _phase
	var tip := _road_at(_finger)
	var alpha := 1.0
	var press := 1.0
	var off := Vector2.ZERO
	if u < 0.4:
		# Coming down onto the van.
		var k := _out(u / 0.3)
		alpha = k
		off = Vector2(30, 60) * (1.0 - k)
		press = 1.0 if u < 0.3 else 0.92
	elif u < at_end:
		press = 0.92
	else:
		# Let go: up and away.
		var k := clampf((u - at_end) / 0.45, 0.0, 1.0)
		alpha = 1.0 - k
		off = Vector2(30, 70) * k
	if alpha <= 0.0:
		return
	if press < 1.0 and u >= 0.3 and u < at_end:
		# Where it's pressing.
		_root.draw_circle(tip, t * 0.2, Color(1, 1, 1, 0.22 * alpha))
	DrawUtil.hand(_root, tip + off, t * 0.95 * press, alpha)
