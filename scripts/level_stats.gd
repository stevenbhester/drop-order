class_name LevelStats
extends RefCounted
## What the game counts while a level is played: attempts, restarts, undos, hints, wrong moves, time. A
## restart makes a new Game, so the counts live here, by level, for as long as the app is open. They go out
## with each play record (Rating.play: on a win, leaving, a skip or the app going to the background, unless
## "Send play stats" is off) and with a rating. They add up until the level's won, then start afresh.

static var _session := ""
static var _records := {}          # level key -> {field: number}
static var wins := 0               # levels won since the app opened
static var rated := 0              # ratings sent since the app opened


## A random id for this run of the app (it says nothing about the player or the phone).
static func session_id() -> String:
	if _session == "":
		_session = Crypto.new().generate_random_bytes(16).hex_encode()
	return _session


static func _rec(key: String) -> Dictionary:
	if not _records.has(key):
		_records[key] = {"opened_ms": Time.get_ticks_msec(), "session_seconds_before": Time.get_ticks_msec() / 1000.0, "wins_before": wins}
	return _records[key]


## A try at a level begins (the first, or after a restart or a trip to the map).
static func begin(key: String) -> void:
	add(key, "attempts")


static func add(key: String, field: String, n: float = 1.0) -> void:
	var r := _rec(key)
	r[field] = float(r.get(field, 0.0)) + n


static func value(key: String, field: String) -> float:
	return float(_rec(key).get(field, 0.0))


## The level's counts so far, with the time since it was first opened, leaving them counting.
static func peek(key: String) -> Dictionary:
	var r: Dictionary = _rec(key).duplicate()
	r["seconds_wall"] = (Time.get_ticks_msec() - int(r["opened_ms"])) / 1000.0
	r.erase("opened_ms")
	return r


## The level's counts so far, with the time since it was first opened. Won: start afresh next time.
static func take(key: String) -> Dictionary:
	var r: Dictionary = _rec(key).duplicate()
	r["seconds_wall"] = (Time.get_ticks_msec() - int(r["opened_ms"])) / 1000.0
	r.erase("opened_ms")
	_records.erase(key)
	return r
