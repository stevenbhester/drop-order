class_name TitleScreen
extends Control
## The title: "Last Mile" over a little looping street where the van does its round forever, flinging the top
## package to each house as it passes and reloading at the depot. Play goes to the next unfinished level, Levels
## to the level select. The studio card (StudioCard) plays over it once a launch.

signal play_pressed
signal levels_pressed

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
var _levels_btn: Button
var _footer: Label
var _t := 0.0


func setup(lvls: Array) -> void:
	_levels = lvls


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

	_levels_btn = Button.new()
	_levels_btn.text = "Levels"
	_levels_btn.custom_minimum_size = Vector2(440, 140)
	_levels_btn.add_theme_font_size_override("font_size", 54)
	_levels_btn.pressed.connect(_on_levels)
	add_child(_levels_btn)

	_footer = _label("a Door Bowl game", 34, Palette.TEXT_SOFT)

	_fit()
	get_viewport().size_changed.connect(_fit)


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
	_levels_btn.position = Vector2((w - _levels_btn.custom_minimum_size.x) / 2.0, play_y + 270)
	_footer.position = Vector2(0, maxf(size.y - 110.0, play_y + 440))
	_footer.size = Vector2(w, 0)


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
