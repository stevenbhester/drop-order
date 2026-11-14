class_name TitleScreen
extends Control
## The title: "Last Mile" over a little looping street where the van does its round forever, flinging the top
## package to each house as it passes and reloading at the depot. Play goes to the next unfinished level, Levels
## to the level select. The studio card (StudioCard) plays over it once a launch. Top left, the version badge
## (a "NEW" sticker until its patch notes have been read) opens the patch notes; when TestFlight has a newer
## build (UpdateCheck) it wears an "UPDATE" sticker and offers that instead.

signal play_pressed
signal levels_pressed
signal daily_pressed
signal garage_pressed
signal options_pressed
signal notes_pressed
signal speedrun_pressed
signal og_pressed

## The loop's half extents and corner radius (its centre line), and the road's width.
const LOOP := Vector2(330, 270)
const CORNER := 120.0
const ROAD_W := 100.0
const GRASS := Rect2(-470, -395, 940, 790)
const VAN_SPEED := 340.0
## Seconds parked at the depot between rounds.
const DEPOT_PAUSE := 0.8
## Houses inside the loop: base position (scene space), colour, and the road point the van flings from.
const HOUSES := [
	{"at": Vector2(-150, -95), "color": "red", "from": Vector2(-150, -270)},
	{"at": Vector2(150, -95), "color": "blue", "from": Vector2(150, -270)},
	{"at": Vector2(150, 175), "color": "green", "from": Vector2(150, 270)},
	{"at": Vector2(-150, 175), "color": "yellow", "from": Vector2(-150, 270)},
]
const TREES := [Vector2(-418, -345), Vector2(418, -345), Vector2(-418, 345), Vector2(418, 345),
		Vector2(0, -352), Vector2(0, 40), Vector2(-430, -150), Vector2(430, 120)]

## True while something plays over the title (the studio card): no sounds.
var quiet := false

var _levels: Array = []
var _scene: Node2D
var _van: Van
var _houses: Array[House] = []
var _path := PackedVector2Array()
var _dist := PackedFloat32Array()
var _length := 0.0
var _triggers: Array[float] = []
var _d := 0.0
var _next_house := 0
var _pause := 0.4
var _since_go := 0.0
var _title: Label
var _tagline: Label
var _play: Button
var _next_label: Label
var _row: HBoxContainer
var _footer: Label
var _gear: JuicyButton
var _badge: Control
var _speed: JuicyButton
var _og: JuicyButton
var _badge_press := 0.0
var _t := 0.0


func setup(lvls: Array) -> void:
	_levels = lvls


func _all_beaten() -> bool:
	if _levels.is_empty():
		return false
	for L in _levels:
		if not Progress.is_complete(L.number):
			return false
	return true


func _ready() -> void:
	theme = UiTheme.theme()
	_build_path()
	_scene = Node2D.new()
	_scene.draw.connect(_draw_scene)
	add_child(_scene)
	for h in HOUSES:
		var house := House.new()
		house.color = Palette.pkg(h["color"])
		house.size = 165.0
		house.base_pos = h["at"]
		house.position = h["at"]
		_scene.add_child(house)
		_houses.append(house)
		_triggers.append(_dist_of(h["from"]))
	_van = Van.new()
	_van.size = 150.0
	_scene.add_child(_van)
	_van.set_top(HOUSES[0]["color"])
	_place_van()

	_title = _label("Last Mile", 210, Palette.TEXT, _fredoka())
	_title.add_theme_color_override("font_shadow_color", Color(0.23, 0.2, 0.27, 0.16))
	_title.add_theme_constant_override("shadow_offset_y", 12)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_tagline = _label("Draw the route. Mind the stack.", 46, Palette.TEXT_SOFT)

	_play = Button.new()
	_play.text = "Play"
	_play.custom_minimum_size = Vector2(600, 180)
	_play.add_theme_font_size_override("font_size", 88)
	_play.add_theme_font_override("font", _fredoka())
	UiTheme.button_style(_play, Palette.ACCENT, Color.WHITE)
	_play.pressed.connect(_on_play)
	add_child(_play)
	_next_label = _label(_next_text(), 40, Palette.TEXT_SOFT)

	# Levels, Daily (its streak as a flame in the button; it breathes if today's isn't done) and Garage.
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 22)
	add_child(_row)
	_row.add_child(_small("grid", "Levels", _on_levels))
	var daily := _small("calendar", "Daily", func():
		Sfx.play("click")
		daily_pressed.emit())
	var today := Daily.today()
	var streak := Progress.streak(today)
	# The streak burns inside the button; if today's is still to do, the button breathes.
	daily.flame = streak
	_row.add_child(daily)
	if not Progress.daily_record(today).get("done", false):
		daily.ready.connect(daily.breathe.bind(true), CONNECT_DEFERRED)
	_row.add_child(_small("paint", "Garage", func():
		Sfx.play("click")
		garage_pressed.emit()))

	# Speedrun: its own mode, locked until the player has met every mechanic it uses.
	_speed = JuicyButton.new()
	var open := Progress.is_complete(Speedrun.UNLOCK_LEVEL)
	_speed.icon_name = "next" if open else ""
	_speed.label = "Speedrun" if open else "Speedrun · beat level %d" % Speedrun.UNLOCK_LEVEL
	_speed.font_px = 40
	_speed.dim = not open
	_speed.custom_minimum_size = Vector2(600, 110)
	_speed.size = _speed.custom_minimum_size
	_speed.pressed.connect(func():
		if Progress.is_complete(Speedrun.UNLOCK_LEVEL):
			Sfx.play("click")
			speedrun_pressed.emit()
		else:
			Sfx.play("bonk", 1.1, -6.0)
			_speed.pop())
	add_child(_speed)

	# The OG 100 (the levels as they used to be): not even here until every level's beaten.
	_og = JuicyButton.new()
	_og.label = "The OG 100"
	_og.icon_name = "undo"
	_og.font_px = 40
	_og.custom_minimum_size = Vector2(600, 110)
	_og.size = _og.custom_minimum_size
	_og.visible = _all_beaten()
	_og.pressed.connect(func():
		Sfx.play("click")
		og_pressed.emit())
	add_child(_og)

	_footer = _label("a Door Bowl game", 34, Palette.TEXT_SOFT)

	_gear = JuicyButton.new()
	_gear.icon_name = "gear"
	_gear.custom_minimum_size = Vector2(112, 102)
	_gear.size = Vector2(112, 102)
	_gear.pressed.connect(func():
		Sfx.play("click")
		options_pressed.emit())
	add_child(_gear)

	_badge = Control.new()
	_badge.size = Vector2(250, 102)
	_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	_badge.draw.connect(_draw_badge)
	_badge.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_badge.accept_event()
			if e.pressed:
				_badge_press = 1.0
			elif _badge_press > 0.0:
				_badge_press = 0.0
				Sfx.play("click")
				Sfx.haptic(12, 0.6)
				notes_pressed.emit())
	add_child(_badge)

	_fit()
	get_viewport().size_changed.connect(_fit)
	# Play breathes, to invite the tap.
	_play.pivot_offset = _play.custom_minimum_size / 2.0
	var breath := _play.create_tween().set_loops()
	breath.tween_property(_play, "scale", Vector2(1.05, 1.05), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_play, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _small(icon: String, text: String, cb: Callable) -> JuicyButton:
	var b := JuicyButton.new()
	b.icon_name = icon
	b.label = text
	b.font_px = 40
	b.custom_minimum_size = Vector2(300, 130)
	b.pressed.connect(cb)
	return b


func _label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _fredoka() -> Font:
	var path := "res://assets/fonts/Fredoka.ttf"
	if not ResourceLoader.exists(path):
		return UiTheme.font()
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	return f


func _next_text() -> String:
	var done := 0
	for L in _levels:
		if Progress.is_complete(L.number):
			done += 1
	if _levels.is_empty():
		return ""
	if done == _levels.size():
		return "All %d delivered!" % done
	var L: LevelData = _levels[Progress.first_incomplete(_levels.size())]
	return "Level %d · %s" % [L.number, L.title]


## Lays everything out for the screen's height (taller phones spread it out).
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var w := size.x
	# Extra height past 16:9 (phones are taller): the street grows to full size and the gaps open up.
	var e := maxf(size.y - 1920.0, 0.0)
	var k := clampf(e / 350.0, 0.0, 1.0)
	var street := lerpf(0.88, 1.0, k)
	var half := GRASS.size.y / 2.0 * street
	var title_y := 120.0 + e * 0.25
	_title.position = Vector2(0, title_y)
	_title.size = Vector2(w, 0)
	_tagline.position = Vector2(0, title_y + 262)
	_tagline.size = Vector2(w, 0)
	var scene_y := title_y + 262 + 90 + half + e * 0.15
	_scene.position = Vector2(w / 2.0, scene_y)
	_scene.scale = Vector2(street, street)
	var play_y := scene_y + half + 70 + e * 0.1
	_play.position = Vector2((w - _play.custom_minimum_size.x) / 2.0, play_y)
	_next_label.position = Vector2(0, play_y + 196)
	_next_label.size = Vector2(w, 0)
	_row.size = Vector2(300 * 3 + 44, 130)
	_row.position = Vector2((w - _row.size.x) / 2.0, play_y + 270)
	_speed.position = Vector2((w - _speed.size.x) / 2.0, play_y + 430)
	_og.position = Vector2((w - _og.size.x) / 2.0, play_y + 556)
	_footer.position = Vector2(0, maxf(size.y - 90.0, play_y + (700 if _og.visible else 570)))
	_footer.visible = _footer.position.y + 50.0 <= size.y      # on short screens the OG button takes its place
	_footer.size = Vector2(w, 0)
	_gear.position = Vector2(w - 36 - 112, 40 + UiTheme.insets(get_viewport()).x)
	_badge.position = Vector2(36, 40 + UiTheme.insets(get_viewport()).x)


## The version badge: a tilted ticket stub ("v0.4" and the update's name) with a star sticker, and a bouncing
## "NEW" sticker while its notes are unread. It sinks a little while pressed.
func _draw_badge() -> void:
	var f := UiTheme.font()
	var sink := 4.0 * _badge_press
	_badge.draw_set_transform(Vector2(125, 51 + sink), -0.05, Vector2.ONE * (1.0 - 0.04 * _badge_press))
	var r := Rect2(-118, -38, 236, 76)
	DrawUtil.rrect(_badge, Rect2(r.position + Vector2(0, 7 - sink), r.size), Palette.ACCENT.darkened(0.3), 24)
	DrawUtil.rrect(_badge, r, Palette.ACCENT, 24)
	# The stub's perforation, and the update's name on the right.
	for k in 5:
		_badge.draw_circle(Vector2(-30, -28 + k * 14), 3.0, Color(1, 1, 1, 0.45))
	var v := "v" + Version.NUMBER
	var vw := f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_badge.draw_string(f, Vector2(-74 - vw / 2.0, 14), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	_badge.draw_string(f, Vector2(-16, -4), "WHAT'S", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.8))
	_badge.draw_string(f, Vector2(-16, 24), "NEW?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	Icons.star(_badge, Vector2(96, -6), 16.0, Palette.STAR_GOLD, _t * 0.8)
	if UpdateCheck.available():
		# A newer build is out: an "UPDATE" sticker (the badge then offers it).
		var b := Vector2(100, -34) + Vector2(0, -6.0 * absf(sin(_t * 3.0)))
		_badge.draw_set_transform(Vector2(125, 51 + sink) + b.rotated(-0.05), 0.2, Vector2.ONE)
		var uw := f.get_string_size("UPDATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var pr := Rect2(-uw / 2.0 - 18, -24, uw + 36, 48)
		DrawUtil.rrect(_badge, Rect2(pr.position + Vector2(0, 4), pr.size), Color(0, 0, 0, 0.18), 24)
		DrawUtil.rrect(_badge, pr, Palette.GOOD, 24)
		_badge.draw_string(f, Vector2(-uw / 2.0, 9), "UPDATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	elif Version.unseen():
		var b := Vector2(108, -34) + Vector2(0, -6.0 * absf(sin(_t * 3.0)))
		_badge.draw_set_transform(Vector2(125, 51 + sink) + b.rotated(-0.05), 0.25, Vector2.ONE)
		_badge.draw_circle(Vector2(0, 3), 30.0, Color(0, 0, 0, 0.18))
		_badge.draw_circle(Vector2.ZERO, 30.0, Color("ff4d6d"))
		var nw := f.get_string_size("NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_badge.draw_string(f, Vector2(-nw / 2.0, 8), "NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	_badge.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_on_play()


func _on_play() -> void:
	Sfx.play("click")
	play_pressed.emit()


func _on_levels() -> void:
	Sfx.play("click")
	levels_pressed.emit()


# --- The little round ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_scene.queue_redraw()
	_badge.queue_redraw()
	if _pause > 0.0:
		_pause -= delta
		_since_go = 0.0
		return
	_since_go += delta
	# Pull away gently, and ease into the depot at the end of the round.
	var speed := VAN_SPEED * minf(_since_go / 0.45, 1.0) * clampf((_length - _d) / 220.0, 0.22, 1.0)
	var before := _d
	_d += speed * delta
	while _next_house < _triggers.size() and before < _triggers[_next_house] and _d >= _triggers[_next_house]:
		_fling(_next_house)
		_next_house += 1
	if _d >= _length:
		_d = 0.0
		_reload()
	_place_van()


func _place_van() -> void:
	var p := _at(_d)
	var ahead := _at(fmod(_d + 6.0, _length)) - _at(fmod(_d - 6.0 + _length, _length))
	_van.position = p
	if ahead.length() > 0.01:
		_van.target_rotation = ahead.angle()


## The van throws its top package at house `i`.
func _fling(i: int) -> void:
	var house := _houses[i]
	var box := FlyBox.new()
	box.color = Palette.pkg(HOUSES[i]["color"])
	box.from = _van.position
	box.to = house.position + Vector2(0, -house.size * 0.32)
	_scene.add_child(box)
	_van.set_top(HOUSES[i + 1]["color"] if i + 1 < HOUSES.size() else "")
	_van.squash()
	_sound("whoosh", 1.1 + i * 0.04, -16.0)
	var tw := box.create_tween()
	tw.tween_property(box, "t", 1.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_landed.bind(i, box))


func _landed(i: int, box: Node2D) -> void:
	box.queue_free()
	_houses[i].deliver()
	_sound("pop", 1.0 + i * 0.08, -12.0)


## Back at the depot: houses reset, the van loads up, and after a pause it sets off again.
func _reload() -> void:
	_next_house = 0
	_pause = DEPOT_PAUSE
	_van.stop_bounce()
	for k in _houses.size():
		var house := _houses[k]
		get_tree().create_timer(0.12 * k).timeout.connect(_reset_house.bind(house))
	get_tree().create_timer(0.5).timeout.connect(_load_van)


func _reset_house(house: House) -> void:
	if is_instance_valid(house):
		house.undeliver(0)


func _load_van() -> void:
	if not is_instance_valid(_van):
		return
	_van.set_top(HOUSES[0]["color"])
	_van.nudge()
	_sound("pickup", 1.0, -16.0)


func _sound(sound: String, pitch: float, db: float) -> void:
	if not quiet and is_visible_in_tree():
		Sfx.play(sound, pitch, db)


# --- The street's shape ----------------------------------------------------------------------------------

## The loop's centre line, clockwise from the depot (middle of the left side).
func _build_path() -> void:
	var a := LOOP - Vector2(CORNER, CORNER)
	_path.append(Vector2(-LOOP.x, 0))
	var corners := [[Vector2(-a.x, -a.y), PI], [Vector2(a.x, -a.y), PI * 1.5], [Vector2(a.x, a.y), 0.0], [Vector2(-a.x, a.y), PI * 0.5]]
	for c in corners:
		for s in 13:
			var ang: float = c[1] + PI * 0.5 * s / 12.0
			_path.append(c[0] + Vector2(cos(ang), sin(ang)) * CORNER)
	_path.append(Vector2(-LOOP.x, 0))
	_dist.append(0.0)
	for i in range(1, _path.size()):
		_dist.append(_dist[i - 1] + _path[i].distance_to(_path[i - 1]))
	_length = _dist[_dist.size() - 1]


func _at(d: float) -> Vector2:
	for i in range(1, _path.size()):
		if _dist[i] >= d:
			var seg := _dist[i] - _dist[i - 1]
			var k := (d - _dist[i - 1]) / seg if seg > 0.0 else 0.0
			return _path[i - 1].lerp(_path[i], k)
	return _path[_path.size() - 1]


## How far round the loop the point nearest `p` is.
func _dist_of(p: Vector2) -> float:
	var best := 0.0
	var best_gap := INF
	var d := 0.0
	while d < _length:
		var gap := _at(d).distance_squared_to(p)
		if gap < best_gap:
			best_gap = gap
			best = d
		d += 4.0
	return best


func _draw_scene() -> void:
	var s := _scene
	DrawUtil.rrect(s, Rect2(GRASS.position + Vector2(0, 18), GRASS.size), Palette.BOARD_SHADOW, 80)
	DrawUtil.rrect(s, GRASS, Palette.GRASS, 80)
	var inner := Rect2(-LOOP + Vector2(ROAD_W, ROAD_W) * 0.62, (LOOP - Vector2(ROAD_W, ROAD_W) * 0.62) * 2.0)
	DrawUtil.rrect(s, inner, Palette.YARD, 50)
	# Road: a darker curb pass a little lower, then the tarmac, then lane dashes.
	var closed := PackedVector2Array(_path)
	var curb := Transform2D(0.0, Vector2(0, 5)) * closed
	s.draw_polyline(curb, Palette.ROAD_EDGE, ROAD_W, true)
	s.draw_polyline(closed, Palette.ROAD, ROAD_W - 6, true)
	var d := 0.0
	while d < _length - 30.0:
		s.draw_line(_at(d), _at(d + 22.0), Palette.ROAD_MARK, 4.0, true)
		d += 44.0
	# Depot ring where each round starts.
	var depot := Vector2(-LOOP.x, 0)
	var glow := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 3.0)) if _pause > 0.0 else 0.85
	s.draw_arc(depot, 40, 0, TAU, 40, Color(Palette.DEPOT, glow), 6.0, true)
	for t in TREES:
		var r := 30.0 + fmod(absf(t.x * 0.37 + t.y * 0.11), 9.0)
		s.draw_circle(t + Vector2(0, r * 0.35), r * 1.02, Color(0, 0, 0, 0.12))
		s.draw_circle(t, r, Palette.TREE)
		s.draw_circle(t + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Palette.TREE_HI)


## A package in flight from the van to a house, on a little arc.
class FlyBox:
	extends Node2D

	var color := Color.WHITE
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var t := 0.0:
		set(v):
			t = v
			var lift := Vector2(0, -110.0 * 4.0 * t * (1.0 - t))
			position = from.lerp(to, t) + lift
			scale = Vector2.ONE * (1.0 + 0.35 * sin(PI * t))
			queue_redraw()

	func _ready() -> void:
		position = from

	func _draw() -> void:
		DrawUtil.package(self, Vector2.ZERO, 52.0, color)
