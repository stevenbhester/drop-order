class_name Boss
extends RefCounted
## The villain of the boss detours: Baron Von Bottomline, CEO of Hoardly Inc., the delivery giant that
## would very much like your little van to stop delivering things to people for less than a premium
## subscription. Top hat, monocle, a moustache you could lose a parcel in, and a bag of everybody's money.
## He laughs at you on the way in (BossIntro) and runs off, dropping his prize, when you win (BossOutro).
##
## A boss detour is a side road (levels/side.json) with "twist": "boss": a dense, very hard map, hints and
## undos allowed, usually behind a key ("locked": true), and a very good cosmetic as its "reward".
##
## Boss.draw(canvas, feet, height, t, mood): him, standing on `feet`, `height` pixels tall. mood:
##   "smug"   one hand on his belly, the money bag swinging
##   "laugh"  head back, shaking with it, HAW HAW HAW
##   "panic"  hat off, arms up, sweating; he's about to run

const NAME := "Baron Von Bottomline"
const COMPANY := "Hoardly Inc."
const SUIT := Color("2b2d42")
const STRIPE := Color("44476a")
const SKIN := Color("f2c4a8")
const GOLD := Color("ffc53d")
const TIE := Color("d62839")

const TAUNTS := [
	"Little van, big dreams! I already bought this neighbourhood.",
	"Same-day delivery? I invented same-day PRICING.",
	"Every package you drop raises MY quarterly earnings. Haw haw haw!",
	"I don't deliver packages. I deliver VALUE. To SHAREHOLDERS.",
	"Your tips have been reclassified as 'synergy'. Haw!",
	"I automated the drivers, then laid off the robots. Efficiency!",
	"This road is now a premium subscription. Ten Dollaroos a turn!",
	"Customer service? We outsourced it to a voicemail. In 1997.",
]
const DEFEATS := [
	"My quarterly earnings!!",
	"This was NOT in the forecast!",
	"Legal will be hearing about this!",
	"Fine! Keep it! I'll write it off!",
	"Somebody short my stock! Not that one!",
]


static func is_boss(d: Dictionary) -> bool:
	return str(d.get("twist", "")) == "boss"


static func taunt() -> String:
	return TAUNTS[randi() % TAUNTS.size()]


static func defeat() -> String:
	return DEFEATS[randi() % DEFEATS.size()]


static func draw(ci: CanvasItem, feet: Vector2, h: float, t: float, mood := "smug", face := 1.0) -> void:
	var u := h / 100.0                      # one hundredth of his height
	var shake := Vector2.ZERO
	var tilt := 0.0
	match mood:
		"laugh":
			shake = Vector2(sin(t * 38.0) * 1.2, -absf(sin(t * 19.0)) * 3.0) * u
			tilt = -0.12
		"panic":
			shake = Vector2(sin(t * 50.0) * 1.6, sin(t * 43.0) * 0.8) * u
		_:
			shake = Vector2(0, -absf(sin(t * 2.4)) * 1.2 * u)
	# Shadow.
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
	ci.draw_circle(Vector2.ZERO, 30.0 * u, Color(0, 0, 0, 0.28))
	ci.draw_set_transform(feet + shake, 0.0, Vector2(face, 1.0))
	# Legs and shoes.
	var step := sin(t * 18.0) * 6.0 * u if mood == "panic" else 0.0
	for sd in [-1.0, 1.0]:
		var hip := Vector2(sd * 9.0 * u, -34.0 * u)
		var foot := Vector2(sd * 11.0 * u + sd * step, -3.0 * u)
		ci.draw_line(hip, foot, SUIT, 10.0 * u, true)
		DrawUtil.rrect(ci, Rect2(foot + Vector2(-6.0 * u + (4.0 * u if sd > 0 else -4.0 * u), -3.0 * u), Vector2(13.0 * u, 7.0 * u)), Color("161616"), 3.0 * u)
	# The belly: a big round suit, pinstriped.
	var belly := Vector2(0, -50.0 * u)
	ci.draw_circle(belly, 27.0 * u, SUIT)
	for k in 5:
		var x := (k - 2) * 9.0 * u
		var half := sqrt(maxf(0.0, pow(26.0 * u, 2.0) - x * x))
		ci.draw_line(belly + Vector2(x, -half), belly + Vector2(x, half), STRIPE, 1.2 * u, true)
	# Shirt front, tie, gold watch chain.
	ci.draw_colored_polygon(PackedVector2Array([belly + Vector2(-9, -26) * u, belly + Vector2(9, -26) * u, belly + Vector2(0, -2) * u]), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([belly + Vector2(-3, -24) * u, belly + Vector2(3, -24) * u, belly + Vector2(4, -6) * u, belly + Vector2(0, -1) * u, belly + Vector2(-4, -6) * u]), TIE)
	ci.draw_arc(belly + Vector2(8, -2) * u, 10.0 * u, 0.3, 2.4, 10, GOLD, 1.6 * u, true)
	ci.draw_circle(belly + Vector2(17, 4) * u, 2.4 * u, GOLD)
	# Arms: one on the belly holding the bag, or both up.
	var bag_at := Vector2(30, -40) * u
	match mood:
		"laugh":
			ci.draw_line(belly + Vector2(-22, -10) * u, belly + Vector2(-12, 6) * u, SUIT, 8.0 * u, true)
			ci.draw_circle(belly + Vector2(-12, 6) * u, 4.0 * u, Color.WHITE)
			ci.draw_line(belly + Vector2(22, -10) * u, belly + Vector2(34, -26) * u, SUIT, 8.0 * u, true)
			bag_at = belly + Vector2(38, -30) * u + Vector2(0, sin(t * 19.0) * 2.0 * u)
		"panic":
			for sd in [-1.0, 1.0]:
				var hand := belly + Vector2(sd * 34.0, -40.0 + sin(t * 30.0 + sd) * 4.0) * u
				ci.draw_line(belly + Vector2(sd * 20.0, -14.0) * u, hand, SUIT, 8.0 * u, true)
				ci.draw_circle(hand, 4.0 * u, Color.WHITE)
			bag_at = Vector2(INF, INF)
		_:
			ci.draw_line(belly + Vector2(-22, -10) * u, belly + Vector2(-10, 4) * u, SUIT, 8.0 * u, true)
			ci.draw_circle(belly + Vector2(-10, 4) * u, 4.0 * u, Color.WHITE)
			var sw := sin(t * 2.4) * 0.15
			ci.draw_line(belly + Vector2(22, -10) * u, belly + Vector2(30, 4) * u, SUIT, 8.0 * u, true)
			bag_at = belly + Vector2(32, 12) * u + Vector2(sin(sw) * 6.0 * u, 0)
	if bag_at.x != INF:
		money_bag(ci, bag_at, 15.0 * u)
	# The head.
	var head := belly + Vector2(0, -38) * u
	ci.draw_set_transform(feet + shake + Vector2(head.x * face, head.y), tilt * face, Vector2(face, 1.0))
	ci.draw_circle(Vector2.ZERO, 16.0 * u, SKIN)
	ci.draw_circle(Vector2(14, 2) * u, 4.0 * u, SKIN.darkened(0.08))
	# Eyes: a monocle on one; wide on panic.
	var eye_r := 3.6 * u if mood == "panic" else 2.2 * u
	if mood == "laugh":
		ci.draw_arc(Vector2(-6, -3) * u, 3.0 * u, PI * 1.1, PI * 1.9, 6, Color("1a1a1a"), 1.6 * u, true)
	else:
		ci.draw_circle(Vector2(-6, -3) * u, eye_r, Color.WHITE)
		ci.draw_circle(Vector2(-6, -3) * u, eye_r * 0.55, Color("1a1a1a"))
	ci.draw_circle(Vector2(6, -3) * u, 6.0 * u, Color(0.8, 0.95, 1.0, 0.35))
	ci.draw_circle(Vector2(6, -3) * u, eye_r * 0.55, Color("1a1a1a"))
	ci.draw_arc(Vector2(6, -3) * u, 6.0 * u, 0, TAU, 18, GOLD, 1.6 * u, true)
	ci.draw_line(Vector2(11, 0) * u, Vector2(14, 16) * u, GOLD, 0.8 * u, true)
	# Eyebrows: wicked, or up in horror.
	var brow := -4.0 * u if mood == "panic" else 0.0
	ci.draw_line(Vector2(-10, -9) * u + Vector2(0, brow), Vector2(-2, -7) * u + Vector2(0, brow * 0.5), Color("e8e8e8"), 2.4 * u, true)
	ci.draw_line(Vector2(2, -7) * u + Vector2(0, brow * 0.5), Vector2(11, -10) * u + Vector2(0, brow), Color("e8e8e8"), 2.4 * u, true)
	# The mouth (wide open laughing or screaming) under a huge curled moustache.
	if mood != "smug":
		DrawUtil.rrect(ci, Rect2(Vector2(-5, 5) * u, Vector2(10, 9) * u), Color("5a1a24"), 4.0 * u)
		ci.draw_rect(Rect2(Vector2(-4, 5) * u, Vector2(8, 2.4) * u), Color.WHITE)
	for sd in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for k in 9:
			var a := k / 8.0
			pts.append(Vector2(sd * (1.0 + a * 13.0), 4.0 + sin(a * PI) * 3.0 - a * a * 6.0) * u)
		ci.draw_polyline(pts, Color("f4f4f4"), 4.2 * u, true)
		ci.draw_circle(Vector2(sd * 14.0, -2.0) * u, 2.2 * u, Color("f4f4f4"))
	# The top hat (knocked flying on panic).
	var hat := Vector2(0, -14) * u
	var hat_rot := 0.0
	if mood == "panic":
		hat += Vector2(-6.0, -10.0 - absf(sin(t * 9.0)) * 6.0) * u
		hat_rot = -0.5 + sin(t * 9.0) * 0.3
	ci.draw_set_transform(feet + shake + Vector2(head.x * face, head.y) + hat.rotated(tilt * face), tilt * face + hat_rot, Vector2(face, 1.0))
	DrawUtil.rrect(ci, Rect2(Vector2(-17, -3) * u, Vector2(34, 5) * u), Color("161616"), 2.0 * u)
	DrawUtil.rrect(ci, Rect2(Vector2(-11, -26) * u, Vector2(22, 25) * u), Color("161616"), 2.0 * u)
	ci.draw_rect(Rect2(Vector2(-11, -7) * u, Vector2(22, 4) * u), GOLD)
	var f := UiTheme.font()
	var px := int(7.0 * u)
	if px >= 6:
		var w := f.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(f, Vector2(-w / 2.0, -12.0 * u), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, px, GOLD)
	if mood == "panic":
		# Sweat.
		ci.draw_set_transform(feet + shake + Vector2(head.x * face, head.y), 0.0, Vector2.ONE)
		for k in 3:
			var a := fmod(t * 2.0 + k * 0.33, 1.0)
			var p := Vector2((-18.0 + k * 18.0) * u, (-6.0 + a * 14.0) * u)
			ci.draw_circle(p, 2.2 * u * (1.0 - a * 0.5), Color(0.6, 0.85, 1.0, 1.0 - a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A fat sack of money with a dollar sign on it.
static func money_bag(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.15), r, Color("c8a25a"))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.1), r * 0.55, Color("d9b56d"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.75), c + Vector2(r * 0.35, -r * 0.75), c + Vector2(r * 0.6, -r * 1.2), c + Vector2(-r * 0.6, -r * 1.2)]), Color("c8a25a"))
	ci.draw_line(c + Vector2(-r * 0.4, -r * 0.78), c + Vector2(r * 0.4, -r * 0.78), Color("7a5a2a"), r * 0.14, true)
	var f := UiTheme.font()
	var px := int(r * 1.1)
	if px >= 6:
		var w := f.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(f, c + Vector2(-w / 2.0, r * 0.5), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("2e7d32"))
