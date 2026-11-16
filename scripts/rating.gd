class_name Rating
extends RefCounted
## Level ratings (the "Rate levels" option, off by default): after a level, RatingCard asks how hard, how
## fun and how frustrating it was, with a few descriptors and an optional note. That goes to the MusicGrid
## server (POST /lm/ratings, kept in its database) with what LevelStats counted while the level was played.
##
## Who it's from: a random id made the first time the option is used (Progress.device_id, kept in the save)
## and a random id per run of the app. Nothing about the phone's owner is sent.
##
## A rating that can't be sent waits in user://ratings_queue.json and goes with the next one, or the next
## time the game starts.

const URL := "https://music-grid-io-42616e204fd3.herokuapp.com/lm/ratings"
const QUEUE := "user://ratings_queue.json"
const MAX_QUEUE := 300
const MAX_NOTE := 500

## The descriptors on the card: [id, emoji, what it says]. Few on purpose: it has to be a glance and a tap.
## The ids are what's stored, so the words and pictures can change.
const TAGS := [
	["too_easy", "😴", "Too easy"],
	["in_my_head", "🧠", "In my head"],
	["trial_error", "🎲", "Guesswork"],
	["aha", "💡", "Aha!"],
	["first_move_trap", "🪤", "Sneaky start"],
	["which_house", "🏠", "Which house?"],
	["thought_bugged", "🐛", "Seemed bugged"],
	["unfair", "😤", "Unfair"],
]

static var _uploader: Uploader


## Where ratings go ("-- --ratings-url=..." points them somewhere else, for testing).
static func url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ratings-url="):
			return a.trim_prefix("--ratings-url=")
	return URL


static func _hex() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


## The rating as the server wants it. answers: {"difficulty", "fun", "frustration": 0-5, "tags": [ids], "note"}.
static func payload(level: LevelData, where: String, answers: Dictionary, stats: Dictionary) -> Dictionary:
	if Progress.device_id == "":
		Progress.set_option("device_id", _hex())
	var clean := {"level_version": version_of(level)}
	for k in stats:
		var v = stats[k]
		clean[str(k)] = snappedf(float(v), 0.01) if (v is float or v is int) else v
	return {
		"id": _hex(),
		"device": Progress.device_id,
		"session": LevelStats.session_id(),
		"level": level.number,
		"level_fp": str(level.fp),
		"title": level.title.substr(0, 60),
		"flavor": level.flavor.substr(0, 24),
		"where": where.substr(0, 40),
		"version": "v%s (%d)" % [Version.NUMBER, Version.BUILD],
		"made_at": Time.get_datetime_string_from_system(true).substr(0, 19),
		"difficulty": int(answers.get("difficulty", 0)),
		"fun": int(answers.get("fun", 0)),
		"frustration": int(answers.get("frustration", 0)),
		"tags": answers.get("tags", []),
		"note": str(answers.get("note", "")).strip_edges().substr(0, MAX_NOTE),
		"stats": clean,
	}


## Which layout of a main level this is: 1 for its first, 2 after its first redesign, ... (from
## levels/level_versions.json, kept by tools/level_versions.gd). 0 if it isn't in the history.
static var _versions := {}

static func version_of(level: LevelData) -> int:
	if _versions.is_empty() and FileAccess.file_exists("res://levels/level_versions.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_versions.json"))
		_versions = d if d is Dictionary else {"": []}
	var seen: Array = _versions.get(str(level.number), [])
	for i in range(seen.size() - 1, -1, -1):
		if int(seen[i]) == level.fp:
			return i + 1
	return 0


static func _read_queue() -> Array:
	if not FileAccess.file_exists(QUEUE):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(QUEUE))
	return d if d is Array else []


static func _write_queue(q: Array) -> void:
	var f := FileAccess.open(QUEUE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(q))


static func waiting() -> int:
	return _read_queue().size()


## Queue a rating and start sending.
static func submit(p: Dictionary) -> void:
	if DebugRemote.on():
		return              # (a simulated playtest: nothing's sent or kept)
	var q := _read_queue()
	q.append(p)
	while q.size() > MAX_QUEUE:
		q.pop_front()
	_write_queue(q)
	LevelStats.rated += 1
	flush()


## Send whatever's waiting (called on submit, and when the game starts).
static func flush() -> void:
	if _read_queue().is_empty():
		return
	if _uploader == null or not is_instance_valid(_uploader):
		_uploader = Uploader.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_uploader)
	else:
		_uploader.kick()


## Sends the queue one at a time, oldest first. A rating leaves the queue when the server has it (or says
## it will never take it); anything else, and the rest wait for next time.
class Uploader:
	extends Node
	var _http: HTTPRequest
	var _busy := false

	func _ready() -> void:
		_http = HTTPRequest.new()
		_http.timeout = 20.0
		_http.request_completed.connect(_on_done)
		add_child(_http)
		kick()

	func kick() -> void:
		if _busy or _http == null:
			return
		var q := Rating._read_queue()
		if q.is_empty():
			return
		var err := _http.request(Rating.url(), PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(q[0]))
		_busy = err == OK
		if err != OK:
			print("[rating] couldn't start sending (%d); %d waiting" % [err, q.size()])

	func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_busy = false
		var q := Rating._read_queue()
		# Taken (201), had it already (200), or refused for good (400, 413): either way it's done with.
		if result == HTTPRequest.RESULT_SUCCESS and code in [200, 201, 400, 413]:
			if not q.is_empty():
				q.pop_front()
				Rating._write_queue(q)
			print("[rating] sent (%d); %d waiting" % [code, q.size()])
			kick()
		else:
			print("[rating] not sent (result %d, code %d); %d waiting" % [result, code, q.size()])
