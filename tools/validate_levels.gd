extends SceneTree
## Headless check: every level parses and is solvable. Prints solution counts.
##   godot --headless --path . --script res://tools/validate_levels.gd
## Add `-- --ablate` to also re-solve each level with its one-way arrows / bridges / gates /
## hubs turned into plain road, to confirm those mechanics actually matter there.
## Exits with code 1 if any level is broken or unsolvable.

func _init() -> void:
	var ablate := OS.get_cmdline_user_args().has("--ablate")
	var ok := true
	var levels := Levels.load_all()
	for L in levels:
		var r := Solver.solve(L)
		var bad: bool = not L.errors.is_empty() or r["count"] == 0
		ok = ok and not bad
		var feats := []
		if L.no_revisit: feats.append("no-revisit")
		if L.houses.any(func(h): return h.order > 1): feats.append("multi")
		if not L.oneway.is_empty(): feats.append("%d one-way" % L.oneway.size())
		if not L.bridges.is_empty(): feats.append("%d bridge" % L.bridges.size())
		if not L.shops.is_empty(): feats.append("%d shop" % L.shops.size())
		if not L.gates.is_empty(): feats.append("%d gate" % L.gates.size())
		if not L.hubs.is_empty(): feats.append("%d hub" % L.hubs.size())
		if L.return_depot: feats.append("return")
		print("%s L%02d %-18s %dx%d %d pkg  %s  [%s]" % ["FAIL" if bad else " ok ", L.number, L.title,
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
	print("%d levels, %s" % [levels.size(), "all solvable" if ok else "PROBLEMS FOUND"])
	quit(0 if ok else 1)
