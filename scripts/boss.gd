class_name Boss
extends RefCounted
## The villain: Baron Von Bottomline, CEO of Hoardly Inc. He owns every delivery van in town but one, and
## wants that one gone so the town's deliveries are all his. We're the last independent courier; he tries to
## buy us, then bury us. He's every delivery-giant founder at once: bald as an egg under a black cowboy hat,
## a quilted vest, a monocle (he is a Baron), a laugh you can hear from orbit, and a bag of everybody's money.
## He talks in shareholder letters and owns a rocket. A parody of the type: no real names, no real brands.
## He laughs at you on the way in (BossIntro) and runs off, dropping his prize, when you win (BossOutro).
## What he says tells that story in order, boss by boss (STORY), so it has to stay short and blunt.
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
const VEST := Color("22335e")
const QUILT := Color("3a4d85")
const SHIRT := Color("e6edf8")
const HAT := Color("161616")

const TAUNTS := [
	"Little van, big dreams! I already bought this neighbourhood.",
	"Same-day delivery? I invented same-day PRICING.",
	"One delivery company. One price. Mine. That's not a monopoly, that's TIDY.",
	"Independent? In MY town? Adorable. Expensive, but adorable.",
	"You deliver for less than I charge to THINK about delivering.",
	"I don't deliver packages. I deliver VALUE. To SHAREHOLDERS.",
	"Your tips have been reclassified as 'synergy'. Haw!",
	"I automated the drivers, then laid off the robots. Efficiency!",
	"This road is now a premium subscription. Ten Dollaroos a turn!",
	"Customer service? We outsourced it to a voicemail. In 1997.",
	"It's always Day One at Hoardly. For you? Day Done.",
	"I have a rocket. Do YOU have a rocket?",
	"We're customer-obsessed. Obsessed with them not being YOUR customers.",
	"My yacht has a yacht. Your van has... you.",
	"Next-day delivery? I can have you out of business by lunch.",
]
const DEFEATS := [
	"One van. ONE! How?!",
	"My quarterly earnings!!",
	"This was NOT in the forecast!",
	"Legal will be hearing about this!",
	"Fine! Keep it! I'll write it off!",
	"Somebody short my stock! Not that one!",
	"Fine! I'm going to SPACE!",
	"Put it in the shareholder letter: 'headwinds'.",
]


static func is_boss(d: Dictionary) -> bool:
	return str(d.get("twist", "")) == "boss"


## Boss fights on the main road. The last job of every zone is one (RoadMap.REGIONS), and so are the CORE
## ones: early fights for the upgrades the game leans on, which can't be skipped or driven round (the jobs
## after one stay locked until he's beaten there). A core fight's "buff" is what he's guarding:
## brighter headlights and two more undos on every level, for good (Progress.headlights(), undo_slots()).
## Detours are for the optional things: rides, power-ups, and the last, brightest lights.
const CORE := {
	6: {"buff": {"lights": 1, "undos": 2}},
	11: {"buff": {"lights": 1, "undos": 2}},
}
## What he loses at each boss on the main road, the first time: one of Hoardly Inc.'s fleet paint jobs
## (Cosmetics), so beating him always wins something you can see.
const LOOT := {
	6: "hq_grey", 11: "hq_pinstripe", 16: "hq_boardroom", 20: "hq_gold_card", 28: "hq_funny_money", 32: "hq_velvet",
	40: "hq_penthouse", 47: "hq_parachute", 54: "hq_shareholder", 61: "hq_offshore", 68: "hq_ticker", 75: "hq_bull",
	83: "hq_monocle", 90: "hq_corner", 95: "hq_buyout", 100: "hq_baron",
}
## The story, in his own words: what he says going into each main-road fight the first time, and what he
## yells when he loses it. Every boss job is one HE booked, rigged so we'd fail it and give up, leaving
## him the town's only delivery company; every loss is him finding out we didn't. Level 6 says who he is
## and that; each one after follows what's pinned to that zone's board (RoadMap.LORE). A replay gets any
## old taunt.
const STORY := {
	6: ["I'm Baron Von Bottomline. I own every van in town but yours. I booked this job so you'd fail, quit, and sell.", "You DELIVERED it? That job was built to make you quit!"],
	11: ["Another order from me. Rigged, naturally. Fail one job and your customers come crawling to Hoardly.", "Still going?! Don't you know when you're beaten?"],
	16: ["Last independent courier in town. Not for long: I booked you a job nobody can finish.", "I bought the depot for NOTHING?!"],
	20: ["A million for your van. Or try this job, fail it, and sell for less. Either way, I win.", "Who turns down a million AND finishes the job?!"],
	28: ["Every road on this job runs through my toll gates. Give up now. Save us both the time.", "My tolls! You were supposed to turn BACK!"],
	32: ["My grey vans are already on this route. You'll never beat them to it. Go home.", "Why are MY vans slower?!"],
	40: ["I bought the ferry to make this job impossible. Admit it: you're done.", "I bought a FERRY for this!"],
	47: ["Gas is triple, just for you. Run dry out here and this town needs only one delivery company.", "Do you know what gas costs?! I do. I set it!"],
	54: ["Every job you finish makes my town untidy. This one won't get finished.", "Still untidy. STILL!"],
	61: ["A Hoardly locker on every corner. I booked this job so nobody needs you. Give it up.", "People LIKE you? That's not in the model!"],
	68: ["Final offer: fail this job and sell, or I make every order in town undeliverable.", "I have other final offers! Worse ones!"],
	75: ["I dug up every road this job needs. For your own good. Quit.", "How are you still DRIVING?!"],
	83: ["So you've seen my order book. Yes, I place your jobs. Yes, I want you to fail them.", "Give that order book BACK!"],
	90: ["From up here I see the whole town. Mine, all but one van. Fail this and it's all mine.", "My view! It's still got a van in it!"],
	95: ["Every trick I've got, on one job. Nobody could finish it. Give up!", "That was everything! ...Almost."],
	100: ["The last mile. I made it impossible, so you'll finally quit. Then this town needs only Hoardly.", "Out of moves. And the town still has you. BAH!"],
}


static func is_level(n: int) -> bool:
	if CORE.has(n):
		return true
	for r in RoadMap.REGIONS:
		if int(r["to"]) == n:
			return true
	return false


## The boss fight on level `L`, in the shape of a boss detour's definition (for BossIntro and prize()).
static func level_def(L: LevelData) -> Dictionary:
	var d := {"level": L.number, "title": L.title}
	d.merge(CORE.get(L.number, {}))
	if LOOT.has(L.number):
		d["reward"] = LOOT[L.number]
	if STORY.has(L.number):
		d["taunt"] = STORY[L.number][0]
		d["defeat"] = STORY[L.number][1]
	return d


## The core boss level that has to be beaten before level `n` can be played (0: none).
static func blocker(n: int) -> int:
	if Progress.auto or Progress.all_open:
		return 0
	var first := 0
	for b in CORE:
		if int(b) < n and not Progress.is_complete(int(b)) and (first == 0 or int(b) < first):
			first = int(b)
	return first


static func _beaten(d: Dictionary) -> bool:
	if d.has("level"):
		return Progress.is_complete(int(d["level"]))
	return Progress.side_done.has(str(d.get("id", "")))


static func taunt() -> String:
	return TAUNTS[randi() % TAUNTS.size()]


## What he says on the way in: his own line for this fight until he's been beaten there, then any taunt.
static func taunt_for(d: Dictionary) -> String:
	if str(d.get("taunt", "")) != "" and not _beaten(d):
		return str(d["taunt"])
	return taunt()


## What beating him here wins, in a few words ("" once it's all been won): the next headlights (while the
## headlights experiment is on), more undos, a cosmetic; on the main road, the bonus if nothing else.
static func prize(d: Dictionary) -> String:
	var parts := []
	for it in loot(d):
		parts.append(str(it["text"]))
	return " + ".join(parts)


## What beating him wins, item by item (for BossIntro's loot tiles): each {kind ("lights", "undos",
## "paint", "item" or "bragging"), label (short, under the tile), text (for a sentence), item (a cosmetic
## id, or ""), n}. Empty once he's been beaten.
static func loot(d: Dictionary) -> Array:
	if _beaten(d):
		return []
	var out := []
	var buff: Dictionary = d.get("buff", {}) if d.get("buff", {}) is Dictionary else {}
	if int(buff.get("lights", 0)) > 0 and Progress.lights_earned() and Progress.headlights() < Progress.MAX_LIGHTS:
		var nm := Progress.light_name(Progress.headlights() + 1)
		out.append({"kind": "lights", "label": nm, "text": nm, "item": "", "n": 1})
	if int(buff.get("undos", 0)) > 0 and Progress.undo_slots() < Progress.MAX_UNDO_SLOTS:
		var more := mini(int(buff["undos"]), Progress.MAX_UNDO_SLOTS - Progress.undo_slots())
		out.append({"kind": "undos", "label": "+1 undo" if more == 1 else "+%d undos" % more,
			"text": "an extra undo" if more == 1 else "%d more undos" % more, "item": "", "n": more})
	var reward := str(d.get("reward", ""))
	if reward != "" and not Progress.owns(reward):
		var paint := Cosmetics.kind_of(reward) == "paint"
		out.append({"kind": "paint" if paint else "item", "label": Cosmetics.name_of(reward),
			"text": Cosmetics.name_of(reward) + (" paint job" if paint else ""), "item": reward, "n": 1})
	if out.is_empty() and d.has("level"):
		var brag := "%d Dollaroos" % ChallengeIntro.BONUS if Progress.COINS else "Bragging rights"
		out.append({"kind": "bragging", "label": brag, "text": brag.to_lower() if not Progress.COINS else brag, "item": "", "n": 0})
	return out


static func defeat() -> String:
	return DEFEATS[randi() % DEFEATS.size()]


## What he yells on the way out: his own line for this fight the first time he loses it, then any.
static func defeat_for(d: Dictionary, first: bool) -> String:
	if first and str(d.get("defeat", "")) != "":
		return str(d["defeat"])
	return defeat()


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
	# The belly: a big round quilted vest, zipped, over an open-necked shirt (no tie: he's "approachable").
	var belly := Vector2(0, -50.0 * u)
	ci.draw_circle(belly, 27.0 * u, VEST)
	for k in 5:
		var y := (k - 2) * 9.0 * u
		var half := sqrt(maxf(0.0, pow(26.0 * u, 2.0) - y * y))
		ci.draw_line(belly + Vector2(-half, y), belly + Vector2(half, y), QUILT, 1.4 * u, true)
	ci.draw_colored_polygon(PackedVector2Array([belly + Vector2(-10, -26) * u, belly + Vector2(10, -26) * u, belly + Vector2(0, -6) * u]), SHIRT)
	ci.draw_line(belly + Vector2(0, -6) * u, belly + Vector2(0, 25) * u, Color("c9cede"), 1.6 * u, true)
	ci.draw_circle(belly + Vector2(0, -6) * u, 1.8 * u, GOLD)
	# The company's mark on his chest.
	ci.draw_circle(belly + Vector2(13, -12) * u, 3.4 * u, GOLD)
	# Arms: one on the belly holding the bag, or both up.
	var bag_at := Vector2(30, -40) * u
	match mood:
		"laugh":
			ci.draw_line(belly + Vector2(-22, -10) * u, belly + Vector2(-12, 6) * u, SHIRT, 8.0 * u, true)
			ci.draw_circle(belly + Vector2(-12, 6) * u, 4.0 * u, SKIN)
			ci.draw_line(belly + Vector2(22, -10) * u, belly + Vector2(34, -26) * u, SHIRT, 8.0 * u, true)
			bag_at = belly + Vector2(38, -30) * u + Vector2(0, sin(t * 19.0) * 2.0 * u)
		"panic":
			for sd in [-1.0, 1.0]:
				var hand := belly + Vector2(sd * 34.0, -40.0 + sin(t * 30.0 + sd) * 4.0) * u
				ci.draw_line(belly + Vector2(sd * 20.0, -14.0) * u, hand, SHIRT, 8.0 * u, true)
				ci.draw_circle(hand, 4.0 * u, SKIN)
			bag_at = Vector2(INF, INF)
		_:
			ci.draw_line(belly + Vector2(-22, -10) * u, belly + Vector2(-10, 4) * u, SHIRT, 8.0 * u, true)
			ci.draw_circle(belly + Vector2(-10, 4) * u, 4.0 * u, SKIN)
			var sw := sin(t * 2.4) * 0.15
			ci.draw_line(belly + Vector2(22, -10) * u, belly + Vector2(30, 4) * u, SHIRT, 8.0 * u, true)
			bag_at = belly + Vector2(32, 12) * u + Vector2(sin(sw) * 6.0 * u, 0)
	if bag_at.x != INF:
		money_bag(ci, bag_at, 15.0 * u)
	# The head.
	var head := belly + Vector2(0, -38) * u
	ci.draw_set_transform(feet + shake + Vector2(head.x * face, head.y), tilt * face, Vector2(face, 1.0))
	ci.draw_circle(Vector2.ZERO, 16.0 * u, SKIN)
	ci.draw_circle(Vector2(14, 2) * u, 4.0 * u, SKIN.darkened(0.08))
	# Bald as an egg, and polished (you see it when the hat goes flying).
	ci.draw_circle(Vector2(5, -11.5) * u, 3.6 * u, Color(1, 1, 1, 0.45))
	ci.draw_circle(Vector2(9, -8.5) * u, 1.4 * u, Color(1, 1, 1, 0.55))
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
	var brow := -4.0 * u if mood == "panic" else (-1.6 * u if mood == "smug" else 0.0)
	ci.draw_line(Vector2(-10, -9) * u + Vector2(0, brow), Vector2(-2, -7) * u + Vector2(0, brow * 0.5), Color("3a2f2a"), 2.6 * u, true)
	ci.draw_line(Vector2(2, -7) * u + Vector2(0, brow * 0.5), Vector2(11, -10) * u + Vector2(0, brow), Color("3a2f2a"), 2.6 * u, true)
	# The mouth: a wall of teeth when he's pleased with himself, wide open laughing or screaming.
	if mood == "smug":
		# A grin from ear to ear: all teeth, turned up at the corners.
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, 3) * u, Vector2(9, 3) * u, Vector2(7, 8) * u, Vector2(3, 11) * u, Vector2(-3, 11) * u, Vector2(-7, 8) * u]), Color("5a1a24"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-7.4, 4) * u, Vector2(7.4, 4) * u, Vector2(5.8, 7.4) * u, Vector2(2.6, 9.8) * u, Vector2(-2.6, 9.8) * u, Vector2(-5.8, 7.4) * u]), Color.WHITE)
		ci.draw_line(Vector2(-6.6, 6.6) * u, Vector2(6.6, 6.6) * u, Color(0, 0, 0, 0.12), 0.6 * u)
		ci.draw_arc(Vector2(-9.5, 2.6) * u, 1.8 * u, PI * 0.9, PI * 1.6, 5, SKIN.darkened(0.25), 0.9 * u, true)
		ci.draw_arc(Vector2(9.5, 2.6) * u, 1.8 * u, -PI * 0.6, PI * 0.1, 5, SKIN.darkened(0.25), 0.9 * u, true)
	else:
		DrawUtil.rrect(ci, Rect2(Vector2(-7, 3) * u, Vector2(14, 12) * u), Color("5a1a24"), 5.0 * u)
		ci.draw_rect(Rect2(Vector2(-5.5, 3.4) * u, Vector2(11, 3.0) * u), Color.WHITE)
		ci.draw_circle(Vector2(0, 12.5) * u, 3.2 * u, Color("d9596a"))
	# The hat: a black cowboy hat with a gold band (knocked flying on panic).
	# (Pushed well back, so the polished dome shows under it.)
	var hat := Vector2(-2, -17) * u
	var hat_rot := -0.16
	if mood == "panic":
		hat += Vector2(-6.0, -10.0 - absf(sin(t * 9.0)) * 6.0) * u
		hat_rot = -0.5 + sin(t * 9.0) * 0.3
	elif mood == "laugh":
		hat_rot = -0.26 + sin(t * 19.0) * 0.05
	ci.draw_set_transform(feet + shake + Vector2(head.x * face, head.y) + hat.rotated(tilt * face), tilt * face + hat_rot, Vector2(face, 1.0))
	# Brim: wide, curling up at the sides.
	var brim := PackedVector2Array()
	for k in 13:
		var a := k / 12.0
		brim.append(Vector2(lerpf(-25.0, 25.0, a), -1.0 - pow(absf(a - 0.5) * 2.0, 2.2) * 6.0) * u)
	ci.draw_polyline(brim, HAT, 5.0 * u, true)
	# Crown: pinched at the top.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -3) * u, Vector2(-11, -18) * u, Vector2(-5, -21) * u, Vector2(0, -18.5) * u, Vector2(5, -21) * u,
		Vector2(11, -18) * u, Vector2(12, -3) * u]), HAT)
	ci.draw_rect(Rect2(Vector2(-12, -8) * u, Vector2(24, 3.6) * u), GOLD)
	var f := UiTheme.font()
	var px := int(7.0 * u)
	if px >= 6:
		var w := f.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(f, Vector2(-w / 2.0, -10.5 * u), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, px, GOLD)
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
