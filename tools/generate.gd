extends SceneTree
## Procedural level generator (design aid). Prints the best candidates as JSON, ready to
## paste into levels/levels.json after a look.
##
##   godot --headless --path . --script res://tools/generate.gd -- \
##       --w=6 --h=8 --n=5 --colors=4 --shops=2 --gates=1 --maxsol=1 --minnodes=150 --tries=3000
##
## How it works (route-first, so every candidate is solvable by construction):
##  1. Street-grid map: a few vertical + horizontal streets, then random street pieces
##     removed (keeping it connected) so there are dead ends, loops and detours.
##  2. A random self-avoiding drive from the depot; with --bridges it may cross its own path
##     straight through a junction (which becomes a bridge); with --ret it then finds a way
##     back to the depot; with --hubs some tiles on it become sorting hubs.
##  3. Houses and shops are placed beside the drive, working BACKWARDS from the end: a
##     delivery means that colour was on top (push it), a shop pickup means the top came from
##     that shop (pop it, shop gets that colour), a hub swap is undone by swapping again.
##     Whatever is left at the start is the van's starting stack.
##  4. Colour gates (--gates) and one-way arrows (--oneway) are added greedily on top, each
##     kept only if it cuts the number of solutions.
##  5. The solver counts every winning route; candidates with more than --maxsol, or whose
##     search is smaller than --minnodes (too few tempting wrong turns), are dropped.
## Candidates are ranked on search size, decision points, "nope" moments and length.
##
## Other flags: --multi=1 require a ×2 house · --needbridge=1 / --needhub=1 the level must be
## unsolvable without its bridges / hubs · --loops=50 % chance to keep extra street pieces ·
## --open=200 how many solutions the map may have before gates/arrows narrow it down.

const COLORS := ["r", "b", "y", "p", "g", "o"]
const ARROW_TOK := {Vector2i(0, -1): "^", Vector2i(1, 0): ">", Vector2i(0, 1): "v", Vector2i(-1, 0): "<"}

var rejects := {}
var o := {"w": 5, "h": 7, "n": 4, "colors": 3, "multi": 0, "oneway": 0, "bridges": 0,
	"shops": 0, "gates": 0, "hubs": 0, "ret": 0, "needbridge": 0, "needhub": 0,
	"maxsol": 3, "minnodes": 0, "tries": 150, "seed": 1, "top": 3, "minlen": 8,
	"nodes": 200000, "loops": 50, "open": 200}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=")
			o[kv[0]] = int(kv[1])
	seed(o.seed)
	var found := []
	var t0 := Time.get_ticks_msec()
	for t in o.tries:
		var c = _candidate()
		if c != null:
			found.append(c)
	found.sort_custom(func(a, b): return a.score > b.score)
	var rk := rejects.keys()
	rk.sort_custom(func(a, b): return rejects[a] > rejects[b])
	print("# rejected: ", ", ".join(rk.slice(0, 6).map(func(k): return "%s ×%d" % [k, rejects[k]])))
	print("# %d/%d candidates kept in %.1fs  (%s)" % [found.size(), o.tries, (Time.get_ticks_msec() - t0) / 1000.0, o])
	for c in found.slice(0, o.top):
		print("# score %.1f · %d solution(s) · shortest %d · %d nodes · %d nope(s) · %d choices" % [
			c.score, c.count, c.len, c.nodes, c.nopes, c.choices])
		for row in c.dict.map:
			print("#   ", row)
		print("#   stack ", c.dict.stack)
		print(JSON.stringify(c.dict))
	quit()


# ------------------------------------------------------------------ map

func _street_lines(n: int) -> Array:
	var xs := []
	var x := randi() % 2
	while x < n:
		xs.append(x)
		x += 2 + (1 if randf() < 0.3 else 0)
	return xs


func _make_map(w: int, h: int) -> Dictionary:
	var xs := _street_lines(w)
	var ys := _street_lines(h)
	if xs.size() < 2 or ys.size() < 2:
		return {}
	var edges := []
	for x in xs:
		for j in ys.size() - 1:
			edges.append([Vector2i(x, ys[j]), Vector2i(x, ys[j + 1])])
	for y in ys:
		for j in xs.size() - 1:
			edges.append([Vector2i(xs[j], y), Vector2i(xs[j + 1], y)])
	edges.shuffle()
	var parent := {}
	for x in xs:
		for y in ys:
			parent[Vector2i(x, y)] = Vector2i(x, y)
	var kept := []
	for e in edges:
		var a := _root(parent, e[0])
		var b := _root(parent, e[1])
		if a != b:
			parent[a] = b
			kept.append(e)
		elif randf() * 100.0 < o.loops:
			kept.append(e)
	var road := {}
	for e in kept:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var p := a
		road[p] = true
		while p != b:
			p += d
			road[p] = true
	return {"w": w, "h": h, "road": road}


func _root(parent: Dictionary, p: Vector2i) -> Vector2i:
	while parent[p] != p:
		p = parent[p]
	return p


func _is_road(m: Dictionary, p: Vector2i) -> bool:
	return m.road.has(p)


func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < o.w and p.y < o.h


func _straight(m: Dictionary, p: Vector2i) -> bool:
	var h := _is_road(m, p + Vector2i(1, 0)) and _is_road(m, p + Vector2i(-1, 0))
	var v := _is_road(m, p + Vector2i(0, 1)) and _is_road(m, p + Vector2i(0, -1))
	var deg := 0
	for d in LevelData.DIRS:
		if _is_road(m, p + d):
			deg += 1
	return deg == 2 and (h or v)


# ------------------------------------------------------------------ candidate

func _candidate():
	var m := _make_map(o.w, o.h)
	if m.is_empty():
		return _rej("m.is_empty()")
	var roads: Array = m.road.keys()
	var start: Vector2i = roads.pick_random()
	for k in 8:
		var deg := 0
		for d in LevelData.DIRS:
			if _is_road(m, start + d):
				deg += 1
		if deg <= 2:
			break
		start = roads.pick_random()

	var walk := _walk(m, start)
	var route: Array = walk.route
	var bridges: Dictionary = walk.bridges
	if o.ret == 1:
		# Cut the drive back to the latest point from which the depot is still reachable.
		var home := []
		var cut := route.size()
		while cut >= 3 and home.is_empty():
			var part := route.slice(0, cut)
			if not bridges.has(part.back()):
				home = _path_home(m, part, bridges, start)
			if home.is_empty():
				cut -= 1
		route = route.slice(0, cut)
		for b in bridges.keys():
			if route.count(b) < 2:
				bridges.erase(b)
		if home.is_empty() or (o.bridges == 1 and bridges.is_empty()):
			return _rej("home.is_empty()")
		route += home
	if route.size() < o.minlen:
		return _rej("route.size() < o.minlen")

	# Sorting hubs on the drive (not near the start or the end).
	var hubs := {}
	for k in o.hubs:
		for t in 10:
			var i := randi_range(2, route.size() - 3)
			var p: Vector2i = route[i]
			if p != start and not bridges.has(p) and not hubs.has(p) and route.count(p) == 1:
				hubs[p] = true
				break
	if hubs.size() < o.hubs:
		return _rej("hubs.size() < o.hubs")

	# Cells that may hold a house or shop.
	var forbidden := {}
	for d in LevelData.DIRS:
		forbidden[start + d] = true
		for b in bridges:
			forbidden[b + d] = true
		for hb in hubs:
			forbidden[hb + d] = true
	var last_i := route.size() - 1 if o.ret == 0 else route.size() - 2
	var spots := []
	for i in range(1, last_i + 1):
		if bridges.has(route[i]) or hubs.has(route[i]) or route[i] == start:
			continue
		if not _free_cells(m, route[i], forbidden, {}).is_empty():
			spots.append(i)
	var events: int = o.n + o.shops
	if spots.size() < events:
		return _rej("spots.size() < events")
	spots.shuffle()
	var slots := spots.slice(0, events)
	slots.sort()
	if o.ret == 0:
		route = route.slice(0, slots.back() + 1)
	var kinds := {}
	var shop_slots := slots.slice(0, slots.size() - 1)
	shop_slots.shuffle()
	for i in slots:
		kinds[i] = "deliver"
	for i in shop_slots.slice(0, o.shops):
		kinds[i] = "pickup"

	# Backwards pass: build the buildings and the starting stack.
	var houses := {}     # Vector2i -> { color, order }
	var shops := {}      # Vector2i -> colour code
	var stack := []
	for i in range(route.size() - 1, 0, -1):
		if kinds.has(i):
			var kind: String = kinds[i]
			if kind == "pickup" and stack.is_empty():
				kind = "deliver"
			var used := {}
			for p in houses:
				used[p] = true
			for p in shops:
				used[p] = true
			var cells := _free_cells(m, route[i], forbidden, used)
			if kind == "pickup":
				if cells.is_empty():
					return _rej("cells.is_empty()")
				var c: Vector2i = cells.pick_random()
				shops[c] = stack.pop_back()
			else:
				var reuse := []
				if o.multi == 1:
					for d in LevelData.DIRS:
						if houses.has(route[i] + d):
							reuse.append(route[i] + d)
				if not reuse.is_empty() and (cells.is_empty() or randf() < 0.4):
					var c: Vector2i = reuse.pick_random()
					houses[c].order += 1
					stack.append(houses[c].color)
				elif not cells.is_empty():
					var c: Vector2i = cells.pick_random()
					var col: String = COLORS[randi() % o.colors]
					houses[c] = {"color": col, "order": 1}
					stack.append(col)
				else:
					return _rej("else")
		if hubs.has(route[i]) and stack.size() >= 2:
			var top = stack[stack.size() - 1]
			stack[stack.size() - 1] = stack[stack.size() - 2]
			stack[stack.size() - 2] = top
	if shops.size() < o.shops:
		return _rej("shops.size() < o.shops")
	if o.multi == 1 and not houses.values().any(func(h): return h.order > 1):
		return _rej("o.multi == 1 and not houses.values().any(func(h)")

	var gates := {}
	var arrows := {}
	var dict := _to_dict(m, start, bridges, hubs, houses, shops, gates, arrows, stack)
	var L := LevelData.from_dict(dict, 0)
	if not L.errors.is_empty():
		return _rej("not L.errors.is_empty()")
	var fin := Sim.run_checked(L, route)
	if fin.is_empty() or not Sim.is_won(L, fin, route):
		return _rej("fin.is_empty() or not Sim.is_won(L, fin, route)")
	# Before gates/arrows the map may be wide open (up to `open` solutions): they are
	# what narrows it down, which leaves lots of tempting-but-wrong roads.
	var r := Solver.solve(L, o.open, o.nodes)
	if r.nodes >= o.nodes:
		return _rej("r.nodes >= o.nodes")
	if o.gates == 0 and o.oneway == 0 and r.count > o.maxsol:
		return _rej("o.gates == 0 and o.oneway == 0 and r.count > o.m")

	# Colour gates on the intended route, coloured to match the top package when the
	# intended route reaches them (and different from the van's starting top, so the
	# player has to rearrange the stack first). A gate is kept if it cuts solutions, or if
	# it guards a chokepoint: the only way to reach some house or shop.
	var first_top := Sim.top_color(L, Sim.new_state(L))
	for k in o.gates:
		var tops := _tops_before(L, route)
		var best_c: int = r.count
		var best := []
		var best_choke := []
		for t in 40:
			var i := randi_range(2, route.size() - 2)
			var p: Vector2i = route[i]
			if p == start or bridges.has(p) or hubs.has(p) or gates.has(p) or not _straight(m, p):
				continue
			if tops[i] == "" or tops[i] == first_top:
				continue
			var trial := gates.duplicate()
			trial[p] = tops[i]
			var L2 := LevelData.from_dict(_to_dict(m, start, bridges, hubs, houses, shops, trial, arrows, stack), 0)
			if not L2.errors.is_empty():
				continue
			var r2 := Solver.solve(L2, best_c, o.nodes)
			if r2.nodes >= o.nodes or r2.count < 1:
				continue
			if r2.count < best_c:
				best_c = r2.count
				best = [p, tops[i]]
			elif best_choke.is_empty() and _chokepoint(L2, p):
				best_choke = [p, tops[i]]
		if best.is_empty():
			best = best_choke
		if best.is_empty():
			break
		gates[best[0]] = best[1]
		L = LevelData.from_dict(_to_dict(m, start, bridges, hubs, houses, shops, gates, arrows, stack), 0)
		r = Solver.solve(L, o.open, o.nodes)
	if gates.size() < o.gates:
		return _rej("gates.size() < o.gates")

	for k in o.oneway:
		var best_c: int = r.count
		var best := []
		for t in 14:
			var a := _arrow_candidate(m, route, start, bridges, hubs, gates, arrows)
			if a.is_empty():
				continue
			var trial := arrows.duplicate()
			trial[a[0]] = a[1]
			var L2 := LevelData.from_dict(_to_dict(m, start, bridges, hubs, houses, shops, gates, trial, stack), 0)
			var r2 := Solver.solve(L2, best_c, o.nodes)
			if r2.nodes < o.nodes and r2.count >= 1 and r2.count < best_c:
				best_c = r2.count
				best = a
		if best.is_empty():
			break
		arrows[best[0]] = best[1]
	if o.oneway > 0 and arrows.is_empty():
		return _rej("o.oneway > 0 and arrows.is_empty()")

	dict = _to_dict(m, start, bridges, hubs, houses, shops, gates, arrows, stack)
	L = LevelData.from_dict(dict, 0)
	r = Solver.solve(L, 2000, o.nodes * 4)
	if r.capped or r.count == 0 or r.count > o.maxsol or r.nodes < o.minnodes:
		return _rej("r.capped or r.count == 0 or r.count > o.maxsol o")
	if o.needbridge == 1 and not _unsolvable_without(L, "bridges"):
		return _rej("o.needbridge == 1 and not _unsolvable_without(L,")
	if o.needhub == 1 and not _unsolvable_without(L, "hubs"):
		return _rej("o.needhub == 1 and not _unsolvable_without(L, hu")

	var nopes := 0
	var s := Sim.new_state(L)
	for i in range(1, r.shortest.size()):
		nopes += Sim.arrive(L, s, r.shortest[i])["nopes"].size()
	var choices := 0
	var s2 := Sim.new_state(L)
	for i in range(0, r.shortest.size() - 1):
		var opts := 0
		for d in LevelData.DIRS:
			if Sim.can_extend(L, r.shortest.slice(0, i + 1), r.shortest[i] + d, s2):
				opts += 1
		choices += maxi(0, opts - 1)
		Sim.arrive(L, s2, r.shortest[i + 1])
	var length: int = r["shortest"].size() - 1
	var score: float = log(float(r.nodes)) / log(2.0) * 3.0 + choices * 1.0 + nopes * 2.0 + length * 0.3 - r.count * 2.0 + randf()
	return {"dict": dict, "count": r.count, "len": length, "nopes": nopes, "choices": choices, "nodes": r.nodes, "score": score}


func _rej(why: String):
	rejects[why] = rejects.get(why, 0) + 1
	return null


## Is `p` the only way from the depot to some house or shop?
func _chokepoint(L: LevelData, p: Vector2i) -> bool:
	var reach := {L.start: true}
	var queue := [L.start]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for d in LevelData.DIRS:
			var n: Vector2i = t + d
			if n != p and L.is_road(n) and not reach.has(n):
				reach[n] = true
				queue.append(n)
	for roads in L.house_roads + L.shop_roads:
		if not roads.any(func(rp): return reach.has(rp)):
			return true
	return false


func _unsolvable_without(L: LevelData, field: String) -> bool:
	var saved: Dictionary = L.get(field)
	L.set(field, {})
	var r := Solver.solve(L, 1, o.nodes)
	L.set(field, saved)
	return r.count == 0 and not r.capped


func _free_cells(m: Dictionary, p: Vector2i, forbidden: Dictionary, used: Dictionary) -> Array:
	var out := []
	for d in LevelData.DIRS:
		var c: Vector2i = p + d
		if _inside(c) and not _is_road(m, c) and not forbidden.has(c) and not used.has(c):
			out.append(c)
	return out


## Top package colour just before entering each route tile (index-aligned with route).
func _tops_before(L: LevelData, route: Array) -> Array:
	var tops := [""]
	var s := Sim.new_state(L)
	for i in range(1, route.size()):
		tops.append(Sim.top_color(L, s))
		Sim.arrive(L, s, route[i])
	return tops


## Random self-avoiding drive. Prefers going straight; may cross itself at a junction
## (perpendicular, straight through) to create a bridge.
func _walk(m: Dictionary, start: Vector2i) -> Dictionary:
	var route := [start]
	var seen := {start: true}
	var bridges := {}
	var target := randi_range(o.minlen + 2, o.w * o.h)
	while route.size() < target:
		var last: Vector2i = route.back()
		var prev_d: Vector2i = last - route[route.size() - 2] if route.size() > 1 else Vector2i.ZERO
		var opts := []
		for d in LevelData.DIRS:
			var n: Vector2i = last + d
			if _is_road(m, n) and not seen.has(n):
				opts.append({"steps": [n], "w": 2.0 if d == prev_d else 1.0})
			elif o.bridges == 1 and _can_bridge(m, route, bridges, start, n, d):
				opts.append({"steps": [n, n + d], "w": 4.0})
		if opts.is_empty():
			break
		var total := 0.0
		for op in opts:
			total += op.w
		var pick := randf() * total
		for op in opts:
			pick -= op.w
			if pick <= 0.0:
				if op.steps.size() == 2:
					bridges[op.steps[0]] = true
				for st in op.steps:
					route.append(st)
					seen[st] = true
				break
	if o.bridges == 1 and bridges.is_empty():
		route = [start]
	return {"route": route, "bridges": bridges}


## Shortest way from the end of `route` back to the depot over unused road.
func _path_home(m: Dictionary, route: Array, bridges: Dictionary, start: Vector2i) -> Array:
	if route.size() < 3:
		return []
	var used := {}
	for p in route:
		used[p] = true
	var from: Vector2i = route.back()
	var prev := {from: from}
	var queue := [from]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		for d in LevelData.DIRS:
			var n: Vector2i = t + d
			if n == start and not (t == from and route[route.size() - 2] == start):
				var path := [start]
				var c := t
				while c != from:
					path.push_front(c)
					c = prev[c]
				return path
			if not _is_road(m, n) or used.has(n) or prev.has(n):
				continue
			prev[n] = t
			queue.append(n)
	return []


func _can_bridge(m: Dictionary, route: Array, bridges: Dictionary, start: Vector2i, n: Vector2i, d: Vector2i) -> bool:
	if n == start or bridges.has(n) or not _is_road(m, n + d) or route.has(n + d):
		return false
	for dd in LevelData.DIRS:
		if not _is_road(m, n + dd):
			return false
	var j := route.find(n)
	if j <= 0 or j >= route.size() - 1:
		return false
	var a: Vector2i = route[j] - route[j - 1]
	var b: Vector2i = route[j + 1] - route[j]
	return a == b and (a.x == 0) != (d.x == 0)


## A one-way arrow that keeps the intended route legal: either on a piece of the route
## pointing along it, or on a straight road the route never uses.
func _arrow_candidate(m: Dictionary, route: Array, start: Vector2i, bridges: Dictionary, hubs: Dictionary, gates: Dictionary, arrows: Dictionary) -> Array:
	for t in 20:
		var p: Vector2i = m.road.keys().pick_random()
		if p == start or bridges.has(p) or hubs.has(p) or gates.has(p) or arrows.has(p):
			continue
		var i := route.find(p)
		var d: Vector2i
		if i >= 1:
			if route.count(p) > 1:
				continue
			d = route[i] - route[i - 1]
		else:
			d = LevelData.DIRS.pick_random()
		if _is_road(m, p - d) and _is_road(m, p + d):
			return [p, d]
	return []


func _to_dict(m: Dictionary, start: Vector2i, bridges: Dictionary, hubs: Dictionary, houses: Dictionary,
		shops: Dictionary, gates: Dictionary, arrows: Dictionary, stack: Array) -> Dictionary:
	var rows := []
	for y in o.h:
		var toks := []
		for x in o.w:
			var p := Vector2i(x, y)
			if p == start:
				toks.append("S")
			elif bridges.has(p):
				toks.append("+")
			elif hubs.has(p):
				toks.append("@")
			elif gates.has(p):
				toks.append("=" + _code(gates[p]))
			elif arrows.has(p):
				toks.append(ARROW_TOK[arrows[p]])
			elif _is_road(m, p):
				toks.append("#")
			elif houses.has(p):
				var h: Dictionary = houses[p]
				toks.append(h.color + (str(h.order) if h.order > 1 else ""))
			elif shops.has(p):
				toks.append(_code(shops[p]).to_upper())
			else:
				toks.append(".")
		rows.append(" ".join(toks))
	var d := {"title": "", "no_revisit": true, "map": rows, "stack": stack.map(func(c): return LevelData.COLOR_CODES.get(c, c))}
	if o.ret == 1:
		d["return"] = true
	return d


## Colour name or code -> single-letter code.
func _code(c: String) -> String:
	if c.length() == 1:
		return c
	for k in LevelData.COLOR_CODES:
		if LevelData.COLOR_CODES[k] == c:
			return k
	return c
