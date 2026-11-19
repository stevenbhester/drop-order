extends Node
## Autoload "Sfx": plays sounds from res://audio/<name>.wav (falls back to synthesis).

var _streams := {}
## Haptics wait while the app's put away and for a moment after it's back (a testers' report: the phone buzzed
## nonstop on coming back to the game), and never come closer together than HAPTIC_GAP, so nothing can pile up.
const HAPTIC_GAP := 0.035
const BACK_QUIET := 0.6
var _away := false
var _back_at := -10.0
var _last_haptic := -10.0
var _players: Array = []
var _next := 0


func _ready() -> void:
	for n in SfxSynth.NAMES:
		var p := "res://audio/%s.wav" % n
		_streams[n] = load(p) if ResourceLoader.exists(p) else SfxSynth.make(n)
	for i in 12:
		var a := AudioStreamPlayer.new()
		add_child(a)
		_players.append(a)


func play(sound: String, pitch := 1.0, db := 0.0) -> void:
	if not _streams.has(sound):
		# Sounds without a synth fallback (the studio card's) are loaded the first time they're played.
		var p := "res://audio/%s.wav" % sound
		if ResourceLoader.exists(p):
			_streams[sound] = load(p)
		elif sound in SfxSynth.LAZY:
			_streams[sound] = SfxSynth.make(sound)
		else:
			return
	var a: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	a.stream = _streams[sound]
	a.pitch_scale = pitch
	a.volume_db = db
	a.play()


## Testing: every haptic call is printed as it happens (-- --log-haptics).
var _log_haptics := OS.get_cmdline_user_args().has("--log-haptics")
## The last HAPTIC_KEEP haptic calls, for a bug report (Feedback): [time, ms, what asked, what happened].
const HAPTIC_KEEP := 30
var _recent_haptics: Array = []
## A burst (more than BURST_MAX in a second) is written to the log, once a second while it lasts: one line,
## so a phone that buzzes nonstop leaves a trace of what was asking.
const BURST_MAX := 25
var _burst_from := 0.0
var _burst_n := 0
var _burst_said := -10.0


## A haptic tap on phones, scaled by the haptics option (0 turns them off); no-op on desktop. `ms` is how
## long the old full-strength buzz was; `strength` (0..1) how hard this one is next to the others; `why`
## where it came from ("game:_win": a phone build can't tell, so every call says).
func haptic(ms: int, strength := 1.0, why := "") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var skip := "away" if _away else ("just back" if now - _back_at < BACK_QUIET else ("too soon" if now - _last_haptic < HAPTIC_GAP else ""))
	_recent_haptics.append([now, ms, why, skip])
	if _recent_haptics.size() > HAPTIC_KEEP:
		_recent_haptics.pop_front()
	if now - _burst_from > 1.0:
		_burst_from = now
		_burst_n = 0
	_burst_n += 1
	if _burst_n > BURST_MAX and now - _burst_said > 1.0:
		_burst_said = now
		print("[haptic] burst: %d in a second, latest from %s%s" % [_burst_n, why, " (app away)" if _away else ""])
	if _log_haptics:
		print("HAPTIC %d ms at %.2f from %s%s" % [ms, now, why, " SKIPPED (" + skip + ")" if skip != "" else ""])
	if skip != "":
		return
	_last_haptic = now
	var h: float = Progress.haptics
	if h <= 0.01 or not OS.has_feature("mobile"):
		return
	var amp := clampf((0.3 + 0.7 * h) * clampf(strength, 0.1, 1.0), 0.05, 1.0)
	Input.vibrate_handheld(maxi(int(ms * (0.6 + 0.8 * h)), 8), amp)


## The last few haptic calls, a line each (oldest first), for a bug report.
func haptic_report() -> String:
	var now := Time.get_ticks_msec() / 1000.0
	var lines := ["[haptics] the last %d, newest last (seconds ago, ms, from, skipped?):" % _recent_haptics.size()]
	for r in _recent_haptics:
		lines.append("  -%.2fs %dms %s%s" % [now - float(r[0]), int(r[1]), str(r[2]) if str(r[2]) != "" else "?", "  skipped: " + str(r[3]) if str(r[3]) != "" else ""])
	return "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _away:
			print("[app] away")          # (in the log a bug report sends: when the game was put away and back)
		_away = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _away:
			print("[app] back")
		_away = false
		_back_at = Time.get_ticks_msec() / 1000.0
