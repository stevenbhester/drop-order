class_name Boss
extends RefCounted
## The villain: Baron Von Bottomline, CEO of Hoardly Inc. He owns every delivery van in town but one, and
## wants that one gone so the town's deliveries are all his. We're the last independent courier; he tries to
## buy us, then bury us. He's every tech billionaire at once, a parody of the type (no real names, no real
## brands): a tall egg of a head under a swoop of very expensive hair, a gold monocle (he IS a Baron), a black tee and a
## puffer vest, a gold chain, always on his phone posting, a honking laugh and a bag of everybody's money. He
## thinks he's the coolest man alive (his boss fights open like an anime: BossIntro), takes offence at
## everything, cries when he loses (BossOutro), and never forgets a slight.
## He laughs at you on the way in (BossIntro) and runs off, dropping his prize, when you win (BossOutro).
## What he says tells that story in order, boss by boss (STORY), so it has to stay short and blunt.
##
## A boss detour is a side road (levels/side.json) with "twist": "boss": a dense, very hard map, hints and
## undos allowed, usually behind a key ("locked": true), and a very good cosmetic as its "reward".
##
## Boss.draw(canvas, feet, height, t, mood): him, standing on `feet`, `height` pixels tall. mood:
##   "smug"   on his phone, posting, the money bag in his other hand
##   "laugh"  head back, shaking with it, HAW HAW HAW
##   "pose"   pointing right at you (his anime opening)
##   "panic"  arms up, eyes popping, the monocle jumping out on its chain; he's about to run
##   "cry"    monocle dangling, fists in his eyes, tears in two waterfalls, a snot bubble

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
const TEE := Color("1f1f26")
const JEANS := Color("2a3350")
const BROW := Color("3a2f2a")
const HAIR := Color("3b2a20")

const TAUNTS := [
	"Bro thinks he can deliver. Skill issue.",
	"I'm not a villain. I'm a visionary. Look it up.",
	"Rate my vest. Out of ten. Choose very carefully.",
	"Same-day delivery? I invented same-day PRICING.",
	"I have a rocket. Do YOU have a rocket? Didn't think so.",
	"Main character energy. You're an NPC. I don't make the rules. Actually, I do.",
	"Imagine delivering things yourself. Couldn't be me.",
	"One delivery company. One price. Mine. That's not a monopoly, that's TIDY.",
	"I automated the drivers, then laid off the robots. Efficiency!",
	"This road is a premium subscription now. Eight Dollaroos a month.",
	"Everyone says I'm hilarious. Everyone I pay.",
	"I'm literally the funniest billionaire alive. Laugh. LAUGH.",
	"Little van, big dreams. Cringe.",
	"Your tips have been reclassified as 'synergy'. Haw!",
	"Just posted about you. It's going viral. You're welcome.",
]
const DEFEATS := [
	"This is a coordinated attack on ME!",
	"Blocked. Reported. Muted. In that order!",
	"I'm not crying! The vest is crying!",
	"Legal will hear about this! And my mom!",
	"Fine! I'm going to SPACE! Don't follow me!",
	"That job was a beta. It doesn't count!",
	"I'm literally the victim here!",
	"You'll regret this. I keep a list. You're on it.",
	"WAAAH! My quarterly earnings!!",
	"Nobody laughed at my jokes AND you won?!",
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
	6: ["Sup. Baron Von Bottomline. I own every van in town but yours. Booked this job so you'd fail, quit, and sell.", "You DELIVERED it?! That's harassment. You're BLOCKED!"],
	11: ["Another order from me. Rigged, obviously. Fail it and your customers come crawling to Hoardly.", "Still going?! This is a coordinated attack! I'm not crying!"],
	16: ["Last independent courier in town? Not for long. I booked you a job nobody can finish. Based.", "I bought the depot for NOTHING?! Somebody hold my vest!"],
	20: ["A million and sixty-nine for your van. Nice. Or fail this and sell for less. I win either way.", "Who turns down a million AND finishes the job?! Posting about this. Tonight."],
	28: ["Every road on this job runs through my toll gates. Pay up or log off.", "My tolls! You were supposed to turn BACK! I'm literally shaking!"],
	32: ["My grey vans are already on this route. Self-driving. Mostly. Go home.", "Why are MY vans slower?! Fake! Recount!"],
	40: ["I bought the ferry to make this job impossible. Named it after me. You're done.", "I bought a FERRY for this! I'm going to cry on a livestream!"],
	47: ["Gas is triple, just for you. Run dry out here and this town is mine. Cope.", "Do you know what gas costs?! I do. I SET it! MOM!!"],
	54: ["Every job you finish makes my town untidy. This one won't get finished. Ratio.", "Still untidy. STILL! WAAAH!"],
	61: ["A Hoardly locker on every corner. I booked this job so nobody needs you.", "People LIKE you? That's not in the algorithm! I'm changing the algorithm!"],
	68: ["Final offer: fail this job and sell, or I make every order in town undeliverable. Not a threat. Okay, a threat.", "I have other final offers! Worse ones! I'm writing them down!"],
	75: ["I dug up every road this job needs. For your own good. Quit.", "How are you still DRIVING?! Unfollow! Unfollow EVERYONE!"],
	83: ["So you've seen my order book. Yes, I place your jobs. Yes, I want you to fail them. Genius, right?", "Give that order book BACK! That's doxxing!"],
	90: ["From up here I see the whole town. Mine, all but one van. Fail this and it's all mine. Rate my view.", "My view! It's still got a van in it! WAAAH!"],
	95: ["Every trick I've got, on one job. Nobody could finish it. Give up, NPC.", "That was everything! ...Almost. I'll be back. I never forget."],
	100: ["The last mile. I made it impossible, so you'll finally quit. Then this town needs only Hoardly.", "Out of moves. And the town still has you. I'm going to SPACE. Forever. Don't follow me."],
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
	# A main-road boss pays Radio calls and a hint (Game._win): undos are free on the road now, so the old
	# "+2 undos" isn't a prize any more (a daily still counts them: Progress.undo_slots keeps the buff).
	if d.has("level") and (Progress.limits_on() or int(d["level"]) >= Progress.LIMITS_FROM):     # (on unlimited help, they'd be nothing)
		out.append({"kind": "radio", "label": "+4 calls", "text": "4 calls", "item": "", "n": 4})
		out.append({"kind": "hint", "label": "+1 hint", "text": "a hint", "item": "", "n": 1})
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
			tilt = -0.14
		"panic":
			shake = Vector2(sin(t * 50.0) * 1.6, sin(t * 43.0) * 0.8) * u
		"cry":
			# Sobbing: his whole body heaves.
			shake = Vector2(sin(t * 9.0) * 0.8, -absf(sin(t * 7.0)) * 2.2) * u
			tilt = sin(t * 4.0) * 0.06
		"pose":
			tilt = 0.08
		_:
			shake = Vector2(0, -absf(sin(t * 2.4)) * 1.2 * u)
	# Shadow.
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
	ci.draw_circle(Vector2.ZERO, 30.0 * u, Color(0, 0, 0, 0.28))
	ci.draw_set_transform(feet + shake, 0.0, Vector2(face, 1.0))
	# Legs (slim dark jeans) and shoes; on a tantrum, stomping.
	var step := 0.0
	if mood == "panic":
		step = sin(t * 18.0) * 6.0 * u
	elif mood == "cry":
		step = maxf(0.0, sin(t * 11.0)) * 5.0 * u
	for sd in [-1.0, 1.0]:
		var hip := Vector2(sd * 7.0 * u, -32.0 * u)
		var lift := -step if (mood == "cry" and sd > 0.0) else 0.0
		var foot := Vector2(sd * 10.0 * u + (sd * step if mood == "panic" else 0.0), -3.0 * u + lift)
		ci.draw_line(hip, foot, JEANS, 9.0 * u, true)
		DrawUtil.rrect(ci, Rect2(foot + Vector2(-6.0 * u + (4.0 * u if sd > 0 else -4.0 * u), -3.0 * u), Vector2(13.0 * u, 7.0 * u)), Color("161616"), 3.0 * u)
	# The torso: a black tee, a puffer vest hanging open over it (he thinks it's a look), a gold chain.
	var torso := PackedVector2Array([Vector2(-19, -60) * u, Vector2(19, -60) * u, Vector2(15, -31) * u, Vector2(-15, -31) * u])
	ci.draw_colored_polygon(torso, TEE)
	for sd in [-1.0, 1.0]:
		var vest := PackedVector2Array([Vector2(sd * 19.5, -60) * u, Vector2(sd * 9, -60) * u, Vector2(sd * 7, -31) * u, Vector2(sd * 15.5, -31) * u])
		ci.draw_colored_polygon(vest, VEST)
		for k in 3:
			var y := (-54.0 + k * 9.0) * u
			ci.draw_line(Vector2(sd * 8.0 * u, y), Vector2(sd * (18.5 - k * 1.2) * u, y), QUILT, 1.3 * u, true)
	ci.draw_arc(Vector2(0, -59) * u, 5.5 * u, PI * 0.2, PI * 0.8, 10, GOLD, 1.2 * u, true)
	ci.draw_circle(Vector2(0, -53.6) * u, 1.6 * u, GOLD)
	# Arms. By mood: on his phone (posting) with the money bag in the other hand; one up laughing; flailing;
	# fists in his eyes; or pointing at you.
	var bag_at := Vector2(INF, INF)
	var sl := Vector2(-18, -57) * u
	var sr := Vector2(18, -57) * u
	match mood:
		"laugh":
			_arm(ci, sl, Vector2(-24, -40) * u, Vector2(-8, -36) * u, u)          # (on his belly)
			_arm(ci, sr, Vector2(30, -62) * u, Vector2(28, -78) * u, u)
			bag_at = Vector2(30, -88) * u + Vector2(0, sin(t * 19.0) * 2.0 * u)
		"panic":
			for sd in [-1.0, 1.0]:
				var hand := Vector2(sd * 32.0, -84.0 + sin(t * 30.0 + sd) * 4.0) * u
				_arm(ci, Vector2(sd * 18, -57) * u, Vector2(sd * 30, -68) * u, hand, u)
		"cry":
			# Fists in his eyes.
			for sd in [-1.0, 1.0]:
				var hand := Vector2(sd * 8.0, -82.0) * u + Vector2(sin(t * 14.0 + sd) * 1.2, 0) * u
				_arm(ci, Vector2(sd * 18, -57) * u, Vector2(sd * 26, -44) * u, hand, u)
		"pose":
			# Pointing right at you (anime), the other fist on his hip.
			_arm(ci, sl, Vector2(-26, -42) * u, Vector2(-14, -33) * u, u)
			_arm(ci, sr, Vector2(32, -64) * u, Vector2(46, -76) * u, u)
			ci.draw_line(Vector2(46, -76) * u, Vector2(52, -81) * u, SKIN, 2.8 * u, true)
		_:
			# On his phone, posting (the screen lights his chin), the bag in the other hand.
			var tap := sin(t * 9.0) * 0.6
			_arm(ci, sl, Vector2(-25, -40) * u, Vector2(-11, -50) * u, u)
			DrawUtil.rrect(ci, Rect2(Vector2(-16, -61) * u, Vector2(10, 16) * u), Color("15151c"), 2.0 * u)
			DrawUtil.rrect(ci, Rect2(Vector2(-15, -60) * u, Vector2(8, 13.5) * u), Color("8fd3ff"), 1.4 * u)
			ci.draw_circle(Vector2(-10, -53 + tap) * u, 1.6 * u, SKIN.darkened(0.04))
			_arm(ci, sr, Vector2(24, -40) * u, Vector2(26, -26) * u, u)
			bag_at = Vector2(26, -14) * u + Vector2(sin(sin(t * 2.4) * 0.15) * 6.0 * u, 0)
	if bag_at.x != INF:
		money_bag(ci, bag_at, 13.0 * u)
	# The head: a tall egg, and on top of it, a swoop of very expensive hair (the hairline still had other
	# ideas: a high, shiny forehead).
	var head := Vector2(0, -82) * u
	ci.draw_set_transform(feet + shake + Vector2(head.x * face, head.y), tilt * face, Vector2(face, 1.0))
	ci.draw_circle(Vector2(-16.5, 3) * u, 3.8 * u, SKIN.darkened(0.08))
	ci.draw_circle(Vector2(16.5, 3) * u, 3.8 * u, SKIN.darkened(0.08))
	var egg := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		var ry := 23.0 if sin(a) < 0.0 else 17.0           # (taller on top: an egg)
		egg.append(Vector2(cos(a) * 16.5, sin(a) * ry) * u)
	ci.draw_colored_polygon(egg, SKIN)
	_hair(ci, u, t, mood)
	# The shine: that forehead, polished.
	ci.draw_circle(Vector2(5, -13.5) * u, 2.6 * u, Color(1, 1, 1, 0.5))
	var glint := fmod(t * 0.7, 3.0)
	if glint < 0.25 and mood != "cry":
		Icons.star(ci, Vector2(5, -13.5) * u, 6.0 * u * sin(PI * glint / 0.25), Color.WHITE)
	# Eyebrows (over the shades): up in delight, knit in horror.
	var brow := -3.0 * u if mood in ["panic", "cry"] else (-1.5 * u if mood in ["smug", "pose"] else 0.0)
	var knit := 2.5 * u if mood in ["panic", "cry"] else 0.0
	ci.draw_line(Vector2(-11, -9) * u + Vector2(0, brow), Vector2(-3, -8) * u + Vector2(0, brow * 0.4 - knit), BROW, 2.4 * u, true)
	ci.draw_line(Vector2(3, -8) * u + Vector2(0, brow * 0.4 - knit), Vector2(11, -9) * u + Vector2(0, brow), BROW, 2.4 * u, true)
	if mood == "cry":
		# The monocle's popped out, dangling on its chain: eyes screwed shut, and two waterfalls.
		_monocle(ci, Vector2(10, 17) * u + Vector2(sin(t * 6.0) * 1.5, 0) * u, u)
		ci.draw_line(Vector2(15, -1) * u, Vector2(12, 12) * u, GOLD, 0.8 * u, true)
		for sd in [-1.0, 1.0]:
			ci.draw_polyline(PackedVector2Array([Vector2(sd * 9.5, -4) * u, Vector2(sd * 6.5, -2) * u, Vector2(sd * 9.5, 0) * u]), Color("1a1a1a"), 1.6 * u, true)
			var stream := PackedVector2Array()
			for k in 9:
				var q := k / 8.0
				var y := q * 30.0
				stream.append(Vector2(sd * (8.0 + q * 18.0 + sin(t * 20.0 + q * 6.0) * 1.2), -1.0 + y) * u)
			ci.draw_polyline(stream, Color(0.55, 0.82, 1.0, 0.9), 3.6 * u, true)
			for k in 3:
				var a := fmod(t * 3.0 + k * 0.33 + (0.5 if sd > 0.0 else 0.0), 1.0)
				ci.draw_circle(Vector2(sd * (26.0 + a * 6.0), 29.0 + a * 10.0) * u, 2.0 * u * (1.0 - a), Color(0.55, 0.82, 1.0, 1.0 - a))
		# A wail: mouth wide, turned down, wobbling.
		var wob := sin(t * 16.0) * 0.8
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, 11) * u, Vector2(-5, 4 + wob) * u, Vector2(5, 4 - wob) * u, Vector2(8, 11) * u, Vector2(0, 13) * u]), Color("5a1a24"))
		ci.draw_circle(Vector2(0, 11) * u, 2.6 * u, Color("d9596a"))
		# ...and a snot bubble, swelling and popping.
		var sb := fmod(t * 0.9, 1.0)
		if sb < 0.85:
			ci.draw_circle(Vector2(3, 1) * u, (1.0 + sb * 5.0) * u, Color(0.75, 0.95, 0.8, 0.55))
			ci.draw_arc(Vector2(3, 1) * u, (1.0 + sb * 5.0) * u, 0, TAU, 14, Color(1, 1, 1, 0.6), 0.7 * u, true)
	else:
		# Eyes: half-lidded and very pleased with himself, one behind a gold monocle (he is a Baron);
		# popping wide in a panic, the monocle jumping out on its chain.
		var wide := mood == "panic"
		for sd in [-1.0, 1.0]:
			var e := Vector2(sd * 6.0, -3.0) * u
			if mood == "laugh":
				ci.draw_arc(e, 3.0 * u, PI * 1.1, PI * 1.9, 6, Color("1a1a1a"), 1.6 * u, true)
				continue
			var r := (3.6 if wide else 2.6) * u
			ci.draw_circle(e, r, Color.WHITE)
			ci.draw_circle(e + Vector2(0.4, 0.3) * u, r * 0.55, Color("1a1a1a"))
			if not wide:
				# The lid: a smug half-close.
				ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-r - 0.6 * u, -r - 0.6 * u), e + Vector2(r + 0.6 * u, -r - 0.6 * u),
					e + Vector2(r + 0.6 * u, -0.3 * u), e + Vector2(-r - 0.6 * u, -0.3 * u)]), SKIN.darkened(0.06))
				ci.draw_line(e + Vector2(-r, -0.3 * u), e + Vector2(r, -0.3 * u), Color("1a1a1a"), 1.0 * u, true)
		if wide:
			var pop := Vector2(14, 6 + absf(sin(t * 12.0)) * 4.0) * u
			_monocle(ci, pop, u)
			ci.draw_line(Vector2(15, -1) * u, pop + Vector2(0, -4.5) * u, GOLD, 0.8 * u, true)
		else:
			_monocle(ci, Vector2(6, -3) * u, u)
			ci.draw_line(Vector2(11, 0) * u, Vector2(14, 16) * u, GOLD, 0.8 * u, true)
		# The mouth: the big grin (all teeth, top lip curled up), wide open honking, or screaming.
		if mood == "smug" or mood == "pose":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 4) * u, Vector2(10, 4) * u, Vector2(8, 9) * u, Vector2(3, 12) * u, Vector2(-3, 12) * u, Vector2(-8, 9) * u]), Color("5a1a24"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-8.6, 5) * u, Vector2(8.6, 5) * u, Vector2(7, 8.4) * u, Vector2(-7, 8.4) * u]), Color.WHITE)
			for k in 5:
				ci.draw_line(Vector2(-6 + k * 3, 5) * u, Vector2(-6 + k * 3, 8.2) * u, Color(0, 0, 0, 0.12), 0.5 * u)
			ci.draw_arc(Vector2(-10.5, 3.4) * u, 2.0 * u, PI * 0.9, PI * 1.6, 5, SKIN.darkened(0.25), 0.9 * u, true)
			ci.draw_arc(Vector2(10.5, 3.4) * u, 2.0 * u, -PI * 0.6, PI * 0.1, 5, SKIN.darkened(0.25), 0.9 * u, true)
		else:
			DrawUtil.rrect(ci, Rect2(Vector2(-8, 3) * u, Vector2(16, 13) * u), Color("5a1a24"), 5.0 * u)
			ci.draw_rect(Rect2(Vector2(-6.5, 3.4) * u, Vector2(13, 3.2) * u), Color.WHITE)
			ci.draw_circle(Vector2(0, 13) * u, 3.4 * u, Color("d9596a"))
	if mood == "panic":
		# Sweat.
		for k in 3:
			var a := fmod(t * 2.0 + k * 0.33, 1.0)
			var p := Vector2((-20.0 + k * 20.0) * u, (-8.0 + a * 14.0) * u)
			ci.draw_circle(p, 2.2 * u * (1.0 - a * 0.5), Color(0.6, 0.85, 1.0, 1.0 - a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## His hair: a dark, swept-up swoop with a quiff at the front over the top of the egg, the hairline
## receding at the temples. It flaps when he panics and droops when he cries.
static func _hair(ci: CanvasItem, u: float, t: float, mood: String) -> void:
	var lift := 0.0
	if mood == "panic":
		lift = absf(sin(t * 18.0)) * 3.0
	elif mood == "cry":
		lift = -1.5
	var pts := PackedVector2Array()
	# Over the top, left to right, a little fuller than the head.
	for k in 13:
		var a := PI + PI * k / 12.0
		var r := Vector2(17.6, 24.5 + lift)
		var bump := 3.5 * exp(-pow((k - 4.0) / 2.2, 2.0))     # (the quiff, front left)
		pts.append(Vector2(cos(a) * r.x, sin(a) * (r.y + bump) - 1.0))
	# The hairline, back right to left: down the temple, a deep bay, the front, the other bay.
	for p in [Vector2(16.4, -7), Vector2(13, -13), Vector2(9, -14), Vector2(6, -17), Vector2(0, -18.5),
			Vector2(-6, -17.5), Vector2(-10, -14), Vector2(-13.5, -13), Vector2(-16.4, -7)]:
		pts.append(p)
	for k in pts.size():
		pts[k] *= u
	ci.draw_colored_polygon(pts, HAIR)
	# A shine along the swoop.
	var shine := PackedVector2Array()
	for k in 7:
		var a := PI * 1.15 + PI * 0.5 * k / 6.0
		shine.append(Vector2(cos(a) * 12.5, sin(a) * (19.0 + lift) - 1.0) * u)
	ci.draw_polyline(shine, Color(1, 1, 1, 0.18), 1.6 * u, true)


## One of his arms: a short tee sleeve, a thin arm, a hand.
static func _arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, u: float) -> void:
	var line := SKIN.darkened(0.18)
	var along := (elbow - shoulder)
	ci.draw_line(elbow, hand, line, 6.6 * u, true)
	ci.draw_line(elbow, hand, SKIN, 5.2 * u, true)
	ci.draw_line(shoulder, elbow, line, 7.4 * u, true)
	ci.draw_line(shoulder, elbow, SKIN, 6.0 * u, true)
	ci.draw_circle(elbow, 3.0 * u, SKIN)
	ci.draw_circle(hand, 4.0 * u, line)
	ci.draw_circle(hand, 3.3 * u, SKIN)
	ci.draw_line(shoulder, shoulder + along.normalized() * 6.0 * u, TEE, 9.0 * u, true)


## His monocle: a gold rim, the glass tinted, a glint across it.
static func _monocle(ci: CanvasItem, c: Vector2, u: float) -> void:
	ci.draw_circle(c, 5.6 * u, Color(0.8, 0.95, 1.0, 0.35))
	ci.draw_arc(c, 5.6 * u, 0, TAU, 20, GOLD, 1.6 * u, true)
	ci.draw_line(c + Vector2(-2.8, -1.8) * u, c + Vector2(0.6, -3.6) * u, Color(1, 1, 1, 0.6), 1.1 * u, true)


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
