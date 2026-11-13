class_name Sim
extends RefCounted
## The game rules, shared by gameplay and the solver so they can never disagree.
##
## State is a plain Dictionary:
##   "stack":  Array[String]  packages in the van, bottom..top
##   "fills":  Array[int]     packages each house has received
##   "picked": Array[int]     parcels taken from each shop so far (a warehouse holds several)
##
## A route is an Array[Vector2i] starting at the van's start tile. The player builds it in
## segments, but the rules only ever look at the whole route so far plus the state after it.


static func new_state(L: LevelData) -> Dictionary:
	var fills := []
	fills.resize(L.houses.size())
	fills.fill(0)
	var picked := []
	picked.resize(L.shops.size())
	picked.fill(0)
	return {"stack": L.stack.duplicate(), "fills": fills, "picked": picked}


## Packages delivered so far (roadworks open after enough of them).
static func delivered_count(s: Dictionary) -> int:
	var n := 0
	for f in s["fills"]:
		n += f
	return n


static func copy_state(s: Dictionary) -> Dictionary:
	return {"stack": s["stack"].duplicate(), "fills": s["fills"].duplicate(), "picked": s["picked"].duplicate()}


static func top_color(_L: LevelData, s: Dictionary) -> String:
	var st: Array = s["stack"]
	return st.back() if not st.is_empty() else ""


## Packages still to deliver (in the van or waiting at shops).
static func remaining(L: LevelData, s: Dictionary) -> int:
	var n := L.total_orders()
	for f in s["fills"]:
		n -= f
	return n


static func all_delivered(L: LevelData, s: Dictionary) -> bool:
	return remaining(L, s) == 0


static func parked(L: LevelData, route: Array) -> bool:
	return L.return_depot and route.size() > 1 and route.back() == L.start


static func is_won(L: LevelData, s: Dictionary, route: Array) -> bool:
	if not all_delivered(L, s):
		return false
	if L.has_exit():
		return route.back() == L.exit
	return parked(L, route) if L.return_depot else true


## Can the route (with state `s` after driving it) be extended onto `next`?
## - orthogonal step onto road
## - one-way tiles: you may turn onto one from the side, but never drive onto it head-on against its arrow,
##   and you must leave it moving the way the arrow points
## - bridges must be driven straight across, and (no-revisit levels) once per axis
## - colour gates may only be entered while the top package is their colour
## - roadworks open only once enough packages have been delivered
## - ice: no turning on it (you leave it the way you drove on)
## - no-revisit levels (all of them now: the road behind the van is wrecked): any other tile at most
##   once, except driving home to the depot
## - once parked at the depot, the shift is over
## U-turns are legal (the player can stop, then draw back the way they came);
## while drawing a single segment, dragging back is a retract instead.
static func can_extend(L: LevelData, route: Array, next: Vector2i, s: Dictionary, ignore_wreck := false) -> bool:
	if not L.is_road(next) or parked(L, route):
		return false
	var last: Vector2i = route.back()
	var d := next - last
	if absi(d.x) + absi(d.y) != 1:
		return false
	if L.oneway.has(next) and L.oneway[next] == -d:
		return false
	if L.oneway.has(last) and L.oneway[last] != d:
		return false
	if L.gates.has(next) and top_color(L, s) != L.gates[next]:
		return false
	if L.works.has(next) and delivered_count(s) < L.works[next]:
		return false
	var n := route.size()
	if L.ice.has(last) and n >= 2 and d != last - route[n - 2]:
		return false
	if L.bridges.has(last) and n >= 2 and d != last - route[n - 2]:
		return false
	if L.bridges.has(next):
		if L.no_revisit and not ignore_wreck:
			for i in range(1, n):
				if route[i] == next and ((route[i] - route[i - 1]).x == 0) == (d.x == 0):
					return false
		return true
	if L.no_revisit and route.has(next) and not ignore_wreck:
		return L.return_depot and next == L.start
	return true


## Is `next` blocked only by the route's own wreckage (it would be a legal step on fresh road)?
## That's a crash: the drawn path turns red from there.
static func wrecked(L: LevelData, route: Array, next: Vector2i, s: Dictionary) -> bool:
	return not can_extend(L, route, next, s) and can_extend(L, route, next, s, true)


static func has_move(L: LevelData, route: Array, s: Dictionary) -> bool:
	for d in LevelData.DIRS:
		if can_extend(L, route, route.back() + d, s):
			return true
	return false


## The van arrives on `tile`, mutating `s`:
##  1. a sorting hub swaps the top two packages;
##  2. then, repeatedly: deliver the top package to an adjacent house that wants it,
##     otherwise collect one waiting parcel from an adjacent shop (it goes on top). A warehouse
##     keeps handing them over one by one, so passing it loads its whole stock (deliveries can
##     happen in between, if a house right there wants what just came aboard).
## Returns { "events": [ {type: "swap"} | {type: "deliver", house, color} |
##                       {type: "pickup", shop, color} ], "nopes": [house idx] }.
static func arrive(L: LevelData, s: Dictionary, tile: Vector2i) -> Dictionary:
	var events := []
	var stack: Array = s["stack"]
	var fills: Array = s["fills"]
	var picked: Array = s["picked"]
	if L.hubs.has(tile) and stack.size() >= 2:
		var a = stack[stack.size() - 1]
		stack[stack.size() - 1] = stack[stack.size() - 2]
		stack[stack.size() - 2] = a
		events.append({"type": "swap"})
	var adj_h: Array = L.adjacent_houses.get(tile, [])
	var adj_s: Array = L.adjacent_shops.get(tile, [])
	var delivered := {}
	var progress := true
	while progress:
		progress = false
		if not stack.is_empty():
			var top: String = stack.back()
			# A house wanting that colour first; a locker (any colour) only if none does.
			for pass_any in [false, true]:
				for h in adj_h:
					if (L.houses[h].color == "any") == pass_any and (pass_any or L.houses[h].color == top) and fills[h] < L.houses[h].order:
						fills[h] += 1
						stack.pop_back()
						delivered[h] = true
						events.append({"type": "deliver", "house": h, "color": top})
						progress = true
						break
				if progress:
					break
		if progress:
			continue
		for k in adj_s:
			if picked[k] < L.shops[k].count:
				picked[k] += 1
				stack.append(L.shops[k].color)
				events.append({"type": "pickup", "shop": k, "color": L.shops[k].color})
				progress = true
				break
	var nopes := []
	if not stack.is_empty():
		var top: String = stack.back()
		for h in adj_h:
			if fills[h] < L.houses[h].order and L.houses[h].color != top and L.houses[h].color != "any" and not delivered.has(h):
				nopes.append(h)
	return {"events": events, "nopes": nopes}


## The most packages aboard at any point along `route` (from a fresh start), counting the start.
static func max_load(L: LevelData, route: Array) -> int:
	var s := new_state(L)
	var most: int = s["stack"].size()
	for i in range(1, route.size()):
		var before: int = s["stack"].size()
		var res := arrive(L, s, route[i])
		# Within one stop the load can rise and fall: count the pickups before any delivery after them.
		var load := before
		for ev in res["events"]:
			load += 1 if ev["type"] == "pickup" else (-1 if ev["type"] == "deliver" else 0)
			most = maxi(most, load)
	return most


## Runs a whole route from a fresh state (no legality checks). Returns the final state.
static func run(L: LevelData, route: Array) -> Dictionary:
	var s := new_state(L)
	for i in range(1, route.size()):
		arrive(L, s, route[i])
	return s


## Runs a route checking every step is legal. Returns the final state, or {} if illegal.
static func run_checked(L: LevelData, route: Array) -> Dictionary:
	var s := new_state(L)
	for i in range(1, route.size()):
		if not can_extend(L, route.slice(0, i), route[i], s):
			return {}
		arrive(L, s, route[i])
	return s
