extends SceneTree
## Design aid for the level redesign: how hard, and how honest, each level is.
##   godot --headless --path . --script res://tools/level_report.gd -- [--from=41] [--to=100]
## Per level: solutions, search nodes (how hard the solver had to look), the shortest route's length, how much
## of the map's road it uses (coverage), a difficulty score (twist_levels.gd's scale: log2(nodes) +
## 0.06 x route + 0.5 x mechanics), and which mechanics do nothing: each family (ice, one-ways, roadworks)
## is turned to plain road and re-solved, and if no new way to win opens up, it's decoration. Ice is also
## checked tile by tile. Flags:
##   EASY      score under 9, or 6+ solutions, or under 400 search nodes
##   LOW-COVER the winning route uses under half the road
##   DECOR     a mechanic family that changes nothing
## and at the end, every run of two or more EASY levels in a row.

const EASY_SCORE := 9.0


func _init() -> void:
	var from := 41
	var to := 100
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = a.trim_prefix("--from=").to_int()
		elif a.begins_with("--to="):
			to = a.trim_prefix("--to=").to_int()
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))["levels"]
	var easy_run := []
	var runs := []
	var decor_total := 0
	var easy_total := 0
	for n in range(from, mini(to, raw.size()) + 1):
		var d: Dictionary = raw[n - 1]
		var L := LevelData.from_dict(d, n)
		var r := Solver.solve(L)
		var sol: Array = r["shortest"]
		var used := {}
		for p in sol:
			used[p] = true
		var cover := float(used.size()) / maxf(L.road_count(), 1.0)
		var mechs := _mechanics(L)
		var score := log(maxf(r["nodes"], 1.0)) / log(2.0) + 0.06 * sol.size() + 0.5 * mechs.size()
		var flags := []
		var easy: bool = score < EASY_SCORE or r["count"] >= 6 or r["nodes"] < 400
		if easy:
			flags.append("EASY")
			easy_total += 1
		if cover < 0.5:
			flags.append("LOW-COVER")
		var decor := []
		for fam in [["ice", ["~"]], ["one-way", [">", "<", "^", "v"]], ["roadworks", ["c"]]]:
			if not _has(d, fam[1]):
				continue
			var plain := _strip(d, fam[1])
			var c := _count(plain, n)
			if c >= 0 and c <= r["count"]:
				decor.append(fam[0])
		if not decor.is_empty():
			flags.append("DECOR(%s)" % ", ".join(decor))
			decor_total += 1
		# Ice tile by tile: one that changes nothing on its own.
		var idle_ice := 0
		for p in L.ice:
			var c := _count(_set_tile(d, p, "#"), n)
			if c >= 0 and c <= r["count"]:
				idle_ice += 1
		if idle_ice > 0:
			flags.append("%d/%d ice idle" % [idle_ice, L.ice.size()])
		print("L%-3d %-22s %3d sol %8d nodes  len %2d  cover %3d%%  score %5.1f  %-34s %s" % [n, L.title.substr(0, 22), r["count"],
			r["nodes"], sol.size(), int(cover * 100.0), score, ", ".join(mechs), " ".join(flags)])
		if easy:
			easy_run.append(n)
		else:
			if easy_run.size() >= 2:
				runs.append(easy_run.duplicate())
			easy_run.clear()
	if easy_run.size() >= 2:
		runs.append(easy_run.duplicate())
	print("\n%d EASY, %d with a decorative mechanic, between levels %d and %d" % [easy_total, decor_total, from, to])
	for run in runs:
		print("easy streak: levels %s" % ", ".join(run.map(func(x): return str(x))))
	quit()


static func _mechanics(L: LevelData) -> Array:
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


func _has(d: Dictionary, toks: Array) -> bool:
	for row in d["map"]:
		for tk in str(row).split(" ", false):
			if tk in toks or (toks.has("c") and tk.begins_with("c") and tk.length() > 1 and tk.substr(1).is_valid_int()):
				return true
	return false


## The level with every token in `toks` (roadworks: any cN) turned to plain road.
func _strip(d: Dictionary, toks: Array) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var m := []
	for row in d["map"]:
		var out := []
		for tk in str(row).split(" ", false):
			var hit: bool = tk in toks or (toks.has("c") and tk.begins_with("c") and tk.length() > 1 and tk.substr(1).is_valid_int())
			out.append("#" if hit else tk)
		m.append(" ".join(out))
	c["map"] = m
	return c


func _set_tile(d: Dictionary, p: Vector2i, tok: String) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var rows := []
	for row in d["map"]:
		rows.append(Array(str(row).split(" ", false)))
	rows[p.y][p.x] = tok
	var m := []
	for r in rows:
		m.append(" ".join(r))
	c["map"] = m
	return c


func _count(d: Dictionary, n: int) -> int:
	var L := LevelData.from_dict(d, n)
	if not L.errors.is_empty():
		return -1
	var r := Solver.solve(L)
	if r["capped"]:
		return -1
	return r["count"]
