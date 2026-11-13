extends SceneTree
## Design aid for the newer mechanics: adds ice (~), parcel lockers (w) and roadworks (cN) to generated
## levels, keeping them winnable. Reads the generator's output (JSON lines), finds a winning route, then
## greedily tries each twist where that route still works (ice on tiles it drives straight across; a locker
## in place of a house; roadworks on a tile it reaches after enough deliveries), keeping a change when the
## level stays solvable with no more solutions than before (fewer is better: the twist matters). Prints the
## results rated by difficulty, hardest first, as JSON lines.
##   godot --headless --path . --script res://tools/twist_levels.gd -- --in=gen.txt --ice=2 --lockers=1 --works=1
## Also: --maxsol=3 (most solutions kept), --top=10. With --rate, just rates the levels in levels.json.
##
## Difficulty score: log2(search nodes) + 0.06 x shortest route + 0.5 x mechanics used (the same scale the
## level order is planned on).

func _init() -> void:
	var o := {"in": "", "ice": "0", "lockers": "0", "works": "0", "maxsol": "3", "top": "10", "rate": ""}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			o[kv[0]] = kv[1]
		elif a == "--rate":
			o["rate"] = "1"
	if o["rate"] != "":
		_rate_all()
		quit()
		return
	var out := []
	for line in FileAccess.get_file_as_string(o["in"]).split("\n"):
		if not line.begins_with("{"):
			continue
		var d = JSON.parse_string(line)
		if not d is Dictionary:
			continue
		var res := _twist(d, int(o["ice"]), int(o["lockers"]), int(o["works"]), int(o["maxsol"]))
		if not res.is_empty():
			out.append(res)
	out.sort_custom(func(a, b): return a.score > b.score)
	for r in out.slice(0, int(o["top"])):
		print("# diff %.1f · %d solution(s) · shortest %d · %d nodes · %s" % [r.score, r.count, r.len, r.nodes, r.mechs])
		for row in r.d["map"]:
			print("#   ", row)
		print("#   stack ", r.d["stack"])
		print(JSON.stringify(r.d))
	print("# %d twisted levels" % out.size())
	quit()


static func mechanics(L: LevelData) -> Array:
	var m := []
	if not L.oneway.is_empty(): m.append("one-way")
	if not L.bridges.is_empty(): m.append("bridge")
	if not L.gates.is_empty(): m.append("gate")
	if not L.hubs.is_empty(): m.append("hub")
	if not L.shops.is_empty(): m.append("warehouse" if L.shops.any(func(s): return s.count > 1) else "pickup")
	if L.return_depot: m.append("return")
	if L.houses.any(func(h): return h.order > 1 and h.color != "any"): m.append("multi")
	if not L.ice.is_empty(): m.append("ice")
	if L.houses.any(func(h): return h.color == "any"): m.append("locker")
	if not L.works.is_empty(): m.append("works")
	return m


static func score(L: LevelData, r: Dictionary) -> float:
	return log(maxf(r["nodes"], 1.0)) / log(2.0) + 0.06 * r["shortest"].size() + 0.5 * mechanics(L).size()


func _rate_all() -> void:
	var all := Levels.load_all()
	for L in all:
		var r := Solver.solve(L)
		print("L%02d %-20s diff %.1f · %d sol · len %d · %d nodes · %s" % [L.number, L.title, score(L, r), r["count"], r["shortest"].size(), r["nodes"], mechanics(L)])


func _tokens(d: Dictionary) -> Array:
	var rows := []
	for row in d["map"]:
		rows.append(Array(str(row).split(" ", false)))
	return rows


func _with(d: Dictionary, rows: Array) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var m := []
	for r in rows:
		m.append(" ".join(r))
	c["map"] = m
	return c


func _solve(d: Dictionary) -> Dictionary:
	var L := LevelData.from_dict(d, 1)
	if not L.errors.is_empty():
		return {}
	var r := Solver.solve(L)
	if r["count"] < 1 or r["capped"]:
		return {}
	return {"L": L, "r": r}


func _twist(d: Dictionary, ice: int, lockers: int, works: int, maxsol: int) -> Dictionary:
	var cur := _solve(d)
	if cur.is_empty():
		return {}
	var sol: Array = cur["r"]["shortest"]
	var count: int = cur["r"]["count"]
	var rows := _tokens(d)
	var dd := d
	var added := {"ice": 0, "lockers": 0, "works": 0}
	# Ice where the route drives straight across plain road.
	var spots := []
	for i in range(1, sol.size() - 1):
		var p: Vector2i = sol[i]
		if sol[i] - sol[i - 1] == sol[i + 1] - sol[i] and rows[p.y][p.x] == "#":
			spots.append(p)
	spots.shuffle()
	for p in spots:
		if added["ice"] >= ice:
			break
		rows[p.y][p.x] = "~"
		var t := _solve(_with(dd, rows))
		if t.is_empty() or t["r"]["count"] > count:
			rows[p.y][p.x] = "#"
			continue
		dd = _with(dd, rows)
		count = t["r"]["count"]
		added["ice"] += 1
	# Lockers in place of single-package houses, if the route still delivers right.
	var hs := []
	for y in rows.size():
		for x in rows[y].size():
			if rows[y][x] in ["r", "b", "g", "y", "p", "o"]:
				hs.append(Vector2i(x, y))
	hs.shuffle()
	for p in hs:
		if added["lockers"] >= lockers:
			break
		var was: String = rows[p.y][p.x]
		rows[p.y][p.x] = "w"
		var nd := _with(dd, rows)
		var L := LevelData.from_dict(nd, 1)
		if not L.errors.is_empty() or not Sim.is_won(L, Sim.run(L, sol), sol):
			rows[p.y][p.x] = was
			continue
		var t := _solve(nd)
		if t.is_empty() or t["r"]["count"] > maxi(count, maxsol):
			rows[p.y][p.x] = was
			continue
		dd = nd
		count = t["r"]["count"]
		added["lockers"] += 1
	# Roadworks on route tiles reached after some deliveries (opening exactly when the route needs them).
	var L0 := LevelData.from_dict(dd, 1)
	var st := Sim.new_state(L0)
	var after := {}
	for i in range(1, sol.size()):
		var p: Vector2i = sol[i]
		var done := Sim.delivered_count(st)
		if done >= 1 and rows[p.y][p.x] == "#" and p != L0.start:
			after[p] = done
		Sim.arrive(L0, st, p)
	var wk := after.keys()
	wk.shuffle()
	for p in wk:
		if added["works"] >= works:
			break
		var n: int = after[p]
		rows[p.y][p.x] = "c%d" % n
		var t := _solve(_with(dd, rows))
		if t.is_empty() or t["r"]["count"] > count:
			rows[p.y][p.x] = "#"
			continue
		dd = _with(dd, rows)
		count = t["r"]["count"]
		added["works"] += 1
	if added["ice"] < ice or added["lockers"] < lockers or added["works"] < works:
		return {}
	var fin := _solve(dd)
	if fin.is_empty() or fin["r"]["count"] > maxsol:
		return {}
	var L2: LevelData = fin["L"]
	return {"d": dd, "score": score(L2, fin["r"]), "count": fin["r"]["count"], "len": fin["r"]["shortest"].size(),
		"nodes": fin["r"]["nodes"], "mechs": mechanics(L2)}
