class_name UpdateCheck
extends Node
## Is there a newer build in TestFlight? At launch (and on coming back after a while) this reads
## release/latest.json from the game's public GitHub repo: the newest build's number, version, name, a few
## of its notes and when it's ready (tools/testflight.sh writes it with each archive, ready an hour later to
## give Apple time to process the upload). If that build is newer than this one, `latest` holds it and
## `found` fires; the title screen then offers the update (UpdateCard). Any failure (offline, a bad file)
## just means no offer.
##   --latest-file=<path> reads a local file instead (for tests); --latest-url=<url> another address.

signal found(info: Dictionary)

const URL := "https://raw.githubusercontent.com/stevenbhester/drop-order/main/release/latest.json"
## Coming back to the game after this long checks again.
const RECHECK_SECS := 1800.0

## The newer build on offer ({version, name, build, notes, ...}), or empty.
static var latest: Dictionary = {}

var _http: HTTPRequest
var _checked_at := -1.0e9


static func available() -> bool:
	return not latest.is_empty()


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	_http.request_completed.connect(_on_done)
	add_child(_http)
	check()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if Time.get_ticks_msec() / 1000.0 - _checked_at > RECHECK_SECS:
			check()


func check() -> void:
	_checked_at = Time.get_ticks_msec() / 1000.0
	var url := URL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--latest-file="):
			_take(FileAccess.get_file_as_string(a.trim_prefix("--latest-file=")))
			return
		if a.begins_with("--latest-url="):
			url = a.trim_prefix("--latest-url=")
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	# A fresh copy each time (GitHub caches the file for a few minutes otherwise).
	var err := _http.request("%s?t=%d" % [url, int(Time.get_unix_time_from_system())])
	if err != OK:
		print("[update] couldn't ask (%s)" % error_string(err))


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("[update] no answer (result %d, HTTP %d)" % [result, code])
		return
	_take(body.get_string_from_utf8())


func _take(text: String) -> void:
	var d = JSON.parse_string(text)
	if not d is Dictionary or not d.has("build"):
		print("[update] couldn't read the latest-build file")
		return
	var build := int(d["build"])
	var ready_at := float(d.get("ready_at", 0))
	var newer := build > Version.BUILD and Time.get_unix_time_from_system() >= ready_at
	print("[update] newest build %d (this is %d)%s" % [build, Version.BUILD, ": offering it" if newer else ""])
	if newer:
		latest = d
		found.emit(d)


## Opens the TestFlight app, where the update is waiting under Last Mile (its web page elsewhere).
static func open_testflight() -> void:
	if OS.get_name() == "iOS" and OS.shell_open("itms-beta://") == OK:
		print("[update] opened TestFlight")
		return
	OS.shell_open("https://testflight.apple.com/")
