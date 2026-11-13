extends SceneTree
## Design aid for mega routes: turns generated levels into parts that end at an exit on a given edge.
## Reads the generator's output (JSON lines), tries every road tile on that edge as the exit (E), solves,
## and prints the parts that are still winnable (with few solutions), best first: prefers a start (S) near
## the edge the van comes in from, so the pan from the last part feels continuous.
##   godot --headless --path . --script res://tools/make_mega.gd -- --in=/path/gen.txt --exit=right --entry=left
## --exit: right/left/up/down ("none" for a final part); --entry: the edge the van comes in from (or none).

const SIDES := {"right": Vector2i(1, 0), "left": Vector2i(-1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}


func _init() -> void:
	var o := {"in": "", "exit": "right", "entry": "none", "top": "3", "maxsol": "4"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			o[kv[0]] = kv[1]
	var found := []
	for line in FileAccess.get_file_as_string(o["in"]).split("\n"):
		if not line.begins_with("{"):
			continue
		var d = JSON.parse_string(line)
		if not d is Dictionary:
			continue
		for cand in _with_exits(d, o["exit"]):
			var L := LevelData.from_dict(cand, 1)
			if not L.errors.is_empty():
				continue
			var r := Solver.solve(L)
			if r["count"] < 1 or r["count"] > int(o["maxsol"]):
				continue
			var score: float = r["nodes"] * 0.02 + r["shortest"].size() * 0.3 - r["count"] * 2.0
			if o["entry"] != "none":
				score -= _edge_dist(L, L.start, SIDES[o["entry"]]) * 3.0
			found.append({"d": cand, "score": score, "r": r})
	found.sort_custom(func(a, b): return a.score > b.score)
	for f in found.slice(0, int(o["top"])):
		print("# score %.1f · %d solution(s) · shortest %d · %d nodes" % [f.score, f.r["count"], f.r["shortest"].size(), f.r["nodes"]])
		for row in f.d["map"]:
			print("#   ", row)
		print(JSON.stringify(f.d))
	print("# %d parts found" % found.size())
	quit()


## Copies of the level with E on each plain road tile along that edge (or just the level for "none").
func _with_exits(d: Dictionary, side: String) -> Array:
	if side == "none":
		return [d]
	var rows: Array = []
	for row in d["map"]:
		rows.append(str(row).split(" ", false))
	var h := rows.size()
	var w: int = rows[0].size()
	var out := []
	for y in h:
		for x in w:
			var on_edge := (side == "right" and x == w - 1) or (side == "left" and x == 0) or (side == "up" and y == 0) or (side == "down" and y == h - 1)
			if on_edge and rows[y][x] == "#":
				var copy: Dictionary = d.duplicate(true)
				var m := []
				for yy in h:
					var toks: Array = Array(rows[yy]).duplicate()
					if yy == y:
						toks[x] = "E"
					m.append(" ".join(toks))
				copy["map"] = m
				out.append(copy)
	return out


func _edge_dist(L: LevelData, p: Vector2i, side: Vector2i) -> int:
	match side:
		Vector2i(1, 0): return L.width - 1 - p.x
		Vector2i(-1, 0): return p.x
		Vector2i(0, -1): return p.y
	return L.height - 1 - p.y
