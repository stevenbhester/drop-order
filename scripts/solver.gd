class_name Solver
extends RefCounted
## DFS over every path the player could draw, using the real rules in Sim.
## A "solution" is a path whose final tile is where the last package gets delivered
## (extending a winning path further is not counted as a new solution).
## On levels that allow revisits the path space is infinite, so each tile may be
## used at most REVISIT_CAP times there; the count is a difficulty signal, not gospel.

const REVISIT_CAP := 2

var L: LevelData
var count := 0
var shortest: Array = []
var limit := 20000
var max_len := 0
var capped := false
var _visits := {}


static func solve(level: LevelData, max_solutions := 20000) -> Dictionary:
	var s := Solver.new()
	s.L = level
	s.limit = max_solutions
	s.max_len = level.road_count() * (1 if level.no_revisit else REVISIT_CAP) + 1
	var t0 := Time.get_ticks_usec()
	s._visits = {level.start: 1}
	s._dfs([level.start], Sim.new_state(level))
	return {
		"count": s.count,
		"shortest": s.shortest,
		"capped": s.capped,
		"ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}


func _dfs(path: Array, state: Dictionary) -> void:
	if count >= limit:
		capped = true
		return
	var last: Vector2i = path.back()
	for d in LevelData.DIRS:
		var nxt: Vector2i = last + d
		if not Sim.can_extend(L, path, nxt):
			continue
		var v: int = _visits.get(nxt, 0)
		if v >= REVISIT_CAP:
			continue
		var st := Sim.copy_state(state)
		Sim.arrive(L, st, nxt)
		path.append(nxt)
		_visits[nxt] = v + 1
		if st["left"] == 0:
			count += 1
			if shortest.is_empty() or path.size() < shortest.size():
				shortest = path.duplicate()
		elif path.size() < max_len:
			_dfs(path, st)
		path.pop_back()
		_visits[nxt] = v


static func describe(L: LevelData, r: Dictionary) -> String:
	var n: int = r["count"]
	var s := "%d%s solution%s" % [n, "+" if r["capped"] else "", "" if n == 1 else "s"]
	if n > 0:
		s += " · shortest %d tiles" % (r["shortest"].size() - 1)
	s += " · %.0f ms" % r["ms"]
	if not L.no_revisit:
		s += " · revisits on (≤%d/tile)" % REVISIT_CAP
	return s
