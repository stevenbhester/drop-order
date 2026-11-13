class_name FinishScreen
extends Control
## The level finish, in the style of a fighting-game "a new challenger joins" freeze frame: the world goes dark
## behind focus lines, a slashed banner whips across, the van punches in big with a white cut-out edge, and
## "DELIVERED!" slams down. Then the stat panels slide in one by one (time, stars, momentum) and the rewards fly
## up to the wallet and gas gauge. With momentum the van is engulfed in anime fire: more, taller and hotter
## the higher it is. A challenge level beaten for the first time goes bigger: the banner turns to hazard tape,
## "CHALLENGE CRUSHED!" slams down instead, confetti flies and the bonus is called out.

signal next_pressed
signal replay_pressed
signal share_pressed

const SLAM_AT := 0.28
const PANEL_AT := 0.62
const PANEL_EVERY := 0.2
const PAY_AT := 1.45
const BUTTONS_AT := 1.7
const INK := Color(0.1, 0.07, 0.16)

var level: LevelData
var stars := 3
var reward := 0
var gas_back := false
var secs := 0.0
var momentum := 0
var new_item := ""
var missed_item := false
var daily := false
var last_level := false
## A side road's title (the label says SIDE ROAD instead of the level number).
var side_title := ""
## First win on a challenge level.
var crushed := false
var coin_chip: CoinChip
var gas_chip: GasChip

var _t := 0.0
var _van: Van
var _front: Node2D
var _fx: Fx
var _next: JuicyButton
var _replay: Button
var _share: JuicyButton
var _landed := 0
var _panels := 0
var _paid := false
var _shake := 0.0
var _center := Vector2.ZERO
var _band := 0.0
var _unlock_shown := false


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	_layout_points()

	_van = Van.new()
	_van.size = 400.0
	_van.position = _center + Vector2(-140, 0)
	_van.rotation = -0.22
	_van.target_rotation = -0.22
	_van.scale = Vector2.ZERO
	_van.draw.connect(_draw_cutout)
	add_child(_van)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)
	_fx = Fx.new()
	add_child(_fx)

	_next = JuicyButton.new()
	_next.font_px = 74
	_next.bg = Palette.GOOD
	_next.fg = Color.WHITE
	_next.label = "Levels" if last_level else "Next"
	_next.icon_name = "" if last_level else "next"
	_next.size = Vector2(560, 156)
	_next.visible = false
	_next.pressed.connect(func():
		Sfx.play("click")
		next_pressed.emit())
	add_child(_next)
	if daily:
		_share = JuicyButton.new()
		_share.font_px = 60
		_share.bg = Color("4d8dff")
		_share.fg = Color.WHITE
		_share.label = "Share"
		_share.icon_name = "share"
		_share.size = Vector2(380, 156)
		_share.visible = false
		_share.pressed.connect(func():
			Sfx.play("click")
			share_pressed.emit())
		add_child(_share)
		_next.size = Vector2(380, 156)
		_next.label = "Done"
		_next.icon_name = ""
	_replay = Button.new()
	_replay.text = "Replay"
	_replay.flat = true
	_replay.focus_mode = Control.FOCUS_NONE
	_replay.add_theme_font_size_override("font_size", 38)
	_replay.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_replay.size = Vector2(420, 76)
	_replay.visible = false
	_replay.pressed.connect(func():
		Sfx.play("click")
		replay_pressed.emit())
	add_child(_replay)
	_layout_buttons()
	get_viewport().size_changed.connect(func():
		size = get_viewport_rect().size
		_layout_points()
		_layout_buttons())
	Sfx.play("punch", 1.0, -1.0)
	Sfx.haptic(40)


func _layout_points() -> void:
	var v := get_viewport_rect().size
	_center = Vector2(v.x * 0.5, v.y * 0.36)


func _layout_buttons() -> void:
	var v := get_viewport_rect().size
	var y := v.y - UiTheme.insets(get_viewport()).y - 330.0
	if _share:
		_share.position = Vector2(v.x / 2.0 - 400.0, y)
		_next.position = Vector2(v.x / 2.0 + 20.0, y)
	else:
		_next.position = Vector2((v.x - _next.size.x) / 2.0, y)
	_replay.position = Vector2((v.x - _replay.size.x) / 2.0, y + 176.0)


func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


func _out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	_shake = maxf(0.0, _shake - delta * 3.0)
	# The van punches in.
	var punch := _pop((_t - 0.06) / 0.26)
	_van.scale = Vector2.ONE * punch
	_van.position = _center + Vector2(-150, 10) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 18.0 * _shake
	if before < SLAM_AT and _t >= SLAM_AT:
		_shake = 1.0
		Sfx.play("slam", 1.0, -2.0)
		Sfx.haptic(30)
		if momentum > 0:
			Sfx.play("whoomp", 1.0 + 0.04 * mini(momentum, 8), -2.0)
		if crushed:
			_shake = 1.6
			Sfx.play("kaching", 0.8, -2.0)
			Sfx.haptic(50, 1.0)
			for col in ["red", "yellow", "blue", "green", "purple", "orange"]:
				_fx.burst(_center + Vector2(0, 260), Palette.pkg(col), 16, 1100.0, 24.0)
	while _panels < 3 and _t >= PANEL_AT + _panels * PANEL_EVERY:
		_panels += 1
		Sfx.play("whoosh", 1.2 + _panels * 0.08, -6.0)
	while _landed < stars and _t >= PANEL_AT + PANEL_EVERY + 0.12 + _landed * 0.12:
		var at := _stat_pos(1) + Vector2(-60.0 + _landed * 60.0, 0)
		_fx.burst(at, Palette.STAR_GOLD, 10, 500.0, 18.0)
		Sfx.play("star", 1.0 + 0.12 * _landed, -4.0)
		_landed += 1
	if not _paid and _t >= PAY_AT:
		_paid = true
		var from := _stat_pos(2) + Vector2(0, 150)
		if coin_chip and reward > 0:
			coin_chip.fly_from(from, clampi(reward / 25, 3, 12), reward)
		if gas_chip and gas_back:
			_fly_gas(from)
		if new_item != "":
			Sfx.play("kaching", 1.2, -3.0)
			_fx.burst(_center + Vector2(0, 520), Cosmetics.tint(new_item), 24, 800.0, 22.0)
	# A new find gets its own big moment, over the top.
	if new_item != "" and not _unlock_shown and _t >= PAY_AT + 0.7:
		_unlock_shown = true
		var card := UnlockCard.new()
		card.item = new_item
		add_child(card)
	if not _next.visible and _t >= BUTTONS_AT:
		for b in [_next, _share]:
			if b == null:
				continue
			b.visible = true
			b.pivot_offset = b.size / 2.0
			b.scale = Vector2.ZERO
			var tw: Tween = b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(b.breathe.bind(true))
		_replay.visible = true
	queue_redraw()
	_front.queue_redraw()
	_van.queue_redraw()


func _fly_gas(from: Vector2) -> void:
	var can := Node2D.new()
	can.top_level = true
	can.z_index = 100
	can.position = from
	can.draw.connect(func(): Icons.draw(can, "gas", Vector2.ZERO, 70.0, GasChip.FUEL))
	gas_chip.add_child(can)
	var to := gas_chip.global_position + Vector2(50, 51)
	var tw := can.create_tween()
	tw.tween_property(can, "position", from + Vector2(-120, -80), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(can, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		can.queue_free()
		Progress.changed.emit()
		gas_chip.bump()
		Sfx.play("pickup", 1.1, -4.0))


func _stat_pos(i: int) -> Vector2:
	var v := get_viewport_rect().size
	return Vector2(v.x * 0.5, _center.y + 470.0 + i * 118.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var v := size
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * _shake
	var dim := clampf(_t / 0.08, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, v), Color(INK, 0.78 * dim))
	# Focus lines, rushing in at the van.
	var lines := 56
	for i in lines:
		var a := TAU * i / lines + sin(_t * 30.0 + i * 1.7) * 0.012
		var w := 0.012 + 0.012 * absf(sin(i * 2.3))
		var r0 := 380.0 + 120.0 * absf(sin(i * 1.9 + _t * 8.0))
		var r1 := v.length()
		var dir := Vector2(cos(a), sin(a))
		var dir2 := Vector2(cos(a + w), sin(a + w))
		draw_colored_polygon(PackedVector2Array([_center + dir * r0, _center + dir * r1, _center + dir2 * r1]), Color(1, 1, 1, 0.13 * dim))
	# The slashed banner.
	var slide := _out(_t / 0.22)
	var band_h := 430.0
	var ang := -0.17
	var pal := AnimeFire.palette(momentum)
	var base_col: Color = Palette.ACCENT if momentum <= 0 else pal[0]
	if crushed:
		base_col = ChallengeIntro.TAPE
	var band_c := _center + Vector2(-v.x * 1.3 * (1.0 - slide), 0) + shake
	draw_set_transform(band_c, ang, Vector2.ONE)
	draw_rect(Rect2(-v.x, -band_h / 2.0 - 34.0, v.x * 2.0, 22.0), Color(Color.WHITE, 0.9))
	draw_rect(Rect2(-v.x, -band_h / 2.0, v.x * 2.0, band_h), base_col)
	draw_rect(Rect2(-v.x, -band_h / 2.0, v.x * 2.0, band_h * 0.42), base_col.lightened(0.18))
	draw_rect(Rect2(-v.x, band_h / 2.0 + 12.0, v.x * 2.0, 22.0), Color(Color.WHITE, 0.9))
	if crushed:
		# Hazard stripes along both edges of the band.
		for edge in [-band_h / 2.0, band_h / 2.0 - 40.0]:
			var x := -v.x
			while x < v.x:
				draw_colored_polygon(PackedVector2Array([Vector2(x, edge), Vector2(x + 40, edge), Vector2(x + 80, edge + 40), Vector2(x + 40, edge + 40)]), ChallengeIntro.INK)
				x += 80.0
	# Speed streaks along the band.
	for i in 9:
		var y := -band_h / 2.0 + 30.0 + i * band_h / 9.0
		var x := fmod(_t * 2600.0 + i * 977.0, v.x * 2.4) - v.x * 1.2
		draw_rect(Rect2(x, y, 260.0 + 140.0 * (i % 3), 8.0), Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Fire behind the van.
	if momentum > 0 and _t > SLAM_AT - 0.05:
		var grow := _out((_t - SLAM_AT + 0.05) / 0.35)
		AnimeFire.draw_aura(self, _van.position, Vector2(420, 260) * grow, _t, momentum, true)
	# Level name, top.
	var f := UiTheme.font()
	if _t > 0.15:
		var k := _out((_t - 0.15) / 0.2)
		var label := "LEVEL %d" % level.number if not daily else "DAILY #%d" % Daily.number(Daily.today())
		if side_title != "":
			label = "SIDE ROAD"
		if level.title != "":
			label += "  ·  " + level.title.to_upper()
		_skewed(label, Vector2(v.x / 2.0 + (1.0 - k) * 600.0, _center.y - 300.0) + shake, 52, Color.WHITE, INK, 10, 1.0)
	# DELIVERED!
	if _t > SLAM_AT - 0.08:
		var u := (_t - SLAM_AT + 0.08) / 0.16
		var s := lerpf(3.2, 1.0, _out(u))
		var alpha := clampf(u * 2.0, 0.0, 1.0)
		if crushed:
			_skewed("CHALLENGE", Vector2(v.x / 2.0, _center.y + 205.0) + shake, int(84 * s), Color.WHITE, INK, 14, alpha, Color(base_col.darkened(0.3), alpha))
			_skewed("CRUSHED!", Vector2(v.x / 2.0, _center.y + 320.0) + shake, int(156 * s), Color("fff3c4"), INK, 18, alpha, Color(Color("ff5a3c"), alpha))
		else:
			_skewed("DELIVERED!", Vector2(v.x / 2.0, _center.y + 300.0) + shake, int(150 * s), Color("fff3c4"), INK, 18, alpha, Color(base_col.darkened(0.25), alpha))
	# Stat panels.
	var stats := [["TIME", Daily.clock(secs)], ["STARS", ""], ["MOMENTUM", "×%d" % momentum if momentum > 0 else "–"]]
	for i in mini(_panels, 3):
		var k := _out((_t - PANEL_AT - i * PANEL_EVERY) / 0.22)
		var c := _stat_pos(i) + Vector2((1.0 - k) * v.x, 0)
		_panel(c, stats[i][0], stats[i][1], i)
	# Rewards and finds.
	if _t > PAY_AT - 0.1:
		var k := _pop((_t - PAY_AT + 0.1) / 0.3)
		var y := _stat_pos(2).y + 140.0
		var parts := []
		if reward > 0:
			parts.append("+%s Dollaroos" % Progress.commas(reward) + (" (%d bonus!)" % ChallengeIntro.BONUS if crushed else ""))
		if gas_back:
			parts.append("+1 gas")
		if not parts.is_empty():
			_centered("   ".join(parts), Vector2(v.x / 2.0, y), int(44 * k), Color("ffe08a"))
		if new_item != "":
			var kind: String = {"paint": "PAINT", "topper": "TOPPER", "ride": "RIDE"}.get(Cosmetics.kind_of(new_item), "ITEM")
			_centered("NEW %s!  %s" % [kind, Cosmetics.name_of(new_item)], Vector2(v.x / 2.0, y + 66.0), int(46 * k), Cosmetics.tint(new_item).lightened(0.3))
		elif missed_item:
			_centered("Something shiny was on the road...", Vector2(v.x / 2.0, y + 66.0), int(36 * k), Color(1, 1, 1, 0.65))
	draw_rect(Rect2(Vector2.ZERO, v), Color(1, 1, 1, maxf(0.0, 0.8 - _t * 7.0)))


## The van's white cut-out edge, drawn behind the van body (in the van's own space).
func _draw_cutout() -> void:
	var L := _van.size * 0.74
	var W := _van.size * 0.46
	DrawUtil.rrect(_van, Rect2(-L / 2 - 26, -W / 2 - 22, L + 52, W + 52), Color(INK, 0.5), W * 0.4)
	DrawUtil.rrect(_van, Rect2(-L / 2 - 22, -W / 2 - 22, L + 44, W + 44), Color.WHITE, W * 0.4)


## Flames in front of the van, and their embers.
func _draw_front() -> void:
	if momentum <= 0 or _t < SLAM_AT:
		return
	var grow := _out((_t - SLAM_AT) / 0.35)
	AnimeFire.draw_aura(_front, _van.position, Vector2(420, 260) * grow, _t, momentum, false)
	var pal := AnimeFire.palette(momentum)
	for i in 10 + mini(momentum, 8) * 3:
		var u := fmod(_t * (0.5 + 0.05 * (i % 5)) + i * 0.137, 1.0)
		var x := _van.position.x + sin(i * 12.9) * 260.0 + sin(_t * 3.0 + i) * 20.0
		var y := _van.position.y + 140.0 - u * (300.0 + 40.0 * mini(momentum, 8))
		_front.draw_circle(Vector2(x, y), 7.0 * (1.0 - u) + 2.0, Color(pal[2], 1.0 - u))
	if _t > SLAM_AT + 0.1:
		var name := AnimeFire.title(momentum)
		if name != "":
			var k := _pop((_t - SLAM_AT - 0.1) / 0.3)
			var f := UiTheme.font()
			var px := maxi(int(56 * k), 4)
			var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var at := _van.position + Vector2(140, -190)
			_front.draw_set_transform_matrix(Transform2D(-0.15, Vector2.ONE, -0.25, at))
			_front.draw_string_outline(f, Vector2(-w / 2.0, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 14, INK)
			_front.draw_string(f, Vector2(-w / 2.0, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, pal[2])
			_front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _skewed(text: String, at: Vector2, px: int, col: Color, outline: Color, ow: int, alpha := 1.0, shadow := Color.TRANSPARENT) -> void:
	if px < 4:
		return
	var f := UiTheme.font()
	# Letter by letter with a little tracking, outlines first, so thick outlines never eat a neighbour.
	var track := px * 0.07
	var widths := []
	var w := 0.0
	for ch in text:
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		widths.append(cw)
		w += cw + track
	w -= track
	var fit := minf(1.0, (size.x - 60.0) / maxf(w, 1.0))
	draw_set_transform_matrix(Transform2D(-0.06, Vector2(fit, fit), -0.2, at))
	for pass_i in 3:
		if pass_i == 0 and shadow.a <= 0.0:
			continue
		var x := -w / 2.0
		for i in text.length():
			var pos := Vector2(x, px * 0.35)
			match pass_i:
				0:
					draw_string_outline(f, pos + Vector2(10, 12), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow, shadow)
				1:
					draw_string_outline(f, pos, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow, Color(outline, alpha))
				2:
					draw_string(f, pos, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, alpha))
			x += widths[i] + track
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _centered(text: String, at: Vector2, px: int, col: Color) -> void:
	if px < 4:
		return
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string_outline(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 10, INK)
	draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## A slanted stat panel: label on the left, value on the right.
func _panel(c: Vector2, label: String, value: String, i: int) -> void:
	var w := 760.0
	var h := 96.0
	var sk := 30.0
	var poly := PackedVector2Array([c + Vector2(-w / 2 + sk, -h / 2), c + Vector2(w / 2 + sk, -h / 2), c + Vector2(w / 2 - sk, h / 2), c + Vector2(-w / 2 - sk, h / 2)])
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + Vector2(10, 10))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(poly, Color(0.16, 0.12, 0.24))
	var accent: Color = [Color("4dd2ff"), Palette.STAR_GOLD, AnimeFire.palette(momentum)[0] if momentum > 0 else Color(1, 1, 1, 0.4)][i]
	draw_colored_polygon(PackedVector2Array([poly[0], poly[0] + Vector2(18, 0), poly[3] + Vector2(18, 0), poly[3]]), accent)
	var f := UiTheme.font()
	draw_string(f, c + Vector2(-w / 2 + 50, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, 0.7))
	if i == 1:
		for k in 3:
			var at := c + Vector2(150.0 + (k - 1) * 70.0, 0)
			var lit := k < _landed
			Icons.star(self, at, 30.0, Palette.STAR_GOLD if lit else Color(1, 1, 1, 0.16))
	else:
		var vw := f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
		var vx := c.x + w / 2 - 70 - vw
		draw_string(f, Vector2(vx, c.y + 20), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 58, Color.WHITE)
		if i == 2 and momentum > 0:
			AnimeFire.draw_flame(self, Vector2(vx - 40, c.y + 26), 44, 64, _t, 3.0, AnimeFire.palette(momentum))
