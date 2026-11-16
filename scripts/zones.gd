class_name Zones
extends RefCounted
## The road trip's zones (RoadMap.REGIONS: Maple Suburbs, Downtown, ...) and what opens them. A zone opens
## with packages delivered (Progress.delivered): SHARE of everything on the road before it, rounded down to a
## five (so a level or two left behind never blocks the way, and detours and dailies make up for more). Inside
## an open zone the jobs come in order: one can be played once every job before it has been delivered or
## jumped (reached()). Jumping a job (the jump jets: a tank of gas, Progress.skip) moves the van on past it;
## it stays on the map to come back to, and pays nothing until it's delivered. Boss jobs can't be jumped.

const SHARE := 0.8


static func count() -> int:
	return RoadMap.REGIONS.size()


## Which zone level number `n` is in.
static func of(n: int) -> int:
	for k in RoadMap.REGIONS.size():
		if n >= int(RoadMap.REGIONS[k]["from"]) and n <= int(RoadMap.REGIONS[k]["to"]):
			return k
	return RoadMap.REGIONS.size() - 1


static func name_of(k: int) -> String:
	return str(RoadMap.REGIONS[clampi(k, 0, count() - 1)]["name"])


## Packages it takes to open zone `k`.
static func need(k: int) -> int:
	if k <= 0:
		return 0
	return maxi(5, int(Levels.packages_before(int(RoadMap.REGIONS[k]["from"])) * SHARE) / 5 * 5)


static func is_open(k: int) -> bool:
	return Progress.delivered() >= need(k) or Progress.auto or Progress.all_open


## Can level `n` be played? Its zone has to be open, no boss who must be beaten first (Boss.blocker) may
## still be standing in the road before it, and the road has to have got that far (reached()).
static func level_open(n: int) -> bool:
	return is_open(of(n)) and Boss.blocker(n) == 0 and reached(n)


## Has the road got as far as job `n`? Every job before it delivered or jumped. (A job already delivered
## can always be played again, whatever's behind it; so can anything under the self-tests or the testers'
## "all open" option.)
static func reached(n: int) -> bool:
	if Progress.auto or Progress.all_open or Progress.is_complete(n):
		return true
	for m in range(1, n):
		if not Progress.is_complete(m) and not Progress.skipped.has(m):
			return false
	return true


## The first job in the way of job `n` (not delivered, not jumped); 0 if none.
static func in_the_way(n: int) -> int:
	for m in range(1, n):
		if not Progress.is_complete(m) and not Progress.skipped.has(m):
			return m
	return 0


## How many zones are open.
static func open_count() -> int:
	var n := 0
	for k in count():
		if is_open(k):
			n = k + 1
	return n


## Where the van should be heading: the first level not yet beaten (and not skipped) in an open zone; failing
## that the first skipped one; -1 when there's nothing left to play in the open zones.
static func frontier(levels: Array) -> int:
	var skipped := -1
	for i in levels.size():
		var L: LevelData = levels[i]
		if Progress.is_complete(L.number) or not level_open(L.number):
			continue
		if Progress.skipped.has(L.number):
			if skipped < 0:
				skipped = i
			continue
		return i
	return skipped
