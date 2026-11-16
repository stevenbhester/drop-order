class_name AdPicker
extends RefCounted
## Which pretend ad plays next, everywhere one plays (a checkpoint, out of gas on a job, the gas station).
## One pool: Hoardly Inc.'s spots (BaronAd, while the option's on), Last Mile's own (PromoAd) and Frontiers
## Celestia (FakeAd). Each of the three gets an equal chance, then one of its spots at random; any spot among
## the last RECENT this player saw (Progress.recent_ads, kept in the save) is left out, so nobody sees the
## same one twice in a short while. Ids: "baron:<spot>", "promo:<kind>", "celestia".
##
## The first ad a player ever watches at a checkpoint is a Hoardly one (it's his gate).

const RECENT := 3


## A new ad, its spot chosen and remembered as seen. `gate_first`: the first one at a checkpoint.
static func make(gate_first := false) -> CanvasLayer:
	var id := pick(gate_first)
	Progress.saw_ad(id)
	if id.begins_with("baron:"):
		var b := BaronAd.new()
		b.spot = id.trim_prefix("baron:")
		return b
	if id.begins_with("promo:"):
		var p := PromoAd.new()
		p.kind = id.trim_prefix("promo:")
		return p
	return FakeAd.new()


## Every spot that could play, by brand.
static func brands() -> Dictionary:
	var out := {}
	var hoardly := Progress.hoardly_ads
	if Progress.auto:
		# (The self-tests see Hoardly only when they ask for him.)
		hoardly = Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--baron-ad"))
	if hoardly:
		out["baron"] = BaronAd.SPOTS.keys().map(func(k): return "baron:" + str(k))
	out["promo"] = PromoAd.KINDS.map(func(k): return "promo:" + str(k))
	out["celestia"] = ["celestia"]
	return out


static func pick(gate_first := false) -> String:
	var all := brands()
	if gate_first and all.has("baron"):
		all = {"baron": all["baron"]}
	var recent: Array = Progress.recent_ads
	var left := {}
	for brand in all:
		var spots: Array = all[brand].filter(func(s): return not recent.has(s))
		if not spots.is_empty():
			left[brand] = spots
	if left.is_empty():
		# (Everything was seen lately: anything but the very last one.)
		var last: String = recent.back() if not recent.is_empty() else ""
		for brand in all:
			var spots: Array = all[brand].filter(func(s): return s != last)
			if not spots.is_empty():
				left[brand] = spots
	if left.is_empty():
		return "celestia"
	var brand: String = left.keys().pick_random()
	return left[brand].pick_random()
