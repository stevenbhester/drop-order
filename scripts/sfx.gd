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
		return
	var a: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	a.stream = _streams[sound]
	a.pitch_scale = pitch
	a.volume_db = db
	a.play()


## Light haptic tap on phones; no-op on desktop.
func haptic(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
