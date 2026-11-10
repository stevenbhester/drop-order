class_name DebugAuto
extends Node
## Command-line self-tests, driven with real injected mouse events where it matters.
##   -- --autoplay   drive the solver's shortest route as one segment
##   -- --autodrag   draw the shortest route by dragging, in one segment
##   -- --autoseg    draw it by dragging, split into two segments
##   -- --autoundo   drive half the route, undo it, then draw the whole route in segments
##   -- --autostuck  wander randomly until stuck (no-revisit levels)
## Prints one "AUTOTEST" line with the outcome.

var g: Game
var mode := ""


static func maybe_run(game: Game) -> void:
	for m in ["autoplay", "autodrag", "autoseg", "autoundo", "autostuck"]:
		if OS.get_cmdline_user_args().has("--" + m):
			var a := DebugAuto.new()
			a.g = game
			a.mode = m
			game.add_child(a)
			return


func _ready() -> void:
	await get_tree().create_timer(0.6).timeout
	var sol: Array = g.solve_info.get("shortest", [])
	var half := maxi(2, sol.size() / 2)
	var pieces := _split_uturns(sol)
	match mode:
		"autoplay":
			g.drive_tiles(sol)
			await g.segment_finished
		"autodrag":
			for p in pieces:
				await _drag(p)
		"autoseg":
			for p in _halve(pieces):
				await _drag(p)
		"autoundo":
			g.drive_tiles(sol.slice(0, half))
			await g.segment_finished
			var before := Sim.remaining(g.level, g.sim_state)
			var stack_before: Array = g.sim_state["stack"].duplicate()
			g.undo()
			for f in 600:
				if g.state == Game.State.IDLE:
					break
				await get_tree().process_frame
			await get_tree().create_timer(0.4).timeout
			var view_ok: bool = g.stack_view.colors == g.sim_state["stack"]
			print("AUTOTEST undo L%d: route back to %d tile(s), remaining %d -> %d, stack %s -> %s, view_matches=%s, undo_left=%d" % [
				g.level.number, g.route.size(), before, Sim.remaining(g.level, g.sim_state), stack_before, g.sim_state["stack"], view_ok, g.undo_left])
			for p in _halve(pieces):
				await _drag(p)
		"autostuck":
			var walk: Array = g.route.duplicate()
			var st := Sim.copy_state(g.sim_state)
			while Sim.has_move(g.level, walk, st) and walk.size() < 200 and not Sim.is_won(g.level, st, walk):
				var opts := []
				for d in LevelData.DIRS:
					if Sim.can_extend(g.level, walk, walk.back() + d, st):
						opts.append(walk.back() + d)
				walk.append(opts.pick_random())
				Sim.arrive(g.level, st, walk.back())
			g.drive_tiles(walk)
			await g.segment_finished
	await get_tree().create_timer(0.5).timeout
	var synced: bool = g.stack_view.colors == g.sim_state["stack"]
	print("AUTOTEST %s L%d: state=%s route=%d tiles, packages left=%d, solution=%d tiles, stack_view_synced=%s" % [
		mode, g.level.number, Game.State.keys()[g.state], g.route.size(), Sim.remaining(g.level, g.sim_state), sol.size(), synced])
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()


## A U-turn can't be drawn inside one drag (dragging back retracts), so cut there.
func _split_uturns(tiles: Array) -> Array:
	var out := []
	var cur := [tiles[0]]
	for i in range(1, tiles.size()):
		cur.append(tiles[i])
		if i + 1 < tiles.size() and tiles[i + 1] == tiles[i - 1]:
			out.append(cur)
			cur = [tiles[i]]
	out.append(cur)
	return out


## Same pieces, with the longest one split in two (to exercise multi-segment drawing).
func _halve(pieces: Array) -> Array:
	var out := []
	for p in pieces:
		if p.size() >= 4 and out.size() < pieces.size() + 1:
			var h: int = p.size() / 2
			out.append(p.slice(0, h + 1))
			out.append(p.slice(h))
		else:
			out.append(p)
	return out


## Presses on the van and drags through the centres of `tiles`, then releases.
func _drag(tiles: Array) -> void:
	var xf := get_viewport().get_final_transform() * g.board.get_global_transform_with_canvas()
	var pts: Array = []
	for k in tiles.size() - 1:
		var a := g.board.center(tiles[k])
		var b := g.board.center(tiles[k + 1])
		for s in 6:
			pts.append(a.lerp(b, s / 6.0) + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
	pts.append(g.board.center(tiles.back()))
	_mouse(xf * pts[0], true)
	for p in pts:
		await get_tree().process_frame
		var m := InputEventMouseMotion.new()
		m.position = xf * p
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
	await get_tree().process_frame
	if g.seg != tiles:
		print("AUTOTEST drag mismatch: drew ", g.seg, " wanted ", tiles)
	_mouse(xf * pts.back(), false)
	await g.segment_finished


func _mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	Input.parse_input_event(ev)
