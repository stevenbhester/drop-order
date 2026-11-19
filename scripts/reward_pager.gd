class_name RewardPager
extends CanvasLayer
## A run of rewards, opened one after another, each on its own page (the boss's packages: BossOutro). A page
## pans in from the right with its present on it; the present lands, glows, rattles and pops by itself in a
## blast of light; out comes the reward on the card for its kind (BuffCard for headlights or undos,
## UnlockCard for a cosmetic), with its button(s). Acknowledge it and the page pans off to the left as the
## next pans in, until they're all open; then `finished`.
##
## Every page is a rounded card with a gold rim on the dark, and dots along the bottom say how far through
## you are. Taps hurry everything: one on a present pops it at once, one on a card still arriving shows it
## all, and one more (off the buttons) is the card's "OK" / "Maybe later". So tapping through is quick.

signal finished

const PAN := 0.3                 # seconds a page takes to pan in (and the last one out)
const OPENS_AT := 0.75           # the present pops by itself this long after its page starts in
const POP := 0.35                # ...and the lid takes this long
const BACK := Color(0.05, 0.035, 0.1)
const RIM := 14.0                # the page's margin from the screen's edge
const CORNER := 54.0

## [{kind: "lights" | "undos" | "item", value, first}], in the order they're shown.
var rewards: Array = []

var _back: Control               # the dark behind the pages
var _chrome: Control             # on top: each page's rim, the dots, the pop's flash
var _i := -1
var _cur := {}                   # the page that's up: {page, card, t (since it started in), wait (since it popped), open}
var _old := {}                   # the one panning off: {page, card, t}
var _flash := 0.0
var _ending := false


func _ready() -> void:
	layer = 66
	_back = Control.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_back.draw.connect(func(): _back.draw_rect(Rect2(Vector2.ZERO, _back.size), Color(BACK, 0.96)))
	add_child(_back)
	var top := CanvasLayer.new()
	top.layer = 83               # over the cards (BuffCard's own layer is 82)
	add_child(top)
	_chrome = Control.new()
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.draw.connect(_draw_chrome)
	top.add_child(_chrome)
	_back.modulate.a = 0.0
	create_tween().tween_property(_back, "modulate:a", 1.0, 0.15)
	_next()


func _width() -> float:
	return _back.get_viewport_rect().size.x


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _tint(r: Dictionary) -> Color:
	match str(r.get("kind", "")):
		"lights":
			return Color("ffc53d")
		"undos":
			return Color("4d8dff")
	return Cosmetics.tint(str(r.get("value", "")))


## The next reward's page starts in (or, after the last, it's over once that one's panned off).
func _next() -> void:
	_i += 1
	_cur = {}
	if _i >= rewards.size():
		_ending = true
		return
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.position.x = _width()
	add_child(page)
	_cur = {"page": page, "card": null, "t": 0.0, "wait": 0.0, "open": false}
	page.draw.connect(_draw_page.bind(page))
	# A tap on the present pops it at once.
	page.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _cur.get("page") == page and not _cur["open"]:
			page.accept_event()
			_open())
	Sfx.play("whoosh", 1.2, -8.0)
	get_tree().create_timer(0.3).timeout.connect(func():
		if _cur.get("page") == page and not _cur["open"]:
			Sfx.play("thunk", 0.9, -4.0)
			Sfx.haptic(16, 1.0, "reward_pager:_next"))


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	var w := _width()
	if not _old.is_empty():
		_old["t"] += delta
		_place(_old, -w * _ease(_old["t"] / PAN))
		if _old["t"] >= PAN:
			for n in [_old["card"], _old["page"]]:
				if n and is_instance_valid(n):
					n.queue_free()
			_old = {}
	if not _cur.is_empty():
		_cur["t"] += delta
		_place(_cur, w * (1.0 - _ease(_cur["t"] / PAN)))
		if not _cur["open"]:
			if _cur["wait"] > 0.0:
				_cur["wait"] += delta
				if _cur["wait"] >= POP:
					_show_card()
			elif _cur["t"] >= OPENS_AT:
				_pop()
			(_cur["page"] as Control).queue_redraw()
	elif _ending and _old.is_empty():
		_ending = false
		var tw := create_tween()
		tw.tween_property(_back, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			finished.emit()
			queue_free())
	_chrome.queue_redraw()


## A page (and its card, which may be a layer of its own) at offset `x` from the middle.
func _place(p: Dictionary, x: float) -> void:
	p["x"] = x
	(p["page"] as Control).position.x = x
	var card = p["card"]
	if card is CanvasLayer and is_instance_valid(card):
		(card as CanvasLayer).offset.x = x


## The lid goes: a punch, a blast of light (POP seconds), then the reward.
func _pop() -> void:
	_cur["wait"] = 0.001
	Sfx.play("punch", 1.2, -2.0)
	Sfx.play("whoomp", 1.1, -4.0)
	Sfx.haptic(45, 1.0, "reward_pager:_pop")


## A tap on the present: no waiting, it's open.
func _open() -> void:
	Sfx.play("punch", 1.2, -2.0)
	Sfx.haptic(30, 0.8, "reward_pager:_open")
	_show_card()


## The present's open: this reward's card, on its page.
func _show_card() -> void:
	var r: Dictionary = rewards[_i]
	var page: Control = _cur["page"]
	_cur["open"] = true
	_flash = 1.0
	Sfx.play("sparkle", 1.0, -4.0)
	match str(r.get("kind", "")):
		"lights", "undos":
			var card := BuffCard.new()
			if r["kind"] == "lights":
				card.lights = int(r["value"])
				card.intro = bool(r.get("first", false))
			else:
				card.undos = int(r["value"])
			card.paged = true
			card.offset.x = page.position.x
			add_child(card)
			card.done.connect(_card_done)
			_cur["card"] = card
		_:
			var uc := UnlockCard.new()
			uc.item = str(r.get("value", ""))
			uc.wrapped = false
			uc.paged = true
			page.add_child(uc)
			uc.closed.connect(_card_done)
			_cur["card"] = uc
	page.queue_redraw()


## Acknowledged: this page pans off as the next pans in.
func _card_done() -> void:
	if _cur.is_empty():
		return
	_old = {"page": _cur["page"], "card": _cur["card"], "t": 0.0}
	_next()


## A page before its present's open: dark, the present dropping in and getting ready to pop, and which
## reward it is over it.
func _draw_page(page: Control) -> void:
	var v := page.size
	page.draw_rect(Rect2(Vector2.ZERO, v), Color("14121f"))
	if _cur.get("page") != page or _cur["open"]:
		return
	var r: Dictionary = rewards[_i]
	var t: float = _cur["t"]
	UnlockCard.draw_parcel(page, v, Vector2(v.x / 2.0, v.y * 0.42), _tint(r), t, _cur["wait"], "", "")
	var f := UiTheme.font()
	var head := "REWARD %d OF %d" % [_i + 1, rewards.size()] if rewards.size() > 1 else "BOSS REWARD"
	var a := clampf(t / 0.2, 0.0, 1.0)
	var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	page.draw_string_outline(f, Vector2((v.x - hw) / 2.0, v.y * 0.17), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 16, Color(0.1, 0.07, 0.16, a))
	page.draw_string(f, Vector2((v.x - hw) / 2.0, v.y * 0.17), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(Boss.GOLD, a))


## Over everything: each page trimmed to a rounded card with a gold rim (wherever it's panned to), the
## pop's flash, and the dots.
func _draw_chrome() -> void:
	var v := _chrome.size
	for p in [_old, _cur]:
		if not p.is_empty():
			_rim(float(p.get("x", 0.0)), v)
	if _flash > 0.0:
		# (A glow from the middle, not a white-out of the whole screen: three of those in a row was a strobe.)
		_chrome.draw_circle(v / 2.0, 420.0 * (1.2 - 0.4 * _flash), Color(1, 1, 0.92, 0.16 * _flash))
	if rewards.size() > 1:
		var ins := UiTheme.insets(_chrome.get_viewport())
		var y := v.y - ins.y - 44.0
		for k in rewards.size():
			var c := Vector2(v.x / 2.0 + (k - (rewards.size() - 1) / 2.0) * 44.0, y)
			var now := k == _i
			_chrome.draw_circle(c, 13.0 if now else 10.0, Color(0, 0, 0, 0.35))
			_chrome.draw_circle(c, 10.0 if now else 7.0, Boss.GOLD if k <= _i else Color(1, 1, 1, 0.3))


## A page's edge at offset `x`: everything outside a rounded rectangle goes back to the dark (so the page is
## a card), and a gold line runs round it.
func _rim(x: float, v: Vector2) -> void:
	var r := Rect2(x + RIM, RIM, v.x - RIM * 2.0, v.y - RIM * 2.0)
	var dark := Color(BACK, 1.0)
	_chrome.draw_rect(Rect2(x, 0, v.x, RIM), dark)
	_chrome.draw_rect(Rect2(x, v.y - RIM, v.x, RIM), dark)
	_chrome.draw_rect(Rect2(x, 0, RIM, v.y), dark)
	_chrome.draw_rect(Rect2(x + v.x - RIM, 0, RIM, v.y), dark)
	var line := PackedVector2Array()
	var corners := [[r.position + Vector2(CORNER, CORNER), PI, r.position], [Vector2(r.end.x - CORNER, r.position.y + CORNER), -PI / 2.0, Vector2(r.end.x, r.position.y)],
		[r.end - Vector2(CORNER, CORNER), 0.0, r.end], [Vector2(r.position.x + CORNER, r.end.y - CORNER), PI / 2.0, Vector2(r.position.x, r.end.y)]]
	for c in corners:
		var wedge := PackedVector2Array([c[2]])
		for s in 9:
			var a: float = float(c[1]) + s / 8.0 * PI / 2.0
			var p: Vector2 = (c[0] as Vector2) + Vector2(cos(a), sin(a)) * CORNER
			wedge.append(p)
			line.append(p)
		_chrome.draw_colored_polygon(wedge, dark)
	line.append(line[0])
	_chrome.draw_polyline(line, Color(Boss.GOLD, 0.85), 5.0, true)
