extends SceneTree
## Searches small arrow edits to a level (flip, remove, or add one-way arrows) that leave exactly one solution,
## so a level broken by a rule change can be repaired without redesigning the map.
##   godot --headless --path . --script res://tools/arrow_edits.gd -- <level number> [--pairs] [--top=6]
##   ... -- path/to/drafts.json <index> [--pairs]     (a JSON array of draft levels; index is 1-based)
## Prints the best candidates: the edits, the solution count with and without arrows, search size, how many arrow
## tiles the solution drives over (and turns onto), and the map with the solution drawn as step numbers.

const DIRS := {"^": Vector2i(0, -1), ">": Vector2i(1, 0), "v": Vector2i(0, 1), "<": Vector2i(-1, 0)}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var file := "res://levels/levels.json"
	var nums := []
	for a in args:
		if a.ends_with(".json"):
			file = a
		elif not a.begins_with("--"):
			nums.append(a.to_int())
	var n: int = nums[0]
	var pairs := args.has("--pairs")
	var top := 6
	for a in args:
		if a.begins_with("--top="):
			top = a.trim_prefix("--top=").to_int()
	var data = JSON.parse_string(FileAccess.get_file_as_string(file))
	var list: Array = data["levels"] if data is Dictionary else data
	var base: Dictionary = list[n - 1]
	var grid := []
	for row in base["map"]:
		grid.append(Array(row.split(" ", false)))
	var spots := []
	for y in grid.size():
		for x in grid[y].size():
			var t: String = grid[y][x]
			if t == "#" or DIRS.has(t):
				spots.append(Vector2i(x, y))
	var singles := []
	for p in spots:
		var t: String = grid[p.y][p.x]
		for c in ["#", "^", ">", "v", "<"]:
			if c != t:
				singles.append([p, c])
	var trials := []
	for e in singles:
		trials.append([e])
	if pairs:
		for i in singles.size():
			for j in range(i + 1, singles.size()):
				if singles[i][0] != singles[j][0]:
					trials.append([singles[i], singles[j]])
	print("L%d %s: %d trials" % [n, base["title"], trials.size()])
	var found := []
	for edits in trials:
		var g := grid.duplicate(true)
		for e in edits:
			g[e[0].y][e[0].x] = e[1]
		var d := base.duplicate(true)
		d["map"] = _rows(g)
		var L := LevelData.from_dict(d, n)
		if not L.errors.is_empty():
			continue
		# Every arrow must point at road you could drive on to.
		var sensible := true
		for p in L.oneway:
			if not L.is_road(p + L.oneway[p]):
				sensible = false
		if not sensible:
			continue
		var r := Solver.solve(L, 2, 400000)
		if r.count != 1:
			continue
		var plain := d.duplicate(true)
		var g2 := g.duplicate(true)
		for y in g2.size():
			for x in g2[y].size():
				if DIRS.has(g2[y][x]):
					g2[y][x] = "#"
		plain["map"] = _rows(g2)
		var r0 := Solver.solve(LevelData.from_dict(plain, n), 50, 400000)
		if r0.count <= 1:
			continue
		var over := 0
		var turned := 0
		var route: Array = r.shortest
		for i in range(1, route.size()):
			if L.oneway.has(route[i]):
				over += 1
				if route[i] - route[i - 1] != L.oneway[route[i]]:
					turned += 1
		var arrows_kept := 0
		for p in spots:
			if DIRS.has(grid[p.y][p.x]) and g[p.y][p.x] == grid[p.y][p.x]:
				arrows_kept += 1
		found.append({"edits": edits, "nodes": r.nodes, "free": r0.count, "over": over, "turned": turned,
			"len": route.size() - 1, "kept": arrows_kept, "arrows": L.oneway.size(), "map": d["map"], "route": route})
	# Fewest edits, then solutions that use an arrow, then the bigger search.
	found.sort_custom(func(a, b): return [a.edits.size(), -mini(a.over, 1), -a.nodes] < [b.edits.size(), -mini(b.over, 1), -b.nodes])
	print("%d candidates with exactly one solution" % found.size())
	for f in found.slice(0, top):
		var desc := []
		for e in f.edits:
			desc.append("(%d,%d)%s->%s" % [e[0].x, e[0].y, grid[e[0].y][e[0].x], e[1]])
		print("\n  edits %s  | arrows %d (kept %d) | %d nodes | %d tiles | over arrows %d (turned onto %d) | without arrows %d" % [
			", ".join(desc), f.arrows, f.kept, f.nodes, f.len, f.over, f.turned, f.free])
		var step := {}
		for i in f.route.size():
			step[f.route[i]] = i
		for y in f.map.size():
			var toks: PackedStringArray = f.map[y].split(" ", false)
			var line := "    "
			for x in toks.size():
				var p := Vector2i(x, y)
				var t: String = toks[x]
				line += ("%s%d" % [t if DIRS.has(t) else "", step[p]] if step.has(p) else t).rpad(5)
			print(line)
	quit()


func _rows(g: Array) -> Array:
	var out := []
	for row in g:
		out.append(" ".join(PackedStringArray(row)))
	return out
