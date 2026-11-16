class_name UnlockCard
extends Control
## "You found something!": pops over the level finish when a present was picked up. First it's a parcel,
## wrapped in the item's colour, rattling: tap to open it. The lid flies off in a blast of light, and then
## the sunburst, the item's kind as a slanted banner, a big turning van (or truck) wearing it on a pad, its
## name, where it's from, and two choices: a button that says what it does for that kind of thing ("Take it
## for a spin", "Paint the van"...) and "Maybe later". Nothing is used unless the player says so.
## A new ride is shown in its own Classic paint (how it's meant to look). Wearing some other paint job, you
## get two ways in, each with a little van beside it showing the result: the big button keeps your paint
## ("in your Duskwood paint", small, under it), a quieter one under that takes it in Classic.
## `wrapped = false` skips the parcel (reopening it from the finish card's tag).

signal closed

## Where it came from, if it wasn't just found on the road ("the job 30 chest"): said under its name.
var source := ""

var item := ""
var wrapped := true
## One page of a run of rewards (RewardPager): closing just says so (no fade; the pager pans it away), and
## once it's all shown a tap anywhere off the buttons is "Maybe later", so tapping through is quick.
var paged := false

## What the big button says, by kind: what using it does.
const CTA := {"ride": "Take it for a spin", "paint": "Paint the van", "topper": "Put it on", "trail": "Burn rubber with it",
	"road": "Repave the roads", "package": "Pack with these", "building": "Rebuild the town", "queue": "Swap the chute",
	"controls": "Use these buttons"}

var _t := 0.0
var _van: Van
var _fx: Fx
var _wear: JuicyButton
var _keep: JuicyButton
var _classic: JuicyButton      # a new ride, in its Classic paint (only when you're wearing another)
var _c := Vector2.ZERO
var _worn := false
var _revealed := false           # the item and its buttons are all in (a tap before then hurries them)
var _closed := false
var _reveal_tw: Tween
var _wear_tw: Tween
## The parcel stage: 0 waiting to be opened, then seconds since the tap; -1 once it's open (or never wrapped).
var _box_t := -1.0
var _box_wait := 0.0
var _items: Array = []    # what the reveal shows (hidden while it's wrapped)


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	var v := size
	_c = Vector2(v.x / 2.0, v.y * 0.4)

	_van = Van.new()
	_van.follow_progress = false
	_van.size = 460.0
	_van.position = _c + Vector2(0, 30)
	_van.scale = Vector2.ZERO
	var kind := Cosmetics.kind_of(item)
	# A new ride in its own Classic paint; anything else on the van as it is.
	_van.paint = item if kind == "paint" else ("classic" if kind == "ride" else Progress.paint)
	_van.topper = item if kind == "topper" else ""
	_van.ride = item if kind == "ride" else Progress.ride       # (a new paint job is shown on what you're driving)
	add_child(_van)
	_van.set_top("yellow")
	# A new look: what it changes, big, instead of the van.
	if Looks.is_look(kind):
		_van.visible = false
		if kind == "building":
			var bp := Looks.building_preview(item, 560.0)
			bp.position = _c + Vector2(0, 20)
			add_child(bp)
		else:
			var pv := Node2D.new()
			pv.position = _c + Vector2(0, 30)
			var t0 := Time.get_ticks_msec() / 1000.0
			pv.draw.connect(func(): Looks.draw_preview(pv, item, Vector2.ZERO, 640.0, Time.get_ticks_msec() / 1000.0 - t0))
			pv.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(pv)
			var redraw := Timer.new()
			redraw.wait_time = 1.0 / 30.0
			redraw.autostart = true
			redraw.timeout.connect(pv.queue_redraw)
			pv.add_child(redraw)
	# A new trail: a stretch of road torn up its way, instead of the van.
	if kind == "trail":
		_van.visible = false
		var tp := TrailPreview.new()
		tp.style = item
		tp.tile = 130.0
		tp.position = _c + Vector2(0, 40)
		add_child(tp)
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(tp):
				tp.replay())
	# A new ride shows off its win celebration once it's in.
	if kind == "ride":
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(_van):
				_van.celebrate())
	_fx = Fx.new()
	add_child(_fx)

	if kind == "ride":
		_ride_buttons(v, Progress.paint != "" and Progress.paint != "classic")
	else:
		_two_buttons(v, kind)
	if kind == "ride":
		_mini(_wear, Progress.paint)

	if wrapped:
		# Wrapped first: everything waits under the paper until it's tapped open.
		for c in get_children():
			if c != _fx and c is CanvasItem:
				_items.append(c)
				c.visible = false
		_box_t = 0.0
		Sfx.play("thunk", 0.8, -4.0)
		Sfx.haptic(20)
		return
	_reveal()


## Where the finish card's Next button sits (FinishScreen._layout_buttons): thumbs tapping through rewards
## land here, so on these cards it's the button that changes nothing ("Maybe later").
func _next_spot(v: Vector2) -> Rect2:
	return Rect2((v.x - 560.0) / 2.0, v.y - UiTheme.insets(get_viewport()).y - 330.0, 560.0, 156.0)


## Two choices: wearing the new thing, and under it, where Next was, keeping your look.
func _two_buttons(v: Vector2, kind: String) -> void:
	var bw := minf(v.x, 1000.0) - 100.0
	var x0 := (v.x - bw) / 2.0 - bw - 30.0
	var spot := _next_spot(v)
	_keep = JuicyButton.new()
	_keep.label = "Maybe later"
	_keep.font_px = 48
	_keep.bg = Palette.GOOD
	_keep.fg = Color.WHITE
	_keep.size = spot.size
	_keep.position = spot.position
	_keep.pressed.connect(_close)
	_keep.modulate.a = 0.0
	add_child(_keep)
	_wear = JuicyButton.new()
	_wear.font_px = 44
	_wear.bg = Palette.ACCENT
	_wear.fg = Color.WHITE
	_wear.label = "Paint my ride" if kind == "paint" and Progress.ride != "" else (Cosmetics.spin_cta(item) if kind == "ride" else CTA.get(kind, "Use it now"))
	_wear.size = Vector2(bw, 150)
	_wear.position = Vector2(x0 + bw + 30.0, spot.position.y - 186.0)
	_wear.pressed.connect(_on_wear)
	_wear.scale = Vector2.ZERO
	add_child(_wear)


## A new ride: the big button (a little van beside it showing the result), Maybe later under it. Wearing a
## paint job (`painted`), the big button keeps it (said small, under it) and a quieter one between takes the
## ride in Classic.
func _ride_buttons(v: Vector2, painted: bool) -> void:
	var bw := minf(v.x, 1000.0) - 100.0
	var x0 := (v.x - bw) / 2.0
	var spot := _next_spot(v)
	var y := spot.position.y - (336.0 if painted else 200.0)
	_wear = JuicyButton.new()
	_wear.font_px = 48
	_wear.bg = Palette.ACCENT
	_wear.fg = Color.WHITE
	_wear.label = Cosmetics.spin_cta(item)
	_wear.size = Vector2(bw, 170)
	_wear.position = Vector2(x0, y)
	_wear.pressed.connect(_on_wear)
	_wear.scale = Vector2.ZERO
	add_child(_wear)
	var sub := Label.new()
	sub.text = "in your %s paint" % Cosmetics.name_of(Progress.paint)
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.position = Vector2(0, 94)
	sub.size = Vector2(bw, 40)
	if painted:
		# (The two lines sit as one block in the middle of the button.)
		_wear.label_dy = -24.0
		_wear.add_child(sub)
	else:
		sub.queue_free()
	if painted:
		_classic = JuicyButton.new()
		_classic.font_px = 36
		_classic.bg = Color.WHITE
		_classic.fg = Color("2b2233")
		_classic.label = "Take %s in Classic" % Cosmetics.them(item)
		_classic.size = Vector2(bw, 116)
		_classic.position = Vector2(x0, y + 190)
		_classic.pressed.connect(_on_classic)
		_classic.modulate.a = 0.0
		add_child(_classic)
		_mini(_classic, "classic")
	_keep = JuicyButton.new()
	_keep.label = "Maybe later"
	_keep.font_px = 48
	_keep.bg = Palette.GOOD
	_keep.fg = Color.WHITE
	_keep.size = spot.size
	_keep.position = spot.position
	_keep.pressed.connect(_close)
	_keep.modulate.a = 0.0
	add_child(_keep)


## How it'd look: a little van of the new ride in `paint`, at the button's left end.
func _mini(b: JuicyButton, paint: String) -> void:
	var m := Van.new()
	m.follow_progress = false
	m.size = b.size.y * 0.78
	m.ride = item
	m.paint = paint
	m.position = Vector2(30.0 + m.size * 0.5, b.size.y / 2.0 - 4.0)
	b.add_child(m)
	m.set_top("yellow")


## Tapped open (or never wrapped): the item, the banner and the buttons.
func _reveal() -> void:
	for c in _items:
		if is_instance_valid(c):
			c.visible = c != _van or not (Looks.is_look(Cosmetics.kind_of(item)) or Cosmetics.kind_of(item) == "trail")
	Sfx.play("jingle", 1.0, -3.0)
	Sfx.play("sparkle")
	Sfx.haptic(30)
	var tw := create_tween()
	_reveal_tw = tw
	tw.tween_property(_van, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_fx.burst(_van.position, Cosmetics.tint(item), 28, 900.0, 24.0)
		_fx.burst(_van.position, Palette.STAR_GOLD, 14, 700.0, 18.0))
	tw.tween_interval(0.15)
	tw.tween_callback(func():
		_wear.pivot_offset = _wear.size / 2.0
		_wear_tw = _wear.create_tween()
		_wear_tw.tween_property(_wear, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	tw.tween_property(_keep, "modulate:a", 1.0, 0.3)
	if _classic:
		tw.parallel().tween_property(_classic, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _revealed = true)


## A tap while it's still arriving: everything's in at once.
func _skip_reveal() -> void:
	for t in [_reveal_tw, _wear_tw]:
		if t and t.is_valid():
			t.kill()
	_van.scale = Vector2.ONE
	_wear.pivot_offset = _wear.size / 2.0
	_wear.scale = Vector2.ONE
	_keep.modulate.a = 1.0
	if _classic:
		_classic.modulate.a = 1.0
	_revealed = true


## Take it in its Classic paint: the ride, and the van's paint back to Classic Cream.
func _on_classic() -> void:
	if _worn:
		return
	Progress.put_on("classic")
	_classic.label = "In Classic!"
	_on_wear()


func _on_wear() -> void:
	if _worn:
		return
	_worn = true
	Sfx.play("kaching", 1.1, -3.0)
	Sfx.haptic(25)
	Progress.put_on(item)
	_van.paint = Progress.paint
	_van.squash()
	_fx.burst(_van.position, Cosmetics.tint(item), 30, 1000.0, 26.0)
	_fx.say(_van.position + Vector2(0, -230), "Looking good!", Palette.GOOD, 72)
	_wear.breathe(false)
	_wear.label = "Riding %s!" % Cosmetics.them(item) if Cosmetics.PRONOUN.has(item) else "Wearing it!"
	_wear.icon_name = "star"
	var tw := create_tween()
	tw.tween_interval(0.45 if paged else 0.9)
	tw.tween_callback(_close)


func _close() -> void:
	if _closed:
		return
	_closed = true
	Sfx.play("click")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if paged:
		closed.emit()          # (the pager pans this page away and frees it)
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if _box_t >= 0.0:
		if _box_wait <= 0.0:
			_open_box()
	elif not _revealed:
		_skip_reveal()         # a tap hurries the reveal
	elif paged and not _worn:
		_close()               # tapping on through a run of rewards: "Maybe later"


func _open_box() -> void:
	_box_wait = 0.001
	Sfx.play("punch", 1.2, -2.0)
	Sfx.play("whoomp", 1.1, -4.0)
	Sfx.haptic(45, 1.0)
	_fx.burst(_c, Cosmetics.tint(item), 40, 1300.0, 28.0)
	_fx.burst(_c, Color.WHITE, 24, 1000.0, 20.0)


func _process(delta: float) -> void:
	_t += delta
	if Progress.auto and not wrapped and _t > 1.6 and not OS.get_cmdline_user_args().has("--card-hold"):
		_close()
	if _box_t >= 0.0:
		_box_t += delta
		if _box_wait > 0.0:
			_box_wait += delta
			if _box_wait > 0.35:
				_box_t = -1.0
				_t = 0.0
				_reveal()
		elif (Progress.auto or OS.get_cmdline_user_args().has("--unlock-open")) and _box_t > 1.2:
			_open_box()
		queue_redraw()
		return
	_van.rotation = sin(_t * 0.8) * 0.35 - 0.25
	_van.target_rotation = _van.rotation
	queue_redraw()


func _draw() -> void:
	var v := size
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.14, 0.86))
	var tint := Cosmetics.tint(item)
	if _box_t >= 0.0:
		_draw_box(v, tint)
		return
	# Turning sunburst.
	for k in 18:
		var a0 := _t * 0.35 + TAU * k / 18.0
		var a1 := a0 + TAU / 36.0
		draw_colored_polygon(PackedVector2Array([_c, _c + Vector2(cos(a0), sin(a0)) * 1400.0, _c + Vector2(cos(a1), sin(a1)) * 1400.0]),
			Color(tint.lightened(0.2), 0.16))
	draw_circle(_c, 330, Color(tint, 0.22))
	# Pad.
	draw_set_transform(_c + Vector2(0, 150), 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 330, Color(1, 1, 1, 0.16))
	draw_arc(Vector2.ZERO, 330, 0, TAU, 64, Color(1, 1, 1, 0.3), 8.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Banner.
	var kind := Cosmetics.kind_of(item)
	var head: String = Cosmetics.BANNERS.get(kind, "NEW!")
	var k := clampf(_t / 0.35, 0.0, 1.0)
	var by := v.y * 0.13
	var band := PackedVector2Array([Vector2(-20, by - 70 + 30), Vector2(v.x * k + 20, by - 70 - 30), Vector2(v.x * k + 20, by + 70 - 30), Vector2(-20, by + 70 + 30)])
	draw_colored_polygon(band, Palette.STAR_GOLD)
	var f := UiTheme.font()
	var px := 96
	var w := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_set_transform(Vector2(v.x / 2.0, by + 34), -0.055, Vector2.ONE)
	draw_string_outline(f, Vector2(-w / 2.0, 0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 18, Color(0.1, 0.07, 0.16))
	draw_string(f, Vector2(-w / 2.0, 0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Name and where it's from.
	var name := Cosmetics.name_of(item)
	var npx := 84
	while npx > 40 and f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x > v.x - 80:
		npx -= 4
	var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x
	var ny := v.y * 0.64
	draw_string_outline(f, Vector2((v.x - nw) / 2.0, ny), name, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, 16, Color(0.1, 0.07, 0.16))
	draw_string(f, Vector2((v.x - nw) / 2.0, ny), name, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, tint.lightened(0.35))
	var from: String = source if source != "" else str(Cosmetics.ITEMS.get(item, {}).get("from", ""))
	var sub := ("from " + from) if from != "" else ("for delivering %s packages" % Progress.commas(Cosmetics.need_for(item)) if Cosmetics.by_count(item) and Cosmetics.need_for(item) > 0 else ("won from %s" % Boss.NAME if Cosmetics.need_for(item) < 0 or Boss.LOOT.values().has(item) else "found on the road"))
	sub += "  ·  yours to keep"
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	draw_string(f, Vector2((v.x - sw) / 2.0, ny + 66), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, 0.7))


## The wrapped parcel: it drops in, rattles more and more (it wants opening), "Tap to open!" under it; on
## the tap it swells, the lid flies off and light pours out.
func _draw_box(v: Vector2, tint: Color) -> void:
	UnlockCard.draw_parcel(self, v, _c, tint, _box_t, _box_wait)


## The wrapped parcel (here, and BuffCard's): dropped in round `centre` `t` seconds ago, rattling, "Tap to
## open!" under it and `head` over it; `wait` > 0 is seconds since it was tapped (the lid flies off in a
## blast of light over 0.35 s).
static func draw_parcel(ci: CanvasItem, v: Vector2, centre: Vector2, tint: Color, t: float, wait: float, head := "A PRESENT!", prompt := "Tap to open!") -> void:
	var drop := clampf(t / 0.35, 0.0, 1.0)
	var land := 1.0 - pow(1.0 - drop, 3.0)
	var c := centre + Vector2(0, -500.0 * (1.0 - land) + 40.0)
	var opening := wait > 0.0
	var k := clampf(wait / 0.35, 0.0, 1.0)
	# Glow underneath, getting keener.
	var keen := clampf(t / 3.0, 0.0, 1.0)
	ci.draw_circle(c, 300.0 + 30.0 * sin(t * 3.0), Color(tint, 0.12 + 0.12 * keen + 0.5 * k))
	if opening:
		for i in 14:
			var a := TAU * i / 14.0 + t
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 1600.0 * k, c + Vector2(cos(a + 0.12), sin(a + 0.12)) * 1600.0 * k]), Color(1, 1, 0.9, 0.35 * k))
	# The rattle: a jiggle every so often, more often as time goes by.
	var cyc := fmod(t, maxf(0.6, 1.4 - t * 0.15))
	var rattle := sin(cyc * 60.0) * clampf(1.0 - cyc / 0.35, 0.0, 1.0) * 0.09 * land
	var sw := 1.0 + 0.25 * k
	ci.draw_set_transform(c, rattle, Vector2(sw, sw / (1.0 + 0.1 * k)))
	var w := 360.0
	var h := 280.0
	DrawUtil.rrect(ci, Rect2(-w / 2.0 + 10, -h / 2.0 + 24, w, h), Color(0, 0, 0, 0.3), 30)
	DrawUtil.rrect(ci, Rect2(-w / 2.0, -h / 2.0, w, h), tint, 30)
	DrawUtil.rrect(ci, Rect2(-w / 2.0, -h / 2.0, w, h * 0.45), tint.lightened(0.12), 30)
	ci.draw_rect(Rect2(-28, -h / 2.0, 56, h), Color.WHITE)
	# The lid, off and flying when it opens.
	var lid_y := -h / 2.0 - 30.0 - 900.0 * k * k
	var lid_r := -0.6 * k
	ci.draw_set_transform(c + Vector2(0, lid_y).rotated(rattle) * sw, rattle + lid_r, Vector2(sw, sw))
	DrawUtil.rrect(ci, Rect2(-w / 2.0 - 22, -36, w + 44, 72), tint.lightened(0.22), 22)
	ci.draw_rect(Rect2(-28, -36, 56, 72), Color.WHITE)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(sx * 52.0, -58.0), 46.0, Color.WHITE)
		ci.draw_circle(Vector2(sx * 52.0, -58.0), 22.0, Color(tint, 0.35))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not opening and t > 0.5 and prompt != "":
		var f := UiTheme.font()
		var a := clampf((t - 0.5) / 0.3, 0.0, 1.0) * (0.75 + 0.25 * sin(t * 5.0))
		var txt := prompt
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
		ci.draw_string_outline(f, Vector2((v.x - tw) / 2.0, c.y + 300.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 14, Color(0.1, 0.07, 0.16, a))
		ci.draw_string(f, Vector2((v.x - tw) / 2.0, c.y + 300.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(1, 1, 1, a))
		var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
		ci.draw_string_outline(f, Vector2((v.x - hw) / 2.0, v.y * 0.15), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 18, Color(0.1, 0.07, 0.16, a))
		ci.draw_string(f, Vector2((v.x - hw) / 2.0, v.y * 0.15), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(Palette.STAR_GOLD, a))
