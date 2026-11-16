class_name RushSplash
extends Control
## A rush just started (Progress.rush_start): "UNDO RUSH!" on a gold band slapped across the screen, the time
## under it, there for a second and a half and gone. It takes no taps: play goes on underneath.

const LIFE := 1.7

var kind := "undos"
var secs := 120.0

var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var v := size
	var f := UiTheme.font()
	var inn := clampf(_t / 0.22, 0.0, 1.0)
	var out := clampf((LIFE - _t) / 0.3, 0.0, 1.0)
	var a := out
	# In with a bounce, a little over-size at first.
	var k := 1.0 + 0.9 * pow(1.0 - inn, 2.0) + 0.04 * sin(_t * 9.0) * out
	var c := Vector2(v.x / 2.0, v.y * 0.4)
	draw_set_transform(c, deg_to_rad(-5.0), Vector2(k, k))
	var bw := v.x * 1.3
	draw_rect(Rect2(-bw / 2.0, -96.0 + 14.0, bw, 192.0), Color(0, 0, 0, 0.22 * a))
	draw_rect(Rect2(-bw / 2.0, -96.0, bw, 192.0), Color(RushRing.GOLD, a))
	draw_rect(Rect2(-bw / 2.0, -96.0, bw, 12.0), Color(1, 1, 1, 0.35 * a))
	draw_rect(Rect2(-bw / 2.0, 84.0, bw, 12.0), Color(0, 0, 0, 0.14 * a))
	var head := "%s!" % str(Progress.RUSH_NAME.get(kind, "Rush")).to_upper()
	var px := 132
	var w := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var wx := 150.0
	var x0 := -(w + wx) / 2.0
	RushRing.draw_watch(self, Vector2(x0 + 52.0, 4.0), 54.0, Color(RushRing.GOLD.lightened(0.3), a), Color(0.1, 0.07, 0.16, a), _t * 9.0)
	draw_string_outline(f, Vector2(x0 + wx, 46.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 20, Color(0.1, 0.07, 0.16, a))
	draw_string(f, Vector2(x0 + wx, 46.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, a))
	var sub := "%s of free %s. Go!" % [Progress.clock(secs), kind]
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
	draw_string_outline(f, Vector2(-sw / 2.0, 176.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 58, 14, Color(0.1, 0.07, 0.16, a))
	draw_string(f, Vector2(-sw / 2.0, 176.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 58, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
