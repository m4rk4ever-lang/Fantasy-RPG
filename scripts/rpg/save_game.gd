class_name SaveGame
extends RefCounted
## Save and load the hero's progress to user:// (IndexedDB in the browser build).
## Saves: level, XP, skill ranks, allegiance, backpack, quests, action bar, run/retaliate, position.

const PATH := "user://savegame.json"
const VERSION: int = 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


static func save(player: Player, bar: ActionBar) -> bool:
	var prog: Progression = player.progression
	var bar_data: Array = []
	for e: Dictionary in bar.entries:
		bar_data.append({"type": e.get("type", ""), "id": e.get("id", "")})
	var data := {
		"version": VERSION,
		"progression": {"class_id": prog.class_id, "faction_id": prog.faction_id, "level": prog.level, "xp": prog.xp, "skill_points": prog.skill_points, "ranks": prog.ranks},
		"inventory": {"coins": player.inventory.coins, "slots": player.inventory.slots},
		"quests": {"states": player.quests.states, "flags": player.quests.flags},
		"bar": bar_data,
		"run": player.run_enabled,
		"retaliate": player.auto_retaliate,
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


## Returns the parsed save or {} when there is none (or it is unreadable).
static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	return parsed


static func apply(data: Dictionary, player: Player, bar: ActionBar) -> void:
	var p: Dictionary = data.get("progression", {})
	var prog: Progression = player.progression
	prog.class_id = p.get("class_id", "vanguard")
	prog.faction_id = p.get("faction_id", "")
	prog.level = int(p.get("level", 1))
	prog.xp = int(p.get("xp", 0))
	prog.skill_points = int(p.get("skill_points", 1))
	prog.ranks.clear()
	for k: String in (p.get("ranks", {}) as Dictionary).keys():
		prog.ranks[k] = int(p["ranks"][k])
	var inv: Dictionary = data.get("inventory", {})
	player.inventory.coins = int(inv.get("coins", 0))
	var slots: Array = inv.get("slots", [])
	for i: int in mini(slots.size(), Inventory.SLOTS):
		var s: Dictionary = slots[i]
		player.inventory.slots[i] = {} if s.is_empty() else {"id": str(s["id"]), "count": int(s["count"])}
	var q: Dictionary = data.get("quests", {})
	player.quests.states = (q.get("states", {}) as Dictionary).duplicate()
	player.quests.flags = (q.get("flags", {}) as Dictionary).duplicate()
	var b: Array = data.get("bar", [])
	for i2: int in mini(b.size(), ActionBar.SLOTS):
		var e: Dictionary = b[i2]
		match e.get("type", ""):
			"skill":
				bar.assign(i2, PlayerCombat.skill_entry(e["id"]))
			"item":
				var d: Dictionary = Inventory.item_data(e["id"])
				bar.assign(i2, {"type": "item", "id": e["id"], "name": d.get("name", ""), "desc": d.get("desc", ""), "color": d.get("color", Color.WHITE), "icon": 4})
			_:
				bar.assign(i2, {})
	player.set_run(bool(data.get("run", true)))
	player.set_auto_retaliate(bool(data.get("retaliate", true)))
	var pos: Array = data.get("position", [])
	if pos.size() == 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]) + 0.3, float(pos[2]))
	prog.ranks_changed.emit()
	prog.xp_changed.emit(prog.xp, prog.xp_to_next(), prog.level)
	player.inventory.changed.emit()
	player.quests.changed.emit()
