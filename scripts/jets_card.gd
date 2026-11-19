class_name JetsCard
extends CanvasLayer
## "JUMP JETS!": what they are, the once, when their present on the ribbon is opened (tapped, from job
## Progress.JETS_FROM on; or opened for them later: Game._reveal_jets). A little picture (the van arcing over a job), what they do in two
## lines, where they live, and what they won't do. `closed` when it's put away.

signal closed

var _root: Control
var _card: PanelContainer
var _pic: Control
var _t := 0.0
var _done := false
## Won with a job (beating job 11: FinishScreen.jets_new): they're a prize, not a present opened.
var won := false


func _ready() -> void:
	layer = 84
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.7)))
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(56)
	sb.set_content_margin_all(46)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(900.0, _root.get_viewport_rect().size.x - 60.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)
	col.add_child(_label("YOU BEAT HIM TWICE! DISPATCH SENT YOU" if won else "DISPATCH SENT HELP YOUR WAY!", 32, Palette.ACCENT))
	col.add_child(_label("JUMP JETS!", 76, Palette.TEXT))
	_pic = Control.new()
	_pic.custom_minimum_size = Vector2(0, 300)
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.draw.connect(_draw_pic)
	col.add_child(_pic)
	col.add_child(_label("Stuck? Jump over the job. It's free.", 44, Palette.TEXT))
	col.add_child(_label("It waits on the map. Come back and deliver it whenever you like.", 34, Palette.TEXT_SOFT))
	col.add_child(_label("Pull out the ribbon at the top left and hold Jump jets. Up to 3 jobs can wait at once. One thing they can't jump: the Baron's jobs. He has to be beaten.", 28, Palette.TEXT_SOFT))
	var ok := JuicyButton.new()
	ok.label = "Got it"
	ok.font_px = 48
	ok.bg = GasChip.FUEL
	ok.fg = Color.WHITE
	ok.custom_minimum_size = Vector2(0, 130)
	ok.pressed.connect(_finish)
	col.add_child(ok)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.18)
	Sfx.play("sparkle", 1.0, -4.0)
	Sfx.play("whoosh", 0.8, -6.0)


func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _process(delta: float) -> void:
	_t += delta
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.position = (v - sz) / 2.0
	_card.size = sz
	_pic.queue_redraw()


## Three job tickets in a row; a little van arcs from the first over the second (the stuck one, in grey,
## with a question mark) and lands by the third, again and again, on a puff of fuel.
func _draw_pic() -> void:
	var s := _pic.size
	var y := s.y * 0.72
	var xs := [s.x * 0.2, s.x * 0.5, s.x * 0.8]
	var f := UiTheme.font()
	for i in 3:
		var c := Vector2(xs[i], y)
		var col: Color = [Palette.GOOD, Color("b9b2a4"), Palette.ACCENT][i]
		DrawUtil.rrect(_pic, Rect2(c + Vector2(-58, -40), Vector2(116, 84)), Color(0, 0, 0, 0.15), 10)
		DrawUtil.rrect(_pic, Rect2(c + Vector2(-62, -46), Vector2(116, 84)), Color.WHITE, 10)
		DrawUtil.rrect(_pic, Rect2(c + Vector2(-62, -46), Vector2(116, 22)), col, 8)
		var mark: String = ["", "?", ""][i]
		if i == 0:
			_pic.draw_polyline(PackedVector2Array([c + Vector2(-22, 2), c + Vector2(-8, 16), c + Vector2(18, -10)]), Palette.GOOD, 9.0, true)
		elif mark != "":
			_pic.draw_string(f, c + Vector2(-14, 26), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color("8c867a"))
		else:
			Icons.draw(_pic, "play", c + Vector2(-4, 4), 40.0, Palette.ACCENT)
	var k := fmod(_t / 1.6, 1.0)
	var u := clampf(k / 0.7, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var p := Vector2(lerpf(xs[0], xs[2], e), y - 70.0 - sin(PI * e) * 150.0)
	# The arc it takes, dotted.
	for d in 14:
		var q := d / 13.0
		_pic.draw_circle(Vector2(lerpf(xs[0], xs[2], q), y - 70.0 - sin(PI * q) * 150.0), 5.0, Color(GasChip.FUEL, 0.3))
	if u < 1.0:
		for j in 4:
			_pic.draw_circle(p + Vector2(-26.0 - j * 14.0, 12.0 + j * 6.0), 12.0 - j * 2.5, Color(GasChip.FUEL, 0.5 - j * 0.1))
	DrawUtil.rrect(_pic, Rect2(p + Vector2(-34, -22), Vector2(68, 44)), Color("fffaf2"), 12)
	DrawUtil.rrect(_pic, Rect2(p + Vector2(4, -16), Vector2(22, 32)), Color("3b4a6b"), 6)
	DrawUtil.rrect(_pic, Rect2(p + Vector2(-34, -22), Vector2(68, 44)).grow(2.0), Color(0, 0, 0, 0.0), 12)


func _finish() -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())
