class_name StackView
extends Node2D
## The van's load as a chute. Packages queue inside it in the order they'll go out; the next one sits in the
## chute's mouth, a little bigger, lit gold. When it's delivered it drops out of the mouth to the van (Game
## flies it from here to the van, then on to the house) and the rest slide down a place. A collected parcel
## comes in at the mouth and pushes the others back up.
##
## Upright (on the left or right of the screen, the default) it reads like a puzzle game's "next" column:
## the mouth, holding the next package, is at the top, and the rest queue down under it. Along the top or
## bottom it lies on its side with its mouth at the right end. Its spout points at the board.
## The frame is thin and quiet (a tube with rivets, a hopper at the back, a gold lip and flap at the mouth) so
## the packages do the talking. While a route is planned, Game has it show the load as it'll be at the end of
## that route (show_stack). On return levels a checkered flag rides behind the last package: back to the pit.
##
## Too many to show (a wrong turn past a warehouse): the back of the queue waits behind a "+N"; drag along the
## chute to scroll through them; it slides back when let go.
## Origin is the centre of the mouth. Mirrors Sim's stack (index 0 = bottom = last out).

## How much bigger the next package (in the mouth) is than the rest: a lot standing up beside the board,
## less lying along it (where the length is tight).
const NEXT_UP := 1.5
const NEXT_SCALE := 1.16
## Parcels are longer than they're wide; the long side runs along the chute (tall in an upright one,
## wide in one lying along the board), so the chute itself stays thin.
const ASPECT := 1.36
## The tallest a parcel gets (upright / on its side), and the smallest before the chute starts hiding some.
const MAX_UP := 62.0
const MAX_SIDE := 70.0
const MIN_H := 38.0
const LINE_A := 0.26

## Stands upright (mouth at the bottom) or lies on its side (mouth at the right).
var vertical := true
## Which way the spout points, toward the board: upright, +1 right / -1 left; on its side, +1 down / -1 up.
var spout := 1.0
## Return levels: a finish flag behind the last package.
var finish_flag := false
## Fog (a side road's twist): every package but the next is a grey "?" crate.
var fog := false:
	set(v):
		fog = v
		_fog_marks()
## Draw the tube at least this long from the mouth's front edge (Game stretches it along the board's side);
## the places past the load are just empty chute.
var reach := 0.0:
	set(v):
		if not is_equal_approx(v, reach):
			reach = v
			queue_redraw()

var ph := 56.0               # a parcel's short side: across the chute
var pw := 76.0               # its long side: along the chute (so the chute stays thin either way)
var box := 60.0              # the step between places along the chute (for scrolling)
var boxes: Array = []        # PackageBox, index 0 = bottom (last out)
var colors: Array = []       # colour names, parallel to boxes
var _capacity := 1
var _avail := 1000.0
var _places := 1             # places drawn in the chute (0 is the mouth)
var _view := 0
var _view_back: Tween
var _roll := 0.0
var _flap := 0.0             # the mouth's flap swings open as a package drops out


# ---------------------------------------------------------------- shape

func _ns() -> float:
	return NEXT_UP if vertical else NEXT_SCALE


## Along the chute, toward the back (away from the mouth).
func _back() -> Vector2:
	return Vector2(0, 1) if vertical else Vector2(-1, 0)


## Across the chute, toward the board.
func _side() -> Vector2:
	return Vector2(spout, 0) if vertical else Vector2(0, spout)


func _along_item() -> float:
	return pw


func _across_item() -> float:
	return ph


## A parcel as drawn: standing tall in an upright chute, lying wide in one along the board.
func _item_size() -> Vector2:
	return Vector2(ph, pw) if vertical else Vector2(pw, ph)


func _dress(b: PackageBox) -> void:
	var sz := _item_size()
	b.size = sz.y
	b.aspect = sz.x / sz.y


## From the mouth's centre to the first place inside, then the step between places.
func _gap0() -> float:
	return _along_item() * (_ns() * 0.5 + 0.5) + ph * 0.34


func _step() -> float:
	return _along_item() + ph * 0.14


## From the mouth's centre to its front edge.
func _front() -> float:
	return _along_item() * _ns() * 0.5 + ph * 0.14


## Room for the "NEXT" label.
func _lab() -> float:
	return ph * 0.6


## How far back the tube's last place is, with `places` places.
func _back_reach(places: int) -> float:
	return 0.0 if places < 2 else _gap0() + (places - 2) * _step()


## Length along the chute from its front edge to the back of the hopper.
func _length(places: int) -> float:
	return _front() + _back_reach(places) + _along_item() * 0.5 + ph * 0.62


func _across_full() -> float:
	return _across_item() * _ns() + ph * 0.5


## `avail` is the room along the chute's length; `capacity` the most it'll ever carry; `upright` stands it
## up (left/right) or lays it down (top/bottom); `toward` is the spout's way (see `spout`).
func setup(cols: Array, avail: float, capacity: int, upright := true, toward := 1.0) -> void:
	_capacity = maxi(capacity, 1)
	_shape(avail, upright, toward)
	for c in cols:
		_add(c)
	_place(false)
	queue_redraw()


## Same load, new shape (the stack's position changed in the options, or the phone turned).
func reshape(avail: float, upright: bool, toward: float) -> void:
	if is_equal_approx(avail, _avail) and upright == vertical and is_equal_approx(toward, spout):
		return
	_shape(avail, upright, toward)
	for b in boxes:
		_dress(b)
		b.queue_redraw()
	_view = 0
	_place(false)
	queue_redraw()


func _shape(avail: float, upright: bool, toward: float) -> void:
	vertical = upright
	spout = toward
	_avail = avail
	var hi := MAX_UP if upright else MAX_SIDE
	var lo := MIN_H
	ph = hi
	pw = ph * ASPECT
	if _length(_capacity) > avail:
		for i in 16:
			ph = (hi + lo) / 2.0
			pw = ph * ASPECT
			if _length(_capacity) > avail:
				hi = ph
			else:
				lo = ph
		ph = lo
		pw = ph * ASPECT
	box = _step()
	_places = _capacity
	while _places > 3 and _length(_places) > avail + 0.5:
		_places -= 1


## The whole chute's size (its label included).
func extent() -> Vector2:
	var along := _length(_places)
	var across := _across_full()
	return Vector2(across, along + _lab()) if vertical else Vector2(along, across + _lab())


## Where the origin (the mouth's centre) sits from the chute's top-left corner.
func origin_in() -> Vector2:
	var e := extent()
	if vertical:
		return Vector2(e.x / 2.0, _lab() + _front())
	return Vector2(e.x - _front(), (_lab() if spout > 0.0 else 0.0) + _across_full() / 2.0)


## Older names the layout uses: width, the origin from the left, and the reach above / below it.
func width() -> float:
	return extent().x


func first_x() -> float:
	return origin_in().x


func above() -> float:
	return origin_in().y


func below() -> float:
	return extent().y - origin_in().y


func top_color() -> String:
	return colors.back() if not colors.is_empty() else ""


## The mouth's centre in global coordinates, and how big the package in it is drawn there (Game flies a
## delivered package from here).
func mouth_global() -> Vector2:
	return to_global(Vector2.ZERO)


func mouth_size() -> Vector2:
	return _item_size() * _ns() * global_scale


# ---------------------------------------------------------------- places

## What fits in the chute right now: {"front": scrolled out of view toward the mouth, "show": in view,
## "behind": waiting out of view at the back}. A "+N" for either end takes a place.
func _fit() -> Dictionary:
	var inside := maxi(boxes.size() - 1, 0)
	var room := _places - 1
	if inside <= room:
		return {"front": 0, "show": inside, "behind": 0}
	var v := clampi(_view, 0, inside)
	var avail := room - (1 if v > 0 else 0)
	var show := mini(inside - v, avail)
	if inside - v > show:
		show = maxi(avail - 1, 1)
	return {"front": v, "show": show, "behind": inside - v - show}


func max_view() -> int:
	var inside := maxi(boxes.size() - 1, 0)
	var room := _places - 1
	return 0 if inside <= room else inside - (room - 1)


## The place package `q` (0 = next) is shown in, or -1 when it's out of view.
func _place_of(q: int) -> int:
	if q <= 0:
		return 0
	var f := _fit()
	var i: int = q - f.front
	if i < 1 or i > f.show:
		return -1
	return i + (1 if f.front > 0 else 0)


## Where place `p` is (0: the mouth).
func _at_place(p: int) -> Vector2:
	if p <= 0:
		return Vector2.ZERO
	return _back() * (_gap0() + (p - 1) * _step())


func _queue_pos(q: int) -> Vector2:
	if q <= 0:
		return Vector2.ZERO
	var at := _place_of(q)
	if at < 0:
		at = 1 if q - _fit().front < 1 else _places - 1
	return _at_place(clampi(at, 1, _places - 1))


## Where stack index `i` rests (the top of the stack is next out).
func _slot(i: int) -> Vector2:
	return _queue_pos(boxes.size() - 1 - i)


func _rest_scale(i: int) -> float:
	return _ns() if i == boxes.size() - 1 else 1.0


func _add(c: String) -> PackageBox:
	var b := PackageBox.new()
	b.color = Palette.pkg(c)
	_dress(b)
	add_child(b)
	boxes.append(b)
	colors.append(c)
	return b


func _place(animate: bool) -> void:
	for i in boxes.size():
		var b: PackageBox = boxes[i]
		var q := boxes.size() - 1 - i
		b.visible = _place_of(q) >= 0
		var to := _slot(i)
		var s := Vector2.ONE * _rest_scale(i)
		if animate and b.visible:
			var tw := b.create_tween().set_parallel()
			tw.tween_property(b, "position", to, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "scale", s, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "rotation", 0.0, 0.2)
		else:
			b.position = to
			b.scale = s
			b.rotation = 0.0
	_fog_marks()


func _fog_marks() -> void:
	for i in boxes.size():
		var b: PackageBox = boxes[i]
		var h := fog and i != boxes.size() - 1
		if b.fogged != h:
			b.fogged = h
			b.queue_redraw()


func _roll_from(by: float) -> void:
	_roll = by
	create_tween().tween_property(self, "_roll", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _swing_flap() -> void:
	_flap = 1.0
	create_tween().tween_property(self, "_flap", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if _roll != 0.0 or _flap != 0.0 or finish_flag or not boxes.is_empty():
		queue_redraw()


# ---------------------------------------------------------------- changes

## A package leaves by the mouth, toward the board (unless Game's taking it over: `handoff`).
func _leave(b: PackageBox, handoff := false) -> void:
	if handoff:
		b.queue_free()
		return
	var out := (_side() * 1.0 + (Vector2(0, -0.3) if vertical else Vector2(0.3, 0))).normalized() * ph * 1.2
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "position", b.position + out, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "scale", Vector2.ONE * 0.4, 0.18)
	tw.tween_property(b, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(b.queue_free)


## The next package drops out of the mouth (`handoff`: Game flies it from here, so it just vanishes); the rest
## slide down a place.
func pop_top(handoff := false) -> void:
	if boxes.is_empty():
		return
	_leave(boxes.pop_back(), handoff)
	colors.pop_back()
	_view = 0
	_place(true)
	_roll_from(1.0)
	_swing_flap()
	queue_redraw()


## A collected parcel comes in at the mouth; the rest shuffle back.
func push(c: String) -> void:
	var b := _add(c)
	_view = 0
	b.position = _side() * ph * 1.4
	b.scale = Vector2(0.5, 0.5)
	_place(true)
	_roll_from(-1.0)
	_swing_flap()
	queue_redraw()


## Sorting hub: the next package and the one behind it trade places, hopping round each other.
func swap_top() -> void:
	var n := boxes.size()
	if n < 2:
		return
	var a: PackageBox = boxes[n - 1]
	var b: PackageBox = boxes[n - 2]
	boxes[n - 1] = b
	boxes[n - 2] = a
	var ca = colors[n - 1]
	colors[n - 1] = colors[n - 2]
	colors[n - 2] = ca
	for pair in [[b, n - 1, 1.0], [a, n - 2, -1.0]]:
		var bx: PackageBox = pair[0]
		var tw := bx.create_tween().set_parallel()
		tw.tween_method(_hop.bind(bx, bx.position, _slot(pair[1]), pair[2]), 0.0, 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bx, "scale", Vector2.ONE * _rest_scale(pair[1]), 0.26)
	_fog_marks()
	queue_redraw()


func _hop(t: float, bx: Node2D, from: Vector2, to: Vector2, way: float) -> void:
	var off := Vector2(1, 0) if vertical else Vector2(0, -1)
	bx.position = from.lerp(to, t) + off * way * _across_item() * 0.42 * sin(PI * t)
	bx.rotation = way * 0.35 * sin(PI * t)


## Undo: the whole load again, popping in from the mouth back.
func rebuild(cols: Array) -> void:
	for b in boxes:
		b.queue_free()
	boxes.clear()
	colors.clear()
	for c in cols:
		_add(c)
	_view = 0
	_place(false)
	for i in boxes.size():
		var b: PackageBox = boxes[i]
		var s := b.scale
		b.scale = Vector2.ZERO
		var tw := b.create_tween()
		tw.tween_interval((boxes.size() - 1 - i) * 0.035)
		tw.tween_property(b, "scale", s, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Show this load instead (the one the planned route will leave, or the real one again): what it shares
## with what's showing (from the back forward) stays put; the rest leave by the mouth or pop in.
func show_stack(cols: Array) -> void:
	var keep := 0
	while keep < mini(colors.size(), cols.size()) and colors[keep] == cols[keep]:
		keep += 1
	if keep == colors.size() and keep == cols.size():
		return
	_view = 0
	var change := cols.size() - colors.size()
	while boxes.size() > keep:
		_leave(boxes.pop_back())
		colors.pop_back()
	var fresh := []
	for i in range(keep, cols.size()):
		fresh.append(_add(cols[i]))
	for b in fresh:
		b.position = _slot(boxes.find(b))
		b.scale = Vector2.ZERO
	_place(true)
	_roll_from(float(signi(-change)))
	queue_redraw()


# ---------------------------------------------------------------- touch

func scroll_to(v: int) -> void:
	v = clampi(v, 0, max_view())
	if v == _view:
		return
	if _view_back and _view_back.is_valid():
		_view_back.kill()
	_roll_from(float(signi(v - _view)))
	_view = v
	_place(true)
	queue_redraw()


func view() -> int:
	return _view


## How far along the chute a local point is, toward the back (for dragging).
func along(local: Vector2) -> float:
	return local.dot(_back())


## A drag that's moved `by` along the chute (toward the back) from where the view was `start_view`.
func drag(start_view: int, by: float) -> void:
	if can_scroll():
		scroll_to(start_view + int(round(by / _step())))


func settle() -> void:
	if _view == 0:
		return
	if _view_back and _view_back.is_valid():
		_view_back.kill()
	_view_back = create_tween()
	_view_back.tween_interval(1.2)
	_view_back.tween_callback(scroll_to.bind(0))


func can_scroll() -> bool:
	return max_view() > 0


func covers(local: Vector2) -> bool:
	var r := Rect2(-origin_in(), extent()).grow(10.0)
	# Stretched along the board: the empty tube counts too.
	var more := maxf(0.0, reach - _length(_places))
	r = r.grow_individual(0, 0, 0, more) if vertical else r.grow_individual(more, 0, 0, 0)
	return r.has_point(local)


func nod() -> void:
	if boxes.is_empty():
		return
	var nb: PackageBox = boxes.back()
	var rest := Vector2.ONE * _ns()
	var tw := nb.create_tween()
	tw.tween_property(nb, "scale", rest * 1.12, 0.07)
	tw.tween_property(nb, "scale", rest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash_remaining() -> void:
	for i in boxes.size():
		var b: PackageBox = boxes[i]
		var tw := b.create_tween()
		tw.tween_interval((boxes.size() - 1 - i) * 0.04)
		for r in [0.18, -0.15, 0.08, 0.0]:
			tw.tween_property(b, "rotation", r, 0.05)


## A tap at `local`: the colour of the package there (it hops), or "".
func tap_at(local: Vector2) -> String:
	for i in boxes.size():
		var b: PackageBox = boxes[i]
		if not b.visible or b.fogged:
			continue
		var at := _slot(i)
		var half := _item_size() * 0.5 * _rest_scale(i) + Vector2(ph, ph) * 0.08
		if Rect2(at - half, half * 2.0).has_point(local):
			var tw := b.create_tween()
			var up := _side() * ph * 0.22
			tw.tween_property(b, "position", at + up, 0.08)
			tw.tween_property(b, "position", at, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			return colors[i]
	return ""


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var line := Color(Palette.TEXT, LINE_A)
	var lw := maxf(ph * 0.05, 2.0)
	var fill := Color(Palette.SURFACE, 0.42)
	var gold := Palette.STAR_GOLD
	var f := UiTheme.font()
	var back := _back()
	var across_dir := Vector2(1, 0) if vertical else Vector2(0, 1)
	var tube := _across_item() + ph * 0.3
	var start := _gap0() - _along_item() * 0.5 - ph * 0.16
	var far := _back_reach(_places) + _along_item() * 0.5 + ph * 0.12
	# Stretched: the tube runs on (empty) to `reach`, its hopper at the far end.
	far = maxf(far, reach - _front() - ph * 0.62)
	if _places >= 2:
		# The tube: from just behind the mouth to the back, thin and rounded.
		var a := back * start - across_dir * tube / 2.0
		var b := back * far + across_dir * tube / 2.0
		var r := Rect2(a, b - a).abs()
		DrawUtil.rrect(self, r.grow(lw), line, tube * 0.28 + lw)
		DrawUtil.rrect(self, r, fill, tube * 0.28)
		# Rivets along both sides, one pair per place.
		var rv := 1
		while _gap0() + (rv - 1) * _step() <= far - ph * 0.2:
			var c := back * (_gap0() + (rv - 1) * _step())
			rv += 1
			for sx in [-1.0, 1.0]:
				draw_circle(c + across_dir * sx * (tube / 2.0 + lw * 0.5), lw * 0.85, Color(Palette.TEXT, LINE_A * 1.4))
		# Little arrows down the middle toward the mouth, between places; they scroll as the load moves.
		var d := -back
		var arrows := int(ceil((far - _gap0()) / _step())) + 2
		for p in range(1, maxi(_places, arrows) + 1):
			var c := back * (_gap0() + (p - 1) * _step()) - back * _step() * (0.5 + _roll)
			if p == 1:
				c = back * (start + ph * 0.06) - back * _step() * _roll
			var dist := c.dot(back)
			if dist < start or dist > far:
				continue
			var w := across_dir * ph * 0.1
			draw_polyline(PackedVector2Array([c - d * ph * 0.05 + w, c + d * ph * 0.05, c - d * ph * 0.05 - w]), Color(Palette.TEXT, 0.16), lw * 0.8, true)
		# The hopper at the back: a little flared cap.
		var hb := back * (far + lw)
		var hop := PackedVector2Array([hb - across_dir * tube * 0.42, hb + back * ph * 0.44 - across_dir * tube * 0.64,
			hb + back * ph * 0.44 + across_dir * tube * 0.64, hb + across_dir * tube * 0.42])
		draw_colored_polygon(hop, fill)
		draw_polyline(PackedVector2Array([hop[0], hop[1], hop[2], hop[3]]), line, lw, true)
		# Hazard stripes on the hopper's rim: the one loud bit.
		var rim_a := hop[1]
		var rim_b := hop[2]
		var n := 6
		for i in n:
			if i % 2 == 0:
				var p0 := rim_a.lerp(rim_b, float(i) / n)
				var p1 := rim_a.lerp(rim_b, float(i + 1) / n)
				draw_line(p0, p1, Color(gold, 0.85), lw * 1.5)
	# The mouth: a gold-framed window round the next package with a slow glow pulsing round it, a gold flap
	# on the board's side that swings out when a package drops through, and a gold NEXT tag.
	var m := _item_size() * _ns()
	var mr := Rect2(-m / 2.0, m).grow(ph * 0.12)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.2)
	if not boxes.is_empty():
		DrawUtil.rrect(self, mr.grow(ph * (0.1 + 0.07 * pulse)), Color(gold, 0.14 + 0.12 * pulse), ph * 0.42)
	DrawUtil.rrect(self, Rect2(mr.position + Vector2(0, lw * 1.6), mr.size).grow(lw * 1.4), Color(gold.darkened(0.3), 0.5), ph * 0.32 + lw)
	DrawUtil.rrect(self, mr.grow(lw * 1.4), Color(gold, 0.95), ph * 0.32 + lw)
	DrawUtil.rrect(self, mr, Palette.SURFACE.lerp(gold, 0.16), ph * 0.32)
	var sd := _side()
	var edge := mr.size.x / 2.0 if vertical else mr.size.y / 2.0
	var along_dir := -back
	var lip_c := sd * (edge + lw * 0.6)
	var half_lip := (mr.size.y if vertical else mr.size.x) * 0.42
	var hinge := lip_c - along_dir * half_lip
	var tip := hinge + along_dir * half_lip * 2.0
	tip = hinge + (tip - hinge).rotated(-signf(sd.x + sd.y) * (1.0 if vertical else -1.0) * _flap * 0.9)
	if _flap > 0.01:
		draw_line(hinge, tip, Color(gold.darkened(0.15), 0.95), lw * 2.2, true)
		draw_circle(hinge, lw * 1.3, Color(gold, 0.95))
	# The NEXT tag: a gold pill over the window (under it when the chute lies along the bottom of the board).
	var nfs := int(ph * 0.3)
	var nw := f.get_string_size("NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var tag_h := ph * 0.42
	var tag_c: Vector2
	if vertical or spout > 0.0:
		tag_c = Vector2(0, mr.position.y - lw * 1.4 - ph * 0.06 - tag_h / 2.0)
	else:
		tag_c = Vector2(0, mr.end.y + lw * 1.4 + ph * 0.06 + tag_h / 2.0)
	var tag := Rect2(tag_c - Vector2(nw / 2.0 + ph * 0.22, tag_h / 2.0), Vector2(nw + ph * 0.44, tag_h))
	DrawUtil.rrect(self, tag, gold, tag_h / 2.0)
	draw_string(f, tag_c + Vector2(-nw / 2.0, nfs * 0.36), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color("3a2a12"))
	# More aboard than fits: "+N" where they're tucked away.
	var fit := _fit()
	for end in [[fit.behind, _places - 1], [fit.front, 1]]:
		var cnt: int = end[0]
		if cnt <= 0:
			continue
		var txt := "+%d" % cnt
		var fs := int(ph * 0.36)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c := _at_place(end[1])
		DrawUtil.rrect(self, Rect2(c - Vector2(tw / 2.0 + ph * 0.1, fs * 0.72), Vector2(tw + ph * 0.2, fs * 1.36)), Palette.SURFACE, ph * 0.14)
		draw_string(f, c + Vector2(-tw / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT)
	# Return levels: the finish flag behind the last package (in the mouth once they're all out).
	if finish_flag:
		var q := boxes.size()
		var at := Vector2.INF
		if q == 0:
			at = Vector2.ZERO
		elif q < _places and fit.behind == 0 and fit.front == 0:
			at = _at_place(q)
		if at != Vector2.INF:
			Icons.finish_flag(self, at, ph * 0.86, Time.get_ticks_msec() / 1000.0)
