class_name FakeAd
extends CanvasLayer
## A pretend rewarded ad, for fun: thirteen seconds of Frontiers Celestia (the studio's other game) drawn in
## code in that game's colours, then an end card with a "Playtest now" button. It isn't a real ad: there's no
## ad network, no tracking and no link, and nobody is paid. A Skip button appears after SKIP_AFTER seconds;
## skipping, closing or finishing all emit `finished`, and the caller hands over the reward.

signal finished

const SKIP_AFTER := 3.0
const END_AT := 13.2
const SKY_TOP := Color(0.05, 0.04, 0.12)
const SKY_BOTTOM := Color(0.2, 0.12, 0.3)
const GOLD := Color(1.0, 0.9, 0.6)
const TEAL := Color(0.55, 0.95, 0.85)
const TURF := Color(0.36, 0.62, 0.55)
const TURF_DARK := Color(0.26, 0.46, 0.44)
const TENT := Color(0.95, 0.62, 0.45)
const CREAM := Color(0.984, 0.965, 0.918)
const SPROUT := Color(0.5, 0.9, 0.74)
const LILAC := Color(0.74, 0.62, 0.94)
const PINK := Color(1.0, 0.56, 0.66)
const MARK: Texture2D = preload("res://assets/ads/frontiers_celestia.png")
## [starts at, caption]
const CAPTIONS := [[0.15, "Tired of deliveries?"], [3.3, "Claim a tiny planet."], [6.6, "Befriend the locals."]]
const WORDS := ["Farm.", "Fish.", "Tinker.", "Nap."]
const WORDS_AT := 9.9
## How much bigger than drawn the locals are.
const BIG := 1.45
const WORD_COLORS := [Color(0.6, 0.92, 0.6), Color(0.5, 0.78, 0.98), Color(1.0, 0.72, 0.45), Color(0.8, 0.7, 1.0)]
## The locals: x offset from the middle, colour, when it hops in, what's on its head.
const CRITTERS := [
	{"x": -300.0, "c": Color(0.5, 0.78, 0.98), "at": 6.75, "top": "drop"},
	{"x": 340.0, "c": Color(0.98, 0.66, 0.46), "at": 7.3, "top": "ears"},
	{"x": -80.0, "c": Color(0.74, 0.62, 0.94), "at": 7.85, "top": "antenna"},
]
const CUES := [[0.05, "jingle", 1.0, -4.0], [3.3, "pop", 0.9, -6.0], [4.9, "sparkle", 1.0, -6.0], [6.6, "pop", 1.0, -6.0],
	[6.95, "ad_chirp1", 1.0, -4.0], [7.5, "ad_chirp2", 1.0, -4.0], [8.05, "ad_chirp3", 1.0, -4.0],
	[9.9, "pop", 1.0, -6.0], [10.5, "pop", 1.12, -6.0], [11.1, "pop", 1.26, -6.0], [11.7, "pop", 0.8, -6.0],
	[END_AT, "star", 1.0, -3.0]]

var _root: Control
var _skip: JuicyButton
var _cta: JuicyButton
var _t := 0.0
var _stars: Array = []
var _closing := false
var _toast_at := -1.0
var _top := 0.0


func _ready() -> void:
	layer = 80
	_top = UiTheme.insets(get_viewport()).x
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_ad)
	add_child(_root)
	for i in 70:
		_stars.append(Vector3(randf(), randf() * 0.8, randf() * TAU))

	_skip = JuicyButton.new()
	_skip.font_px = 36
	_skip.bg = Color(1, 1, 1, 0.16)
	_skip.dim_bg = Color(1, 1, 1, 0.07)
	_skip.fg = CREAM
	_skip.custom_minimum_size = Vector2(250, 92)
	_skip.size = Vector2(250, 92)
	_skip.pressed.connect(_on_skip)
	_root.add_child(_skip)

	_cta = JuicyButton.new()
	_cta.font_px = 68
	_cta.bg = TEAL
	_cta.fg = Color(0.07, 0.16, 0.2)
	_cta.label = "Playtest now"
	_cta.size = Vector2(700, 170)
	_cta.visible = false
	_cta.pressed.connect(_on_cta)
	_root.add_child(_cta)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var size := _root.get_viewport_rect().size
	_skip.position = Vector2(size.x - _skip.size.x - 36.0, 40.0 + _top)
	_cta.position = Vector2((size.x - _cta.size.x) / 2.0, size.y * 0.6)
	_cta.pivot_offset = _cta.size / 2.0


func _process(delta: float) -> void:
	if _closing:
		return
	var before := _t
	_t += minf(delta, 0.1)
	for cue in CUES:
		var at: float = cue[0]
		if at > before and at <= _t:
			Sfx.play(cue[1], cue[2], cue[3])
	if _t < SKIP_AFTER:
		_skip.dim = true
		_skip.icon_name = ""
		_skip.label = "Skip in %d" % int(ceil(SKIP_AFTER - _t))
	elif _t < END_AT:
		_skip.dim = false
		_skip.icon_name = ""
		_skip.label = "Skip  »"
	else:
		_skip.dim = false
		_skip.icon_name = "x"
		_skip.label = "Close"
		if not _cta.visible:
			_cta.visible = true
			_cta.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_interval(0.5)
			tw.tween_property(_cta, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_cta.breathe.bind(true))
	if _toast_at >= 0.0 and _t - _toast_at > 2.6:
		_close()
	_root.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Nothing reaches the game underneath while the ad is up.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_on_skip()


func _on_skip() -> void:
	if _t < SKIP_AFTER:
		Sfx.play("bonk", 1.3, -10.0)
		return
	Sfx.play("click")
	_close()


func _on_cta() -> void:
	if _toast_at >= 0.0:
		return
	Sfx.play("ad_chirp1")
	_toast_at = _t
	_cta.breathe(false)


func _close() -> void:
	if _closing:
		return
	_closing = true
	finished.emit()
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- drawing

func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


## 0 -> overshoot -> 1, for things popping in.
func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


func _text(text: String, at: Vector2, px: int, col: Color, max_w := 0.0) -> void:
	var f := UiTheme.font()
	if max_w > 0.0:
		while px > 20 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			px -= 2
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_string_outline(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(px / 5, 6), Color(SKY_TOP, col.a))
	_root.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_ad() -> void:
	var r := _root
	var size := r.size
	var w := size.x
	var h := size.y
	r.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), size, Vector2(0, h)]), PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + s.z)
		r.draw_circle(Vector2(s.x * w, s.y * h), 2.0 + 2.5 * tw, Color(1, 1, 1, 0.3 + 0.6 * tw))

	# The planet: a big curve along the bottom.
	var radius := w * 1.15
	var horizon := h * 0.68
	var centre := Vector2(w / 2.0, horizon + radius)
	r.draw_circle(centre, radius + 10.0, Color(TEAL, 0.35))
	r.draw_circle(centre, radius, TURF_DARK)
	r.draw_circle(centre + Vector2(0, 16), radius, TURF)
	for m in [[-0.3, 60.0], [-0.12, 44.0], [0.1, 70.0], [0.27, 50.0]]:
		var ang: float = m[0] - PI / 2.0
		var mp := centre + Vector2(cos(ang), sin(ang)) * (radius - 70.0)
		r.draw_set_transform(mp, m[0], Vector2(1.0, 0.45))
		r.draw_circle(Vector2.ZERO, m[1], Color(LILAC, 0.32))
		r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _t < 3.6:
		_draw_parcels(w, horizon)
	if _t >= 3.3:
		_draw_sprout(Vector2(w / 2.0 + 130.0, _ground(centre, radius, w / 2.0 + 130.0)))
		_draw_tent(Vector2(w * 0.1, _ground(centre, radius, w * 0.1) + 8.0))
	for i in CRITTERS.size():
		_draw_critter(i, centre, radius, w)
	_draw_captions(w, h)

	if _t >= END_AT:
		_draw_end_card(w, h)

	# Ad furniture: a label, and how much is left.
	var tag := Rect2(36.0, 44.0 + _top, 108.0, 64.0)
	DrawUtil.rrect(r, tag, Color(1, 1, 1, 0.16), 32)
	r.draw_string(UiTheme.font(), tag.position + Vector2(30, 45), "Ad", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, CREAM)
	var left := clampf(_t / END_AT, 0.0, 1.0)
	r.draw_rect(Rect2(0, h - 12.0, w, 12.0), Color(1, 1, 1, 0.12))
	r.draw_rect(Rect2(0, h - 12.0, w * left, 12.0), TEAL)
	_text("Not a real ad. Nobody paid for this. Real game, though.", Vector2(w / 2.0, h - 54.0), 28, Color(CREAM, 0.6), w - 60.0)


## The y of the planet's surface at screen x.
func _ground(centre: Vector2, radius: float, x: float) -> float:
	return centre.y - sqrt(maxf(radius * radius - (x - centre.x) * (x - centre.x), 0.0))


## Scene one: the parcels float off into space. No more deliveries.
func _draw_parcels(w: float, horizon: float) -> void:
	var cols := [Palette.pkg("red"), Palette.pkg("yellow"), Palette.pkg("blue")]
	for i in 3:
		var u := clampf((_t - i * 0.35) / 3.0, 0.0, 1.0)
		var at := Vector2(w * (0.3 + 0.2 * i) + sin(u * 4.0 + i) * 40.0, lerpf(horizon - 60.0, horizon - 900.0, _ease_out(u)))
		_root.draw_set_transform(at, u * (3.0 + i), Vector2.ONE * lerpf(1.0, 0.25, u))
		DrawUtil.package(_root, Vector2.ZERO, 120.0, Color(cols[i], 1.0 - smoothstep(0.75, 1.0, u)), false)
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Scene two (and on): a sprout grows, a ring swings round it and a star lights at its tip. The game's mark.
func _draw_sprout(base: Vector2) -> void:
	var r := _root
	var grow := _ease_out((_t - 3.4) / 1.3)
	var sway := sin(_t * 1.7) * 0.03
	var tip := base + Vector2(sin(sway) * 460.0, -460.0) * grow
	r.draw_line(base + Vector2(0, 10), tip, SPROUT, 22.0, true)
	r.draw_circle(tip, 11.0, SPROUT)
	var leaves := _pop((_t - 4.3) / 0.6) if _t > 4.3 else 0.0
	if leaves > 0.0:
		var mid := base.lerp(tip, 0.5)
		for side in [-1.0, 1.0]:
			r.draw_set_transform(mid, side * (1.05 + sway * 3.0), Vector2(leaves, leaves))
			var leaf := PackedVector2Array()
			for k in 13:
				var a := PI * k / 12.0
				leaf.append(Vector2(sin(a) * 58.0 * side, -a / PI * 250.0))
			for k in range(11, 0, -1):
				var a := PI * k / 12.0
				leaf.append(Vector2(-sin(a) * 18.0 * side, -a / PI * 250.0))
			r.draw_colored_polygon(leaf, SPROUT.darkened(0.1 if side < 0.0 else 0.0))
			r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sweep := clampf((_t - 4.9) / 0.9, 0.0, 1.0)
	if sweep > 0.0:
		r.draw_set_transform(base.lerp(tip, 0.55), -0.2, Vector2(1.0, 0.26))
		r.draw_arc(Vector2.ZERO, 290.0, _t * 0.6, _t * 0.6 + TAU * sweep, 60, Color(LILAC, 0.9), 9.0, true)
		r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var lit := _pop((_t - 5.5) / 0.5) if _t > 5.5 else 0.0
	if lit > 0.0:
		var c := tip + Vector2(0, -46)
		var tw := 1.0 + 0.15 * sin(_t * 5.0)
		r.draw_circle(c, 90.0 * lit * tw, Color(GOLD, 0.14))
		r.draw_circle(c, 50.0 * lit * tw, Color(GOLD, 0.22))
		for q in 2:
			var long := Vector2(0, 96.0 * lit * tw) if q == 0 else Vector2(96.0 * lit * tw, 0)
			var short := Vector2(13.0, 0) if q == 0 else Vector2(0, 13.0)
			r.draw_colored_polygon(PackedVector2Array([c - long, c + short, c + long, c - short]), GOLD)


## A little tent pitched on the horizon: the claim is staked.
func _draw_tent(base: Vector2) -> void:
	if _t <= 5.0:
		return
	var s := _pop((_t - 5.0) / 0.4) * 0.62
	var r := _root
	r.draw_set_transform(base, -0.16, Vector2(s, s))
	r.draw_colored_polygon(PackedVector2Array([Vector2(-130, 0), Vector2(0, -190), Vector2(130, 0)]), TENT)
	r.draw_colored_polygon(PackedVector2Array([Vector2(-36, 0), Vector2(0, -110), Vector2(36, 0)]), SKY_BOTTOM)
	r.draw_line(Vector2(0, -190), Vector2(0, -260), CREAM, 6.0, true)
	r.draw_colored_polygon(PackedVector2Array([Vector2(0, -260), Vector2(56, -244), Vector2(0, -226)]), TEAL)
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Scene three (and on): the locals hop in, bob about, and doze off at "Nap."
func _draw_critter(i: int, centre: Vector2, radius: float, w: float) -> void:
	var cr: Dictionary = CRITTERS[i]
	var at_t: float = cr["at"]
	if _t < at_t:
		return
	var r := _root
	var arrive := clampf((_t - at_t) / 0.8, 0.0, 1.0)
	var from_x: float = -140.0 if cr["x"] < 0.0 else w + 140.0
	var x := lerpf(from_x, w / 2.0 + cr["x"], _ease_out(arrive))
	var asleep := _t > WORDS_AT + 1.9 and _t < END_AT + 0.4
	var hop := absf(sin((_t - at_t) * (9.0 if arrive < 1.0 else 3.2) + i)) * (70.0 if arrive < 1.0 else (4.0 if asleep else 22.0))
	var gy := _ground(centre, radius, x) + 10.0
	var squash := 1.0 - 0.12 * (1.0 - minf(hop / 22.0, 1.0))
	var col: Color = cr["c"]
	r.draw_set_transform(Vector2(x, gy), 0.0, Vector2(1.0, 0.3) * BIG)
	r.draw_circle(Vector2.ZERO, 70.0, Color(0, 0, 0, 0.2))
	r.draw_set_transform(Vector2(x, gy - hop), 0.0, Vector2(2.0 - squash, squash) * BIG)
	match cr["top"]:
		"drop":
			r.draw_colored_polygon(PackedVector2Array([Vector2(-38, -100), Vector2(0, -176), Vector2(38, -100)]), col)
		"ears":
			r.draw_circle(Vector2(-46, -124), 26.0, col)
			r.draw_circle(Vector2(46, -124), 26.0, col)
			r.draw_circle(Vector2(-46, -124), 13.0, col.lightened(0.35))
			r.draw_circle(Vector2(46, -124), 13.0, col.lightened(0.35))
		"antenna":
			r.draw_line(Vector2(0, -120), Vector2(14, -182), col, 8.0, true)
			r.draw_circle(Vector2(14, -186), 15.0, GOLD)
	r.draw_circle(Vector2(0, -70), 74.0, col)
	r.draw_circle(Vector2(0, -52), 50.0, col.lightened(0.22))
	r.draw_circle(Vector2(-30, -112), 16.0, Color(1, 1, 1, 0.35))
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * 27.0, -84.0)
		if asleep:
			r.draw_arc(eye, 11.0, 0.15, PI - 0.15, 10, SKY_TOP, 5.0, true)
		else:
			r.draw_circle(eye, 14.0, Color.WHITE)
			r.draw_circle(eye + Vector2(side * 2.0, 2.0), 8.0, SKY_TOP)
			r.draw_circle(eye + Vector2(side * 2.0 - 3.0, -2.0), 3.0, Color.WHITE)
		r.draw_circle(Vector2(side * 46.0, -62.0), 10.0, Color(PINK, 0.55))
	r.draw_arc(Vector2(0, -66), 12.0, 0.25, PI - 0.25, 10, SKY_TOP, 5.0, true)
	r.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A heart floats up from each once they've settled; z's once they nap.
	var since := _t - at_t - 1.1
	if since > 0.0 and not asleep and _t < END_AT:
		var u := fmod(since, 1.6) / 1.6
		_heart(Vector2(x + sin(u * 5.0 + i) * 18.0, gy - 190.0 * BIG - 150.0 * u), 26.0 * (0.6 + 0.4 * u), Color(PINK, 1.0 - u))
	if asleep:
		var u := fmod(_t + i * 0.4, 1.4) / 1.4
		_text("z", Vector2(x + 90.0 + 40.0 * u, gy - 180.0 * BIG - 110.0 * u), int(34 + 30 * u), Color(CREAM, 1.0 - u))


func _heart(at: Vector2, s: float, col: Color) -> void:
	_root.draw_circle(at + Vector2(-s * 0.5, 0), s * 0.56, col)
	_root.draw_circle(at + Vector2(s * 0.5, 0), s * 0.56, col)
	_root.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 1.02, s * 0.22), at + Vector2(s * 1.02, s * 0.22), at + Vector2(0, s * 1.4)]), col)


func _draw_captions(w: float, h: float) -> void:
	if _t >= END_AT:
		return
	var y := h * 0.2
	for i in CAPTIONS.size():
		var from: float = CAPTIONS[i][0]
		var to: float = CAPTIONS[i + 1][0] if i + 1 < CAPTIONS.size() else WORDS_AT
		if _t < from or _t >= to:
			continue
		var grow := _pop((_t - from) / 0.35)
		var fade := 1.0 - smoothstep(to - 0.3, to, _t)
		_text(CAPTIONS[i][1], Vector2(w / 2.0, y), maxi(int(92 * grow), 8), Color(CREAM, fade), w - 80.0)
	if _t >= WORDS_AT:
		var fade := 1.0 - smoothstep(END_AT - 0.3, END_AT, _t)
		for i in WORDS.size():
			var from := WORDS_AT + i * 0.6
			if _t < from:
				continue
			var grow := _pop((_t - from) / 0.3)
			var at := Vector2(w * (0.29 if i % 2 == 0 else 0.71), y - 70.0 + 150.0 * (i / 2))
			_text(WORDS[i], at, maxi(int(104 * grow), 8), Color(WORD_COLORS[i], fade))


func _draw_end_card(w: float, h: float) -> void:
	var r := _root
	var u := _t - END_AT
	r.draw_rect(Rect2(0, 0, w, h), Color(SKY_TOP, 0.86 * clampf(u / 0.3, 0.0, 1.0)))
	var grow := _pop(u / 0.45)
	var c := Vector2(w / 2.0, h * 0.24)
	var s := 340.0 * grow
	r.draw_circle(c, s * 0.75 + 12.0 * sin(_t * 2.0), Color(TEAL, 0.1))
	r.draw_circle(c, s * 0.62, Color(TEAL, 0.14))
	r.draw_texture_rect(MARK, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false)
	if u > 0.2:
		var g2 := _pop((u - 0.2) / 0.4)
		_text("Frontiers", Vector2(w / 2.0, h * 0.24 + 270.0), maxi(int(140 * g2), 8), GOLD)
		_text("Celestia", Vector2(w / 2.0, h * 0.24 + 410.0), maxi(int(140 * g2), 8), GOLD)
	if u > 0.45:
		_text("A cozy little planet of your own.", Vector2(w / 2.0, h * 0.24 + 530.0), 46, Color(CREAM, clampf((u - 0.45) / 0.3, 0.0, 1.0)), w - 80.0)
	if u > 0.9:
		_text("a Door Bowl game", Vector2(w / 2.0, _cta.position.y + _cta.size.y + 70.0), 36, Color(CREAM, 0.7 * clampf((u - 0.9) / 0.3, 0.0, 1.0)))
	if _toast_at >= 0.0:
		var k := _pop((_t - _toast_at) / 0.3)
		var box := Rect2(w / 2.0 - 440.0 * k, _cta.position.y + _cta.size.y + 130.0, 880.0 * k, 190.0)
		DrawUtil.rrect(r, box, CREAM, 44)
		_text("Beep. This link goes nowhere (yet).", box.get_center() + Vector2(0, -36), 40, SKY_BOTTOM, box.size.x - 50.0)
		_text("Ask whoever handed you this game.", box.get_center() + Vector2(0, 30), 40, SKY_BOTTOM, box.size.x - 50.0)
