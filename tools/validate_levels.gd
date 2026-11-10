extends SceneTree
## Headless check: every level parses and is solvable. Prints solution counts.
##   godot --headless --path . --script res://tools/validate_levels.gd
## Exits with code 1 if any level is broken or unsolvable.

func _init() -> void:
	var ok := true
	var levels := Levels.load_all()
	for L in levels:
		var r := Solver.solve(L)
		var bad: bool = not L.errors.is_empty() or r["count"] == 0
		ok = ok and not bad
		print("%s L%02d %-18s %s" % ["FAIL" if bad else " ok ", L.number, L.title, Solver.describe(L, r)])
		for e in L.errors:
			print("       ! ", e)
		if r["count"] > 0:
			print("       shortest: ", r["shortest"])
	print("%d levels, %s" % [levels.size(), "all solvable" if ok else "PROBLEMS FOUND"])
	quit(0 if ok else 1)
