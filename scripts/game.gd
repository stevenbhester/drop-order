class_name Game
extends Node2D
## One level being played: input -> path, drive, deliveries, win/fail, UI.
## Rules come from Sim, visuals from Board/Van/House/StackView.

signal menu_requested
signal level_requested(index: int)

enum State { IDLE, DRAWING, DRIVING, WON, FAILED }

const DRIVE_SPEED := 7.0         # tiles per second at cruise
const RAMP := 0.6                # tiles spent accelerating / braking
const TOP_BAR := 170.0
const BOTTOM_MIN := 400.0
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

var path: Array = []             # Vector2i, path[0] = van start
var sim_state: Dictionary
var combo := 0
var _fired := 0
var _drive_len := 0.0
var _last_delivery_ms := 0

var _top_inset := 0.0
var _bottom_inset := 0.0
var level_label: Label
var hint_label: Label
var debug_label: Label
var result_box: VBoxContainer
var result_label: Label
var result_button: Button


func setup(lvl: LevelData, idx: int, count: int, solved: Dictionary) -> void:
	level = lvl
	index = idx
	total = count
	solve_info = solved


func _ready() -> void:
	sim_state = Sim.new_state(level)
	_compute_insets()
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay") or args.has("--autofail"):
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(autoplay.bind(args.has("--autofail")))
	elif args.has("--autodrag"):
		_autodrag()


## Debug: feed real mouse events along the solution, to exercise the drag code.
func _autodrag() -> void:
	await get_tree().create_timer(0.6).timeout
	var sol: Array = solve_info.get("shortest", [])
	var xf := get_viewport().get_final_transform() * board.get_global_transform_with_canvas()
	var pts: Array = []
	for k in sol.size() - 1:
		var a := board.center(sol[k])
		var b := board.center(sol[k + 1])
		for s in 6:
			pts.append(a.lerp(b, s / 6.0) + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
	pts.append(board.center(sol.back()))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = xf * pts[0]
	Input.parse_input_event(ev)
	for p in pts:
		await get_tree().process_frame
		var m := InputEventMouseMotion.new()
		m.position = xf * p
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
	await get_tree().process_frame
	print("autodrag: drew %d tiles, solution has %d" % [path.size(), sol.size()])
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = xf * pts.back()
	Input.parse_input_event(up)


## Debug: drive the solver's shortest route.
func autoplay(fail := false) -> void:
	var sol: Array = solve_info.get("shortest", [])
	if state != State.IDLE or sol.is_empty():
		return
	path = sol.slice(0, 3) if fail else sol.duplicate()
	van.inviting = false
	if ghost:
		ghost.visible = false
	hint_label.modulate.a = 0.35
	board.show_path(path)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(_drive)


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
	var box := clampf((BOTTOM_MIN - 120.0) / maxf(level.stack.size(), 1) - 10.0, 40.0, 84.0)
	stack_view.setup(level.stack, box)

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
	hint_label.add_theme_font_size_override("font_size", 42)
	hint_label.add_theme_color_override("font_color", Palette.TEXT)
	var title := ("“%s”\n" % level.title) if level.title != "" else ""
	hint_label.text = title + (level.hint if level.hint != "" else "Drag a route from the van.")
	root.add_child(hint_label)

	result_box = VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 22)
	result_box.visible = false
	root.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 54)
	result_box.add_child(result_label)
	result_button = Button.new()
	result_button.add_theme_font_size_override("font_size", 64)
	result_button.custom_minimum_size = Vector2(420, 150)
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
	stack_view.position = Vector2(150, bottom - 40)
	var right_x := stack_view.position.x + stack_view.box * 2.3 + 40.0
	hint_label.position = Vector2(right_x, board_bottom + 20)
	hint_label.size = Vector2(vp.x - right_x - 50, area_h - 40)
	result_box.position = Vector2(right_x, board_bottom + 10)
	result_box.size = Vector2(vp.x - right_x - 50, area_h - 20)
	result_box.pivot_offset = result_box.size / 2.0


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_retry()
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
				if OS.is_debug_build():
					autoplay()
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
	var on_van := board.tile_at(lp) == level.start or lp.distance_to(board.center(level.start)) < board.tile * 0.75
	if not on_van:
		if lp.x > -board.tile and lp.y > -board.tile and lp.x < board.size_px().x + board.tile and lp.y < board.size_px().y + board.tile:
			van.nudge()
			Sfx.play("untick", 0.8, -6)
		return
	state = State.DRAWING
	path = [level.start]
	van.inviting = false
	van.nudge()
	if ghost:
		ghost.visible = false
	_fade(hint_label, 0.35)
	board.show_path(path)
	Sfx.play("tick", 0.85)
	Sfx.haptic(8)


func _drag(lp: Vector2) -> void:
	var last: Vector2i = path.back()
	# Hysteresis: stay on the current tile until the finger is clearly out of it.
	var off := (lp - board.center(last)).abs()
	if maxf(off.x, off.y) < board.tile * 0.58:
		return
	var target := board.tile_at(lp)
	var guard := 0
	while target != path.back() and guard < 24:
		guard += 1
		if path.size() >= 2 and target == path[path.size() - 2]:
			_retract()
			continue
		if level.no_revisit:
			var at := path.find(target)
			if at >= 0:
				while path.size() > at + 1:
					_retract()
				break
		var cur: Vector2i = path.back()
		var diff := target - cur
		var steps: Array = [Vector2i(signi(diff.x), 0), Vector2i(0, signi(diff.y))]
		if absi(diff.y) > absi(diff.x):
			steps.reverse()
		var moved := false
		for s in steps:
			if s == Vector2i.ZERO:
				continue
			var nxt: Vector2i = cur + s
			if Sim.can_extend(level, path, nxt):
				_extend(nxt)
				moved = true
				break
		if not moved:
			break


func _extend(t: Vector2i) -> void:
	path.append(t)
	board.show_path(path)
	Sfx.play("tick", 1.0 + minf(path.size(), 24) * 0.015, -2)
	Sfx.haptic(6)


func _retract() -> void:
	path.pop_back()
	board.show_path(path)
	Sfx.play("untick", 1.0, -4)
	Sfx.haptic(4)


func _release() -> void:
	if state != State.DRAWING:
		return
	if path.size() < 2:
		state = State.IDLE
		path = []
		board.show_path(path)
		van.inviting = true
		if ghost:
			ghost.visible = true
		_fade(hint_label, 1.0)
		return
	_drive()


# ---------------------------------------------------------------- driving

func _drive() -> void:
	state = State.DRIVING
	combo = 0
	_fired = 0
	_drive_len = float(path.size() - 1)
	var ramp := minf(RAMP, _drive_len / 2.0)
	var dur := (_drive_len + 2.0 * ramp) / DRIVE_SPEED
	var tw := create_tween()
	tw.tween_method(_drive_tick, 0.0, dur, dur)
	tw.tween_callback(_drive_done)


## Distance along the path at time t: accelerate over RAMP tiles, cruise, brake.
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
	var i := clampi(int(floor(d)), 0, path.size() - 2)
	var a := board.center(path[i])
	var b := board.center(path[i + 1])
	van.position = a.lerp(b, d - i)
	van.target_rotation = (b - a).angle()
	# Route behind the van disappears.
	var rest: Array = [van.position]
	for k in range(i + 1, path.size()):
		rest.append(path[k])
	board.show_path(rest)
	while _fired < path.size() - 1 and d >= _fired + 1 - 0.02:
		_fired += 1
		_arrive(_fired)


func _arrive(k: int) -> void:
	var ev := Sim.arrive(level, sim_state, path[k])
	var n := 0
	for h in ev["delivered"]:
		_launch_package(h, n * 0.07)
		n += 1
	if not ev["nopes"].is_empty():
		for h in ev["nopes"]:
			board.house_nodes[h].wobble()
		Sfx.play("bonk", randf_range(0.95, 1.05), -3)
		Sfx.haptic(12)
		combo = 0
	van.set_top(Sim.top_color(level, sim_state))
	# Squash on turns.
	if k < path.size() - 1:
		var d_in: Vector2i = path[k] - path[k - 1]
		var d_out: Vector2i = path[k + 1] - path[k]
		if d_in != d_out:
			van.squash()


func _launch_package(h: int, delay: float) -> void:
	var house: House = board.house_nodes[h]
	var from := van.position
	var to := house.base_pos + Vector2(0, -board.tile * 0.35)
	stack_view.pop_top()
	var pkg := PackageBox.new()
	pkg.color = Palette.pkg(level.houses[h].color)
	pkg.size = board.tile * 0.3
	pkg.position = from
	pkg.z_index = 5
	pkg.visible = delay <= 0.0
	board.add_child(pkg)
	var step := combo
	combo += 1
	_last_delivery_ms = Time.get_ticks_msec() + int(delay * 1000.0) + 260
	var arc := board.tile * 0.7
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): pkg.visible = true)
	tw.tween_callback(func(): Sfx.play("whoosh", randf_range(0.95, 1.1), -10))
	tw.tween_method(_fly.bind(pkg, from, to, arc), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		pkg.queue_free()
		house.deliver()
		var semis: int = COMBO_STEPS[mini(step, COMBO_STEPS.size() - 1)]
		Sfx.play("thunk", pow(2.0, semis / 12.0))
		Sfx.haptic(18))


func _fly(t: float, pkg: Node2D, from: Vector2, to: Vector2, arc: float) -> void:
	pkg.position = from.lerp(to, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))
	pkg.rotation = t * PI
	pkg.scale = Vector2.ONE * lerpf(1.0, 0.75, t)


func _drive_done() -> void:
	van.stop_bounce()
	board.show_path([])
	var wait := maxf(0.05, (_last_delivery_ms - Time.get_ticks_msec()) / 1000.0 + 0.04)
	var tw := create_tween()
	tw.tween_interval(wait)
	tw.tween_callback(_win if sim_state["left"] == 0 else _fail)


# ---------------------------------------------------------------- results

func _win() -> void:
	state = State.WON
	Progress.mark_complete(level.number)
	Sfx.play("win")
	Sfx.haptic(30)
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
	Sfx.play("fail", 1.0, -2)
	Sfx.haptic(25)
	van.shake()
	stack_view.flash_remaining()
	var left: int = sim_state["left"]
	hint_label.visible = false
	_show_result("%d package%s left" % [left, "" if left == 1 else "s"], "Retry", Palette.ACCENT, 0.0)


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
