class_name RideWins
extends RefCounted
## What each ride does when a level's won (and when it's picked in the garage): Van.celebrate() plays it.
## time() is how long it lasts, so the finish card waits for it (pick a ride with a short one to get on
## quicker). pose() moves the whole ride (Van applies it to its body); the ride's own drawing does the rest
## (FriendRides and Cosmetics get the seconds since it started), and overlay() draws what goes on top, in the
## van's space, upright on screen.
##   (the van)      two happy hops                       0.7 s
##   monster_truck  crazy hydraulics bouncing            1.4 s
##   scooter        a wheelie, then a spin               1.1 s
##   ice_cream      a twirl to its jingle                1.2 s
##   rocket_van     boosts forward and back              1.1 s
##   hover_van      lifts, spins, lands                  1.2 s
##   race_car       two donuts, back end out, rubber on the road  2.0 s
##   bassinet       shudders, eyes going everywhere      1.4 s
##   caterpillar    tosses a green package and eats it   1.8 s
##   minivan        doors slide open, BEEP BEEP          1.4 s
##   pillow_tower   its topper dives into the puddle (a tiny someone, if it wears none)  1.7 s
##   shark          leaps through a hoop, splashes down, swims back  1.9 s
##   eazy_van       smoke puffs out of every window       1.6 s
##   dreamsicle     a bite pops out of it, crumbs flying  1.3 s
##   classic_car    a gleam sweeps over it, sparkles pop  1.3 s
##   lab            potions run into the big flask, it churns and puffs up a sparkly cloud  1.9 s
##   zero           a hand of cards fans out over him, he plays Zoomies (3 energy to 2), and does them  2.0 s

const TIMES := {"": 0.7, "monster_truck": 1.4, "scooter": 1.1, "ice_cream": 1.2, "rocket_van": 1.1, "hover_van": 1.2,
	"race_car": 2.0, "bassinet": 1.4, "caterpillar": 1.8, "minivan": 1.4, "pillow_tower": 1.7, "shark": 1.9,
	"eazy_van": 1.6, "dreamsicle": 1.3, "classic_car": 1.3, "lab": 1.9, "zero": 2.0}
## How far ahead the shark's hoop stands (times the van's size), and how far it lands past where it started.
const SHARK_HOOP := 0.55
const SHARK_LAND := 1.1


static func time(ride: String) -> float:
	return TIMES.get(ride, 0.8)


## The race car's donut: how far round it's swung `w` seconds in (two turns, quick in the middle).
static func donut_angle(w: float) -> float:
	var u := clampf(w / 1.8, 0.0, 1.0)
	return TAU * 2.0 * _ease(u)


## Where the front wheels sit (the point it spins round), in the van's space.
static func donut_pivot(size: float) -> Vector2:
	return Vector2(size * 0.74 * 0.3, 0)


## A back wheel (side -1 or 1), unturned.
static func donut_wheel(size: float, side: float) -> Vector2:
	return Vector2(-size * 0.74 * 0.32, side * size * 0.46 * 0.42)


## The black rubber the back wheels leave on the road, on the board under the van, for a donut. Drawn as
## it happens, then it stays a while and fades.
class TyreMarks:
	extends Node2D
	var size := 60.0
	var t := 0.0
	const STAY := 7.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > RideWins.time("race_car") + STAY:
			queue_free()

	func _draw() -> void:
		var front := RideWins.donut_pivot(size)
		var upto := RideWins.donut_angle(minf(t, 1.8))
		var fade := clampf(1.0 - (t - RideWins.time("race_car") - STAY * 0.4) / (STAY * 0.6), 0.0, 1.0)
		var col := Color(0.06, 0.05, 0.07, 0.72 * fade)
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			var n := int(clampf(upto / 0.08, 1.0, 200.0))
			for k in n + 1:
				var a := upto * k / n
				pts.append(front + (RideWins.donut_wheel(size, side) - front).rotated(a))
			if pts.size() >= 2:
				draw_polyline(pts, col, size * 0.1, true)

static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## The whole ride's offset, turn and scale `w` seconds in (`size` is the van's size).
static func pose(ride: String, w: float, size: float) -> Dictionary:
	var T := time(ride)
	var u := clampf(w / T, 0.0, 1.0)
	var fade := 1.0 - u
	var pos := Vector2.ZERO
	var rot := 0.0
	var sc := Vector2.ONE
	match ride:
		"":
			var hop := absf(sin(PI * w / 0.35)) if w < 0.7 else 0.0
			sc = Vector2.ONE * (1.0 + 0.16 * hop)
		"monster_truck":
			# Hydraulics: front and back slamming up and down, faster than anyone should.
			var k := sin(w * 26.0)
			sc = Vector2(1.0 + 0.1 * k * fade, 1.0 + 0.06 * sin(w * 26.0 + 1.6) * fade)
			pos = Vector2(k * size * 0.035, absf(sin(w * 13.0)) * -size * 0.05) * fade
			rot = sin(w * 13.0) * 0.07 * fade
		"scooter":
			if w < 0.45:
				var k := sin(PI * w / 0.45)
				sc = Vector2(1.0 - 0.18 * k, 1.0)
				pos = Vector2(-size * 0.06 * k, 0)
			else:
				rot = TAU * _ease((w - 0.45) / 0.6)
		"ice_cream":
			rot = TAU * _ease(u)
			sc = Vector2.ONE * (1.0 + 0.08 * sin(PI * u))
		"rocket_van":
			pos = Vector2(size * 0.9 * sin(PI * _ease(u)), 0)
		"hover_van":
			sc = Vector2.ONE * (1.0 + 0.32 * sin(PI * u))
			rot = TAU * _ease(u)
		"race_car":
			# Donuts: the front wheels stay planted and the back end swings round them, twice, with a
			# little kick as it catches and lets go.
			var a := donut_angle(w)
			var front := donut_pivot(size)
			rot = a + 0.08 * sin(w * 19.0) * fade
			pos = front - front.rotated(rot)
		"bassinet":
			pos = Vector2(sin(w * 47.0), cos(w * 39.0)) * size * 0.025 * fade
			rot = sin(w * 31.0) * 0.09 * fade
		"caterpillar":
			var chomp := clampf(1.0 - absf(w - 0.8) / 0.12, 0.0, 1.0)
			sc = Vector2(1.0 + 0.08 * chomp, 1.0 - 0.06 * chomp)
		"minivan":
			var beep := maxf(clampf(1.0 - absf(w - 0.4) / 0.1, 0.0, 1.0), clampf(1.0 - absf(w - 0.75) / 0.1, 0.0, 1.0))
			sc = Vector2.ONE * (1.0 + 0.06 * beep)
		"shark":
			# A dip, the leap (it grows: it's up out of the water), through the hoop, a splash, then it swims
			# back to where it was.
			var D := size * SHARK_LAND
			if w < 0.25:
				sc = Vector2.ONE * (1.0 - 0.1 * sin(PI * w / 0.25))
			elif w < 0.85:
				var k := (w - 0.25) / 0.6
				pos = Vector2(D * _ease(k), 0)
				sc = Vector2.ONE * (1.0 + 0.5 * sin(PI * k))
			elif w < 1.05:
				pos = Vector2(D, 0)
				sc = Vector2(1.0 + 0.1 * sin(PI * (w - 0.85) / 0.2), 1.0)
			else:
				pos = Vector2(D * (1.0 - _ease((w - 1.05) / 0.8)), 0)
		"eazy_van":
			rot = sin(w * 9.0) * 0.035 * fade
		"dreamsicle":
			var chomp := clampf(1.0 - absf(w - 0.2) / 0.1, 0.0, 1.0)
			sc = Vector2(1.0 - 0.1 * chomp, 1.0 + 0.08 * chomp)
			rot = sin(w * 20.0) * 0.05 * clampf((w - 0.2) / 0.1, 0.0, 1.0) * fade
		"classic_car":
			sc = Vector2.ONE * (1.0 + 0.05 * sin(PI * u))
		"zero":
			# Zoomies: two quick laps of a little circle, ending where he started.
			var zk := _ease((w - 0.8) / 1.0)
			var a := TAU * 2.0 * zk
			var r := size * 0.22 * sin(PI * zk)
			pos = Vector2(sin(a), -(1.0 - cos(a))) * r
			rot = a
		"lab":
			var fizz := clampf((w - 0.5) / 0.3, 0.0, 1.0) * (1.0 - clampf((w - 0.85) / 0.1, 0.0, 1.0))
			pos = Vector2(sin(w * 53.0), cos(w * 47.0)) * size * 0.012 * fizz
			var pop := clampf(1.0 - absf(w - 0.9) / 0.12, 0.0, 1.0)
			sc = Vector2.ONE * (1.0 + 0.08 * pop)
	return {"pos": pos, "rot": rot, "scale": sc}


## Sounds, as [seconds in, sound, pitch, dB].
static func cues(ride: String) -> Array:
	match ride:
		"":
			return [[0.0, "pop", 1.3, -6.0], [0.35, "pop", 1.5, -6.0]]
		"monster_truck":
			var out := [[0.0, "whoomp", 0.8, -2.0]]
			for k in 6:
				out.append([0.1 + k * 0.22, "thunk", 0.7 + 0.05 * k, -4.0])
			return out
		"scooter":
			return [[0.0, "beep", 1.6, -6.0], [0.45, "whoosh", 1.3, -6.0]]
		"ice_cream":
			return [[0.0, "jingle", 1.1, -4.0]]
		"rocket_van":
			return [[0.0, "whoomp", 1.0, 0.0], [0.05, "whoosh", 0.8, -2.0]]
		"hover_van":
			return [[0.0, "sparkle", 1.0, -4.0], [0.2, "whoosh", 1.4, -6.0]]
		"race_car":
			return [[0.0, "whoomp", 0.7, -4.0], [0.05, "screech", 0.9, -2.0], [0.7, "screech", 1.0, -3.0], [1.35, "screech", 1.1, -4.0], [1.8, "thunk", 0.8, -6.0]]
		"bassinet":
			return [[0.0, "studio_creak", 0.7, -2.0], [0.15, "punch", 0.6, -8.0], [0.6, "studio_creak", 0.55, -4.0]]
		"caterpillar":
			return [[0.0, "pop", 1.2, -4.0], [0.78, "thunk", 1.3, -2.0], [0.95, "studio_goo", 1.4, -4.0]]
		"minivan":
			return [[0.0, "whoosh", 0.7, -8.0], [0.38, "beep", 1.0, -2.0], [0.73, "beep", 1.0, -2.0]]
		"pillow_tower":
			return [[0.15, "pop", 1.6, -4.0], [0.95, "studio_gush", 1.6, -4.0], [0.95, "sparkle", 1.3, -8.0]]
		"shark":
			return [[0.22, "whoosh", 1.2, -4.0], [0.55, "sparkle", 1.4, -6.0], [0.85, "studio_gush", 1.3, -2.0], [1.05, "whoosh", 0.7, -10.0]]
		"eazy_van":
			return [[0.05, "studio_gush", 0.6, -8.0], [0.2, "pop", 0.8, -10.0], [0.5, "pop", 0.7, -10.0], [0.8, "pop", 0.75, -10.0]]
		"dreamsicle":
			return [[0.18, "punch", 1.5, -4.0], [0.2, "pop", 1.4, -4.0], [0.5, "sparkle", 1.6, -8.0]]
		"classic_car":
			return [[0.0, "sparkle", 1.0, -4.0], [0.45, "sparkle", 1.3, -6.0], [0.8, "sparkle", 1.6, -8.0]]
		"zero":
			return [[0.0, "whoosh", 1.6, -8.0], [0.1, "tick", 1.2, -6.0], [0.2, "tick", 1.35, -6.0], [0.3, "tick", 1.5, -6.0],
				[0.68, "kaching", 1.3, -6.0], [0.82, "pop", 1.0, -4.0], [0.85, "whoosh", 1.2, -4.0], [1.3, "whoosh", 1.4, -6.0]]
		"lab":
			return [[0.0, "studio_goo", 1.2, -6.0], [0.55, "studio_gush", 1.5, -6.0], [0.88, "whoomp", 1.3, -4.0], [0.9, "sparkle", 1.0, -4.0]]
	return []


## Drawn with the ride, in the van's space (not turned by pose()); `rot` is the van's turn on screen, so
## words and emoji can stand upright. `under`: the layer beneath the ride (smoke, splashes), else above it.
## `has_topper`: the ride's wearing one (the tower's own topper does its dive: Van draws that).
static func overlay(ci: CanvasItem, ride: String, w: float, size: float, rot: float, under := false, has_topper := false) -> void:
	var L := size * 0.74
	var W := size * 0.46
	var up := Vector2.UP.rotated(-rot)
	var f := UiTheme.font()
	if under and not (ride in ["race_car", "pillow_tower", "shark"]):
		return
	match ride:
		"race_car":
			if not under:
				return
			# Tyre smoke boiling off the back wheels (the black marks they leave are TyreMarks, on the road).
			var T := time(ride)
			var front := donut_pivot(size)
			for k in 22:
				var at_t := k * 0.08
				var age := w - at_t
				if age < 0.0 or age > 1.1 or at_t > T:
					continue
				var a := donut_angle(at_t)
				for side in [-1.0, 1.0]:
					var p := front + (donut_wheel(size, side) - front).rotated(a)
					p += Vector2(-1, 0).rotated(a) * W * 0.5 * age
					ci.draw_circle(p, W * (0.2 + 0.55 * age), Color(0.88, 0.88, 0.9, 0.42 * (1.0 - age / 1.1)))
		"minivan":
			if under:
				return
			for b in [0.38, 0.73]:
				var age: float = w - float(b)
				if age < 0.0 or age > 0.5:
					continue
				var k := clampf(age / 0.12, 0.0, 1.0)
				var at: Vector2 = Vector2(L * 0.5, 0) + up * (W * 0.9 + age * W * 0.6)
				ci.draw_set_transform(at, -rot, Vector2.ONE * (0.6 + 0.4 * k))
				var tw := f.get_string_size("BEEP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(W * 0.5)).x
				DrawUtil.rrect(ci, Rect2(-tw / 2.0 - W * 0.12, -W * 0.36, tw + W * 0.24, W * 0.52), Color(Palette.BUBBLE, 0.95 * (1.0 - age / 0.5)), W * 0.2)
				ci.draw_string(f, Vector2(-tw / 2.0, W * 0.08), "BEEP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(W * 0.5), Color(Palette.TEXT, 1.0 - age / 0.5))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pillow_tower":
			# The topper (Van draws it) or, with none on, a tiny someone hops off the top of the stack and
			# into the puddle. Splash.
			var top := up * W * 0.2 * 7.0
			var pc := FriendRides.puddle_at(L, W, up)
			var u := clampf((w - 0.15) / 0.8, 0.0, 1.0)
			if w >= 0.15 and w < 0.95 and not under and not has_topper:
				var at := top.lerp(pc, u) + up * W * 1.2 * sin(PI * u)
				var px := int(W * 0.42)
				var ew := f.get_string_size("😄", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				ci.draw_set_transform(at, -rot + u * TAU, Vector2.ONE)
				ci.draw_string(f, Vector2(-ew / 2.0, px * 0.36), "😄", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif w >= 0.95 and under:
				var s := (w - 0.95) / 0.7
				for k in 2:
					var r := W * (0.2 + 0.5 * clampf(s - k * 0.15, 0.0, 1.0))
					ci.draw_set_transform(pc, up.angle() + PI / 2.0, Vector2(1.0, 0.6))
					ci.draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.6, 0.8, 1.0, 0.9 * (1.0 - s)), W * 0.05, true)
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for k in 5:
					var a := TAU * k / 5.0
					var d := Vector2(cos(a), sin(a)) * W * 0.5 * s
					ci.draw_circle(pc + d + up * W * 0.6 * sin(PI * clampf(s * 1.4, 0.0, 1.0)), W * 0.05 * (1.0 - s), Color(0.6, 0.8, 1.0))
		"shark":
			_shark_overlay(ci, w, size, under)
		"eazy_van":
			# Smoke puffing out of every window, drifting off and up.
			for wp in FriendRides.eazy_windows(L, W):
				var side := signf((wp as Vector2).y)
				for k in 4:
					var born := 0.05 + k * 0.3 + absf(wp.x) / L * 0.15
					var age := w - born
					if age < 0.0 or age > 0.9:
						continue
					var a := age / 0.9
					var at: Vector2 = wp + Vector2(0, side * W * (0.15 + 0.9 * a)) + up * W * 0.7 * a + Vector2(-W * 0.3 * a, 0)
					var r := W * (0.08 + 0.2 * a)
					var col := Color(0.93, 0.93, 0.95, 0.6 * (1.0 - a))
					ci.draw_circle(at, r, col)
					ci.draw_circle(at + Vector2(r * 0.6, -r * 0.3), r * 0.7, col)
					ci.draw_circle(at + Vector2(-r * 0.5, r * 0.2), r * 0.6, col)
		"dreamsicle":
			# Crumbs flying off the bite.
			if w >= 0.18 and w < 0.9:
				var a := (w - 0.18) / 0.72
				var bc := Vector2(L * 0.42, -W * 0.3)
				for k in 7:
					var ang := -PI * 0.15 - k * 0.35
					var at := bc + Vector2(cos(ang), sin(ang)) * W * (0.2 + 1.1 * a) + up * W * 0.6 * sin(PI * a)
					ci.draw_circle(at, W * 0.05 * (1.0 - a * 0.5), Color("fff3dd") if k % 2 == 0 else Color("ff9a3c"))
		"classic_car":
			# Sparkles popping off the paint.
			var spots := [Vector2(0.42, -0.3), Vector2(0.1, 0.36), Vector2(-0.3, -0.4), Vector2(0.25, 0.05), Vector2(-0.42, 0.25)]
			for k in spots.size():
				var born := 0.15 + k * 0.17
				var age := w - born
				if age < 0.0 or age > 0.5:
					continue
				var s := sin(PI * age / 0.5)
				Icons.star(ci, Vector2(spots[k].x * L, spots[k].y * W), W * 0.22 * s, Color(1, 1, 1, s))
		"zero":
			_zero_cards(ci, w, size, rot)
		"lab":
			# The concoction: a puff of colourful cloud and sparkles rising out of the big flask.
			if w >= 0.85:
				var a := clampf((w - 0.85) / 1.0, 0.0, 1.0)
				var c := Vector2(-L * 0.02, 0) + up * W * 1.3 * a
				for k in 6:
					var ang := TAU * k / 6.0 + w
					var r := W * (0.18 + 0.25 * a)
					ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.8, r * 0.7, Color.from_hsv(fmod(k / 6.0 + w * 0.3, 1.0), 0.45, 1.0, 0.8 * (1.0 - a)))
				for k in 5:
					var ang := TAU * k / 5.0 - w * 2.0
					Icons.star(ci, c + Vector2(cos(ang), sin(ang)) * W * (0.4 + 0.6 * a), W * 0.12 * (1.0 - a), Color(1, 0.95, 0.6, 1.0 - a))


## The shark's hoop: a red-and-white circus hoop standing across its way, ahead of it. The far half goes
## under the shark, the near half over (so it leaps through), and splashes where it goes in and comes out.
static func _shark_overlay(ci: CanvasItem, w: float, size: float, under: bool) -> void:
	var W := size * 0.46
	var T := time("shark")
	var show := clampf(w / 0.15, 0.0, 1.0) * clampf((T - w) / 0.3, 0.0, 1.0)
	var hc := Vector2(size * SHARK_HOOP, 0)
	var rx := W * 0.22 * show
	var ry := W * 0.95 * show
	# Half the hoop: red and white stripes round an ellipse, the far side (left of its middle) or the near.
	var from := PI * 0.5 if under else -PI * 0.5
	var n := 14
	for k in n:
		var a0 := from + PI * k / n
		var a1 := from + PI * (k + 1) / n
		var p0 := hc + Vector2(cos(a0) * rx, sin(a0) * ry)
		var p1 := hc + Vector2(cos(a1) * rx, sin(a1) * ry)
		ci.draw_line(p0, p1, Color("e8323c") if k % 2 == 0 else Color.WHITE, W * 0.12 * show, true)
	if not under:
		return
	# Splashes: where it dives in, and where it lands.
	for spot in [[Vector2.ZERO, 0.25], [Vector2(size * SHARK_LAND, 0), 0.85]]:
		var age: float = w - float(spot[1])
		if age < 0.0 or age > 0.7:
			continue
		var a := age / 0.7
		for k in 2:
			ci.draw_arc(spot[0], W * (0.3 + 0.7 * clampf(a - k * 0.15, 0.0, 1.0)), 0, TAU, 32, Color(0.75, 0.9, 1.0, 0.9 * (1.0 - a)), W * 0.06, true)
		for k in 6:
			var ang := TAU * k / 6.0
			ci.draw_circle(spot[0] + Vector2(cos(ang), sin(ang)) * W * 0.6 * a, W * 0.07 * (1.0 - a), Color(0.75, 0.9, 1.0))


## Zero's win, a deckbuilder's turn: a hand of three cards fans out over him (an energy orb beside it, 3/3),
## the middle one (Zoomies) lifts and glows, he plays it (2/3), it flies into him with a burst, the others
## drop away, and he does them (the spin's in pose()). Upright on screen whatever way he faces.
static func _zero_cards(ci: CanvasItem, w: float, size: float, rot: float) -> void:
	var W := size * 0.46
	var up := Vector2.UP.rotated(-rot)
	var hand_c := up * W * 1.5
	var deal := _ease(w / 0.3)
	var lift := _ease((w - 0.35) / 0.3)
	var play := _ease((w - 0.7) / 0.15)
	var gone := _ease((w - 0.7) / 0.25)
	var cards := [["Strike", Color("d9534f"), "sword"], ["Zoomies", Color("e07b39"), "paw"], ["Defend", Color("4caf7a"), "shield"]]
	var cw := W * 0.85
	var ch := W * 1.18
	for i in 3:
		var mid := i == 1
		var spread := (i - 1) * W * 0.8 * deal
		var at := hand_c + Vector2(spread, 0).rotated(-rot) + up * W * 0.25 * absf(i - 1)
		var ang := (i - 1) * 0.28 * deal
		var sc := deal
		var a := 1.0
		if mid:
			at += up * W * 0.4 * lift
			sc *= 1.0 + 0.25 * lift
			# Played: it flies into him and shrinks away.
			at = at.lerp(Vector2.ZERO, play)
			sc *= 1.0 - 0.8 * play
			a = 1.0 - play
		else:
			at -= up * W * 1.2 * gone
			a = 1.0 - gone
		if sc <= 0.01 or a <= 0.01:
			continue
		ci.draw_set_transform(at, -rot + ang, Vector2.ONE * sc)
		if mid and lift > 0.0:
			DrawUtil.rrect(ci, Rect2(-cw / 2.0 - W * 0.1, -ch / 2.0 - W * 0.1, cw + W * 0.2, ch + W * 0.2), Color(1.0, 0.9, 0.4, 0.55 * lift * a), W * 0.22)
		_card(ci, cw, ch, str(cards[i][0]), cards[i][1], str(cards[i][2]), a, W)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The energy orb, left of the hand: 3/3, then 2/3 as the card's played.
	if deal > 0.0 and w < 1.7:
		var oa := deal * clampf((1.7 - w) / 0.3, 0.0, 1.0)
		var oc := hand_c + Vector2(-W * 1.55, W * 0.3).rotated(-rot)
		var bump := 1.0 + 0.3 * clampf(1.0 - absf(w - 0.7) / 0.12, 0.0, 1.0)
		ci.draw_set_transform(oc, -rot, Vector2.ONE * bump)
		ci.draw_circle(Vector2.ZERO, W * 0.36, Color(0.3, 0.1, 0.05, 0.5 * oa))
		ci.draw_circle(Vector2.ZERO, W * 0.32, Color(1.0, 0.55, 0.15, oa))
		ci.draw_circle(Vector2(-W * 0.08, -W * 0.1), W * 0.12, Color(1.0, 0.85, 0.5, 0.7 * oa))
		var txt := "3/3" if w < 0.7 else "2/3"
		var f := UiTheme.font()
		var px := int(W * 0.3)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string_outline(f, Vector2(-tw / 2.0, px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(W * 0.08), Color(0.25, 0.08, 0.02, oa))
		ci.draw_string(f, Vector2(-tw / 2.0, px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, oa))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The burst as it lands, and the word.
	var hit := w - 0.85
	if hit >= 0.0 and hit < 0.4:
		var k := hit / 0.4
		for j in 8:
			var d := Vector2.from_angle(TAU * j / 8.0 + 0.3)
			Icons.star(ci, d * W * (0.4 + 1.2 * k), W * 0.16 * (1.0 - k), Color(1.0, 0.85, 0.3, 1.0 - k))
	if w >= 0.85 and w < 1.95:
		var k := clampf((w - 0.85) / 0.15, 0.0, 1.0)
		var fade := clampf((1.95 - w) / 0.25, 0.0, 1.0)
		var f := UiTheme.font()
		var px := int(W * 0.55)
		var txt := "ZOOMIES!"
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_set_transform(up * W * 1.3, -rot - 0.08, Vector2.ONE * (0.6 + 0.4 * k))
		ci.draw_string_outline(f, Vector2(-tw / 2.0, px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(W * 0.12), Color(0.2, 0.08, 0.05, fade))
		ci.draw_string(f, Vector2(-tw / 2.0, px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1.0, 0.8, 0.3, fade))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One card, centred on the current transform's origin: a coloured frame, a cost gem with 1 in it, a name
## banner and a little picture (a sword, a paw, a shield).
static func _card(ci: CanvasItem, cw: float, ch: float, title: String, col: Color, art: String, a: float, W: float) -> void:
	var r := Rect2(-cw / 2.0, -ch / 2.0, cw, ch)
	DrawUtil.rrect(ci, Rect2(r.position + Vector2(0, W * 0.06), r.size), Color(0, 0, 0, 0.3 * a), W * 0.14)
	DrawUtil.rrect(ci, r, Color(col.darkened(0.35), a), W * 0.14)
	DrawUtil.rrect(ci, r.grow(-W * 0.06), Color(col, a), W * 0.11)
	var pic := Rect2(r.position.x + W * 0.14, r.position.y + ch * 0.3, cw - W * 0.28, ch * 0.42)
	DrawUtil.rrect(ci, pic, Color(0.98, 0.95, 0.88, a), W * 0.06)
	var pc := pic.get_center()
	var ink := Color(0.16, 0.12, 0.2, a)
	match art:
		"sword":
			ci.draw_line(pc + Vector2(-W * 0.2, W * 0.2), pc + Vector2(W * 0.2, -W * 0.2), ink, W * 0.07)
			ci.draw_line(pc + Vector2(-W * 0.2, W * 0.02), pc + Vector2(-W * 0.02, W * 0.2), ink, W * 0.06)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([pc + Vector2(-W * 0.18, -W * 0.2), pc + Vector2(W * 0.18, -W * 0.2),
				pc + Vector2(W * 0.16, W * 0.04), pc + Vector2(0, W * 0.22), pc + Vector2(-W * 0.16, W * 0.04)]), ink)
		_:
			ci.draw_circle(pc + Vector2(0, W * 0.06), W * 0.12, ink)
			for k in 4:
				ci.draw_circle(pc + Vector2((k - 1.5) * W * 0.1, -W * 0.1 - (W * 0.03 if k in [1, 2] else 0.0)), W * 0.05, ink)
	# The name banner, and the cost gem in the corner.
	var f := UiTheme.font()
	var px := maxi(int(W * 0.22), 6)
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	DrawUtil.rrect(ci, Rect2(r.position.x + W * 0.08, r.position.y + ch * 0.1, cw - W * 0.16, px * 1.3), Color(0.98, 0.95, 0.88, a), W * 0.05)
	ci.draw_string(f, Vector2(-tw / 2.0, r.position.y + ch * 0.1 + px * 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
	var gem := r.position + Vector2(W * 0.08, W * 0.08)
	ci.draw_circle(gem, W * 0.17, Color(0.3, 0.1, 0.05, a))
	ci.draw_circle(gem, W * 0.14, Color(1.0, 0.55, 0.15, a))
	var cpx := maxi(int(W * 0.2), 6)
	var cw2 := f.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, cpx).x
	ci.draw_string(f, gem + Vector2(-cw2 / 2.0, cpx * 0.35), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, cpx, Color(1, 1, 1, a))
	# A line of rules text, too small to read (it's a card).
	for l in 2:
		var y := r.position.y + ch * 0.8 + l * W * 0.08
		ci.draw_line(Vector2(r.position.x + W * 0.18, y), Vector2(r.end.x - W * (0.18 + 0.2 * l), y), Color(1, 1, 1, 0.55 * a), W * 0.03)

