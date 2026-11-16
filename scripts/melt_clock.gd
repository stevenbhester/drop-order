class_name MeltClock
extends Control
## Before It Melts: the clock, big, in the middle of the top bar (where the level's name usually goes). An ice-cream cone
## melts as the time runs down, the seconds count in big digits, and a bar drains. In the last ten seconds
## it goes red, throbs, and ticks every second.

var game: Game
var _last := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	visible = game.state != Game.State.WON
	var left := game._melt_left()
	var s := int(ceil(left))
	if s != _last:
		if s <= 10 and s > 0 and _last > s and game.timing:
			Sfx.play("click", 1.4 if s <= 3 else 1.1, -4.0)
		_last = s
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var total := float(game.side.get("seconds", 60))
	var left := maxf(game._melt_left(), 0.0)
	var k := clampf(left / maxf(total, 1.0), 0.0, 1.0)
	var hurry := left < 10.0
	var t := Time.get_ticks_msec() / 1000.0
	var throb := 1.0 + (0.06 * absf(sin(t * PI * 2.0)) if hurry else 0.0)
	var h := size.y
	var w := minf(size.x, h * 3.2)
	var r := Rect2((size.x - w * throb) / 2.0, (h - h * throb) / 2.0, w * throb, h * throb)
	var bg := Palette.CRASH if hurry else Color("6cc6e8")
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 8), r.size), Color(0, 0, 0, 0.14), r.size.y / 2.0)
	DrawUtil.rrect(self, r, Color.WHITE, r.size.y / 2.0)
	# The bar draining along the bottom of the pill.
	var bar := Rect2(r.position.x + r.size.y * 0.5, r.end.y - r.size.y * 0.2, (r.size.x - r.size.y * 0.8), r.size.y * 0.1)
	DrawUtil.rrect(self, bar, Color(bg, 0.18), bar.size.y / 2.0)
	DrawUtil.rrect(self, Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), bg, bar.size.y / 2.0)
	# The cone, its scoop shrinking and dripping.
	var cx := r.position.x + r.size.y * 0.55
	var cy := r.position.y + r.size.y * 0.5
	var u := r.size.y / 150.0
	var cone := PackedVector2Array([Vector2(cx - 26 * u, cy - 4 * u), Vector2(cx + 26 * u, cy - 4 * u), Vector2(cx, cy + 50 * u)])
	draw_colored_polygon(cone, Color("e2a35a"))
	var sr := (14.0 + 18.0 * k) * u
	var scoop := Color("ffb3c7")
	draw_circle(Vector2(cx, cy - 4 * u - sr * 0.6), sr, scoop)
	draw_rect(Rect2(cx - 26 * u, cy - 10 * u, 52 * u, 10 * u), scoop)
	for i in 3:
		var dx := (i - 1) * 16.0 * u
		var drip := (6.0 + 22.0 * (1.0 - k)) * u * (0.6 + 0.4 * absf(sin(t * 1.3 + i)))
		draw_rect(Rect2(cx + dx - 4 * u, cy - 4 * u, 8 * u, drip), scoop)
		draw_circle(Vector2(cx + dx, cy - 4 * u + drip), 4 * u, scoop)
	# The time.
	var f := UiTheme.font()
	var sec := int(ceil(left))
	var txt := "%d:%02d" % [sec / 60, sec % 60]
	var px := int(r.size.y * 0.6)
	var tx := r.position.x + r.size.y * 1.05
	draw_string(f, Vector2(tx, cy + px * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 10.0, px, Palette.CRASH if hurry else Palette.TEXT)
