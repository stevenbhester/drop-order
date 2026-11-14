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
##   race_car       two donuts in a cloud of tyre smoke  1.7 s
##   bassinet       shudders, eyes going everywhere      1.4 s
##   caterpillar    tosses a green package and eats it   1.8 s
##   minivan        doors slide open, BEEP BEEP          1.4 s
##   pillow_tower   a tiny someone jumps into the puddle 1.7 s

const TIMES := {"": 0.7, "monster_truck": 1.4, "scooter": 1.1, "ice_cream": 1.2, "rocket_van": 1.1, "hover_van": 1.2,
	"race_car": 1.7, "bassinet": 1.4, "caterpillar": 1.8, "minivan": 1.4, "pillow_tower": 1.7}


static func time(ride: String) -> float:
	return TIMES.get(ride, 0.8)


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
			# Two donuts round a point just behind it.
			var a := TAU * 2.0 * _ease(u)
			rot = a
			pos = (Vector2(cos(a), sin(a)) - Vector2(1, 0)) * size * 0.16
		"bassinet":
			pos = Vector2(sin(w * 47.0), cos(w * 39.0)) * size * 0.025 * fade
			rot = sin(w * 31.0) * 0.09 * fade
		"caterpillar":
			var chomp := clampf(1.0 - absf(w - 0.8) / 0.12, 0.0, 1.0)
			sc = Vector2(1.0 + 0.08 * chomp, 1.0 - 0.06 * chomp)
		"minivan":
			var beep := maxf(clampf(1.0 - absf(w - 0.4) / 0.1, 0.0, 1.0), clampf(1.0 - absf(w - 0.75) / 0.1, 0.0, 1.0))
			sc = Vector2.ONE * (1.0 + 0.06 * beep)
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
			return [[0.0, "screech", 1.0, -2.0], [0.8, "screech", 1.1, -4.0], [0.05, "whoosh", 0.9, -6.0]]
		"bassinet":
			return [[0.0, "studio_creak", 0.7, -2.0], [0.15, "punch", 0.6, -8.0], [0.6, "studio_creak", 0.55, -4.0]]
		"caterpillar":
			return [[0.0, "pop", 1.2, -4.0], [0.78, "thunk", 1.3, -2.0], [0.95, "studio_goo", 1.4, -4.0]]
		"minivan":
			return [[0.0, "whoosh", 0.7, -8.0], [0.38, "beep", 1.0, -2.0], [0.73, "beep", 1.0, -2.0]]
		"pillow_tower":
			return [[0.15, "pop", 1.6, -4.0], [0.95, "studio_gush", 1.6, -4.0], [0.95, "sparkle", 1.3, -8.0]]
	return []


## Drawn with the ride, in the van's space (not turned by pose()); `rot` is the van's turn on screen, so
## words and emoji can stand upright. `under`: the layer beneath the ride (smoke, splashes), else above it.
static func overlay(ci: CanvasItem, ride: String, w: float, size: float, rot: float, under := false) -> void:
	var L := size * 0.74
	var W := size * 0.46
	var up := Vector2.UP.rotated(-rot)
	var f := UiTheme.font()
	if under and not (ride in ["race_car", "pillow_tower"]):
		return
	match ride:
		"race_car":
			if not under:
				return
			# Tyre smoke left round the donut.
			var T := time(ride)
			for k in 14:
				var age := w - k * 0.09
				if age < 0.0 or age > 0.9 or k * 0.09 > T:
					continue
				var a := TAU * 2.0 * _ease(clampf(k * 0.09 / T, 0.0, 1.0))
				var p := (Vector2(cos(a), sin(a)) - Vector2(1, 0)) * size * 0.16 - Vector2(cos(a), sin(a)) * L * 0.3
				ci.draw_circle(p, W * (0.25 + 0.5 * age), Color(0.85, 0.85, 0.88, 0.5 * (1.0 - age / 0.9)))
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
				DrawUtil.rrect(ci, Rect2(-tw / 2.0 - W * 0.12, -W * 0.36, tw + W * 0.24, W * 0.52), Color(1, 1, 1, 0.95 * (1.0 - age / 0.5)), W * 0.2)
				ci.draw_string(f, Vector2(-tw / 2.0, W * 0.08), "BEEP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(W * 0.5), Color(Palette.TEXT, 1.0 - age / 0.5))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pillow_tower":
			# A tiny someone hops off the top of the stack and into the puddle. Splash.
			var top := up * W * 0.2 * 7.0
			var pc := FriendRides.puddle_at(L, W, up)
			var u := clampf((w - 0.15) / 0.8, 0.0, 1.0)
			if w >= 0.15 and w < 0.95 and not under:
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
