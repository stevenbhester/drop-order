class_name BaronAd
extends CanvasLayer
## A pretend ad from Hoardly Inc., the Baron's company, in the rotation with the others (FakeAd, PromoAd):
## a calm corporate spot that says the quiet part out loud. The thirteen spots are the ones reviewed in
## "Last Mile: ads, offers and residents to review" (design/todo.md links it). House rules: about ten
## seconds, calm captions over simple scenes, a tap on the ad lights up Skip (it doesn't skip: Steven, 15 Nov),
## an option turns them off ("Hoardly ads",
## Progress.hoardly_ads), Hoardly is never evil for its own sake (it's always after the next penny), and no
## spot names a game mechanic.
##
## Each: a one-word title card on deep blue ("Choice."), two or three beats of simple scenes drawn in code
## with a slow "stock footage" drift and a sincere caption each, then the logo card (the gold H with its
## monocle, the tagline, the fine print) over soft piano (audio/corp_bed.wav). A parody: nobody is paid and
## nothing is tracked. Skipping, closing or finishing all emit `finished`, and the caller hands over the
## reward. At the end, "Acknowledge": it closes, and you're straight back to what you were doing.
##
## One at random, never the same twice running. `-- --baron-ad=<spot>` plays one over whatever's showing.

signal finished

const SKIP_AFTER := 1.0
const TITLE := 1.2                # the title card
const BEATS := 6.4                # the scenes, shared between the spot's beats
const LOGO_AT := TITLE + BEATS
const END_AT := LOGO_AT + 2.8
const NAVY := Color("0f1b33")
const GOLD := Color("ffc53d")
const CREAM := Color(0.99, 0.97, 0.92)
const INK := Color("2a2233")
const RED := Color("d7192a")
const GREY_VAN := Color("8d8f99")
const GREY_CAB := Color("4a4c57")
## Each spot: its title card, its beats ([scene, caption]), its tagline, and its colours [sky top, sky
## bottom, ground].
const SPOTS := {
	"choice": {"title": "Choice.", "look": ["ffe2cf", "fff6e6", "d8d2c4"],
		"beats": [["pumps", "At Hoardly, we believe in choice."], ["pumps_owned", "That's why we own both."]],
		"tag": "Hoardly Gas. It's the only gas. We checked."},
	"roads": {"title": "Roads.", "look": ["cfe8ff", "fff1dc", "cfe7c4"],
		"beats": [["connect", "Roads connect us."], ["connect_value", "Connection is valuable."], ["connect_toll", "And value should be captured."]],
		"tag": "Hoardly Infrastructure. Bringing people together. $4.99 each way."},
	"family": {"title": "Family.", "look": ["fde3ec", "fff6ef", "e3dccc"],
		"beats": [["vans_row", "Hoardly drivers are family."], ["vans_unpaid", "And like family, they don't get paid."], ["robot", ""]],
		"tag": "Hoardly. Family. Restructured."},
	"premium": {"title": "Premium.", "look": ["e6e0ff", "fbf8ff", "ddd8ea"],
		"beats": [["product", "Introducing Hoardly Prime Plus Max."], ["product_list", "Everything in Prime Plus. Minus some things."], ["toll_drop", "Now with tolls."]],
		"tag": "More is less. For more."},
	"gps": {"title": "GPS.", "look": ["d6ecff", "f3f7ff", "c9dcc2"],
		"beats": [["gps", "Hoardly GPS always knows the way."], ["gps_ads", "It will tell you. For a price."]],
		"tag": "Hoardly GPS. You are here. Somewhere under the ads."},
	"offer": {"title": "The Offer.", "look": ["cfe8ff", "fff1dc", "cfe7c4"],
		"beats": [["courier", "Some packages are still delivered by small, independent couriers."], ["monocle", "We find that... sweet."]],
		"tag": ""},
	"air": {"title": "Air.", "look": ["d6f0ff", "f6fbff", "d4d4dc"],
		"beats": [["air_pump", "Air. It's everywhere. It's free."], ["air_coin", "We noticed."]],
		"tag": "Hoardly Air. Breathe easy. Tyres extra."},
	"rewards": {"title": "Rewards.", "look": ["fff0c9", "fffaf0", "e8dcc0"],
		"beats": [["points", "Hoardly Rewards. Earn a point with every ten deliveries."], ["points_more", "Points can be redeemed for more points."]],
		"tag": "Hoardly Rewards. You've earned it. Almost."},
	"convenience": {"title": "Convenience.", "look": ["e2f4e8", "fbfffc", "d5e2d8"],
		"beats": [["receipt", "Paying should be easy. So we added a convenience fee."], ["receipt_long", "And a fee for the convenience fee. For your convenience."]],
		"tag": "Hoardly Pay. It adds up."},
	"returns": {"title": "Returns.", "look": ["ffe8d6", "fff8f0", "e2d6c6"],
		"beats": [["send_back", "Not happy? Send it back, free."], ["refund", "Refunds ship separately. Shipping not included."]],
		"tag": "Hoardly Returns. What goes around, bills around."},
	"sunshine": {"title": "Sunshine.", "look": ["ffd9b0", "fff3d6", "cfe7c4"],
		"beats": [["sunrise", "The sun rises on every home, free of charge."], ["billboard", "We're looking into it."]],
		"tag": "Hoardly Outdoor. Brighter days. Premium tier."},
	"careers": {"title": "Careers.", "look": ["dff1ff", "f8fcff", "d6dde6"],
		"beats": [["ladder", "Hoardly is hiring. Unlimited growth potential."], ["ladder_sold", "For us."]],
		"tag": "Hoardly Careers. Aim higher. We did."},
	"terms": {"title": "Terms.", "look": ["f2f2f2", "ffffff", "f2f2f2"],
		"beats": [["small_print", "By watching this, you agree."]],
		"tag": "Hoardly Legal. Too late."},
}
## "The Offer" gets more desperate as his bosses fall (one line per stage: none beaten, then 1-2, 3-5, 6+).
const OFFER_TAGS := ["Hoardly. We've made an offer.", "Hoardly. We've made a better offer.", "Hoardly. Please take the offer.",
	"Hoardly. We are open to offers."]
const FINE := "Hoardly Inc. is not responsible for anything, ever. Offer subject to change, mostly upward. Void where people are nice. Baron sold separately."
const LEGALESE := ["The undersigned (you) hereby", "assigns to Hoardly Inc. all", "rights, title and interest in",
	"any package, parcel, porch or", "nearby porch, in perpetuity and", "throughout the known universe,", "including Tuesdays. Fees apply",
	"to fees. Disputes shall be heard", "by the Baron, personally, on his", "yacht, at a time of his choosing.", "Silence constitutes agreement.",
	"So does speaking. Blinking twice", "is binding. See page 4,012."]

static var _last := ""

## Debug (--baron-ad=<spot>): this spot; else one at random.
var spot := ""

var _root: Control
var _skip: JuicyButton
var _cta: JuicyButton
var _t := 0.0
var _closing := false
var _toast_at := -1.0
var _top := 0.0
var _sting := false
var _bed: AudioStreamPlayer
var _xf := Transform2D.IDENTITY     # the footage's camera this frame (stage -> screen)


## Does a Hoardly ad come up this time (instead of the usual one)? About a third of the time, unless the
## option's off; never under the self-tests unless they ask (--baron-ad).
static func due() -> bool:
	if Progress.auto:
		return Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--baron-ad"))
	return Progress.hoardly_ads and randf() < 0.34


func _ready() -> void:
	layer = 80
	if not SPOTS.has(spot):
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--baron-ad="):
				spot = a.trim_prefix("--baron-ad=")
	if not SPOTS.has(spot):
		var pool := SPOTS.keys().filter(func(k: String) -> bool: return k != _last)
		spot = pool[randi() % pool.size()]
	_last = spot
	_top = UiTheme.insets(get_viewport()).x
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_ad)
	# A tap on the ad points at Skip (it doesn't skip).
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_root.accept_event()
			FakeAd.nudge(_skip))
	add_child(_root)

	_skip = JuicyButton.new()
	_skip.font_px = 46
	_skip.bg = Color(1, 1, 1, 0.16)
	_skip.dim_bg = Color(1, 1, 1, 0.07)
	_skip.fg = CREAM
	_skip.custom_minimum_size = Vector2(320, 128)
	_skip.size = Vector2(320, 128)
	_skip.pressed.connect(_on_skip)
	_root.add_child(_skip)

	_cta = JuicyButton.new()
	_cta.font_px = 60
	_cta.bg = GOLD
	_cta.fg = NAVY
	_cta.label = "Acknowledge"
	_cta.size = Vector2(640, 160)
	_cta.visible = false
	_cta.pressed.connect(_on_cta)
	_root.add_child(_cta)

	_bed = AudioStreamPlayer.new()
	_bed.stream = load("res://audio/corp_bed.wav") if ResourceLoader.exists("res://audio/corp_bed.wav") else SfxSynth.make("corp_bed")
	_bed.volume_db = -6.0            # (the options' volume is on the master bus)
	add_child(_bed)
	_bed.play()

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var size := _root.get_viewport_rect().size
	var bottom := UiTheme.insets(get_viewport()).y
	_skip.position = Vector2(36.0 if Progress.left_hand else size.x - _skip.size.x - 36.0, size.y - bottom - _skip.size.y - 56.0)
	_cta.position = Vector2((size.x - _cta.size.x) / 2.0, size.y * 0.66)
	_cta.pivot_offset = _cta.size / 2.0


func _process(delta: float) -> void:
	if _closing:
		return
	_t += minf(delta, 0.1)
	if not _sting and _t >= LOGO_AT:
		_sting = true
		Sfx.play("corp_sting", 1.0, -4.0)
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
		if not _cta.visible and _toast_at < 0.0:
			_cta.visible = true
			_cta.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_property(_cta, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_cta.breathe.bind(true))
	if _toast_at >= 0.0 and _t - _toast_at > 2.4:
		_close()
	_root.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
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


## "Acknowledge": the ad closes at once (the reward still comes), straight back to playing.
func _on_cta() -> void:
	Sfx.play("kaching", 0.8, -6.0)
	_cta.breathe(false)
	_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	finished.emit()
	var tw := create_tween()
	tw.tween_property(_bed, "volume_db", -40.0, 0.2)
	tw.parallel().tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## This spot's tagline ("The Offer"'s depends on how many of his bosses have fallen).
func _tag() -> String:
	if spot != "offer":
		return str(SPOTS[spot]["tag"])
	var beaten := 0
	for n in Boss.LOOT:
		if Progress.is_complete(int(n)):
			beaten += 1
	return OFFER_TAGS[0 if beaten == 0 else (1 if beaten <= 2 else (2 if beaten <= 5 else 3))]


# ---------------------------------------------------------------- drawing

func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


func _text(text: String, at: Vector2, px: int, col: Color, shadow := Color(0, 0, 0, 0.0)) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if shadow.a > 0.0:
		_root.draw_string(f, at + Vector2(-w / 2.0 + 3, px * 0.35 + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, shadow)
	_root.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## `text` wrapped to `w` and centred on `at`.
func _lines(text: String, at: Vector2, px: int, w: float, col: Color, shadow := Color(0, 0, 0, 0.0)) -> void:
	var lines := BossIntro.wrap_text(text, px, w)
	var gap := px * 1.25
	for i in lines.size():
		_text(str(lines[i]), at + Vector2(0, (i - (lines.size() - 1) / 2.0) * gap), px, col, shadow)


func _draw_ad() -> void:
	var v := _root.size
	if _t < TITLE:
		_draw_title(v)
	elif _t < LOGO_AT:
		var beats: Array = SPOTS[spot]["beats"]
		var each := BEATS / beats.size()
		var i := clampi(int((_t - TITLE) / each), 0, beats.size() - 1)
		_draw_beat(v, i, _t - TITLE - i * each, each)
	else:
		_draw_logo(v)
	# Letterbox bars: it's a commercial.
	var bar := 90.0 + _top
	_root.draw_rect(Rect2(0, 0, v.x, bar), Color.BLACK)
	_root.draw_rect(Rect2(0, v.y - bar - 40.0, v.x, bar + 40.0), Color.BLACK)
	_text("AD", Vector2(70, bar - 36), 26, Color(1, 1, 1, 0.5))
	if _toast_at >= 0.0:
		var a := clampf((_t - _toast_at) * 4.0, 0.0, 1.0)
		DrawUtil.rrect(_root, Rect2(v.x / 2.0 - 400, v.y * 0.66, 800, 160), Color(1, 1, 1, a), 40)
		_text("You already did.", Vector2(v.x / 2.0, v.y * 0.66 + 56), 50, Color(NAVY, a))
		_text("(Page 4,012. Paragraph \"Everything.\")", Vector2(v.x / 2.0, v.y * 0.66 + 112), 30, Color(INK, 0.7 * a))


## The title card: the spot's word, calm and serious, on deep blue.
func _draw_title(v: Vector2) -> void:
	_root.draw_rect(Rect2(Vector2.ZERO, v), NAVY)
	var k := _ease(_t / 0.5)
	var a := k * (1.0 - _ease((_t - (TITLE - 0.25)) / 0.25))
	var c := Vector2(v.x / 2.0, v.y * 0.46)
	_root.draw_line(c + Vector2(-180.0 * k, 90), c + Vector2(180.0 * k, 90), Color(GOLD, a), 4.0)
	_text(str(SPOTS[spot]["title"]), c + Vector2(0, -8.0 * (1.0 - k)), 120, Color(1, 1, 1, a))
	_text("A message from Hoardly Inc.", c + Vector2(0, 150), 36, Color(1, 1, 1, 0.6 * a))


## One beat: its scene drifting slowly (stock footage), its caption in the lower third, and a dip to the
## sky's colour between beats.
func _draw_beat(v: Vector2, i: int, local: float, each: float) -> void:
	var look: Array = SPOTS[spot]["look"]
	var top := Color(look[0])
	var low := Color(look[1])
	var k := local / each
	_root.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), v, Vector2(0, v.y)]), PackedColorArray([top, top, low, low]))
	var stage := Vector2(v.x / 2.0, v.y * 0.45)
	var drift := Vector2((k - 0.5) * 40.0 * (1.0 if i % 2 == 0 else -1.0), 0)
	var zoom := (v.x / 1080.0) * 1.15 * (1.0 + 0.06 * (_t - TITLE) / BEATS)
	_xf = Transform2D(0.0, Vector2.ONE * zoom, 0.0, stage + drift)
	_root.draw_set_transform_matrix(_xf)
	_root.draw_rect(Rect2(-v.x, 180, v.x * 2.0, v.y), Color(look[2]))
	_root.draw_rect(Rect2(-v.x, 180, v.x * 2.0, 10), Color(look[2]).darkened(0.08))
	var beat: Array = SPOTS[spot]["beats"][i]
	_scene(str(beat[0]), k, local)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var caption := str(beat[1])
	if caption != "":
		var ca := clampf((local - 0.15) / 0.25, 0.0, 1.0) * clampf((each - local) / 0.2, 0.0, 1.0)
		_root.draw_rect(Rect2(0, v.y * 0.7, v.x, 200), Color(0, 0, 0, 0.28 * ca))
		_lines(caption, Vector2(v.x / 2.0, v.y * 0.7 + 100), 50, v.x - 140.0, Color(1, 1, 1, ca), Color(0, 0, 0, 0.35 * ca))
	var dip := 1.0 - clampf(minf(local, each - local) / 0.15, 0.0, 1.0)
	if dip > 0.0:
		_root.draw_rect(Rect2(Vector2.ZERO, v), Color(low, dip))


## The logo card: the gold H with its monocle, the tagline, the company line, and the fine print.
func _draw_logo(v: Vector2) -> void:
	var u := _t - LOGO_AT
	_root.draw_rect(Rect2(Vector2.ZERO, v), NAVY)
	var k := _ease(u / 0.4)
	var c := Vector2(v.x / 2.0, v.y * 0.3)
	var r := 110.0 * (0.8 + 0.2 * k)
	_root.draw_circle(c, r + 10.0, Color(GOLD, 0.25 * k))
	_root.draw_circle(c, r, Color(GOLD, k))
	_root.draw_arc(c, r - 14.0, 0, TAU, 48, Color(NAVY, 0.35 * k), 4.0, true)
	_text("H", c + Vector2(0, -6), 150, Color(NAVY, k))
	# A monocle on the H. He is a Baron.
	_root.draw_arc(c + Vector2(38, -40), 22.0, 0, TAU, 24, Color(NAVY, k), 5.0, true)
	_root.draw_line(c + Vector2(58, -30), c + Vector2(74, 30), Color(NAVY, k), 3.0)
	_text("HOARDLY INC.", c + Vector2(0, r + 90), 80, Color(1, 1, 1, k))
	_lines(_tag(), c + Vector2(0, r + 210), 50, v.x - 160.0, Color(GOLD, _ease((u - 0.4) / 0.4)))
	_text("We deliver. To shareholders.", c + Vector2(0, r + 320), 36, Color(1, 1, 1, 0.65 * _ease((u - 0.8) / 0.4)))
	_lines(FINE, Vector2(v.x / 2.0, v.y * 0.8), 24, v.x - 200.0, Color(1, 1, 1, 0.45 * _ease((u - 1.0) / 0.3)))


# ---------------------------------------------------------------- the footage
# Drawn round the stage's centre, the ground at y = 180, about ±420 across. `k` runs 0..1 through the beat.

func _scene(name: String, k: float, local: float) -> void:
	var ci := _root
	match name:
		"pumps", "pumps_owned":
			# Two pumps from two brands. Then the same gold H goes on both.
			var owned := name == "pumps_owned"
			var cols := [Color("e8574a"), Color("3d8fd6")]
			var brands := ["FUELCO", "GASSY"]
			for j in 2:
				var x := -200.0 + j * 400.0
				var s := _pop(k * 3.0 - j * 0.4) if not owned else 1.0
				_pump(Vector2(x, 180), 300.0 * s, cols[j], brands[j])
				if owned:
					var sk := _pop(k * 3.0 - j * 0.5)
					if sk > 0.0:
						ci.draw_circle(Vector2(x, -150), 62.0 * sk, GOLD)
						_text_at(Vector2(x, -154), "H", int(80 * sk), NAVY)
		"connect", "connect_value", "connect_toll":
			_house(Vector2(-330, 180), 220.0, Color("ffd6c9"), Color("e8746a"))
			_house(Vector2(330, 180), 220.0, Color("cfe4ff"), Color("6aa8e8"))
			var grow := _ease(k * 1.5) if name == "connect" else 1.0
			_root.draw_rect(Rect2(-230, 200, 460.0 * grow, 90), Color("55545e"))
			var x := -220.0
			while x < -230.0 + 460.0 * grow - 50.0:
				_root.draw_rect(Rect2(x, 240, 40, 8), Color(1, 1, 1, 0.8))
				x += 80.0
			var tolled := name == "connect_toll"
			_person(Vector2(-200, 330), Color("e8746a"), not tolled, local)
			_person(Vector2(200, 330), Color("3d8fd6"), not tolled, local + 1.0)
			if name == "connect_value":
				for j in 6:
					var sk := fmod(local * 0.9 + j / 6.0, 1.0)
					Icons.star(ci, Vector2(-200 + j * 80, 180 - sk * 120), 16.0 * (1.0 - sk), Color(GOLD, 1.0 - sk))
			if tolled:
				_barrier(Vector2(110, 300), 1.0 - _ease(k * 2.5))
				_sign(Vector2(0, -40), "TOLL $4.99", GOLD, NAVY, 44)
		"vans_row", "vans_unpaid":
			for j in 4:
				var p := Vector2(-330 + j * 220, 120 + (j % 2) * 120)
				_van(p, 190.0, true)
				# A driver in each cab.
				ci.draw_circle(p + Vector2(55, -18), 14.0, Color("f2c9a0"))
				if name == "vans_unpaid":
					var tk := _pop(k * 3.0 - j * 0.3)
					if tk > 0.0:
						_sign(p + Vector2(0, -110), "$0.00", Color.WHITE, RED, int(30 * tk) + 1)
		"robot":
			var merge := _ease(k / 0.35)
			if merge < 1.0:
				for j in 4:
					var from := Vector2(-330 + j * 220, 120 + (j % 2) * 120)
					_van(from.lerp(Vector2(0, 160), merge), 190.0 * (1.0 - 0.5 * merge), true)
			else:
				_robot(Vector2(0, 180), 380.0 * _pop((k - 0.35) / 0.2), local)
			if k > 0.6:
				var nk := _pop((k - 0.6) / 0.15)
				DrawUtil.rrect(ci, Rect2(Vector2(-270, -330) * nk, Vector2(540, 150) * nk), Color.WHITE, 12)
				_text_at(Vector2(0, -290) * nk, "NOTICE", int(30 * nk) + 1, RED)
				_text_at(Vector2(0, -230) * nk, "Position eliminated.", int(38 * nk) + 1, INK)
		"product":
			var s := _pop(k * 2.0)
			DrawUtil.rrect(ci, Rect2(Vector2(-260, -230) * s, Vector2(520, 340) * s), Color("16121f"), 30)
			DrawUtil.rrect(ci, Rect2(Vector2(-244, -214) * s, Vector2(488, 308) * s), Color("2a2140"), 24)
			_text_at(Vector2(0, -150) * s, "HOARDLY", int(44 * s) + 1, GOLD)
			_text_at(Vector2(0, -70) * s, "PRIME PLUS", int(60 * s) + 1, Color.WHITE)
			_text_at(Vector2(0, 10) * s, "MAX", int(80 * s) + 1, GOLD)
			for j in 5:
				var sk := fmod(local * 0.8 + j * 0.2, 1.0)
				Icons.star(ci, Vector2(-300 + j * 150, -260 + sin(j * 2.0) * 40), 20.0 * sin(PI * sk), Color(GOLD, 0.9))
		"product_list":
			DrawUtil.rrect(ci, Rect2(-300, -300, 600, 460), Color.WHITE, 24)
			_text_at(Vector2(0, -250), "WHAT'S INCLUDED", 34, Color(INK, 0.6))
			var items := ["Fast shipping", "Free returns", "Customer support", "The box", "Feelings"]
			for j in items.size():
				var y := -170.0 + j * 72.0
				_root.draw_string(UiTheme.font(), Vector2(-220, y + 14), str(items[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, INK)
				var cut := _ease(k * 3.0 - 0.3 - j * 0.35)
				if cut > 0.0:
					_root.draw_line(Vector2(-230, y), Vector2(-230 + 460.0 * cut, y), RED, 7.0)
		"toll_drop":
			_road()
			_barrier(Vector2(120, 240), 1.0 - _ease(k * 2.5))
			_sign(Vector2(0, -60), "PRIME PLUS MAX TOLL", GOLD, NAVY, 40)
			_van(Vector2(-260, 255), 220.0, false)
		"gps", "gps_ads":
			# A phone: a clean map, a clean route.
			DrawUtil.rrect(ci, Rect2(-230, -340, 460, 640), Color("1e1e28"), 44)
			DrawUtil.rrect(ci, Rect2(-210, -310, 420, 580), Color("eef2e6"), 26)
			for j in 5:
				ci.draw_line(Vector2(-210, -250 + j * 120), Vector2(210, -250 + j * 120), Color.WHITE, 16.0)
				ci.draw_line(Vector2(-170 + j * 90, -310), Vector2(-170 + j * 90, 270), Color.WHITE, 16.0)
			var route := PackedVector2Array([Vector2(-170, 230), Vector2(-170, -10), Vector2(10, -10), Vector2(10, -250), Vector2(190, -250)])
			ci.draw_polyline(route, Color("3d8fd6"), 12.0, true)
			ci.draw_circle(route[0], 16.0, Color("3d8fd6"))
			ci.draw_circle(route[route.size() - 1], 18.0, RED)
			var lit := 5
			if name == "gps_ads":
				var ads := ["SALE!", "BUY NOW", "HOARDLY+", "50% MORE", "UPGRADE", "LAST CHANCE", "WIN A YACHT", "SPONSORED"]
				var n := int(k * 11.0)
				for j in mini(n, ads.size()):
					var r := Rect2(Vector2(-200 + fmod(j * 137.0, 220.0), -290 + fmod(j * 211.0, 470.0)), Vector2(220, 90))
					DrawUtil.rrect(ci, r, [GOLD, Color("ff6fae"), Color("7b5cff"), Color("3ed27a")][j % 4], 12)
					_text_at(r.get_center(), str(ads[j]), 30, NAVY)
				lit = clampi(5 - int(k * 5.0), 1, 5)
			# The app's rating, up in the corner.
			for j in 5:
				Icons.star(ci, Vector2(-120 + j * 60, -390), 22.0, GOLD if j < lit else Color(INK, 0.18))
		"courier", "monocle":
			var walls := [Color("ffd6c9"), Color("fff0b8"), Color("cfe4ff")]
			var roofs := [Color("e8746a"), Color("6aa8e8"), Color("8bc36a")]
			for j in 3:
				_house(Vector2(-320 + j * 320, 180), 220.0, walls[j], roofs[j])
			_van(Vector2(-400 + k * 500.0 if name == "courier" else 100.0, 260), 220.0, false)
			for j in 4:
				var hk := fmod(local * 0.5 + j * 0.25, 1.0)
				_heart(Vector2(-300 + j * 200, 0.0 - hk * 200.0), 16.0, Color(1.0, 0.45, 0.55, 1.0 - hk))
			if name == "monocle":
				# The view darkens, and a monocle fills the frame. It glints.
				ci.draw_rect(Rect2(-1200, -1200, 2400, 2400), Color(0, 0, 0, 0.45 * _ease(k * 2.0)))
				var s := _ease(k * 2.0)
				var c := Vector2(0, -40)
				ci.draw_arc(c, 210.0 * s, 0, TAU, 64, GOLD, 24.0 * s, true)
				ci.draw_circle(c, 200.0 * s, Color(0.85, 0.92, 1.0, 0.18))
				ci.draw_line(c + Vector2(140, 155) * s, c + Vector2(230, 460), GOLD, 8.0)
				var g := clampf((k - 0.55) / 0.25, 0.0, 1.0)
				if g > 0.0 and g < 1.0:
					var gx := lerpf(-200.0, 200.0, g)
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(gx - 30, -200), c + Vector2(gx + 20, -200), c + Vector2(gx - 20, 200), c + Vector2(gx - 70, 200)]), Color(1, 1, 1, 0.55))
					Icons.star(ci, c + Vector2(-140, -140), 40.0 * sin(PI * g), Color.WHITE)
		"air_pump", "air_coin":
			_root.draw_rect(Rect2(-80, -200, 160, 380), Color("e8574a"))
			DrawUtil.rrect(ci, Rect2(-90, -230, 180, 70), Color("c63d33"), 14)
			ci.draw_circle(Vector2(0, -80), 52.0, Color.WHITE)
			ci.draw_arc(Vector2(0, -80), 52.0, 0, TAU, 32, INK, 5.0, true)
			ci.draw_line(Vector2(0, -80), Vector2(0, -80) + Vector2.from_angle(-PI * 0.75 + sin(local * 2.0) * 0.3) * 40.0, RED, 5.0)
			var hose := PackedVector2Array()
			for j in 20:
				var u := j / 19.0
				hose.append(Vector2(80 + u * 220.0, 40 + sin(u * PI) * 120.0))
			ci.draw_polyline(hose, Color("2a2a33"), 12.0, true)
			var coin := name == "air_coin"
			_sign(Vector2(0, -330), "AIR $1.50" if coin else "FREE AIR", RED if coin else Color("2b8a3e"), Color.WHITE, 48)
			if coin:
				var slide := _ease(k * 2.0)
				var p := Vector2(lerpf(520.0, 0.0, slide), 60)
				DrawUtil.rrect(ci, Rect2(p + Vector2(-70, -60), Vector2(140, 120)), Color("9da0aa"), 12)
				ci.draw_rect(Rect2(p + Vector2(-8, -36), Vector2(16, 72)), Color("2a2a33"))
				ci.draw_circle(p + Vector2(0, 74), 14.0, GOLD)
		"points", "points_more":
			if name == "points":
				# Ten parcels stack up. Then: one point.
				for j in 10:
					var pk := _pop(k * 4.0 - j * 0.25)
					if pk > 0.0:
						DrawUtil.parcel(ci, Vector2(-260 + (j % 5) * 130, 140 - (j / 5) * 100), Vector2(110, 86) * pk, Palette.pkg(["red", "blue", "yellow", "green", "purple"][j % 5]), true)
				var ptk := _pop((k - 0.6) / 0.25)
				if ptk > 0.0:
					ci.draw_circle(Vector2(0, -200), 90.0 * ptk, GOLD)
					_text_at(Vector2(0, -206), "+1", int(70 * ptk) + 1, NAVY)
			else:
				# One point in, one point out, forever.
				var spin := sin(local * 4.0)
				for j in 2:
					var c := Vector2(-220 + j * 440, -60)
					_root.draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(absf(spin) * 0.6 + 0.4, 1.0), 0.0, c))
					ci.draw_circle(Vector2.ZERO, 100.0, GOLD)
					_text_at(Vector2(0, -6), "1 PT", 44, NAVY)
					_root.draw_set_transform_matrix(_xf)
				var arrow := PackedVector2Array([Vector2(-90, -100), Vector2(90, -100)])
				ci.draw_polyline(arrow, INK, 10.0, true)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(110, -100), Vector2(80, -125), Vector2(80, -75)]), INK)
				ci.draw_polyline(PackedVector2Array([Vector2(90, -20), Vector2(-90, -20)]), INK, 10.0, true)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-110, -20), Vector2(-80, -45), Vector2(-80, 5)]), INK)
		"receipt", "receipt_long":
			# A till, and a receipt coming out of it.
			DrawUtil.rrect(ci, Rect2(-260, -380, 520, 120), Color("3b3f4a"), 20)
			ci.draw_rect(Rect2(-230, -280, 460, 12), Color("1e1e28"))
			var lines := [["Item", "$9.99"], ["Convenience fee", "$2.99"]]
			if name == "receipt_long":
				lines += [["Fee for the fee", "$0.99"], ["Convenience fee fee", "$0.49"], ["Paper", "$0.25"], ["Ink", "$0.25"],
					["Receipt fee", "$0.75"], ["Reading fee", "$1.10"], ["Scrolling fee", "$0.40"], ["Gratitude", "$3.00"], ["Fee", "$0.01"]]
			var out := 160.0 + (k * 220.0 if name == "receipt" else 260.0 + k * 900.0)
			var scroll := maxf(0.0, out - 560.0)
			var top := -276.0
			ci.draw_rect(Rect2(-210, top, 420, out), Color.WHITE)
			var f := UiTheme.font()
			for j in lines.size():
				var y := top + 60.0 + j * 64.0 - scroll
				if y > top + 20.0 and y < top + out:
					ci.draw_string(f, Vector2(-190, y), str(lines[j][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
					ci.draw_string(f, Vector2(70, y), str(lines[j][1]), HORIZONTAL_ALIGNMENT_RIGHT, 110, 30, INK)
		"send_back", "refund":
			if name == "send_back":
				_house(Vector2(-300, 180), 240.0, Color("fff0b8"), Color("6aa8e8"))
				DrawUtil.rrect(ci, Rect2(150, -60, 280, 240), Color("c9c6cc"), 10)
				_sign(Vector2(290, -90), "HOARDLY", GOLD, NAVY, 34)
				var u := _ease(k * 1.4)
				var p := Vector2(lerpf(-250.0, 290.0, u), lerpf(60.0, 40.0, u) - sin(u * PI) * 260.0)
				DrawUtil.parcel(ci, p, Vector2(110, 86), Palette.pkg("orange"), true)
			else:
				# The refund, in its own box, with its own shipping charge.
				var s := _pop(k * 2.5)
				DrawUtil.parcel(ci, Vector2(0, 40), Vector2(360, 280) * s, Palette.pkg("blue"), true)
				_sign(Vector2(0, 20) * s, "REFUND: $0.42", Color.WHITE, INK, int(40 * s) + 1)
				var tk := _pop((k - 0.4) / 0.2)
				if tk > 0.0:
					_sign(Vector2(170, -170), "SHIPPING $12.99", RED, Color.WHITE, int(36 * tk) + 1)
		"sunrise", "billboard":
			var rise := _ease(k * 1.4) if name == "sunrise" else 1.0
			ci.draw_circle(Vector2(0, 160 - 320.0 * rise), 110.0, Color("ffcf5a"))
			for j in 8:
				var a := j * TAU / 8.0 + local * 0.2
				var c := Vector2(0, 160 - 320.0 * rise)
				ci.draw_line(c + Vector2.from_angle(a) * 130.0, c + Vector2.from_angle(a) * 175.0, Color(1.0, 0.82, 0.35, 0.7), 10.0)
			# (The ground again, in front of the sun still coming up.)
			ci.draw_rect(Rect2(-1200, 180, 2400, 1400), Color(SPOTS[spot]["look"][2]))
			var walls := [Color("ffd6c9"), Color("fff0b8"), Color("cfe4ff"), Color("e0f2d0")]
			var roofs := [Color("e8746a"), Color("6aa8e8"), Color("8bc36a"), Color("b07ad6")]
			for j in 4:
				_house(Vector2(-390 + j * 260, 180), 190.0, walls[j], roofs[j])
			if name == "billboard":
				var up := _ease(k * 1.6)
				var by := 180.0 - 560.0 * up
				# Its shadow over the street.
				ci.draw_rect(Rect2(-1200, -40, 2400, 520), Color(0.1, 0.1, 0.2, 0.35 * up))
				ci.draw_rect(Rect2(-20, by + 220, 40, 560), Color("6b6e78"))
				DrawUtil.rrect(ci, Rect2(-380, by - 40, 760, 260), NAVY, 10)
				ci.draw_circle(Vector2(-270, by + 90), 70.0, GOLD)
				_text_at(Vector2(-270, by + 86), "H", 90, NAVY)
				_text_at(Vector2(70, by + 50), "HOARDLY", 70, GOLD)
				_text_at(Vector2(70, by + 130), "OUTDOOR", 50, Color.WHITE)
		"ladder", "ladder_sold":
			var rails := Color("b07a48")
			ci.draw_line(Vector2(-110, 180), Vector2(-110, -420), rails, 22.0)
			ci.draw_line(Vector2(110, 180), Vector2(110, -420), rails, 22.0)
			var n := 10
			for j in n:
				var y := 140.0 - j * 58.0
				var appear := _pop(k * 4.0 - j * 0.25) if name == "ladder" else 1.0
				var gone := name == "ladder_sold" and j < 6
				if gone:
					# The bottom rungs come off and are sold back, price tags on.
					var fly := _ease(k * 2.2 - (5 - j) * 0.18)
					var p := Vector2(lerpf(0.0, 380.0 * (1.0 if j % 2 == 0 else -1.0), fly), y - fly * 120.0)
					if fly < 1.0:
						ci.draw_line(p + Vector2(-100, 0), p + Vector2(100, 0), rails.lightened(0.15), 16.0)
					if fly > 0.3:
						_sign(p + Vector2(0, -40), "$%d" % (49 + j * 50), Color.WHITE, RED, 28)
				elif appear > 0.0:
					ci.draw_line(Vector2(-100 * appear, y), Vector2(100 * appear, y), rails.lightened(0.15), 16.0)
			# Hoardly's flag at the top.
			ci.draw_line(Vector2(0, -420), Vector2(0, -540), INK, 6.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -540), Vector2(120, -510), Vector2(0, -480)]), GOLD)
		"small_print":
			# Small print, far too fast to read.
			ci.draw_rect(Rect2(-1200, -1200, 2400, 2400), Color.WHITE)
			var f := UiTheme.font()
			for j in 60:
				var y := -520.0 + j * 40.0 - fmod(local * 900.0, 40.0)
				var line: String = LEGALESE[(j + int(local * 900.0 / 40.0)) % LEGALESE.size()]
				ci.draw_string(f, Vector2(-380, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(INK, 0.55))


func _text_at(at: Vector2, text: String, px: int, col: Color) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## A house standing on `base` (bottom middle), `s` wide: walls, a roof, warm windows and a door.
func _house(base: Vector2, s: float, wall: Color, roof: Color) -> void:
	var h := s * 0.7
	var body := Rect2(base.x - s / 2.0, base.y - h, s, h)
	DrawUtil.rrect(_root, Rect2(body.position + Vector2(8, 10), body.size), Color(0, 0, 0, 0.12), 8)
	DrawUtil.rrect(_root, body, wall, 8)
	_root.draw_colored_polygon(PackedVector2Array([Vector2(base.x - s * 0.62, base.y - h + 4), Vector2(base.x, base.y - h - s * 0.48),
		Vector2(base.x + s * 0.62, base.y - h + 4)]), roof)
	DrawUtil.rrect(_root, Rect2(base.x - s * 0.1, base.y - h * 0.5, s * 0.2, h * 0.5), roof.darkened(0.3), 6)
	DrawUtil.rrect(_root, Rect2(base.x - s * 0.38, base.y - h * 0.75, s * 0.2, s * 0.18), Color("ffe9a0"), 6)
	DrawUtil.rrect(_root, Rect2(base.x + s * 0.18, base.y - h * 0.75, s * 0.2, s * 0.18), Color("ffe9a0"), 6)


## A van, side on, `s` long, centred on `c`: a grey Hoardly one (gold H, HRDLY plate) or ours (cream, blue).
func _van(c: Vector2, s: float, hoardly: bool) -> void:
	var h := s * 0.46
	var body := GREY_VAN if hoardly else Color("f6eedc")
	var cab := GREY_CAB if hoardly else Color("3d6fd6")
	DrawUtil.rrect(_root, Rect2(c + Vector2(-s / 2.0 + 6, -h / 2.0 + 12), Vector2(s, h)), Color(0, 0, 0, 0.15), h * 0.25)
	DrawUtil.rrect(_root, Rect2(c + Vector2(-s / 2.0, -h / 2.0), Vector2(s, h)), body, h * 0.22)
	DrawUtil.rrect(_root, Rect2(c + Vector2(s * 0.18, -h / 2.0), Vector2(s * 0.32, h * 0.62)), cab, h * 0.18)
	DrawUtil.rrect(_root, Rect2(c + Vector2(s * 0.24, -h * 0.4), Vector2(s * 0.2, h * 0.3)), Color(0.85, 0.93, 1.0), h * 0.08)
	for x in [-0.3, 0.3]:
		_root.draw_circle(c + Vector2(s * x, h / 2.0), h * 0.22, Color("2a2a33"))
		_root.draw_circle(c + Vector2(s * x, h / 2.0), h * 0.09, Color("bfbfc8"))
	if hoardly:
		_root.draw_circle(c + Vector2(-s * 0.12, -h * 0.05), h * 0.22, GOLD)
		_text_at(c + Vector2(-s * 0.12, -h * 0.07), "H", int(h * 0.3), NAVY)


## A petrol pump on `base`, `h` tall, in its brand's colour, the brand's sign on top.
func _pump(base: Vector2, h: float, col: Color, brand: String) -> void:
	if h < 4.0:
		return
	var w := h * 0.5
	DrawUtil.rrect(_root, Rect2(base + Vector2(-w / 2.0 + 8, -h + 10), Vector2(w, h)), Color(0, 0, 0, 0.12), 14)
	DrawUtil.rrect(_root, Rect2(base + Vector2(-w / 2.0, -h), Vector2(w, h)), col, 14)
	DrawUtil.rrect(_root, Rect2(base + Vector2(-w * 0.36, -h * 0.85), Vector2(w * 0.72, h * 0.25)), Color("1e1e28"), 8)
	_text_at(base + Vector2(0, -h * 0.73), "$$$", int(h * 0.08), Color("7dff9a"))
	_root.draw_rect(Rect2(base + Vector2(w / 2.0, -h * 0.55), Vector2(16, h * 0.4)), Color("2a2a33"))
	DrawUtil.rrect(_root, Rect2(base + Vector2(-w * 0.6, -h - 80), Vector2(w * 1.2, 70)), col.darkened(0.2), 12)
	_text_at(base + Vector2(0, -h - 45), brand, int(h * 0.1), Color.WHITE)


## A little person on `feet`: a body in `col`, waving (or arms down).
func _person(feet: Vector2, col: Color, waving: bool, t: float) -> void:
	DrawUtil.rrect(_root, Rect2(feet + Vector2(-22, -80), Vector2(44, 80)), col, 16)
	_root.draw_circle(feet + Vector2(0, -102), 24.0, Color("f2c9a0"))
	var sh := feet + Vector2(18, -70)
	var hand := sh + (Vector2.from_angle(-PI / 2.0 + 0.5 + sin(t * 9.0) * 0.5) * 50.0 if waving else Vector2(10, 46))
	_root.draw_line(sh, hand, col, 12.0)
	_root.draw_line(feet + Vector2(-18, -70), feet + Vector2(-26, -24), col, 12.0)


## Every driver, merged into one robot: a grey box with a gold H, blinking eyes and an antenna.
func _robot(base: Vector2, h: float, t: float) -> void:
	if h < 4.0:
		return
	var w := h * 0.6
	DrawUtil.rrect(_root, Rect2(base + Vector2(-w / 2.0, -h * 0.62), Vector2(w, h * 0.62)), GREY_VAN, 20)
	DrawUtil.rrect(_root, Rect2(base + Vector2(-w * 0.4, -h), Vector2(w * 0.8, h * 0.34)), GREY_CAB, 18)
	var blink := 0.15 if fmod(t, 1.6) < 0.1 else 1.0
	for x in [-0.18, 0.18]:
		_root.draw_rect(Rect2(base + Vector2(w * x - 14, -h * 0.86 - 10 * blink), Vector2(28, 20 * blink)), Color("7de0ff"))
	_root.draw_line(base + Vector2(0, -h), base + Vector2(0, -h - 50), GREY_CAB, 6.0)
	_root.draw_circle(base + Vector2(0, -h - 54), 12.0, RED)
	_root.draw_circle(base + Vector2(0, -h * 0.32), h * 0.12, GOLD)
	_text_at(base + Vector2(0, -h * 0.33), "H", int(h * 0.15), NAVY)


func _heart(c: Vector2, r: float, col: Color) -> void:
	_root.draw_circle(c + Vector2(-r * 0.5, 0), r * 0.6, col)
	_root.draw_circle(c + Vector2(r * 0.5, 0), r * 0.6, col)
	_root.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.05, r * 0.15), c + Vector2(r * 1.05, r * 0.15), c + Vector2(0, r * 1.3)]), col)


func _sign(c: Vector2, text: String, bg: Color, fg: Color, px: int) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + px
	DrawUtil.rrect(_root, Rect2(c - Vector2(w / 2.0, px * 0.9), Vector2(w, px * 1.8)), bg, px * 0.4)
	_text_at(c, text, px, fg)


func _road() -> void:
	_root.draw_rect(Rect2(-1100, 190, 2200, 160), Color("55545e"))
	var x := -1100.0
	while x < 1100.0:
		_root.draw_rect(Rect2(x, 266, 70, 8), Color(1, 1, 1, 0.8))
		x += 140.0


## A toll boom pivoting on `post` (its foot): down across the road (0), or lifted (1).
func _barrier(post: Vector2, lift: float) -> void:
	_root.draw_rect(Rect2(post + Vector2(-14, -140), Vector2(28, 140)), Color("d0d0d8"))
	var dir := Vector2.from_angle(lerpf(PI, PI * 1.45, lift))
	var top := post + Vector2(0, -110)
	for j in 8:
		_root.draw_line(top + dir * (j * 52.0), top + dir * ((j + 1) * 52.0), RED if j % 2 == 0 else Color.WHITE, 22.0)
	_root.draw_circle(top, 18.0, GREY_CAB)
