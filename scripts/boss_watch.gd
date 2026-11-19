class_name BossWatch
extends Control
## A boss job, said all the while it's played (not just on the way in): so it's plain why the jump jets are
## taped off and why this one's harder.
##   - the job's name in the top bar sits on a black-and-gold plate, and reads "BOSS FIGHT · Job 11"
##   - the Baron stands in the top right corner, under the options button, watching: smug; laughing for a few
##     seconds each time the van gets stuck or cuts a stop off; sweating once there's only one package left
##   - the board wears a black-and-gold frame, and the screen takes a faint Hoardly-purple cast
## It only draws: taps go straight through. Game adds it on the main road's boss jobs and boss detours.

const INK := Color("2b1f3d")
const LAUGH_FOR := 3.0

var game: Game

var _t := 0.0
var _laugh_until := -1.0
var _was_stuck := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if game.side.is_empty():
		game.level_label.text = "BOSS FIGHT · " + game.level_label.text
	game.level_label.add_theme_color_override("font_color", INK)


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(game):
		return
	visible = game.state != Game.State.WON
	# Stuck, or a stop cut off: he enjoys that.
	var stuck := game.state == Game.State.FAILED or (game.state == Game.State.IDLE and game._stranded)
	if stuck and not _was_stuck:
		_laugh_until = _t + LAUGH_FOR
		Sfx.play("laugh", 1.1, -8.0)
	_was_stuck = stuck
	queue_redraw()


func _mood() -> String:
	if _t < _laugh_until:
		return "laugh"
	if game.route.size() > 1 and Sim.remaining(game.level, game.sim_state) <= 1:
		return "panic"
	return "smug"


func _draw() -> void:
	if not is_instance_valid(game) or game.board == null:
		return
	var v := get_viewport_rect().size
	# A faint cast over everything: his colours.
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.2, 0.12, 0.3, 0.1))
	# The board's frame: gold on black.
	var xf := game.board.get_global_transform_with_canvas()
	var br: Rect2 = xf * Rect2(Vector2.ZERO, game.board.size_px())
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	_frame(br.grow(16.0), INK, 14.0)
	_frame(br.grow(13.0), Color(Boss.GOLD, 0.75 + 0.25 * pulse), 6.0)
	# The plate behind the job's name.
	var lr := game.level_label.get_global_rect()
	var f := UiTheme.font()
	var tw := f.get_string_size(game.level_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	var plate := Rect2(lr.get_center().x - tw / 2.0 - 30.0, lr.position.y - 2.0, tw + 60.0, lr.size.y + 6.0)
	DrawUtil.rrect(self, Rect2(plate.position + Vector2(0, 7), plate.size), Color(0, 0, 0, 0.25), 22)
	DrawUtil.rrect(self, plate.grow(6.0), INK, 26)
	DrawUtil.rrect(self, plate, Boss.GOLD, 22)
	# Him, under the options button.
	var top := game.exit_ribbon.position.y if game.exit_ribbon else 40.0
	var feet := Vector2(v.x - 96.0, top + 110.0 + 200.0)
	var h := 178.0
	# Never on the chute's mouth (the next package, and its NEXT tag): on a tall map the chute rides up under
	# him, so he stands on top of it instead, smaller if that's tight.
	var sv: StackView = game.stack_view
	if sv and sv.is_visible_in_tree():
		var sx := sv.get_global_transform_with_canvas()
		var m := sv._item_size() * sv._ns()
		var mouth_top := (sx * Vector2(0, -(m.y / 2.0 + sv.ph * 0.75))).y
		var mouth_left := (sx * Vector2(-(m.x / 2.0 + sv.ph * 0.2), 0)).x
		if mouth_left < feet.x + 60.0 and feet.y > mouth_top - 6.0:
			feet.y = mouth_top - 6.0
			h = clampf(feet.y - (top + 96.0), 96.0, 178.0)
	var k := h / 178.0
	DrawUtil.rrect(self, Rect2(feet + Vector2(-58, -8) * k, Vector2(116, 18) * k), Color(0, 0, 0, 0.14), 9 * k)
	Boss.draw(self, feet, h, _t, _mood())


func _frame(r: Rect2, col: Color, w: float) -> void:
	var rad := 44.0
	var pts := PackedVector2Array()
	for corner in [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), -PI / 2.0],
			[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0]]:
		for s in 9:
			var a: float = float(corner[1]) + s / 8.0 * PI / 2.0
			pts.append((corner[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	draw_polyline(pts, col, w, true)
