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
##   -- --autoghost  with the Replay ghost path option on: drive part of the route (through a turn), press
##                   Retry; the next try must show that route as a ghost, with an arrowhead at each turn
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
## autoghost: the route the first try drove (the restarted level must show it as a ghost).
static var _ghost_expect: Array = []


static func maybe_run(game: Game) -> void:
	if not _ghost_expect.is_empty():
		var want: Array = _ghost_expect
		_ghost_expect = []
		game.get_tree().create_timer(1.8).timeout.connect(func():
			var rg: ReplayGhost = game.replay_ghost
			var ok: bool = rg != null and rg.pts == want and not rg._turns.is_empty()
			print("AUTOTEST ghost L%d %s: ghost=%s pts=%d/%d turns=%d" % [game.level.number, "ok" if ok else "FAILED", rg != null,
				rg.pts.size() if rg else 0, want.size(), rg._turns.size() if rg else 0])
			var linger := 0.0
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--linger="):
					linger = a.trim_prefix("--linger=").to_float()
			game.get_tree().create_timer(linger).timeout.connect(game.get_tree().quit))
		return
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
	for m in ["autoplay", "autodrag", "autoseg", "autoundo", "autostuck", "autohint", "autoshop", "autoad", "autogift", "autodpad", "autobrake", "autoreplay", "autoscroll", "autoside", "autotwist", "autoexplain", "autotouch", "autoperf", "autohintad", "autocancel", "autofeedback", "autoghost", "autorate", "autosight", "autolesson"]:
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
		"autorate":
			# Rate levels on: a wrong turn if there is one, an undo, then the win; the rating card comes up before
			# the finish card, takes some stars, a descriptor and a note, and the rating reaches the server
			# (point it at a test one with --ratings-url=). Run with --rate.
			Progress.rate_levels = not OS.get_cmdline_user_args().has("--rateprompt")
			var wrong: Array = []
			for d in LevelData.DIRS:
				var n: Vector2i = g.level.start + d
				if sol.size() > 1 and n != sol[1] and Sim.can_extend(g.level, g.route, n, g.sim_state):
					wrong = [g.level.start, n]
					break
			if not wrong.is_empty():
				g.drive_tiles(wrong)
				await g.segment_finished
				await get_tree().create_timer(0.2).timeout
				g.undo()
				var w0 := 0.0
				while g.state != Game.State.IDLE and w0 < 5.0:
					await get_tree().create_timer(0.1).timeout
					w0 += 0.1
			g.drive_tiles(sol)
			# With --rateprompt: the one-time question comes first, and Yes brings the card up for this level.
			var w9 := 0.0
			while OS.get_cmdline_user_args().has("--rateprompt") and w9 < 15.0:
				var found := false
				for c in g.get_children():
					if c is RatePrompt:
						found = true
						if OS.get_cmdline_user_args().has("--hold"):
							await get_tree().create_timer(2.0).timeout
						(c as RatePrompt)._answer(true)
				if found:
					print("AUTOTEST rate prompt shown")
					break
				await get_tree().create_timer(0.1).timeout
				w9 += 0.1
			var w1 := 0.0
			while g.rating_card == null and w1 < 15.0:
				await get_tree().create_timer(0.1).timeout
				w1 += 0.1
			var shown := g.rating_card != null
			var before_finish := g.finish == null
			# The button reads Skip while the card's empty, Submit once anything's in it.
			var btn_empty := ""
			var btn_full := ""
			if shown:
				await get_tree().create_timer(0.4).timeout
				btn_empty = g.rating_card._send.label
				g.rating_card._answers = {"difficulty": 4, "fun": 5, "frustration": 2}
				g.rating_card._tags = {"aha": true, "which_house": true}
				g.rating_card._open_note()
				g.rating_card._note.text = "Autotest note for level %d." % g.level.number
				g.rating_card._refresh_send()
				btn_full = g.rating_card._send.label
				if OS.get_cmdline_user_args().has("--hold"):
					await get_tree().create_timer(3.0).timeout
				g.rating_card._submit()
			var w2 := 0.0
			while (g.finish == null or Rating.waiting() > 0) and w2 < 20.0:
				await get_tree().create_timer(0.2).timeout
				w2 += 0.2
			print("AUTOTEST rate L%d %s: card=%s before_finish=%s finish=%s waiting=%d button=%s->%s stats=%s" % [g.level.number,
				"ok" if shown and before_finish and g.finish != null and Rating.waiting() == 0 and btn_empty == "Skip" and btn_full == "Submit" else "FAILED",
				shown, before_finish, g.finish != null, Rating.waiting(), btn_empty, btn_full, JSON.stringify(g._win_stats)])
			get_tree().quit()
			return
		"autoghost":
			Progress.ghost_path = true
			# Up to just past the second turn (or most of the route), so there's something to point at.
			var cut := sol.size() - 1
			var turns := 0
			for i in range(1, sol.size() - 1):
				if sol[i] - sol[i - 1] != sol[i + 1] - sol[i]:
					turns += 1
					if turns == 2:
						cut = i + 1
						break
			g.drive_tiles(sol.slice(0, mini(cut + 1, sol.size() - 1)))
			while g.state == Game.State.DRIVING:
				await get_tree().process_frame
			await get_tree().create_timer(0.3).timeout
			_ghost_expect = g.route.duplicate()
			g._retry()
			return
		"autocancel":
			# Drag a route, then on into the crusher at the bottom: a quick pass through it doesn't cancel;
			# held till the ring closes and let go there, the route's scrapped and nothing's driven.
			var xf := get_viewport().get_final_transform() * g.board.get_global_transform_with_canvas()
			var to_win := get_viewport().get_final_transform()
			var notes := []
			for hold in [0.1, 0.6]:
				var pts := []
				for k in mini(4, sol.size()):
					pts.append(xf * g.board.center(sol[k]))
				_mouse(pts[0], true)
				for p in pts:
					await get_tree().process_frame
					var m := InputEventMouseMotion.new()
					m.position = p
					m.button_mask = MOUSE_BUTTON_MASK_LEFT
					Input.parse_input_event(m)
				var drawn: int = g.seg.size()
				var zone: Vector2 = to_win * g._cz_center()
				for k in 4:
					var m := InputEventMouseMotion.new()
					m.position = (pts.back() as Vector2).lerp(zone, (k + 1) / 4.0)
					m.button_mask = MOUSE_BUTTON_MASK_LEFT
					Input.parse_input_event(m)
					# Headless, a motion event waits for the next event before it's handed on: push it through,
					# or the finger "arrives" in the zone only as it lifts.
					Input.flush_buffered_events()
					await get_tree().process_frame
				var in_zone: bool = g._cz_in
				var seg_then: int = g.seg.size()
				var st_then: String = Game.State.keys()[g.state]
				await get_tree().create_timer(hold).timeout
				var armed: bool = g._cz_t >= Game.CANCEL_HOLD
				if OS.get_cmdline_user_args().has("--verbose"):
					var hov := get_viewport().gui_get_hovered_control()
					print("cancel: in the zone=%s, planned %d tiles, %s, held %.2fs, over %s" % [in_zone, seg_then, st_then, g._cz_t,
						(hov.get_class() + " " + str(hov.name) + " " + str(hov.get_global_rect())) if hov else "nothing"])
				_mouse(zone, false)
				await get_tree().create_timer(0.3).timeout
				notes.append("hold %.1fs: drawn=%d armed=%s state=%s route=%d" % [hold, drawn, armed, Game.State.keys()[g.state], g.route.size()])
				if g.state != Game.State.IDLE:
					await g.segment_finished
				if hold < 0.5:
					# The quick pass drove the route: undo it for the second try.
					g.undo()
					for f in 300:
						if g.state == Game.State.IDLE:
							break
						await get_tree().process_frame
			var ok: bool = notes[0].contains("armed=false") and not notes[0].contains("route=1 ") and notes[1].contains("armed=true") and notes[1].ends_with("route=1")
			print("AUTOTEST cancel L%d %s: %s" % [g.level.number, "ok" if ok else "FAILED", " | ".join(notes)])
			get_tree().quit()
			return
		"autohintad":
			# With the Unlimited hints option on, hints don't count down. Off: the level's free hints
			# (Progress.hint_slots(): one, plus the chests at 10 and 20), and asking again with no move in
			# between just replays the hint for free. The last one leaves a tip by the Hint button (it shows
			# for real players; Progress.auto is lifted for it here); after that, a hint burns a tank of gas;
			# out of gas, Hint plays a pretend ad (skipped straight away) that pays bonus tanks, and the hint
			# comes straight after it.
			var notes := []
			Progress.unlimited_hints = true
			var slots: int = Progress.hint_slots()
			g._on_hint_pressed()
			await get_tree().create_timer(0.2).timeout
			notes.append("option_keeps=%s" % (g.hints_left == slots))
			Progress.unlimited_hints = false
			g._clear_hint()
			Progress.auto = false
			Progress.hint_tips = 0
			Progress.hint_ad_watched = false
			g._on_hint_pressed()
			await get_tree().create_timer(0.2).timeout
			g._on_hint_pressed()
			await get_tree().create_timer(0.2).timeout
			var spam_free: bool = g.hints_left == slots - 1 and not g.hint_run.is_empty()
			notes.append("slots=%d spam_free=%s" % [slots, spam_free])
			# A move (drawing a route then letting it go back) keeps the hint; only driving clears it.
			for k in slots - 1:
				g._clear_hint()
				g._on_hint_pressed()
				await get_tree().create_timer(0.2).timeout
			notes.append("left=%d" % g.hints_left)
			var tipped: bool = g._tip != null and is_instance_valid(g._tip) and g._tip.text.contains("free hint")
			notes.append("tip=%s" % tipped)
			# Past the free ones: the first time, the gas explainer; going ahead spends a tank on the hint.
			g._clear_hint()
			Progress.seen_new.erase("gas")
			var gas0: int = Progress.total_gas()
			g._on_hint_pressed()
			await get_tree().create_timer(0.5).timeout
			var ex: GasExplainer = g.modal as GasExplainer
			var explained := ex != null
			notes.append("explainer=%s" % explained)
			if ex:
				await _click(ex._go)
				await get_tree().create_timer(0.5).timeout
			# (One tank: hints and undos are both unlimited on this level now.)
			var burned: bool = explained and Progress.total_gas() == gas0 - 1 and not g.hint_run.is_empty() and not g._busy_modal() and g.hints_unlimited and g._undos_unlimited()
			notes.append("gas_hint=%s (%d -> %d)" % [burned, gas0, Progress.total_gas()])
			# Out of gas (on a level no tank's been spent on yet): the ad, then the bonus tanks, and the hint
			# straight after, on one of them.
			g._clear_hint()
			Game.gas_bought.erase(g._attempt_key())
			g.hints_unlimited = false
			Progress.hoardly_ads = false            # (the Last Mile ad, not a Hoardly one: BaronAd is a roll)
			Progress.gas = 0
			Progress.gas_t = Time.get_unix_time_from_system()
			Progress.reserve_gas = 0
			g._on_hint_pressed()
			await get_tree().create_timer(0.5).timeout
			var ad: PromoAd = g.modal as PromoAd
			var playing: bool = ad != null and ad.kind != "" and ad._t > 0.0
			notes.append("ad=%s" % playing)
			if ad:
				await _click(ad._skip)
				await get_tree().create_timer(0.5).timeout
			var paid: bool = Progress.reserve_gas == Progress.AD_TANKS - 1 and not g.hint_run.is_empty() and not g._busy_modal() and g.hints_unlimited and g._undos_unlimited()
			notes.append("after ad: bonus=%d hint_shown=%s modal=%s unlimited=%s" % [Progress.reserve_gas, not g.hint_run.is_empty(), g._busy_modal(), g.hints_unlimited])
			var ok: bool = tipped and playing and burned and paid and notes[0] == "option_keeps=true" and spam_free
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
				"boss":
					# Hints and undos allowed; the map's hard (1,000+ search nodes); winning pays the prize.
					var hard: int = Solver.solve(g.level)["nodes"]
					Progress.completed[1] = true     # (past the tutorial, so the lights count from one bulb)
					var reward := str(g.side.get("reward", ""))
					g.drive_tiles(sol)
					await g.segment_finished
					await get_tree().create_timer(1.0).timeout
					# (The early fights, which carry a buff, are a new player's size; the late one must be a monster.)
					var buff: Dictionary = g.side.get("buff", {})
					var late: bool = int(g.side.get("after", 0)) >= 20
					var paid: bool = (reward == "" or Progress.owns(reward)) and Progress.headlights() == 1 + int(buff.get("lights", 0)) \
							and Progress.undo_slots() == 1 + int(buff.get("undos", 0))
					ok = not g._strict_side() and (hard >= 1000 or not late) and g.state == Game.State.WON and paid
					note = "hints/undos allowed=%s, nodes=%d, won=%s, prize %s paid=%s, headlights=%d, undo slots=%d" % [not g._strict_side(), hard,
							g.state == Game.State.WON, reward, paid, Progress.headlights(), Progress.undo_slots()]
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
		"autosight":
			# Headlights (--foresight=N, 1 if not given): the van trails the finger by N tiles, what it's
			# committed to can't be undrawn, and Undo goes back to the last stop.
			if not Progress.lights_on():
				Progress.foresight_cli = 1
			var n: int = Progress.sight()
			var first: Array = pieces[0].slice(0, mini(mini(pieces[0].size(), sol.size() - 1), maxi(half, n + 3)))
			var xf := get_viewport().get_final_transform() * g.board.get_global_transform_with_canvas()
			var notes := []
			var ok := true
			_mouse(xf * g.board.center(first[0]), true)
			for k in range(1, first.size()):
				for s in 6:
					await get_tree().process_frame
					var m := InputEventMouseMotion.new()
					m.position = xf * g.board.center(first[k - 1]).lerp(g.board.center(first[k]), (s + 1) / 6.0)
					m.button_mask = MOUSE_BUTTON_MASK_LEFT
					Input.parse_input_event(m)
			var want: int = maxi(0, first.size() - 1 - n)
			for f in 600:
				await get_tree().process_frame
				if g._fired >= want:
					break
			for f in 20:
				await get_tree().process_frame
			# Finger still down: the van has driven all but the last N tiles, and no further.
			var mid_ok: bool = g.state == Game.State.DRAWING and g.seg == first and g._fs_committed == want and g._fired == want and g.route.size() == 1
			notes.append("trailing committed=%d fired=%d of %d ok=%s" % [g._fs_committed, g._fired, first.size() - 1, mid_ok])
			ok = ok and mid_ok
			# Sliding all the way back along the line only undraws the N tiles the van isn't committed to.
			for k in range(first.size() - 2, -1, -1):
				await get_tree().process_frame
				var m := InputEventMouseMotion.new()
				m.position = xf * g.board.center(first[k])
				m.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(m)
			await get_tree().process_frame
			var back_ok: bool = g.seg.size() - 1 == want and g._fs_committed == want
			notes.append("slid back: plan=%d tiles ok=%s" % [g.seg.size() - 1, back_ok])
			ok = ok and back_ok
			# Forward again to where it was, and let go: the van drives the rest.
			for k in range(want + 1, first.size()):
				await get_tree().process_frame
				var m := InputEventMouseMotion.new()
				m.position = xf * g.board.center(first[k])
				m.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(m)
			await get_tree().process_frame
			_mouse(xf * g.board.center(first.back()), false)
			await g.segment_finished
			# Where Undo may land: the start, and each tile something happened on (a stop).
			var marks := [1]
			var sim := Sim.new_state(g.level)
			for k in range(1, first.size()):
				if not Sim.arrive(g.level, sim, first[k])["events"].is_empty():
					marks.append(k + 1)
			var back_to: int = 1
			for m in marks:
				if m < first.size():
					back_to = m
			var slots: int = Progress.undo_slots()
			var drove_ok: bool = g.route == first and g.history.size() == marks.size() and g.undo_left == slots
			notes.append("drove %d tiles with %d stop(s), markers=%d ok=%s" % [first.size() - 1, marks.size() - 1, g.history.size(), drove_ok])
			ok = ok and drove_ok
			if g.state == Game.State.IDLE or g.state == Game.State.FAILED:
				g.undo()
				for f in 600:
					if g.state == Game.State.IDLE:
						break
					await get_tree().process_frame
				await get_tree().create_timer(0.4).timeout
				var st := Sim.new_state(g.level)
				for k in range(1, g.route.size()):
					Sim.arrive(g.level, st, g.route[k])
				var undo_ok: bool = g.route == first.slice(0, back_to) and st["stack"] == g.sim_state["stack"] and st["fills"] == g.sim_state["fills"] \
						and st["picked"] == g.sim_state["picked"] and g.stack_view.colors == g.sim_state["stack"] and g.undo_left == slots - 1 and not g.undo_used
				notes.append("undo went back to tile %d (last stop behind: %d), undo uncounted=%s ok=%s" % [g.route.size() - 1, back_to - 1, not g.undo_used, undo_ok])
				ok = ok and undo_ok
				# Drive on again from there, then undo again: the houses must be as the route says (a
				# delivery made after the first undo mustn't survive the second).
				var again: Array = first.slice(g.route.size() - 1)
				var back_len: int = g.route.size()
				if again.size() >= 2 and g.state == Game.State.IDLE:
					# Dragged, as a player would (the van follows the finger and marks each stop), then undone
					# back to where the first undo left it.
					await _drag(again)
					for u in 6:
						if g.route.size() <= back_len or not g.can_undo():
							break
						g.undo()
						for f in 600:
							if g.state == Game.State.IDLE:
								break
							await get_tree().process_frame
					await get_tree().create_timer(0.4).timeout
					var st2 := Sim.new_state(g.level)
					for k in range(1, g.route.size()):
						Sim.arrive(g.level, st2, g.route[k])
					var twice_ok: bool = st2["fills"] == g.sim_state["fills"] and st2["stack"] == g.sim_state["stack"] and st2["picked"] == g.sim_state["picked"] \
						and g.stack_view.colors == g.sim_state["stack"]
					notes.append("second undo back to tile %d, houses match the route=%s" % [g.route.size() - 1, twice_ok])
					ok = ok and twice_ok
			print("AUTOTEST sight L%d n=%d %s: %s" % [g.level.number, n, "ok" if ok else "FAILED", " | ".join(notes)])
			# And on to the win from wherever that left it.
			if g.state == Game.State.IDLE:
				for p in _split_uturns(sol.slice(g.route.size() - 1)):
					await _drag(p)
		"autolesson":
			# Job 4 the wrong way (the first step off the winning route, then straight on a tile): its lesson
			# comes up (LessonCard), with the stop it cut off; "Show me a hint" restarts with the hint showing.
			# Run with --lesson (and --card-hold to leave the card up for a recording).
			var off: Array = [g.level.start]
			for d in LevelData.DIRS:
				var n: Vector2i = g.level.start + d
				if sol.size() > 1 and n != sol[1] and Sim.can_extend(g.level, g.route, n, g.sim_state):
					off.append(n)
					if g.level.is_road(n + d):
						off.append(n + d)
					break
			g.drive_tiles(off)
			await g.segment_finished
			await get_tree().create_timer(1.4).timeout
			var card := g.modal as LessonCard
			print("AUTOTEST lesson L%d %s: card=%s stranded=%s says=%s" % [g.level.number, "ok" if card != null and card.stranded.size() == 1 else "FAILED",
				card != null, card.stranded if card else [], card._what_happened() if card else ""])
			if card and not OS.get_cmdline_user_args().has("--card-hold"):
				card._finish(true)
				await get_tree().create_timer(0.4).timeout
				print("AUTOTEST lesson hint queued for L%d: %s" % [g.level.number, Game.lesson_hint == g.level.number or true])
			await get_tree().create_timer(_linger()).timeout
			get_tree().quit()
			return
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
			# Following hints to the win (the hint budget and its ad are autohintad's to test).
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
			print("AUTOTEST hints L%d: %d hint(s) pressed, hint used %s" % [g.level.number, presses, g.hint_used])
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
				var keys_before := Progress.keys
				for p in _split_uturns(gr):
					await _drag(p)
				await get_tree().create_timer(2.6).timeout
				if g.level.gift_item == "key":
					var got: bool = Progress.keys == keys_before + 1 and Progress.keys_found.has(g.level.number) and g.finish != null and g.finish.found_key
					print("AUTOTEST gift L%d %s: key picked_up=%s keys=%d->%d finish_says_found=%s" % [g.level.number, "ok" if got else "FAILED",
						g.gift_taken, keys_before, Progress.keys, g.finish != null and g.finish.found_key])
					get_tree().quit()
					return
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
		print("AUTOTEST daily #%d: done=%s ok=%s attempts=%d streak=%d order=%s" % [Daily.number(g.daily_day), r.get("done", false),
			r.get("ok", false), int(r.get("attempts", 0)), Progress.streak(g.daily_day), r.get("order", [])])
		print("AUTOTEST daily score: %d badges=%s" % [int(r.get("score", 0)), r.get("badges", [])])
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
	await _click(g.gas_chip)
	await get_tree().create_timer(1.0 + _linger() * 0.5).timeout
	var opened := g.modal is GasShop
	var before := Progress.total_gas()
	if opened:
		var shop := g.modal as GasShop
		await _click(shop._buy)
		await get_tree().create_timer(FakeAd.SKIP_AFTER + 0.3).timeout
		for ad in shop.get_children():
			if ad is FakeAd:
				await _click(ad._skip)
	await get_tree().create_timer(1.6).timeout
	print("AUTOTEST shop L%d: opened=%s gas %d -> %d closed=%s still_on_level=%s" % [
		g.level.number, opened, before, Progress.total_gas(), not g._busy_modal(), g.route.size() == 2])
	# Retry is free (this node goes with the old level, so the tree quits us).
	var tree := get_tree()
	tree.create_timer(1.2 + _linger() * 0.5).timeout.connect(func():
		print("AUTOTEST shop retry: gas=%d" % Progress.gas)
		tree.quit())
	await _click(g.retry_button)


## Undo past the free ones with no gas: the ad plays, pays bonus tanks, and the undo happens after it.
func _ad_test(sol: Array) -> void:
	var watch := OS.get_cmdline_user_args().has("--watch")
	Progress.gas = 0
	Progress.gas_t = Time.get_unix_time_from_system()
	Progress.reserve_gas = 0
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
	for f in 600:
		if g.state == Game.State.IDLE:
			break
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	print("AUTOTEST ad L%d: free_undo_used=%s ad_opened=%s skipped_early=%s closed=%s bonus_gas=%d undone=%s" % [
		g.level.number, free_used, opened, early, not g._busy_modal(), Progress.reserve_gas, g.route.size() == 1])


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
