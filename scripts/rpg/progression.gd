class_name Progression
extends Node
## Hero progression: class, level, XP, skill points, skill-tree ranks and faction allegiance.
## Allegiance never affects the class (owner's choice, 13-11-2026).

signal xp_changed(xp: int, xp_to_next: int, level: int)
signal leveled_up(level: int)
signal ranks_changed
signal allegiance_changed(faction_id: String)

## Character levels in WoW style (owner, 13-11-2026): one level for the hero, cap 60.
const MAX_LEVEL: int = 60

var class_id: String = "vanguard"
var faction_id: String = ""
var level: int = 1
var xp: int = 0
var skill_points: int = 1
var ranks: Dictionary = {}  # node_id -> rank


func _ready() -> void:
	_grant_free_nodes()


func _grant_free_nodes() -> void:
	var c: Dictionary = ClassData.get_class_data(class_id)
	for b: Dictionary in c.get("branches", []):
		for n: Dictionary in b["nodes"]:
			if n.get("free", false) and get_rank(n["id"]) == 0:
				ranks[n["id"]] = 1


## XP curve: quick early levels, steeper later (level 1: 100, level 10: ~3.200, level 59: ~59.000).
func xp_to_next() -> int:
	return int(round(100.0 * pow(float(level), 1.55)))


## XP for defeating a monster, scaled by the level difference (grey mobs give little).
static func kill_xp(mob_level: int, hero_level: int) -> int:
	var base: float = 45.0 + 5.0 * mob_level
	var diff: int = mob_level - hero_level
	var mult: float = clampf(1.0 + 0.1 * diff, 0.1, 1.5)
	if diff <= -8:
		mult = 0.0
	return int(round(base * mult))


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		skill_points += 1
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
	xp_changed.emit(xp, xp_to_next(), level)


func get_rank(node_id: String) -> int:
	return int(ranks.get(node_id, 0))


## Requirement: the explicit `requires` node, or else the previous node in the branch.
func requirement_of(node_id: String) -> String:
	var c: Dictionary = ClassData.get_class_data(class_id)
	for b: Dictionary in c.get("branches", []):
		var nodes: Array = b["nodes"]
		for i: int in nodes.size():
			if nodes[i]["id"] == node_id:
				if nodes[i].has("requires"):
					return nodes[i]["requires"]
				return nodes[i - 1]["id"] if i > 0 else ""
	return ""


func can_rank_up(node_id: String) -> bool:
	var c: Dictionary = ClassData.get_class_data(class_id)
	if not c.get("playable", false) or skill_points <= 0:
		return false
	var n: Dictionary = ClassData.get_node_data(class_id, node_id)
	if n.is_empty() or get_rank(node_id) >= int(n.get("max", 1)):
		return false
	var req: String = requirement_of(node_id)
	return req == "" or get_rank(req) > 0


func rank_up(node_id: String) -> bool:
	if not can_rank_up(node_id):
		return false
	ranks[node_id] = get_rank(node_id) + 1
	skill_points -= 1
	ranks_changed.emit()
	return true


## Sum of a passive stat over all ranked nodes.
func stat(key: String) -> float:
	var total: float = 0.0
	var c: Dictionary = ClassData.get_class_data(class_id)
	for b: Dictionary in c.get("branches", []):
		for n: Dictionary in b["nodes"]:
			var r: int = get_rank(n["id"])
			if r > 0 and n.has("stats"):
				total += float((n["stats"] as Dictionary).get(key, 0.0)) * r
	return total


func is_skill_unlocked(skill_id: String) -> bool:
	var c: Dictionary = ClassData.get_class_data(class_id)
	for b: Dictionary in c.get("branches", []):
		for n: Dictionary in b["nodes"]:
			if n.get("skill", "") == skill_id:
				return get_rank(n["id"]) > 0
	return false


func set_allegiance(id: String) -> void:
	faction_id = id
	allegiance_changed.emit(id)
