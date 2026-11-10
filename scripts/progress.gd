extends Node
## Autoload "Progress": which levels are completed, saved to user://save.json.

const PATH := "user://save.json"

var completed := {}


func _ready() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		for n in d.get("completed", []):
			completed[int(n)] = true


func is_complete(n: int) -> bool:
	return completed.has(n)


func mark_complete(n: int) -> void:
	completed[n] = true
	_save()


func reset() -> void:
	completed.clear()
	_save()


## Index (0-based) of the first level not yet completed.
func first_incomplete(count: int) -> int:
	for i in count:
		if not is_complete(i + 1):
			return i
	return 0


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"completed": completed.keys()}))
