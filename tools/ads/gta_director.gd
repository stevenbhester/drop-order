class_name GtaDirector
extends Node2D
## The "GTA VI" trash-talk ad (a joke for friends, not a real ad). About 28 seconds:
##   1. BREAKING NEWS: five real headlines about publishers dodging GTA VI's release, quoted word for word
##      with their outlets, piling up on a newsroom background with a ticker.
##   2. Record scratch. "NO GAME DARES???"
##   3. The song kicks in: "LAST MILE / DOESN'T GIVE A / &@$*&!!!!", slammed on its first hits.
##   4. A fancam edit of level 45 (Grand Tour): follow cam, zoom punches, tilts, RGB split, flashes and speed
##      ramps on the song's hits, the fire getting hotter (red, blue, violet), then the "DELIVERED!" finish.
##   5. "ROCKSTAR. / DELAY GTA VI / OR BE WRECKED / BY THE BEST GAME / ON FOUR WHEELS."
##   6. "DROPPING NOVEMBER 19, 2026. IT'S THE ONLY GAME YOU'RE GONNA BE HEARING ABOUT."
## The song is the user's own file (-- --song=<path>); its first ~21 seconds are used. Hits were measured from
## it: about 87.7 BPM, first beat at 0.53 s. Everything is timed in frames (30 fps).

signal finished

const FPS := 30.0
const INK := Color(0.07, 0.05, 0.12)
const YELLOW := Color("ffe14d")
const RED := Color("ff2e3e")
const NEWS_RED := Color("d7192a")
const NAVY := Color("0b1630")

## Real headlines (exact wording) and where they ran.
const HEADLINES := [
	["TWEAKTOWN", "GTA 6 release has every other game developer scared, publishers pushing launch dates far away"],
	["TECHRADAR", "Publishers are reportedly not announcing firm release dates to dodge GTA 6 launch"],
	["TECHSPOT", "Game publishers are refusing to commit to release dates for fear of clashing with GTA 6"],
	["DEXERTO", "GTA 6 reportedly has major publishers so scared they're delaying games to avoid competition"],
	["MEIN-MMO", "Even the biggest publishers fear the release of GTA 6: “A huge meteor”"],
]
const NEWS_T0 := 0.3
const NEWS_EVERY := 1.1
const DARES_T := 5.95
const SONG_T := 7.65          # the song starts here (its own t = 0)
const BEAT := 60.0 / 87.7
const BEAT0 := 0.53
## Song-time hits used by the fancam (kick/snare onsets measured from the track).
const FANCAM_HITS := [3.95, 4.63, 4.98, 5.32, 6.35, 7.03, 7.71]
const CUT_IN := 2.58          # song time the fancam starts
const WIN_AT := 8.45          # song time the level should be won (so "DELIVERED!" lands on the 9.08 hit)
const CHALLENGE_AT := 11.48
const RELEASE_AT := 15.58
const SONG_END := 20.9

var main: Node
var view: Sprite2D
var game_vp: SubViewport
var g: Game

var _frame := 0
var _t := 0.0
var _font: Font
var _song: AudioStreamPlayer
var _bed: AudioStreamPlayer
var _shake := 0.0
var _flash := 0.0
var _split := 0.0
var _invert := 0.0
var _mono := 0.0
var _blur := 0.0
var _zoom := 1.0
var _punch := 0.0
var _tilt := 0.0
var _tilt_to := 0.0
var _cam := Vector2(540, 960)
var _fancam := false
var _scene := "news"          # news, dares, gauntlet, fancam, finish, challenge, release
var _words: Array = []        # {text, t0, at, px, col, rot}: fancam flash words
var _hit_i := 0
var _last_hit := -10.0
var _won := false
var _end_van: Van
var _end_fire: AnimeFire
var _fire_last := Vector2.INF


func _ready() -> void:
	_font = _fredoka()
	var song_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--song="):
			song_path = a.trim_prefix("--song=")
	if main and main.get("screen") is Game:
		g = main.screen
	# Game sounds go on their own, quieter bus so the song leads.
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "GameFx")
	AudioServer.set_bus_volume_db(bus, -9.0)
	for p in Sfx._players:
		p.bus = "GameFx"
	_song = AudioStreamPlayer.new()
	var mp3 := AudioStreamMP3.new()
	mp3.data = FileAccess.get_file_as_bytes(song_path)
	_song.stream = mp3
	add_child(_song)
	_bed = AudioStreamPlayer.new()
	_bed.stream = _news_bed(SONG_T + 0.2)
	_bed.volume_db = -4.0
	add_child(_bed)
	_bed.play()
	view.visible = false
	_dress_game()
	_run()


func _dress_game() -> void:
	if g == null:
		return
	for n in [g.bar, g.actions, g.hint_label, g.title_label, g.mode_button, g.momentum_ctl, g.debug_label, g.stack_view]:
		n.visible = false


func _song_t() -> float:
	return _t - SONG_T


func _process(_delta: float) -> void:
	_frame += 1
	_t = _frame / FPS
	if g == null and main and main.get("screen") is Game:
		g = main.screen
		_dress_game()
	var dt := 1.0 / FPS
	_shake = maxf(0.0, _shake - dt * 3.0)
	_flash = maxf(0.0, _flash - dt * 6.0)
	_split = maxf(0.0, _split - dt * 60.0)
	_invert = maxf(0.0, _invert - dt * 12.0)
	_mono = maxf(0.0, _mono - dt * 3.0)
	_blur = maxf(0.0, _blur - dt * 1.6)
	_punch = maxf(0.0, _punch - dt * 2.8)
	_tilt = lerpf(_tilt, _tilt_to, 0.35)
	if _fancam:
		_fancam_tick()
	_apply_view()
	if _end_van and _end_fire:
		var p := _end_van.position
		if _fire_last == Vector2.INF or p.distance_to(_fire_last) > 30.0:
			_fire_last = p
			_end_fire.emit(p)
	var fade := clampf((_song_t() - (SONG_END - 1.0)) / 1.0, 0.0, 1.0)
	_song.volume_db = -1.0 - 40.0 * fade * fade
	queue_redraw()


func _until(t: float) -> void:
	while _t < t:
		await get_tree().process_frame


func _at_song(st: float) -> void:
	await _until(SONG_T + st)


# ---------------------------------------------------------------- the timeline

func _run() -> void:
	# 1. Breaking news.
	for i in HEADLINES.size():
		await _until(NEWS_T0 + i * NEWS_EVERY)
		Sfx.play("whoosh", 0.8, 0.0)
		_shake = 0.35
	# 2. Record scratch. "NO GAME DARES???"
	await _until(DARES_T)
	_scene = "dares"
	_bed.stop()
	var scratch := AudioStreamPlayer.new()
	scratch.stream = _scratch()
	add_child(scratch)
	scratch.play()
	_shake = 0.8
	await _until(DARES_T + 0.45)
	_shake = 0.6
	Sfx.play("slam", 0.8, 2.0)
	await _until(DARES_T + 0.95)
	_shake = 0.9
	Sfx.play("slam", 0.7, 2.0)

	# 3. The song kicks in.
	await _until(SONG_T)
	_scene = "gauntlet"
	_song.play()
	_flash = 0.0
	_shake = 1.0
	await _at_song(BEAT0)
	_shake = 1.0
	await _at_song(1.90)
	_shake = 1.4

	# 4. Fancam.
	await _at_song(CUT_IN - 0.05)
	_scene = "fancam"
	view.visible = true
	_flash = 1.0
	_zoom = 2.3
	_punch = 0.6
	_tilt_to = -0.06
	_split = 22.0
	if g:
		_cam = _van_pos()
		g.drive_tiles(g.solve_info["shortest"])
	_fancam = true
	await _at_song(WIN_AT + 0.2)
	await _until_won()
	_fancam = false
	Engine.time_scale = 1.0
	await _at_song(9.08 - 0.32)
	_scene = "finish"
	# Snap out to the whole frame for the "DELIVERED!" slam.
	_zoom = 1.0
	_punch = 0.18
	_tilt_to = 0.0
	_cam = Vector2(540, 960)
	await _at_song(9.08)
	_flash = 0.8
	_split = 18.0
	await _at_song(10.11)
	_flash = 0.5
	_split = 14.0
	_punch = 0.12

	# 5. The challenge.
	await _at_song(CHALLENGE_AT)
	_scene = "challenge"
	view.visible = false
	_flash = 1.0
	_shake = 1.2
	for k in range(17, 22):
		await _at_song(BEAT0 + k * BEAT)
		_shake = 1.0
		_flash = 0.35

	# 6. The release.
	await _at_song(RELEASE_AT)
	_scene = "release"
	_flash = 1.0
	_shake = 0.8
	_start_release()
	for k in [23, 25, 26]:
		await _at_song(BEAT0 + k * BEAT)
		_shake = 0.8
		_flash = 0.3
	await _at_song(SONG_END)
	finished.emit()


func _until_won() -> void:
	var stop := _t + 6.0
	while g and g.state != Game.State.WON and _t < stop:
		await get_tree().process_frame


func _van_pos() -> Vector2:
	return g.board.get_global_transform_with_canvas() * g.van.position


## Follow cam, beat effects and speed ramps while the van drives.
func _fancam_tick() -> void:
	var st := _song_t()
	if g and is_instance_valid(g) and g.state == Game.State.DRIVING:
		_cam = _cam.lerp(_van_pos(), 0.2)
		# Speed: aim to finish the drive by WIN_AT, slowed for a moment right after each hit.
		var left_tiles := float(g.seg.size() - 1 - g._fired)
		var left_real := maxf(SONG_T + WIN_AT - _t, 0.15)
		var base := clampf((left_tiles / Game.DRIVE_SPEED + 0.15) / left_real, 0.2, 3.5)
		var since := st - _last_hit
		var ramp := 0.3 if since < 0.12 else lerpf(0.75, 1.35, clampf((since - 0.12) / 0.35, 0.0, 1.0))
		Engine.time_scale = base * ramp
	while _hit_i < FANCAM_HITS.size() and st >= FANCAM_HITS[_hit_i]:
		_hit(_hit_i)
		_hit_i += 1


func _hit(i: int) -> void:
	_last_hit = FANCAM_HITS[i]
	_punch = 0.75
	_split = 26.0
	_flash = 0.55
	_shake = 0.6
	_tilt_to = 0.08 if i % 2 == 0 else -0.08
	_blur = 0.12
	match i:
		1:
			_word("NO BRAKES")
		2:
			_heat(6)
		3:
			_mono = 1.0
		4:
			_word("NO FEAR")
			_invert = 1.0
		5:
			_heat(9)
		6:
			_word("NO DELAYS")
			_blur = 0.25


func _word(text: String) -> void:
	_words.append({"text": text, "t0": _t, "rot": -0.12 if _words.size() % 2 == 0 else 0.1})


## Hotter fire: blue, then violet.
func _heat(m: int) -> void:
	if g == null:
		return
	g.board.fire.momentum = m
	g.board.wreck.momentum = m
	Progress.momentum = m - 1
	Sfx.play("whoomp", 1.0, 2.0)


func _apply_view() -> void:
	if view == null:
		return
	var z := _zoom * (1.0 + _punch * 0.35)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * _shake
	var rot := _tilt
	view.scale = Vector2.ONE * z
	view.rotation = rot
	view.position = Vector2(540, 960) + off - ((_cam - Vector2(540, 960)) * z).rotated(rot)
	var m: ShaderMaterial = view.material
	m.set_shader_parameter("split", _split)
	m.set_shader_parameter("flash", _flash if _scene in ["fancam", "finish"] else 0.0)
	m.set_shader_parameter("invert", 1.0 if _invert > 0.5 else 0.0)
	m.set_shader_parameter("sat", lerpf(1.25, 0.0, _mono))
	m.set_shader_parameter("contrast", 1.12 + 0.3 * _mono)
	m.set_shader_parameter("blur", _blur)
	m.set_shader_parameter("vignette", 0.55 if _scene == "fancam" else 0.2)


func _start_release() -> void:
	_end_fire = AnimeFire.new()
	_end_fire.tile = 200.0
	_end_fire.momentum = 9
	add_child(_end_fire)
	_end_van = Van.new()
	_end_van.follow_progress = false
	_end_van.size = 320.0
	_end_van.position = Vector2(-320, 1250)
	add_child(_end_van)
	_end_van.set_top("red")
	var tw := _end_van.create_tween()
	tw.tween_property(_end_van, "position:x", 540.0, 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_end_van.stop_bounce)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 26.0 * _shake
	match _scene:
		"news":
			_draw_news(off)
		"dares":
			_draw_dares(off)
		"gauntlet":
			_draw_gauntlet(off)
		"fancam":
			_draw_fancam_words()
		"challenge":
			_draw_challenge(off)
		"release":
			_draw_release(off)
	if _flash > 0.0 and not (_scene in ["fancam", "finish"]):
		draw_rect(Rect2(0, 0, 1080, 1920), Color(1, 1, 1, _flash * 0.85))


func _draw_news(off: Vector2) -> void:
	# Studio background: deep blue gradient, sweeping light beams, a dotted globe grid.
	for i in 24:
		var y := i * 80.0
		draw_rect(Rect2(0, y, 1080, 81), NAVY.lerp(Color("1b2f63"), sin(PI * i / 23.0) * 0.8))
	for k in 3:
		var x := fmod(_t * 220.0 + k * 520.0, 1700.0) - 300.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 140, 0), Vector2(x - 260, 1920), Vector2(x - 400, 1920)]), Color(1, 1, 1, 0.04))
	for gx in 14:
		for gy in 22:
			var p := Vector2(60 + gx * 74, 140 + gy * 78)
			var d := p.distance_to(Vector2(540, 900))
			if d < 620.0:
				draw_circle(p, 3.5, Color(0.5, 0.75, 1.0, 0.18 * (1.0 - d / 620.0)))
	# BREAKING NEWS bar.
	var bar := Rect2(0, 150, 1080, 150)
	draw_rect(bar, NEWS_RED)
	draw_rect(Rect2(0, 300, 1080, 10), Color(0, 0, 0, 0.3))
	_text("BREAKING NEWS", Vector2(60, 252) + off * 0.3, 92, Color.WHITE)
	if int(_t * 2.0) % 2 == 0:
		draw_circle(Vector2(905, 225), 18, Color.WHITE)
	_text("LIVE", Vector2(935, 244), 52, Color.WHITE)
	# The headlines pile up, newest on top.
	var shown := 0
	for i in HEADLINES.size():
		if _t >= NEWS_T0 + i * NEWS_EVERY:
			shown = i + 1
	for i in shown:
		var age := _t - (NEWS_T0 + i * NEWS_EVERY)
		var depth := shown - 1 - i
		var slide := _out(age / 0.28)
		var x := lerpf(1500.0, 540.0, slide) + (8.0 if i % 2 == 0 else -8.0) * depth
		var y := 830.0 - depth * 46.0
		var sc := (1.0 - depth * 0.05) * (1.0 + 0.02 * minf(age, 1.5))
		var rot := (-0.035 if i % 2 == 0 else 0.03) * (1.0 + depth * 0.3)
		_headline_card(Vector2(x, y) + off * (1.0 if depth == 0 else 0.3), sc, rot, HEADLINES[i][0], HEADLINES[i][1], depth)
	# The ticker.
	var ty := 1640.0
	draw_rect(Rect2(0, ty, 1080, 110), Color("0a0f1f"))
	draw_rect(Rect2(0, ty, 230, 110), YELLOW)
	_text("GTA VI", Vector2(34, ty + 74), 56, INK)
	var tick := "NOVEMBER 19, 2026   •   PUBLISHERS DUCK FOR COVER   •   RELEASE DATES PUSHED   •   NOBODY WANTS THAT SMOKE   •   "
	var tw := _font.get_string_size(tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
	var tx := 250.0 - fmod(_t * 330.0, tw)
	for r in 3:
		draw_string(_font, Vector2(tx + r * tw, ty + 72), tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
	draw_rect(Rect2(0, ty, 230, 110), YELLOW)
	_text("GTA VI", Vector2(34, ty + 74), 56, INK)


func _headline_card(c: Vector2, sc: float, rot: float, outlet: String, line: String, depth: int) -> void:
	draw_set_transform(c, rot, Vector2.ONE * sc)
	var w := 940.0
	var lines := _wrap(line, 62, w - 100.0)
	var h := 150.0 + lines.size() * 74.0
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 18), r.size), Color(0, 0, 0, 0.35), 28)
	DrawUtil.rrect(self, r, Color.WHITE, 28)
	draw_rect(Rect2(r.position.x, r.position.y + 28, 14, h - 56), NEWS_RED)
	_text(outlet, r.position + Vector2(52, 78), 40, NEWS_RED)
	for i in lines.size():
		draw_string(_font, r.position + Vector2(52, 150 + i * 74), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 62, Color("141414"))
	if depth > 0:
		DrawUtil.rrect(self, r, Color(0, 0, 0, minf(0.18 * depth, 0.6)), 28)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dares(off: Vector2) -> void:
	draw_rect(Rect2(0, 0, 1080, 1920), Color.BLACK)
	var t := _t - DARES_T
	var push := 1.0 + 0.06 * t
	if t >= 0.45:
		_outlined("NO GAME", Vector2(540, 820) + off, 190, Color.WHITE, INK, 0, -0.04, _pop((t - 0.45) / 0.22) * push)
	if t >= 0.95:
		_outlined("DARES???", Vector2(540, 1050) + off, 210, RED, INK, 0, -0.04, _pop((t - 0.95) / 0.22) * push)


func _draw_gauntlet(off: Vector2) -> void:
	var st := _song_t()
	draw_rect(Rect2(0, 0, 1080, 1920), Color("120712"))
	# A wall of fire rising from the bottom, hotter on each hit.
	var m := 3 if st < BEAT0 else (6 if st < 1.9 else 9)
	for i in 9:
		var x := 60.0 + i * 120.0
		AnimeFire.draw_flame(self, Vector2(x, 1990), 230, 520 + 120 * sin(_t * 3.0 + i) + 60.0 * m, _t, i * 1.7, AnimeFire.palette(m))
	_outlined("LAST MILE", Vector2(540, 560) + off, 200, Palette.ACCENT, INK, 34, -0.07, _pop(st / 0.2))
	if st >= BEAT0:
		_outlined("DOESN'T GIVE A", Vector2(540, 800) + off, 130, Color.WHITE, INK, 28, -0.07, _pop((st - BEAT0) / 0.2))
	if st >= 1.90:
		var k := _pop((st - 1.90) / 0.18) * (1.0 + 0.05 * sin(_t * 40.0))
		_outlined("&@$*&!!!!", Vector2(540, 1070) + off * 1.6, 230, RED, Color.WHITE, 30, -0.07, k)


func _draw_fancam_words() -> void:
	for wd in _words:
		var age: float = _t - wd["t0"]
		if age > 0.55:
			continue
		var k := _pop(age / 0.12)
		var a := clampf((0.55 - age) / 0.15, 0.0, 1.0)
		_outlined(wd["text"], Vector2(540, 1500), 170, YELLOW, INK, 30, wd["rot"], k, a)


func _draw_challenge(off: Vector2) -> void:
	var st := _song_t()
	draw_rect(Rect2(0, 0, 1080, 1920), Color("0a0508"))
	for i in 5:
		var y := fmod(i * 420.0 + _t * 260.0, 2300.0) - 300.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(1080, y - 260), Vector2(1080, y - 200), Vector2(0, y + 60)]), Color(RED, 0.16))
	var lines := [["ROCKSTAR.", RED, 200], ["DELAY GTA VI", Color.WHITE, 136], ["OR BE WRECKED", YELLOW, 130],
		["BY THE BEST GAME", Color.WHITE, 112], ["ON FOUR WHEELS.", Palette.ACCENT, 122]]
	var ys := [420, 700, 910, 1110, 1300]
	for i in lines.size():
		var t0 := CHALLENGE_AT if i == 0 else BEAT0 + (16 + i) * BEAT
		if st < t0:
			continue
		var l: Array = lines[i]
		_outlined(l[0], Vector2(540, ys[i]) + off * (1.0 if i == 0 else 0.6), l[2], l[1], Color.WHITE if i == 0 else INK, 26, -0.06, _pop((st - t0) / 0.18))
	# The van tears across the bottom on supernova fire.
	var vx := fmod((st - CHALLENGE_AT) * 900.0, 1700.0) - 300.0
	for i in 8:
		AnimeFire.draw_flame(self, Vector2(vx - 90 - i * 80, 1650), 120, 220 - i * 18, _t, i * 2.1, AnimeFire.palette(9))
	_mini_van(Vector2(vx, 1640))


func _draw_release(off: Vector2) -> void:
	var st := _song_t()
	for i in 24:
		var y := i * 80.0
		draw_rect(Rect2(0, y, 1080, 81), Color("2a0f4a").lerp(Color("ff5a2c"), pow(i / 23.0, 1.6)))
	for i in 16:
		var a0 := _t * 0.4 + TAU * i / 16.0
		var a1 := a0 + TAU / 32.0
		var c := Vector2(540, 1250)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 2400.0, c + Vector2(cos(a1), sin(a1)) * 2400.0]), Color(1, 1, 1, 0.05))
	_titled("Last Mile", Vector2(540, 300) + off * 0.4, 170, Color.WHITE, _pop((st - RELEASE_AT) / 0.25))
	var d0 := RELEASE_AT
	_outlined("DROPPING", Vector2(540, 540) + off, 120, Color.WHITE, INK, 24, -0.05, _pop((st - d0) / 0.2))
	var d1 := BEAT0 + 23 * BEAT
	if st >= d1:
		_outlined("NOVEMBER 19, 2026.", Vector2(540, 720) + off, 116, YELLOW, INK, 26, -0.05, _pop((st - d1) / 0.2))
	var d2 := BEAT0 + 25 * BEAT
	if st >= d2:
		_outlined("IT'S THE ONLY GAME", Vector2(540, 900) + off * 0.5, 84, Color.WHITE, INK, 20, -0.05, _pop((st - d2) / 0.2))
	var d3 := BEAT0 + 26 * BEAT
	if st >= d3:
		_outlined("YOU'RE GONNA BE HEARING ABOUT", Vector2(540, 1010) + off * 0.5, 66, Color.WHITE, INK, 18, -0.05, _pop((st - d3) / 0.2))
	# Road strip under the van, which arrives on fire.
	draw_rect(Rect2(0, 1180, 1080, 140), Color("596273"))
	draw_rect(Rect2(0, 1180, 1080, 10), Color("444b59"))
	for i in 9:
		draw_rect(Rect2(i * 140 + 20, 1245, 70, 10), Color(1, 1, 1, 0.5))
	if _end_van:
		AnimeFire.draw_aura(self, _end_van.position, Vector2(330, 200), _t, 9, true)
	_center("a Door Bowl game", Vector2(540, 1760), 44, Color(1, 1, 1, 0.8))


## A tiny top-down van for the challenge card's drive-by.
func _mini_van(c: Vector2) -> void:
	var L := 230.0
	var W := 140.0
	DrawUtil.rrect(self, Rect2(c - Vector2(L, W) / 2.0, Vector2(L, W)), Palette.VAN_BODY, W * 0.28)
	DrawUtil.rrect(self, Rect2(c + Vector2(L / 2.0 - L * 0.3, -W / 2.0), Vector2(L * 0.3, W)), Palette.VAN_CAB, W * 0.28)
	DrawUtil.package(self, c + Vector2(-L * 0.13, 0), W * 0.62, Palette.pkg("red"), false)


# ---------------------------------------------------------------- text and sound

func _fredoka() -> Font:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Fredoka.ttf")
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	return f


func _text(text: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _center(text: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _wrap(text: String, px: int, width: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


func _titled(text: String, at: Vector2, px: int, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	draw_set_transform(at, 0.0, Vector2.ONE * k)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, Vector2(-w / 2.0, px * 0.35 + 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.25))
	draw_string(_font, Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Thick-outlined, slanted, scaled about its centre (shrunk to fit the width).
func _outlined(text: String, at: Vector2, px: int, fill: Color, outline: Color, ow: int, rot: float, k: float, alpha := 1.0) -> void:
	if k <= 0.01 or alpha <= 0.0:
		return
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var fit := minf(1.0, 1000.0 / maxf(w, 1.0))
	draw_set_transform(at, rot, Vector2.ONE * k * fit)
	var p := Vector2(-w / 2.0, px * 0.35)
	if ow > 0:
		draw_string_outline(_font, p + Vector2(0, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow, Color(0, 0, 0, 0.35 * alpha))
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ow, Color(outline, alpha))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(fill, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


func _out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


const RATE := 22050


static func _wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w


## Urgent newsroom bed: a low drone, a ticking clock pulse, and a brassy stab on each headline.
static func _news_bed(seconds: float) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * 55.0 / RATE
		var drone := (sin(ph) + 0.5 * sin(ph * 1.5) + 0.3 * sin(ph * 2.0)) * 0.12
		var beat := fmod(t, 0.25)
		var tick := sin(TAU * 1800.0 * beat) * exp(-beat * 90.0) * (0.12 if int(t * 4.0) % 4 == 0 else 0.06)
		b[i] = drone * minf(1.0, t * 3.0) + tick
	for k in HEADLINES.size():
		var t0: float = NEWS_T0 + k * NEWS_EVERY
		for n in [43, 50, 55, 59]:
			var f := 440.0 * pow(2.0, (n - 69.0) / 12.0)
			var s0 := int(t0 * RATE)
			for i in int(0.7 * RATE):
				if s0 + i >= b.size():
					break
				var t := float(i) / RATE
				var env := minf(1.0, t * 200.0) * exp(-t * 4.0)
				var saw := 2.0 * fmod(f * t, 1.0) - 1.0
				b[s0 + i] += (saw * 0.5 + sin(TAU * f * t)) * env * 0.07
	for i in b.size():
		b[i] = tanh(b[i] * 1.3)
	return _wav(b)


## A record scratch.
static func _scratch() -> AudioStreamWAV:
	var b := PackedFloat32Array()
	b.resize(int(0.42 * RATE))
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 300.0 + 1500.0 * absf(sin(t * 18.0))
		ph += TAU * f / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		b[i] = (sin(ph) * 0.4 + lp * 0.5) * minf(1.0, (0.42 - t) * 10.0) * 0.8
	return _wav(b)
