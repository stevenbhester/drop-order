class_name Sim
extends RefCounted
## The game rules, shared by gameplay and the solver so they can never disagree.
##
## State is a plain Dictionary:
##   "stack":  Array[String]  packages in the van, bottom..top
##   "fills":  Array[int]     packages each house has received
##   "picked": Array[int]     parcels taken from each shop so far (a warehouse holds several)
##   "held":   Array[String]  what each parking locker is keeping ("" empty)
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
	var held := []
	held.resize(L.lockers.size())
	held.fill("")
	return {"stack": L.stack.duplicate(), "fills": fills, "picked": picked, "held": held}


## Packages delivered so far (roadworks open after enough of them).
static func delivered_count(s: Dictionary) -> int:
	var n := 0
	for f in s["fills"]:
		n += f
	return n


static func copy_state(s: Dictionary) -> Dictionary:
	return {"stack": s["stack"].duplicate(), "fills": s["fills"].duplicate(), "picked": s["picked"].duplicate(),
		"held": s.get("held", []).duplicate()}


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
## (Parking lockers do nothing on arrival: the player uses one by tapping it, use_locker.)
## Returns { "events": [ {type: "swap"} | {type: "deliver", house, color} |
##                       {type: "pickup", shop, color} | {type: "unpark"|"park", locker, color} ],
##           "nopes": [house idx] }.
##
## Two houses beside the tile that both want the package on top: the one this is the LAST CHANCE for gets
## it (every other road tile beside it is already driven: `route`, the tiles driven so far, says). Failing
## that, the first in reading order (top to bottom, left to right). So the game never hands a package to a
## house it could have served later while the one next door goes without for good. (With no `route` given
## it's reading order alone.)
static func arrive(L: LevelData, s: Dictionary, tile: Vector2i, route: Array = []) -> Dictionary:
	var events := []
	var stack: Array = s["stack"]
	if L.hubs.has(tile) and stack.size() >= 2:
		var a = stack[stack.size() - 1]
		stack[stack.size() - 1] = stack[stack.size() - 2]
		stack[stack.size() - 2] = a
		events.append({"type": "swap"})
	return _settle(L, s, tile, route, events)


## Deliveries and pickups at `tile` until nothing more happens (arrive's step 2), then which houses there
## were passed over ("nopes").
static func _settle(L: LevelData, s: Dictionary, tile: Vector2i, route: Array, events: Array) -> Dictionary:
	var stack: Array = s["stack"]
	var fills: Array = s["fills"]
	var picked: Array = s["picked"]
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
				var pick := -1
				for h in adj_h:
					if (L.houses[h].color == "any") == pass_any and (pass_any or L.houses[h].color == top) and fills[h] < L.houses[h].order:
						if pick < 0:
							pick = h
						if route.is_empty():
							break
						if _last_chance(L, h, tile, route):
							pick = h
							break
				if pick >= 0:
					fills[pick] += 1
					stack.pop_back()
					delivered[pick] = true
					events.append({"type": "deliver", "house": pick, "color": top})
					progress = true
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


## The parking locker the van can use from `tile` right now (stopped beside it): it's keeping a package to
## give back, or it's empty and there's a package on top to leave. -1 if none.
static func locker_here(L: LevelData, s: Dictionary, tile: Vector2i) -> int:
	var held: Array = s.get("held", [])
	for k in L.adjacent_lockers.get(tile, []):
		if k < held.size() and (held[k] != "" or not s["stack"].is_empty()):
			return k
	return -1


## The player taps the parking locker the van's stopped beside (locker_here): it takes the top package, or
## gives back the one it's keeping, on top. Then, as on arriving, a house right there that wants what's now
## on top gets it. Same result shape as arrive. (Never automatic: you choose when, and whether.)
static func use_locker(L: LevelData, s: Dictionary, tile: Vector2i, route: Array = []) -> Dictionary:
	var events := []
	var k := locker_here(L, s, tile)
	if k < 0:
		return {"events": events, "nopes": []}
	var held: Array = s["held"]
	var stack: Array = s["stack"]
	if held[k] != "":
		stack.append(held[k])
		events.append({"type": "unpark", "locker": k, "color": held[k]})
		held[k] = ""
	else:
		held[k] = stack.pop_back()
		events.append({"type": "park", "locker": k, "color": held[k]})
	return _settle(L, s, tile, route, events)


## Steps (a route with locker uses written in as a repeated tile) back to just the tiles driven.
static func tiles_of(steps: Array) -> Array:
	var out := []
	for i in steps.size():
		if i == 0 or steps[i] != steps[i - 1]:
			out.append(steps[i])
	return out


## (The same as run: kept for the name.)
static func run_steps(L: LevelData, steps: Array) -> Dictionary:
	return run(L, steps)


## Is `tile` the last road tile beside house `h` that the van can still stand on? (Every other one is in
## `route` already; a bridge, or the depot on a round trip, can be driven again, so those still count.)
static func _last_chance(L: LevelData, h: int, tile: Vector2i, route: Array) -> bool:
	if not L.no_revisit:
		return false
	for r in L.house_roads[h]:
		if r != tile and (not route.has(r) or L.bridges.has(r) or (L.return_depot and r == L.start)):
			return false
	return true


## The most packages aboard at any point along `route` (from a fresh start), counting the start. (A route
## may have locker uses in it: the same tile twice in a row.)
static func max_load(L: LevelData, route: Array) -> int:
	var s := new_state(L)
	var most: int = s["stack"].size()
	var tiles := [route[0]]
	for i in range(1, route.size()):
		var before: int = s["stack"].size()
		var res := use_locker(L, s, route[i], tiles) if route[i] == route[i - 1] else arrive(L, s, route[i], tiles)
		if route[i] != route[i - 1]:
			tiles.append(route[i])
		# Within one stop the load can rise and fall: count the pickups before any delivery after them.
		var load := before
		for ev in res["events"]:
			load += 1 if ev["type"] == "pickup" or ev["type"] == "unpark" else (-1 if ev["type"] == "deliver" or ev["type"] == "park" else 0)
			most = maxi(most, load)
	return most


## Runs a whole route from a fresh state (no legality checks). Returns the final state. (Locker uses written
## in as the same tile twice in a row are used, Sim.use_locker.)
static func run(L: LevelData, route: Array) -> Dictionary:
	var s := new_state(L)
	var tiles := [route[0]]
	for i in range(1, route.size()):
		if route[i] == route[i - 1]:
			use_locker(L, s, route[i], tiles)
		else:
			arrive(L, s, route[i], tiles)
			tiles.append(route[i])
	return s


## Runs a route checking every step is legal. Returns the final state, or {} if illegal.
static func run_checked(L: LevelData, route: Array) -> Dictionary:
	var s := new_state(L)
	var tiles := [route[0]]
	for i in range(1, route.size()):
		if route[i] == route[i - 1]:
			if (i >= 2 and route[i - 1] == route[i - 2]) or locker_here(L, s, route[i]) < 0:
				return {}
			use_locker(L, s, route[i], tiles)
			continue
		if not can_extend(L, tiles, route[i], s):
			return {}
		arrive(L, s, route[i], tiles)
		tiles.append(route[i])
	return s
