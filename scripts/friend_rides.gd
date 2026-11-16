class_name FriendRides
extends RefCounted
## The friends' rides (Cosmetics), drawn in code, top-down, facing +x, `L` long and `W` wide like the van.
## `t` is time (idle wiggles); `win` is seconds into the win celebration (RideWins), or -1; `up` is which way
## is up on screen in the ride's own space (the pillow tower stacks that way, whichever way it's driving).
## Each returns where the topper goes.
##   race_car      Sam's Race Car: a dark-navy open-wheel racer with red and yellow trim and a yellow nose.
##   bassinet      James' Evil Bassinet: a black wicker pram, red eyes glowing under the hood.
##   caterpillar   Tara's Hungry Caterpillar: green segments, a big friendly head, antennae.
##   minivan       Orin's Green Car: a big forest-green minivan with sliding doors and a roof rack.
##   pillow_tower  Violet's Tower: a wobbly stack of pillows on casters, with a little blue puddle beside it.
##   shark         Howard's Shark: swimming, tail swishing, in a little wake of its own.
##   eazy_van      Sheena's Eazy Van: a sky-blue split-window bus, cream roof, roof rack, rainbow waves.
##   dreamsicle    Tay's Dreamsicle: an orange-and-vanilla popsicle on its stick, dripping a little.
##   classic_car   Cole's Classic: a silver sports car, round frog-eye headlights, wide hips.
##   lab           Twinkle's Lab: a wheeled lab bench of flasks, tubes and a burner, all bubbling.
##   zero          Zero the Steed: a fluffy black dog, white blaze and muzzle, amber eyes, a saddle blanket.


static func draw(ci: CanvasItem, id: String, L: float, W: float, cargo: Variant, t: float, paint: String, win: float, up: Vector2, base := Transform2D.IDENTITY) -> Vector2:
	match id:
		"race_car":
			return _race_car(ci, L, W, cargo, t, paint, win)
		"bassinet":
			return _bassinet(ci, L, W, cargo, t, paint, win)
		"caterpillar":
			return _caterpillar(ci, L, W, cargo, t, paint, win)
		"minivan":
			return _minivan(ci, L, W, cargo, t, paint, win)
		"pillow_tower":
			return _pillow_tower(ci, L, W, cargo, t, paint, win, up, base)
		"shark":
			return _shark(ci, L, W, cargo, t, paint, win)
		"eazy_van":
			return _eazy_van(ci, L, W, cargo, t, paint, win)
		"dreamsicle":
			return _dreamsicle(ci, L, W, cargo, t, paint, win)
		"classic_car":
			return _classic_car(ci, L, W, cargo, t, paint, win)
		"lab":
			return _lab(ci, L, W, cargo, t, paint, win)
		"zero":
			return _zero(ci, L, W, cargo, t, paint, win)
	return Vector2.ZERO


static func _cols(id: String, paint: String) -> Array:
	if paint != "" and paint != "classic" and Cosmetics.ITEMS.has(paint):
		return [Cosmetics.body_color(paint), Cosmetics.cab_color(paint)]
	return [Cosmetics.ITEMS[id]["body"], Cosmetics.ITEMS[id]["cab"]]


static func _poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)


## Sam's Race Car: low and long, four big exposed tyres, front and rear wings, sidepods with a red sweep
## and a yellow sun, a yellow nose, the cockpit with its halo (the topper sits on the driver's helmet).
static func _race_car(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("race_car", paint)
	var navy: Color = cols[0]
	var red: Color = cols[1]
	var yellow := Color("ffd200")
	var tire := Color("16161a")
	DrawUtil.rrect(ci, Rect2(-L * 0.6, -W * 0.7, L * 1.2, W * 1.4), Color(0, 0, 0, 0.16), W * 0.3)
	# Tyres: fat at the back, a red sidewall stripe.
	for spec in [[-0.34, 0.27, 0.5], [0.3, 0.22, 0.42]]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(L * float(spec[0]), sy * W * 0.55)
			var r := Rect2(c - Vector2(L * float(spec[1]) / 2.0, W * float(spec[2]) / 2.0), Vector2(L * float(spec[1]), W * float(spec[2])))
			DrawUtil.rrect(ci, r, tire, W * 0.08)
			ci.draw_line(Vector2(r.position.x + W * 0.03, c.y - sy * r.size.y * 0.32), Vector2(r.end.x - W * 0.03, c.y - sy * r.size.y * 0.32), Color("e4002b"), W * 0.035)
	# Rear wing and front wing.
	DrawUtil.rrect(ci, Rect2(-L * 0.56, -W * 0.46, L * 0.11, W * 0.92), navy.darkened(0.2), W * 0.04)
	for sy in [-1.0, 1.0]:
		DrawUtil.rrect(ci, Rect2(-L * 0.57, sy * W * 0.46 - W * 0.05, L * 0.13, W * 0.1), red, W * 0.03)
	DrawUtil.rrect(ci, Rect2(L * 0.42, -W * 0.62, L * 0.1, W * 1.24), navy, W * 0.04)
	for sy in [-1.0, 1.0]:
		DrawUtil.rrect(ci, Rect2(L * 0.41, sy * W * 0.62 - W * 0.05, L * 0.12, W * 0.1), red, W * 0.03)
	# Nose: tapering to a yellow tip.
	_poly(ci, [Vector2(L * 0.08, -W * 0.15), Vector2(L * 0.47, -W * 0.07), Vector2(L * 0.54, 0), Vector2(L * 0.47, W * 0.07), Vector2(L * 0.08, W * 0.15)], navy)
	_poly(ci, [Vector2(L * 0.42, -W * 0.08), Vector2(L * 0.55, 0), Vector2(L * 0.42, W * 0.08)], yellow)
	# Body and sidepods.
	DrawUtil.rrect(ci, Rect2(-L * 0.48, -W * 0.16, L * 0.6, W * 0.32), navy, W * 0.14)
	DrawUtil.rrect(ci, Rect2(-L * 0.24, -W * 0.34, L * 0.36, W * 0.68), navy, W * 0.2)
	if not (paint != "" and paint != "classic"):
		for sy in [-1.0, 1.0]:
			_poly(ci, [Vector2(L * 0.1, sy * W * 0.3), Vector2(-L * 0.04, sy * W * 0.2), Vector2(-L * 0.22, sy * W * 0.31), Vector2(-L * 0.06, sy * W * 0.33)], red)
		ci.draw_circle(Vector2(-L * 0.3, 0), W * 0.07, yellow)
	else:
		Cosmetics.draw_pattern(ci, paint, Rect2(-L * 0.22, -W * 0.32, L * 0.32, W * 0.64))
	# Engine cover: the cargo rides on it.
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-L * 0.17, 0), W * 0.34, cargo, false)
	# Cockpit and halo.
	var ck := Vector2(L * 0.06, 0)
	DrawUtil.rrect(ci, Rect2(ck - Vector2(L * 0.07, W * 0.1), Vector2(L * 0.14, W * 0.2)), Color("0d0f1a"), W * 0.08)
	ci.draw_circle(ck + Vector2(-L * 0.01, 0), W * 0.085, Color("f2f2f5"))
	ci.draw_circle(ck + Vector2(L * 0.01, 0), W * 0.05, Color("2a7fff"))
	ci.draw_arc(ck + Vector2(L * 0.02, 0), W * 0.14, -PI * 0.55, PI * 0.55, 16, Color("b9bec8"), W * 0.035, true)
	ci.draw_line(ck + Vector2(L * 0.08, 0), ck + Vector2(L * 0.13, 0), Color("b9bec8"), W * 0.035, true)
	return ck


## James' Evil Bassinet: a pram of black wicker, four spindly wheels, a blanket at the back (the cargo lies on
## it), and under the hood at the front, two red eyes that glow, blink, and on a win go completely wild.
static func _bassinet(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("bassinet", paint)
	var wicker: Color = cols[0]
	var hood: Color = cols[1]
	DrawUtil.rrect(ci, Rect2(-L * 0.55, -W * 0.6, L * 1.1, W * 1.25), Color(0, 0, 0, 0.18), W * 0.4)
	# Spindly wheels with spokes.
	for sx in [-0.34, 0.34]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(L * sx, sy * W * 0.52)
			ci.draw_circle(c, W * 0.12, Color("1a1420"))
			ci.draw_circle(c, W * 0.085, Color("4a3b55"))
			for k in 3:
				var a := t * 6.0 + k * PI / 3.0
				ci.draw_line(c - Vector2(cos(a), sin(a)) * W * 0.08, c + Vector2(cos(a), sin(a)) * W * 0.08, Color("1a1420"), W * 0.02)
	# The basket.
	DrawUtil.rrect(ci, Rect2(-L * 0.48, -W * 0.46, L * 0.96, W * 0.92), wicker.darkened(0.3), W * 0.42)
	DrawUtil.rrect(ci, Rect2(-L * 0.45, -W * 0.42, L * 0.9, W * 0.84), wicker, W * 0.38)
	for k in 7:
		var x := -L * 0.4 + k * L * 0.12
		ci.draw_line(Vector2(x, -W * 0.38), Vector2(x + L * 0.05, W * 0.38), Color(wicker.lightened(0.15), 0.5), W * 0.025)
	# Blanket at the back, with the cargo on it.
	DrawUtil.rrect(ci, Rect2(-L * 0.4, -W * 0.33, L * 0.42, W * 0.66), Color("6b4f8a"), W * 0.2)
	for k in 3:
		ci.draw_line(Vector2(-L * 0.36 + k * L * 0.13, -W * 0.3), Vector2(-L * 0.36 + k * L * 0.13, W * 0.3), Color("8c6bb1"), W * 0.03)
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-L * 0.2, 0), W * 0.36, cargo, false)
	# The hood over the front, scalloped, and the darkness under it.
	var hc := Vector2(L * 0.2, 0)
	DrawUtil.rrect(ci, Rect2(hc - Vector2(L * 0.04, W * 0.44), Vector2(L * 0.32, W * 0.88)), hood, W * 0.36)
	for k in 5:
		ci.draw_circle(Vector2(hc.x - L * 0.04, -W * 0.34 + k * W * 0.17), W * 0.09, hood)
	DrawUtil.rrect(ci, Rect2(hc + Vector2(L * 0.0, -W * 0.3), Vector2(L * 0.2, W * 0.6)), Color("07040a"), W * 0.26)
	# The eyes. Idle: a slow glow and the odd blink. Win: they dart about, more of them open up, all red.
	var blink := fmod(t, 3.1) < 0.12 and win < 0.0
	var glow := 0.55 + 0.25 * sin(t * 2.3)
	var eyes := [Vector2(L * 0.13, -W * 0.13), Vector2(L * 0.13, W * 0.13)]
	if win >= 0.0:
		glow = 1.0
		var extra := mini(int(win * 6.0), 4)
		var spots := [Vector2(L * 0.2, 0), Vector2(L * 0.07, -W * 0.22), Vector2(L * 0.07, W * 0.22), Vector2(L * 0.22, -W * 0.22)]
		for k in extra:
			eyes.append(spots[k])
	for i in eyes.size():
		var e: Vector2 = eyes[i]
		var r := W * (0.085 if i < 2 else 0.055)
		ci.draw_circle(e, r * 1.9, Color(1, 0.1, 0.1, 0.18 * glow))
		if blink:
			ci.draw_line(e - Vector2(0, r), e + Vector2(0, r), Color("ff3030"), W * 0.025)
			continue
		ci.draw_circle(e, r, Color(1.0, 0.15 + 0.2 * glow, 0.1))
		var look := Vector2(cos(t * 0.7), sin(t * 0.9)) * r * 0.3
		if win >= 0.0:
			look = Vector2(cos(win * 31.0 + i * 2.0), sin(win * 27.0 + i * 1.3)) * r * 0.45
		# A slit pupil.
		ci.draw_line(e + look - Vector2(r * 0.55, 0), e + look + Vector2(r * 0.55, 0), Color("120004"), r * 0.32)
	return Vector2(L * 0.32, 0)


## Tara's Hungry Caterpillar: green segments (the cargo rides on the middle one) on little legs, a big round
## head with happy eyes and two antennae. On a win it tosses a green package up, catches it in its mouth and
## gulps it down the length of its body.
static func _caterpillar(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("caterpillar", paint)
	var green: Color = cols[0]
	var head_col: Color = cols[1]
	var n := 5
	var dur := 1.8
	# Win timing: the toss (0..0.7), the chomp (0.7..0.9), then the gulp travels back (0.9..1.6).
	var gulp := -1.0
	var mouth := 0.0
	if win >= 0.0:
		mouth = smoothstep(0.35, 0.65, win) * (1.0 - smoothstep(0.72, 0.82, win))
		if win >= 0.82:
			gulp = (win - 0.82) / 0.8
	var pts := []
	for i in n:
		var x := -L * 0.46 + i * L * 0.19
		var wave := sin(t * 6.0 - i * 0.9) * W * 0.06
		pts.append(Vector2(x, wave))
	DrawUtil.rrect(ci, Rect2(-L * 0.6, -W * 0.48, L * 1.2, W * 0.98), Color(0, 0, 0, 0.14), W * 0.4)
	for i in n:
		var p: Vector2 = pts[i]
		var r := W * (0.27 + 0.025 * i)
		if gulp >= 0.0 and gulp <= 1.0:
			var at := (n - 1) - gulp * (n - 1)
			r *= 1.0 + 0.3 * maxf(0.0, 1.0 - absf(i - at))
		# Little legs.
		for sy in [-1.0, 1.0]:
			var lg := sin(t * 10.0 + i) * W * 0.03
			ci.draw_line(p + Vector2(lg, sy * r * 0.7), p + Vector2(lg, sy * (r + W * 0.08)), Color("2c3a22"), W * 0.05, true)
		ci.draw_circle(p, r, green.darkened(0.15) if i % 2 == 0 else green)
		ci.draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.22))
	if cargo is Color and win < 0.0:
		DrawUtil.package(ci, pts[2], W * 0.36, cargo, false)
	# The head.
	var hp: Vector2 = Vector2(L * 0.44, sin(t * 6.0 + 0.9) * W * 0.06)
	var hr := W * 0.38
	for sy in [-1.0, 1.0]:
		var tip := hp + Vector2(L * 0.1, sy * W * 0.36) + Vector2(sin(t * 5.0 + sy) * W * 0.04, 0)
		ci.draw_line(hp + Vector2(0, sy * hr * 0.4), tip, Color("2c3a22"), W * 0.045, true)
		ci.draw_circle(tip, W * 0.07, Color("ff9f43"))
	ci.draw_circle(hp, hr, head_col)
	ci.draw_circle(hp + Vector2(-hr * 0.3, -hr * 0.35), hr * 0.3, Color(1, 1, 1, 0.25))
	for sy in [-1.0, 1.0]:
		var e := hp + Vector2(hr * 0.15, sy * hr * 0.38)
		ci.draw_circle(e, hr * 0.24, Color.WHITE)
		ci.draw_circle(e + Vector2(hr * 0.08, 0), hr * 0.13, Color("1d1f26"))
		ci.draw_circle(e + Vector2(hr * 0.12, -hr * 0.05), hr * 0.05, Color.WHITE)
		ci.draw_circle(hp + Vector2(-hr * 0.15, sy * hr * 0.62), hr * 0.13, Color(1, 0.5, 0.55, 0.45))
	# Mouth: a smile, or wide open for the catch.
	if mouth > 0.05:
		DrawUtil.rrect(ci, Rect2(hp + Vector2(hr * 0.45 - hr * 0.2 * mouth, -hr * 0.3 * mouth - hr * 0.06), Vector2(hr * 0.45 * mouth + hr * 0.1, hr * 0.6 * mouth + hr * 0.12)), Color("5a1f2a"), hr * 0.2)
	else:
		ci.draw_arc(hp + Vector2(hr * 0.42, 0), hr * 0.3, -PI * 0.45, PI * 0.45, 12, Color("2c3a22"), W * 0.04, true)
	# The tossed package: up off its back, over and into the mouth (bigger near the top of its arc).
	if win >= 0.0 and win < 0.78:
		var u := clampf(win / 0.75, 0.0, 1.0)
		var from: Vector2 = pts[2]
		var to := hp + Vector2(hr * 0.55, 0)
		var at := from.lerp(to, u)
		var height := sin(PI * u)
		DrawUtil.package(ci, at, W * (0.36 + 0.3 * height), Palette.pkg("green"), true)
	return hp + Vector2(-hr * 0.1, 0)


## Orin's Green Car: a long forest-green minivan, windscreen at the front, a roof rack (the cargo rides on it),
## a sliding door down each side (they slide open on a win) and headlights.
static func _minivan(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("minivan", paint)
	var body: Color = cols[0]
	var trim: Color = cols[1]
	var LL := L * 1.12
	var WW := W * 1.06
	DrawUtil.rrect(ci, Rect2(-LL / 2 - 4, -WW / 2 - 2, LL + 8, WW + 12), Color(0, 0, 0, 0.2), WW * 0.3)
	for sx in [-0.3, 0.3]:
		for sy in [-1.0, 1.0]:
			DrawUtil.rrect(ci, Rect2(Vector2(LL * sx - LL * 0.08, sy * WW * 0.5 - WW * 0.08), Vector2(LL * 0.16, WW * 0.16)), Palette.WHEEL, WW * 0.05)
	DrawUtil.rrect(ci, Rect2(-LL / 2, -WW / 2, LL, WW), body, WW * 0.26)
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, Rect2(-LL / 2 + WW * 0.1, -WW / 2 + WW * 0.1, LL * 0.6, WW * 0.8))
	# The sliding doors, one each side: on a win they slide back, showing the seats inside.
	var open := 0.0
	if win >= 0.0:
		open = smoothstep(0.0, 0.25, win) * (1.0 - smoothstep(1.1, 1.35, win))
	for sy in [-1.0, 1.0]:
		var door := Rect2(Vector2(-LL * 0.08, sy * WW * 0.5 - (WW * 0.1 if sy < 0 else 0.0)), Vector2(LL * 0.26, WW * 0.1))
		if open > 0.0:
			DrawUtil.rrect(ci, Rect2(door.position + Vector2(0, -sy * WW * 0.12 if sy > 0 else 0.0), Vector2(door.size.x, WW * 0.22)), Color("1c1f26"), WW * 0.04)
			for k in 2:
				DrawUtil.rrect(ci, Rect2(Vector2(-LL * 0.05 + k * LL * 0.11, sy * WW * 0.3 - WW * 0.06), Vector2(LL * 0.08, WW * 0.12)), Color("b98a5e"), WW * 0.03)
		var shift := -LL * 0.22 * open
		DrawUtil.rrect(ci, Rect2(door.position + Vector2(shift, 0), door.size), body.darkened(0.12), WW * 0.03)
		ci.draw_line(door.position + Vector2(shift + door.size.x * 0.2, door.size.y * 0.5), door.position + Vector2(shift + door.size.x * 0.35, door.size.y * 0.5), Color(1, 1, 1, 0.5), WW * 0.02)
	# Windscreen and bonnet at the front, back window.
	DrawUtil.rrect(ci, Rect2(LL * 0.26, -WW * 0.4, LL * 0.12, WW * 0.8), Palette.VAN_GLASS, WW * 0.1)
	DrawUtil.rrect(ci, Rect2(-LL * 0.47, -WW * 0.36, LL * 0.06, WW * 0.72), Palette.VAN_GLASS.darkened(0.1), WW * 0.06)
	DrawUtil.rrect(ci, Rect2(LL * 0.38, -WW * 0.42, LL * 0.1, WW * 0.84), body.lightened(0.06), WW * 0.16)
	for sy in [-1.0, 1.0]:
		ci.draw_circle(Vector2(LL * 0.47, sy * WW * 0.32), WW * 0.07, Color("ffe28a"))
		# Mirrors.
		DrawUtil.rrect(ci, Rect2(Vector2(LL * 0.26, sy * WW * 0.5 - WW * 0.05), Vector2(LL * 0.05, WW * 0.1)), trim, WW * 0.03)
	# Roof rack: two rails and the cargo strapped between.
	for sy in [-1.0, 1.0]:
		DrawUtil.rrect(ci, Rect2(Vector2(-LL * 0.36, sy * WW * 0.3 - WW * 0.03), Vector2(LL * 0.56, WW * 0.06)), trim, WW * 0.03)
	for k in 3:
		ci.draw_line(Vector2(-LL * 0.3 + k * LL * 0.22, -WW * 0.3), Vector2(-LL * 0.3 + k * LL * 0.22, WW * 0.3), trim, WW * 0.035)
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-LL * 0.08, 0), WW * 0.5, cargo, false)
	return Vector2(LL * 0.18, 0)


## Violet's Tower: a tall stack of pillows on casters, each a different colour, wobbling more the higher they
## go, stacked "up" the screen whichever way it's facing. Beside it, a little blue puddle (for the win, see
## RideWins). Returns the top pillow, where the topper (and the cargo) go.
## `base` is whatever transform the caller is drawing under (a preview tile's): the pillows turn within it.
static func _pillow_tower(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float, up: Vector2, base := Transform2D.IDENTITY) -> Vector2:
	var cols := _cols("pillow_tower", paint)
	var pillows := [cols[0], Color("ffb3c7"), Color("b8f0d2"), Color("fff1c2"), Color("bfe3ff"), Color("ffd2a8"), cols[1]]
	var side := Vector2(-up.y, up.x)
	# The puddle, off to one side.
	var pc := puddle_at(L, W, up)
	ci.draw_set_transform_matrix(base * Transform2D(up.angle() + PI / 2.0, Vector2(1.0, 0.6), 0.0, pc))
	ci.draw_circle(Vector2.ZERO, W * 0.42, Color("4d8dff", 0.55))
	ci.draw_circle(Vector2(-W * 0.08, -W * 0.06), W * 0.28, Color("7fb0ff", 0.55))
	ci.draw_circle(Vector2(W * 0.14, W * 0.1), W * 0.08, Color(1, 1, 1, 0.5))
	ci.draw_set_transform_matrix(base)
	# Shadow and casters.
	ci.draw_circle(Vector2.ZERO, W * 0.5, Color(0, 0, 0, 0.18))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		ci.draw_circle(Vector2(cos(a), sin(a)) * W * 0.36, W * 0.07, Palette.WHEEL)
	var step := W * 0.2
	var top := Vector2.ZERO
	for i in pillows.size():
		var h := i * step
		var wob := sin(t * 3.2 + i * 0.8) * W * 0.012 * i
		if win >= 0.0:
			wob += sin(win * 18.0 + i) * W * 0.02 * i * (1.0 - clampf(win / 1.6, 0.0, 1.0))
		var c := up * h + side * wob
		var sz := Vector2(W * 0.9, W * 0.62) * (1.0 - i * 0.02)
		ci.draw_set_transform_matrix(base * Transform2D(up.angle() + PI / 2.0, Vector2.ONE, 0.0, c))
		DrawUtil.rrect(ci, Rect2(-sz / 2.0 + Vector2(0, W * 0.05), sz), Color(0, 0, 0, 0.12), W * 0.22)
		DrawUtil.rrect(ci, Rect2(-sz / 2.0, sz), pillows[i], W * 0.24)
		ci.draw_line(Vector2(-sz.x * 0.3, 0), Vector2(sz.x * 0.3, 0), Color(1, 1, 1, 0.35), W * 0.025)
		for cx in [-1.0, 1.0]:
			for cy in [-1.0, 1.0]:
				ci.draw_circle(Vector2(cx * sz.x * 0.42, cy * sz.y * 0.36), W * 0.05, Color(pillows[i]).darkened(0.08))
		ci.draw_set_transform_matrix(base)
		top = c
	if cargo is Color:
		DrawUtil.package(ci, top + up * W * 0.12, W * 0.34, cargo, false)
	return top + up * W * 0.2


## Where Violet's puddle sits, in the ride's space.
static func puddle_at(L: float, W: float, up: Vector2) -> Vector2:
	var side := Vector2(-up.y, up.x)
	return side * W * 0.95 - up * W * 0.15


## Scaled points: `pts` in units of (L, W), mirrored across the middle (the top half given, nose first or
## tail first, whichever: it's walked down one side and back up the other).
static func _mirror(pts: Array, L: float, W: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * L, p.y * W))
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		if absf(p.y) > 0.001:
			out.append(Vector2(p.x * L, -p.y * W))
	return out


## A rounded rectangle as a polygon (for clipping).
static func _rrect_poly(r: Rect2, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		for s in 7:
			var a := -PI / 2.0 + k * PI / 2.0 + s / 6.0 * PI / 2.0
			out.append(cs[k] + Vector2(cos(a), sin(a)) * rad)
	return out


static func _circle_poly(c: Vector2, r: float, n := 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		out.append(c + Vector2(cos(TAU * k / n), sin(TAU * k / n)) * r)
	return out


## Howard's Shark: a sleek grey-blue back (it's swimming, seen from above), a dorsal fin, pectoral fins out to
## the sides, the tail swishing, beady eyes, gills, and a little wake behind it. The cargo rides just behind
## its head. Its win (RideWins) is a leap through a hoop: this just swishes harder.
static func _shark(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("shark", paint)
	var skin: Color = cols[0]
	var pale: Color = cols[1]
	var wag := sin(t * 7.0) * 0.32
	if win >= 0.0:
		wag = sin(win * 22.0) * 0.5
	# Its wake.
	for k in 3:
		ci.draw_arc(Vector2(-L * (0.32 + k * 0.13), 0), W * (0.34 + k * 0.12), PI * 0.62, PI * 1.38, 18, Color(1, 1, 1, 0.3 - k * 0.08), W * 0.04, true)
	ci.draw_colored_polygon(_mirror([Vector2(0.56, 0), Vector2(0.4, 0.34), Vector2(0.0, 0.46), Vector2(-0.42, 0.22), Vector2(-0.6, 0)], L, W), Color(0, 0, 0, 0.14))
	# The body bends with the tail: points behind the middle swing with it.
	var top := [Vector2(0.54, 0.0), Vector2(0.52, 0.07), Vector2(0.45, 0.19), Vector2(0.32, 0.3), Vector2(0.15, 0.36), Vector2(-0.05, 0.33),
		Vector2(-0.25, 0.19), Vector2(-0.38, 0.08)]
	var body := PackedVector2Array()
	var bend := func(p: Vector2) -> Vector2:
		var k := clampf(-p.x / 0.4, 0.0, 1.0)
		return Vector2(p.x * L, p.y * W + wag * W * 0.5 * k * k)
	for p in top:
		body.append(bend.call(p))
	for i in range(top.size() - 1, -1, -1):
		var p: Vector2 = top[i]
		if p.y > 0.001:
			body.append(bend.call(Vector2(p.x, -p.y)))
	# Pectoral fins, out to the sides.
	for sy in [-1.0, 1.0]:
		_poly(ci, [Vector2(L * 0.14, sy * W * 0.3), Vector2(-L * 0.1, sy * W * 0.66), Vector2(-L * 0.02, sy * W * 0.28)], skin.darkened(0.15))
	# The tail: a crescent on the end of the stalk, swishing.
	var stalk: Vector2 = bend.call(Vector2(-0.38, 0.0))
	var ta := wag * 1.2
	var fin_a := stalk + Vector2(-L * 0.2, -W * 0.38).rotated(ta)
	var fin_b := stalk + Vector2(-L * 0.2, W * 0.38).rotated(ta)
	_poly(ci, [stalk + Vector2(L * 0.03, 0).rotated(ta), fin_a, stalk + Vector2(-L * 0.08, 0).rotated(ta), fin_b], skin.darkened(0.12))
	ci.draw_colored_polygon(body, skin)
	# A paler belly line down its back's edges, and a shine.
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, Rect2(-L * 0.18, -W * 0.22, L * 0.4, W * 0.44))
	ci.draw_colored_polygon(_mirror([Vector2(0.44, 0.0), Vector2(0.4, 0.08), Vector2(0.2, 0.12), Vector2(0.0, 0.08), Vector2(-0.1, 0.0)], L, W), Color(pale, 0.35))
	# The dorsal fin: a dark wedge sticking up out of its back (and its shadow).
	var df := [Vector2(L * 0.06, -W * 0.06), Vector2(-L * 0.2, -W * 0.01 + wag * W * 0.1), Vector2(L * 0.06, W * 0.06)]
	_poly(ci, [df[0] + Vector2(W * 0.05, W * 0.06), df[1] + Vector2(W * 0.05, W * 0.06), df[2] + Vector2(W * 0.05, W * 0.06)], Color(0, 0, 0, 0.18))
	_poly(ci, df, skin.darkened(0.3))
	# Gills, eyes.
	for sy in [-1.0, 1.0]:
		for k in 3:
			var gx := L * (0.24 - k * 0.04)
			ci.draw_line(Vector2(gx, sy * W * 0.2), Vector2(gx - L * 0.02, sy * W * 0.3), skin.darkened(0.3), W * 0.022, true)
		var e := Vector2(L * 0.38, sy * W * 0.2)
		ci.draw_circle(e, W * 0.06, Color("11151c"))
		ci.draw_circle(e + Vector2(W * 0.015, -W * 0.02), W * 0.02, Color.WHITE)
	if cargo is Color:
		DrawUtil.package(ci, Vector2(L * 0.2, 0), W * 0.3, cargo, false)
	return Vector2(L * 0.3, 0)


## Sheena's Eazy Van: a split-window bus seen from above. Sky-blue body, a cream roof, the windows down each
## side under its edge (smoke puffs out of them on a win: RideWins), a white roof rack (the cargo's strapped
## to it) and rainbow waves down the flanks.
static func _eazy_van(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("eazy_van", paint)
	var blue: Color = cols[0]
	var cream: Color = cols[1]
	var LL := L * 1.1
	var WW := W * 1.04
	var sway := sin(win * 9.0) * WW * 0.02 if win >= 0.0 else 0.0
	DrawUtil.rrect(ci, Rect2(-LL / 2 - 4, -WW / 2 - 2, LL + 8, WW + 12), Color(0, 0, 0, 0.2), WW * 0.32)
	for sx in [-0.3, 0.32]:
		for sy in [-1.0, 1.0]:
			DrawUtil.rrect(ci, Rect2(Vector2(LL * sx - LL * 0.08, sy * WW * 0.5 - WW * 0.08), Vector2(LL * 0.16, WW * 0.16)), Palette.WHEEL, WW * 0.06)
	DrawUtil.rrect(ci, Rect2(-LL / 2, -WW / 2 + sway, LL, WW), blue, WW * 0.32)
	# Rainbow waves down both flanks (red, yellow, white), between the roof's edge and the body's.
	if not (paint != "" and paint != "classic"):
		for sy in [-1.0, 1.0]:
			var stripes := [Color("ef5b4c"), Color("f7c548"), Color("fdfaf2")]
			for k in 3:
				var pts := PackedVector2Array()
				for i in 17:
					var x := lerpf(-LL * 0.42, LL * 0.3, i / 16.0)
					var y: float = sy * (WW * 0.41 - k * WW * 0.035) + sin(i * 0.8) * WW * 0.022 + sway
					pts.append(Vector2(x, y))
				ci.draw_polyline(pts, stripes[k], WW * 0.03, true)
	# The roof, cream, with its windows peeking out along the edges.
	var roof := Rect2(-LL * 0.46, -WW * 0.36 + sway, LL * 0.88, WW * 0.72)
	DrawUtil.rrect(ci, roof, cream, WW * 0.26)
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, roof.grow(-WW * 0.1))
	for sy in [-1.0, 1.0]:
		for k in 5:
			var x := -LL * 0.38 + k * LL * 0.135
			DrawUtil.rrect(ci, Rect2(Vector2(x, sy * WW * 0.315 - WW * 0.04 + sway), Vector2(LL * 0.1, WW * 0.08)), Palette.VAN_GLASS.darkened(0.08), WW * 0.03)
	# The split windscreen and the round headlamps.
	for sy in [-1.0, 1.0]:
		DrawUtil.rrect(ci, Rect2(Vector2(LL * 0.33, sy * WW * 0.15 - WW * 0.13 + sway), Vector2(LL * 0.09, WW * 0.26)), Palette.VAN_GLASS, WW * 0.06)
		ci.draw_circle(Vector2(LL * 0.47, sy * WW * 0.3 + sway), WW * 0.07, Color("fff3c4"))
		ci.draw_circle(Vector2(LL * 0.47, sy * WW * 0.3 + sway), WW * 0.04, Color("ffe28a"))
	# The roof rack: white tubes, slats across.
	var rack := Rect2(-LL * 0.3, -WW * 0.22 + sway, LL * 0.5, WW * 0.44)
	ci.draw_rect(rack, Color(1, 1, 1, 0.95), false, WW * 0.045)
	for k in 5:
		var x := rack.position.x + rack.size.x * (k + 0.5) / 5.0
		ci.draw_line(Vector2(x, rack.position.y), Vector2(x, rack.end.y), Color(1, 1, 1, 0.8), WW * 0.03)
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-LL * 0.05, sway), WW * 0.4, cargo, false)
	return Vector2(LL * 0.29, sway)


## Where the eazy van's side windows are, in the ride's space (smoke comes out of them on a win).
static func eazy_windows(L: float, W: float) -> Array:
	var LL := L * 1.1
	var WW := W * 1.04
	var out := []
	for sy in [-1.0, 1.0]:
		for k in 5:
			out.append(Vector2(-LL * 0.38 + k * LL * 0.135 + LL * 0.05, sy * WW * 0.36))
	return out


## Tay's Dreamsicle: an orange popsicle (vanilla inside) on a wooden stick, frosty, a drip or two. On a win a
## bite pops out of its front corner, showing the vanilla, and stays out till the win's done.
static func _dreamsicle(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("dreamsicle", paint)
	var orange: Color = cols[0]
	var vanilla: Color = cols[1]
	var bar := Rect2(-L * 0.32, -W * 0.4, L * 0.8, W * 0.8)
	DrawUtil.rrect(ci, Rect2(-L * 0.56, -W * 0.38, L * 1.1, W * 0.9), Color(0, 0, 0, 0.14), W * 0.36)
	# The stick, out the back.
	DrawUtil.rrect(ci, Rect2(-L * 0.55, -W * 0.11, L * 0.3, W * 0.22), Color("e2c08d"), W * 0.1)
	ci.draw_line(Vector2(-L * 0.5, -W * 0.04), Vector2(-L * 0.32, -W * 0.04), Color("c9a46c"), W * 0.025)
	var shell := _rrect_poly(bar, W * 0.34)
	var bite := PackedVector2Array()
	var k := 0.0
	if win >= 0.18:
		k = clampf((win - 0.18) / 0.08, 0.0, 1.0)
		# Three teeth-sized circles at the front corner, the bite.
		var bc := Vector2(bar.end.x - W * 0.08, bar.position.y + W * 0.1)
		var parts := Geometry2D.merge_polygons(_circle_poly(bc, W * 0.26 * k), _circle_poly(bc + Vector2(-W * 0.22, -W * 0.02), W * 0.18 * k))
		bite = parts[0] if not parts.is_empty() else PackedVector2Array()
		var parts2 := Geometry2D.merge_polygons(bite, _circle_poly(bc + Vector2(W * 0.04, W * 0.22), W * 0.17 * k))
		bite = parts2[0] if not parts2.is_empty() else bite
	if bite.size() >= 3:
		# The vanilla inside, round the edge of the bite.
		var grown := Geometry2D.offset_polygon(bite, W * 0.1)
		var outer := Geometry2D.clip_polygons(shell, grown[0] if not grown.is_empty() else bite)
		for poly in outer:
			if not Geometry2D.is_polygon_clockwise(poly):
				ci.draw_colored_polygon(poly, orange)
		for g in grown:
			for ring in Geometry2D.intersect_polygons(shell, g):
				for poly in Geometry2D.clip_polygons(ring, bite):
					if not Geometry2D.is_polygon_clockwise(poly):
						ci.draw_colored_polygon(poly, vanilla)
	else:
		ci.draw_colored_polygon(shell, orange)
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, bar.grow(-W * 0.12))
	# Frost: a shine and a few streaks.
	DrawUtil.rrect(ci, Rect2(bar.position + Vector2(W * 0.12, W * 0.08), Vector2(bar.size.x * 0.6, W * 0.1)), Color(1, 1, 1, 0.35), W * 0.05)
	for i in 3:
		ci.draw_line(Vector2(bar.position.x + L * (0.15 + i * 0.18), -W * 0.2), Vector2(bar.position.x + L * (0.22 + i * 0.18), W * 0.24), Color(vanilla, 0.28), W * 0.04, true)
	# Drips down the sides.
	for sy in [-1.0, 1.0]:
		var d := fmod(t * 0.6 + (0.5 if sy > 0 else 0.0), 1.0)
		var dc := Vector2(-L * 0.05 + sy * L * 0.12, sy * (W * 0.4 + W * 0.08 * d))
		ci.draw_circle(dc, W * (0.06 + 0.03 * d), Color(orange, 1.0 - d * 0.6))
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-L * 0.04, 0), W * 0.36, cargo, false)
	return Vector2(L * 0.2, 0)


## Cole's Classic: a long-bonneted silver sports car, frog-eye headlights on its front wings, a sloping back
## with engine-lid slats and wide hips. On a win a gleam sweeps over it (RideWins adds the sparkles).
static func _classic_car(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("classic_car", paint)
	var silver: Color = cols[0]
	var dark: Color = cols[1]
	var LL := L * 1.06
	var outline := _mirror([Vector2(0.53, 0.0), Vector2(0.52, 0.16), Vector2(0.47, 0.32), Vector2(0.38, 0.43), Vector2(0.24, 0.42),
		Vector2(0.1, 0.36), Vector2(-0.12, 0.38), Vector2(-0.3, 0.47), Vector2(-0.45, 0.42), Vector2(-0.52, 0.26), Vector2(-0.54, 0.0)], LL, W)
	var shadow := PackedVector2Array()
	for p in outline:
		shadow.append(p * 1.04 + Vector2(4, 8))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.2))
	for spec in [[0.31, 0.44], [-0.3, 0.49]]:
		for sy in [-1.0, 1.0]:
			DrawUtil.rrect(ci, Rect2(Vector2(LL * float(spec[0]) - LL * 0.075, sy * W * float(spec[1]) - W * 0.08), Vector2(LL * 0.15, W * 0.16)), Palette.WHEEL, W * 0.05)
	ci.draw_colored_polygon(outline, silver)
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, Rect2(LL * 0.2, -W * 0.26, LL * 0.26, W * 0.52))
	# The bonnet's crease and the cabin.
	ci.draw_line(Vector2(LL * 0.5, 0), Vector2(LL * 0.22, 0), Color(silver.darkened(0.12)), W * 0.025, true)
	_poly(ci, [Vector2(LL * 0.2, -W * 0.3), Vector2(LL * 0.08, -W * 0.33), Vector2(LL * 0.08, W * 0.33), Vector2(LL * 0.2, W * 0.3)], Palette.VAN_GLASS.darkened(0.05))
	DrawUtil.rrect(ci, Rect2(-LL * 0.14, -W * 0.31, LL * 0.22, W * 0.62), silver.darkened(0.06), W * 0.14)
	_poly(ci, [Vector2(-LL * 0.14, -W * 0.28), Vector2(-LL * 0.27, -W * 0.22), Vector2(-LL * 0.27, W * 0.22), Vector2(-LL * 0.14, W * 0.28)], Palette.VAN_GLASS.darkened(0.15))
	# Engine-lid slats, tail lights.
	for k in 5:
		var x := -LL * (0.33 + k * 0.03)
		ci.draw_line(Vector2(x, -W * 0.14), Vector2(x, W * 0.14), dark, W * 0.02)
	for sy in [-1.0, 1.0]:
		DrawUtil.rrect(ci, Rect2(Vector2(-LL * 0.54, sy * W * 0.3 - W * 0.07), Vector2(LL * 0.035, W * 0.14)), Color("d62b3a"), W * 0.02)
		# Frog-eye headlights on the front wings, and the mirrors.
		var hl := Vector2(LL * 0.42, sy * W * 0.31)
		ci.draw_circle(hl, W * 0.11, silver.lightened(0.2))
		ci.draw_circle(hl, W * 0.08, Color("e9f3ff"))
		ci.draw_circle(hl + Vector2(W * 0.02, -W * 0.02), W * 0.03, Color.WHITE)
		DrawUtil.rrect(ci, Rect2(Vector2(LL * 0.12, sy * W * 0.4 - W * 0.04), Vector2(LL * 0.05, W * 0.08)), dark, W * 0.03)
	# A soft shine along its top, and on a win a bright gleam sweeping nose to tail.
	ci.draw_colored_polygon(_mirror([Vector2(0.4, 0.0), Vector2(0.38, 0.1), Vector2(0.22, 0.14), Vector2(0.24, 0.0)], LL, W), Color(1, 1, 1, 0.22))
	if win >= 0.0:
		var u := clampf(win / 0.9, 0.0, 1.0)
		var x := lerpf(LL * 0.7, -LL * 0.7, u)
		var band := PackedVector2Array([Vector2(x, -W * 0.6), Vector2(x + LL * 0.16, -W * 0.6), Vector2(x - LL * 0.06, W * 0.6), Vector2(x - LL * 0.22, W * 0.6)])
		for poly in Geometry2D.intersect_polygons(outline, band):
			ci.draw_colored_polygon(poly, Color(1, 1, 1, 0.75 * sin(PI * u)))
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-LL * 0.4, 0), W * 0.3, cargo, false)
	return Vector2(-LL * 0.03, 0)


## Twinkle's Lab: a wooden lab bench on casters with a big round flask in the middle (the concoction), an
## Erlenmeyer flask and a round-bottom one over a burner at the front, a beaker and a rack of test tubes at
## the back, glass tubing running into the middle. Everything bubbles. On a win the potions run down the
## tubes into the big flask, which churns through colours (RideWins puffs the result up out of it).
static func _lab(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("lab", paint)
	var wood: Color = cols[0]
	var potion: Color = cols[1]
	var LL := L * 1.04
	var WW := W * 1.12
	var bench := Rect2(-LL / 2, -WW / 2, LL, WW)
	DrawUtil.rrect(ci, Rect2(bench.position + Vector2(4, 8), bench.size), Color(0, 0, 0, 0.2), WW * 0.1)
	for c in [bench.position, Vector2(bench.end.x, bench.position.y), bench.end, Vector2(bench.position.x, bench.end.y)]:
		ci.draw_circle(c + (Vector2.ZERO - c).normalized() * WW * 0.08, WW * 0.07, Palette.WHEEL)
	DrawUtil.rrect(ci, bench, wood.darkened(0.2), WW * 0.08)
	DrawUtil.rrect(ci, bench.grow(-WW * 0.04), wood, WW * 0.06)
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, bench.grow(-WW * 0.08))
	else:
		for k in 4:
			var y := bench.position.y + WW * (0.2 + k * 0.2)
			ci.draw_line(Vector2(bench.position.x + WW * 0.06, y), Vector2(bench.end.x - WW * 0.06, y + WW * 0.02), Color(wood.darkened(0.12), 0.6), WW * 0.015)
	var mid := Vector2(-LL * 0.02, 0)
	var flow := clampf(win / 0.7, 0.0, 1.0) if win >= 0.0 else 0.0
	var feeds := [[Vector2(LL * 0.3, -WW * 0.26), Color("7ee081")], [Vector2(LL * 0.3, WW * 0.24), Color("ff7ab6")], [Vector2(-LL * 0.3, WW * 0.24), Color("6cc3ff")]]
	# Glass tubing from each into the big flask; on a win the potions run down it.
	for fd in feeds:
		var a: Vector2 = fd[0]
		var ctrl := (a + mid) / 2.0 + Vector2(0, -WW * 0.12)
		var pts := PackedVector2Array()
		for s in 11:
			var u := s / 10.0
			pts.append(a.lerp(ctrl, u).lerp(ctrl.lerp(mid, u), u))
		ci.draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.85), WW * 0.045, true)
		if win >= 0.0 and win < 0.85:
			for d in 4:
				var u := fmod(win * 2.4 + d * 0.25, 1.0)
				var i := int(u * 10.0)
				ci.draw_circle(pts[mini(i, 10)], WW * 0.03, fd[1])
	# The test-tube rack.
	DrawUtil.rrect(ci, Rect2(-LL * 0.44, -WW * 0.36, LL * 0.3, WW * 0.16), Color("8a6a4a"), WW * 0.03)
	var tube_cols := [Color("ff7ab6"), Color("7ee081"), Color("ffd166"), Color("6cc3ff")]
	for k in 4:
		var c := Vector2(-LL * 0.4 + k * LL * 0.07, -WW * 0.28)
		ci.draw_circle(c, WW * 0.05, Color(1, 1, 1, 0.8))
		ci.draw_circle(c, WW * 0.035, tube_cols[k])
	# The beaker, the Erlenmeyer, the round-bottom over its burner (a little flame flickering under it).
	for fd in feeds:
		var c: Vector2 = fd[0]
		var r := WW * (0.13 if c.x > 0.0 else 0.11)
		if c.x > 0.0 and c.y > 0.0:
			ci.draw_circle(c + Vector2(WW * 0.03, WW * 0.03), r * (1.15 + 0.08 * sin(t * 13.0)), Color(1.0, 0.55, 0.15, 0.55))
		ci.draw_circle(c, r, Color(1, 1, 1, 0.85))
		var level := 1.0 - (0.5 * flow if win >= 0.0 else 0.0)
		ci.draw_circle(c, r * 0.78 * level, fd[1])
		ci.draw_circle(c, r * 0.32, Color(1, 1, 1, 0.9))
		ci.draw_circle(c + Vector2(r * 0.3, -r * 0.2) * sin(t * 4.0 + c.x), r * 0.12, Color(1, 1, 1, 0.6))
	# The big flask in the middle: its potion, bubbling; on a win it fills and churns through colours.
	var col := potion
	if win >= 0.0:
		col = Color.from_hsv(fmod(0.45 + win * 0.9, 1.0), 0.6, 1.0)
	var R := WW * 0.24
	ci.draw_circle(mid, R * 1.08, Color(1, 1, 1, 0.9))
	ci.draw_circle(mid, R * (0.86 + 0.08 * flow), col)
	for b in 4:
		var u := fmod(t * (0.9 + b * 0.2) + b * 0.3, 1.0)
		var bp := mid + Vector2(cos(b * 1.7), sin(b * 2.3)) * R * 0.45 * (1.0 - u)
		ci.draw_circle(bp, R * (0.08 + 0.1 * u) * (1.0 + flow), Color(1, 1, 1, 0.55 * (1.0 - u)))
	ci.draw_circle(mid, R * 0.36, Color(1, 1, 1, 0.85))
	ci.draw_circle(mid + Vector2(-R * 0.42, -R * 0.42), R * 0.14, Color(1, 1, 1, 0.7))
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-LL * 0.3, -WW * 0.02), WW * 0.28, cargo, false)
	return mid


## Zero the Steed: a fluffy black dog seen from above, trotting. Tufty fur all round, floppy ears that bounce,
## a white blaze down his face to a white muzzle and a black nose, amber eyes, a white bib at the neck, a
## plume of a tail that wags (hard, on a win), paws going at the sides, and a red saddle blanket with the
## cargo strapped on: he's a steed. A paint job colours his fur (and his markings stay white).
static func _zero(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float) -> Vector2:
	var cols := _cols("zero", paint)
	var fur: Color = cols[0]
	var white: Color = cols[1]
	var amber := Color("c98a3c")
	var trot := sin(t * 9.0)
	var wag := sin(t * 8.0) * 0.35
	if win >= 0.0:
		wag = sin(win * 26.0) * 0.6
	# Paws, under him, going as he trots.
	for sy in [-1.0, 1.0]:
		for front in [true, false]:
			var step := trot * (1.0 if front == (sy > 0.0) else -1.0)
			var p := Vector2(L * (0.16 if front else -0.28) + step * L * 0.05, sy * W * 0.4)
			ci.draw_circle(p, W * 0.1, fur.darkened(0.2))
	# The tail: a fluffy plume behind, wagging.
	var base := Vector2(-L * 0.4, 0)
	var tip := base + Vector2(-L * 0.26, W * 0.55 * wag)
	ci.draw_colored_polygon(_fluff(base.lerp(tip, 0.55), L * 0.17, W * 0.15, 0.15, t * 2.0), fur.lightened(0.05))
	ci.draw_colored_polygon(_fluff(tip, W * 0.1, W * 0.09, 0.15, t), white)
	# Shadow, then the fluffy body: an oval with a tufty edge.
	ci.draw_colored_polygon(_fluff(Vector2(-L * 0.06 + W * 0.04, W * 0.06), L * 0.4, W * 0.42, 0.0, 0.0), Color(0, 0, 0, 0.16))
	ci.draw_colored_polygon(_fluff(Vector2(-L * 0.06, 0), L * 0.4, W * 0.42, 0.07, t), fur)
	# The saddle blanket, and the cargo strapped on it.
	var sad := Rect2(-L * 0.2, -W * 0.36, L * 0.3, W * 0.72)
	ci.draw_colored_polygon(_rrect_poly(sad, W * 0.1), Color("c8302c"))
	ci.draw_colored_polygon(_rrect_poly(sad.grow(-W * 0.05), W * 0.07), Color("e0473f"))
	for sy in [-1.0, 1.0]:
		ci.draw_line(Vector2(sad.position.x + W * 0.04, sy * W * 0.3), Vector2(sad.end.x - W * 0.04, sy * W * 0.3), Color("ffd166"), W * 0.035)
	if paint != "" and paint != "classic":
		Cosmetics.draw_pattern(ci, paint, sad.grow(-W * 0.05))
	if cargo is Color:
		DrawUtil.package(ci, Vector2(-L * 0.05, 0), W * 0.34, cargo, false)
	# The white bib at the neck, then the head.
	ci.draw_colored_polygon(_fluff(Vector2(L * 0.2, 0), W * 0.2, W * 0.24, 0.1, t + 1.0), white)
	var h := Vector2(L * 0.32, 0)
	# Ears: big fluffy flaps hanging out to the sides, bouncing as he goes.
	for sy in [-1.0, 1.0]:
		var flop: float = 0.18 * trot * sy
		var e := h + Vector2(-W * 0.1, sy * W * 0.3) + Vector2(-W * 0.02, sy * W * 0.06).rotated(flop)
		ci.draw_colored_polygon(_fluff(e, W * 0.2, W * 0.15, 0.12, t * 1.3 + sy), fur.lightened(0.07))
	ci.draw_colored_polygon(_fluff(h, W * 0.34, W * 0.32, 0.06, t + 2.0), fur)
	# The muzzle, white, out front, with a short thin blaze up between the eyes; the nose on the end.
	ci.draw_colored_polygon(_circle_poly(h + Vector2(W * 0.27, 0), W * 0.15, 20), white)
	_poly(ci, [h + Vector2(W * 0.02, -W * 0.02), h + Vector2(W * 0.2, -W * 0.06), h + Vector2(W * 0.2, W * 0.06), h + Vector2(W * 0.02, W * 0.02)], white)
	ci.draw_circle(h + Vector2(W * 0.4, 0), W * 0.075, Color("15131a"))
	ci.draw_circle(h + Vector2(W * 0.42, -W * 0.025), W * 0.022, Color(1, 1, 1, 0.6))
	# Amber eyes, looking up at you.
	for sy in [-1.0, 1.0]:
		var ey := h + Vector2(W * 0.1, sy * W * 0.14)
		ci.draw_circle(ey, W * 0.062, amber)
		ci.draw_circle(ey + Vector2(W * 0.012, 0), W * 0.03, Color("15131a"))
		ci.draw_circle(ey + Vector2(W * 0.024, -W * 0.022), W * 0.015, Color.WHITE)
	return h


## A tufty oval: radii `rx`, `ry` round `c`, the edge broken into fur tufts `tuft` deep (stirring with `t`).
static func _fluff(c: Vector2, rx: float, ry: float, tuft: float, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 64
	for k in n:
		var a := TAU * k / n
		# Soft scallops (tufts), not spikes, stirring a little.
		var r := 1.0 + tuft * (absf(sin(a * 7.0 + sin(t * 1.5) * 0.3)) - 0.4)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry) * r)
	return out

