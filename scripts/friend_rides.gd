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


static func draw(ci: CanvasItem, id: String, L: float, W: float, cargo: Variant, t: float, paint: String, win: float, up: Vector2) -> Vector2:
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
			return _pillow_tower(ci, L, W, cargo, t, paint, win, up)
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
static func _pillow_tower(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float, paint: String, win: float, up: Vector2) -> Vector2:
	var cols := _cols("pillow_tower", paint)
	var pillows := [cols[0], Color("ffb3c7"), Color("b8f0d2"), Color("fff1c2"), Color("bfe3ff"), Color("ffd2a8"), cols[1]]
	var side := Vector2(-up.y, up.x)
	# The puddle, off to one side.
	var pc := puddle_at(L, W, up)
	ci.draw_set_transform(pc, up.angle() + PI / 2.0, Vector2(1.0, 0.6))
	ci.draw_circle(Vector2.ZERO, W * 0.42, Color("4d8dff", 0.55))
	ci.draw_circle(Vector2(-W * 0.08, -W * 0.06), W * 0.28, Color("7fb0ff", 0.55))
	ci.draw_circle(Vector2(W * 0.14, W * 0.1), W * 0.08, Color(1, 1, 1, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
		ci.draw_set_transform(c, up.angle() + PI / 2.0, Vector2.ONE)
		DrawUtil.rrect(ci, Rect2(-sz / 2.0 + Vector2(0, W * 0.05), sz), Color(0, 0, 0, 0.12), W * 0.22)
		DrawUtil.rrect(ci, Rect2(-sz / 2.0, sz), pillows[i], W * 0.24)
		ci.draw_line(Vector2(-sz.x * 0.3, 0), Vector2(sz.x * 0.3, 0), Color(1, 1, 1, 0.35), W * 0.025)
		for cx in [-1.0, 1.0]:
			for cy in [-1.0, 1.0]:
				ci.draw_circle(Vector2(cx * sz.x * 0.42, cy * sz.y * 0.36), W * 0.05, Color(pillows[i]).darkened(0.08))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		top = c
	if cargo is Color:
		DrawUtil.package(ci, top + up * W * 0.12, W * 0.34, cargo, false)
	return top + up * W * 0.2


## Where Violet's puddle sits, in the ride's space.
static func puddle_at(L: float, W: float, up: Vector2) -> Vector2:
	var side := Vector2(-up.y, up.x)
	return side * W * 0.95 - up * W * 0.15
