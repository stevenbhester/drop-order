class_name UnlockCard
extends Control
## "You found something!": pops over the level finish when a present was picked up. Sunburst, the item's
## kind as a slanted banner, a big turning van (or truck) wearing it on a pad, its name, where it's from,
## and two choices: "Wear it now" (puts it on there and then) or "Keep my look". Nothing is worn
## unless the player says so.

signal closed

var item := ""

var _t := 0.0
var _van: Van
var _fx: Fx
var _wear: JuicyButton
var _keep: Button
var _c := Vector2.ZERO
var _worn := false


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
	_van.paint = item if kind == "paint" else Progress.paint
	_van.topper = item if kind == "topper" else ""
	_van.ride = item if kind == "ride" else ""
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

	_wear = JuicyButton.new()
	_wear.font_px = 66
	_wear.bg = Palette.GOOD
	_wear.fg = Color.WHITE
	_wear.label = "Wear it now"
	_wear.icon_name = "paint"
	_wear.size = Vector2(640, 150)
	_wear.position = Vector2((v.x - 640) / 2.0, v.y * 0.76)
	_wear.pressed.connect(_on_wear)
	_wear.scale = Vector2.ZERO
	add_child(_wear)
	_keep = Button.new()
	_keep.text = "Keep my look"
	_keep.flat = true
	_keep.focus_mode = Control.FOCUS_NONE
	_keep.add_theme_font_size_override("font_size", 40)
	_keep.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_keep.size = Vector2(420, 80)
	_keep.position = Vector2((v.x - 420) / 2.0, v.y * 0.76 + 170)
	_keep.pressed.connect(_close)
	_keep.modulate.a = 0.0
	add_child(_keep)

	Sfx.play("jingle", 1.0, -3.0)
	Sfx.play("sparkle")
	Sfx.haptic(30)
	var tw := create_tween()
	tw.tween_property(_van, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_fx.burst(_van.position, Cosmetics.tint(item), 28, 900.0, 24.0)
		_fx.burst(_van.position, Palette.STAR_GOLD, 14, 700.0, 18.0))
	tw.tween_interval(0.15)
	tw.tween_callback(func():
		_wear.pivot_offset = _wear.size / 2.0
		var bt := _wear.create_tween()
		bt.tween_property(_wear, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_callback(_wear.breathe.bind(true)))
	tw.tween_property(_keep, "modulate:a", 1.0, 0.3)


func _on_wear() -> void:
	if _worn:
		return
	_worn = true
	Sfx.play("kaching", 1.1, -3.0)
	Sfx.haptic(25)
	Progress.put_on(item)
	_van.squash()
	_fx.burst(_van.position, Cosmetics.tint(item), 30, 1000.0, 26.0)
	_fx.say(_van.position + Vector2(0, -230), "Looking good!", Palette.GOOD, 72)
	_wear.breathe(false)
	_wear.label = "Wearing it!"
	_wear.icon_name = "star"
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(_close)


func _close() -> void:
	Sfx.play("click")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	_van.rotation = sin(_t * 0.8) * 0.35 - 0.25
	_van.target_rotation = _van.rotation
	queue_redraw()


func _draw() -> void:
	var v := size
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.14, 0.86))
	var tint := Cosmetics.tint(item)
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
	var from: String = Cosmetics.ITEMS.get(item, {}).get("from", "")
	var sub := ("from " + from) if from != "" else ("unlocked with %d stars" % Cosmetics.stars_for(item) if Cosmetics.by_stars(item) and Cosmetics.stars_for(item) > 0 else ("won from %s" % Boss.NAME if Cosmetics.stars_for(item) < 0 else "found on the road"))
	sub += "  ·  yours to keep"
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	draw_string(f, Vector2((v.x - sw) / 2.0, ny + 66), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, 0.7))
