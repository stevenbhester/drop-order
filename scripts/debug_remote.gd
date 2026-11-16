class_name DebugRemote
extends Node
## A remote control, for playtests driven from outside the game (tools/playtest/lm.py): the real game, its
## real screens, cards, ads and tutorials, played by taps and drags that arrive as files.
##
## Run with `-- --remote=<dir>` (and `--profile=<name>` for a save of its own: Progress). Every 50 ms it
## looks for <dir>/cmd.json: {"id": n, "op": ..., ...}. It does it, lets things settle, and writes
## <dir>/out_<n>.json: {"ok", "note", "state", "shot"}. `state` is the screen as text (see _state): which
## screen and cards are up, every button and label with where it is, and in a level the board as a little
## map. Cards that draw their own words don't show there: ask for a picture ("shot": true on any command;
## it's the window as the player sees it, and positions everywhere are that picture's pixels).
##   state                      just look
##   tap    x y                 a tap
##   press  "label"             a tap on the button whose label has that text
##   hold   x y secs            press and hold ("label" works too)
##   drag   [[x, y], ...]       a finger along those points (a pause at each)
##   drive  "UURRD"             in a level: a drag from the van, a tile per letter
##   wait   secs
## While it's on, nothing leaves the machine: no ratings, daily results or feedback are sent or queued, and
## nothing opens a browser (on()).

var main: Node
var _dir := ""
var _busy := false
var _t := 0.0


static func on() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--remote="):
			return true
	return false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--remote="):
			_dir = a.trim_prefix("--remote=")
	DirAccess.make_dir_recursive_absolute(_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	if _busy or _t < 0.05:
		return
	_t = 0.0
	var p := _dir.path_join("cmd.json")
	if not FileAccess.file_exists(p):
		return
	var cmd = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (cmd is Dictionary):
		return                      # (half-written: next time)
	DirAccess.remove_absolute(p)
	_busy = true
	await _run(cmd)
	_busy = false


func _run(cmd: Dictionary) -> void:
	var id := int(cmd.get("id", 0))
	var out := {"ok": true, "note": ""}
	match str(cmd.get("op", "state")):
		"tap":
			await _press(Vector2(float(cmd.get("x", 0)), float(cmd.get("y", 0))), 0.06)
		"press", "hold":
			var at := Vector2(float(cmd.get("x", -1)), float(cmd.get("y", -1)))
			if cmd.has("label"):
				at = _find(str(cmd["label"]))
			if at.x < 0.0:
				out["ok"] = false
				out["note"] = "no button with that label is showing"
			else:
				await _press(at, float(cmd.get("secs", 0.06)) if cmd["op"] == "hold" else 0.06)
		"drag":
			var pts: Array = cmd.get("points", [])
			if pts.size() >= 2:
				await _drag_points(pts.map(func(q): return Vector2(float(q[0]), float(q[1]))), float(cmd.get("pause", 0.03)), bool(cmd.get("keep", false)))
		"up":
			# Lifts a finger a drag left down ("keep").
			_mouse(Vector2(float(cmd.get("x", 0)), float(cmd.get("y", 0))), false)
			await get_tree().process_frame
		"drive":
			out["note"] = await _drive(str(cmd.get("moves", "")))
			out["ok"] = not str(out["note"]).begins_with("can't")
		"wait":
			await get_tree().create_timer(clampf(float(cmd.get("secs", 1.0)), 0.0, 30.0)).timeout
	await get_tree().create_timer(clampf(float(cmd.get("settle", 0.45)), 0.0, 10.0)).timeout
	out["state"] = _state()
	if cmd.get("shot", false):
		var img := get_viewport().get_texture().get_image()
		var path := _dir.path_join("shot_%d.png" % id)
		img.save_png(path)
		out["shot"] = path
	var tmp := _dir.path_join("out_%d.tmp" % id)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	DirAccess.rename_absolute(tmp, _dir.path_join("out_%d.json" % id))


# ---------------------------------------------------------------- input

func _mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


func _move(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(m)


func _press(pos: Vector2, secs: float) -> void:
	_mouse(pos, true)
	await get_tree().create_timer(maxf(secs, 0.05)).timeout
	_mouse(pos, false)
	await get_tree().process_frame


func _drag_points(pts: Array, pause: float, keep := false) -> void:
	_mouse(pts[0], true)
	await get_tree().process_frame
	for k in range(1, pts.size()):
		for s in range(1, 6):
			_move((pts[k - 1] as Vector2).lerp(pts[k], s / 5.0))
			await get_tree().process_frame
		if pause > 0.0:
			await get_tree().create_timer(pause).timeout
	if keep:
		return                     # (the finger stays down: "up" lifts it)
	_mouse(pts.back(), false)
	await get_tree().process_frame


## A drag from the van, a tile per letter of `moves` (U D L R). Waits for the van to stop.
func _drive(moves: String) -> String:
	var g := main.get("screen") as Game
	if g == null:
		return "can't: not in a level"
	if g.state != Game.State.IDLE or g._busy_modal():
		return "can't: the game isn't waiting for a move (state %s%s)" % [Game.State.keys()[g.state], ", something's on top" if g._busy_modal() else ""]
	var tiles: Array = [g.route.back()]
	for ch in moves.to_upper():
		var d: Vector2i = {"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}.get(ch, Vector2i.ZERO)
		if d != Vector2i.ZERO:
			tiles.append(tiles.back() + d)
	if tiles.size() < 2:
		return "can't: no moves given"
	var xf: Transform2D = get_viewport().get_final_transform() * g.board.get_global_transform_with_canvas()
	var before := g.route.size()
	await _drag_points(tiles.map(func(t): return xf * g.board.center(t)), 0.05)
	var waited := 0.0
	while waited < 12.0 and (g.state == Game.State.DRAWING or g.state == Game.State.DRIVING):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if not is_instance_valid(g):
			return "the level went away"
	return "drove %d of %d tiles asked" % [g.route.size() - before, tiles.size() - 1]


# ---------------------------------------------------------------- looking

## Where the button whose label holds `text` is (window pixels), topmost first; (-1, -1) if none.
func _find(text: String) -> Vector2:
	var best := Vector2(-1, -1)
	var best_layer := -9999
	for it in _controls():
		if it["kind"] == "button" and str(it["text"]).to_lower().contains(text.to_lower()) and int(it["layer"]) >= best_layer:
			best_layer = int(it["layer"])
			best = it["at"]
	return best


func _layer_of(n: Node) -> int:
	var p := n
	while p:
		if p is CanvasLayer:
			return (p as CanvasLayer).layer
		p = p.get_parent()
	return 0


## Every visible button and label: {kind, text, at (window pixels), layer}.
func _controls() -> Array:
	var out := []
	var xf := get_viewport().get_final_transform()
	var todo: Array = [get_tree().root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			continue
		for c in n.get_children():
			todo.append(c)
		if not (n is Control):
			continue
		var c := n as Control
		var text := ""
		var kind := ""
		if c is BaseButton:
			kind = "button"
			text = str(c.get("label")) if c is JuicyButton else str(c.get("text"))
			if text == "" and c is JuicyButton:
				text = "[%s]" % c.icon_name
			if c is JuicyButton and c.badge != "":
				text += " (badge: %s%s)" % [c.badge, " " + c.badge_icon if c.badge_icon != "" else ""]
			if c is JuicyButton and c.dim:
				text += " (greyed)"
			if (c as BaseButton).disabled:
				text += " (disabled)"
		elif c is Label and (c as Label).text.strip_edges() != "":
			kind = "label"
			text = (c as Label).text.replace("\n", " / ")
		elif c is TipBubble:
			kind = "tip bubble"
			text = (c as TipBubble).text.replace("\n", " / ")
		elif c is CloseX:
			kind = "button"
			text = "[red X]"
		elif c is ExitRibbon:
			# The way out, top left: put away it's one thing to tap; pulled out, a row to hold for each.
			var er := c as ExitRibbon
			var o := xf * (er.get_global_transform_with_canvas() * Vector2.ZERO)
			var sc := xf.get_scale().x
			if not er.is_open():
				out.append({"kind": "button", "text": "[ribbon, top left: back arrow%s. Tap to pull it out]" % ({"jets": " + jump-jets arrow", "locked": " + a padlock", "gift": " + a bow"}.get(er.row, "")), "at": (o + Vector2(50, 50) * sc).round(), "layer": _layer_of(c)})
			else:
				out.append({"kind": "button", "text": "%s (press and HOLD about half a second)" % er.give_label, "at": (o + Vector2(200, ExitRibbon.ROW_H * 0.5) * sc).round(), "layer": _layer_of(c)})
				if er.row == "jets":
					out.append({"kind": "button", "text": "Jump jets, costs 1 gas (press and HOLD about a second)%s" % (" (taped off)" if er.jets_blocked else ""), "at": (o + Vector2(200, ExitRibbon.ROW_H * 1.5) * sc).round(), "layer": _layer_of(c)})
				elif er.row == "locked":
					out.append({"kind": "button", "text": "[a parcel label: DO NOT OPEN TILL JOB %d]" % er.locked_until, "at": (o + Vector2(200, ExitRibbon.ROW_H * 1.5) * sc).round(), "layer": _layer_of(c)})
				elif er.row == "gift":
					out.append({"kind": "button", "text": "From Dispatch! (a present with a bow: tap to open)", "at": (o + Vector2(200, ExitRibbon.ROW_H * 1.5) * sc).round(), "layer": _layer_of(c)})
			continue
		if kind == "" or c.modulate.a < 0.05 or c.size.x < 2.0:
			continue
		var r := c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
		var at := xf * r.get_center()
		var win := get_viewport().get_visible_rect().size * xf.get_scale()
		if at.x < -20 or at.y < -20 or at.x > win.x + 20 or at.y > win.y + 20:
			continue
		out.append({"kind": kind, "text": text, "at": at.round(), "layer": _layer_of(c)})
	out.sort_custom(func(a, b): return a["layer"] > b["layer"] if a["layer"] != b["layer"] else a["at"].y < b["at"].y)
	return out


## The screen as text.
func _state() -> String:
	var lines := []
	var screen: Node = main.get("screen")
	var sname := "?"
	if screen and screen.get_script():
		sname = str((screen.get_script() as Script).get_global_name())
	lines.append("SCREEN: %s" % sname)
	# Cards and pop-ups on top: any layer with a named script.
	var tops := []
	var todo: Array = [get_tree().root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		for c in n.get_children():
			todo.append(c)
		if n is CanvasLayer and (n as CanvasLayer).visible and n.get_script() and n != self:
			var nm := str((n.get_script() as Script).get_global_name())
			if nm != "" and nm != sname:
				tops.append("%s (layer %d)" % [nm, (n as CanvasLayer).layer])
	lines.append("ON TOP: %s" % (", ".join(tops) if not tops.is_empty() else "nothing"))
	lines.append("GAS: %d tank(s)   DELIVERED: %d packages   JOBS DONE: %d" % [Progress.total_gas(), Progress.delivered(), Progress.completed.size()])
	if screen is Game:
		lines.append_array(_board(screen as Game))
	lines.append("BUTTONS AND TEXT (topmost layer first; x,y are window pixels):")
	for it in _controls():
		lines.append("  [%d] %s %s @ %d,%d" % [it["layer"], it["kind"], JSON.stringify(it["text"]), it["at"].x, it["at"].y])
	return "\n".join(lines)


func _board(g: Game) -> Array:
	var L := g.level
	var lines := []
	lines.append("LEVEL %d \"%s\"  state: %s%s" % [L.number, L.title, Game.State.keys()[g.state], ("  (input blocked: %s is on top)" % (str((g.modal.get_script() as Script).get_global_name()) if g.modal.get_script() else g.modal.get_class())) if g._busy_modal() else ""])
	lines.append("HINT LINE: %s" % g.hint_label.text.replace("\n", " / "))
	var stack: Array = g.sim_state["stack"].duplicate()
	stack.reverse()
	lines.append("VAN LOAD, next out first: %s" % (", ".join(stack) if not stack.is_empty() else "(empty)"))
	lines.append("FREE UNDOS LEFT: %d   HINTS LEFT: %d" % [g.undo_left, g.hints_left])
	var driven := {}
	for p in g.route:
		driven[p] = true
	var here: Vector2i = g.route.back()
	for y in L.height:
		var row := []
		for x in L.width:
			var p := Vector2i(x, y)
			var t := "."
			if p == here:
				t = "VAN"
			elif L.is_road(p):
				t = "x" if driven.has(p) else "#"
				if L.oneway.has(p):
					t = {Vector2i.UP: "^", Vector2i.DOWN: "v", Vector2i.LEFT: "<", Vector2i.RIGHT: ">"}.get(L.oneway[p], "?") + ("x" if driven.has(p) else "")
				elif L.bridges.has(p):
					t = "+"
				elif L.gates.has(p):
					t = "=" + str(L.gates[p]).left(1)
				elif L.hubs.has(p):
					t = "@"
				elif L.ice.has(p):
					t = "~"
				elif L.works.has(p):
					t = "c%d" % int(L.works[p])
				if p == L.gift and not g.gift_taken:
					t += "*"
			else:
				for h in L.houses.size():
					if L.houses[h].pos == p:
						var left := int(L.houses[h].order) - int(g.sim_state["fills"][h])
						t = str(L.houses[h].color).left(1) + (str(left) if left > 0 else "ok")
				for s in L.shops.size():
					if L.shops[s].pos == p:
						t = str(L.shops[s].color).left(1).to_upper() + "shop"
			row.append(t.rpad(5))
		lines.append("  " + "".join(row))
	lines.append("  (VAN the van; # road; x road already driven, gone; letter+number a house still owed that many of its colour, 'ok' done; * a present on the road; ^ v < > one-way; + bridge; =c gate; @ spinner)")
	return lines
