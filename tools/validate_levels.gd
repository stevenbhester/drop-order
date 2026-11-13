extends SceneTree
## Headless check: every level (and every daily puzzle and side road) parses and is solvable, and every present on the road
## can be picked up on the way to a win. Prints solution counts.
##   godot --headless --path . --script res://tools/validate_levels.gd
## Add `-- --ablate` to also re-solve each level with its one-way arrows / bridges / gates /
## hubs turned into plain road, to confirm those mechanics actually matter there.
## Exits with code 1 if any level is broken or unsolvable.

func _init() -> void:
	var ablate := OS.get_cmdline_user_args().has("--ablate")
	var ok := true
	var levels := Levels.load_all() + Daily.puzzles() + SideRoads.all_levels()
	for L in levels:
		var r := Solver.solve(L)
		if r["count"] > 0:
			var most := Sim.max_load(L, r["shortest"])
			if most > LevelData.MAX_LOAD:
				L.errors.append("the winning route carries %d packages at once; the most is %d" % [most, LevelData.MAX_LOAD])
		var bad: bool = not L.errors.is_empty() or r["count"] == 0
		ok = ok and not bad
		var feats := []
		if L.no_revisit: feats.append("no-revisit")
		if L.houses.any(func(h): return h.order > 1): feats.append("multi")
		if not L.oneway.is_empty(): feats.append("%d one-way" % L.oneway.size())
		if not L.bridges.is_empty(): feats.append("%d bridge" % L.bridges.size())
		if not L.shops.is_empty(): feats.append("%d shop" % L.shops.size())
		if L.shops.any(func(s): return s.count > 1): feats.append("%d pkg total" % L.total_orders())
		if not L.gates.is_empty(): feats.append("%d gate" % L.gates.size())
		if not L.hubs.is_empty(): feats.append("%d hub" % L.hubs.size())
		if L.return_depot: feats.append("return")
		if L.preview: feats.append("PREVIEW")
		if L.number > Daily.NUMBER_BASE: feats.append("DAILY")
		elif L.number >= SideRoads.NUMBER_BASE: feats.append("SIDE ROAD")
		if L.gift_item != "":
			var gr := Solver.gift_route(L)
			if gr.is_empty():
				bad = true
				ok = false
				L.errors.append("the present (%s) can't be picked up on the way to a win" % L.gift_item)
			else:
				var kind := "on the route" if Sim.is_won(L, Sim.run(L, gr), gr) and gr.back() != L.gift else "extra mile"
				feats.append("gift %s, %s" % [L.gift_item, kind])
		var tag := "D%02d" % (L.number - Daily.NUMBER_BASE) if L.number > Daily.NUMBER_BASE else "L%02d" % L.number
		if L.number >= SideRoads.NUMBER_BASE and L.number < Daily.NUMBER_BASE:
			tag = "S%02d" % (L.number - SideRoads.NUMBER_BASE + 1)
		print("%s %s %-18s %dx%d %d pkg  %s  [%s]" % ["FAIL" if bad else " ok ", tag, L.title,
			L.width, L.height, L.stack.size(), Solver.describe(L, r), ", ".join(feats)])
		for e in L.errors:
			print("       ! ", e)
		if ablate:
			for field in ["oneway", "bridges", "gates", "hubs"]:
				var saved: Dictionary = L.get(field)
				if saved.is_empty():
					continue
				L.set(field, {})
				print("       without %s: %s" % [field, Solver.describe(L, Solver.solve(L))])
				L.set(field, saved)
	print("%d levels (with dailies and side roads), %s" % [levels.size(), "all solvable" if ok else "PROBLEMS FOUND"])
	quit(0 if ok else 1)
