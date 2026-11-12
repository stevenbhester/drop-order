extends SceneTree
## Finds good spots for a cosmetic present on each level: plain road tiles the obvious winning route never
## touches, but that can still be picked up on the way to a win. Two kinds:
##   alt   - on a different winning route than the shortest one (a tricky alternate path)
##   extra - beyond the last delivery: keep dragging past the finish in the same segment ("the extra mile")
## Picking up a present needs the van to drive onto it at some point before the level ends.
##   godot --headless --path . --script res://tools/place_gifts.gd -- [levels.json|daily.json] [level numbers...]

const DEPTH := 5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var file := "res://levels/levels.json"
	var want := []
	for a in args:
		if a.ends_with(".json"):
			file = a if a.begins_with("res://") else "res://" + a
		else:
			want.append(a.to_int())
	var data = JSON.parse_string(FileAccess.get_file_as_string(file))
	var list: Array = data["levels"]
	for i in list.size():
		if not want.is_empty() and not want.has(i + 1):
			continue
		var L := LevelData.from_dict(list[i], i + 1)
		_report(L)
	quit()


func _plain(L: LevelData, p: Vector2i) -> bool:
	return L.is_road(p) and p != L.start and not L.oneway.has(p) and not L.bridges.has(p) and not L.gates.has(p) and not L.hubs.has(p)


func _report(L: LevelData) -> void:
	var routes := Solver.solve_all(L, 300)
	if routes.is_empty():
		print("L%d %s: no solution" % [L.number, L.title])
		return
	var main: Array = routes[0]
	var on_main := {}
	for p in main:
		on_main[p] = true
	var found := {}   # tile -> [kind, score]
	# Other winning routes.
	for r in routes.slice(1):
		for p in r:
			if not on_main.has(p) and _plain(L, p):
				found[p] = ["alt", 10]
	# The extra mile: driving on after the last delivery, in the same segment.
	if not L.return_depot:
		for r in routes:
			var st := Sim.run(L, r)
			_extend(L, r.duplicate(), st, 0, on_main, found)
	var keys := found.keys()
	keys.sort_custom(func(a, b): return found[a][1] > found[b][1])
	var desc := []
	for p in keys.slice(0, 6):
		desc.append("(%d,%d) %s%s" % [p.x, p.y, found[p][0], "" if found[p][0] == "alt" else " +%d" % found[p][1]])
	print("L%d %-20s %d route(s) · %s" % [L.number, L.title, routes.size(), ", ".join(desc) if not desc.is_empty() else "nothing off the main route"])


func _extend(L: LevelData, route: Array, st: Dictionary, depth: int, on_main: Dictionary, found: Dictionary) -> void:
	if depth >= DEPTH:
		return
	for d in LevelData.DIRS:
		var n: Vector2i = route.back() + d
		if not Sim.can_extend(L, route, n, st):
			continue
		route.append(n)
		var st2 := Sim.copy_state(st)
		Sim.arrive(L, st2, n)
		if not on_main.has(n) and _plain(L, n) and depth + 1 >= 2:
			var prev = found.get(n, null)
			if prev == null or (prev[0] == "extra" and prev[1] > depth + 1):
				found[n] = ["extra", depth + 1]
		_extend(L, route, st2, depth + 1, on_main, found)
		route.pop_back()
