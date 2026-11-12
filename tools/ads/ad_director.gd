class_name AdDirector
extends Node2D
## Directs one demo ad over the real game: drives the van, fakes a hand, and draws the ad's captions, stamps,
## coins and the end card. Two cuts of about 30 seconds (-- --ad=fun|bait):
##   fun  - the legit one. Level 4: every package has someone waiting; only the top of the stack can go
##          out (it hops from the stack onto the van, again each time a new one comes up); a finger draws
##          the loop and the van delivers all three. "Seems simple enough..." dissolves to level 45,
##          "...until it isn't.": a missed turn leaves it stuck, going back crashes into its own wreckage,
##          it rewinds, and then the one perfect route goes down in violet fire. The finish dissolves to
##          the end card over the road-trip map. Scenes change by soft dissolves; captions fade.
##   bait - an affectionate parody of ragebait game ads, with a reaction face in the corner. Level 17:
##          "99% FAIL THIS LEVEL!", then the same two intro beats as the legit ad. The NOOB starts well
##          (three deliveries, "YESSS!", IQ up), stops at a fork to think, turns into its own wreckage
##          ("AWW MAN!", red X, sad trombone, IQ 2). The PRO (sunglasses) rewinds it and solves the lot,
##          fast, in fire and coins: "PSHAW. TOO EASY." Then level 45 loads: "WHAAATTT?!" and
##          "CAN YOU DO IT?".
## Beats are timed in frames (30 fps); the video ends `_end_hold` seconds after the end card starts.

signal finished

const FPS := 30.0
const INK := Color(0.1, 0.07, 0.16)
const YELLOW := Color("ffe14d")
const RED := Color("ff2e3e")
const CREAM := Color("f3ead9")
const MUSIC_LEN := 37.0
const HARD_STOP := 40.0

var main: Node
var cut := "fun"
var g: Game

var _frame := 0
var _t := 0.0
var _font: Font
var _captions: Array = []        # {text, t0, t1}
var _hearts_t0 := -1.0
var _hand := {"on": false, "p": Vector2.ZERO, "press": 0.0, "a": 0.0}
var _coins: Array = []
var _floats: Array = []          # {text, p, t0, col}
var _shake := 0.0
var _stamp_t0 := -1.0            # red X + FAIL
var _bait_head_t0 := -1.0
var _end_t0 := -1.0
var _end_van: Van
var _end_fire: AnimeFire
var _fire_last := Vector2.INF
var _tap_t0 := -1.0
var _music: AudioStreamPlayer
var _music_db := -9.0
var _duck := 0.0
var _stop_t := -1.0              # when the video ends (set when the end card starts)
var _end_hold := 2.9             # seconds of end card
var _iq_on := false
var _iq := 100.0
var _iq_target := 100.0
var _iq_y := 1590.0
var _cap_px := 64                # caption text size
var _cap_at := Vector2.INF       # where captions sit (default: just under the board)
var _veil := 0.0                 # 0..1: a sheet of `_veil_col` over everything (scene dissolves)
var _veil_col := CREAM
var _end_map := false            # fun: the end card sits over the road-trip map
var _cam := {}                   # bait: the reaction face {face, name, col, at, r, t0, say, say_t0, say_at, say_px, say_w}
var _alarm := false              # bait: flashing red frame
var _counter_t0 := -1.0          # bait: the fake "LEVEL 9,999" counter spins up from here
var _watch_stack := false        # fly each new top package from the stack to the van
var _stack_n := -1
var _flyers: Array = []          # {col, from, size, t0, dur, landed}
var _rings: Array = []           # {t0, col}: a ring on the van as a flyer lands
var _top_ring_t0 := -1.0         # pulsing ring round the stack's top package
var _marks: Array = []           # {h, glyph, col, t0, life}: little bubbles over houses ("?" or "x")
var _think := {}                 # {t0, at}: the thinking face
var _choice := {}                # {t0, left, right}: flashing "this way or that?" arrows


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ad="):
			cut = a.trim_prefix("--ad=")
	_font = _fredoka()
	# The game is already up (Main started it before this node was added): take hold of it now, so the
	# very first frame (the thumbnail) is already dressed for the ad.
	if main and main.get("screen") is Game:
		g = main.screen
	_music = AudioStreamPlayer.new()
	_music.stream = AdMusic.fun(MUSIC_LEN) if cut == "fun" else AdMusic.bait(MUSIC_LEN)
	_music_db = -9.0 if cut == "fun" else -8.0
	_music.volume_db = _music_db
	add_child(_music)
	_music.play()
	if cut == "fun":
		_run_fun()
	else:
		_run_bait()


func _process(_delta: float) -> void:
	_frame += 1
	_t = _frame / FPS
	if g == null and main and main.get("screen") is Game:
		g = main.screen
	_shake = maxf(0.0, _shake - 1.0 / FPS * 2.5)
	# Music: ducked under the trombone, faded out over the last half second.
	var fade := clampf((_t - (_stop_t - 0.6)) / 0.6, 0.0, 1.0) if _stop_t > 0.0 else 0.0
	_music.volume_db = _music_db + _duck - 40.0 * fade * fade
	_iq = lerpf(_iq, _iq_target, 0.22)
	if g and is_instance_valid(g):
		g.hint_label.visible = false
		g.title_label.visible = false
		if _watch_stack:
			var n: int = g.stack_view.colors.size()
			if _stack_n >= 0 and n < _stack_n and n > 0 and g.state != Game.State.REWINDING:
				_fly_top(0.34)
			_stack_n = n
	for f in _flyers:
		if not f["landed"] and _t >= f["t0"] + f["dur"]:
			f["landed"] = true
			_rings.append({"t0": _t, "col": f["col"]})
			Sfx.play("pop", 1.4, -8.0)
			if g and is_instance_valid(g):
				g.van.nudge()
	_flyers = _flyers.filter(func(f): return not f["landed"])
	_rings = _rings.filter(func(r): return _t - r["t0"] < 0.35)
	_marks = _marks.filter(func(m): return _t - m["t0"] < m["life"])
	if _t > HARD_STOP:
		finished.emit()
	var dt := 1.0 / FPS
	for c in _coins:
		c["v"] += Vector2(0, 2600.0) * dt
		c["p"] += c["v"] * dt
		c["spin"] += c["w"] * dt
	_coins = _coins.filter(func(c): return c["p"].y < 2200.0)
	if _end_van and _end_fire:
		var p := _end_van.position
		if _fire_last == Vector2.INF or p.distance_to(_fire_last) > 30.0:
			_fire_last = p
			_end_fire.emit(p)
	queue_redraw()


func _until(t: float) -> void:
	while _t < t:
		await get_tree().process_frame


func _when(cond: Callable, limit := 6.0) -> void:
	var stop := _t + limit
	while not cond.call() and _t < stop:
		await get_tree().process_frame


## A caption pill from t0 to t1. By default it sits under the board; `at` puts its centre somewhere else.
func _cap(text: String, t0: float, t1: float, at := Vector2.INF) -> void:
	_captions.append({"text": text, "t0": t0, "t1": t1, "at": at})


## A caption starting now for `dur` seconds; whatever caption is up bows out first, so two never overlap.
func _say(text: String, dur: float, at := Vector2.INF) -> void:
	for c in _captions:
		if c["t0"] <= _t and c["t1"] > _t + 0.22:
			c["t1"] = _t + 0.22
	_cap(text, _t + 0.2, _t + 0.2 + dur, at)


## Fades the veil (a flat sheet over the whole frame) to `a`: scene changes happen behind it.
func _veil_to(a: float, dur: float) -> void:
	var from := _veil
	var t0 := _t
	while _t < t0 + dur:
		_veil = lerpf(from, a, _ease((_t - t0) / dur))
		await get_tree().process_frame
	_veil = a


func _hide_ui() -> void:
	for n in [g.bar, g.mode_button, g.actions, g.hint_label, g.title_label, g.momentum_ctl, g.debug_label]:
		n.visible = false


## The two opening beats both ads share: someone's waiting for every package; only the top of the stack
## can go out (it hops onto the van, and the house it's for perks up). Takes 4.7 s.
func _intro_beats() -> void:
	var t := _t
	_cap("Every package has\nsomeone waiting.", t + 0.15, t + 2.1)
	_hearts_t0 = t + 0.3
	await _until(t + 2.1)
	_hearts_t0 = -1.0
	_cap("Only the top of the\nstack can go out.", t + 2.3, t + 4.85)
	await _until(t + 2.4)
	_top_ring_t0 = _t
	await _until(t + 2.8)
	_fly_top(0.6)
	await _until(t + 3.5)
	g.board.house_nodes[_wanting_house()].hop()
	_mark(_wanting_house(), "heart", 1.1)
	await _until(t + 4.7)
	_top_ring_t0 = -1.0


func _frame_wait() -> void:
	await get_tree().process_frame


## The cartoon hand slides in to point at `at`.
func _hand_in(at: Vector2, dur := 0.3) -> void:
	var from := at + Vector2(170, 250)
	_hand = {"on": true, "p": from, "press": 0.0, "a": 0.0}
	var t0 := _t
	while _t < t0 + dur:
		var k := (_t - t0) / dur
		_hand["a"] = minf(1.0, k * 2.0)
		_hand["p"] = from.lerp(at, _ease(k))
		await get_tree().process_frame
	_hand["a"] = 1.0
	_hand["p"] = at


func _hand_out(dur := 0.22) -> void:
	var t0 := _t
	var from: Vector2 = _hand["p"]
	_hand["press"] = 0.0
	while _t < t0 + dur:
		var k := (_t - t0) / dur
		_hand["a"] = 1.0 - k
		_hand["p"] = from + Vector2(130, 190) * _ease(k)
		await get_tree().process_frame
	_hand["on"] = false


# ---------------------------------------------------------------- the two cuts

## Where the stack's top package is, on screen.
func _stack_top_pos() -> Vector2:
	var sv := g.stack_view
	return sv.get_global_transform_with_canvas() * sv._slot(maxi(sv.boxes.size() - 1, 0))


## The top package hops from the stack onto the van: "this is the one that goes out next".
func _fly_top(dur := 0.5) -> void:
	var sv := g.stack_view
	if sv.colors.is_empty():
		return
	_flyers.append({"col": Palette.pkg(sv.colors.back()), "from": _stack_top_pos(), "size": sv.box, "t0": _t, "dur": dur, "landed": false})
	Sfx.play("whoosh", 1.3, -10.0)


func _house_at(p: Vector2i) -> int:
	for h in g.level.houses.size():
		if g.level.houses[h]["pos"] == p:
			return h
	return 0


## The house that wants the package now on top.
func _wanting_house() -> int:
	var top := Sim.top_color(g.level, g.sim_state)
	for h in g.level.houses.size():
		if g.level.houses[h]["color"] == top and g.sim_state["fills"][h] < g.level.houses[h]["order"]:
			return h
	return 0


func _mark(h: int, glyph: String, life := 1.0) -> void:
	_marks.append({"h": h, "glyph": glyph, "col": Palette.pkg(g.level.houses[h]["color"]), "t0": _t, "life": life})


## The hand (already pressed) drags through `pts` (board space), drawing the route as it goes.
func _drag_along(pts: Array, dur: float) -> void:
	var xf := g.board.get_global_transform_with_canvas()
	var t0 := _t
	while _t < t0 + dur:
		var k := (_t - t0) / dur
		var u := (0.75 * k + 0.25 * _ease(k)) * (pts.size() - 1)
		var i := mini(int(u), pts.size() - 2)
		var p: Vector2 = pts[i].lerp(pts[i + 1], u - i)
		g._drag(p)
		_hand["p"] = xf * p
		await get_tree().process_frame
	g._drag(pts.back())
	_hand["p"] = xf * pts.back()


## The hand comes in, presses on the van, draws `tiles`, holds a beat, lets go and leaves.
func _draw_route(tiles: Array, dur: float, hold := 0.18, exact := true) -> void:
	var b := g.board
	var pts: Array = []
	for p in tiles:
		pts.append(b.center(p))
	await _hand_in(b.get_global_transform_with_canvas() * pts[0], 0.25)
	_hand["press"] = 1.0
	g._press(pts[0])
	await _drag_along(pts, dur)
	if exact and g.seg != tiles:
		push_warning("ad: the drawn route didn't match; forcing it")
		g.seg = tiles.duplicate()
	await _until(_t + hold)
	g._release()
	_hand_out()


func _run_fun() -> void:
	await _when(func(): return g != null)
	_hide_ui()
	_end_hold = 3.5
	_watch_stack = true
	var sol: Array = g.solve_info["shortest"]

	# 1. A small level: the hook, the rule, and one clean route.
	await _intro_beats()
	_say("So draw one route\nto deliver them all.", 2.2)
	var c1_end := _t + 2.45
	await _draw_route(sol, 1.0)
	await _when(func(): return g._fired >= 6, 4.0)
	await _until(maxf(_t, c1_end))
	_say("Seems simple enough...", 3.0)
	await _when(func(): return g.state == Game.State.WON, 6.0)
	await _until(_t + 0.28)
	g.process_mode = Node.PROCESS_MODE_DISABLED       # hold the moment (and skip this level's finish screen)
	await _until(_t + 0.3)
	await _veil_to(1.0, 0.45)

	# 2. ...until it isn't: the big one.
	g = null
	_stack_n = -1
	_captions.clear()
	main._start(44)
	await _when(func(): return g != null and is_instance_valid(g), 2.0)
	_hide_ui()
	Progress.undo_bank = 4
	var b := g.board
	sol = g.solve_info["shortest"]
	await _frame_wait()
	_say("...until it isn't.", 2.0)
	await _veil_to(0.0, 0.55)
	await _until(_t + 1.55)

	# 3. A missed turn: three delivered, then nowhere useful to go.
	_say("Plan carefully, or\nyou'll get stuck...", 3.6)
	var wrong: Array = [Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8), Vector2i(7, 7), Vector2i(7, 6), Vector2i(7, 5), Vector2i(7, 4), Vector2i(7, 3)]
	await _draw_route(wrong, 0.8)
	await _when(func(): return g.state == Game.State.IDLE and g.route.size() == wrong.size(), 5.0)
	await _until(_t + 0.35)
	for h in g.level.houses.size():
		if g.sim_state["fills"][h] < g.level.houses[h]["order"]:
			_mark(h, "?", 1.25)
	g.van.shake()
	g.stack_view.flash_remaining()
	Sfx.play("fail", 1.0, -6.0)
	await _until(_t + 1.3)

	# 4. ...or crash: going back for the turn means driving into your own wreckage.
	_say("...or crash.", 2.0)
	await _draw_route([Vector2i(7, 3), Vector2i(7, 4), Vector2i(6, 4)], 0.45, 0.35, false)
	await _when(func(): return g.state == Game.State.FAILED, 3.0)
	await _until(_t + 0.65)

	# 5. Take it back, and find the one perfect route: every turn, bridge and gate, in fire.
	_say("So find the one\nperfect route.", 3.2)
	g.undo()
	await _when(func(): return g.state == Game.State.IDLE, 2.0)
	g.undo()
	await _when(func(): return g.state == Game.State.IDLE, 3.0)
	g.undo_used = false
	Progress.momentum = 9
	b.fire.momentum = 9
	b.wreck.momentum = 9
	await _until(_t + 0.2)
	await _draw_route(sol, 1.8)
	Engine.time_scale = 1.3
	await _when(func(): return g.finish != null, 12.0)
	Engine.time_scale = 1.0
	await _until(_t + 1.7)

	# 6. Dissolve to the end card, over the road-trip map drifting by.
	await _veil_to(1.0, 0.4)
	_watch_stack = false
	g = null
	main.show_select()
	await _frame_wait()
	await _frame_wait()
	var sel: LevelSelect = main.screen
	for ch in sel.get_children():
		if ch != sel.map:
			ch.visible = false
	var map := sel.map
	map.focus(19)
	var s0 := map.scroll
	map.focus(22)
	var s1 := map.scroll
	map.scroll = s0
	_end_map = true
	_start_end()
	_veil_to(0.0, 0.5)
	var tapped := false
	while _t < _stop_t:
		map.set("_vel", 0.0)
		map.scroll = lerpf(s0, s1, (_t - _end_t0) / _end_hold)
		if not tapped and _t >= _end_t0 + 2.3:
			tapped = true
			_tap_t0 = _t
			Sfx.play("click")
		await get_tree().process_frame
	finished.emit()


## The reaction face changes (it pops), and optionally says something (clears what it was saying if not).
func _face(face: String, say := "") -> void:
	_cam["face"] = face
	_cam["t0"] = _t
	_cam["say"] = say
	_cam["say_t0"] = _t


func _run_bait() -> void:
	await _when(func(): return g != null)
	for n in [g.mode_button, g.debug_label]:
		n.visible = false
	Progress.undo_bank = 5
	_end_hold = 3.2
	var b := g.board
	var xf := b.get_global_transform_with_canvas()
	var tile := b.tile
	var sol: Array = g.solve_info["shortest"]
	_iq_y = (xf * Vector2(0, b.size_px().y)).y + 120.0
	_iq_on = true
	_watch_stack = true
	var cam_home := Vector2(935, _iq_y + 250.0)
	_cap_px = 54
	_cap_at = Vector2(515, _iq_y + 190.0)
	_cam = {"face": "🙂", "name": "NOOB", "col": Color("8ea2b6"), "at": cam_home, "r": 118.0, "t0": 0.0,
		"say": "", "say_t0": 0.0, "say_at": cam_home + Vector2(-430, -6), "say_px": 104, "say_w": 540.0}
	_bait_head_t0 = 0.05
	_alarm = true
	_shake = 1.0
	Sfx.play("slam", 1.0, 0.0)
	await _until(1.3)
	_bait_head_t0 = -1.0
	_alarm = false

	# The same opening as the legit ad: what the game is.
	await _intro_beats()

	# The NOOB starts well: round the corner, three deliveries in a row.
	var first: Array = sol.slice(0, 8)
	await _draw_route(first, 0.8)
	await _when(func(): return g._fired >= 5, 4.0)
	_face("😄")
	_iq_target = 124.0
	await _when(func(): return g.state == Game.State.IDLE and g.route.size() == first.size(), 5.0)
	_face("🤩", "YESSS!")
	_iq_target = 152.0
	Sfx.play("star", 1.0, 0.0)
	_floats.append({"text": "+52 IQ", "p": Vector2(670, _iq_y - 110.0), "t0": _t, "col": Palette.GOOD.lightened(0.2), "px": 84, "life": 0.9})
	await _until(_t + 1.05)

	# On to the next fork... where it stops to think. Left: open road. Right: the road it just tore up.
	_face("🙂")
	var c := func(x: int, y: int) -> Vector2: return b.center(Vector2i(x, y))
	var fork: Vector2 = c.call(4, 6)
	await _hand_in(xf * c.call(4, 4), 0.25)
	_hand["press"] = 1.0
	g._press(c.call(4, 4))
	await _drag_along([c.call(4, 4), c.call(4, 5), fork], 0.4)
	_face("🤔")
	_think = {"t0": _t, "at": xf * fork + Vector2(0, -300)}
	_choice = {"t0": _t, "left": xf * c.call(3, 6), "right": xf * c.call(5, 6)}
	Sfx.play("hint", 0.7, -4.0)
	var t0 := _t
	while _t < t0 + 1.4:
		var k := (_t - t0) / 1.4
		_hand["p"] = xf * (fork + Vector2(-0.3 * tile * sin(k * TAU * 1.25), 0))
		await get_tree().process_frame
	_choice = {}
	_think = {}

	# It goes right. The path turns red, there's a warning sign... and it lets go.
	await _drag_along([fork + Vector2(-0.3 * tile, 0), c.call(5, 6)], 0.22)
	_face("😬")
	_iq_target = 31.0
	_shake = 0.7
	Sfx.play("empty", 1.0, 0.0)
	_floats.append({"text": "-121 IQ", "p": Vector2(670, _iq_y - 110.0), "t0": _t, "col": RED, "px": 84, "life": 0.9})
	await _until(_t + 0.8)
	g._release()
	_hand_out(0.15)
	await _when(func(): return g.state == Game.State.FAILED, 5.0)
	_stamp_t0 = _t
	_alarm = true
	_iq_target = 2.0
	_shake = 1.0
	_face("😭", "AWW MAN!")
	Sfx.play("punch", 0.8, 0.0)
	var trombone := AudioStreamPlayer.new()
	trombone.stream = AdMusic.sad_trombone()
	trombone.volume_db = -2.0
	add_child(trombone)
	trombone.play()
	_duck = -12.0
	await _until(_t + 2.0)
	_duck = 0.0
	_stamp_t0 = -1.0
	_alarm = false

	# The PRO takes over: rewinds the lot...
	_cam["name"] = "PRO"
	_cam["col"] = YELLOW
	_face("😎", "PSHAW.")
	Sfx.play("whoosh", 0.8, 0.0)
	_iq_target = 180.0
	for i in 3:
		g.undo()
		await _when(func(): return g.state == Game.State.IDLE, 3.0)
	g.undo_used = false
	Progress.momentum = 8
	b.fire.momentum = 9
	b.wreck.momentum = 9
	await _until(_t + 0.5)
	_face("😎", "TOO EASY.")
	await _until(_t + 0.5)

	# ...and solves it in one go, fast, in fire and coins.
	await _draw_route(sol, 1.2)
	Engine.time_scale = 1.5
	var run_t0 := _t
	var next_coin := _t
	while g.state != Game.State.WON and _t < run_t0 + 7.0:
		_iq_target = lerpf(180.0, 900.0, clampf((_t - run_t0) / 2.6, 0.0, 1.0))
		if _t >= next_coin:
			next_coin = _t + 0.14
			_burst_coins(xf * g.van.position, 4, 900.0)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_iq_target = 999.0
	Sfx.play("kaching", 1.0, 0.0)
	Sfx.play("jingle", 1.2, -2.0)
	_burst_coins(Vector2(540, 900), 40, 2200.0)
	_floats.append({"text": "+999,999", "p": Vector2(540, 760), "t0": _t, "col": YELLOW, "px": 130, "life": 1.3})
	_shake = 0.8
	await _until(_t + 1.6)

	# Next level. It's the big one.
	_veil_col = Color.WHITE
	await _veil_to(1.0, 0.12)
	g = null
	_stack_n = -1
	_watch_stack = false
	_iq_on = false
	_coins.clear()
	_face("😎", "NEXT!")
	main._start(44)
	await _when(func(): return g != null and is_instance_valid(g), 2.0)
	for n in [g.mode_button, g.debug_label]:
		n.visible = false
	_counter_t0 = _t
	Sfx.play("whoosh", 1.1, 0.0)
	await _veil_to(0.0, 0.3)
	await _until(_t + 1.0)
	# ...
	_face("😱")
	_alarm = true
	_shake = 1.0
	Sfx.play("slam", 0.8, 0.0)
	var from_at: Vector2 = _cam["at"]
	t0 = _t
	while _t < t0 + 0.3:
		var k := _out((_t - t0) / 0.3)
		_cam["at"] = from_at.lerp(Vector2(540, 860), k)
		_cam["r"] = lerpf(118.0, 250.0, k)
		await get_tree().process_frame
	_cam["name"] = ""
	_cam["say_at"] = Vector2(540, 1290)
	_cam["say_px"] = 190
	_cam["say_w"] = 1000.0
	_face("😱", "WHAAATTT?!")
	_shake = 1.0
	await _until(_t + 2.2)
	_alarm = false
	_cam = {}

	_start_end()
	await _until(_end_t0 + 1.7)
	_tap_t0 = _t
	Sfx.play("click")
	_burst_coins(Vector2(540, 1480), 24, 1700.0)
	await _until(_stop_t)
	finished.emit()


func _start_end() -> void:
	_end_t0 = _t
	_stop_t = _t + _end_hold
	_hand["on"] = false
	if _end_map:
		return
	Sfx.play("whoosh", 0.9, 0.0)
	_end_fire = AnimeFire.new()
	_end_fire.tile = 190.0
	_end_fire.momentum = 5 if cut == "fun" else 9
	add_child(_end_fire)
	_end_van = Van.new()
	_end_van.follow_progress = false
	_end_van.size = 300.0
	if cut == "bait":
		_end_van.ride = "monster_truck"
		_end_van.topper = "bonkle"
	else:
		_end_van.topper = "soup_bowl"
	_end_van.position = Vector2(-300, 1130)
	add_child(_end_van)
	_end_van.set_top("red")
	var tw := _end_van.create_tween()
	tw.tween_property(_end_van, "position:x", 540.0, 0.85).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_end_van.stop_bounce)
	if cut == "bait":
		_burst_coins(Vector2(540, 400), 30, 1800.0)


func _burst_coins(at: Vector2, n: int, speed: float) -> void:
	for i in n:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		_coins.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(0.4, 1.0) * speed, "spin": randf() * TAU,
			"w": randf_range(-10.0, 10.0), "s": randf_range(46.0, 80.0)})
	if n >= 4:
		Sfx.play("coin", randf_range(0.9, 1.2), -6.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 26.0 * _shake
	if _hearts_t0 >= 0.0 and _t >= _hearts_t0 and g:
		_draw_hearts()
	for c in _captions:
		if _t >= c["t0"] and _t < c["t1"]:
			_caption(c["text"], c["t0"], c["t1"], c["at"])
	if cut == "bait":
		_draw_bait(off)
	if _end_t0 < 0.0:
		_draw_coins()
		_draw_marks()
		_draw_stack_fx()
		_draw_think()
	for f in _floats:
		var k: float = (_t - f["t0"]) / f["life"]
		if k >= 0.0 and k < 1.0:
			var pop := _pop(k * 5.0)
			_outlined(f["text"], f["p"] + Vector2(0, -80.0 * k), f["px"], f["col"], INK, 18, -0.08, pop, 1.0 - maxf(0.0, k - 0.7) / 0.3)
	if _hand["on"]:
		_draw_hand(_hand["p"], _hand["press"], _hand["a"])
	if _end_t0 < 0.0:
		_draw_cam(off)
	if _end_t0 >= 0.0:
		if _end_map:
			_draw_end_map()
		else:
			_draw_end()
	if _veil > 0.001:
		draw_rect(Rect2(0, 0, 1080, 1920), Color(_veil_col, _veil))


func _draw_coins() -> void:
	for c in _coins:
		draw_set_transform(c["p"], c["spin"] * 0.2, Vector2(absf(cos(c["spin"])) * 0.7 + 0.3, 1.0))
		Icons.draw(self, "coin", Vector2.ZERO, c["s"], Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A white rounded caption pill near the top, popping in and fading out.
func _caption(text: String, t0: float, t1: float, at := Vector2.INF) -> void:
	var lines := text.split("\n")
	var px := _cap_px
	var w := 0.0
	for l in lines:
		w = maxf(w, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var h := lines.size() * px * 1.18 + 56.0
	var k := _pop((_t - t0) / 0.3)
	var a := clampf((t1 - _t) / 0.18, 0.0, 1.0)
	var rise := 0.0
	if cut == "fun":
		# No pop: it fades up into place and fades away.
		k = 1.0
		var fade_in := _ease((_t - t0) / 0.35)
		a = minf(fade_in, clampf((t1 - _t) / 0.3, 0.0, 1.0))
		rise = 22.0 * (1.0 - fade_in)
	var top := 1260.0
	if g:
		top = (g.board.get_global_transform_with_canvas() * Vector2(0, g.board.size_px().y)).y + 70.0
	var c := Vector2(650, top + h / 2.0)
	if at != Vector2.INF:
		c = at
	elif _cap_at != Vector2.INF:
		c = _cap_at
	c.y += rise
	draw_set_transform(c, -0.02 if cut == "bait" else 0.0, Vector2.ONE * k)
	var r := Rect2(Vector2(-w / 2.0 - 48, -h / 2.0), Vector2(w + 96, h))
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 10), r.size), Color(0.23, 0.2, 0.27, 0.18 * a), 46)
	DrawUtil.rrect(self, r, Color(1, 1, 1, 0.97 * a), 46)
	for i in lines.size():
		var lw := _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(_font, Vector2(-lw / 2.0, -h / 2.0 + 28 + px * 0.95 + i * px * 1.18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Palette.TEXT, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Speech bubbles with a heart in each house's colour pop up over the houses, one by one.
func _draw_hearts() -> void:
	var xf := g.board.get_global_transform_with_canvas()
	var tile := g.board.tile
	for h in g.board.house_nodes.size():
		var k := _pop((_t - _hearts_t0 - h * 0.09) / 0.3)
		if k <= 0.01:
			continue
		var house: Node2D = g.board.house_nodes[h]
		var c := xf * (house.position + Vector2(0, -tile * 0.95)) + Vector2(0, -6.0 * sin(_t * 6.0 + h))
		var r := tile * 0.36 * k
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.12))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, r * 0.7), c + Vector2(r * 0.1, r * 1.35), c + Vector2(r * 0.35, r * 0.6)]), Color.WHITE)
		draw_circle(c, r, Color.WHITE)
		_heart(c + Vector2(0, r * 0.05), r * 0.5, Palette.pkg(g.level.houses[h].color))


func _heart(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, -r * 0.25), r * 0.56, col)
	draw_circle(c + Vector2(r * 0.5, -r * 0.25), r * 0.56, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.04, -r * 0.08), c + Vector2(r * 1.04, -r * 0.08), c + Vector2(0, r * 1.1)]), col)


func _draw_bait(off: Vector2) -> void:
	if _end_t0 < 0.0:
		# The fake level counter over the real one, spinning up to an absurd number.
		if _counter_t0 >= 0.0:
			var n := int(lerpf(18.0, 9999.0, pow(clampf((_t - _counter_t0) / 0.9, 0.0, 1.0), 0.35)))
			var label := "LEVEL %s" % Progress.commas(n)
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x + 70
			var r := Rect2(Vector2(540 - w / 2.0, 42), Vector2(w, 112))
			DrawUtil.rrect(self, r.grow(8), Color.WHITE, 60)
			DrawUtil.rrect(self, r, RED, 56)
			draw_string(_font, Vector2(540 - (w - 70) / 2.0, 120), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color.WHITE)
		# Flashing red frame, for the dramatic bits.
		if _alarm and int(_t * 8.0) % 2 == 0:
			var e := 22.0
			for rr in [Rect2(0, 0, 1080, e), Rect2(0, 1920 - e, 1080, e), Rect2(0, 0, e, 1920), Rect2(1080 - e, 0, e, 1920)]:
				draw_rect(rr, Color(RED, 0.9))
	if _iq_on and _end_t0 < 0.0:
		_draw_iq(off)
	if _bait_head_t0 >= 0.0:
		var k := _pop((_t - _bait_head_t0) / 0.28)
		var big := 1.0 + 1.6 * maxf(0.0, 1.0 - (_t - _bait_head_t0) / 0.18)
		_outlined("99% FAIL", Vector2(540, 620) + off, 190, YELLOW, RED.darkened(0.35), 30, -0.09, k * big)
		_outlined("THIS LEVEL!", Vector2(540, 810) + off, 150, Color.WHITE, RED.darkened(0.35), 28, -0.09, k * big)
	if _stamp_t0 >= 0.0 and g:
		var bc := g.board.get_global_transform_with_canvas() * (g.board.size_px() / 2.0) + off
		var s := 330.0
		for i in 2:
			var k := clampf((_t - _stamp_t0 - i * 0.12) / 0.12, 0.0, 1.0)
			if k <= 0.0:
				continue
			var a := bc + Vector2(-s if i == 0 else s, -s)
			var b := a.lerp(bc + Vector2(s if i == 0 else -s, s), k)
			draw_line(a, b, Color.WHITE, 120.0, true)
			draw_circle(a, 60.0, Color.WHITE)
			draw_circle(b, 60.0, Color.WHITE)
			draw_line(a, b, RED, 86.0, true)
			draw_circle(a, 43.0, RED)
			draw_circle(b, 43.0, RED)
		var ks := clampf((_t - _stamp_t0 - 0.3) / 0.14, 0.0, 1.0)
		if ks > 0.0:
			var sc := lerpf(2.4, 1.0, ks)
			draw_set_transform(bc + Vector2(0, 470), -0.14, Vector2.ONE * sc)
			var r := Rect2(-300, -110, 600, 220)
			DrawUtil.rrect(self, r.grow(14), Color(1, 1, 1, ks), 40)
			DrawUtil.rrect(self, r, Color(RED, ks), 32)
			var fw := _font.get_string_size("FAIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 190).x
			draw_string(_font, Vector2(-fw / 2.0, 66), "FAIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 190, Color(1, 1, 1, ks))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The IQ meter under the board: about 100, plummets to 2 on the crash, rockets past 900 for the genius.
func _draw_iq(off: Vector2) -> void:
	var v := _iq + (sin(_t * 23.0) * 3.0 if _iq > 20.0 else 0.0)
	var low := v < 40.0
	var c := Vector2(670, _iq_y) + (off * 0.6 if low else Vector2.ZERO)
	var r := Rect2(c - Vector2(370, 56), Vector2(740, 112))
	var flash := low and int(_t * 9.0) % 2 == 0
	DrawUtil.rrect(self, r.grow(9), Color.WHITE, 64)
	DrawUtil.rrect(self, r, RED.darkened(0.2) if flash else INK, 56)
	draw_string(_font, r.position + Vector2(36, 80), "IQ", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, YELLOW)
	var track := Rect2(r.position + Vector2(150, 34), Vector2(330, 44))
	DrawUtil.rrect(self, track, Color(1, 1, 1, 0.18), 22)
	var k := clampf(v / 200.0, 0.03, 1.0)
	var col := RED.lerp(YELLOW, clampf(k * 2.0, 0.0, 1.0)).lerp(Palette.GOOD, clampf(k * 2.0 - 1.0, 0.0, 1.0))
	if v > 200.0:
		col = Color.from_hsv(fmod(_t * 2.0, 1.0), 0.75, 1.0)
	DrawUtil.rrect(self, Rect2(track.position, Vector2(maxf(track.size.x * k, 44.0), track.size.y)), col, 22)
	var num := str(int(round(v))) + ("+" if v > 950.0 else "")
	var px := 84
	var nw := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, Vector2(r.end.x - 36 - nw, r.position.y + 86), num, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE if not low else YELLOW)


## Little bubbles over houses: a heart, a "?" (out of reach) or a red x (not your turn).
func _draw_marks() -> void:
	if g == null or not is_instance_valid(g):
		return
	var xf := g.board.get_global_transform_with_canvas()
	var tile := g.board.tile
	for m in _marks:
		var age: float = _t - m["t0"]
		var k := _pop(age / 0.25)
		var a := clampf((m["life"] - age) / 0.18, 0.0, 1.0)
		var house: Node2D = g.board.house_nodes[m["h"]]
		var c := xf * (house.position + Vector2(0, -tile * 0.95)) + Vector2(0, -6.0 * sin(_t * 6.0 + m["h"]))
		var r := tile * 0.36 * k
		if r < 2.0:
			continue
		draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.12 * a))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, r * 0.7), c + Vector2(r * 0.1, r * 1.35), c + Vector2(r * 0.35, r * 0.6)]), Color(1, 1, 1, a))
		draw_circle(c, r, Color(1, 1, 1, a))
		match m["glyph"]:
			"heart":
				_heart(c + Vector2(0, r * 0.05), r * 0.5, Color(m["col"], a))
			"x":
				for sx in [-1.0, 1.0]:
					draw_line(c + Vector2(-sx, -1) * r * 0.42, c + Vector2(sx, 1) * r * 0.42, Color(RED, a), r * 0.26, true)
			_:
				var px := int(r * 1.5)
				var w := _font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				draw_string(_font, c + Vector2(-w / 2.0, px * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(m["col"].darkened(0.1), a))


## The stack's top package: a pulsing ring round it, and its hop over to the van.
func _draw_stack_fx() -> void:
	if g == null or not is_instance_valid(g):
		return
	if _top_ring_t0 >= 0.0:
		var c := _stack_top_pos()
		var r := g.stack_view.box * (0.86 + 0.08 * sin((_t - _top_ring_t0) * 11.0))
		draw_arc(c, r + 16.0, 0, TAU, 48, Color(Palette.ACCENT, 0.3), 8.0, true)
		draw_arc(c, r, 0, TAU, 48, Palette.ACCENT, 10.0, true)
	var to: Vector2 = g.board.get_global_transform_with_canvas() * g.van.position
	for f in _flyers:
		var k := clampf((_t - f["t0"]) / f["dur"], 0.0, 1.0)
		var from: Vector2 = f["from"]
		var lift := 180.0 + from.distance_to(to) * 0.2
		for j in [4, 3, 2, 1, 0]:
			var kk := maxf(0.0, k - j * 0.045)
			var e := _ease(kk)
			var p := from.lerp(to, e) + Vector2(0, -lift * sin(PI * kk))
			var sz := lerpf(f["size"], g.board.tile * 0.36, e) * (1.0 + 0.4 * sin(PI * kk))
			if j == 0:
				DrawUtil.package(self, p, sz, f["col"])
			else:
				draw_circle(p, sz * 0.34 * (1.0 - j * 0.15), Color(f["col"], 0.4 - j * 0.08))
	for r in _rings:
		var k: float = (_t - r["t0"]) / 0.35
		draw_arc(to, g.board.tile * (0.3 + 0.5 * k), 0, TAU, 40, Color(r["col"], 1.0 - k), 12.0 * (1.0 - k) + 2.0, true)


## The thinking face, and the "this way or that?" arrows at a fork.
func _draw_think() -> void:
	if not _choice.is_empty():
		var left_on := int((_t - _choice["t0"]) * 5.0) % 2 == 0
		var wob := 10.0 * sin(_t * 18.0)
		if left_on:
			_arrow(_choice["left"] + Vector2(-50 - wob, 0), Vector2(-1, 0), 0.75, false)
		else:
			_arrow(_choice["right"] + Vector2(50 + wob, 0), Vector2(1, 0), 0.75, false)
	if _think.is_empty():
		return
	var k := _pop((_t - _think["t0"]) / 0.25)
	var px := int(230.0 * k)
	if px < 8:
		return
	var at: Vector2 = _think["at"] + Vector2(0, -10.0 * sin(_t * 6.0))
	var w := _font.get_string_size("🤔", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_set_transform(at, 0.1 * sin(_t * 4.0), Vector2.ONE)
	draw_circle(Vector2(0, 14), px * 0.52, Color(0, 0, 0, 0.18))
	draw_string(_font, Vector2(-w / 2.0, px * 0.36), "🤔", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The reaction face: a "player cam" bubble with an emoji, a name tag and whatever it's shouting.
func _draw_cam(off: Vector2) -> void:
	if _cam.is_empty():
		return
	var at: Vector2 = _cam["at"] + off * 0.5
	var r: float = _cam["r"]
	var k := _pop((_t - _cam["t0"]) / 0.25)
	draw_circle(at + Vector2(0, 12), r + 16, Color(0, 0, 0, 0.22))
	draw_circle(at, r + 16, Color.WHITE)
	draw_circle(at, r, _cam["col"])
	var face: String = _cam["face"]
	var px := int(r * 1.62 * (0.72 + 0.28 * k))
	var w := _font.get_string_size(face, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, at + Vector2(-w / 2.0, px * 0.36 + 4.0 * sin(_t * 9.0)), face, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	var tag: String = _cam["name"]
	if tag != "":
		var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x + 56.0
		var tr := Rect2(at.x - tw / 2.0, at.y + r - 10.0, tw, 74)
		DrawUtil.rrect(self, tr.grow(8), INK, 30)
		DrawUtil.rrect(self, tr, _cam["col"], 24)
		draw_string(_font, tr.position + Vector2(28, 54), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, INK if tag == "PRO" else Color.WHITE)
	var say: String = _cam["say"]
	if say != "":
		var sk := _pop((_t - _cam["say_t0"]) / 0.25)
		_outlined(say, _cam["say_at"] + off, _cam["say_px"], YELLOW, INK, 24, -0.06, sk, 1.0, _cam["say_w"])


## A chunky flashing yellow arrow, tip at `tip`, pointing along `dir`.
func _arrow(tip: Vector2, dir: Vector2, s: float, flash := true) -> void:
	if flash and int(_t * 7.0) % 2 == 1:
		return
	var side := Vector2(-dir.y, dir.x)
	var L := 190.0 * s
	var pts := PackedVector2Array([tip, tip - dir * L * 0.5 + side * L * 0.42, tip - dir * L * 0.5 + side * L * 0.17,
		tip - dir * L + side * L * 0.17, tip - dir * L - side * L * 0.17, tip - dir * L * 0.5 - side * L * 0.17,
		tip - dir * L * 0.5 - side * L * 0.42])
	var outline := PackedVector2Array()
	var mid := tip - dir * L * 0.55
	for p in pts:
		outline.append(mid + (p - mid) * 1.16)
	draw_colored_polygon(outline, INK)
	draw_colored_polygon(pts, YELLOW)


## A cartoon pointing hand in a white glove, fingertip at `tip`.
func _draw_hand(tip: Vector2, press: float, a: float) -> void:
	var sc := 1.0 - 0.08 * press
	draw_set_transform(tip + Vector2(10, 16), -0.42, Vector2.ONE * sc)
	_hand_shape(Color(0, 0, 0, 0.18 * a), 0.0)
	draw_set_transform(tip, -0.42, Vector2.ONE * sc)
	_hand_shape(Color(INK, a), 9.0)
	_hand_shape(Color(1, 1, 1, a), 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if press > 0.0:
		draw_arc(tip, 46.0 + 8.0 * sin(_t * 14.0), 0, TAU, 32, Color(1, 1, 1, 0.8 * a), 8.0, true)


func _hand_shape(col: Color, grow: float) -> void:
	DrawUtil.rrect(self, Rect2(-30, -6, 60, 170).grow(grow), col, 30 + grow)
	DrawUtil.rrect(self, Rect2(-62, 104, 178, 160).grow(grow), col, 62 + grow)
	for k in 3:
		draw_circle(Vector2(52 + k * 26, 118 + k * 10), 30 + grow, col)
	draw_colored_polygon(_ellipse(Vector2(-60, 170), 40 + grow, 26 + grow, -0.9), col)
	DrawUtil.rrect(self, Rect2(-46, 250, 150, 70).grow(grow), col, 26 + grow)


func _ellipse(c: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 20:
		var ang := TAU * k / 20.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry).rotated(rot))
	return pts


func _draw_end() -> void:
	var k := clampf((_t - _end_t0) / 0.35, 0.0, 1.0)
	var c := Vector2(540, 960)
	var rad := 2300.0 * _out(k)
	var bg := CREAM if cut == "fun" else Color("2a1650")
	draw_circle(c, rad, bg)
	if k < 1.0:
		return
	var t := _t - _end_t0
	# Rays.
	var ray := Color(Palette.ACCENT, 0.08) if cut == "fun" else Color(YELLOW, 0.13)
	var spin := t * (0.25 if cut == "fun" else 1.2)
	for i in 16:
		var a0 := spin + TAU * i / 16.0
		var a1 := a0 + TAU / 32.0
		draw_colored_polygon(PackedVector2Array([Vector2(540, 900), Vector2(540, 900) + Vector2(cos(a0), sin(a0)) * 2400.0,
			Vector2(540, 900) + Vector2(cos(a1), sin(a1)) * 2400.0]), ray)
	# Coins fall behind the words and the button.
	_draw_coins()
	# Road strip the van arrives on.
	draw_rect(Rect2(0, 1060, 1080, 140), Color("596273"))
	draw_rect(Rect2(0, 1060, 1080, 10), Color("444b59"))
	for i in 9:
		draw_rect(Rect2(i * 140 - fmod(t * 0.0, 140.0) + 20, 1125, 70, 10), Color(1, 1, 1, 0.5))
	if cut == "fun":
		# Three parcels bouncing in, one per beat.
		var cols := ["red", "yellow", "blue"]
		for i in 3:
			var pk := _pop((t - 0.25 - i * 0.1) / 0.35)
			if pk > 0.01:
				var hop := absf(sin(t * 5.0 + i * 1.1)) * 26.0
				DrawUtil.package(self, Vector2(400 + i * 140, 330 - hop), 110.0 * pk, Palette.pkg(cols[i]))
		var tk := _pop((t - 0.15) / 0.4)
		_titled("Last Mile", Vector2(540, 560), 200, Palette.TEXT, tk)
		var gk := clampf((t - 0.45) / 0.3, 0.0, 1.0)
		_center_text("Plan the route. Burn the road.", Vector2(540, 720), 56, Color(Palette.TEXT, 0.7 * gk))
	else:
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0
		var tk := _pop((t - 0.05) / 0.3)
		var flash := YELLOW if int(_t * 8.0) % 2 == 0 else Color.WHITE
		_outlined("CAN YOU", Vector2(540, 470) + off, 170, flash, INK, 30, -0.07, tk)
		_outlined("DO IT?", Vector2(540, 680) + off, 210, flash, INK, 34, -0.07, tk)
		_titled("Last Mile", Vector2(540, 880), 96, Color.WHITE, _pop((t - 0.3) / 0.3))
	_draw_cta(t, 0.6, 0.9, Vector2(540, 1440))
	_center_text("a Door Bowl game", Vector2(540, 1760), 42, Color(Palette.TEXT, 0.6) if cut == "fun" else Color(1, 1, 1, 0.7))


## The "Playtest now" button (it pops in at `cta_at`), and the hand that comes in at `hand_at` to tap it.
func _draw_cta(t: float, cta_at: float, hand_at: float, bc: Vector2) -> void:
	var bk := _pop((t - cta_at) / 0.35)
	var breathe := 1.0 + 0.04 * sin(t * 6.0)
	var press := 0.0
	if _tap_t0 >= 0.0:
		press = clampf(1.0 - absf(_t - _tap_t0 - 0.1) / 0.1, 0.0, 1.0)
	draw_set_transform(bc, 0.0, Vector2.ONE * bk * breathe * (1.0 - 0.07 * press))
	var r := Rect2(-340, -95, 680, 190)
	var btn := Palette.ACCENT if cut == "fun" else Palette.GOOD
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 16), r.size), btn.darkened(0.3), 95)
	DrawUtil.rrect(self, r, btn, 95)
	var label := "Playtest now"
	var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	Icons.draw(self, "play", Vector2(-lw / 2.0 - 30, 0), 64, Color.WHITE)
	draw_string(_font, Vector2(-lw / 2.0 + 20, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _tap_t0 >= 0.0:
		var rk := clampf((_t - _tap_t0) / 0.5, 0.0, 1.0)
		draw_arc(bc, 340.0 + 120.0 * rk, 0, TAU, 64, Color(btn, 1.0 - rk), 14.0, true)
	if cut == "bait" and bk > 0.5:
		_arrow(bc + Vector2(-420, 12 * sin(_t * 20.0)), Vector2(1, 0), 0.8)
		_arrow(bc + Vector2(420, 12 * sin(_t * 20.0)), Vector2(-1, 0), 0.8)
	var hk := clampf((t - hand_at) / 0.5, 0.0, 1.0)
	if hk > 0.0:
		var tip := (bc + Vector2(340, 80)).lerp(bc + Vector2(290, 55), _ease(hk)) + Vector2(260, 330) * (1.0 - _ease(hk))
		_draw_hand(tip, press, minf(1.0, hk * 3.0))


## The legit end card, over the road-trip map: a cream wash with a clearer window across the middle where the
## road drifts by, the title above it and the button below. Everything fades in; nothing slams.
func _draw_end_map() -> void:
	var t := _t - _end_t0
	var top := 860.0
	var bot := 1330.0
	var band := 110.0
	var steps := 11
	draw_rect(Rect2(0, 0, 1080, top), Color(CREAM, 0.9))
	draw_rect(Rect2(0, bot, 1080, 1920.0 - bot), Color(CREAM, 0.9))
	for i in steps:
		var a := lerpf(0.9, 0.08, (i + 1.0) / steps)
		draw_rect(Rect2(0, top + i * band / steps, 1080, band / steps + 1.0), Color(CREAM, a))
		draw_rect(Rect2(0, bot - (i + 1) * band / steps, 1080, band / steps + 1.0), Color(CREAM, a))
	draw_rect(Rect2(0, top + band, 1080, bot - top - 2.0 * band), Color(CREAM, 0.08))
	var cols := ["red", "yellow", "blue"]
	for i in 3:
		var pk := _pop((t - 0.5 - i * 0.12) / 0.4)
		if pk > 0.01:
			var hop := absf(sin(t * 4.0 + i * 1.1)) * 22.0
			DrawUtil.package(self, Vector2(400 + i * 140, 290 - hop), 110.0 * pk, Palette.pkg(cols[i]))
	_titled("Last Mile", Vector2(540, 510), 200, Color(Palette.TEXT, clampf((t - 0.3) / 0.5, 0.0, 1.0)), 1.0)
	_center_text("Plan the route. Burn the road.", Vector2(540, 672), 56, Color(Palette.TEXT, 0.75 * clampf((t - 0.7) / 0.4, 0.0, 1.0)))
	_center_text("45 stops  ·  a daily puzzle  ·  hidden presents", Vector2(540, 772), 45, Color(Palette.TEXT, 0.82 * clampf((t - 1.0) / 0.4, 0.0, 1.0)))
	_draw_cta(t, 1.2, 1.75, Vector2(540, 1510))
	_center_text("a Door Bowl game", Vector2(540, 1770), 42, Color(Palette.TEXT, 0.6 * clampf((t - 1.2) / 0.4, 0.0, 1.0)))


# ---------------------------------------------------------------- text

func _fredoka() -> Font:
	var path := "res://assets/fonts/Fredoka.ttf"
	if not ResourceLoader.exists(path):
		return UiTheme.font()
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	return f


func _center_text(text: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## The game's title look: big Fredoka with a soft drop shadow.
func _titled(text: String, at: Vector2, px: int, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	draw_set_transform(at, 0.0, Vector2.ONE * k)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, Vector2(-w / 2.0, px * 0.35 + 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.23, 0.2, 0.27, 0.16 * col.a))
	draw_string(_font, Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mobile-ad text: thick outline, slanted, scaled about its centre.
func _outlined(text: String, at: Vector2, px: int, fill: Color, outline: Color, ow: int, rot: float, k: float, alpha := 1.0, maxw := 1000.0) -> void:
	if k <= 0.01 or alpha <= 0.0:
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var fit := minf(1.0, maxw / maxf(w, 1.0))
	draw_set_transform(at, rot, Vector2.ONE * k * fit)
	var p := Vector2(-w / 2.0, px * 0.35)
	draw_string_outline(_font, p + Vector2(0, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow, Color(0, 0, 0, 0.3 * alpha))
	draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow, Color(outline, alpha))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(fill, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


func _out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)
