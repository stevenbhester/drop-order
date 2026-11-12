class_name Solver
extends RefCounted
## DFS over every route the player could build, using the real rules in Sim.
## A "solution" is a route that ends the moment the level is won (driving further after
## winning is not counted as a new solution). Segments don't matter here: any route can be
## split into segments wherever the player likes.
##
## On levels that allow revisits the route space is infinite, so each tile may be used at
## most REVISIT_CAP times there; the count is a difficulty signal, not gospel.
## No-revisit levels prune branches where something still needed can no longer be reached.
##
## `nodes` (partial routes explored) is a rough measure of how many tempting wrong
## routes a level has: the generator uses it to prefer deceptive levels.

const REVISIT_CAP := 2

var L: LevelData
var count := 0
var shortest: Array = []
var limit := 20000
var max_len := 0
var capped := false
var nodes := 0
var node_limit := 4000000
var _visits := {}
## When set, every winning route found is kept here (up to `limit`).
var keep_all := false
var routes: Array = []


static func solve(level: LevelData, max_solutions := 20000, max_nodes := 4000000) -> Dictionary:
	var s := Solver.new()
	s.L = level
	s.limit = max_solutions
	s.node_limit = max_nodes
	s.max_len = level.road_count() * (1 if level.no_revisit else REVISIT_CAP) + level.bridges.size() + 2
	var t0 := Time.get_ticks_usec()
	s._visits = {level.start: 1}
	s._dfs([level.start], Sim.new_state(level))
	return {
		"count": s.count,
		"shortest": s.shortest,
		"capped": s.capped,
		"nodes": s.nodes,
		"ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}


## Every winning route (up to `cap`), shortest first.
static func solve_all(level: LevelData, cap := 400, max_nodes := 2000000) -> Array:
	var s := Solver.new()
	s.L = level
	s.limit = cap
	s.node_limit = max_nodes
	s.keep_all = true
	s.max_len = level.road_count() * (1 if level.no_revisit else REVISIT_CAP) + level.bridges.size() + 2
	s._visits = {level.start: 1}
	s._dfs([level.start], Sim.new_state(level))
	s.routes.sort_custom(func(a, b): return a.size() < b.size())
	return s.routes


## A winning route that drives over the level's present: either a winning route through it, or one that
## carries on past the last delivery to reach it ("the extra mile"). [] if the present can't be had.
static func gift_route(level: LevelData) -> Array:
	if level.gift_item == "":
		return []
	var routes := solve_all(level, 300)
	for r in routes:
		if r.has(level.gift):
			return r
	if level.return_depot:
		return []
	for r in routes:
		var ext := _reach(level, r.duplicate(), Sim.run(level, r), level.gift, 6)
		if not ext.is_empty():
			return ext
	return []


static func _reach(L: LevelData, route: Array, st: Dictionary, goal: Vector2i, depth: int) -> Array:
	if route.back() == goal:
		return route.duplicate()
	if depth <= 0:
		return []
	for d in LevelData.DIRS:
		var n: Vector2i = route.back() + d
		if not Sim.can_extend(L, route, n, st):
			continue
		route.append(n)
		var st2 := Sim.copy_state(st)
		Sim.arrive(L, st2, n)
		var got := _reach(L, route, st2, goal, depth - 1)
		route.pop_back()
		if not got.is_empty():
			return got
	return []


## The shortest way to finish from where the player is now: the tiles from the van's tile onwards, or [] if
## there's no way to win from here. Used for hints.
static func solve_from(level: LevelData, route: Array, state: Dictionary, max_nodes := 400000) -> Array:
	var s := Solver.new()
	s.L = level
	s.limit = 400
	s.node_limit = max_nodes
	s.max_len = level.road_count() * (1 if level.no_revisit else REVISIT_CAP) + level.bridges.size() + 2
	var from: Array = route.duplicate()
	if level.no_revisit:
		for t in from:
			s._visits[t] = s._visits.get(t, 0) + 1
	else:
		# Earlier driving doesn't restrict anything on these levels: search afresh from the van.
		from = [route.back()]
		s._visits = {route.back(): 1}
	if s._hopeless(from, state):
		return []
	s._dfs(from, Sim.copy_state(state))
	if s.shortest.is_empty():
		return []
	return s.shortest.slice(from.size() - 1)


func _dfs(route: Array, state: Dictionary) -> void:
	if count >= limit or nodes >= node_limit:
		capped = true
		return
	nodes += 1
	var last: Vector2i = route.back()
	for d in LevelData.DIRS:
		var nxt: Vector2i = last + d
		if not Sim.can_extend(L, route, nxt, state):
			continue
		var v: int = _visits.get(nxt, 0)
		if not L.no_revisit and v >= REVISIT_CAP:
			continue
		var st := Sim.copy_state(state)
		Sim.arrive(L, st, nxt)
		route.append(nxt)
		_visits[nxt] = v + 1
		if Sim.is_won(L, st, route):
			count += 1
			if keep_all:
				routes.append(route.duplicate())
			if shortest.is_empty() or route.size() < shortest.size():
				shortest = route.duplicate()
		elif route.size() < max_len and not _hopeless(route, st):
			_dfs(route, st)
		route.pop_back()
		_visits[nxt] = v


## True if something still needed can't be reached any more: a house still waiting, a
## shop still holding a parcel, or (return levels) the depot. Only valid without revisits.
func _hopeless(route: Array, st: Dictionary) -> bool:
	if not L.no_revisit:
		return false
	if Sim.parked(L, route):
		return true
	var last: Vector2i = route.back()
	var reach := {last: true}
	var queue := [last]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for d in LevelData.DIRS:
			var n: Vector2i = t + d
			if reach.has(n) or not L.is_road(n) or _used_up(n):
				continue
			reach[n] = true
			queue.append(n)
	var fills: Array = st["fills"]
	for h in L.houses.size():
		if fills[h] < L.houses[h].order and not _touches(L.house_roads[h], reach, last):
			return true
	var picked: Array = st["picked"]
	for k in L.shops.size():
		if picked[k] < L.shops[k].count and not _touches(L.shop_roads[k], reach, last):
			return true
	if L.return_depot:
		var home := false
		for d in LevelData.DIRS:
			if reach.has(L.start + d):
				home = true
				break
		if not home:
			return true
	return false


func _touches(roads: Array, reach: Dictionary, last: Vector2i) -> bool:
	for rp in roads:
		if reach.has(rp) and rp != last:
			return true
	return false


func _used_up(t: Vector2i) -> bool:
	var v: int = _visits.get(t, 0)
	return v >= (2 if L.bridges.has(t) else 1)


static func describe(L: LevelData, r: Dictionary) -> String:
	var n: int = r["count"]
	var s := "%d%s solution%s" % [n, "+" if r["capped"] else "", "" if n == 1 else "s"]
	if n > 0:
		s += " · shortest %d tiles" % (r["shortest"].size() - 1)
	s += " · %d nodes · %.0f ms" % [r.get("nodes", 0), r["ms"]]
	if not L.no_revisit:
		s += " · revisits on (≤%d/tile)" % REVISIT_CAP
	return s
