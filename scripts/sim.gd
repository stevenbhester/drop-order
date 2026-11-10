class_name Sim
extends RefCounted
## The game rules, shared by gameplay and the solver so they can never disagree.
## State is a plain Dictionary: { "left": int (packages still in the van), "fills": Array[int] }.


static func new_state(L: LevelData) -> Dictionary:
	var fills := []
	fills.resize(L.houses.size())
	fills.fill(0)
	return {"left": L.stack.size(), "fills": fills}


static func copy_state(s: Dictionary) -> Dictionary:
	return {"left": s["left"], "fills": s["fills"].duplicate()}


static func top_color(L: LevelData, s: Dictionary) -> String:
	var n: int = s["left"]
	return L.stack[n - 1] if n > 0 else ""


## Can a path (path[0] is the van's tile) be extended onto `next`?
## Stepping back onto path[-2] is a retract, never an extension.
static func can_extend(L: LevelData, path: Array, next: Vector2i) -> bool:
	if not L.is_road(next):
		return false
	var last: Vector2i = path.back()
	if absi(next.x - last.x) + absi(next.y - last.y) != 1:
		return false
	if path.size() >= 2 and next == path[path.size() - 2]:
		return false
	if L.no_revisit and path.has(next):
		return false
	return true


## The van arrives on `tile`. Delivers the top package to every adjacent matching
## house it can (repeatedly, since the next package may also match), mutating `s`.
## Returns { "delivered": [house idx in order], "nopes": [house idx] }.
static func arrive(L: LevelData, s: Dictionary, tile: Vector2i) -> Dictionary:
	var delivered := []
	var adj: Array = L.adjacent_houses.get(tile, [])
	var fills: Array = s["fills"]
	var progress := true
	while progress and s["left"] > 0:
		progress = false
		var top: String = L.stack[s["left"] - 1]
		for h in adj:
			if L.houses[h].color == top and fills[h] < L.houses[h].order:
				fills[h] += 1
				s["left"] -= 1
				delivered.append(h)
				progress = true
				break
	var nopes := []
	if s["left"] > 0:
		var top: String = L.stack[s["left"] - 1]
		for h in adj:
			if fills[h] < L.houses[h].order and L.houses[h].color != top and not delivered.has(h):
				nopes.append(h)
	return {"delivered": delivered, "nopes": nopes}
