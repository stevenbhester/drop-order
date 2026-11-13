class_name FeedbackCard
extends CanvasLayer
## Feedback / Bug report (from the options): Bug or Idea, a box for what happened, "Include a screenshot"
## (ticked, with a little preview of what was on screen when the options were opened), and a big
## "Submit to Steven". Sending shows a little loading animation (a parcel hopping along to a mailbox)
## until the server says it's filed; then a thank-you with the report's id, or what went wrong and Try
## again (the message is kept). The card rises above the on-screen keyboard while typing.

signal closed

## What was on screen (taken before the options opened over it), and where the player was.
var shot: Image
var where := ""

enum Stage { WRITING, SENDING, SENT, FAILED }

var _stage := Stage.WRITING
var _root: Control
var _card: PanelContainer
var _kind := "bug"
var _kind_box: HBoxContainer
var _text: TextEdit
var _include: Tick
var _thumb: TextureRect
var _send: JuicyButton
var _status: Control
var _status_text := ""
var _report_id := ""
var _http: HTTPRequest
var _t := 0.0
var _rise := 0.0


func _ready() -> void:
	layer = 86
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.66)))
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(56)
	sb.set_content_margin_all(44)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(940.0, _root.get_viewport_rect().size.x - 60.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)

	var head := HBoxContainer.new()
	var title := _label("Tell Steven", 68, Palette.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := JuicyButton.new()
	x.icon_name = "x"
	x.custom_minimum_size = Vector2(104, 96)
	x.pressed.connect(_close)
	head.add_child(x)
	col.add_child(head)
	col.add_child(_label("Found a bug, or got an idea? It goes straight to Steven, with the game's recent log.", 32, Palette.TEXT_SOFT, true))

	_kind_box = HBoxContainer.new()
	_kind_box.add_theme_constant_override("separation", 14)
	col.add_child(_kind_box)
	_build_kinds()

	_text = TextEdit.new()
	_text.placeholder_text = "What happened? What were you doing just before?"
	_text.custom_minimum_size = Vector2(0, 300)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 38)
	_text.add_theme_color_override("font_color", Palette.TEXT)
	_text.add_theme_color_override("font_placeholder_color", Palette.TEXT_SOFT)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Palette.SURFACE
	tsb.set_corner_radius_all(28)
	tsb.set_content_margin_all(24)
	tsb.border_color = Color(Palette.TEXT, 0.15)
	tsb.set_border_width_all(3)
	_text.add_theme_stylebox_override("normal", tsb)
	var tsf := tsb.duplicate() as StyleBoxFlat
	tsf.border_color = Palette.ACCENT
	_text.add_theme_stylebox_override("focus", tsf)
	_text.text_changed.connect(_refresh_send)
	col.add_child(_text)

	var shot_row := HBoxContainer.new()
	shot_row.add_theme_constant_override("separation", 18)
	col.add_child(shot_row)
	_include = Tick.new()
	_include.text = "Include a screenshot"
	_include.on = shot != null
	_include.custom_minimum_size = Vector2(0, 110)
	_include.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_include.toggled.connect(func(on: bool): _thumb.modulate.a = 1.0 if on else 0.3)
	shot_row.add_child(_include)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(120, 200)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if shot:
		_thumb.texture = ImageTexture.create_from_image(shot)
	shot_row.add_child(_thumb)

	_status = Control.new()
	_status.custom_minimum_size = Vector2(0, 0)
	_status.draw.connect(_draw_status)
	col.add_child(_status)

	_send = JuicyButton.new()
	_send.label = "Submit to Steven"
	_send.icon_name = "next"
	_send.font_px = 50
	_send.bg = Palette.ACCENT
	_send.fg = Color.WHITE
	_send.custom_minimum_size = Vector2(0, 140)
	_send.pressed.connect(_submit)
	col.add_child(_send)
	_refresh_send()

	_http = HTTPRequest.new()
	_http.timeout = 30.0
	_http.request_completed.connect(_on_done)
	add_child(_http)

	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)
	_place()


func _label(t: String, px: int, c: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_kinds() -> void:
	for c in _kind_box.get_children():
		c.queue_free()
	for k in [["bug", "Something's broken"], ["feedback", "An idea / feedback"]]:
		var on: bool = _kind == k[0]
		var b := JuicyButton.new()
		b.label = k[1]
		b.font_px = 32
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.bg = Palette.ACCENT if on else Color(0, 0, 0, 0)
		b.fg = Color.WHITE if on else Color(0, 0, 0, 0)
		var value: String = k[0]
		b.pressed.connect(func():
			if _stage == Stage.SENDING:
				return
			_kind = value
			Sfx.play("click")
			_build_kinds())
		_kind_box.add_child(b)


func _refresh_send() -> void:
	if _send == null:
		return
	var ready_to := _text.text.strip_edges() != "" and _stage != Stage.SENDING
	_send.dim = not ready_to
	if _stage == Stage.WRITING or _stage == Stage.FAILED:
		_send.label = "Submit to Steven" if _stage == Stage.WRITING else "Try again"


## Centred, and up above the on-screen keyboard while it's open.
func _place() -> void:
	var v := _root.get_viewport_rect().size
	var kb := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var screen_h := float(DisplayServer.window_get_size().y)
		if screen_h > 0.0:
			kb = DisplayServer.virtual_keyboard_get_height() * v.y / screen_h
	_rise = lerpf(_rise, kb, 0.3)
	var sz := _card.get_combined_minimum_size()
	var y := (v.y - sz.y) / 2.0
	if _rise > 1.0:
		y = minf(y, v.y - _rise - sz.y - 20.0)
	_card.position = Vector2((v.x - sz.x) / 2.0, maxf(y, 20.0))
	_card.size = sz


func _process(delta: float) -> void:
	_t += delta
	_place()
	if _stage != Stage.WRITING:
		_status.queue_redraw()


func _submit() -> void:
	if _stage == Stage.SENDING:
		return
	if _stage == Stage.SENT:
		_close()
		return
	var msg := _text.text.strip_edges()
	if msg == "":
		Sfx.play("bonk", 1.1, -6.0)
		_text.grab_focus()
		return
	_text.release_focus()
	DisplayServer.virtual_keyboard_hide()
	var jpg := Feedback.screenshot_jpeg(shot) if _include.on and shot else PackedByteArray()
	var body := JSON.stringify(Feedback.payload(_kind, msg, where, jpg))
	print("[feedback] sending a %s report (%d bytes)" % [_kind, body.length()])
	var err := _http.request(Feedback.url(), PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	if err != OK:
		_fail("Couldn't start sending (%d). Check your connection and try again." % err)
		return
	_stage = Stage.SENDING
	_status_text = "Sending to Steven"
	_status.custom_minimum_size = Vector2(0, 170)
	_text.editable = false
	_send.dim = true
	_send.label = "Sending..."
	Sfx.play("whoosh", 1.0, -6.0)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var reply = JSON.parse_string(body.get_string_from_utf8())
	if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
		_stage = Stage.SENT
		_report_id = str(reply.get("id", "")) if reply is Dictionary else ""
		_status_text = "Got it! Steven has your report."
		_send.dim = false
		_send.label = "Done"
		_send.icon_name = "star"
		_send.bg = Palette.GOOD
		Sfx.play("kaching", 1.1, -3.0)
		Sfx.haptic(25)
		print("[feedback] sent (%s)" % _report_id)
		return
	var why := "Couldn't reach the server. Check your connection and try again."
	if result == HTTPRequest.RESULT_SUCCESS:
		why = str(reply.get("error", "The server said no (%d)." % code)) if reply is Dictionary else "The server said no (%d)." % code
	elif result == HTTPRequest.RESULT_TIMEOUT:
		why = "That took too long. Try again in a moment."
	_fail(why)


func _fail(why: String) -> void:
	_stage = Stage.FAILED
	_status_text = why
	_status.custom_minimum_size = Vector2(0, 120)
	_text.editable = true
	_refresh_send()
	Sfx.play("bonk", 0.9, -4.0)
	print("[feedback] not sent: %s" % why)


## The loading animation (a parcel hopping along to a mailbox), then the outcome.
func _draw_status() -> void:
	var w := _status.size.x
	var f := UiTheme.font()
	match _stage:
		Stage.SENDING:
			var y := 90.0
			var box := Vector2(w - 120.0, y)
			DrawUtil.rrect(_status, Rect2(box + Vector2(-40, -50), Vector2(80, 70)), Color("8f98aa"), 14)
			DrawUtil.rrect(_status, Rect2(box + Vector2(-26, -36), Vector2(52, 14)), Color("2b2233"), 6)
			_status.draw_line(box + Vector2(0, 20), box + Vector2(0, 60), Color("6b7385"), 8.0)
			var u := fmod(_t, 1.1) / 1.1
			var x := lerpf(80.0, w - 160.0, u)
			var hop := absf(sin(u * PI * 4.0)) * 46.0
			DrawUtil.parcel(_status, Vector2(x, y - hop), Vector2(70, 52), Palette.pkg(["red", "blue", "yellow", "green"][int(_t / 1.1) % 4]))
			var dots := ".".repeat(1 + int(_t * 3.0) % 3)
			_status.draw_string(f, Vector2(80, 158), _status_text + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.TEXT_SOFT)
		Stage.SENT:
			var c := Vector2(54, 54)
			_status.draw_circle(c, 40.0, Palette.GOOD)
			_status.draw_polyline(PackedVector2Array([c + Vector2(-18, 0), c + Vector2(-5, 13), c + Vector2(20, -13)]), Color.WHITE, 9.0, true)
			_status.draw_multiline_string(f, Vector2(116, 50), _status_text, HORIZONTAL_ALIGNMENT_LEFT, w - 120.0, 40, 2, Palette.TEXT)
			if _report_id != "":
				_status.draw_string(f, Vector2(116, 96), "Report %s" % _report_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.TEXT_SOFT)
		Stage.FAILED:
			_status.draw_multiline_string(f, Vector2(0, 40), _status_text, HORIZONTAL_ALIGNMENT_LEFT, w, 34, 3, Palette.CRASH)


func _close() -> void:
	if _stage == Stage.SENDING:
		return
	Sfx.play("click")
	DisplayServer.virtual_keyboard_hide()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


## A big tick box with its words beside it; the whole row is the button.
class Tick:
	extends Control
	signal toggled(on: bool)
	var text := ""
	var on := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			accept_event()
			on = not on
			Sfx.play("click", 1.1 if on else 0.9)
			Sfx.haptic(10, 0.5)
			toggled.emit(on)
			queue_redraw()

	func _draw() -> void:
		var s := 64.0
		var r := Rect2(Vector2(0, (size.y - s) / 2.0), Vector2(s, s))
		DrawUtil.rrect(self, r, Palette.GOOD if on else Palette.SURFACE, 16)
		if not on:
			draw_rect(r.grow(-3), Color(Palette.TEXT, 0.25), false, 4.0)
		else:
			var c := r.get_center()
			draw_polyline(PackedVector2Array([c + Vector2(-16, 0), c + Vector2(-5, 12), c + Vector2(18, -12)]), Color.WHITE, 8.0, true)
		draw_string(UiTheme.font(), Vector2(s + 22, size.y / 2.0 + 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Palette.TEXT)
