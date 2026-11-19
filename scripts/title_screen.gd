class_name TitleScreen
extends Control
## The title: "Last Mile" over a little looping street where the van does its round forever, flinging the top
## package to each house as it passes and reloading at the depot, in time with the theme (the street is its
## rhythm section: see THEME). Play goes to the next unfinished level, Levels
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
## The theme: audio/theme.wav, composed and rendered by tools/make_theme.py, which has this same table (keep
## the two in step). One lap of the van is LAP_BEATS beats at THEME_BPM, driven at a steady speed, so what it
## passes lands on the beat: the depot on 0 (it loads up), the houses on theirs (each colour its own note),
## the two bridges (to-tok) and the gate (ka-chunk). Those sounds are in the tune; nothing here plays one.
const THEME := "res://audio/theme.wav"
const THEME_BPM := 132.0
const LAP_BEATS := 16.0
const THEME_DB := -7.0
const BRIDGE_BEATS := [4.0, 12.0]
const GATE_BEAT := 8.0
const GATE_COLOR := "green"
## A package is in the air this many beats, and lands on its house's beat.
const FLY_BEATS := 0.75
## Houses inside the loop: how far down the yard, colour, and the beat the van is level with it (which is
## where along the road it stands).
const HOUSES := [
	{"y": -95.0, "color": "red", "beat": 3.0},
	{"y": -95.0, "color": "blue", "beat": 5.0},
	{"y": 175.0, "color": "green", "beat": 11.0},
	{"y": 175.0, "color": "yellow", "beat": 13.0},
]
const TREES := [Vector2(-418, -345), Vector2(418, -345), Vector2(-418, 345), Vector2(418, 345),
		Vector2(-232, -356), Vector2(236, 356), Vector2(-430, -150), Vector2(430, 120)]
const WATER := Color("6fc3e8")

## True while something plays over the title (the studio card): no sounds.
var quiet := false

var _levels: Array = []
var _scene: Node2D
var _van: Van
var _houses: Array[House] = []
var _path := PackedVector2Array()
var _dist := PackedFloat32Array()
var _length := 0.0
var _d := 0.0
## The round's clock, in seconds: the theme's own while it plays (so the street can't drift off the beat),
## the frame clock otherwise (music off, or no sound device).
var _clock := 0.0
var _music: AudioStreamPlayer
var _music_tw: Tween
var _latency := 0.0
var _heard := -1.0
var _flights: Array = []       # packages in the air: {house, box, from (the beat it was thrown on)}
var _gate: Gate
var _gate_tw: Tween
## 1 on each beat, fading: the trees and the depot ring nod along.
var _pulse := 0.0
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
		house.base_pos = Vector2(_at(float(h["beat"]) / LAP_BEATS * _length).x, float(h["y"]))
		house.position = house.base_pos
		_scene.add_child(house)
		_houses.append(house)
	# The gate, across the right-hand road: it lifts for the van's next package as the van comes down to it.
	_gate = Gate.new()
	_gate.color = Palette.pkg(GATE_COLOR)
	_gate.tile = 130.0
	_gate.road_w = ROAD_W
	_gate.position = _at(GATE_BEAT / LAP_BEATS * _length)
	_gate.rotation = PI / 2.0
	_scene.add_child(_gate)
	_van = Van.new()
	_van.size = 150.0
	_scene.add_child(_van)
	_van.set_top(HOUSES[0]["color"])
	_place_van()
	_music = AudioStreamPlayer.new()
	if ResourceLoader.exists(THEME):
		var st := load(THEME) as AudioStreamWAV
		if st:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = int(round(st.get_length() * st.mix_rate))
			_music.stream = st
	add_child(_music)
	_latency = AudioServer.get_output_latency()

	_title = _label("Last Mile", 210, Palette.TEXT, _fredoka())
	_title.add_theme_color_override("font_shadow_color", Color(0.23, 0.2, 0.27, 0.16))
	_title.add_theme_constant_override("shadow_offset_y", 12)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_tagline = _label("Draw the route. Mind the order.", 46, Palette.TEXT_SOFT)

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
	_row.add_child(_small("grid", "Jobs", _on_levels))
	var daily: JuicyButton
	daily = _small("calendar", "Daily", func():
		if not Daily.unlocked():
			Sfx.play("bonk", 1.1, -6.0)
			daily.pop()
			return
		Sfx.play("click")
		daily_pressed.emit())
	var today := Daily.today()
	var streak := Progress.streak(today)
	# The streak burns inside the button; if today's is still to do, the button breathes. Locked until
	# job Daily.UNLOCK_AT: a padlock, greyed.
	daily.flame = streak
	_row.add_child(daily)
	if not Daily.unlocked():
		daily.icon_name = "lock"
		daily.flame = 0
		daily.dim = true
	elif not Progress.daily_record(today).get("done", false):
		daily.ready.connect(daily.breathe.bind(true), CONNECT_DEFERRED)
	_row.add_child(_small("paint", "Garage", func():
		Sfx.play("click")
		garage_pressed.emit()))

	# Speedrun: its own mode, locked until the player has met every mechanic it uses.
	_speed = JuicyButton.new()
	var open := Progress.is_complete(Speedrun.UNLOCK_LEVEL)
	_speed.icon_name = "next" if open else ""
	_speed.label = "Speedrun" if open else "Speedrun · beat job %d" % Speedrun.UNLOCK_LEVEL
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
				Sfx.haptic(12, 0.6, "title_screen:_ready")
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
	var L: LevelData = _levels[maxi(Zones.frontier(_levels), 0)]
	return "Job %d · %s" % [L.number, L.title]


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
	# The stub's 88 wide: a longer number ("v0.7a") steps the size down to fit.
	var vfs := 40
	while vfs > 26 and f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x > 78:
		vfs -= 2
	var vw := f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x
	_badge.draw_string(f, Vector2(-74 - vw / 2.0, 14 - (40 - vfs) * 0.36), v, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs, Color.WHITE)
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
	_pulse = maxf(_pulse - delta * 4.0, 0.0)
	_scene.queue_redraw()
	_badge.queue_redraw()
	_tune()
	if quiet:
		return           # (something's playing over the title: the van waits at the depot for the downbeat)
	var beat_secs := 60.0 / THEME_BPM
	var lap := LAP_BEATS * beat_secs
	var before := _clock
	_clock += delta
	var jumped := false
	if _music.playing:
		# The tune's clock, not ours. (Only once it's seen to move: with no sound device it never does.)
		var heard := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - _latency
		if not is_equal_approx(heard, _heard):
			_heard = heard
			var off := wrapf(heard - _clock, -lap / 2.0, lap / 2.0)
			jumped = absf(off) > 0.08
			_clock += off if jumped else off * 0.25
	var b1 := fposmod(_clock, lap) / beat_secs
	if not jumped:
		_round(fposmod(before, lap) / beat_secs, b1)
	# Packages in the air fly on the tune's clock too, so each lands on its beat whatever the frame rate does.
	for f in _flights.duplicate():
		var k := fposmod(b1 - float(f["from"]), LAP_BEATS) / FLY_BEATS
		if k >= 1.0:
			_flights.erase(f)
			_landed(f["house"], f["box"])
		else:
			(f["box"] as FlyBox).t = 0.5 - 0.5 * cos(PI * k)
	_d = b1 / LAP_BEATS * _length
	_place_van()


## The theme plays while the title's showing and nothing's over it (and Music is on in Options). It starts
## from the top, with the van at the depot.
func _tune() -> void:
	var want := not quiet and is_visible_in_tree() and Progress.music and _music.stream != null
	if want == _music.playing:
		return
	if _music_tw and _music_tw.is_valid():
		_music_tw.kill()
	if not want:
		_music.stop()
		return
	_clock = 0.0
	_heard = -1.0
	for f in _flights:
		f["box"].queue_free()
	_flights.clear()
	_reload()
	_music.volume_db = -30.0
	_music.play()
	_music_tw = create_tween()
	_music_tw.tween_property(_music, "volume_db", THEME_DB, 0.5).set_ease(Tween.EASE_OUT)


## What happens between beats `b0` and `b1` of the lap (b1 < b0: the van's just passed the depot).
func _round(b0: float, b1: float) -> void:
	var passed := func(beat: float) -> bool:
		beat = fposmod(beat, LAP_BEATS)
		return (b0 < beat and beat <= b1) if b1 >= b0 else (beat > b0 or beat <= b1)
	if b1 < b0:
		_reload()
	if int(floor(b1)) != int(floor(b0)):
		_pulse = 1.0
	for i in HOUSES.size():
		# Thrown early, to land on the beat.
		var beat: float = HOUSES[i]["beat"]
		if passed.call(beat - FLY_BEATS):
			_fling(i, beat - FLY_BEATS)
	for beat in BRIDGE_BEATS:
		if passed.call(beat):
			_van.shake()
	if passed.call(GATE_BEAT - 0.5):
		_swing_gate(1.0, 0.5 * 60.0 / THEME_BPM, Tween.TRANS_BACK)
	if passed.call(GATE_BEAT + 1.0):
		_swing_gate(0.0, 0.22, Tween.TRANS_BOUNCE)


func _swing_gate(to: float, secs: float, trans: Tween.TransitionType) -> void:
	if _gate_tw and _gate_tw.is_valid():
		_gate_tw.kill()
	_gate_tw = _gate.create_tween()
	_gate_tw.tween_property(_gate, "open_t", to, secs).set_trans(trans).set_ease(Tween.EASE_OUT)


func _place_van() -> void:
	var p := _at(_d)
	var ahead := _at(fmod(_d + 6.0, _length)) - _at(fmod(_d - 6.0 + _length, _length))
	_van.position = p
	if ahead.length() > 0.01:
		_van.target_rotation = ahead.angle()


## The van throws its top package at house `i` (on beat `from` of the lap; it lands FLY_BEATS later).
func _fling(i: int, from: float) -> void:
	var house := _houses[i]
	var box := FlyBox.new()
	box.color = Palette.pkg(HOUSES[i]["color"])
	box.from = _van.position
	box.to = house.position + Vector2(0, -house.size * 0.32)
	_scene.add_child(box)
	_van.set_top(HOUSES[i + 1]["color"] if i + 1 < HOUSES.size() else "")
	_van.squash()
	_flights.append({"house": i, "box": box, "from": from})


func _landed(i: int, box: Node2D) -> void:
	box.queue_free()
	_houses[i].deliver()
	# The note it just played, where you can see it: a ring out from the house and a quaver floating off it.
	var pop := NotePop.new()
	pop.color = Palette.pkg(HOUSES[i]["color"])
	pop.position = _houses[i].position + Vector2(0, -_houses[i].size * 0.3)
	_scene.add_child(pop)
	_van.nudge()


## Passing the depot: the houses reset and the van loads up, without stopping.
func _reload() -> void:
	for k in _houses.size():
		get_tree().create_timer(0.1 * k).timeout.connect(_reset_house.bind(_houses[k]))
	_van.set_top(HOUSES[0]["color"])
	_van.nudge()


func _reset_house(house: House) -> void:
	if is_instance_valid(house):
		house.undeliver(0)


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


func _draw_scene() -> void:
	var s := _scene
	DrawUtil.rrect(s, Rect2(GRASS.position + Vector2(0, 18), GRASS.size), Palette.BOARD_SHADOW, 80)
	DrawUtil.rrect(s, GRASS, Palette.GRASS, 80)
	var inner := Rect2(-LOOP + Vector2(ROAD_W, ROAD_W) * 0.62, (LOOP - Vector2(ROAD_W, ROAD_W) * 0.62) * 2.0)
	DrawUtil.rrect(s, inner, Palette.YARD, 50)
	# A stream down the middle, under both roads (they cross it on the two bridges).
	var stream := PackedVector2Array()
	var y := GRASS.position.y + 14.0
	while y <= GRASS.end.y - 14.0:
		stream.append(Vector2(13.0 * sin(PI * y / 135.0), y))
		y += 12.0
	s.draw_polyline(stream, WATER.darkened(0.18), 44.0, true)
	s.draw_polyline(stream, WATER, 34.0, true)
	for k in 7:
		var wy := GRASS.position.y + 60.0 + k * 105.0 + fmod(_t * 26.0, 105.0)
		if wy < GRASS.end.y - 40.0:
			var wx := 13.0 * sin(PI * wy / 135.0)
			s.draw_line(Vector2(wx - 7, wy), Vector2(wx + 7, wy), Color(1, 1, 1, 0.5), 3.0, true)
	# Road: a darker curb pass a little lower, then the tarmac, then lane dashes.
	var closed := PackedVector2Array(_path)
	var curb := Transform2D(0.0, Vector2(0, 5)) * closed
	s.draw_polyline(curb, Palette.ROAD_EDGE, ROAD_W, true)
	s.draw_polyline(closed, Palette.ROAD, ROAD_W - 6, true)
	var d := 0.0
	while d < _length - 30.0:
		s.draw_line(_at(d), _at(d + 22.0), Palette.ROAD_MARK, 4.0, true)
		d += 44.0
	# The bridges: a deck with rails over the stream, top and bottom.
	for beat in BRIDGE_BEATS:
		var c := _at(float(beat) / LAP_BEATS * _length)
		var deck := Rect2(c - Vector2(46, ROAD_W / 2.0), Vector2(92, ROAD_W))
		s.draw_rect(Rect2(deck.position - Vector2(9, 0), Vector2(9, ROAD_W)), Palette.BRIDGE_SHADOW)
		s.draw_rect(Rect2(Vector2(deck.end.x, deck.position.y), Vector2(9, ROAD_W)), Palette.BRIDGE_SHADOW)
		DrawUtil.rrect(s, deck.grow_individual(4, 8, 4, 8), Palette.RAIL, 7)
		s.draw_rect(deck, Palette.BRIDGE_DECK)
		for k in 5:
			var px := deck.position.x + 9.0 + k * 18.5
			s.draw_line(Vector2(px, deck.position.y + 3), Vector2(px, deck.end.y - 3), Color(0, 0, 0, 0.14), 2.0)
		s.draw_dashed_line(Vector2(deck.position.x, c.y), Vector2(deck.end.x, c.y), Palette.ROAD_MARK, 4.0, 14.0, true, true)
	# Depot ring where each round starts: it flares on the beat.
	var depot := Vector2(-LOOP.x, 0)
	s.draw_arc(depot, 40 + 5.0 * _pulse, 0, TAU, 40, Color(Palette.DEPOT, 0.7 + 0.3 * _pulse), 6.0, true)
	for t in TREES:
		var r := (30.0 + fmod(absf(t.x * 0.37 + t.y * 0.11), 9.0)) * (1.0 + 0.05 * _pulse)
		s.draw_circle(t + Vector2(0, r * 0.35), r * 1.02, Color(0, 0, 0, 0.12))
		s.draw_circle(t, r, Palette.TREE)
		s.draw_circle(t + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Palette.TREE_HI)


## A delivery's note: a ring that opens out and a quaver that drifts up and fades, in the package's colour.
class NotePop:
	extends Node2D

	var color := Color.WHITE
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_property(self, "t", 1.0, 0.7)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var out := 1.0 - pow(1.0 - t, 3.0)
		draw_arc(Vector2(0, 40), 70.0 + 80.0 * out, 0, TAU, 48, Color(color, 0.85 * (1.0 - t)), 10.0 * (1.0 - t) + 2.0, true)
		var at := Vector2(34.0 + 10.0 * sin(t * 5.0), -70.0 - 90.0 * out)
		var a := minf(1.0, (1.0 - t) * 2.5)
		Icons.draw(self, "note", at + Vector2(0, 4), 64.0 * (0.7 + 0.3 * minf(t * 6.0, 1.0)), Color(0.17, 0.13, 0.2, 0.35 * a))
		Icons.draw(self, "note", at, 64.0 * (0.7 + 0.3 * minf(t * 6.0, 1.0)), Color(color.lightened(0.15), a))


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
