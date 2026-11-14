extends SceneTree
## Headless check: every level (and every daily puzzle and side road) parses and is solvable, and every present on the road
## can be picked up on the way to a win. Prints solution counts.
##   godot --headless --path . --script res://tools/validate_levels.gd
## Add `-- --ablate` to also re-solve each level with its one-way arrows / bridges / gates /
## hubs turned into plain road, to confirm those mechanics actually matter there.
## Keys: every locked side road must have had enough keys placed on the levels up to its stop (counting the
## keys every earlier locked side road needs), so a key is always waiting before a lock shows up.
## Exits with code 1 if any level is broken or unsolvable.

func _init() -> void:
	var ablate := OS.get_cmdline_user_args().has("--ablate")
	var ok := true
	var levels := Levels.load_all() + Daily.puzzles() + SideRoads.all_levels() + Speedrun.all_levels()
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
		elif L.number >= SideRoads.NUMBER_BASE + 20: feats.append("MEGA ROUTE, exit %s" % ("none (last part)" if not L.has_exit() else str(L.exit_dir())))
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
				# Hints follow the plain (shortest) route, so a present on it would be handed out by the hints.
				if r["count"] > 0 and (r["shortest"] as Array).has(L.gift):
					bad = true
					ok = false
					L.errors.append("the present (%s) is on the plain winning route (the hints would walk you to it)" % L.gift_item)
		var tag := "D%02d" % (L.number - Daily.NUMBER_BASE) if L.number > Daily.NUMBER_BASE else "L%02d" % L.number
		if L.number >= Speedrun.NUMBER_BASE and L.number < Daily.NUMBER_BASE:
			tag = "R%02d" % (L.number - Speedrun.NUMBER_BASE)
			feats.append("SPEEDRUN")
		elif L.number >= SideRoads.NUMBER_BASE + 20 and L.number < Daily.NUMBER_BASE:
			tag = "M%02d" % (L.number - SideRoads.NUMBER_BASE - 20)
		elif L.number >= SideRoads.NUMBER_BASE and L.number < Daily.NUMBER_BASE:
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
	# Keys before locks: by each locked side road's stop, at least as many keys placed as locks so far.
	var key_levels := []
	for L in Levels.load_all():
		if L.gift_item == "key":
			key_levels.append(L.number)
	var locks := SideRoads.defs().filter(func(d): return bool(d.get("locked", false)))
	locks.sort_custom(func(a, b): return int(a.get("after", 0)) < int(b.get("after", 0)))
	for k in locks.size():
		var at := int(locks[k].get("after", 0))
		var keys := key_levels.filter(func(n): return n <= at).size()
		var line := "lock %s (after %d): %d key(s) placed by then, %d lock(s) by then" % [locks[k].get("id", ""), at, keys, k + 1]
		if keys < k + 1:
			ok = false
			line += "  ! NOT ENOUGH KEYS"
		print(line)
	print("%d levels (with dailies, side roads and speedruns), %s" % [levels.size(), "all solvable" if ok else "PROBLEMS FOUND"])
	quit(0 if ok else 1)
