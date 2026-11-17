class_name UndoLesson
extends Node
## Job 5's lesson ("Dead End Drive"): Undo, taught by making the mistake for them.
##
## The van looks up the street ahead: six drop-offs in a row. "So many drop-offs! This HAS to be the
## way…" and it drives itself up it, into a dead end, one package still aboard. Then, a tip at a time (each
## waits for them to do the thing; nothing's a card to read):
##   stuck    "Dead end! Tap Undo": it takes you back to your last stop.
##   free     the first undo done: Undo never runs out; hold it down to rewind fast.
##   done     back at the start: Undo and Retry are always free. Over.
## It follows what the game's in, not a script: drive back up the street and it waits; with the headlights
## off one undo goes all the way back, and it skips to the end.
## Retry is put off until it's done (Game._on_retry_pressed), or the lesson would just start again.
## Shown once (Progress.seen_new "undo_lesson"), to anyone who hasn't beaten job 5 as it is now.
## Debug: --undo-lesson shows it regardless; --undo-lesson-demo plays the player's part too (recordings).
## (It used to be job 7, after the first boss, and went on to teach gas: undos were counted then. The Baron's
## scene on job 6 covers what's metered now, LimitsScene, and undos aren't.)

const LEVEL := 5
const SPUR_MIN := 4              # stops up the street: enough of them for a few undos

var game: Game
var step := "wait"

var _t := 0.0
var _drawn := 0
var _spur: Array = []            # the street: the road tiles straight up from the van
var _tip: TipBubble
var _dim: FocusDim
var _bars: Control               # the letterbox, while the van's driving itself
var _bar_k := 0.0
var _zoom_from: Array = []       # the board's [scale, position] before it pushed in
var _last_n := 1
var _said := {}
var _demo := false
var _demo_t := 0.0
var _demo_hold := -1.0


## Is the lesson due on this game? (Job 7, laid out as the lesson needs, first time through.)
static func due(g: Game) -> bool:
	if g.level.number != LEVEL or not g.side.is_empty() or g.daily_day >= 0 or g.og or spur(g.level).size() < SPUR_MIN:
		return false
	if OS.get_cmdline_user_args().has("--undo-lesson") or OS.get_cmdline_user_args().has("--undo-lesson-demo"):
		return true
	# (Cut, 2026-11-16: Steven didn't want job 5 driving itself or forcing an undo. Undo's free now, and a dead
	# end already says to undo or retry (Game: the dead-end sign). Kept for the debug flags above.)
	return false


## The street the van's sent up: the road tiles straight up from its start, as far as they go.
static func spur(L: LevelData) -> Array:
	var out: Array = []
	var p := L.start + Vector2i.UP
	while L.is_road(p):
		out.append(p)
		p += Vector2i.UP
	return out


func _ready() -> void:
	_spur = spur(game.level)
	_demo = OS.get_cmdline_user_args().has("--undo-lesson-demo")


## Still teaching (Retry waits)?
func busy() -> bool:
	return step != "done"


func _say(key: String, text: String, at: Vector2, life := 40.0, above := false) -> void:
	if _said.has(key):
		return
	_said[key] = true
	if is_instance_valid(_tip):
		_tip.dismiss()
	_tip = TipBubble.new()
	_tip.text = text
	_tip.target = at
	_tip.life = life
	_tip.above = above
	game._ui_root.add_child(_tip)
	# Everything but Undo dims a little while a tip about it is up, so it can't be missed.
	if is_instance_valid(_dim):
		_dim.fade_out()
		_dim = null
	if at.distance_to(_undo_at()) < 4.0:
		_dim = FocusDim.new()
		_dim.hole = game.undo_button.get_global_rect()
		game._ui_root.add_child(_dim)
		game._ui_root.move_child(_dim, _tip.get_index())
		_tip.gone.connect(func():
			if is_instance_valid(_dim):
				_dim.fade_out()
				_dim = null)


func _undo_at() -> Vector2:
	return game.undo_button.get_global_rect().get_center()


func _process(delta: float) -> void:
	if not is_instance_valid(game) or game.state == Game.State.WON:
		queue_free()
		return
	match step:
		"wait":
			# Whatever else opens the job (a spotlight, a card) goes first.
			if game._alive < 0.3:
				return
			if game.modal == null:
				game.modal = self        # hands off until the van's made its mistake
			if game.modal != self or game._alive < 1.1 or game.state != Game.State.IDLE:
				return
			_cine_in()
			_say("think", "So many drop-offs!\nThis HAS to be the way…", game.board.get_global_transform_with_canvas() * game.board.center(game.level.start), 3.0)
			step = "think"
			_t = 0.0
		"think":
			_t += delta
			if _t >= 1.7:
				game._begin_plan()
				step = "draw"
				_t = 0.0
		"draw":
			# The route draws itself up the street, a tile at a time, then it's sent.
			_t += delta
			if _t >= 0.14:
				_t = 0.0
				if _drawn < _spur.size():
					game._extend(_spur[_drawn])
					_drawn += 1
				else:
					game._release()
					step = "drive"
		"drive":
			if game.state == Game.State.FAILED or (game.state == Game.State.IDLE and game.route.size() > 1):
				if game.modal == self:
					game.modal = null
				game.retry_button.breathe(false)
				_last_n = game.route.size()
				_cine_out()
				step = "stuck"
				_say("stuck", "Dead end! Tap Undo.\nIt takes you back to your last stop.", _undo_at())
		"stuck", "free":
			_watch()
			if _demo:
				_demo_tick(delta)


## The scripted bit is a little film, and looks like one: black bars slide in top and bottom (over the buttons,
## which do nothing meanwhile) and the board pushes in a touch. So nobody thinks they mis-tapped: the van's
## doing this by itself.
func _cine_in() -> void:
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(func():
		var v := _bars.get_viewport_rect().size
		var h := v.y * 0.09 * _bar_k
		_bars.draw_rect(Rect2(0, 0, v.x, h), Color("0e0b16"))
		_bars.draw_rect(Rect2(0, v.y - h, v.x, h), Color("0e0b16")))
	game._ui_root.add_child(_bars)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		_bar_k = k
		if is_instance_valid(_bars):
			_bars.queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var b := game.board
	_zoom_from = [b.scale, b.position]
	var grow := 0.05
	var tz := create_tween().set_parallel()
	tz.tween_property(b, "scale", b.scale * (1.0 + grow), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tz.tween_property(b, "position", b.position - b.size_px() * b.scale * grow / 2.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sfx.play("whoosh", 0.7, -10.0)


func _cine_out() -> void:
	if is_instance_valid(_bars):
		var bars := _bars
		var tw := create_tween()
		tw.tween_method(func(k: float):
			_bar_k = k
			if is_instance_valid(bars):
				bars.queue_redraw(), 1.0, 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(bars.queue_free)
	if _zoom_from.size() == 2 and is_instance_valid(game) and is_instance_valid(game.board):
		var tz := create_tween().set_parallel()
		tz.tween_property(game.board, "scale", _zoom_from[0], 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tz.tween_property(game.board, "position", _zoom_from[1], 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_from = []


## Has an undo just landed (the route's shorter, and the van's still)? Then the next thing to say.
func _watch() -> void:
	if not (game.state == Game.State.IDLE or game.state == Game.State.FAILED):
		return
	var n := game.route.size()
	if n >= _last_n:
		_last_n = n
		return
	_last_n = n
	if n <= 1:
		_finish()
	else:
		step = "free"
		_say("free", "Undo never runs out.\nHold it down to rewind fast.", _undo_at())


## Back at the start: the last word, and it's over.
func _finish() -> void:
	step = "done"
	Progress.seen_new["undo_lesson"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	_say("done", "Undo and Retry are always free.\nUse them as much as you like.", _undo_at(), 7.0, true)
	game._say("Now, the way that actually works…")
	get_tree().create_timer(8.0).timeout.connect(queue_free)


## Debug: the player's part, for recordings. A tap on Undo every so often; a long hold when a tank's due
## (or to rewind once it's spent).
func _demo_tick(delta: float) -> void:
	if _demo_hold >= 0.0:
		_demo_hold -= delta
		if _demo_hold < 0.0:
			game._hold_up()
		return
	_demo_t += delta
	if _demo_t < 1.6:
		return
	_demo_t = 0.0
	if game.route.size() > 3:
		game._hold_down("undo")
		_demo_hold = 2.4
	else:
		game._on_undo_pressed()
