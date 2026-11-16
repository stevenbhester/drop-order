class_name ShareSheet
extends RefCounted
## The phone's own share sheet ("send this with..."), with the player's frequent chats along the top. On iOS
## the native plugin opens it (ios/plugins/src/LastMileNotify.mm watches for user://lastmile_share.json and
## presents a UIActivityViewController with its text). Anywhere else there isn't one: open() says false and
## the caller falls back (copying the text).

const FILE := "user://lastmile_share.json"


## Asks for the share sheet with `text`. True if it's on its way.
static func open(text: String) -> bool:
	if OS.get_name() != "iOS":
		return false
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"text": text}))
	f.close()
	return true
