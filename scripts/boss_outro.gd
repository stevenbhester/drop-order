class_name BossOutro
extends CanvasLayer
## A boss beaten: Baron Von Bottomline pops up in a panic, bursts into tears ("This is a coordinated attack
## on ME!"), and runs for it bawling, WAAAH trailing behind him. With nothing to hand over he drops his money bag, which bursts in a shower of gold, and it's over
## in TIME seconds. With `rewards` ([{kind: "lights" | "undos" | "item", value}], one per prize) he drops a
## wrapped package for each as he runs; then BOSS REWARD goes up and the packages wait. A tap anywhere opens
## them: the one tapped first (the leftmost, for a tap anywhere else), then the rest in turn, each on its own
## page (RewardPager). A tap before they've landed skips his exit. Once they're all open it fades and says
## `done`.

signal done

const TIME := 2.6
const DROP_EVERY := 0.22

var rewards: Array = []
var _opened: Array = []           # per package: true once it's been shown
var _busy := false                # a reward's card is up
var _bob := []

var _root: Control
var _t := 0.0
var line := ""                   # what he yells (any defeat line if empty)
var _line := ""
var _dropped := false
var _ran := false
## When he turns and runs, and when it's over. He stands there bawling till his line's been read (a tester
## often couldn't finish it before he was gone): the run, the drops and the end all wait that long.
var _run := 1.3
var _end := TIME
var _stand_x := 0.0              # where he stood (his bubble stays there as he runs)


func _ready() -> void:
	add_to_group(Music.HUSH_GROUP)      # (the background music waits while this is up)
	layer = 65
	_line = line if line != "" else Boss.defeat()
	# Reading time: about a third of a second a word, and a beat. The bubble's up from 0.15 to the run + 0.6.
	var words := _line.split(" ", false).size()
	var hold := clampf(0.9 + 0.32 * words - (1.3 + 0.6 - 0.15), 0.0, 3.5)
	_run += hold
	_end += hold
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if not rewards.is_empty() else Control.MOUSE_FILTER_IGNORE
	_root.gui_input.connect(_on_input)
	for r in rewards:
		_opened.append(false)
	_root.draw.connect(_draw_it)
	add_child(_root)
	Sfx.play("bonk", 0.7, -2.0)
	get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play("fail", 0.7, -4.0))


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if not _dropped and _t >= 1.05:
		_dropped = true
		Sfx.play("kaching", 0.9, -2.0)
		Sfx.play("thunk", 0.8, -4.0)
		Sfx.haptic(30, 0.8, "boss_outro:_process")
	if not _ran and _t >= _run:
		_ran = true
		Sfx.play("whoosh", 0.7, -4.0)
		Sfx.play("screech", 1.6, -12.0)
	# The packages land, one at a time, as he runs.
	for i in rewards.size():
		var at := _run + i * DROP_EVERY + 0.28
		if before < at and _t >= at:
			Sfx.play("thunk", 1.1 + 0.1 * i, -4.0)
			Sfx.haptic(14, 1.0, "boss_outro:_process")
	if rewards.is_empty():
		if before < _end - 0.25 and _t >= _end - 0.25:
			create_tween().tween_property(_root, "modulate:a", 0.0, 0.25)
		if _t >= _end:
			done.emit()
			queue_free()
	elif before < _end and _t >= _end:
		Sfx.play("sparkle", 1.0, -4.0)
	# (Self-tests open them on their own.)
	if Progress.auto and not rewards.is_empty() and _t >= _end + 0.3 and not _busy:
		var next := _opened.find(false)
		if next >= 0:
			_open(next)
	_root.queue_redraw()


## Where package `i` lands: in a row across the floor, centred.
func _package_at(i: int) -> Vector2:
	var v := _root.size
	var ins := UiTheme.insets(_root.get_viewport())
	var floor_y := v.y - 260.0 - ins.y
	var gap := minf(260.0, (v.x - 160.0) / maxf(1.0, rewards.size()))
	return Vector2(v.x / 2.0 + (i - (rewards.size() - 1) / 2.0) * gap, floor_y - 40.0)


func _on_input(e: InputEvent) -> void:
	var press: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if not press or _busy or rewards.is_empty():
		return
	_root.accept_event()
	if _t < _end:
		# Still running off: skip to the packages, landed and waiting.
		_t = _end
		_dropped = true
		_ran = true
		Sfx.play("sparkle", 1.0, -4.0)
		return
	# The package tapped, or (a tap anywhere else) the leftmost.
	var first := _opened.find(false)
	for i in rewards.size():
		if not _opened[i] and e.position.distance_to(_package_at(i)) < 110.0:
			first = i
			break
	if first >= 0:
		_open(first)


## Opens them all, one after another on their own pages (RewardPager), starting with package `i`.
func _open(i: int) -> void:
	_busy = true
	Sfx.play("pop", 1.0, -2.0)
	Sfx.haptic(20, 1.0, "boss_outro:_open")
	var order := [rewards[i]]
	for k in rewards.size():
		if k != i and not _opened[k]:
			order.append(rewards[k])
	var pager := RewardPager.new()
	pager.rewards = order
	add_child(pager)
	# (Behind the pages, the boxes are opened.)
	get_tree().create_timer(0.3).timeout.connect(func(): _opened.fill(true))
	pager.finished.connect(func():
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			done.emit()
			queue_free()))


## A cardboard delivery box tied with a ribbon in the prize's colour (and a bow); opened, the flaps are up
## and it's empty.
func _reward_box(c: Vector2, s: float, ribbon: Color, opened: bool) -> void:
	var card := Color("c8955a")
	var r := Rect2(c + Vector2(-s / 2.0, -s * 0.36), Vector2(s, s * 0.72))
	DrawUtil.rrect(_root, Rect2(r.position + Vector2(0, s * 0.07), r.size), Color(0, 0, 0, 0.3), s * 0.08)
	DrawUtil.rrect(_root, r, card, s * 0.08)
	DrawUtil.rrect(_root, Rect2(r.position, Vector2(s, s * 0.2)), card.lightened(0.12), s * 0.08)
	if opened:
		# Flaps open, nothing inside.
		DrawUtil.rrect(_root, Rect2(r.position + Vector2(s * 0.08, s * 0.04), Vector2(s * 0.84, s * 0.16)), Color("3a2418"), s * 0.04)
		for sd: float in [-1.0, 1.0]:
			var a := c + Vector2(sd * s * 0.5, -s * 0.36)
			_root.draw_colored_polygon(PackedVector2Array([a, a + Vector2(sd * s * 0.22, -s * 0.2), a + Vector2(-sd * s * 0.12, -s * 0.24), a + Vector2(-sd * s * 0.32, 0)]), card.lightened(0.05))
		return
	# The ribbon, both ways, and a bow on top.
	_root.draw_rect(Rect2(c.x - s * 0.08, r.position.y, s * 0.16, r.size.y), ribbon)
	_root.draw_rect(Rect2(r.position.x, c.y - s * 0.06, r.size.x, s * 0.12), ribbon)
	for sx: float in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			loop.append(Vector2(c.x, r.position.y) + Vector2(sx * s * 0.17, -s * 0.07) + Vector2(cos(a) * s * 0.16, sin(a) * s * 0.1).rotated(sx * 0.35))
		_root.draw_colored_polygon(loop, ribbon.darkened(0.08))
	_root.draw_circle(Vector2(c.x, r.position.y - s * 0.02), s * 0.07, ribbon.lightened(0.15))


func _reward_color(r: Dictionary) -> Color:
	match str(r.get("kind", "")):
		"lights":
			return Color("ffc53d")
		"undos":
			return Color("4d8dff")
	return Cosmetics.tint(str(r.get("value", "")))


func _draw_it() -> void:
	var v := _root.size
	var ins := UiTheme.insets(_root.get_viewport())
	var tall := 380.0
	var floor_y := v.y - 260.0 - ins.y
	# (Darker once his packages are waiting: it's their moment.)
	var dark := 0.35 + (0.5 * clampf((_t - _end + 0.4) / 0.4, 0.0, 1.0) if not rewards.is_empty() else 0.0)
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.06, 0.04, 0.12, dark * clampf(_t / 0.2, 0.0, 1.0)))
	# In from the right, panicking; off to the left at a sprint after the drop.
	var x := v.x * 0.62
	if _t < 0.3:
		x = lerpf(v.x + 240.0, v.x * 0.62, 1.0 - pow(1.0 - _t / 0.3, 3.0))
	elif _t > _run:
		var u := (_t - _run) / 0.9
		x = lerpf(v.x * 0.62, -320.0, u * u)
	var feet := Vector2(x, floor_y + (absf(sin(_t * 20.0)) * -18.0 if _t > _run else 0.0))
	Boss.draw(_root, feet, tall, _t, "panic" if _t < 0.45 else "cry", -1.0 if _t > _run else 1.0)
	# Bawling: WAAAH, popping off him.
	if _t > 0.45:
		var f := UiTheme.font()
		for k in 3:
			var a := fmod(_t - 0.45 + k * 0.33, 1.0)
			var at := Vector2(feet.x + (k - 1) * 120.0 + (60.0 if _t > _run else -60.0) * a, feet.y - tall * 1.15 - a * 120.0)
			var w := f.get_string_size("WAAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x
			_root.draw_set_transform(at, (k - 1) * 0.25, Vector2.ONE * (0.7 + 0.5 * a))
			_root.draw_string_outline(f, Vector2(-w / 2.0, 0), "WAAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 50, 10, Color(0.1, 0.06, 0.16, 1.0 - a))
			_root.draw_string(f, Vector2(-w / 2.0, 0), "WAAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color(0.6, 0.85, 1.0, 1.0 - a))
			_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Dust kicked up as he runs.
	if _t > _run:
		for k in 6:
			var a := fmod(_t * 3.0 + k / 6.0, 1.0)
			var p := Vector2(x + 60.0 + a * 160.0, floor_y - 10.0 - a * 30.0)
			_root.draw_circle(p, 20.0 + 30.0 * a, Color(0.85, 0.8, 0.72, 0.5 * (1.0 - a)))
	# The packages he drops as he runs (one per prize), or (nothing to give) the money bag, bursting.
	for i in rewards.size():
		var t0 := _run + i * DROP_EVERY
		if _t < t0:
			continue
		var land := _package_at(i)
		var u := clampf((_t - t0) / 0.28, 0.0, 1.0)
		var from := Vector2(lerpf(v.x * 0.62, -320.0, pow((t0 - _run) / 0.9, 2.0)), floor_y - tall * 0.55)
		var p := from.lerp(land, u) + Vector2(0, -160.0 * sin(PI * u))
		if u >= 1.0 and _t >= _end and not _opened[i]:
			# Waiting to be opened: a hop now and then, a ring.
			p.y -= absf(sin(_t * 3.0 + i * 1.3)) * 16.0
			var k := fmod(_t / 1.4 + i * 0.3, 1.0)
			_root.draw_arc(land, 70.0 + 50.0 * k, 0, TAU, 40, Color(Boss.GOLD, 0.7 * (1.0 - k)), 6.0, true)
		_root.draw_set_transform(p, sin(_t * 9.0 + i) * 0.08 if u < 1.0 else 0.0, Vector2.ONE)
		_reward_box(Vector2.ZERO, 150.0, _reward_color(rewards[i]), _opened[i])
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not rewards.is_empty() and _t >= _end - 0.2:
		var k := clampf((_t - _end + 0.2) / 0.3, 0.0, 1.0)
		var f := UiTheme.font()
		var head := "BOSS REWARD" if rewards.size() == 1 else "BOSS REWARDS"
		var ins2 := UiTheme.insets(_root.get_viewport())
		var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
		var hy := ins2.x + 300.0
		_root.draw_string_outline(f, Vector2(v.x / 2.0 - hw / 2.0, hy), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 16, Color(0.1, 0.06, 0.16, k))
		_root.draw_string(f, Vector2(v.x / 2.0 - hw / 2.0, hy), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(Boss.GOLD, k))
		if _opened.find(false) >= 0 and not _busy:
			var tip := "Tap to open!"
			var tw2 := f.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
			var ty := _package_at(0).y + 150.0
			_root.draw_string_outline(f, Vector2(v.x / 2.0 - tw2 / 2.0, ty), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 10, Color(0.1, 0.06, 0.16, k))
			_root.draw_string(f, Vector2(v.x / 2.0 - tw2 / 2.0, ty), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1, 1, 1, k * (0.65 + 0.35 * sin(_t * 4.0))))
	# The money bag: dropped, bounces, bursts into gold.
	if _t >= 0.9 and rewards.is_empty():
		var bag_x := v.x * 0.62 + 120.0
		var u := clampf((_t - 0.9) / 0.15, 0.0, 1.0)
		var bag := Vector2(bag_x, lerpf(floor_y - tall * 0.5, floor_y - 30.0, u * u))
		if _t < 1.2:
			Boss.money_bag(_root, bag, 46.0)
		var b := _t - 1.05
		if b > 0.0:
			var k := clampf(b / 0.9, 0.0, 1.0)
			_root.draw_circle(bag, 60.0 + 240.0 * k, Color(1.0, 0.9, 0.5, 0.45 * (1.0 - k)))
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			for q in 22:
				var a := rng.randf_range(-PI, 0.0)
				var sp := rng.randf_range(300.0, 700.0)
				var p := bag + Vector2(cos(a), sin(a)) * sp * b + Vector2(0, 900.0 * b * b)
				if b < 1.4:
					Icons.draw(_root, "coin", p, 40.0 * (1.0 - 0.3 * k), Color.WHITE)
	# What he says: it stays where he stood, a moment after he's off.
	if _t <= _run:
		_stand_x = feet.x
	if _t > 0.15 and _t < _run + 0.6:
		var px := 44
		var f := UiTheme.font()
		var w := f.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var lines: Array = BossIntro.wrap_text(_line, px, v.x - 200.0)
		var bw := minf(w, v.x - 200.0) + 64.0
		var bh := lines.size() * px * 1.25 + 44.0
		var bc := Vector2(clampf(_stand_x, bw / 2.0 + 40.0, v.x - bw / 2.0 - 40.0), floor_y - tall * 1.5 - bh / 2.0)
		var s := 1.0 - pow(1.0 - clampf((_t - 0.15) / 0.18, 0.0, 1.0), 3.0)
		s *= clampf((_run + 0.6 - _t) / 0.2, 0.0, 1.0)          # (and pops away)
		_root.draw_set_transform(bc, sin(_t * 30.0) * 0.02, Vector2.ONE * s)
		DrawUtil.rrect(_root, Rect2(Vector2(-bw / 2.0, -bh / 2.0) + Vector2(0, 8), Vector2(bw, bh)), Color(0, 0, 0, 0.3), 30.0)
		DrawUtil.rrect(_root, Rect2(Vector2(-bw / 2.0, -bh / 2.0), Vector2(bw, bh)), Palette.BUBBLE, 30.0)
		for i in lines.size():
			var lw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			_root.draw_string(f, Vector2(-lw / 2.0, -bh / 2.0 + 22.0 + px + i * px * 1.25), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("d62839") if not Palette.night else Color("ff7a85"))
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
