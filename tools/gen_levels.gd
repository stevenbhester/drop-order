extends SceneTree
## The level generator (the "engine"). Map first, stack second.
##
##   godot --headless --path . --script res://tools/gen_levels.gd -- --slot=37 [--plan=res://tools/level_plan.json]
##       [--tries=400] [--seed=1] [--keep=6] [--current]
##
## One run fills one slot of the plan (tools/level_plan.json, written by tools/make_plan.py): a slot says what
## the level is for (its flavour, how hard, which mechanics, how big) and the generator makes candidates
## until some fit, scoring each with tools/level_metrics.gd. It prints the best as "CAND {json}" lines
## (tools/gen_all.sh runs slots side by side; tools/assemble_levels.py picks and writes levels.json).
## --current also scores the level now in that slot as a candidate ("kept": true), so a level that already
## fits is kept.
##
## How a candidate is made (design/level_engine.md has the reasoning):
##  1. A TOWN: a lattice of streets two or three apart with most of its loops kept, so there are many ways
##     to drive it. With `districts`, the lattice is cut into neighbourhoods joined by one or two door tiles.
##  2. FIXTURES that shape driving whatever's aboard: bridges at crossroads, hubs, some ice (only at
##     junctions, where turning is the tempting move) and one-way streets.
##  3. BUILDINGS: houses, lockers and pickups on cells beside the streets, preferring cells that touch two
##     or more streets (a house you can drive past now and deliver to later).
##  4. A DRIVE: a random route that passes every building at least once (one of the many the town allows),
##     often carrying on a little so some buildings are passed twice.
##  5. THE LOAD, worked out backwards from that drive: each house gets its package on one of the passes
##     (not always the first), pickups hand over whatever is needed next, lockers take a package of a
##     chosen colour. What's left at the start is the van's stack. The real rules (Sim) then check the drive
##     wins.
##  6. DOORS that depend on the load: colour gates and roadworks on the drive, set to what the van has done
##     by then.
##  7. NARROWING: if the level has too many answers, add an allowed road mechanic where it removes some.
##     Then every mechanic tile that changes nothing is taken away again (a few are left in as red herrings).
##  8. JUDGING: route choice (colour-blind routes), the solver's count and cost, the four scores, the
##     flavour's signature, the mechanic-intro rule, and how close it is to the difficulty the plan asked for.

const Metrics := preload("res://tools/level_metrics.gd")
const COLORS := ["r", "b", "g", "y", "p", "o"]
const NAMES := {"r": "red", "b": "blue", "g": "green", "y": "yellow", "p": "purple", "o": "orange"}
const ARROW_TOK := {Vector2i(0, -1): "^", Vector2i(1, 0): ">", Vector2i(0, 1): "v", Vector2i(-1, 0): "<"}

var S := {}
var W := 5
var H := 7
var rejects := {}
var found: Array = []
var verbose := false


func _init() -> void:
	var plan_path := "res://tools/level_plan.json"
	var slot := 1
	var tries := 300
	var seed_v := 1
	var keep := 6
	var current := false
	var secs := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="):
			plan_path = a.trim_prefix("--plan=")
		elif a.begins_with("--slot="):
			slot = a.trim_prefix("--slot=").to_int()
		elif a.begins_with("--tries="):
			tries = a.trim_prefix("--tries=").to_int()
		elif a.begins_with("--seed="):
			seed_v = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--keep="):
			keep = a.trim_prefix("--keep=").to_int()
		elif a.begins_with("--secs="):
			secs = a.trim_prefix("--secs=").to_float()
		elif a == "--current":
			current = true
		elif a == "--verbose":
			verbose = true
	var plan = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	for sp in plan["slots"]:
		if int(sp["n"]) == slot:
			S = sp
	if S.is_empty():
		print("no slot %d in %s" % [slot, plan_path])
		quit()
		return
	W = int(S["w"])
	H = int(S["h"])
	seed(seed_v * 7919 + slot * 104729)
	var t0 := Time.get_ticks_msec()
	if current:
		_score_current(slot)
	for t in tries:
		if secs > 0.0 and (Time.get_ticks_msec() - t0) / 1000.0 > secs:
			break
		var c = _attempt()
		if c != null:
			found.append(c)
	found.sort_custom(func(a, b): return float(a["fit"]) > float(b["fit"]))
	var rk := rejects.keys()
	rk.sort_custom(func(a, b): return rejects[a] > rejects[b])
	print("# slot %d (%s, %s): %d kept of %d tries in %.0fs. Rejected: %s" % [slot, S.get("flavor", ""), S.get("tier", ""), found.size(),
		tries, (Time.get_ticks_msec() - t0) / 1000.0, ", ".join(rk.slice(0, 9).map(func(k): return "%s ×%d" % [k, rejects[k]]))])
	for c in found.slice(0, keep):
		print("CAND " + JSON.stringify(c))
	quit()


func _rej(why: String):
	rejects[why] = int(rejects.get(why, 0)) + 1
	return null


func _pick(key: String, dflt: Array) -> int:
	var r: Array = S.get(key, dflt)
	return randi_range(int(r[0]), int(r[1]))


# ------------------------------------------------------------------ 1. the town

var _wide := 0.2

func _lines(n: int) -> Array:
	var xs := []
	var x := randi() % 2
	var wide := _wide
	while x < n:
		xs.append(x)
		x += 2 + (1 if randf() < wide else 0)
	return xs


func _root(parent: Dictionary, p: Vector2i) -> Vector2i:
	while parent[p] != p:
		p = parent[p]
	return p


func _make_map() -> Dictionary:
	# Towns differ: tight one-tile blocks, or some longer ones (unless the slot says).
	_wide = float(S["wide"]) if S.has("wide") else [0.0, 0.15, 0.3, 0.5].pick_random()
	var xs := _lines(W)
	var ys := _lines(H)
	if xs.size() < 2 or ys.size() < 2:
		return {}
	var nd := int(S.get("districts", 1))
	var along_y := ys.size() >= xs.size()
	var n_lines := ys.size() if along_y else xs.size()
	if nd > n_lines:
		return {}
	var parent := {}
	var dist := {}          # junction -> district
	for xi in xs.size():
		for yi in ys.size():
			var j := Vector2i(xs[xi], ys[yi])
			parent[j] = j
			dist[j] = mini((yi if along_y else xi) * nd / n_lines, nd - 1)
	var inner := []
	var cross := []
	for xi in xs.size():
		for yi in ys.size():
			var a := Vector2i(xs[xi], ys[yi])
			if xi + 1 < xs.size():
				var b := Vector2i(xs[xi + 1], ys[yi])
				(inner if dist[a] == dist[b] else cross).append([a, b])
			if yi + 1 < ys.size():
				var b2 := Vector2i(xs[xi], ys[yi + 1])
				(inner if dist[a] == dist[b2] else cross).append([a, b2])
	inner.shuffle()
	cross.shuffle()
	var lr: Array = S.get("loops", [60, 90])
	var loops := randf_range(float(lr[0]), float(lr[1]))
	var kept := []
	for e in inner:
		var ra := _root(parent, e[0])
		var rb := _root(parent, e[1])
		if ra != rb:
			parent[ra] = rb
			kept.append(e)
		elif randf() * 100.0 < loops:
			kept.append(e)
	# A bridge needs a crossroads: give one or two inner junctions all four of their streets.
	var want_cross := int((S.get("bridge", [0, 0]) as Array)[1])
	if want_cross > 0 and xs.size() >= 3 and ys.size() >= 3:
		for k in want_cross:
			var cx := randi_range(1, xs.size() - 2)
			var cy := randi_range(1, ys.size() - 2)
			var j := Vector2i(xs[cx], ys[cy])
			for nbj in [Vector2i(xs[cx - 1], ys[cy]), Vector2i(xs[cx + 1], ys[cy]), Vector2i(xs[cx], ys[cy - 1]), Vector2i(xs[cx], ys[cy + 1])]:
				if dist[nbj] == dist[j]:
					kept.append([j, nbj])
	var doors := {}
	var per_cut := {}
	var want := int(S.get("doors", 1))
	for e in cross:
		var cut := mini(int(dist[e[0]]), int(dist[e[1]]))
		if int(per_cut.get(cut, 0)) >= want:
			continue
		per_cut[cut] = int(per_cut.get(cut, 0)) + 1
		kept.append(e)
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		doors[a + Vector2i(signi(b.x - a.x), signi(b.y - a.y))] = true
		parent[_root(parent, a)] = _root(parent, b)
	for cut in nd - 1:
		if not per_cut.has(cut):
			return {}
	var road := {}
	var zone := {}          # road tile -> district
	for e in kept:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var p := a
		road[p] = true
		zone[p] = dist[a]
		while p != b:
			p += d
			road[p] = true
			zone[p] = dist[b] if doors.has(p - d) or p == b else dist[a]
	# One town: everything must be joined up.
	var first: Vector2i = road.keys()[0]
	var seen := {first: true}
	var queue := [first]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for d in LevelData.DIRS:
			if road.has(t + d) and not seen.has(t + d):
				seen[t + d] = true
				queue.append(t + d)
	if seen.size() != road.size():
		return {}
	return {"road": road, "doors": doors, "zone": zone, "districts": nd}


func _deg(road: Dictionary, p: Vector2i) -> int:
	var n := 0
	for d in LevelData.DIRS:
		if road.has(p + d):
			n += 1
	return n


func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


# ------------------------------------------------------------------ the design, and its level

## Everything a level is made of, in the generator's own terms; _dict() turns it into the game's format.
func _dict(D: Dictionary) -> Dictionary:
	var rows := []
	var road: Dictionary = D["road"]
	for y in H:
		var toks := []
		for x in W:
			var p := Vector2i(x, y)
			if p == D["start"]:
				toks.append("S")
			elif D["bridges"].has(p):
				toks.append("+")
			elif D["hubs"].has(p):
				toks.append("@")
			elif D["gates"].has(p):
				toks.append("=" + str(D["gates"][p]))
			elif D["works"].has(p):
				toks.append("c%d" % int(D["works"][p]))
			elif D["ice"].has(p):
				toks.append("~")
			elif D["arrows"].has(p):
				toks.append(ARROW_TOK[D["arrows"][p]])
			elif road.has(p):
				toks.append("#")
			elif D["houses"].has(p):
				var h: Dictionary = D["houses"][p]
				toks.append(str(h["color"]) + (str(h["order"]) if int(h["order"]) > 1 else ""))
			elif D["lockers"].has(p):
				var lk: Dictionary = D["lockers"][p]
				toks.append("w" + (str(lk["order"]) if int(lk["order"]) > 1 else ""))
			elif D["shops"].has(p):
				var sh: Dictionary = D["shops"][p]
				toks.append(str(sh["color"]).to_upper() + (str(sh["count"]) if int(sh["count"]) > 1 else ""))
			else:
				toks.append(".")
		rows.append(" ".join(toks))
	var d := {"title": "", "no_revisit": true, "map": rows, "stack": (D["stack"] as Array).map(func(c): return NAMES.get(c, c))}
	if D["ret"]:
		d["return"] = true
	return d


func _valid(D: Dictionary) -> LevelData:
	var L := LevelData.from_dict(_dict(D), 0)
	if not L.errors.is_empty():
		return null
	var fin := Sim.run_checked(L, D["route"])
	if fin.is_empty() or not Sim.is_won(L, fin, D["route"]):
		return null
	return L


# ------------------------------------------------------------------ 4. a drive past everything

var _cw_nodes := 0

## A random self-avoiding drive on `L` (every building a locker) that passes them all. [] if none found.
func _cover_walk(L: LevelData, cap: int) -> Array:
	_cw_nodes = 0
	var route: Array = [L.start]
	if _cw_dfs(L, route, Sim.new_state(L), cap):
		return route
	return []


func _cw_dfs(L: LevelData, route: Array, st: Dictionary, cap: int) -> bool:
	if _cw_nodes >= cap:
		return false
	_cw_nodes += 1
	var last: Vector2i = route.back()
	var prev: Vector2i = last - route[route.size() - 2] if route.size() > 1 else Vector2i.ZERO
	var dirs: Array = LevelData.DIRS.duplicate()
	dirs.shuffle()
	# Mostly carry straight on (drives look like drives, not scribbles).
	if prev != Vector2i.ZERO and randf() < 0.45:
		dirs.erase(prev)
		dirs.push_front(prev)
	for d in dirs:
		var nxt: Vector2i = last + d
		if not Sim.can_extend(L, route, nxt, st):
			continue
		var st2 := Sim.copy_state(st)
		Sim.arrive(L, st2, nxt)
		route.append(nxt)
		if Sim.all_delivered(L, st2):
			return true
		if not Metrics.hopeless(L, route, st2) and _cw_dfs(L, route, st2, cap):
			return true
		route.pop_back()
	return false


## Carries a drive on for up to `more` steps (so buildings can be passed again).
func _extend(L: LevelData, route: Array, more: int) -> void:
	var st := Sim.run(L, route)
	for k in more:
		var opts := []
		for d in LevelData.DIRS:
			if Sim.can_extend(L, route, route.back() + d, st):
				opts.append(route.back() + d)
		if opts.is_empty():
			return
		var nxt: Vector2i = opts.pick_random()
		Sim.arrive(L, st, nxt)
		route.append(nxt)


## The shortest legal way from the end of `route` back onto the start tile. [] if there's none.
func _way_home(L: LevelData, route: Array, st: Dictionary) -> Array:
	var queue := [route.duplicate()]
	var seen := {route.back(): true}
	var qi := 0
	while qi < queue.size() and qi < 400:
		var r: Array = queue[qi]
		qi += 1
		for d in LevelData.DIRS:
			var nxt: Vector2i = r.back() + d
			if not Sim.can_extend(L, r, nxt, st):
				continue
			if nxt == L.start:
				var out: Array = r.slice(route.size())
				out.append(nxt)
				return out
			if seen.has(nxt):
				continue
			seen[nxt] = true
			var r2: Array = r.duplicate()
			r2.append(nxt)
			queue.append(r2)
	return []


# ------------------------------------------------------------------ one candidate

## One town; a couple of drives through it; a few loads for each. The first that fits the slot is returned.
func _attempt():
	var T = _town()
	if T == null:
		return null
	for w in int(S.get("walks", 2)):
		var walk = _drive(T)
		if walk == null:
			continue
		for k in int(S.get("loads", 3)):
			var D = _load(T, walk)
			if D == null:
				continue
			var c = _finish(D)
			if c != null:
				return c
	return null


## Steps 1-3: streets, fixtures and buildings.
func _town():
	var m := _make_map()
	if m.is_empty():
		return _rej("map")
	var road: Dictionary = m["road"]
	var doors: Dictionary = m["doors"]
	var zone: Dictionary = m["zone"]
	var ret: bool = S.get("ret", false)
	# The depot: on a quiet street (in the first district).
	var tiles: Array = road.keys()
	tiles.shuffle()
	var start := Vector2i(-1, -1)
	for want_deg in [2, 3, 4]:
		for p in tiles:
			if doors.has(p) or int(zone.get(p, 0)) != 0:
				continue
			var dg := _deg(road, p)
			if dg <= want_deg and dg >= (2 if ret else 1):
				start = p
				break
		if start.x >= 0:
			break
	if start.x < 0:
		return _rej("no depot")
	var bridges := {}
	var ice := {}
	var arrows := {}
	var nb := _pick("bridge", [0, 0])
	for p in tiles:
		if bridges.size() >= nb:
			break
		if p != start and not doors.has(p) and _deg(road, p) == 4:
			var near := false
			for d in LevelData.DIRS:
				if bridges.has(p + d) or p + d == start:
					near = true
			if not near:
				bridges[p] = true
	if bridges.size() < int((S.get("bridge", [0, 0]) as Array)[0]):
		return _rej("no crossroads for a bridge")
	var pre_ice := (_pick("ice", [0, 0]) + 1) / 2
	for p in tiles:
		if ice.size() >= pre_ice:
			break
		if p == start or doors.has(p) or bridges.has(p) or _deg(road, p) < 3:
			continue
		if (road.has(p + Vector2i(1, 0)) and road.has(p - Vector2i(1, 0))) or (road.has(p + Vector2i(0, 1)) and road.has(p - Vector2i(0, 1))):
			ice[p] = true
	var pre_arrows := (_pick("oneway", [0, 0]) + 1) / 2
	for p in tiles:
		if arrows.size() >= pre_arrows:
			break
		if p == start or doors.has(p) or bridges.has(p) or ice.has(p):
			continue
		var ds: Array = LevelData.DIRS.duplicate()
		ds.shuffle()
		for d in ds:
			if road.has(p + d) and road.has(p - d):
				arrows[p] = d
				break
	# Buildings.
	var forbidden := {}
	for d in LevelData.DIRS:
		forbidden[start + d] = true
		for b in bridges:
			forbidden[b + d] = true
	var n_house := _pick("houses", [3, 4])
	var n_lock := _pick("lockers", [0, 0])
	var n_shop := _pick("shops", [0, 0])
	var bias := float(S.get("two_door", 1.5))
	var cells := []
	var weights := []
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			if road.has(p) or forbidden.has(p):
				continue
			var adj := _deg(road, p)
			if adj == 0:
				continue
			cells.append(p)
			weights.append(1.0 + bias * (adj - 1))
	var total_b := n_house + n_lock + n_shop
	var chosen := []
	for k in total_b:
		var sum := 0.0
		for wv in weights:
			sum += float(wv)
		if sum <= 0.0:
			break
		var pickv := randf() * sum
		for ci in cells.size():
			pickv -= float(weights[ci])
			if pickv <= 0.0:
				chosen.append(cells[ci])
				cells.remove_at(ci)
				weights.remove_at(ci)
				break
	if chosen.size() < total_b:
		return _rej("no room for the buildings")
	if int(m["districts"]) > 1:
		var zones_hit := {}
		for c in chosen:
			for d in LevelData.DIRS:
				if road.has(c + d) and not doors.has(c + d):
					zones_hit[zone[c + d]] = true
		if zones_hit.size() < int(m["districts"]):
			return _rej("a district with nothing in it")
	chosen.shuffle()
	var T := {"road": road, "doors": doors, "start": start, "bridges": bridges, "ice": ice, "arrows": arrows, "ret": ret,
		"house_cells": chosen.slice(0, n_house), "lock_cells": chosen.slice(n_house, n_house + n_lock),
		"shop_cells": chosen.slice(n_house + n_lock), "all_cells": chosen}
	# Route choice is a property of the town: check it before spending anything on drives and loads.
	var P := _blank(T)
	for c in chosen:
		P["lockers"][c] = {"order": 1}
		P["stack"].append("r")
	P["ret"] = ret
	var fc := Metrics.free_choice(_dict(P), Metrics.FREE_CAP, int(S.get("nodes_max", 3000)) * 6)
	if int(fc["orders"]) < int(S.get("free_min", 3)):
		return _rej("town: too little route choice")
	if int(fc["orders"]) > int(S.get("free_max", 9999)):
		return _rej("town: too much route choice")
	return T


func _blank(T: Dictionary) -> Dictionary:
	return {"road": T["road"], "start": T["start"], "bridges": T["bridges"], "hubs": {}, "ice": (T["ice"] as Dictionary).duplicate(),
		"arrows": (T["arrows"] as Dictionary).duplicate(), "gates": {}, "works": {}, "houses": {}, "lockers": {}, "shops": {}, "stack": [],
		"ret": false, "route": [], "doors": T["doors"]}


## Step 4: a drive past every building, on the town with each of them a locker.
func _drive(T: Dictionary):
	var D := _blank(T)
	for c in T["all_cells"]:
		D["lockers"][c] = {"order": 1}
		D["stack"].append("r")
	D["ret"] = T["ret"]      # so the drive keeps a way home open
	var PL := LevelData.from_dict(_dict(D), 0)
	if not PL.errors.is_empty():
		return _rej("provisional: " + str(PL.errors[0]).substr(0, 30))
	var walk := _cover_walk(PL, 500 + 20 * (T["road"] as Dictionary).size())
	if walk.is_empty():
		return _rej("no drive covers it")
	_extend(PL, walk, _pick("ext", [0, 4]))
	return walk


## Step 5: the load, backwards from the drive.
func _load(T: Dictionary, walk: Array):
	var road: Dictionary = T["road"]
	# Who is what: pickups among the buildings the drive reaches early (something must come after them).
	var by_first: Array = (T["all_cells"] as Array).duplicate()
	var first_at := {}
	for c in by_first:
		var ps0 := _passes(walk, road, c)
		if ps0.is_empty():
			return _rej("a building the drive never passes")
		first_at[c] = ps0[0]
	by_first.sort_custom(func(a, b): return int(first_at[a]) < int(first_at[b]))
	var n_shop: int = (T["shop_cells"] as Array).size()
	var n_lock: int = (T["lock_cells"] as Array).size()
	var early: Array = by_first.slice(0, maxi(n_shop, int(ceil(by_first.size() * 0.6))))
	early.shuffle()
	var shop_cells: Array = early.slice(0, n_shop)
	var rest: Array = by_first.filter(func(c): return not shop_cells.has(c))
	rest.shuffle()
	var lock_cells: Array = rest.slice(0, n_lock)
	var house_cells: Array = rest.slice(n_lock)
	var cols: Array = COLORS.slice(0, int(S.get("colors", 3)))
	cols.shuffle()
	var houses := {}
	var hi := 0
	var order_cells: Array = house_cells.duplicate()
	order_cells.shuffle()
	for c in order_cells:
		houses[c] = {"color": cols[hi % cols.size()], "order": 1}
		hi += 1
	var max_order := int(S.get("max_order", 3))
	for k in _pick("multi", [0, 0]):
		var c: Vector2i = house_cells.pick_random()
		if int(houses[c]["order"]) < max_order:
			houses[c]["order"] = int(houses[c]["order"]) + 1
	var late := float(S.get("late", 0.25))
	var events := {}
	var last_idx := 0
	for c in house_cells:
		var ps := _passes(walk, road, c)
		if ps.is_empty():
			return _rej("a building the drive never passes")
		# All of a house's packages usually arrive together; sometimes one comes on a later pass.
		var at: int = ps[0]
		if ps.size() > 1 and randf() < late:
			at = ps[randi_range(1, ps.size() - 1)]
		for u in int(houses[c]["order"]):
			var at_u := at
			if u > 0 and ps.size() > 1 and randf() < 0.25:
				at_u = ps.pick_random()
			_ev(events, at_u, {"t": 0, "cell": c})
			last_idx = maxi(last_idx, at_u)
	var lockers := {}
	for c in lock_cells:
		var ps := _passes(walk, road, c)
		if ps.is_empty():
			return _rej("a building the drive never passes")
		lockers[c] = {"order": 1}
		# A locker's package: usually a colour some house wants too (so which one goes in the locker?).
		var lc: String = houses[house_cells.pick_random()]["color"] if randf() < 0.65 else cols.pick_random()
		_ev(events, ps[0], {"t": 1, "cell": c, "c": lc})
		last_idx = maxi(last_idx, ps[0])
	var stock := int(S.get("stock", 1))
	for c in shop_cells:
		var ps := _passes(walk, road, c)
		if ps.is_empty():
			return _rej("a building the drive never passes")
		_ev(events, ps[0], {"t": 2, "cell": c, "n": randi_range(1, stock)})
	for i in range(last_idx + 1, walk.size()):
		if events.has(i):
			return _rej("a pickup after the last delivery")
	var core: Array = walk.slice(0, last_idx + 1)
	# Hubs: on the drive, away from buildings.
	var hubs := {}
	var n_hub := _pick("hub", [0, 0])
	if n_hub > 0:
		var idxs := range(2, core.size() - 1)
		idxs.shuffle()
		for i in idxs:
			if hubs.size() >= n_hub:
				break
			var p: Vector2i = core[i]
			if core.count(p) != 1 or T["bridges"].has(p) or T["ice"].has(p) or T["arrows"].has(p) or T["doors"].has(p):
				continue
			var clear := true
			for d in LevelData.DIRS:
				if T["all_cells"].has(p + d) or hubs.has(p + d):
					clear = false
			if clear:
				hubs[p] = true
		if hubs.size() < int((S.get("hub", [0, 0]) as Array)[0]):
			return _rej("nowhere for a hub")
	var D := _blank(T)
	D["hubs"] = hubs
	D["houses"] = houses
	D["lockers"] = lockers
	D["events"] = events
	D["core"] = core
	D["shop_cells"] = shop_cells
	D["house_cells"] = house_cells
	D["cols"] = cols
	if not _restack(D):
		return _rej("the load doesn't work out")
	D["route"] = core
	D["ret"] = T["ret"]
	var L := LevelData.from_dict(_dict(D), 0)
	if not L.errors.is_empty():
		return _rej("level: " + str(L.errors[0]).substr(0, 28))
	D["home"] = []
	if T["ret"]:
		var fin0 := Sim.run_checked(L, core)
		if fin0.is_empty() or not Sim.all_delivered(L, fin0):
			return _rej("the drive doesn't deliver")
		var home := _way_home(L, core, fin0)
		if home.is_empty():
			return _rej("no way home")
		D["home"] = home
		D["route"] = core + home
	L = _valid(D)
	if L == null:
		return _rej("the drive doesn't win")
	if Sim.max_load(L, D["route"]) > LevelData.MAX_LOAD:
		return _rej("too many aboard")
	if L.total_orders() < int(S.get("minpkg", 0)):
		return _rej("too few packages")
	return D


## Works the starting stack (and what each pickup holds) out backwards from the drive's events.
func _restack(D: Dictionary) -> bool:
	var core: Array = D["core"]
	var events: Dictionary = D["events"]
	var houses: Dictionary = D["houses"]
	var hubs: Dictionary = D["hubs"]
	var shops := {}
	var stack := []
	for i in range(core.size() - 1, 0, -1):
		var evs: Array = events.get(i, [])
		evs.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]))
		for j in range(evs.size() - 1, -1, -1):
			var e: Dictionary = evs[j]
			match int(e["t"]):
				0:
					stack.append(houses[e["cell"]]["color"])
				1:
					stack.append(e["c"])
				2:
					if stack.is_empty():
						return false
					var col: String = stack.back()
					var cnt := 0
					while cnt < int(e["n"]) and not stack.is_empty() and stack.back() == col:
						stack.pop_back()
						cnt += 1
					shops[e["cell"]] = {"color": col, "count": cnt}
		if hubs.has(core[i]) and stack.size() >= 2:
			var top = stack[stack.size() - 1]
			stack[stack.size() - 1] = stack[stack.size() - 2]
			stack[stack.size() - 2] = top
	if stack.size() > LevelData.MAX_LOAD or stack.is_empty():
		return false
	if shops.size() < (D["shop_cells"] as Array).size():
		return false
	D["shops"] = shops
	D["stack"] = stack
	return true


## How many winning routes and plans the design has. {"ok": false} if its own drive no longer wins.
func _plans(D: Dictionary) -> Dictionary:
	var L := _valid(D)
	if L == null:
		return {"ok": false}
	var routes_max := int(S.get("routes_max", 50))
	var r := Metrics.solve_all(L, routes_max + 1, int(S.get("nodes_max", 3000)) * 3)
	if bool(r["capped"]):
		return {"ok": true, "plans": 999, "routes": 999}
	return {"ok": true, "plans": Metrics.plan_count(L, r["routes"]), "routes": int(r["count"])}


func _worse(a: Dictionary, b: Dictionary) -> bool:
	# Is a worse than b? Fewer plans first, then fewer routes.
	if int(a["plans"]) != int(b["plans"]):
		return int(a["plans"]) > int(b["plans"])
	return int(a["routes"]) > int(b["routes"])


## Steps 6-8.
func _finish(D: Dictionary):
	var pl: Array = S.get("plans", [1, 2])
	var pmin := int(pl[0])
	var pmax := int(pl[1])
	var cur := _plans(D)
	if not cur["ok"]:
		return _rej("the drive doesn't win")
	# Too many plans: repaint houses (the roads stay as open as they were).
	var house_cells: Array = D["house_cells"]
	var cols: Array = D["cols"]
	var moves := 0
	while int(cur["plans"]) > pmax and moves < int(S.get("repaints", 12)) and house_cells.size() >= 2:
		moves += 1
		var a: Vector2i = house_cells.pick_random()
		var b: Vector2i = house_cells.pick_random()
		var old_a: String = D["houses"][a]["color"]
		var old_b: String = D["houses"][b]["color"]
		if randf() < 0.5 or a == b:
			D["houses"][a]["color"] = cols.pick_random()
		else:
			D["houses"][a]["color"] = old_b
			D["houses"][b]["color"] = old_a
		var ok := _restack(D)
		var trial := _plans(D) if ok else {"ok": false}
		if ok and trial["ok"] and _worse(cur, trial):
			cur = trial
		else:
			D["houses"][a]["color"] = old_a
			D["houses"][b]["color"] = old_b
			_restack(D)
	# Doors that depend on the load.
	_add_doors(D)
	var after := _plans(D)
	if not after["ok"]:
		return _rej("doors broke the drive")
	cur = after
	if D["gates"].size() < int((S.get("gate", [0, 0]) as Array)[0]):
		return _rej("nowhere for a gate")
	if D["works"].size() < int((S.get("works", [0, 0]) as Array)[0]):
		return _rej("nowhere for roadworks")
	# Still too many: an allowed road mechanic where it removes some.
	var rounds := 0
	while (int(cur["plans"]) > pmax or int(cur["routes"]) > int(S.get("routes_max", 50))) and rounds < 6:
		rounds += 1
		var better := _narrow(D, cur, pmin, "")
		if better.is_empty():
			break
		cur = better
	if int(cur["routes"]) > int(S.get("routes_max", 50)):
		return _rej("too many routes")
	if int(cur["plans"]) > pmax:
		return _rej("too many plans")
	if int(cur["plans"]) < pmin:
		return _rej("too few plans")
	_prune_idle(D)
	# A mechanic the slot is about must be there and matter: put one where it changes the answer.
	for fam in S.get("need", []):
		var key: String = {"oneway": "arrows", "ice": "ice", "gate": "gates", "works": "works"}.get(fam, "")
		if key != "" and D[key].is_empty() and not (str(S.get("flavor", "")) == "districts" and (fam == "works" or fam == "gate")):
			var got := _narrow(D, cur, pmin, key)
			if got.is_empty():
				return _rej("nowhere " + str(fam) + " matters")
			cur = got
	_decorate(D)
	if _valid(D) == null:
		return _rej("pruning broke it")
	for fam in ["oneway", "ice", "gate", "works", "bridge", "hub"]:
		var lo := int((S.get(fam, [0, 0]) as Array)[0])
		var have: int = {"oneway": D["arrows"].size(), "ice": D["ice"].size(), "gate": D["gates"].size(), "works": D["works"].size(),
			"bridge": D["bridges"].size(), "hub": D["hubs"].size()}[fam]
		if have < lo:
			return _rej("lost its " + fam)
	return _judge(_dict(D), false)


func _passes(walk: Array, road: Dictionary, cell: Vector2i) -> Array:
	var out := []
	for i in range(1, walk.size()):
		var p: Vector2i = walk[i]
		if absi(p.x - cell.x) + absi(p.y - cell.y) == 1 and road.has(p):
			out.append(i)
	return out


func _ev(events: Dictionary, at: int, e: Dictionary) -> void:
	if not events.has(at):
		events[at] = []
	events[at].append(e)


## What the van has on top, and how many it has delivered, just before each tile of the drive.
func _before(L: LevelData, route: Array) -> Array:
	var out := [["", 0]]
	var st := Sim.new_state(L)
	for i in range(1, route.size()):
		out.append([Sim.top_color(L, st), Sim.delivered_count(st)])
		Sim.arrive(L, st, route[i])
	return out


func _code(colour: String) -> String:
	for k in NAMES:
		if NAMES[k] == colour:
			return k
	return colour


func _plain(D: Dictionary, p: Vector2i) -> bool:
	return p != D["start"] and not D["bridges"].has(p) and not D["hubs"].has(p) and not D["ice"].has(p) and not D["arrows"].has(p) \
		and not D["gates"].has(p) and not D["works"].has(p)


## Where on the drive a gate or roadworks could go: [index, tile] for tiles it drives straight through.
func _straight_spots(D: Dictionary) -> Array:
	var route: Array = D["route"]
	var out := []
	for i in range(2, route.size() - 1):
		var p: Vector2i = route[i]
		if not _plain(D, p) or route.count(p) != 1:
			continue
		if route[i] - route[i - 1] == route[i + 1] - route[i]:
			out.append([i, p])
	return out


func _add_doors(D: Dictionary) -> void:
	var L := LevelData.from_dict(_dict(D), 0)
	var route: Array = D["route"]
	var bf := _before(L, route)
	var first_top: String = bf[1][0] if bf.size() > 1 else ""
	var n_gate := _pick("gate", [0, 0])
	var n_work := _pick("works", [0, 0])
	var spots := _straight_spots(D)
	spots.shuffle()
	# Doors between districts come first: that's what they're for.
	spots.sort_custom(func(a, b): return int(D["doors"].has(a[1])) > int(D["doors"].has(b[1])))
	for sp in spots:
		var i: int = sp[0]
		var p: Vector2i = sp[1]
		var top: String = bf[i][0]
		var done: int = bf[i][1]
		var want_gate: bool = D["gates"].size() < n_gate and top != "" and (top != first_top or randf() < 0.3)
		var want_work: bool = D["works"].size() < n_work and done >= 1
		if want_gate and (not want_work or randf() < 0.5):
			D["gates"][p] = _code(top)
		elif want_work:
			D["works"][p] = maxi(1, done - (1 if randf() < 0.3 else 0))


## Tries road mechanics the slot allows (or just `only`: "arrows", "ice", "gates" or "works"), one at a
## time, and keeps the one that leaves the fewest plans (then routes) while changing the answer. Returns the
## new counts, or {} if nothing helped.
func _narrow(D: Dictionary, cur: Dictionary, pmin: int, only: String) -> Dictionary:
	var route: Array = D["route"]
	var road: Dictionary = D["road"]
	var can_arrow: bool = D["arrows"].size() < int((S.get("oneway", [0, 0]) as Array)[1]) and (only == "" or only == "arrows")
	var can_ice: bool = D["ice"].size() < int((S.get("ice", [0, 0]) as Array)[1]) and (only == "" or only == "ice")
	var can_gate: bool = D["gates"].size() < int((S.get("gate", [0, 0]) as Array)[1]) and (only == "" or only == "gates")
	var can_work: bool = D["works"].size() < int((S.get("works", [0, 0]) as Array)[1]) and (only == "" or only == "works")
	if not (can_arrow or can_ice or can_gate or can_work):
		return {}
	var L := LevelData.from_dict(_dict(D), 0)
	var bf := _before(L, route)
	var trials := []
	var tiles: Array = road.keys()
	tiles.shuffle()
	for p in tiles:
		if trials.size() >= 16:
			break
		if not _plain(D, p):
			continue
		var i := route.find(p)
		if i == 0:
			continue
		var on_route: bool = i > 0 and route.count(p) == 1 and i < route.size() - 1
		if i > 0 and not on_route:
			continue
		var straight: bool = on_route and route[i] - route[i - 1] == route[i + 1] - route[i]
		var kinds := []
		if can_arrow:
			kinds.append("arrow")
		if can_ice and _deg(road, p) >= 3 and (straight or i < 0):
			kinds.append("ice")
		if can_gate and straight and str(bf[i][0]) != "" and _deg(road, p) == 2:
			kinds.append("gate")
		if can_work and straight and int(bf[i][1]) >= 1:
			kinds.append("works")
		if kinds.is_empty():
			continue
		var kind: String = kinds.pick_random()
		match kind:
			"arrow":
				var d: Vector2i
				if on_route:
					d = route[i + 1] - route[i]
				else:
					d = LevelData.DIRS.pick_random()
				if road.has(p + d) and road.has(p - d):
					trials.append(["arrows", p, d])
			"ice":
				if (road.has(p + Vector2i(1, 0)) and road.has(p - Vector2i(1, 0))) or (road.has(p + Vector2i(0, 1)) and road.has(p - Vector2i(0, 1))):
					trials.append(["ice", p, true])
			"gate":
				trials.append(["gates", p, _code(str(bf[i][0]))])
			"works":
				trials.append(["works", p, int(bf[i][1])])
	var best := {}
	var best_t := []
	for t in trials:
		D[t[0]][t[1]] = t[2]
		var got := _plans(D)
		D[t[0]].erase(t[1])
		if not got["ok"] or int(got["plans"]) < maxi(pmin, 1) or int(got["plans"]) >= 999:
			continue
		# It has to change something: fewer plans or routes than now.
		if not _worse(cur, got):
			continue
		if best.is_empty() or _worse(best, got):
			best = got
			best_t = t
	if best_t.is_empty():
		return {}
	D[best_t[0]][best_t[1]] = best_t[2]
	return best


## Takes away every ice, arrow, gate and roadworks tile that changes nothing (now and then one is left in
## as a red herring: `decor` is the chance).
func _prune_idle(D: Dictionary) -> void:
	var L := _valid(D)
	if L == null:
		return
	var nodes_max := int(S.get("nodes_max", 3000))
	var base := Metrics.solve_all(L, 80, nodes_max * 3)
	var keys := {}
	for rt in base["routes"]:
		keys[Metrics._route_key(rt)] = true
	var decor := float(S.get("decor", 0.12))
	for fam in ["arrows", "ice", "gates", "works"]:
		for p in D[fam].keys():
			if D["doors"].has(p):
				continue      # a door between districts stays, as a guide
			var saved = D[fam][p]
			D[fam].erase(p)
			if Metrics._differs(_dict(D), keys, nodes_max * 3) or randf() < decor:
				D[fam][p] = saved


## A themed level: a few extra tiles of the zone's own mechanic that change nothing, just for the mood
## (ice all over a winter town). "theme": "ice", "theme_n": how many.
func _decorate(D: Dictionary) -> void:
	var kind := str(S.get("theme", ""))
	var n := int(S.get("theme_n", 0))
	if kind != "ice" or n <= 0:
		return
	var L := _valid(D)
	if L == null:
		return
	var nodes_max := int(S.get("nodes_max", 3000))
	var keys := {}
	for rt in Metrics.solve_all(L, 80, nodes_max * 3)["routes"]:
		keys[Metrics._route_key(rt)] = true
	var road: Dictionary = D["road"]
	var tiles: Array = road.keys()
	tiles.shuffle()
	var added := 0
	for p in tiles:
		if added >= n:
			break
		if not _plain(D, p) or D["doors"].has(p):
			continue
		if not ((road.has(p + Vector2i(1, 0)) and road.has(p - Vector2i(1, 0))) or (road.has(p + Vector2i(0, 1)) and road.has(p - Vector2i(0, 1)))):
			continue
		D["ice"][p] = true
		if _valid(D) != null and not Metrics._differs(_dict(D), keys, nodes_max * 3):
			added += 1
		else:
			D["ice"].erase(p)


# ------------------------------------------------------------------ 8. judging

func _score_current(slot: int) -> void:
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))["levels"]
	if slot > raw.size():
		return
	var d: Dictionary = raw[slot - 1].duplicate(true)
	var c = _judge(d, true)
	if c != null:
		found.append(c)
	elif verbose:
		print("# current level rejected: ", rejects)


## Scores a level against the slot. null (with a reason counted) if it doesn't fit.
func _judge(d: Dictionary, kept: bool):
	var why := "current: " if kept else ""
	var L := LevelData.from_dict(d, 0)
	if not L.errors.is_empty():
		return _rej(why + "errors")
	var pl: Array = S.get("plans", [1, 2])
	var nodes_max := int(S.get("nodes_max", 3000))
	var routes_max := int(S.get("routes_max", 50))
	var pre := Solver.solve(L, routes_max + 1, nodes_max)
	if int(pre["count"]) < 1:
		return _rej(why + "unsolved in budget")
	if bool(pre["capped"]):
		return _rej(why + ("too many routes" if int(pre["count"]) > routes_max else "over the solver budget"))
	var fc := Metrics.free_choice(d, Metrics.FREE_CAP, nodes_max * 6)
	var fo: int = fc["orders"]
	if fo < int(S.get("free_min", 3)):
		return _rej(why + "too little route choice")
	if fo > int(S.get("free_max", 9999)):
		return _rej(why + "too much route choice")
	var m := Metrics.measure(d, 0, {"nodes": nodes_max * 3, "free": false})
	if not m["ok"]:
		return _rej(why + "measure failed")
	m["free"] = fc["routes"]
	m["free_orders"] = fo
	Metrics._scores(m)
	if int(m["plans"]) > int(pl[1]):
		return _rej(why + "too many plans")
	if int(m["plans"]) < int(pl[0]):
		return _rej(why + "too few plans")
	if int(m["max_load"]) > LevelData.MAX_LOAD:
		return _rej(why + "too many aboard")
	if int(m["len"]) < int(S.get("len_min", 0)):
		return _rej(why + "too short a drive")
	if float(m["cover"]) < float(S.get("cover_min", 0.0)):
		return _rej(why + "leaves most of the town unused")
	# Mechanics the slot is about must change the answer; idle tiles stay a small minority.
	var fl0 := str(S.get("flavor", ""))
	for fam in S.get("need", []):
		# Doors between districts may only be guides ("finish this side first"): they needn't change the answer.
		var guide: bool = fl0 == "districts" and (fam == "works" or fam == "gate")
		if (m["matters"] as Dictionary).has(fam) and not m["matters"][fam] and not guide:
			return _rej(why + str(fam) + " is decoration")
		if fam in ["oneway", "ice", "gate", "works", "hub", "bridge"] and not (m["matters"] as Dictionary).has(fam):
			return _rej(why + "no " + str(fam))
		if fam == "locker" and int(m["locker_drops"]) < 1:
			return _rej(why + "no locker")
		if (fam == "pickup" or fam == "warehouse") and int(m["pickups"]) < 1:
			return _rej(why + "no pickup")
	var idle_ok := maxi(1, int(m["mech_tiles"]) / 3) + int(S.get("theme_n", 0)) + (2 if fl0 == "districts" else 0)
	if int(m["mech_tiles"]) > 0 and int(m["idle"]) > idle_ok:
		return _rej(why + "too much decoration")
	var intro := str(S.get("intro", ""))
	if intro != "" and not _intro_ok(d, L, m, intro):
		return _rej(why + "fails the intro rule")
	var fl := str(S.get("flavor", ""))
	var fwhy := _flavor_miss(fl, m)
	if fwhy != "":
		return _rej(why + fl + ": " + fwhy)
	# A present or a key: somewhere worth going that the plain route doesn't.
	if S.has("gift"):
		var at := _gift_spot(d, L, m)
		if at.x < 0:
			return _rej(why + "nowhere for the present")
		d["gift"] = {"at": [at.x, at.y], "item": S["gift"]}
	var band: Array = S.get("diff", [0, 10])
	var dv: float = m["difficulty"]
	var off := 0.0
	if dv < float(band[0]):
		off = float(band[0]) - dv
	elif dv > float(band[1]):
		off = dv - float(band[1])
	if off > float(S.get("diff_slack", 1.2)):
		return _rej(why + ("too easy" if dv < float(band[0]) else "too hard"))
	var prof: Dictionary = m["profile"]
	var bonus := 0.0
	match fl:
		"knot", "longcon":
			bonus = 2.0 * float(prof["foresight"])
		"decoy", "twodoor":
			bonus = 2.0 * float(prof["lateral"])
		"fork":
			bonus = 1.5 * float(prof["trick"])
		"sorter", "dump", "restock", "hoard":
			bonus = 2.0 * float(prof["juggling"])
		"freerun", "twin":
			bonus = 2.0 * float((m["fun_parts"] as Dictionary)["choice"])
		"districts":
			bonus = 1.0 * float(prof["foresight"]) + 1.0 * float(prof["search"])
	# A zone's other mechanics are optional; a level that makes them matter is a better fit for its zone.
	var mattering := 0
	for fam in m["matters"]:
		if m["matters"][fam]:
			mattering += 1
	var fit := 10.0 - 2.5 * off + 0.8 * float(m["fun"]) + bonus + 0.6 * float(m["cover"]) + 0.35 * mattering
	d["flavor"] = fl
	var mm := m.duplicate()
	mm.erase("route")
	mm.erase("shortest")
	return {"slot": int(S["n"]), "fit": snappedf(fit, 0.01), "kept": kept, "band": band, "dict": d, "m": mm}


## "" if the level has the flavour's signature, else what's missing.
func _flavor_miss(fl: String, m: Dictionary) -> String:
	var dec: int = m["decisions"]
	match fl:
		"fork":
			if dec < 1 or dec > 4:
				return "wants 1-4 real choices"
		"freerun":
			if float(m["bits"]) > float(S.get("bits_max", 3.0)):
				return "too surprising for a free run"
		"decoy":
			if int(m["anti"]) < 1 or int(m["first_anti"]) > 2 or float(m["greedy"]) > 0.7:
				return "the obvious start works"
		"sorter":
			if int(m["swaps"]) + int(m["pickups"]) < 1:
				return "no sorting"
			if int(m["anti"]) < 1 and float(m["trick"]) < 2.0:
				return "sorts itself"
		"twodoor":
			if int(m["late_drops"]) < int(S.get("late_min", 2)):
				return "no house is passed and come back to"
		"dump":
			if int(m["dumps"]) < 1:
				return "the locker takes nothing a house wanted"
		"restock":
			if int(m["pickups"]) < 1:
				return "no pickup"
			if int(m["pickup_anti"]) < 1:
				return "the pickup is on the way"
		"knot":
			if float(m["cover"]) < 0.72:
				return "leaves too much road"
			if float(m["late"]) < 2.0:
				return "mistakes show at once"
		"longcon":
			if int(m["early_doom"]) < int(S.get("doom_min", 7)):
				return "no early choice with late consequences"
		"twin":
			if float(m["overlap"]) > float(S.get("overlap_max", 0.7)):
				return "the two answers are nearly the same"
		"hoard":
			if int(m["max_load"]) < int(S.get("load_min", 8)):
				return "the van never fills"
		"districts":
			if int(m["gate_passes"]) + int(m["works_passes"]) + int(m["bridge_double"]) + int(m["oneway_used"]) < 1:
				return "no door is used"
	return ""


## The mechanic-intro rule: the level uses the new mechanic, and what you'd do without it doesn't work.
func _intro_ok(d: Dictionary, L: LevelData, m: Dictionary, intro: String) -> bool:
	var used := true
	match intro:
		"multi":
			used = L.houses.any(func(h): return h.order > 1 and h.color != "any")
		"oneway":
			used = int(m["oneway_used"]) >= 1
		"bridge":
			used = int(m["bridge_double"]) >= 1
		"pickup":
			used = int(m["pickups"]) >= 1 and int(m["pickup_anti"]) + int(m["anti"]) >= 1
		"gate":
			used = int(m["gate_passes"]) >= 1
		"return":
			used = L.return_depot
		"hub":
			used = int(m["swaps"]) >= 1
		"ice":
			used = int(m["ice_slides"]) >= 1
		"locker":
			used = int(m["locker_drops"]) >= 1
		"works":
			used = int(m["works_passes"]) >= 1
	if not used:
		return false
	var fam: String = {"oneway": "oneway", "bridge": "bridge", "gate": "gate", "hub": "hub", "ice": "ice", "works": "works"}.get(intro, "")
	var d2 := {}
	if fam != "":
		if not (m["matters"] as Dictionary).get(fam, false):
			return false
		d2 = Metrics.stripped(d, fam)
	elif intro == "return":
		d2 = d.duplicate(true)
		d2.erase("return")
	if d2.is_empty():
		return true
	# The plain version's natural answer must not win the real level.
	var m2 := Metrics.measure(d2, 0, {"nodes": int(S.get("nodes_max", 3000)) * 3, "deep": false, "ablate": false, "free": false})
	if not m2["ok"]:
		return true      # without it there's no way at all: it certainly matters
	var natural: Array = m2["route"]
	if intro == "return":
		# Without having to come home you'd finish somewhere you can't get back from.
		var fin := Sim.run_checked(L, natural)
		if fin.is_empty():
			return true
		return _way_home(L, natural, fin).is_empty()
	var fin2 := Sim.run_checked(L, natural)
	return fin2.is_empty() or not Sim.is_won(L, fin2, natural)


## A road tile for the present: on another winning route (not the plain one), else just past the finish.
func _gift_spot(d: Dictionary, L: LevelData, m: Dictionary) -> Vector2i:
	var plain: Array = m["shortest"]
	var on_plain := {}
	for p in plain:
		on_plain[p] = true
	var routes: Array = Metrics.solve_all(L, 40, int(S.get("nodes_max", 3000)) * 3)["routes"]
	var spots := []
	for k in range(routes.size() - 1, 0, -1):
		for p in routes[k]:
			if not on_plain.has(p) and p != L.start and not spots.has(p):
				spots.append(p)
		if not spots.is_empty():
			break
	if spots.is_empty() and not L.return_depot:
		# The extra mile: a few tiles on from where the plain route ends.
		var st := Sim.run(L, plain)
		var frontier := [plain.duplicate()]
		for depth in 4:
			var nxt_frontier := []
			for r in frontier:
				for dd in LevelData.DIRS:
					var n: Vector2i = (r.back() as Vector2i) + dd
					if Sim.can_extend(L, r, n, st):
						var r2: Array = r.duplicate()
						r2.append(n)
						nxt_frontier.append(r2)
						if depth >= 1 and not on_plain.has(n) and not spots.has(n):
							spots.append(n)
			frontier = nxt_frontier
	for p in spots:
		var d2: Dictionary = d.duplicate(true)
		d2["gift"] = {"at": [p.x, p.y], "item": S["gift"]}
		var L2 := LevelData.from_dict(d2, 0)
		if L2.errors.is_empty() and not Solver.gift_route(L2).is_empty() and not (Solver.solve(L2)["shortest"] as Array).has(p):
			return p
	return Vector2i(-1, -1)
