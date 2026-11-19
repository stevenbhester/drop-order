extends Node
## Autoload "Music": the background music, everywhere but the title (TitleScreen plays its own theme, and
## drives its street from it). Main says what should be playing as the screen changes; this fades it in and
## out, loops it, and keeps quiet while anything in HUSH_GROUP is up (ads and the Baron's scenes: they have
## their own sound). Options' Music switch turns it off; the Sound slider is the master volume, as ever.
##
## The tunes are composed and rendered by tools/make_sunrise.py and tools/make_chill.py (and tools/make_theme.py
## for the title's).

## "sunrise" is the background music. "chill" (thinking hard, then an aha, over and over) is kept for wherever
## it turns out to belong; nothing plays it yet.
const TRACKS := {"sunrise": "res://audio/sunrise.wav", "chill": "res://audio/chill.wav"}
const DB := -13.0
const SILENT := -50.0
const HUSH_GROUP := "hush_music"

var _player: AudioStreamPlayer
var _want := ""
var _on := ""
var _hushed := false
var _tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	add_child(_player)
	Progress.settings_changed.connect(_sync)


## Plays `track` (a key of TRACKS) from now on. Asking for what's already playing changes nothing.
func play(track: String) -> void:
	_want = track
	_sync()


func stop() -> void:
	_want = ""
	_sync()


func _process(_delta: float) -> void:
	var hush := not get_tree().get_nodes_in_group(HUSH_GROUP).is_empty()
	if hush == _hushed:
		return
	_hushed = hush
	if _on == "":
		return
	if hush:
		_fade(SILENT, 0.4).tween_callback(func(): _player.stream_paused = true)
	else:
		_player.stream_paused = false
		_fade(DB, 1.2)


func _sync() -> void:
	var want := _want if Progress.music and TRACKS.has(_want) else ""
	if want == _on:
		return
	_on = want
	if want == "":
		_fade(SILENT, 0.4).tween_callback(_player.stop)
		return
	var path: String = TRACKS[want]
	if not ResourceLoader.exists(path):
		_on = ""
		return
	var st := load(path) as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(round(st.get_length() * st.mix_rate))
	_player.stream = st
	_player.volume_db = SILENT
	_player.stream_paused = false
	_player.play()
	if _hushed:
		_player.stream_paused = true
	else:
		_fade(DB, 1.2)


func _fade(to: float, secs: float) -> Tween:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_player, "volume_db", to, secs)
	return _tw
