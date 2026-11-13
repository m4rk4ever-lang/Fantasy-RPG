class_name SaveGame
extends Node
## Save and load to one JSON file (user:// is IndexedDB in the web build).
## Never crashes on a missing, corrupt or wrong-version file: it warns and starts fresh.

signal saved
signal loaded

const VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 60.0

var path: String = "user://save_1.json"
var player: Player
## Timed autosave; main turns it on (off in headless test runs).
var autosave: bool = false

var _timer: float = 0.0
var _loading: bool = false


func setup(p: Player) -> void:
	player = p


func _process(delta: float) -> void:
	if not autosave:
		return
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		save_now()


func has_save() -> bool:
	return FileAccess.file_exists(path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func build_data() -> Dictionary:
	var pos: Vector3 = player.global_position
	return {
		"version": VERSION,
		"progression": player.progression.to_dict(),
		"inventory": player.inventory.to_dict(),
		"quests": {"states": player.quests.states.duplicate(), "flags": player.quests.flags.duplicate()},
		"player": {"x": pos.x, "y": pos.y, "z": pos.z, "health": player.health},
	}


## Writes the save file. Skipped while a load is running.
func save_now() -> bool:
	_timer = 0.0
	if _loading or player == null or not is_instance_valid(player):
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(build_data()))
	f.close()
	saved.emit()
	return true


## Loads the save file. Returns false (and changes nothing) on any problem.
func load_game() -> bool:
	if not has_save():
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SaveGame: cannot read %s" % path)
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveGame: corrupt save file, starting fresh")
		return false
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != VERSION:
		push_warning("SaveGame: unsupported save version %s, starting fresh" % str(d.get("version")))
		return false
	_apply(d)
	loaded.emit()
	return true


func _apply(d: Dictionary) -> void:
	_loading = true
	var prog: Variant = d.get("progression", {})
	if prog is Dictionary:
		player.progression.load_dict(prog)
	var inv: Variant = d.get("inventory", {})
	if inv is Dictionary:
		player.inventory.load_dict(inv)
	var q: Variant = d.get("quests", {})
	if q is Dictionary:
		var ql: QuestLog = player.quests
		ql.states = {}
		ql.flags = {}
		var st: Variant = (q as Dictionary).get("states", {})
		if st is Dictionary:
			for k: Variant in (st as Dictionary).keys():
				ql.states[str(k)] = str((st as Dictionary)[k])
		var fl: Variant = (q as Dictionary).get("flags", {})
		if fl is Dictionary:
			for k: Variant in (fl as Dictionary).keys():
				ql.flags[str(k)] = bool((fl as Dictionary)[k])
		if ql.state(QuestLog.STORY_QUEST) == "none":
			ql.states[QuestLog.STORY_QUEST] = "active"
		ql.changed.emit()
	var pl: Variant = d.get("player", {})
	if pl is Dictionary:
		var pd: Dictionary = pl
		var pos := Vector3(float(pd.get("x", 0.0)), float(pd.get("y", 0.0)), float(pd.get("z", 0.0)))
		if pd.has("x") and pd.has("y") and pd.has("z") and is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z):
			player.global_position = pos + Vector3.UP * 0.3
			player.velocity = Vector3.ZERO
		var hp: float = float(pd.get("health", player.max_health))
		if is_finite(hp):
			player.health = clampf(hp, 1.0, player.max_health)
			player.health_changed.emit(player.health, player.max_health)
	_loading = false
