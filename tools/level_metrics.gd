extends RefCounted
## Level metrics and scores: how a level plays, measured with the real rules (Sim) and the real solver.
## Used by tools/level_report.gd (the scorecard), tools/gen_levels.gd (the generator) and anything else that
## wants to know whether a level is fun, clever, complex or hard. Load it with
##   const Metrics := preload("res://tools/level_metrics.gd")
## and call Metrics.measure(level_dict, number). Everything it returns is explained in
## design/level_engine.md; the short version:
##
## THE PLAYER MODEL. A level is judged against a "greedy driver": someone who always heads for the nearest
## place the top package can go, can see when a move obviously strands a house (the road to it is cut off),
## and otherwise doesn't plan. At every step of a winning route we ask how likely that driver was to make
## the right move. Where they'd have gone wrong, the level is asking for thought.
##   bits        how surprising the winning route is to the greedy driver (log2 of their expected tries)
##   decisions   steps where there's a real choice (two or more moves that aren't obviously dead)
##   anti        steps where the right move heads AWAY from the nearest delivery ("outside the box")
##   trick_bits  the single most surprising step ("the little trick")
##   traps       tempting wrong moves that don't look wrong yet
##   doom        how many moves a wrong turn can keep going before it's obviously dead (foresight:
##               "holding a long path in your head"); max_doom is the worst one, early_doom the worst in
##               the first third of the route
##   drive_bys   times the route passes a house that wants a package and doesn't deliver ("not yet")
## ROUTE CHOICE.
##   solutions   winning routes (as the game's solver counts them)
##   plans       distinct plans among them: the order things are delivered, picked up and swapped. Many
##               routes can drive one plan (round a block either way); the plan is the idea
##   free        winning routes if colours didn't matter (every house a locker): what the MAP allows
##   free_orders the distinct orders those routes visit the buildings in. Few (3 or less) is
##               connect-the-dots: the map decides the order, not the packages
##   openers     first real choices that can still win
## FOUR SCORES, each 0-10 (formulas in _scores()):
##   difficulty  mostly bits, plus foresight and load
##   cleverness  anti-greedy moves, the trick, drive-bys, stack tricks (hub, locker, pickup timing)
##   complexity  how much there is to hold: decisions, length, packages, mechanics, foresight
##   fun         a model, not a measurement: route choice, a healthy share of real decisions, an "aha"
##               or two, traps that resolve quickly, the map being used, mechanics that matter
## plus a `profile` saying which kind of difficulty the level flexes: foresight, lateral, trick, juggling,
## search.

const BETA := 0.9            # how strongly the greedy driver prefers the nearer delivery (per tile)
const DEAD_W := 0.04         # weight of an obviously dead move
const SOL_CAP := 60          # winning routes kept
const FREE_CAP := 150        # colour-blind routes looked at
const DOOM_CAP := 20         # longest a wrong turn is followed
const INF := 99


# ------------------------------------------------------------------ solving

static func solve_all(L: LevelData, cap: int, max_nodes: int) -> Dictionary:
	var s := Solver.new()
	s.L = L
	s.limit = cap
	s.node_limit = max_nodes
	s.keep_all = true
	s.max_len = L.road_count() * (1 if L.no_revisit else Solver.REVISIT_CAP) + L.bridges.size() + 2
	s._visits = {L.start: 1}
	s._dfs([L.start], Sim.new_state(L))
	s.routes.sort_custom(func(a, b): return a.size() < b.size())
	return {"routes": s.routes, "count": s.count, "nodes": s.nodes, "capped": s.capped}


## The level with every house turned into a locker (it takes whatever's on top) and every colour gate into
## plain road: what's left is what the map allows.
static func lockerized(d: Dictionary) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var rows := []
	for row in d["map"]:
		var out := []
		for tk in str(row).split(" ", false):
			var t: String = tk
			if "rbgypo".contains(t[0]) and (t.length() == 1 or t.substr(1).is_valid_int()):
				t = "w" + t.substr(1)
			elif t.begins_with("=") and t.length() == 2:
				t = "#"
			out.append(t)
		rows.append(" ".join(out))
	c["map"] = rows
	return c


## A route's plan: what happens in what order (which house gets a package, which shop is emptied, swaps).
static func plan_key(L: LevelData, route: Array) -> String:
	var st := Sim.new_state(L)
	var out := PackedStringArray()
	for i in range(1, route.size()):
		for ev in Sim.arrive(L, st, route[i])["events"]:
			match str(ev["type"]):
				"deliver":
					out.append("d%d" % int(ev["house"]))
				"pickup":
					out.append("p%d" % int(ev["shop"]))
				"swap":
					out.append("s")
	return "".join(out)


static func plan_count(L: LevelData, routes: Array) -> int:
	var seen := {}
	for r in routes:
		seen[plan_key(L, r)] = true
	return seen.size()


## Route choice with colours ignored: {"routes": winning routes (up to `cap`), "orders": the distinct orders
## they visit the buildings in}. {"routes": -1} if that level can't be built.
static func free_choice(d: Dictionary, cap := FREE_CAP, max_nodes := 60000) -> Dictionary:
	var L := LevelData.from_dict(lockerized(d), 0)
	if not L.errors.is_empty():
		return {"routes": -1, "orders": -1}
	var r := solve_all(L, cap, max_nodes)
	var orders := {}
	for rt in r["routes"]:
		orders[plan_key(L, rt)] = true
	if bool(r["capped"]):
		# Too many to list (the list so far is one corner of them): sample random drives as well.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(d["map"]))
		for k in 28:
			var route: Array = [L.start]
			var budget := [200 + 12 * L.road_count()]
			if _random_cover(L, route, Sim.new_state(L), rng, budget):
				orders[plan_key(L, route)] = true
	return {"routes": int(r["count"]), "orders": orders.size(), "capped": bool(r["capped"])}


## A random winning drive (directions tried in random order). True if `route` now holds one.
static func _random_cover(L: LevelData, route: Array, st: Dictionary, rng: RandomNumberGenerator, budget: Array) -> bool:
	if int(budget[0]) <= 0:
		return false
	budget[0] = int(budget[0]) - 1
	var order := [0, 1, 2, 3]
	for i in range(3, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var last: Vector2i = route.back()
	for di in order:
		var nxt: Vector2i = last + LevelData.DIRS[di]
		if not Sim.can_extend(L, route, nxt, st):
			continue
		var st2 := Sim.copy_state(st)
		Sim.arrive(L, st2, nxt)
		route.append(nxt)
		if Sim.is_won(L, st2, route):
			return true
		if not hopeless(L, route, st2) and _random_cover(L, route, st2, rng, budget):
			return true
		route.pop_back()
	return false


## Winning routes with colours ignored, counted up to `cap` (-1: that level can't be built).
static func free_routes(d: Dictionary, cap := FREE_CAP, max_nodes := 60000) -> int:
	var L := LevelData.from_dict(lockerized(d), 0)
	if not L.errors.is_empty():
		return -1
	var r := Solver.solve(L, cap, max_nodes)
	if r["capped"] and int(r["count"]) < cap:
		return maxi(int(r["count"]), cap / 2)   # the search ran out first: a lower bound
	return int(r["count"])


const FAMILIES := {"ice": ["~"], "oneway": [">", "<", "^", "v"], "works": ["c"], "gate": ["="], "hub": ["@"], "bridge": ["+"]}

static func has_family(d: Dictionary, fam: String) -> bool:
	for row in d["map"]:
		for tk in str(row).split(" ", false):
			if _in_family(tk, fam):
				return true
	return false


static func _in_family(tk: String, fam: String) -> bool:
	match fam:
		"works":
			return tk.begins_with("c") and tk.length() > 1 and tk.substr(1).is_valid_int()
		"gate":
			return tk.begins_with("=") and tk.length() == 2
		"locker":
			return tk == "w" or (tk.begins_with("w") and tk.substr(1).is_valid_int())
	return tk in FAMILIES.get(fam, [])


## The level with one mechanic family turned into plain road.
static func stripped(d: Dictionary, fam: String) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var rows := []
	for row in d["map"]:
		var out := []
		for tk in str(row).split(" ", false):
			out.append("#" if _in_family(tk, fam) else tk)
		rows.append(" ".join(out))
	c["map"] = rows
	return c


## The level with one cell's token replaced.
static func with_token(d: Dictionary, p: Vector2i, tok: String) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var rows := []
	for row in d["map"]:
		rows.append(Array(str(row).split(" ", false)))
	rows[p.y][p.x] = tok
	var out := []
	for r in rows:
		out.append(" ".join(r))
	c["map"] = out
	return c


static func _route_key(r: Array) -> String:
	var s := PackedStringArray()
	for p in r:
		s.append("%d,%d" % [p.x, p.y])
	return ";".join(s)


## Which mechanic families change the answer. A family "matters" if the level without it has a different
## set of winning routes. Returns {family: true/false}; `idle` lists single ice/arrow/roadworks tiles that
## change nothing on their own.
static func ablation(d: Dictionary, base_routes: Array, node_cap: int) -> Dictionary:
	var keys := {}
	for r in base_routes:
		keys[_route_key(r)] = true
	var matters := {}
	for fam in FAMILIES:
		if not has_family(d, fam):
			continue
		matters[fam] = _differs(stripped(d, fam), keys, node_cap)
	var idle := 0
	var tiles := 0
	var rows: Array = d["map"]
	for y in rows.size():
		var toks := str(rows[y]).split(" ", false)
		for x in toks.size():
			for fam in ["ice", "oneway", "works"]:
				if _in_family(toks[x], fam):
					tiles += 1
					if matters.get(fam, false) and not _differs(with_token(d, Vector2i(x, y), "#"), keys, node_cap):
						idle += 1
					elif not matters.get(fam, false):
						idle += 1
	return {"matters": matters, "idle": idle, "tiles": tiles}


static func _differs(d2: Dictionary, keys: Dictionary, node_cap: int) -> bool:
	var L2 := LevelData.from_dict(d2, 0)
	if not L2.errors.is_empty():
		return true
	var r := solve_all(L2, keys.size() + 2, node_cap)
	if int(r["count"]) != keys.size():
		return true
	for rt in r["routes"]:
		if not keys.has(_route_key(rt)):
			return true
	return false


# ------------------------------------------------------------------ the greedy driver

static func _visits_of(route: Array) -> Dictionary:
	var v := {}
	for p in route:
		v[p] = int(v.get(p, 0)) + 1
	return v


static func hopeless(L: LevelData, route: Array, st: Dictionary) -> bool:
	var sv := Solver.new()
	sv.L = L
	sv._visits = _visits_of(route)
	return sv._hopeless(route, st)


## Where the greedy driver wants to go next: the road tiles from which the top package can be delivered;
## if nobody wants it, wherever the load can change (a locker, a pickup, a hub); with nothing left, home.
static func targets(L: LevelData, st: Dictionary) -> Dictionary:
	var tiles := {}
	var stack: Array = st["stack"]
	var fills: Array = st["fills"]
	var picked: Array = st["picked"]
	if not stack.is_empty():
		var top: String = stack.back()
		for h in L.houses.size():
			if L.houses[h].color == top and fills[h] < L.houses[h].order:
				for rp in L.house_roads[h]:
					tiles[rp] = true
		if tiles.is_empty():
			for h in L.houses.size():
				if L.houses[h].color == "any" and fills[h] < L.houses[h].order:
					for rp in L.house_roads[h]:
						tiles[rp] = true
	if tiles.is_empty():
		for k in L.shops.size():
			if picked[k] < L.shops[k].count:
				for rp in L.shop_roads[k]:
					tiles[rp] = true
		if stack.size() >= 2:
			for hb in L.hubs:
				tiles[hb] = true
	if tiles.is_empty() and L.return_depot:
		tiles[L.start] = true
	return tiles


## Tiles from `from` to the nearest target over road not yet torn up (0 if `from` is one).
static func _dist(L: LevelData, from: Vector2i, tg: Dictionary, used: Dictionary) -> int:
	if tg.has(from):
		return 0
	var seen := {from: 0}
	var queue: Array[Vector2i] = [from]
	var qi := 0
	while qi < queue.size():
		var t: Vector2i = queue[qi]
		qi += 1
		var dt: int = seen[t]
		for d in LevelData.DIRS:
			var n: Vector2i = t + d
			if seen.has(n) or not L.is_road(n):
				continue
			if tg.has(n) and (not used.has(n) or n == L.start):
				return dt + 1
			if used.has(n) and not L.bridges.has(n):
				continue
			seen[n] = dt + 1
			queue.append(n)
	return INF


## Every legal move from the end of `route`, as the greedy driver sees it:
## [{to, state, won, dead, dist, w, events, nopes}], with `w` the weight they give it.
static func moves(L: LevelData, route: Array, st: Dictionary) -> Array:
	var out := []
	var last: Vector2i = route.back()
	var tg := targets(L, st)
	var used := {}
	for p in route:
		used[p] = true
	var dmin := INF
	for d in LevelData.DIRS:
		var nxt: Vector2i = last + d
		if not Sim.can_extend(L, route, nxt, st):
			continue
		var st2 := Sim.copy_state(st)
		var res := Sim.arrive(L, st2, nxt)
		var r2: Array = route.duplicate()
		r2.append(nxt)
		var won := Sim.is_won(L, st2, r2)
		var dead := false
		if not won:
			dead = hopeless(L, r2, st2) or not Sim.has_move(L, r2, st2)
		var dist := 0 if won else _dist(L, nxt, tg, used)
		if not dead:
			dmin = mini(dmin, dist)
		out.append({"to": nxt, "state": st2, "won": won, "dead": dead, "dist": dist, "w": 1.0,
			"events": res["events"], "nopes": res["nopes"]})
	if dmin == INF:
		dmin = 0
	for m in out:
		var extra := clampi(int(m["dist"]) - dmin, 0, 3)
		var w := exp(-BETA * extra)
		if m["dead"]:
			w *= DEAD_W
		m["w"] = w
	return out


## How long the greedy driver keeps going after a wrong turn before it's obvious (every move left strands
## something, or there's none): the moves a mistake costs, and how far ahead you'd have had to look.
static func _doom(L: LevelData, route: Array, st: Dictionary) -> int:
	var r: Array = route.duplicate()
	var s: Dictionary = st
	var depth := 0
	while depth < DOOM_CAP:
		var ms := moves(L, r, s)
		var best: Dictionary = {}
		for m in ms:
			if m["dead"]:
				continue
			if m["won"]:
				return DOOM_CAP
			if best.is_empty() or float(m["w"]) > float(best["w"]) + 0.000001:
				best = m
		if best.is_empty():
			break
		r.append(best["to"])
		s = best["state"]
		depth += 1
	return depth


## Walks one winning route step by step against the greedy driver.
static func walk(L: LevelData, sol: Array, prefixes: Dictionary, complete: bool, deep := true) -> Dictionary:
	var st := Sim.new_state(L)
	var bits := 0.0
	var decisions := 0
	var anti := 0
	var trick := 0.0
	var traps := 0
	var trap_mass := 0.0
	var doom_sum := 0.0
	var max_doom := 0
	var early_doom := 0
	var on_track := 1.0       # chance the greedy driver is still on a winning route
	var fail_p := 0.0         # chance their try ends in a wrong turn
	var fail_moves := 0.0     # ... weighted by the moves that try took
	var fail_late := 0.0      # ... weighted by the moves driven after the wrong turn
	var drive_bys := 0
	var swaps := 0
	var pickups := 0
	var dumps := 0
	var forced_run := 0
	var longest_forced := 0
	var openers := -1
	var first_anti := -1
	var turns := 0
	var late_drops := 0       # deliveries made on a later pass of the house, not the first
	var locker_drops := 0
	var gate_passes := 0
	var works_passes := 0
	var oneway_used := 0
	var ice_slides := 0
	var bridge_seen := {}
	var bridge_double := 0
	var passed := {}          # house -> true once the route has been next to it
	var anti_steps := []
	var pickup_steps := []
	var n := sol.size()
	var step_bits := []
	for i in range(0, n - 1):
		var route: Array = sol.slice(0, i + 1)
		var ms := moves(L, route, st)
		var total := 0.0
		var alive := 0
		var chosen: Dictionary = {}
		for m in ms:
			total += float(m["w"])
			if not m["dead"]:
				alive += 1
			if m["to"] == sol[i + 1]:
				chosen = m
		if chosen.is_empty():
			return {"ok": false}
		var b := -log(float(chosen["w"]) / total) / log(2.0)
		bits += b
		step_bits.append(b)
		trick = maxf(trick, b)
		if alive >= 2:
			decisions += 1
			longest_forced = maxi(longest_forced, forced_run)
			forced_run = 0
			var nearer := false
			for m in ms:
				if not m["dead"] and m["to"] != chosen["to"] and int(m["dist"]) < int(chosen["dist"]):
					nearer = true
			if nearer:
				anti += 1
				anti_steps.append(i)
				if first_anti < 0:
					first_anti = decisions
			var good := 0
			for m in ms:
				if m["dead"]:
					continue
				var r2: Array = route.duplicate()
				r2.append(m["to"])
				var on_sol: bool = m["to"] == chosen["to"] or prefixes.has(_route_key(r2))
				if on_sol:
					good += 1
					continue
				if not complete:
					continue
				traps += 1
				var p := float(m["w"]) / total
				trap_mass += p
				var dd := 1
				if deep:
					dd = 1 + _doom(L, r2, m["state"])
					doom_sum += p * dd
					max_doom = maxi(max_doom, dd)
					if i * 3 < n:
						early_doom = maxi(early_doom, dd)
				fail_p += on_track * p
				fail_moves += on_track * p * (i + dd)
				fail_late += on_track * p * dd
			if openers < 0:
				openers = good
		else:
			forced_run += 1
		# Obviously dead moves cost a try too (rarely taken, found out at once).
		for m in ms:
			if m["dead"]:
				var pd := float(m["w"]) / total
				fail_p += on_track * pd
				fail_moves += on_track * pd * (i + 1)
				fail_late += on_track * pd
		on_track *= float(chosen["w"]) / total
		if i >= 1 and sol[i + 1] - sol[i] != sol[i] - sol[i - 1]:
			turns += 1
		# What happens on arrival.
		var to: Vector2i = sol[i + 1]
		if L.gates.has(to):
			gate_passes += 1
		if L.works.has(to):
			works_passes += 1
		if L.oneway.has(to):
			oneway_used += 1
		if L.ice.has(to):
			var deg := 0
			for dd4 in LevelData.DIRS:
				if L.is_road(to + dd4):
					deg += 1
			if deg >= 3:
				ice_slides += 1
		if L.bridges.has(to):
			if bridge_seen.has(to):
				bridge_double += 1
			bridge_seen[to] = true
		drive_bys += (chosen["nopes"] as Array).size()
		for ev in chosen["events"]:
			match str(ev["type"]):
				"swap":
					swaps += 1
				"pickup":
					pickups += 1
					pickup_steps.append(i)
				"deliver":
					var hi: int = ev["house"]
					if passed.has(hi):
						late_drops += 1
					if L.houses[hi].color == "any":
						locker_drops += 1
						# A locker took it. A "dump" if some house still wanted that colour.
						var fills: Array = (chosen["state"] as Dictionary)["fills"]
						for h in L.houses.size():
							if L.houses[h].color == str(ev["color"]) and fills[h] < L.houses[h].order:
								dumps += 1
								break
		for hh in L.adjacent_houses.get(to, []):
			passed[hh] = true
		st = chosen["state"]
	longest_forced = maxi(longest_forced, forced_run)
	# Pickups reached by going against the greedy pull just before (holding off, or fetching early).
	var pickup_anti := 0
	for ps in pickup_steps:
		for a in anti_steps:
			if a <= ps and ps - a <= 5:
				pickup_anti += 1
				break
	return {"ok": true, "bits": bits, "decisions": decisions, "anti": anti, "trick": trick, "traps": traps,
		"trap_mass": trap_mass, "doom": doom_sum, "max_doom": max_doom, "early_doom": early_doom,
		"drive_bys": drive_bys, "swaps": swaps, "pickups": pickups, "dumps": dumps,
		"longest_forced": longest_forced, "openers": maxi(openers, 1), "first_anti": first_anti, "turns": turns,
		"step_bits": step_bits, "late_drops": late_drops, "locker_drops": locker_drops, "gate_passes": gate_passes,
		"works_passes": works_passes, "oneway_used": oneway_used, "ice_slides": ice_slides, "bridge_double": bridge_double,
		"pickup_anti": pickup_anti,
		"fail_moves": fail_moves / maxf(fail_p, 0.000001) if fail_p > 0.0 else 0.0,
		"late": fail_late / maxf(fail_p, 0.000001) if fail_p > 0.0 else 0.0}


## Does the pure greedy driver (always the highest-weight move, first one on a tie) win? Returns how far
## along they got as a share of the winning route's length (1.0: they win).
static func greedy_run(L: LevelData, sol_len: int) -> float:
	var route: Array = [L.start]
	var st := Sim.new_state(L)
	for step in sol_len * 2 + 8:
		var ms := moves(L, route, st)
		if ms.is_empty():
			break
		var best: Dictionary = ms[0]
		for m in ms:
			if float(m["w"]) > float(best["w"]) + 0.000001:
				best = m
		route.append(best["to"])
		st = best["state"]
		if best["won"]:
			return 1.0
		if best["dead"]:
			break
	return clampf(float(route.size() - 1) / maxf(sol_len - 1, 1.0), 0.0, 0.99)


# ------------------------------------------------------------------ the whole measure

static func mechanics(L: LevelData) -> Array:
	var m := []
	if not L.oneway.is_empty(): m.append("oneway")
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


## Everything about one level. opts: {"nodes": solver budget, "deep": follow traps (default true),
## "ablate": check which mechanics matter (default true), "free": count colour-blind routes (default true)}.
static func measure(d: Dictionary, number := 0, opts := {}) -> Dictionary:
	var L := LevelData.from_dict(d, number)
	var out := {"ok": false, "errors": L.errors}
	if not L.errors.is_empty():
		return out
	var node_cap: int = opts.get("nodes", 400000)
	var r := solve_all(L, SOL_CAP, node_cap)
	var routes: Array = r["routes"]
	out["solutions"] = int(r["count"])
	out["nodes"] = int(r["nodes"])
	out["capped"] = bool(r["capped"])
	if routes.is_empty():
		return out
	var complete: bool = not bool(r["capped"])
	var prefixes := {}
	for rt in routes:
		var acc := PackedStringArray()
		for p in rt:
			acc.append("%d,%d" % [p.x, p.y])
			prefixes[";".join(acc)] = true
	# Every winning route against the greedy driver: the level is as easy as its easiest route to stumble on.
	var best: Dictionary = {}
	var best_route: Array = []
	var p_total := 0.0
	var deep: bool = opts.get("deep", true)
	for k in routes.size():
		var w := walk(L, routes[k], prefixes, complete, false)
		if not w["ok"]:
			continue
		p_total += pow(2.0, -float(w["bits"]))
		if best.is_empty() or float(w["bits"]) < float(best["bits"]):
			best = w
			best_route = routes[k]
	if best.is_empty():
		return out
	best = walk(L, best_route, prefixes, complete, deep)
	var sol: Array = best_route
	var shortest: Array = routes[0]
	out["ok"] = true
	out["route"] = sol
	out["shortest"] = shortest
	out["len"] = sol.size() - 1
	out["short_len"] = shortest.size() - 1
	out["long_len"] = (routes.back() as Array).size() - 1
	out["bits"] = -log(maxf(p_total, 1e-30)) / log(2.0)
	for k in ["decisions", "anti", "trick", "traps", "trap_mass", "doom", "max_doom", "early_doom", "drive_bys",
			"swaps", "pickups", "dumps", "longest_forced", "openers", "first_anti", "turns", "fail_moves", "late",
			"late_drops", "locker_drops", "gate_passes", "works_passes", "oneway_used", "ice_slides", "bridge_double", "pickup_anti"]:
		out[k] = best[k]
	# Effort: log2 of the moves the greedy driver burns on failed tries before a win.
	var fails := pow(2.0, float(out["bits"])) - 1.0
	out["effort"] = log(1.0 + fails * maxf(float(best["fail_moves"]), 1.0)) / log(2.0)
	out["greedy"] = greedy_run(L, sol.size())
	var used := {}
	for p in sol:
		used[p] = true
	out["roads"] = L.road_count()
	out["cover"] = float(used.size()) / maxf(L.road_count(), 1.0)
	out["packages"] = L.total_orders()
	out["houses"] = L.houses.size()
	out["max_load"] = Sim.max_load(L, sol)
	var cols := {}
	for h in L.houses:
		cols[h.color] = true
	out["colours"] = cols.size()
	out["mechanics"] = mechanics(L)
	out["size"] = [L.width, L.height]
	# Houses that can be reached from two or more road tiles.
	var two := 0
	for hr in L.house_roads:
		if (hr as Array).size() >= 2:
			two += 1
	out["two_door"] = two
	# Route choice.
	out["plans"] = plan_count(L, routes)
	out["free"] = -1
	out["free_orders"] = -1
	if opts.get("free", true):
		var fc := free_choice(d, FREE_CAP, maxi(node_cap / 4, 20000))
		out["free"] = fc["routes"]
		out["free_orders"] = fc["orders"]
	# Twin: two answers that share little.
	out["overlap"] = 1.0
	if routes.size() >= 2:
		var a := {}
		for p in routes[0]:
			a[p] = true
		var best_ov := 1.0
		for k in range(1, routes.size()):
			var inter := 0
			var uni := a.size()
			var seen := {}
			for p in routes[k]:
				if seen.has(p):
					continue
				seen[p] = true
				if a.has(p):
					inter += 1
				else:
					uni += 1
			best_ov = minf(best_ov, float(inter) / maxf(uni, 1.0))
		out["overlap"] = best_ov
	# Mechanics that matter.
	out["matters"] = {}
	out["idle"] = 0
	out["mech_tiles"] = 0
	if opts.get("ablate", true):
		var ab := ablation(d, routes, maxi(node_cap / 4, 20000)) if complete else {"matters": {}, "idle": 0, "tiles": 0}
		out["matters"] = ab["matters"]
		out["idle"] = ab["idle"]
		out["mech_tiles"] = ab["tiles"]
	_scores(out)
	return out


static func _sat(x: float, k: float) -> float:
	return 1.0 - exp(-maxf(x, 0.0) / k)


## A hump: 1 between lo and hi, falling off outside.
static func _band(x: float, lo: float, hi: float, soft: float) -> float:
	if x < lo:
		return clampf(1.0 - (lo - x) / soft, 0.0, 1.0)
	if x > hi:
		return clampf(1.0 - (x - hi) / soft, 0.0, 1.0)
	return 1.0


## The four headline scores and the difficulty profile, from the raw measures.
static func _scores(m: Dictionary) -> void:
	var decisions: int = m["decisions"]
	var anti: int = m["anti"]
	var len: int = m["len"]
	var kinds: int = (m["mechanics"] as Array).size()
	var late: float = m["late"]
	var max_doom: int = m["max_doom"]
	var packages: int = m["packages"]
	var stack_tricks: int = int(m["swaps"]) + int(m["dumps"]) + mini(int(m["pickups"]), 3)
	# The kinds of difficulty, each 0-1.
	var foresight := _sat(maxf(late - 2.5, 0.0) + 0.08 * max_doom, 4.0)
	# Lateral: several moves against the obvious. Trick: one surprising step in an otherwise ordinary drive.
	var lateral := _sat(float(anti) + 0.5 * int(m["late_drops"]), 1.8) if anti >= 1 else 0.15 * minf(float(int(m["late_drops"])), 2.0)
	var trick := _sat(maxf(float(m["trick"]) - 1.5, 0.0), 2.2) * (1.0 if anti <= 1 else 0.6)
	var juggling := _sat(stack_tricks + 0.15 * maxi(int(m["max_load"]) - 5, 0) + 0.4 * maxi(int(m["colours"]) - 2, 0), 4.5)
	var search := _sat(decisions + 0.6 * int(m["traps"]), 12.0)
	m["profile"] = {"foresight": snappedf(foresight, 0.01), "lateral": snappedf(lateral, 0.01), "trick": snappedf(trick, 0.01),
		"juggling": snappedf(juggling, 0.01), "search": snappedf(search, 0.01)}
	# Complexity: how much there is to hold in your head.
	var load := 0.32 * decisions + 0.07 * len + 0.25 * packages + 0.7 * kinds + 0.2 * maxf(late - 1.0, 0.0) + 0.5 * stack_tricks
	var complexity := 10.0 * _sat(load, 9.0)
	# Cleverness: how far the answer is from the obvious one.
	var clever_raw := 1.6 * anti + 0.9 * maxf(float(m["trick"]) - 1.5, 0.0) + 0.3 * mini(int(m["drive_bys"]), 4) \
		+ 1.2 * int(m["dumps"]) + 0.6 * int(m["swaps"]) + (1.0 if float(m["greedy"]) < 0.5 else 0.0)
	var cleverness := 10.0 * _sat(clever_raw, 7.0)
	# Difficulty: the greedy driver's wasted moves (effort), plus a little for sheer load.
	var difficulty := 10.0 * _sat(float(m["effort"]) + 0.08 * load, 8.0)
	# Fun (a model): choice, agency, an aha, fairness, economy, purpose.
	var free: int = m["free_orders"]
	var choice := _sat(float(maxi(free - 1, 0)), 5.0) if free >= 0 else 0.5
	var share := float(decisions) / maxf(len, 1.0)
	var agency := _band(share, 0.18, 0.55, 0.18)
	var aha := _band(float(anti) + (1.0 if float(m["trick"]) >= 2.5 else 0.0), 1.0, 4.0, 2.5)
	var fair := _band(late, 0.0, 6.0, 8.0)
	var economy := 0.5 * clampf(float(m["cover"]) / 0.6, 0.0, 1.0) + 0.5 * clampf(1.0 - float(int(m["longest_forced"])) / maxf(len, 1.0) * 1.4, 0.0, 1.0)
	var tiles: int = m["mech_tiles"]
	var purpose := 1.0 if tiles == 0 else clampf(1.0 - float(int(m["idle"])) / float(tiles), 0.0, 1.0)
	# Freedom: several ways to drive the same plan (forgiving), not one exact path.
	var freedom := _sat(float(int(m["solutions"])) / maxf(float(int(m.get("plans", 1))), 1.0) - 1.0, 3.0)
	var fun := 10.0 * (0.24 * choice + 0.18 * agency + 0.18 * aha + 0.12 * fair + 0.10 * economy + 0.10 * purpose + 0.08 * freedom)
	m["difficulty"] = snappedf(difficulty, 0.1)
	m["cleverness"] = snappedf(cleverness, 0.1)
	m["complexity"] = snappedf(complexity, 0.1)
	m["fun"] = snappedf(fun, 0.1)
	m["fun_parts"] = {"choice": snappedf(choice, 0.01), "agency": snappedf(agency, 0.01), "aha": snappedf(aha, 0.01),
		"fair": snappedf(fair, 0.01), "economy": snappedf(economy, 0.01), "purpose": snappedf(purpose, 0.01),
		"freedom": snappedf(freedom, 0.01)}
