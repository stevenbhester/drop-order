class_name DispatchBox
extends Control
## Dispatch on the radio: a dark little radio panel with an electric, jagged edge that crackles, scan lines,
## a LIVE light and signal bars along its top, and a zigzag tail down to what it's about. Its words (BBCode:
## the helpers' names in their own colours) type in over a burst of static.
##
## Two ways it's used:
##  - `modal`: Dispatch has something to say (job 6: what Hint and Call are for). It takes the taps; one after
##    it's had a moment to be read puts it away. `glow` buttons get a pulsing ring in their own colour, and a
##    hop now and then.
##  - a call's answer (`calling`): first "CALLING DISPATCH..." with a wobbly signal running across it, then the
##    answer (`good`: green, else red). Not modal: taps go on through, and any of them (or `life` seconds)
##    sends it away.
## `gone` when it's gone.

signal gone

const BG := Color("1d2433")
const EDGE := Color("7fe3ff")
const CALL_BLUE := Color("5ab8ff")
const RED := Color("ff5a4e")
const GREEN := Color("4fe08a")
const CALL_SECS := 0.85           # how long the call takes to get through

var text := ""                    # BBCode
var title := "DISPATCH"
## What its tail points at (screen space); an empty Rect2: no tail.
var target := Rect2()
## ...and it sits over that (else under it).
var above := true
var modal := false
var calling := false
var good := true
var life := 0.0                   # seconds it stays up by itself (0: until tapped)
var width := 860.0
var glow: Array = []              # [[Control, Color]]
## A line under the words, small ("tap to go on").
var foot := ""

var _t := 0.0
var _label: RichTextLabel
var _box := Rect2()
var _closing := false
var _close_t := 0.0
var _said := false                # the answer's in (or there's no call to wait for)
var _jit: Array = []              # the edge's teeth: a little offset each, re-rolled now and then
var _jit_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP if modal else Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", UiTheme.font())
	_label.add_theme_font_override("bold_font", UiTheme.font())
	_label.add_theme_font_size_override("normal_font_size", 38 if modal else 36)
	_label.add_theme_font_size_override("bold_font_size", 38 if modal else 36)
	_label.add_theme_color_override("default_color", Color("eef6ff"))
	_label.add_theme_constant_override("line_separation", 6)
	add_child(_label)
	_said = not calling
	_label.text = text if not calling else "[color=#9fb4cc]Calling Dispatch...[/color]"
	_label.visible_ratio = 0.0
	_place()
	Sfx.play("radio", 1.0, -4.0)
	Sfx.haptic(8, 0.4)
	_reroll()


func _reroll() -> void:
	_jit = []
	for i in 160:
		_jit.append(randf_range(-1.0, 1.0))


func _place() -> void:
	var v := get_viewport_rect().size
	var w := minf(width, v.x - 48.0)
	_label.custom_minimum_size = Vector2(w - 76.0, 0)
	_label.size = Vector2(w - 76.0, 0)
	var th: float = float(_label.get_content_height()) if _label.get_content_height() > 0 else 50.0
	var h := 74.0 + th + 40.0 + (36.0 if foot != "" else 0.0)
	var x: float = clampf((target.get_center().x - w / 2.0) if target.size != Vector2.ZERO else (v.x - w) / 2.0, 24.0, v.x - 24.0 - w)
	var y: float = v.y * 0.4 - h / 2.0
	if target.size != Vector2.ZERO:
		y = target.position.y - 52.0 - h if above else target.end.y + 52.0
	y = clampf(y, 40.0, v.y - h - 30.0)
	_box = Rect2(x, y, w, h)
	_label.position = _box.position + Vector2(38, 70)


## Puts it away now (a move made, the job left...).
func close() -> void:
	if _closing:
		return
	_closing = true
	_close_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("radio", 0.75, -12.0)


func _gui_input(e: InputEvent) -> void:
	if modal and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _t > 0.9:
			close()
		else:
			_label.visible_ratio = 1.0          # (a tap hurries the words in)


func _input(e: InputEvent) -> void:
	# A call's answer: any tap or drag anywhere sends it on (the tap still goes through to the game).
	if modal or _closing or not _said or _t < CALL_SECS + 0.35:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		close()


func _process(delta: float) -> void:
	_t += delta
	_jit_t += delta
	if _jit_t > 0.07:
		_jit_t = 0.0
		# The edge crackles: some of its teeth twitch.
		for k in 18:
			_jit[randi() % _jit.size()] = randf_range(-1.0, 1.0)
	if calling and not _said and _t >= CALL_SECS:
		_said = true
		_label.text = text
		_label.visible_ratio = 0.0
		_place()
		Sfx.play("radio", 1.25 if good else 0.85, -5.0)
		Sfx.haptic(12 if good else 25)
	var since := _t - (CALL_SECS if calling else 0.0)
	if _said:
		_label.visible_ratio = minf(1.0, maxf(_label.visible_ratio, since / 0.55))
	if life > 0.0 and _said and since > life:
		close()
	if _closing:
		_close_t += delta
		modulate.a = 1.0 - clampf(_close_t / 0.18, 0.0, 1.0)
		if _close_t >= 0.2:
			gone.emit()
			queue_free()
			return
	else:
		modulate.a = clampf(_t / 0.12, 0.0, 1.0)
	_place()
	queue_redraw()


## The edge: along each side of `r`, little teeth in and out (electric), twitching.
func _jagged(r: Rect2, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var j := 0
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var n := maxi(4, int(a.distance_to(b) / 34.0))
		var out := (b - a).orthogonal().normalized() * -1.0
		for i in n:
			var p := a.lerp(b, float(i) / n)
			var k := 0.0 if i == 0 else float(_jit[j % _jit.size()]) * amp
			pts.append(p + out * k)
			j += 1
	return pts


func _draw() -> void:
	var f := UiTheme.font()
	var r := _box
	var tint := EDGE
	if _said and calling:
		tint = GREEN if good else RED
	var flick := 0.75 + 0.25 * sin(_t * 31.0) * sin(_t * 7.0)
	# The helpers it's about: a ring each, pulsing in its own colour.
	for g in glow:
		var c: Control = g[0]
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var gr: Rect2 = c.get_global_rect().grow(10.0 + 6.0 * (0.5 + 0.5 * sin(_t * 5.0)))
		var gc: Color = g[1]
		DrawUtil.rrect(self, gr.grow(6.0), Color(gc, 0.18), 34.0)
		draw_polyline(_round_rect_pts(gr, 30.0), gc, 7.0, true)
		# ...and a little arrow over it, bobbing.
		var tip := Vector2(gr.get_center().x, gr.position.y - 14.0 - 10.0 * absf(sin(_t * 4.0)))
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, -28), tip + Vector2(20, -28)]), gc)
	# The tail: a zigzag down (or up) to what it's about.
	if target.size != Vector2.ZERO:
		var from := Vector2(clampf(target.get_center().x, r.position.x + 60.0, r.end.x - 60.0), r.end.y if above else r.position.y)
		var to := Vector2(target.get_center().x, target.position.y - 8.0 if above else target.end.y + 8.0)
		var zig := PackedVector2Array([from + Vector2(-20, 0), from.lerp(to, 0.45) + Vector2(14, 0), from.lerp(to, 0.4) + Vector2(-6, 0), to,
			from.lerp(to, 0.55) + Vector2(10, 0), from.lerp(to, 0.6) + Vector2(-12, 0), from + Vector2(22, 0)])
		draw_colored_polygon(zig, BG)
		draw_polyline(PackedVector2Array([from + Vector2(-20, 0), from.lerp(to, 0.45) + Vector2(14, 0), from.lerp(to, 0.4) + Vector2(-6, 0), to]), Color(tint, flick), 4.0, true)
	# The panel.
	var shadow := _jagged(Rect2(r.position + Vector2(0, 12), r.size), 3.0)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
	var body := _jagged(r, 4.5)
	draw_colored_polygon(body, BG)
	# Scan lines, drifting.
	var off := fmod(_t * 40.0, 8.0)
	var y := r.position.y + 6.0 + off
	while y < r.end.y - 4.0:
		draw_line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), Color(1, 1, 1, 0.035), 2.0)
		y += 8.0
	var edge := body.duplicate()
	edge.append(body[0])
	draw_polyline(edge, Color(tint, flick), 4.0, true)
	draw_polyline(edge, Color(tint, 0.25 * flick), 11.0, true)
	# The top: a radio, DISPATCH, the LIVE light, signal bars.
	var head_y := r.position.y + 40.0
	Icons.draw(self, "radio", Vector2(r.position.x + 52.0, head_y), 46.0, tint)
	var head := title if (_said or not calling) else "CALLING..."
	draw_string(f, Vector2(r.position.x + 86.0, head_y + 12.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, tint)
	var live_on := fmod(_t, 1.0) < 0.6
	var lx := r.end.x - 150.0
	draw_circle(Vector2(lx, head_y), 9.0, Color(RED, 1.0 if live_on else 0.3))
	draw_string(f, Vector2(lx + 16.0, head_y + 10.0), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))
	for i in 4:
		var on := (_said and not calling) or (calling and _said) or int(_t * 8.0) % 5 > i
		var bh := 8.0 + i * 6.0
		draw_rect(Rect2(r.end.x - 60.0 + i * 11.0, head_y + 12.0 - bh, 7.0, bh), Color(tint, 0.9 if on else 0.2))
	draw_line(Vector2(r.position.x + 24.0, r.position.y + 64.0), Vector2(r.end.x - 24.0, r.position.y + 64.0), Color(tint, 0.25), 2.0)
	# Calling: a wobbly signal running across, over the "Calling Dispatch..." line.
	if calling and not _said:
		var pts := PackedVector2Array()
		var mid_y := r.position.y + r.size.y * 0.5 + 34.0
		for i in 61:
			var u := float(i) / 60.0
			var x := lerpf(r.position.x + 40.0, r.end.x - 40.0, u)
			var a := sin(u * 30.0 - _t * 22.0) * 16.0 * sin(u * PI) + randf_range(-4.0, 4.0)
			pts.append(Vector2(x, mid_y + a))
		draw_polyline(pts, Color(EDGE, 0.9), 4.0, true)
	if foot != "" and _t > 0.9:
		var fw := f.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(f, Vector2(r.get_center().x - fw / 2.0, r.end.y - 22.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(1, 1, 1, 0.45 + 0.25 * sin(_t * 4.0)))


func _round_rect_pts(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var cs := [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for c in cs:
		for i in 7:
			var a: float = c[1] + PI / 2.0 * i / 6.0
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	return pts
