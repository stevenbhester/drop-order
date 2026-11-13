class_name DebugAuto
extends Node
## Command-line self-tests, driven with real injected mouse events where it matters.
##   -- --autoplay   drive the solver's shortest route as one segment
##   -- --autodrag   draw the shortest route by dragging, in one segment
##   -- --autoseg    draw it by dragging, split into two segments
##   -- --autoundo   drive half the route, undo it, then draw the whole route in segments
##   -- --autostuck  wander randomly until stuck (no-revisit levels)
##   -- --autohint   press Hint and drag what it shows, over and over, until the level is won
##   -- --autoshop   run out of gas, press Retry, buy a (pretend) full tank with a real click
##   -- --autoad     use up the undos, open the (pretend) ad, check Skip waits 3 s, skip it, undo again
##                   (add --watch to sit through the whole ad and press its button)
##   -- --autogift   drive a winning route that picks up the level's present; check it's yours after
##   -- --autodpad   plot the shortest route with real clicks on the D-pad arrows, then click DRIVE BABY DRIVE
##   -- --autobrake  drive a bit, drag back into the wreckage: the line must stop with the red X and nothing
##                   be lost on letting go; then send a plan off with the X showing (the van brakes); then finish
##   -- --autoreplay drive two tiles, press Retry, and report whether it took a gas tank (it shouldn't once
##                   the level's been beaten: try with and without --save=done:N)
##   -- --autoscroll drag the truck sideways (real injected touches); report how far it scrolled (use with
##                   --load-demo=N for a load bigger than fits)
##   -- --autochain=N win N levels in a row through the real Next button (gas, momentum, finish screen)
## With --daily, --autodrag plays today's daily puzzle and checks the record, streak and share text.
## Add --linger=N to stay open N more seconds at the end (for recording).
## Prints one "AUTOTEST" line with the outcome.

var g: Game
var mode := ""

static var _ran := false
## Mega routes: the last part the test ran on (each part is a fresh Game; the test carries on into it).
static var _mega_seen := -1
static var _chain_left := -1
static var _chain_log: Array = []


static func maybe_run(game: Game) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autochain="):
			if _chain_left < 0:
				_chain_left = a.trim_prefix("--autochain=").to_int()
			if _chain_left > 0:
				var c := DebugAuto.new()
				c.g = game
				c.mode = "autochain"
				game.add_child(c)
			return
	if _ran and not (game._twist() == "mega" and game.part > _mega_seen):
		return
	if game._twist() == "mega":
		_mega_seen = game.part
	for m in ["autoplay", "autodrag", "autoseg", "autoundo", "autostuck", "autohint", "autoshop", "autoad", "autogift", "autodpad", "autobrake", "autoreplay", "autoscroll", "autoside", "autotwist", "autoexplain", "autotouch", "autoperf", "autohintad", "autofeedback"]:
		if OS.get_cmdline_user_args().has("--" + m):
			_ran = true
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
		"autofeedback":
			# A report goes all the way out (point it at a test server with --feedback-url=).
			var main := get_tree().root.get_node_or_null("Main")
			var card := FeedbackCard.new()
			card.shot = get_viewport().get_texture().get_image()
			card.where = Feedback.where_of(g)
			get_tree().root.add_child(card)
			await get_tree().process_frame
			card._text.text = "Autotest: the van drove off the edge of the map on level %d." % g.level.number
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--feedback-text="):
					card._text.text = a.trim_prefix("--feedback-text=")
			card._submit()
			var waited := 0.0
			while card._stage == FeedbackCard.Stage.SENDING and waited < 20.0:
				await get_tree().create_timer(0.2).timeout
				waited += 0.2
			print("AUTOTEST feedback: stage=%s id=%s status=%s" % [FeedbackCard.Stage.keys()[card._stage], card._report_id, card._status_text])
			get_tree().quit()
			return
		"autoexplain":
			# Every symbol on the board explains itself (a line for each), and the card closes on a tap.
			var kinds := {}
			var bad := 0
			for y in g.level.height:
				for x in g.level.width:
					var sym: Dictionary = g._symbol_at(Vector2i(x, y))
					if sym.is_empty():
						continue
					g._explain(Vector2i(x, y))
					await get_tree().process_frame
					var card: SymbolCard = g._sym_card
					if card == null or card.line() == "":
						bad += 1
					else:
						kinds[sym["kind"]] = true
					card.close()
					await get_tree().create_timer(0.2).timeout
			print("AUTOTEST explain L%d: kinds=%s bad=%d closed=%s" % [g.level.number, kinds.keys(), bad, g.modal == null])
			get_tree().quit()
			return
		"autoperf":
			# How heavy a long drive is: the CPU time of every frame while the van drives the whole solution
			# (headless runs flat out, so a frame's length is its scripts and drawing). Prints the average, the
			# slow end and the worst, and how many nodes were alive at most.
			# (Headless, Godot otherwise sleeps out each frame to 6.9 ms.)
			Engine.max_fps = 0
			OS.low_processor_usage_mode_sleep_usec = 1
			# --perf-skip=ClassA,ClassB: those nodes stop redrawing every frame, to see what each one costs.
			var skip := []
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--perf-skip="):
					skip = Array(arg.trim_prefix("--perf-skip=").split(","))
			if not skip.is_empty():
				var stack: Array = [get_tree().root]
				while not stack.is_empty():
					var nd: Node = stack.pop_back()
					stack.append_array(nd.get_children())
					var sc: Script = nd.get_script()
					if sc and skip.has(sc.get_global_name()):
						nd.set_process(false)
			var times := PackedFloat32Array()
			var nodes_max := 0
			var done := [false]
			g.segment_finished.connect(func(): done[0] = true, CONNECT_ONE_SHOT)
			g.drive_tiles(sol)
			var last := Time.get_ticks_usec()
			while not done[0]:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				times.append((now - last) / 1000.0)
				last = now
				nodes_max = maxi(nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			var sorted := times.duplicate()
			sorted.sort()
			var total := 0.0
			for t in times:
				total += t
			var n := maxi(times.size(), 1)
			print("AUTOTEST perf L%d: tiles=%d frames=%d avg=%.2fms p95=%.2fms p99=%.2fms max=%.2fms nodes_max=%d" % [g.level.number,
				sol.size(), times.size(), total / n, sorted[int(n * 0.95)] if times.size() > 0 else 0.0,
				sorted[int(n * 0.99)] if times.size() > 0 else 0.0, sorted[n - 1] if times.size() > 0 else 0.0, nodes_max])
			get_tree().quit()
			return
		"autohintad":
			# With the Unlimited hints option on, hints don't count down. Off: three, and the third leaves a
			# tip by the Hint button (it shows for real players; Progress.auto is lifted for it here); the
			# fourth plays a pretend ad, skipped straight away, and hints are free for the rest of the level.
			var notes := []
			Progress.unlimited_hints = true
			g._on_hint_pressed()
			await get_tree().create_timer(0.2).timeout
			notes.append("option_keeps=%s" % (g.hints_left == Game.HINTS_PER_LEVEL))
			Progress.unlimited_hints = false
			Progress.auto = false
			Progress.hint_tips = 0
			Progress.hint_ad_watched = false
			for k in Game.HINTS_PER_LEVEL:
				g._on_hint_pressed()
				await get_tree().create_timer(0.2).timeout
			notes.append("left=%d" % g.hints_left)
			var tipped: bool = g._tip != null and is_instance_valid(g._tip) and g._tip.text.contains("Unlimited hints")
			notes.append("tip=%s" % tipped)
			g._on_hint_pressed()
			await get_tree().create_timer(0.5).timeout
			var ad: PromoAd = g.modal as PromoAd
			var playing: bool = ad != null and ad.kind != "" and ad._t > 0.0
			notes.append("ad=%s" % playing)
			if ad:
				await _click(ad._skip)
				await get_tree().create_timer(0.5).timeout
			notes.append("unlimited=%s watched=%s" % [g.hints_unlimited, Progress.hint_ad_watched])
			var before: int = g.hints_left
			g._on_hint_pressed()
			await get_tree().create_timer(0.2).timeout
			notes.append("after: left=%d modal=%s hint_shown=%s" % [g.hints_left, g._busy_modal(), not g.hint_run.is_empty()])
			var ok: bool = g.hints_unlimited and before == 0 and g.hints_left == 0 and not g._busy_modal() and tipped and playing \
				and Progress.hint_ad_watched and notes[0] == "option_keeps=true"
			Progress.auto = true
			print("AUTOTEST hintad L%d %s: %s" % [g.level.number, "ok" if ok else "FAILED", " ".join(notes)])
			get_tree().quit()
			return
		"autotouch":
			# The symbol card, opened and closed with real touches the way a phone sends them (each touch
			# also makes an emulated mouse event, as on iOS): a tap, a hold, a tap on the card itself, a
			# double tap. Every way must close it and give the game its input back.
			var spot := Vector2i(-1, -1)
			for y in g.level.height:
				for x in g.level.width:
					var t := Vector2i(x, y)
					if spot.x < 0 and not g._symbol_at(t).is_empty() and t != g.level.start:
						spot = t
			if spot.x < 0:
				print("AUTOTEST touch: no symbol on L%d" % g.level.number)
				get_tree().quit()
				return
			var xf := get_viewport().get_final_transform() * g.board.get_global_transform_with_canvas()
			var at: Vector2 = xf * g.board.center(spot)
			var away: Vector2 = get_viewport().get_final_transform() * Vector2(get_viewport().get_visible_rect().size.x * 0.5, get_viewport().get_visible_rect().size.y - 40.0)
			var results := []
			for by_mouse in [false, true]:
				for how in ["tap, then tap away", "tap, then tap the card", "hold, then tap away", "double tap, then tap away", "tap, then drag"]:
					var opened := false
					if how.begins_with("hold"):
						await _touch(at, 0.7, Vector2.ZERO, by_mouse)
					elif how.begins_with("double"):
						await _touch(at, 0.06, Vector2.ZERO, by_mouse)
						await _touch(at, 0.06, Vector2.ZERO, by_mouse)
					else:
						await _touch(at, 0.08, Vector2.ZERO, by_mouse)
					await get_tree().create_timer(0.3).timeout
					opened = g._sym_card != null and is_instance_valid(g._sym_card) and g._busy_modal()
					if how.ends_with("the card") and opened:
						await _touch(get_viewport().get_final_transform() * g._sym_card._box.get_center(), 0.08, Vector2.ZERO, by_mouse)
					elif how.ends_with("drag"):
						await _touch(away, 0.2, Vector2(0, -160), by_mouse)
					else:
						await _touch(away, 0.08, Vector2.ZERO, by_mouse)
					await get_tree().create_timer(0.5).timeout
					var gone: bool = (g._sym_card == null or not is_instance_valid(g._sym_card)) and not g._busy_modal()
					results.append("%s %s: opened=%s closed=%s" % ["mouse" if by_mouse else "touch", how, opened, gone])
					if not gone and g._sym_card and is_instance_valid(g._sym_card):
						g._sym_card.close()
						await get_tree().create_timer(0.4).timeout
			var ok := results.all(func(r): return r.ends_with("opened=true closed=true"))
			print("AUTOTEST touch L%d %s: %s" % [g.level.number, "ok" if ok else "FAILED", " | ".join(results)])
			get_tree().quit()
			return
		"autotwist":
			# A side road's twist actually bites (run with --side=<id>).
			var tw: String = g._twist()
			var ok := false
			var note := ""
			match tw:
				"one_shot":
					g.drive_tiles(sol.slice(0, half))
					await g.segment_finished
					ok = g.state == Game.State.FAILED
					note = "half a run then stop: failed=%s" % ok
				"fuel":
					var cap: int = g._fuel_cap()
					g.drive_tiles(sol.slice(0, half))
					await g.segment_finished
					ok = g._fuel_left() == cap - (half - 1)
					note = "cap %d, after %d moves left %d" % [cap, half - 1, g._fuel_left()]
				"melt":
					g.play_time = float(g.side.get("seconds", 60)) + 0.5
					await get_tree().create_timer(0.3).timeout
					ok = g.state == Game.State.FAILED
					note = "clock out: failed=%s" % ok
				"mega":
					g.drive_tiles(sol)
					await g.segment_finished
					var id := str(g.side.get("id", ""))
					ok = Progress.mega_part(id) == 1 and g.route.back() == g.level.exit
					note = "part 1 done on the exit, saved as part %d" % Progress.mega_part(id)
				"fog":
					await get_tree().create_timer(float(g.side.get("peek", 6)) + 0.4).timeout
					var shown := 0
					for b in g.stack_view.boxes:
						if not b.fogged:
							shown += 1
					ok = g.stack_view.fog and shown == 1
					note = "fogged=%s, packages showing=%d of %d" % [g.stack_view.fog, shown, g.stack_view.boxes.size()]
			print("AUTOTEST twist %s: %s ok=%s" % [tw, note, ok])
			get_tree().quit()
			return
		"autoside":
			# The chute in each spot (as if changed in the options mid-level): on screen, clear of the board
			# and the words; then the level's played out from the last spot.
			var ok := true
			var vr := g.get_viewport_rect()
			for side in ["top", "right", "bottom", "auto", "left"]:
				Progress.stack_side = side
				g._on_settings()
				await get_tree().process_frame
				var sv := g.stack_view
				var chute := Rect2(sv.position - sv.origin_in(), sv.extent())
				var bk := g.board.scale.x
				var tk := g.board.tile * bk
				var board := Rect2(g.board.position - Vector2(tk * 0.15, tk * 0.14), g.board.size_px() * bk + Vector2(tk * 0.3, tk * 0.35))
				var shown: float = g.hint_label.get_line_height() * g.hint_label.get_visible_line_count()
				var words := Rect2(g.hint_label.position, Vector2(g.hint_label.size.x, shown))
				var fine := vr.encloses(chute) and not chute.intersects(board) and not (g.hint_label.text != "" and chute.intersects(words))
				ok = ok and fine
				print("AUTOTEST side %s L%d: chute=%s board=%s words=%s vr=%s fits=%s" % [side, g.level.number, chute, board, words, vr, fine])
			for p in pieces:
				await _drag(p)
			print("AUTOTEST sides L%d: all_fit=%s" % [g.level.number, ok])
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
		"autohint":
			# Following hints to the win (the three-hint budget and its ad are autohintad's to test).
			g.hints_unlimited = true
			var presses := 0
			while g.state != Game.State.WON and presses < 80:
				g._on_hint_pressed()
				presses += 1
				if g.hint_run.size() < 2:
					break
				if OS.get_cmdline_user_args().has("--peek"):
					await get_tree().create_timer(2.0).timeout
					break
				await get_tree().create_timer(0.15).timeout
				await _drag(g.hint_run.duplicate())
			print("AUTOTEST hints L%d: %d hint(s) pressed, stars on offer %d" % [g.level.number, presses, 3 - int(g.hint_used) - int(g.undo_used)])
		"autoshop":
			await _shop_test(sol)
			return
		"autoreplay":
			g.drive_tiles(sol.slice(0, 3))
			await g.segment_finished
			var beaten := Progress.is_complete(g.level.number)
			var gas_before := Progress.gas
			var badge: String = g.retry_button.badge
			g._retry()
			print("AUTOTEST replay L%d: beaten=%s gas %d -> %d paid=%s badge='%s'" % [g.level.number, beaten, gas_before, Progress.gas, g.retry_paid, badge])
			get_tree().quit()
			return
		"autoscroll":
			var sv := g.stack_view
			var xf := get_viewport().get_final_transform() * sv.get_global_transform_with_canvas()
			var at := sv._back() * sv.box * 3.0
			var can := sv.can_scroll()
			_mouse(xf * at, true)
			for k in 12:
				await get_tree().process_frame
				var m := InputEventMouseMotion.new()
				m.position = xf * (at - sv._back() * sv.box * 0.5 * (k + 1))
				m.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(m)
			await get_tree().process_frame
			var moved := sv.view()
			if _linger() > 0.0:
				await get_tree().create_timer(0.8).timeout
			_mouse(xf * (at - sv._back() * sv.box * 6.0), false)
			await get_tree().create_timer(1.8).timeout
			print("AUTOTEST scroll L%d: aboard=%d can_scroll=%s scrolled_to=%d max=%d back_to_front=%s" % [g.level.number, sv.boxes.size(), can,
				moved, sv.max_view(), sv.view() == 0])
			get_tree().quit()
			return
		"autodpad":
			await _dpad(sol)
		"autobrake":
			# The first point on the route where turning straight back runs into the wreckage (on some
			# levels an arrow or a gate forbids that U-turn anyway, which isn't the same thing).
			var k := 2
			var st := Sim.run(g.level, sol.slice(0, 3))
			while k < sol.size() - 2 and not Sim.wrecked(g.level, sol.slice(0, k + 1), sol[k - 1], st):
				k += 1
				Sim.arrive(g.level, st, sol[k])
			g.drive_tiles(sol.slice(0, k + 1))
			await g.segment_finished
			var at := g.route.size()
			var xf := get_viewport().get_final_transform() * g.board.get_global_transform_with_canvas()
			if g.dpad_mode:
				print("AUTOTEST brake needs draw mode")
			# 1. Press on the van and drag straight back over the road just driven.
			_mouse(xf * g.board.center(sol[k]), true)
			for s in 8:
				await get_tree().process_frame
				var m := InputEventMouseMotion.new()
				m.position = xf * g.board.center(sol[k]).lerp(g.board.center(sol[k - 1]), (s + 1) / 8.0)
				m.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(m)
			await get_tree().process_frame
			var x_shown: bool = g.board.crash_mark.visible and g.blocked_at == sol[k - 1]
			var stopped: bool = g.seg.size() == 1
			if _linger() > 0.0:
				await get_tree().create_timer(1.0).timeout
			_mouse(xf * g.board.center(sol[k - 1]), false)
			await get_tree().process_frame
			var kept: bool = g.state == Game.State.IDLE and g.route.size() == at and g.history.size() == 1
			# 2. Plan the next tile, then send it off while pushing into wreckage: it drives, brakes, carries on.
			g._press(g.board.center(sol[k]))
			g._drag(g.board.center(sol[k + 1]))
			g.blocked_at = sol[k]
			g._release()
			await g.segment_finished
			var braked: bool = g.state != Game.State.FAILED and g.route.size() == at + 1
			print("AUTOTEST brake L%d: x_shown=%s line_stopped=%s nothing_lost=%s braked_ok=%s" % [g.level.number, x_shown, stopped, kept, braked])
			if g.state == Game.State.IDLE:
				g.drive_tiles(sol.slice(k + 1))
				await g.segment_finished
		"autoad":
			await _ad_test(sol)
		"autogift":
			var gr := Solver.gift_route(g.level)
			if gr.is_empty():
				print("AUTOTEST gift L%d: no present on this level" % g.level.number)
			else:
				var owned_before := Progress.owns(g.level.gift_item)
				for p in _split_uturns(gr):
					await _drag(p)
				await get_tree().create_timer(2.6).timeout
				print("AUTOTEST gift L%d: item=%s owned_before=%s picked_up=%s owned_after=%s worn=%s finish_says_new=%s" % [
					g.level.number, g.level.gift_item, owned_before, g.gift_taken, Progress.owns(g.level.gift_item),
					Progress.paint == g.level.gift_item or Progress.topper == g.level.gift_item, g.finish != null and g.finish.new_item == g.level.gift_item])
		"autochain":
			for p in pieces:
				await _drag(p)
			await get_tree().create_timer(2.4 + _linger() * 0.5).timeout
			_chain_left -= 1
			_chain_log.append("L%d:%s m=%d gas=%d" % [g.level.number, Game.State.keys()[g.state], Progress.momentum, Progress.gas])
			if _chain_left <= 0 or g.state != Game.State.WON:
				print("AUTOTEST chain: ", ", ".join(_chain_log), " | trail momentum=", g.board.fire.momentum)
				await get_tree().create_timer(0.3 + _linger()).timeout
				get_tree().quit()
				return
			await _click(g.finish._next)
			return
	if g.daily_day >= 0:
		await get_tree().create_timer(0.6).timeout
		var r := Progress.daily_record(g.daily_day)
		print("AUTOTEST daily #%d: done=%s ok=%s attempts=%d stars=%d streak=%d order=%s" % [Daily.number(g.daily_day), r.get("done", false),
			r.get("ok", false), int(r.get("attempts", 0)), int(r.get("stars", 0)), Progress.streak(g.daily_day), r.get("order", [])])
		print("AUTOTEST share text:\n" + Daily.share_text(g.daily_day, r, Progress.streak(g.daily_day)))
	if g._twist() == "mega" and g.part < g._parts() - 1:
		# A mega route's part: done means parked on the exit; the next part's Game takes over the test.
		print("AUTOTEST mega part %d/%d: state=%s on_exit=%s" % [g.part + 1, g._parts(), Game.State.keys()[g.state], g.route.back() == g.level.exit])
		return
	await get_tree().create_timer(0.5).timeout
	var synced: bool = g.stack_view.colors == g.sim_state["stack"]
	print("AUTOTEST %s L%d: state=%s route=%d tiles, packages left=%d, solution=%d tiles, stack_view_synced=%s" % [
		mode, g.level.number, Game.State.keys()[g.state], g.route.size(), Sim.remaining(g.level, g.sim_state), sol.size(), synced])
	await get_tree().create_timer(0.8 + _linger()).timeout
	get_tree().quit()


## Plots `tiles` on the D-pad with real clicks on its arrows, then clicks DRIVE BABY DRIVE.
func _dpad(tiles: Array) -> void:
	if not g.dpad_mode:
		g.set_dpad_mode(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var xf := get_viewport().get_final_transform() * g.dpad.get_global_transform_with_canvas()
	for k in tiles.size() - 1:
		var d: Vector2i = tiles[k + 1] - tiles[k]
		var at: Vector2 = xf * g.dpad.key_center(d)
		_mouse(at, true)
		await get_tree().process_frame
		_mouse(at, false)
		await get_tree().process_frame
	if g.seg != tiles:
		print("AUTOTEST dpad mismatch: plotted ", g.seg, " wanted ", tiles)
	await _click(g.drive_button)
	await g.segment_finished


func _linger() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--linger="):
			return a.trim_prefix("--linger=").to_float()
	return 0.0


## Clicks the middle of a Control with real injected mouse events.
func _click(c: Control) -> void:
	var at: Vector2 = get_viewport().get_final_transform() * (c.global_position + c.size / 2.0)
	_mouse(at, true)
	await get_tree().process_frame
	_mouse(at, false)
	await get_tree().process_frame


func _shop_test(sol: Array) -> void:
	Progress.gas = 0
	Progress.gas_t = Time.get_unix_time_from_system()
	Progress.changed.emit()
	g.drive_tiles(sol.slice(0, 2))
	await g.segment_finished
	await _click(g.retry_button)
	await get_tree().create_timer(1.0 + _linger() * 0.5).timeout
	var opened := g.modal is GasShop
	var before := Progress.dollaroos
	if opened:
		await _click((g.modal as GasShop)._buy)
	await get_tree().create_timer(1.4).timeout
	print("AUTOTEST shop L%d: opened=%s gas=%d paid=%d closed=%s still_on_level=%s" % [
		g.level.number, opened, Progress.gas, before - Progress.dollaroos, not g._busy_modal(), g.route.size() == 2])
	# With gas again, Retry restarts the level (this node goes with the old one, so the tree quits us).
	var tree := get_tree()
	tree.create_timer(1.2 + _linger() * 0.5).timeout.connect(func():
		print("AUTOTEST shop retry: gas=%d" % Progress.gas)
		tree.quit())
	await _click(g.retry_button)


func _ad_test(sol: Array) -> void:
	var watch := OS.get_cmdline_user_args().has("--watch")
	g.drive_tiles(sol.slice(0, 2))
	await g.segment_finished
	await _click(g.undo_button)
	for f in 600:
		if g.state == Game.State.IDLE:
			break
		await get_tree().process_frame
	var free_used := g.undos_available() == 0 and g.route.size() == 1
	g.drive_tiles(sol.slice(0, 2))
	await g.segment_finished
	await get_tree().create_timer(0.4 + (1.0 if watch else 0.0)).timeout
	await _click(g.undo_button)
	await get_tree().create_timer(FakeAd.SKIP_AFTER * 0.4).timeout
	var opened := g.modal is FakeAd
	var early := false
	if opened:
		var ad := g.modal as FakeAd
		await _click(ad._skip)
		early = not g._busy_modal()
		if watch:
			await get_tree().create_timer(FakeAd.END_AT + 1.2).timeout
			await _click(ad._cta)
			await get_tree().create_timer(3.2).timeout
		else:
			await get_tree().create_timer(FakeAd.SKIP_AFTER).timeout
			if is_instance_valid(ad):
				await _click(ad._skip)
			await get_tree().create_timer(0.4).timeout
	var bank := Progress.undo_bank
	await get_tree().create_timer(0.6).timeout
	await _click(g.undo_button)
	for f in 600:
		if g.state == Game.State.IDLE:
			break
		await get_tree().process_frame
	print("AUTOTEST ad L%d: free_undo_used=%s ad_opened=%s skipped_early=%s closed=%s bank_after_ad=%d bank_after_undo=%d route=%d" % [
		g.level.number, free_used, opened, early, not g._busy_modal(), bank, Progress.undo_bank, g.route.size()])


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


## A finger on the screen at `pos` (window pixels) for `hold` seconds, sliding by `slide` on the way, as a
## phone reports it: touch events, which Godot also turns into mouse events (emulate_mouse_from_touch).
## With `by_mouse`, a mouse click and drag instead, as on a computer.
func _touch(pos: Vector2, hold: float, slide := Vector2.ZERO, by_mouse := false) -> void:
	if by_mouse:
		_mouse(pos, true)
		var n := 6 if slide != Vector2.ZERO else 1
		for k in n:
			await get_tree().create_timer(hold / n).timeout
			if slide != Vector2.ZERO:
				var m := InputEventMouseMotion.new()
				m.position = pos + slide * (k + 1) / n
				m.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(m)
		_mouse(pos + slide, false)
		await get_tree().process_frame
		return
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	var steps := 6 if slide != Vector2.ZERO else 0
	for k in steps:
		await get_tree().create_timer(hold / steps).timeout
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = pos + slide * (k + 1) / steps
		d.relative = slide / steps
		Input.parse_input_event(d)
	if steps == 0:
		await get_tree().create_timer(hold).timeout
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = pos + slide
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	Input.parse_input_event(ev)
