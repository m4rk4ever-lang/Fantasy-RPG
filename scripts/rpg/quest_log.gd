class_name QuestLog
extends Node
## Quest states and objectives. Quests: "none" -> "active" -> "done".

signal changed

const QUESTS: Dictionary = {
	"ashes_on_the_shore": {
		"name": "Ashes on the Shore",
		"giver": "Brenna Gale, Harbourmaster of Saltwick",
		"summary": "The Hollowed drift down from the ruins and scare the gulls. Bring Brenna 5 Veil Dust as proof you dealt with them.",
		"item": "veil_dust", "needed": 5,
		"reward_xp": 150, "reward_coins": 50, "reward_items": [["salted_fish", 3]],
	},
	"the_dark_spire": {
		"name": "The Dark Spire",
		"giver": "Brenna Gale, Harbourmaster of Saltwick",
		"summary": "The light of the Veilspire above the vale went out three nights ago. Find out why. (Coming soon.)",
	},
}

var states: Dictionary = {}
var inventory: Inventory


func state(id: String) -> String:
	return states.get(id, "none")


func start(id: String) -> void:
	states[id] = "active"
	changed.emit()


func progress(id: String) -> int:
	var q: Dictionary = QUESTS[id]
	if not q.has("item") or inventory == null:
		return 0
	return mini(inventory.count_of(q["item"]), int(q["needed"]))


func can_complete(id: String) -> bool:
	var q: Dictionary = QUESTS[id]
	return state(id) == "active" and q.has("item") and progress(id) >= int(q["needed"])


## Hands in the items and returns the rewards; the caller grants XP.
func complete(id: String) -> Dictionary:
	if not can_complete(id):
		return {}
	var q: Dictionary = QUESTS[id]
	inventory.remove(q["item"], int(q["needed"]))
	inventory.add("coins", int(q.get("reward_coins", 0)))
	for it: Array in q.get("reward_items", []):
		inventory.add(it[0], it[1])
	states[id] = "done"
	changed.emit()
	return q


## One-line objective for the HUD tracker. Empty when nothing is active.
func tracker_text() -> String:
	for id: String in QUESTS.keys():
		if state(id) == "active":
			var q: Dictionary = QUESTS[id]
			if q.has("item"):
				var item_name: String = Inventory.item_data(q["item"])["name"]
				var done: bool = progress(id) >= int(q["needed"])
				return "%s\n%s %d/%d%s" % [q["name"], item_name, progress(id), int(q["needed"]), "  · return to Brenna" if done else ""]
			return "%s\n%s" % [q["name"], q["summary"]]
	return ""
