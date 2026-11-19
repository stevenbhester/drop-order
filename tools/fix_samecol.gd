extends SceneTree
## One-off repair for hand-built side roads and speedrun legs: wherever two houses of one colour share a
## road tile, recolour one of them (and the packages that go to it) to a colour nobody else at that stop
## wants. A fix is kept only if the level is still clean, still solves, and has no more answers than before
## (the same answer first, where one exists).
##   godot --headless --path . --script res://tools/fix_samecol.gd
## Prints one line per fixed part: FIX <file> <id> <part> <json of {map, stack}>, or STUCK when nothing
## simple works (Hostile Takeover was: its purple house sat behind a purple gate, so the house, its pickup
## and the gate all went blue together, by hand). Copy the fixes into the level files yourself.

const LETTER := {"red": "r", "blue": "b", "green": "g", "yellow": "y", "purple": "p", "orange": "o"}


func _init() -> void:
	for d in SideRoads.defs():
		_route("side", d)
	for d in Speedrun.defs():
		_route("speedrun", d)
	quit()


func _route(file: String, d: Dictionary) -> void:
	var parts: Array = d.get("parts", [])
	if parts.is_empty():
		if d.has("map"):
			_fix_part(file, str(d.get("id", "")), -1, d)
		return
	for k in parts.size():
		var pd: Dictionary = (parts[k] as Dictionary).duplicate(true)
		if k < parts.size() - 1:
			var here: Array = parts[k].get("at", [k, 0])
			var there: Array = parts[k + 1].get("at", [k + 1, 0])
			pd["exit_dir"] = [signi(int(there[0]) - int(here[0])), signi(int(there[1]) - int(here[1]))]
		_fix_part(file, str(d.get("id", "")), k, pd)


func _clashes(L: LevelData) -> Array:
	var out := []
	for e in L.errors:
		if "beside two" in str(e):
			out.append(e)
	return out


func _fix_part(file: String, id: String, k: int, pd: Dictionary) -> void:
	var L := LevelData.from_dict(pd, 800)
	if _clashes(L).is_empty():
		return
	var r0 := Solver.solve(L)
	var count0: int = r0["count"]
	var short0: Array = r0["shortest"]
	var cur := pd.duplicate(true)
	for _round in 6:
		var Lc := LevelData.from_dict(cur, 800)
		if _clashes(Lc).is_empty():
			break
		var best = null
		var best_score := 1 << 30
		for rp in Lc.adjacent_houses:
			var by := {}
			for hi in Lc.adjacent_houses[rp]:
				var c: String = Lc.houses[hi].color
				by[c] = by.get(c, []) + [hi]
			for c in by:
				if c == "any" or by[c].size() < 2:
					continue
				for hi in by[c]:
					for nc in LETTER:
						if nc == c:
							continue
						for cand in _recolours(cur, Lc, hi, c, nc):
							var L2 := LevelData.from_dict(cand, 800)
							var bad := 0
							for e in L2.errors:
								if not "beside two" in str(e):
									bad = 1
							if bad:
								continue
							var left := _clashes(L2).size()
							if left >= _clashes(Lc).size():
								continue
							var r2 := Solver.solve(L2)
							if r2["count"] == 0 or r2["count"] > count0:
								continue
							var score: int = left * 100 + (0 if r2["shortest"] == short0 else 10) + int(r2["count"])
							if score < best_score:
								best_score = score
								best = cand
		if best == null:
			print("STUCK %s %s %d: %s" % [file, id, k, _clashes(Lc)])
			return
		cur = best
	var Lf := LevelData.from_dict(cur, 800)
	var rf := Solver.solve(Lf)
	print("FIX\t%s\t%s\t%d\t%s\t(answers %d -> %d, same answer: %s)" % [file, id, k,
		JSON.stringify({"map": cur["map"], "stack": cur.get("stack", [])}), count0, rf["count"], rf["shortest"] == short0])


## Every way to turn house `hi` (colour c) into colour nc, taking its packages from the starting load.
func _recolours(d: Dictionary, L: LevelData, hi: int, c: String, nc: String) -> Array:
	var out := []
	var h = L.houses[hi]
	var pos: Vector2i = h.pos
	var rows: Array = d["map"]
	var toks := str(rows[pos.y]).split(" ", false)
	var t := str(toks[pos.x])
	if t.substr(0, 1) != LETTER[c]:
		return out
	toks[pos.x] = LETTER[nc] + t.substr(1)
	var new_rows := rows.duplicate()
	new_rows[pos.y] = " ".join(toks)
	var n0: int = h.order
	# Or a pickup shop of that colour holding exactly this house's order turns colour with it.
	for s in L.shops:
		if s.color != c or s.count != n0:
			continue
		var srows := new_rows.duplicate()
		var st := str(srows[s.pos.y]).split(" ", false)
		st[s.pos.x] = LETTER[nc].to_upper() + str(st[s.pos.x]).substr(1)
		srows[s.pos.y] = " ".join(st)
		var sd := d.duplicate(true)
		sd["map"] = srows
		out.append(sd)
	var stack: Array = d.get("stack", [])
	var idx := []
	for i in stack.size():
		if str(stack[i]) == c:
			idx.append(i)
	var n: int = h.order
	if idx.size() < n:
		return out
	for combo in _combos(idx, n):
		var s2 := stack.duplicate()
		for i in combo:
			s2[i] = nc
		var nd := d.duplicate(true)
		nd["map"] = new_rows
		nd["stack"] = s2
		out.append(nd)
	return out


func _combos(a: Array, n: int) -> Array:
	if n == 0:
		return [[]]
	if a.size() < n:
		return []
	var out := []
	for i in a.size():
		for rest in _combos(a.slice(i + 1), n - 1):
			out.append([a[i]] + rest)
	return out
