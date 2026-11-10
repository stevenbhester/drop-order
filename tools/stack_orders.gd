extends SceneTree
## Level-design helper: for one level's map, tries every distinct ordering of its
## stack and prints how many solutions each has (fewer = harder).
##   godot --headless --path . --script res://tools/stack_orders.gd -- 5

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 1
	var L: LevelData = Levels.load_all()[n - 1]
	var seen := {}
	for perm in _perms(L.stack):
		var key := ",".join(perm)
		if seen.has(key):
			continue
		seen[key] = true
		L.stack = perm
		var r := Solver.solve(L)
		print("%-40s %s" % [key, Solver.describe(L, r)])
	quit()

func _perms(a: Array) -> Array:
	if a.size() <= 1:
		return [a.duplicate()]
	var out := []
	for i in a.size():
		var rest := a.duplicate()
		var x = rest.pop_at(i)
		for p in _perms(rest):
			out.append(p + [x])
	return out
