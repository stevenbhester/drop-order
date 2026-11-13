extends SceneTree
## Ice only matters where you could otherwise turn: a junction. On a straight stretch (or a corner, or a
## dead end) it changes nothing. This finds ice like that, turns it back into road, and puts the same amount
## of ice on junctions instead, where it actually takes turns away: of the junctions that keep the level
## winnable, the one leaving the fewest solutions (ties: one the shortest route drives straight across).
## If no junction works, that ice just goes. Prints a JSON line per level it changes ({i, old, new, note}:
## the level's index and its map rows before and after), to write back into the file.
##   godot --headless --path . --script res://tools/fix_ice.gd -- --file=res://levels/levels.json

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init() -> void:
	var path := "res://levels/levels.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			path = a.trim_prefix("--file=")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var levels: Array = data["levels"]
	for i in levels.size():
		var d: Dictionary = levels[i]
		if not str(d["map"]).contains("~"):
			continue
		var res := _fix(d, i + 1)
		if not res.is_empty():
			print(JSON.stringify({"i": i, "old": d["map"], "new": res["map"], "note": res["note"]}))
	quit()


func _rows(m: Array) -> Array:
	var out := []
	for r in m:
		out.append(Array(str(r).split(" ", false)))
	return out


func _map(rows: Array) -> Array:
	var out := []
	for r in rows:
		out.append(" ".join(r))
	return out


func _with(d: Dictionary, rows: Array) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c["map"] = _map(rows)
	return c


## Solutions left, or -1 if it can't be won (or the search ran out).
func _count(d: Dictionary, n: int) -> int:
	var L := LevelData.from_dict(d, n)
	if not L.errors.is_empty():
		return -1
	var r := Solver.solve(L)
	if r["count"] < 1 or r["capped"]:
		return -1
	return r["count"]


func _fix(d: Dictionary, n: int) -> Dictionary:
	var L := LevelData.from_dict(d, n)
	var rows := _rows(d["map"])
	var useless := []
	for p in L.ice:
		var ways := []
		for dv in DIRS:
			if L.is_road(p + dv):
				ways.append(dv)
		if ways.size() < 3:
			useless.append(p)
	if useless.is_empty():
		return {}
	var before := _count(d, n)
	for p in useless:
		rows[p.y][p.x] = "#"
	var cur := _with(d, rows)
	var count := _count(cur, n)
	var sol: Array = Solver.solve(LevelData.from_dict(cur, n))["shortest"]
	var straight := {}
	for k in range(1, sol.size() - 1):
		if sol[k] - sol[k - 1] == sol[k + 1] - sol[k]:
			straight[sol[k]] = true
	var placed := []
	for _k in useless.size():
		var L2 := LevelData.from_dict(cur, n)
		var best := Vector2i(-1, -1)
		var best_count := 1 << 30
		var best_on := false
		for y in rows.size():
			for x in rows[y].size():
				var p := Vector2i(x, y)
				if rows[y][x] != "#" or placed.has(p):
					continue
				var ways := 0
				for dv in DIRS:
					if L2.is_road(p + dv):
						ways += 1
				if ways < 3:
					continue
				rows[y][x] = "~"
				var c := _count(_with(cur, rows), n)
				rows[y][x] = "#"
				if c < 0:
					continue
				var on := straight.has(p)
				if c < best_count or (c == best_count and on and not best_on):
					best = p
					best_count = c
					best_on = on
		if best.x < 0:
			break
		rows[best.y][best.x] = "~"
		placed.append(best)
		cur = _with(cur, rows)
		count = best_count
	var note := "L%d: %d useless ice off %s; on %s; solutions %d -> %d" % [n, useless.size(), str(useless), str(placed), before, count]
	return {"map": _map(rows), "note": note}
