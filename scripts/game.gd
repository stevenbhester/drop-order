class_name Game
extends Node2D
## One level being played: input -> segments, driving, deliveries, undo, win/fail, UI.
## Rules come from Sim, visuals from Board/Van/House/Shop/Gate/StackView.
##
## The player builds the route in segments: press on the van, drag, lift -> the van drives
## that segment immediately. They continue from wherever it stopped. Undo rewinds the last
## segment (packages come back) and can be used once per attempt.
##
## Sim updates instantly as the van reaches each tile; the matching animations (packages
## flying, the stack view changing) run on a small timeline so they always play in rule
## order even when several happen close together.

signal menu_requested
signal level_requested(index: int)
signal segment_finished

enum State { IDLE, DRAWING, DRIVING, REWINDING, WON, FAILED }

const DRIVE_SPEED := 7.0         # tiles per second at cruise
const REWIND_SPEED := 16.0
const RAMP := 0.6                # tiles spent accelerating / braking
const TOP_BAR := 170.0
const BOTTOM_MIN := 400.0
const UNDOS_PER_ATTEMPT := 1
const FLY_TIME := 0.25
const COMBO_STEPS := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]

var level: LevelData
var index := 0
var total := 0
var solve_info := {}
var state := State.IDLE

var board: Board
var van: Van
var stack_view: StackView
var confetti: Confetti
var ghost: GhostFinger

var route: Array = []            # Vector2i: everything driven so far; route[0] = start
var seg: Array = []              # segment being drawn/driven; seg[0] = route.back()
var seg_states: Array = []       # predicted Sim state after each tile of `seg` (while drawing)
var history: Array = []          # per driven segment: { "len", "state", "rot" } before it
var undo_left := UNDOS_PER_ATTEMPT
var sim_state: Dictionary
var combo := 0
var _fired := 0
var _drive_len := 0.0
var _vis_cursor := 0.0           # timeline: when the next stack animation may start (s)
var _effects_end := 0.0          # timeline: when the last scheduled animation finishes (s)
var _denied := Vector2i(-99, -99)

var _top_inset := 0.0
var _bottom_inset := 0.0
var level_label: Label
var hint_label: Label
var debug_label: Label
var result_box: VBoxContainer
var result_label: Label
var result_button: Button
var undo_button: Button


func setup(lvl: LevelData, idx: int, count: int, solved: Dictionary) -> void:
	level = lvl
	index = idx
	total = count
	solve_info = solved


func _ready() -> void:
	sim_state = Sim.new_state(level)
	route = [level.start]
	_compute_insets()
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_undo()
	board.update_gates(Sim.top_color(level, sim_state), true)
	DebugAuto.maybe_run(self)


# ---------------------------------------------------------------- building

func _compute_insets() -> void:
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return
	var k := get_viewport_rect().size.x / float(win.x)
	_top_inset = safe.position.y * k
	_bottom_inset = maxf(0.0, (win.y - safe.end.y) * k)


func _build_world() -> void:
	var vp := get_viewport_rect().size
	var avail_h := vp.y - TOP_BAR - _top_inset - BOTTOM_MIN - _bottom_inset - 40.0
	var tile := minf((vp.x - 90.0) / level.width, avail_h / level.height)
	tile = minf(tile, 230.0)

	board = Board.new()
	add_child(board)
	board.setup(level, tile)

	if level.number == 1 and not solve_info.get("shortest", []).is_empty():
		ghost = GhostFinger.new()
		ghost.radius = tile * 0.22
		for p in solve_info["shortest"]:
			ghost.pts.append(board.center(p))
		board.add_child(ghost)

	van = Van.new()
	van.size = tile
	van.position = board.center(level.start)
	van.target_rotation = _initial_heading()
	board.add_child(van)
	van.set_top(Sim.top_color(level, sim_state))
	van.inviting = true

	stack_view = StackView.new()
	add_child(stack_view)
	var bottom_h := vp.y - (TOP_BAR + _top_inset + 30.0) - level.height * tile - tile * 0.2 - 50.0 - _bottom_inset
	var cap := level.stack.size() + level.shops.size()
	var n := maxf(cap, 1)
	stack_view.setup(level.stack, clampf((bottom_h - 30.0) / (1.14 * n + 0.69), 28.0, 84.0), cap)

	confetti = Confetti.new()
	confetti.z_index = 50
	add_child(confetti)


func _initial_heading() -> float:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		if level.is_road(level.start + d):
			return Vector2(d).angle()
	return 0.0


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	ui.add_child(root)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 40
	bar.offset_right = -40
	bar.offset_top = 40 + _top_inset
	bar.offset_bottom = 40 + _top_inset + 110
	root.add_child(bar)

	var menu_btn := Button.new()
	menu_btn.text = "Levels"
	menu_btn.custom_minimum_size.x = 230
	menu_btn.pressed.connect(func():
		Sfx.play("click")
		menu_requested.emit())
	bar.add_child(menu_btn)

	level_label = Label.new()
	level_label.text = "Level %d" % level.number
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 60)
	bar.add_child(level_label)

	var retry_btn := Button.new()
	retry_btn.text = "Retry"
	retry_btn.custom_minimum_size.x = 230
	retry_btn.pressed.connect(func():
		Sfx.play("click")
		_retry())
	bar.add_child(retry_btn)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 26)
	debug_label.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	debug_label.text = "DEBUG  solver: " + Solver.describe(level, solve_info) if not solve_info.is_empty() else ""
	debug_label.visible = OS.is_debug_build()
	debug_label.position = Vector2(44, 160 + _top_inset)
	root.add_child(debug_label)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 40)
	hint_label.add_theme_color_override("font_color", Palette.TEXT)
	var title := ("“%s”\n" % level.title) if level.title != "" else ""
	var default_hint := "Deliver everything, then park at the depot." if level.return_depot else "Drag a route from the van."
	hint_label.text = title + (level.hint if level.hint != "" else default_hint)
	root.add_child(hint_label)

	undo_button = Button.new()
	undo_button.add_theme_font_size_override("font_size", 44)
	undo_button.pressed.connect(func():
		Sfx.play("click")
		undo())
	root.add_child(undo_button)

	result_box = VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 18)
	result_box.visible = false
	root.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 50)
	result_box.add_child(result_label)
	result_button = Button.new()
	result_button.add_theme_font_size_override("font_size", 54)
	result_button.custom_minimum_size = Vector2(400, 112)
	result_button.pressed.connect(_on_result_pressed)
	result_box.add_child(result_button)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var bsz := board.size_px()
	var top := TOP_BAR + _top_inset + 30.0
	board.position = Vector2(round((vp.x - bsz.x) / 2.0), top)
	var board_bottom := top + bsz.y + board.tile * 0.2
	var bottom := vp.y - _bottom_inset - 50.0
	var area_h := bottom - board_bottom
	stack_view.position = Vector2(40 + stack_view.box * 0.75, bottom - 30)
	var right_x := stack_view.position.x + stack_view.box * 2.3 + 40.0
	var right_w := vp.x - right_x - 40.0
	undo_button.size = Vector2(300, 110)
	undo_button.position = Vector2(vp.x - 40 - 300, bottom - 110)
	hint_label.position = Vector2(right_x, board_bottom + 16)
	hint_label.size = Vector2(right_w, area_h - 140)
	result_box.position = Vector2(right_x, board_bottom + 4)
	result_box.size = Vector2(right_w, area_h - 130)
	result_box.pivot_offset = result_box.size / 2.0


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_retry()
			KEY_Z, KEY_U, KEY_BACKSPACE:
				undo()
			KEY_N, KEY_ENTER, KEY_SPACE:
				if state == State.WON:
					_next()
				elif state == State.FAILED:
					_retry()
			KEY_ESCAPE:
				menu_requested.emit()
			KEY_F3, KEY_D:
				debug_label.visible = not debug_label.visible
			KEY_S:
				if OS.is_debug_build() and route.size() == 1:
					drive_tiles(solve_info.get("shortest", []))
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var lp: Vector2 = board.make_input_local(event).position
		if event.pressed:
			_press(lp)
		else:
			_release()
	elif event is InputEventMouseMotion and state == State.DRAWING:
		_drag(board.make_input_local(event).position)


func _press(lp: Vector2) -> void:
	if state != State.IDLE:
		return
	var here: Vector2i = route.back()
	var on_van := board.tile_at(lp) == here or lp.distance_to(board.center(here)) < board.tile * 0.75
	if not on_van:
		if Rect2(Vector2.ZERO, board.size_px()).grow(board.tile).has_point(lp):
			van.nudge()
			Sfx.play("untick", 0.8, -6)
		return
	state = State.DRAWING
	seg = [here]
	seg_states = [Sim.copy_state(sim_state)]
	_denied = Vector2i(-99, -99)
	van.inviting = false
	van.nudge()
	if ghost:
		ghost.visible = false
	_fade(hint_label, 0.35)
	board.show_path(seg)
	Sfx.play("tick", 0.85)
	Sfx.haptic(8)


func _full() -> Array:
	return route + seg.slice(1)


func _can(next: Vector2i) -> bool:
	return Sim.can_extend(level, _full(), next, seg_states.back())


func _drag(lp: Vector2) -> void:
	var last: Vector2i = seg.back()
	# Hysteresis: stay on the current tile until the finger is clearly out of it.
	var off := (lp - board.center(last)).abs()
	if maxf(off.x, off.y) < board.tile * 0.58:
		return
	var target := board.tile_at(lp)
	var guard := 0
	while target != seg.back() and guard < 24:
		guard += 1
		var cur: Vector2i = seg.back()
		# Dragging back over the segment retracts it (finished segments are locked).
		if seg.size() >= 2 and target == seg[seg.size() - 2]:
			_retract()
			continue
		var diff := target - cur
		if absi(diff.x) + absi(diff.y) == 1:
			if _can(target):
				_extend(target)
				continue
			_maybe_deny(target)
		var at := seg.find(target)
		if at >= 0:
			while seg.size() > at + 1:
				_retract()
			break
		var steps: Array = [Vector2i(signi(diff.x), 0), Vector2i(0, signi(diff.y))]
		if absi(diff.y) > absi(diff.x):
			steps.reverse()
		var moved := false
		for s in steps:
			if s == Vector2i.ZERO:
				continue
			var nxt: Vector2i = cur + s
			if seg.size() >= 2 and nxt == seg[seg.size() - 2]:
				continue
			if _can(nxt):
				_extend(nxt)
				moved = true
				break
		if not moved:
			break


## Bumping into a closed gate: it rattles (once per attempt at that tile).
func _maybe_deny(t: Vector2i) -> void:
	if t == _denied or not board.gate_nodes.has(t):
		return
	_denied = t
	board.gate_nodes[t].deny()
	Sfx.play("bonk", 1.3, -8)
	Sfx.haptic(10)


func _extend(t: Vector2i) -> void:
	var st := Sim.copy_state(seg_states.back())
	Sim.arrive(level, st, t)
	seg.append(t)
	seg_states.append(st)
	board.show_path(seg)
	board.update_gates(Sim.top_color(level, st))
	Sfx.play("tick", 1.0 + minf(seg.size(), 24) * 0.015, -2)
	Sfx.haptic(6)


func _retract() -> void:
	seg.pop_back()
	seg_states.pop_back()
	_denied = Vector2i(-99, -99)
	board.show_path(seg)
	board.update_gates(Sim.top_color(level, seg_states.back()))
	Sfx.play("untick", 1.0, -4)
	Sfx.haptic(4)


func _release() -> void:
	if state != State.DRAWING:
		return
	if seg.size() < 2:
		state = State.IDLE
		seg = []
		board.show_path(seg)
		board.update_gates(Sim.top_color(level, sim_state))
		van.inviting = true
		if ghost and route.size() == 1:
			ghost.visible = true
		if route.size() == 1:
			_fade(hint_label, 1.0)
		return
	_drive()


## Drives `tiles` (which must start at the van) as one segment. Used by debug/autotests.
func drive_tiles(tiles: Array) -> void:
	if state != State.IDLE or tiles.size() < 2 or tiles[0] != route.back():
		return
	seg = tiles.duplicate()
	van.inviting = false
	if ghost:
		ghost.visible = false
	hint_label.modulate.a = 0.35
	board.show_path(seg)
	_drive()


# ---------------------------------------------------------------- driving

func _drive() -> void:
	state = State.DRIVING
	history.append({"len": route.size(), "state": Sim.copy_state(sim_state), "rot": van.target_rotation})
	combo = 0
	_fired = 0
	_drive_len = float(seg.size() - 1)
	_update_undo()
	var ramp := minf(RAMP, _drive_len / 2.0)
	var dur := (_drive_len + 2.0 * ramp) / DRIVE_SPEED
	var tw := create_tween()
	tw.tween_method(_drive_tick, 0.0, dur, dur)
	tw.tween_callback(_drive_done)


## Distance along the segment at time t: accelerate over RAMP tiles, cruise, brake.
func _dist_at(t: float) -> float:
	var ramp := minf(RAMP, _drive_len / 2.0)
	var v := DRIVE_SPEED
	var ta := 2.0 * ramp / v
	var tc := (_drive_len - 2.0 * ramp) / v
	if t < ta:
		return 0.5 * (v / ta) * t * t
	if t < ta + tc:
		return ramp + v * (t - ta)
	var r := maxf(0.0, ta * 2.0 + tc - t)
	return _drive_len - 0.5 * (v / ta) * r * r


func _drive_tick(t: float) -> void:
	var d := clampf(_dist_at(t), 0.0, _drive_len)
	var i := clampi(int(floor(d)), 0, seg.size() - 2)
	var a := board.center(seg[i])
	var b := board.center(seg[i + 1])
	van.position = a.lerp(b, d - i)
	van.target_rotation = (b - a).angle()
	# Drawn route ahead of the van shrinks; the driven trail grows behind it.
	var ahead: Array = [van.position]
	for k in range(i + 1, seg.size()):
		ahead.append(seg[k])
	board.show_path(ahead)
	board.show_trail(route + seg.slice(1, i + 1) + [van.position])
	while _fired < seg.size() - 1 and d >= _fired + 1 - 0.02:
		_fired += 1
		_arrive(_fired)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Runs `cb` at absolute timeline time `at` (now if already past).
func _at(at: float, cb: Callable) -> void:
	var delay := at - _now()
	if delay <= 0.005:
		cb.call()
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(cb)


func _arrive(k: int) -> void:
	var tile: Vector2i = seg[k]
	var res := Sim.arrive(level, sim_state, tile)
	for ev in res["events"]:
		var t := maxf(_now(), _vis_cursor)
		match ev["type"]:
			"swap":
				_at(t, _show_swap.bind(tile))
				_vis_cursor = t + 0.14
				_effects_end = maxf(_effects_end, t + 0.3)
			"deliver":
				_at(t, _launch_package.bind(ev["house"], combo))
				combo += 1
				_vis_cursor = t + 0.08
				_effects_end = maxf(_effects_end, t + FLY_TIME + 0.02)
			"pickup":
				_at(t, _collect_parcel.bind(ev["shop"]))
				_vis_cursor = t + FLY_TIME + 0.02
				_effects_end = maxf(_effects_end, t + FLY_TIME + 0.04)
	if not res["nopes"].is_empty():
		for h in res["nopes"]:
			board.house_nodes[h].wobble()
		Sfx.play("bonk", randf_range(0.95, 1.05), -3)
		Sfx.haptic(12)
		combo = 0
	board.update_gates(Sim.top_color(level, sim_state))
	if level.return_depot and board.depot:
		board.depot.calling = Sim.all_delivered(level, sim_state)
	if k < seg.size() - 1:
		var d_in: Vector2i = seg[k] - seg[k - 1]
		var d_out: Vector2i = seg[k + 1] - seg[k]
		if d_in != d_out:
			van.squash()


func _show_swap(tile: Vector2i) -> void:
	stack_view.swap_top()
	van.set_top(stack_view.top_color())
	if board.hub_nodes.has(tile):
		board.hub_nodes[tile].spin()
	van.squash()
	Sfx.play("swap")
	Sfx.haptic(14)


func _launch_package(h: int, step: int) -> void:
	var house: House = board.house_nodes[h]
	var from := van.position
	var to := house.base_pos + Vector2(0, -board.tile * 0.35)
	stack_view.pop_top()
	van.set_top(stack_view.top_color())
	var pkg := _make_flyer(level.houses[h].color, from)
	Sfx.play("whoosh", randf_range(0.95, 1.1), -10)
	var tw := create_tween()
	tw.tween_method(_fly.bind(pkg, from, to, board.tile * 0.7), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		pkg.queue_free()
		house.deliver()
		var semis: int = COMBO_STEPS[mini(step, COMBO_STEPS.size() - 1)]
		Sfx.play("thunk", pow(2.0, semis / 12.0))
		Sfx.haptic(18))


## Parcel hops from the shop onto the (moving) van, then lands on top of the stack.
func _collect_parcel(k: int) -> void:
	var shop: Shop = board.shop_nodes[k]
	var color: String = level.shops[k].color
	var from := shop.parcel_pos()
	shop.collect()
	var pkg := _make_flyer(color, from)
	Sfx.play("pickup")
	Sfx.haptic(14)
	var tw := create_tween()
	tw.tween_method(_fly_to_van.bind(pkg, from, board.tile * 0.6), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		pkg.queue_free()
		stack_view.push(color)
		van.set_top(stack_view.top_color())
		van.nudge())


func _make_flyer(color_name: String, at: Vector2) -> PackageBox:
	var pkg := PackageBox.new()
	pkg.color = Palette.pkg(color_name)
	pkg.size = board.tile * 0.3
	pkg.position = at
	pkg.z_index = 5
	board.add_child(pkg)
	return pkg


func _fly(t: float, pkg: Node2D, from: Vector2, to: Vector2, arc: float) -> void:
	pkg.position = from.lerp(to, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))
	pkg.rotation = t * PI
	pkg.scale = Vector2.ONE * lerpf(1.0, 0.75, t)


func _fly_to_van(t: float, pkg: Node2D, from: Vector2, arc: float) -> void:
	_fly(t, pkg, from, van.position, arc)


func _drive_done() -> void:
	van.stop_bounce()
	route = _full()
	seg = []
	board.show_path([])
	board.show_trail(route)
	var tw := create_tween()
	tw.tween_interval(maxf(0.05, _effects_end - _now() + 0.04))
	tw.tween_callback(_after_segment)


func _after_segment() -> void:
	if Sim.is_won(level, sim_state, route):
		_win()
	elif not Sim.has_move(level, route, sim_state):
		_fail()
	else:
		state = State.IDLE
		van.inviting = true
		if level.return_depot and Sim.all_delivered(level, sim_state):
			hint_label.text = "All delivered! Drive back to the depot."
			hint_label.modulate.a = 1.0
		_update_undo()
	segment_finished.emit()


# ---------------------------------------------------------------- undo

func can_undo() -> bool:
	return undo_left > 0 and not history.is_empty() and (state == State.IDLE or state == State.FAILED)


func undo() -> void:
	if not can_undo():
		return
	undo_left -= 1
	var snap: Dictionary = history.pop_back()
	var start_i: int = snap["len"] - 1
	var back: Array = route.slice(start_i)          # segment tiles, first = where it began
	var old: Dictionary = sim_state
	sim_state = snap["state"]
	route.resize(snap["len"])
	state = State.REWINDING
	van.inviting = false
	result_box.visible = false
	hint_label.visible = true
	_update_undo()
	Sfx.play("rewind")
	Sfx.haptic(20)

	# Delivered packages fly back from their houses to where the van will end up;
	# collected parcels fly back to their shops.
	var dest := board.center(back[0])
	var k := 0
	for h in old["fills"].size():
		var returned: int = old["fills"][h] - sim_state["fills"][h]
		if returned <= 0:
			continue
		var house: House = board.house_nodes[h]
		house.undeliver(sim_state["fills"][h])
		for j in returned:
			_fly_back(level.houses[h].color, house.base_pos + Vector2(0, -board.tile * 0.35), dest, k * 0.05)
			k += 1
	for s in old["picked"].size():
		if old["picked"][s] and not sim_state["picked"][s]:
			var shop: Shop = board.shop_nodes[s]
			_fly_back(level.shops[s].color, van.position, shop.parcel_pos(), k * 0.05, shop.restore)
			k += 1

	var n := float(back.size() - 1)
	var rt := create_tween()
	rt.tween_method(_rewind_tick.bind(back), n, 0.0, n / REWIND_SPEED + 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_callback(func():
		van.target_rotation = snap["rot"]
		van.position = dest
		stack_view.rebuild(sim_state["stack"])
		van.set_top(stack_view.top_color())
		van.stop_bounce()
		board.show_trail(route)
		board.update_gates(Sim.top_color(level, sim_state))
		if board.depot:
			board.depot.calling = false
		state = State.IDLE
		van.inviting = true
		_update_undo())


func _fly_back(color: String, from: Vector2, to: Vector2, delay: float, done: Callable = Callable()) -> void:
	var pkg := _make_flyer(color, from)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_fly.bind(pkg, from, to, board.tile * 0.5), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(pkg.queue_free)
	if done.is_valid():
		tw.tween_callback(done)


func _rewind_tick(d: float, tiles: Array) -> void:
	var i := clampi(int(floor(d)), 0, tiles.size() - 2)
	var a := board.center(tiles[i])
	var b := board.center(tiles[i + 1])
	van.position = a.lerp(b, d - i)
	van.target_rotation = (b - a).angle()   # facing forward: it's reversing
	board.show_trail(route + tiles.slice(1, i + 1) + [van.position])


func _update_undo() -> void:
	if undo_button == null:
		return
	var usable := can_undo()
	undo_button.disabled = not usable
	undo_button.text = "Undo" if undo_left > 0 else "Undo used"
	undo_button.visible = state != State.WON
	undo_button.modulate.a = 1.0 if usable else 0.55


# ---------------------------------------------------------------- results

func _win() -> void:
	state = State.WON
	_update_undo()
	Progress.mark_complete(level.number)
	Sfx.play("win")
	Sfx.haptic(30)
	if board.depot:
		board.depot.calling = false
	var bpos := board.position
	var bsz := board.size_px()
	confetti.burst(Vector2(bpos.x - 20, bpos.y + bsz.y), -PI * 0.36, 0.22, 70)
	confetti.burst(Vector2(bpos.x + bsz.x + 20, bpos.y + bsz.y), -PI * 0.64, 0.22, 70)
	for i in board.house_nodes.size():
		board.house_nodes[i].bounce(i * 0.07)
	hint_label.visible = false
	_show_result("Delivered!", "Next" if index + 1 < total else "Levels", Palette.GOOD, 0.22)


func _fail() -> void:
	state = State.FAILED
	_update_undo()
	Sfx.play("fail", 1.0, -2)
	Sfx.haptic(25)
	van.shake()
	stack_view.flash_remaining()
	var left := Sim.remaining(level, sim_state)
	hint_label.visible = false
	var msg := "Stuck! %d left" % left if left > 0 else "Stuck! Can't reach the depot"
	_show_result(msg, "Retry", Palette.ACCENT, 0.0)
	if can_undo():
		var tw := undo_button.create_tween().set_loops(3)
		undo_button.pivot_offset = undo_button.size / 2.0
		tw.tween_property(undo_button, "scale", Vector2(1.08, 1.08), 0.18)
		tw.tween_property(undo_button, "scale", Vector2.ONE, 0.22)


func _show_result(msg: String, btn: String, col: Color, delay: float) -> void:
	result_label.text = msg
	result_button.text = btn
	UiTheme.button_style(result_button, col, Color.WHITE)
	result_box.visible = true
	result_box.scale = Vector2(0.6, 0.6)
	result_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): Sfx.play("pop", 1.0, -6))
	tw.tween_property(result_box, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(result_box, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_result_pressed() -> void:
	Sfx.play("click")
	if state == State.WON:
		_next()
	else:
		_retry()


func _retry() -> void:
	level_requested.emit(index)


func _next() -> void:
	if index + 1 < total:
		level_requested.emit(index + 1)
	else:
		menu_requested.emit()


func _fade(c: CanvasItem, a: float) -> void:
	create_tween().tween_property(c, "modulate:a", a, 0.2)
