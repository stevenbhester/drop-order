extends SceneTree
## Level-design helper: solve candidate levels from a JSON file (an array of level objects,
## same format as levels.json entries) and show the shortest solution drawn on the map.
##   godot --headless --path . --script res://tools/check_level.gd -- path/to/draft.json

func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for i in list.size():
		var L := LevelData.from_dict(list[i], i + 1)
		print("== %s" % list[i].get("title", "#%d" % (i + 1)))
		for e in L.errors:
			print("   ! ", e)
		if not L.errors.is_empty():
			continue
		var r := Solver.solve(L)
		print("   ", Solver.describe(L, r))
		if r["count"] > 0:
			_draw_route(L, r["shortest"])
		for field in ["oneway", "bridges", "gates", "hubs"]:
			var saved: Dictionary = L.get(field)
			if saved.is_empty():
				continue
			L.set(field, {})
			print("   without %s: %s" % [field, Solver.describe(L, Solver.solve(L))])
			L.set(field, saved)
	quit()


## Map rows with the route's step numbers (mod 100) in place of road tiles.
func _draw_route(L: LevelData, route: Array) -> void:
	var step := {}
	for k in route.size():
		step[route[k]] = ("%d" % k) if not step.has(route[k]) else step[route[k]] + "/" + str(k)
	var rows: Array = []
	for y in L.height:
		var out := ""
		for x in L.width:
			var p := Vector2i(x, y)
			var tok := "."
			if step.has(p):
				tok = step[p]
			elif L.is_road(p):
				tok = "#"
			else:
				for h in L.houses:
					if h.pos == p:
						tok = h.color.substr(0, 1) + (str(h.order) if h.order > 1 else "")
				for s in L.shops:
					if s.pos == p:
						tok = s.color.substr(0, 1).to_upper()
			out += "%-4s" % tok
		rows.append(out)
	for row in rows:
		print("     ", row)
