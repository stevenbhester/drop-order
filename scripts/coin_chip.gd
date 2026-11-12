class_name CoinChip
extends Control
## The wallet: Door Bowl Dollaroos (pretend money). The number rolls to its new value, and
## fly_from() sends a stream of coins into it, each one ticking the count up as it lands.

const H := 110.0
const W := 252.0
const ICON_AT := Vector2(50, 51)

var shown := 0.0
## While coins are in the air the number waits for them instead of jumping.
var frozen := false

var _bump := 0.0
var _roll: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown = Progress.dollaroos
	Progress.changed.connect(_sync)


func _sync() -> void:
	if frozen or int(shown) == Progress.dollaroos:
		return
	if _roll and _roll.is_valid():
		_roll.kill()
	_roll = create_tween()
	_roll.tween_method(_set_shown, shown, float(Progress.dollaroos), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bump = 1.0


func _set_shown(v: float) -> void:
	shown = v
	queue_redraw()


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 4.0)
		queue_redraw()


## Where coins should fly to, in this canvas layer's coordinates.
func target() -> Vector2:
	return global_position + ICON_AT


## `coins` coins fly from `from` (same canvas layer) into the chip, adding up to `amount` on the display.
func fly_from(from: Vector2, coins: int, amount: int) -> void:
	frozen = true
	var start := float(Progress.dollaroos - amount)
	shown = start
	queue_redraw()
	for i in coins:
		var c := Coin.new()
		c.top_level = true
		c.z_index = 100
		c.position = from
		add_child(c)
		var mid := from + Vector2(randf_range(-160.0, 160.0), randf_range(-60.0, 140.0))
		var tw := c.create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(c, "position", mid, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", target(), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_coin_landed.bind(c, i, coins, start, amount))


func _coin_landed(c: Node2D, i: int, coins: int, start: float, amount: int) -> void:
	c.queue_free()
	shown = start + amount * float(i + 1) / coins
	_bump = 1.0
	Sfx.play("coin", 1.0 + 0.05 * i, -8.0)
	Sfx.haptic(6)
	if i == coins - 1:
		frozen = false
		shown = Progress.dollaroos
	queue_redraw()


func _draw() -> void:
	var f := UiTheme.font()
	var r := Rect2(0, 0, size.x, H - 8.0)
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 8), r.size), Color(0.36, 0.29, 0.2, 0.16), 40)
	DrawUtil.rrect(self, r, Palette.SURFACE, 40)
	Icons.draw(self, "coin", ICON_AT, 62.0 * (1.0 + 0.22 * _bump), Color.WHITE)
	var n := int(round(shown))
	var txt := Progress.commas(n)
	var px := 44
	var room := size.x - 92.0 - 18.0
	while px > 24 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 2
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, Vector2(92.0 + (room - w) / 2.0, 51.0 + px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		Color("e5484d") if n < 0 else Palette.TEXT)


class Coin:
	extends Node2D

	func _draw() -> void:
		Icons.draw(self, "coin", Vector2.ZERO, 54.0, Color.WHITE)
