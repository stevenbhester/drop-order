class_name DailyResults
extends RefCounted
## Today's daily, everyone's: each player's result goes to the MusicGrid server (POST /lm/daily: solved or
## not, score, time, tries, route length, undos, badge ids) and "How everyone did" (DailyStats) reads the
## day's totals back (GET /lm/daily/stats?day=...).
##
## Who it's from: Progress.device_id (a random id, made the first time it's needed). Nothing about the
## phone's owner. A result that can't be sent waits (user://daily_queue.json, the newest per day) and goes
## the next time one is sent or the game starts.
##
## `-- --daily-url=<base>` points both somewhere else (a local server: http://127.0.0.1:5000/lm).

const BASE := "https://music-grid-io-42616e204fd3.herokuapp.com/lm"
const QUEUE := "user://daily_queue.json"

static var _sender: Sender


static func base() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--daily-url="):
			return a.trim_prefix("--daily-url=").trim_suffix("/")
	return BASE


## Today's result (or the day's), as the server wants it, from its record.
static func payload(day: int) -> Dictionary:
	if Progress.device_id == "":
		Progress.set_option("device_id", Crypto.new().generate_random_bytes(16).hex_encode())
	var r := Progress.daily_record(day)
	return {
		"device": Progress.device_id,
		"day": Daily.key(day),
		"version": "v%s (%d)" % [Version.NUMBER, Version.BUILD],
		"solved": bool(r.get("done", false)),
		"score": int(r.get("score", 0)),
		"secs": snappedf(float(r.get("time", 0.0)), 0.1),
		"tries": clampi(int(r.get("attempts", 1)), 1, 20),
		"tiles": int(r.get("tiles", 0)),
		"undos": int(r.get("undos", 0)),
		"badges": r.get("badges", []),
	}


## Send the day's result (after a solve, or the last try spent). Never under the self-tests, unless they
## point it somewhere (--daily-url).
static func send(day: int) -> void:
	if DebugRemote.on():
		return              # (a simulated playtest: nothing's sent or kept)
	if Progress.auto and base() == BASE:
		return
	var q := _read()
	q[Daily.key(day)] = payload(day)
	_write(q)
	flush()


static func flush() -> void:
	if _read().is_empty():
		return
	if _sender == null or not is_instance_valid(_sender):
		_sender = Sender.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_sender)
	else:
		_sender.kick()


static func _read() -> Dictionary:
	if not FileAccess.file_exists(QUEUE):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(QUEUE))
	return d if d is Dictionary else {}


static func _write(q: Dictionary) -> void:
	var f := FileAccess.open(QUEUE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(q))


## Fetches day `day`'s totals and calls `done` with them (a Dictionary), or with {} if they can't be had.
## `owner` holds the request (it goes when the owner does).
static func fetch(owner: Node, day: int, done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	owner.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var d = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		done.call(d if d is Dictionary else {}))
	if http.request("%s/daily/stats?day=%s" % [base(), Daily.key(day)]) != OK:
		http.queue_free()
		done.call({})


## Day `day`'s totals with the simulated drivers' added in (Daily.sim_stats): `real` is what the server
## sent ({} if it couldn't be had: then it's the drivers alone).
static func with_sim(day: int, real: Dictionary) -> Dictionary:
	var sim := Daily.sim_stats(day)
	if sim.is_empty():
		return real
	if real.is_empty():
		return sim.duplicate(true)
	var out := real.duplicate(true)
	out["players"] = int(real.get("players", 0)) + int(sim.get("players", 0))
	out["solved"] = int(real.get("solved", 0)) + int(sim.get("solved", 0))
	var rs := int(real.get("solved", 0))
	var ss := int(sim.get("solved", 0))
	out["scoreAvg"] = roundi((float(real.get("scoreAvg", 0)) * rs + float(sim.get("scoreAvg", 0)) * ss) / maxf(rs + ss, 1))
	for part in ["scores", "secs", "tries", "badges"]:
		var d: Dictionary = (real.get(part, {}) as Dictionary).duplicate()
		var extra: Dictionary = sim.get(part, {})
		for k in extra:
			d[k] = int(d.get(k, 0)) + int(extra[k])
		out[part] = d
	return out


## Sends what's waiting, one at a time. A result leaves when the server has it (or refuses it for good).
class Sender:
	extends Node
	var _http: HTTPRequest
	var _busy := false
	var _key := ""

	func _ready() -> void:
		_http = HTTPRequest.new()
		_http.timeout = 20.0
		_http.request_completed.connect(_on_done)
		add_child(_http)
		kick()

	func kick() -> void:
		if _busy or _http == null:
			return
		var q := DailyResults._read()
		if q.is_empty():
			return
		_key = str(q.keys()[0])
		var err := _http.request(DailyResults.base() + "/daily", PackedStringArray(["Content-Type: application/json"]),
			HTTPClient.METHOD_POST, JSON.stringify(q[_key]))
		_busy = err == OK

	func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_busy = false
		if result == HTTPRequest.RESULT_SUCCESS and code in [200, 201, 400, 413]:
			var q := DailyResults._read()
			q.erase(_key)
			DailyResults._write(q)
			kick()
		else:
			print("[daily] result not sent (result %d, code %d)" % [result, code])
