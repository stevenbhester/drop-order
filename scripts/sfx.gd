extends Node
## Autoload "Sfx": plays sounds from res://audio/<name>.wav (falls back to synthesis).

var _streams := {}
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
		if not ResourceLoader.exists(p):
			return
		_streams[sound] = load(p)
	var a: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	a.stream = _streams[sound]
	a.pitch_scale = pitch
	a.volume_db = db
	a.play()


## A haptic tap on phones, scaled by the haptics option (0 turns them off); no-op on desktop. `ms` is how
## long the old full-strength buzz was; `strength` (0..1) how hard this one is next to the others.
func haptic(ms: int, strength := 1.0) -> void:
	var h: float = Progress.haptics
	if h <= 0.01 or not OS.has_feature("mobile"):
		return
	var amp := clampf((0.3 + 0.7 * h) * clampf(strength, 0.1, 1.0), 0.05, 1.0)
	Input.vibrate_handheld(maxi(int(ms * (0.6 + 0.8 * h)), 8), amp)
