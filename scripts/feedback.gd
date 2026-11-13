class_name Feedback
extends RefCounted
## What a bug report or a bit of feedback carries, and where it goes. The game posts it to the sign-up
## server (POST /lm/feedback on the MusicGrid server), which files it as an issue in Steven's private
## feedback repo on GitHub (with the screenshot and log stored alongside). The game never holds a GitHub
## token: only the server does.
##
## A report: the player's message, bug or idea, the version and build, where they were, device and game
## details, the end of the game's log (Godot writes it to user://logs/godot.log; file logging is on for
## every platform, iOS included), and a screenshot of what was on screen if they ticked the box.

const URL := "https://music-grid-io-42616e204fd3.herokuapp.com/lm/feedback"


## Where reports go ("-- --feedback-url=..." points them somewhere else, for testing).
static func url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--feedback-url="):
			return a.trim_prefix("--feedback-url=")
	return URL
const LOG_PATH := "user://logs/godot.log"
## The most of the log sent, and of the message (the server refuses more).
const MAX_LOG := 100_000
const MAX_MESSAGE := 3_900


## Where the player was: the screen, and on a level, which one.
static func where_of(screen: Node) -> String:
	if screen is Game:
		var g := screen as Game
		if g._speedrun():
			return "Speedrun %s, zone %d" % [g.side.get("title", ""), g.part + 1]
		if not g.side.is_empty():
			return "Side road %s%s" % [g.side.get("title", ""), (", part %d" % (g.part + 1)) if g._twist() == "mega" else ""]
		if g.daily_day >= 0:
			return "Daily #%d" % Daily.number(g.daily_day)
		return "Level %d" % g.level.number
	if screen is LevelSelect:
		return "Map"
	if screen is TitleScreen:
		return "Title"
	if screen is Garage:
		return "Garage"
	if screen is DailyScreen:
		return "Daily screen"
	if screen is SpeedrunScreen:
		return "Speedrun list"
	return screen.get_class() if screen else "Starting up"


## The last MAX_LOG characters of the game's log (empty if there isn't one).
static func recent_log() -> String:
	if not FileAccess.file_exists(LOG_PATH):
		return ""
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return ""
	var n := f.get_length()
	if n > MAX_LOG:
		f.seek(n - MAX_LOG)
	return f.get_buffer(mini(n, MAX_LOG)).get_string_from_utf8()


## Device and game details, a line each.
static func system_info() -> String:
	var lines := [
		"Game: Last Mile v%s (build %d)" % [Version.NUMBER, Version.BUILD],
		"Device: %s · %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()],
		"Screen: %s, viewport %s" % [DisplayServer.screen_get_size(), Vector2i(Engine.get_main_loop().root.get_visible_rect().size)],
		"Engine: Godot %s" % Engine.get_version_info().get("string", ""),
		"Progress: %d levels done, next %d; momentum %d; gas %d (+%d spare); %d Dollaroos" % [Progress.completed.size(),
			Progress.first_incomplete(100) + 1, Progress.momentum, Progress.gas, Progress.reserve_gas, Progress.dollaroos],
		"Settings: steering %s, queue %s, night %s, sideways %s, colorblind %s, trail %s, hand %s" % [Progress.drive_mode,
			Progress.stack_side, Progress.night, Progress.landscape, Progress.colorblind, Progress.trail, "left" if Progress.left_hand else "right"],
	]
	return "\n".join(lines)


## A screenshot, small enough to send: at most 720 wide, as a JPEG.
static func screenshot_jpeg(img: Image) -> PackedByteArray:
	if img == null or img.is_empty():
		return PackedByteArray()
	var im := img.duplicate() as Image
	if im.get_width() > 720:
		im.resize(720, int(im.get_height() * 720.0 / im.get_width()), Image.INTERPOLATE_BILINEAR)
	im.convert(Image.FORMAT_RGB8)
	return im.save_jpg_to_buffer(0.72)


## The report as the server wants it.
static func payload(kind: String, message: String, where: String, shot: PackedByteArray) -> Dictionary:
	var d := {
		"kind": kind,
		"version": "v%s (%d)" % [Version.NUMBER, Version.BUILD],
		"description": message.strip_edges().substr(0, MAX_MESSAGE),
		"where": where.substr(0, 80),
		"made_at": Time.get_datetime_string_from_system(true).substr(0, 19),
		"system": system_info(),
		"logs": {"godot": recent_log()},
	}
	if shot.size() > 0:
		d["screenshot"] = Marshalls.raw_to_base64(shot)
	return d
