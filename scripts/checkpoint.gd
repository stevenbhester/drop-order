class_name Checkpoint
extends CanvasLayer
## A road checkpoint at the entrance to each zone after the first: the first time you start a job in a zone
## you haven't played in yet (whichever job: levels can be skipped, so it's tied to the zone, not to a
## level), an inspector stops the van and you watch one short (pretend) ad. A tank of gas after, for your
## trouble. It's the government, officially. Unofficially, the fine print and the H on his clipboard say
## who paid for it.
##
## The point: players good enough never to run out of gas still see an ad now and then. So anyone who's
## watched an ad since the last checkpoint is waved through. With the "Full license" (Progress.licensed:
## a tester option standing in for the premium version) there are none. Self-tests skip them.
## While in beta, a post-it on the card's corner says the ads are stand-ins (BETA_NOTE).
## `-- --checkpoint` shows one over whatever's showing (`--checkpoint=waved` the waved-through card).

signal done

const HAZARD := Color("ffd23f")
const HAZARD_INK := Color("2a2233")
const NAVY := Color("23325c")
const STAMP := Color("d7192a")
## The fine print, one per zone in turn: the Baron, never named.
const FINE := ["By order of Senator Crumb's Committee on Roads.", "Checkpoint made possible by a generous, entirely unrelated donation.",
	"Hoardly vehicles are exempt, for safety reasons.", "This inspection brought to you by the Department of Roads (a Hoardly Inc. partner)."]

## The post-it: testers kept asking whether the ads were real.
const BETA_NOTE := "Real ads aren't in yet, so the villain's company, Hoardly Inc., is filling in with pretend ones. It's all a joke, and nothing's for sale."

var zone := 1
## "ask" (watch the ad), "ad" (it's playing), "cleared" (watched: gas), "waved" (an ad watched lately).
var state := "ask"

var _root: Control
var _go: JuicyButton
var _t := 0.0
var _state_t := 0.0
var _closing := false


## Does starting level `n` stop at a checkpoint first?
static func due(n: int) -> bool:
	if Progress.auto or Progress.licensed:
		return false
	return pending(Zones.of(n))


## Is zone `k`'s checkpoint still standing? (Never for the first zone; gone once passed, or once any job in
## the zone has been won, so nobody already playing there meets one.)
static func pending(k: int) -> bool:
	if k <= 0 or Progress.licensed or Progress.checkpoints.has(k):
		return false
	for n in range(int(RoadMap.REGIONS[k]["from"]), int(RoadMap.REGIONS[k]["to"]) + 1):
		if Progress.is_complete(n):
			return false
	return true


## Is zone `k`'s gate still held shut for its checkpoint? (pending(), but never under the self-tests.) The
## map keeps the tape up and the fog in until it's passed, then opens the zone (RoadMap.open_zone).
static func holds(k: int) -> bool:
	return not Progress.auto and pending(k)


func _ready() -> void:
	layer = 82
	if state == "ask" and Progress.ads_seen > 0:
		state = "waved"
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_card)
	add_child(_root)
	_go = JuicyButton.new()
	_go.font_px = 52
	_go.size = Vector2(640, 150)
	_go.pressed.connect(_on_go)
	_root.add_child(_go)
	_label_button()
	if state == "waved":
		_pass(false)
	elif state == "cleared":
		_pass(true)             # (debug: straight to the end)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	Sfx.play("screech", 1.0, -8.0)
	Sfx.haptic(20)


func _label_button() -> void:
	var asking := state == "ask"
	_go.label = "Watch ad" if asking else Cosmetics.go_word(Progress.ride, 2)
	_go.icon_name = "ad" if asking else "play"
	_go.bg = HAZARD if asking else Palette.GOOD
	_go.fg = HAZARD_INK if asking else Color.WHITE
	_go.restyle()
	_go.breathe(true)


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	var v := _root.get_viewport_rect().size
	# Asking: right under the paragraph (the flavour line goes under it). After: at the card's foot.
	var card := _card_rect(v)
	_go.position = Vector2((v.x - _go.size.x) / 2.0, card.position.y + 815.0 if state == "ask" else card.end.y - 190.0)
	_go.pivot_offset = _go.size / 2.0
	_root.queue_redraw()


func _on_go() -> void:
	if _closing or state == "ad":
		return
	Sfx.play("click")
	if state == "ask":
		_watch()
	else:
		_close()


## The message from our sponsors (AdPicker). The first one a player ever watches at a gate is a Hoardly spot
## (it's his checkpoint); after that, any of them.
func _watch() -> void:
	state = "ad"
	_root.visible = false
	var ad := AdPicker.make(Progress.gate_ads == 0)
	add_child(ad)
	ad.finished.connect(func():
		Progress.gate_ad_watched()
		_root.visible = true
		_pass(true))


## Through: the stamp, and (after an ad here) a tank of gas.
func _pass(watched: bool) -> void:
	Progress.checkpoint_passed(zone)
	state = "cleared" if watched else "waved"
	_state_t = 0.0
	if watched:
		Progress.refuel()
		Sfx.play("kaching", 1.0, -4.0)
	Sfx.play("slam", 1.2, -6.0)
	Sfx.haptic(30)
	_label_button()


func _close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		done.emit()
		queue_free())


func _card_rect(v: Vector2) -> Rect2:
	var w := minf(940.0, v.x - 60.0)
	var h := 1260.0
	return Rect2((v.x - w) / 2.0, (v.y - h) / 2.0, w, h)


func _text(text: String, at: Vector2, px: int, col: Color) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _lines(text: String, at: Vector2, px: int, w: float, col: Color) -> void:
	var lines := BossIntro.wrap_text(text, px, w)
	for i in lines.size():
		_text(str(lines[i]), at + Vector2(0, (i - (lines.size() - 1) / 2.0) * px * 1.3), px, col)


func _draw_card() -> void:
	var v := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.1, 0.08, 0.16, 0.65))
	var r := _card_rect(v)
	var cx := r.get_center().x
	DrawUtil.rrect(_root, Rect2(r.position + Vector2(0, 14), r.size), Color(0, 0, 0, 0.3), 56)
	DrawUtil.rrect(_root, r, Palette.CARD, 56)
	# The hazard band across the top, and the word.
	var band := Rect2(r.position + Vector2(0, 60), Vector2(r.size.x, 120))
	_root.draw_rect(band, HAZARD)
	var x := band.position.x - 40.0
	while x < band.end.x:
		_root.draw_colored_polygon(PackedVector2Array([Vector2(maxf(x, band.position.x), band.position.y), Vector2(minf(x + 30, band.end.x), band.position.y),
			Vector2(minf(x + 10, band.end.x), band.position.y + 18), Vector2(maxf(x - 20, band.position.x), band.position.y + 18)]), HAZARD_INK)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(maxf(x, band.position.x), band.end.y - 18), Vector2(minf(x + 30, band.end.x), band.end.y - 18),
			Vector2(minf(x + 10, band.end.x), band.end.y), Vector2(maxf(x - 20, band.position.x), band.end.y)]), HAZARD_INK)
		x += 60.0
	_text("CHECKPOINT", band.get_center(), 68, HAZARD_INK)
	# The inspector, with his clipboard (the clipboard has an H on it).
	_inspector(Vector2(cx - 120, band.end.y + 330), 300.0)
	_barrier(Vector2(cx + 150, band.end.y + 330))
	var y := band.end.y + 400.0
	var zname := Zones.name_of(zone)
	if state == "ask":
		_text("Entering %s" % zname, Vector2(cx, y), 52, Palette.TEXT)
		# Said straight: it's an ad, and here's what watching it gets you.
		var jobs := int(RoadMap.REGIONS[zone]["to"]) - int(RoadMap.REGIONS[zone]["from"]) + 1
		_lines("Watch one short ad to open %s: %d new jobs, and a full tank of gas." % [zname, jobs],
			Vector2(cx, y + 120), 38, r.size.x - 120.0, Palette.TEXT_SOFT)
		# (The button sits here: see _process.) Under it, small: who to blame.
		# Under it, not ready yet (and it says so): the way to never see these again.
		UiTheme.draw_wip(_root, Rect2(cx - 380.0, r.position.y + 815.0 + 150.0 + 26.0, 760.0, 104.0), "Buy Last Mile Premium to remove ads!")
		_lines(str(FINE[posmod(zone - 1, FINE.size())]), Vector2(cx, r.position.y + 815.0 + 150.0 + 26.0 + 104.0 + 42.0), 24, r.size.x - 160.0, Color(Palette.TEXT_SOFT, 0.6))
	else:
		# PAPERS IN ORDER, stamped down.
		var k := clampf(_state_t / 0.18, 0.0, 1.0)
		var s := lerpf(2.2, 1.0, k)
		var at := Vector2(cx, y + 20)
		_root.draw_set_transform(at, -0.12, Vector2.ONE * s)
		var a := k
		_root.draw_rect(Rect2(-300, -60, 600, 120), Color(STAMP, 0.9 * a), false, 10.0)
		_text("PAPERS IN ORDER", Vector2.ZERO, 58, Color(STAMP, a))
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var body := "A full tank, for your trouble. Welcome to %s." % zname if state == "cleared" \
			else "You've watched an ad on your way here. The inspector waves you through to %s." % zname
		_lines(body, Vector2(cx, y + 170), 38, r.size.x - 120.0, Palette.TEXT)
		if state == "cleared":
			Icons.draw(_root, "gas", Vector2(cx, y + 260), 70.0 * _pop((_state_t - 0.2) / 0.3), GasChip.FUEL)
	_post_it(Vector2(r.end.x - 220.0, r.end.y + 60.0))        # (stuck on the card's bottom edge, out of the way of the headline)


## The beta note: a yellow post-it, a strip of tape across its top, stuck on the card's corner at a tilt.
func _post_it(c: Vector2) -> void:
	var w := 380.0
	var lines := BossIntro.wrap_text(BETA_NOTE, 25, w - 50.0)
	var h := 92.0 + lines.size() * 31.0
	_root.draw_set_transform(c, 0.06, Vector2.ONE)
	_root.draw_rect(Rect2(-w / 2.0 + 6, -h / 2.0 + 10, w, h), Color(0, 0, 0, 0.18))
	_root.draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h), Color("fff1a1"))
	_root.draw_rect(Rect2(-w / 2.0, h / 2.0 - 14, w, 14), Color("f5e17a"))
	_root.draw_rect(Rect2(-60, -h / 2.0 - 16, 120, 34), Color(1, 1, 1, 0.55))
	var f := UiTheme.font()
	Icons.draw(_root, "cone", Vector2(-w / 2.0 + 44, -h / 2.0 + 40), 40.0, Color.WHITE)
	_root.draw_string(f, Vector2(-w / 2.0 + 74, -h / 2.0 + 52), "Beta note", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("2a2233"))
	for i in lines.size():
		_root.draw_string(f, Vector2(-w / 2.0 + 26, -h / 2.0 + 90 + i * 31.0), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("4a4458"))
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


## The inspector, standing on `feet`, `h` tall: a peaked cap, a moustache, a uniform and a clipboard.
func _inspector(feet: Vector2, h: float) -> void:
	var u := h / 100.0
	var bob := sin(_t * 2.5) * u
	_root.draw_set_transform(feet, 0.0, Vector2(1.0, 0.25))
	_root.draw_circle(Vector2.ZERO, 30.0 * u, Color(0, 0, 0, 0.14))
	_root.draw_set_transform(feet + Vector2(0, bob), 0.0, Vector2.ONE)
	DrawUtil.rrect(_root, Rect2(Vector2(-22, -62) * u, Vector2(44, 62) * u), NAVY, 10.0 * u)
	_root.draw_rect(Rect2(Vector2(-22, -10) * u, Vector2(44, 10) * u), NAVY.darkened(0.3))
	_root.draw_circle(Vector2(0, -76) * u, 17.0 * u, Color("f2c9a0"))
	# The moustache, and two dots of eyes.
	_root.draw_colored_polygon(PackedVector2Array([Vector2(-10, -70) * u, Vector2(0, -73) * u, Vector2(10, -70) * u, Vector2(6, -67) * u, Vector2(0, -69) * u, Vector2(-6, -67) * u]), Color("6b4a32"))
	for ex in [-6.0, 6.0]:
		_root.draw_circle(Vector2(ex, -80) * u, 1.8 * u, HAZARD_INK)
	# The cap: crown, peak, badge.
	DrawUtil.rrect(_root, Rect2(Vector2(-19, -100) * u, Vector2(38, 14) * u), NAVY, 4.0 * u)
	_root.draw_rect(Rect2(Vector2(-22, -88) * u, Vector2(44, 5) * u), HAZARD_INK)
	_root.draw_circle(Vector2(0, -94) * u, 3.5 * u, BaronAd.GOLD)
	# The clipboard, held out, with a small gold H in its corner.
	DrawUtil.rrect(_root, Rect2(Vector2(14, -52) * u, Vector2(30, 38) * u), Color("c8a46a"), 3.0 * u)
	_root.draw_rect(Rect2(Vector2(17, -48) * u, Vector2(24, 31) * u), Color.WHITE)
	for l in 4:
		_root.draw_line(Vector2(20, -42 + l * 6) * u, Vector2(34 - (l % 2) * 6, -42 + l * 6) * u, Color(HAZARD_INK, 0.5), 1.2 * u)
	_root.draw_circle(Vector2(37, -22) * u, 4.0 * u, BaronAd.GOLD)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The boom: down while you wait, up once you're through.
func _barrier(post: Vector2) -> void:
	var lift := 0.0 if state == "ask" or state == "ad" else clampf(_state_t / 0.5, 0.0, 1.0)
	_root.draw_rect(Rect2(post + Vector2(-12, -150), Vector2(24, 150)), Color("d0d0d8"))
	var dir := Vector2.from_angle(lerpf(0.0, -PI * 0.45, lift))
	var top := post + Vector2(0, -120)
	for j in 5:
		_root.draw_line(top + dir * (j * 46.0), top + dir * ((j + 1) * 46.0), STAMP if j % 2 == 0 else Color.WHITE, 20.0)
	_root.draw_circle(top, 16.0, HAZARD_INK)
