class_name StatsFlair
extends Control
## Dresses up a daily's Stats button (DailyScore, DailyScreen) without changing its size or place: a purple
## face, a little live bar chart where its icon goes (four bars in the package colours, rising when it
## appears and bobbing after), a shine that sweeps across it every few seconds, and, until today's stats
## have been opened (`seen_today`), a pulsing dot on its corner. `StatsFlair.dress(button)` does it all;
## `StatsFlair.mark_seen()` when the stats are opened.

const FACE := Color("7b5cff")
const BARS := ["red", "yellow", "green", "blue"]
const SEEN_KEY := "stats_day"

var button: JuicyButton
var _t := 0.0


static func dress(b: JuicyButton) -> void:
	b.recolor(FACE, Color.WHITE)
	b.icon_name = "blank"            # (keeps the icon's room: the chart's drawn there)
	var f := StatsFlair.new()
	f.button = b
	b.add_child(f)


static func seen_today() -> bool:
	return int(Progress.seen_new.get(SEEN_KEY, -1)) == Daily.today()


static func mark_seen() -> void:
	Progress.seen_new[SEEN_KEY] = Daily.today()
	Progress.set_option("seen_new", Progress.seen_new)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var b := button
	var f := UiTheme.font()
	var px := b.font_px
	# Where JuicyButton put its icon (the same sums as its _draw).
	var mid := size / 2.0 + Vector2(0, (2.0 if b.is_pressed() else -3.0) + b.label_dy)
	var isz := minf(size.y * 0.5, px * 1.3) * b.icon_scale
	var tw := f.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var gap := px * 0.26
	var x0 := mid.x - (isz + gap + tw) / 2.0
	# The chart: four bars on a baseline, growing in when it appears, then each bobbing on its own beat.
	var grow := 1.0 - pow(1.0 - clampf(_t / 0.6, 0.0, 1.0), 3.0)
	var base_y := mid.y + isz * 0.42
	var bw := isz * 0.2
	for i in BARS.size():
		var h := isz * (0.35 + 0.18 * i) * grow * (0.85 + 0.15 * sin(_t * 3.2 + i * 1.3))
		var r := Rect2(x0 + i * (bw + isz * 0.06), base_y - h, bw, h)
		DrawUtil.rrect(self, r, Palette.pkg(BARS[i]), bw * 0.3)
		DrawUtil.rrect(self, Rect2(r.position + Vector2(bw * 0.2, bw * 0.2), Vector2(bw * 0.25, maxf(0.0, h - bw * 0.4))), Color(1, 1, 1, 0.35), bw * 0.12)
	draw_line(Vector2(x0 - 2.0, base_y + 2.0), Vector2(x0 + isz + 2.0, base_y + 2.0), Color(1, 1, 1, 0.9), 3.0, true)
	# The shine: a slanted band of light across the face, every few seconds.
	var k := fmod(_t, 3.2) / 0.7
	if k < 1.0:
		var sx := lerpf(-size.x * 0.3, size.x * 1.3, k)
		var face_h := size.y - 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx, 4), Vector2(sx + 40.0, 4), Vector2(sx + 40.0 - face_h * 0.5, face_h), Vector2(sx - face_h * 0.5, face_h)]),
			Color(1, 1, 1, 0.22 * sin(PI * k)))
	# Not looked at today: a dot on the corner, pulsing.
	if not seen_today():
		var c := Vector2(size.x - 10.0, 8.0)
		var r2 := 13.0 * (1.0 + 0.15 * sin(_t * 6.0))
		draw_circle(c, r2 + 4.0, Color.WHITE)
		draw_circle(c, r2, Color("ff5a4e"))
