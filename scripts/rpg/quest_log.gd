class_name QuestLog
extends Node
## Quests with explicit steps, plus the main story split into chapters.
## Quest states: "none" -> "active" -> "done". Steps are derived from states, flags and items,
## so the log always shows exactly where the player stands.

signal changed

const STORY_QUEST := "the_last_warden"

const QUESTS: Dictionary = {
	"the_last_warden": {
		"name": "The Last Warden", "main": true, "chapter": "Chapter I: The Last Warden",
		"giver": "The story",
		"summary": "You woke in a green vale beneath a Veilspire whose light has gone out. A shard of the Sundered Crown hangs in the sky. You are the last of the Wardens, and you remember very little.",
	},
	"ashes_on_the_shore": {
		"name": "Ashes on the Shore", "main": false,
		"giver": "Brenna Gale, Harbourmaster of Saltwick",
		"summary": "The Hollowed drift down from the ruins and scare the gulls. Bring Brenna 5 Veil Dust as proof you dealt with them.",
		"item": "veil_dust", "needed": 5,
		"reward_xp": 150, "reward_coins": 50, "reward_items": [["salted_fish", 3]],
	},
	"the_dark_spire": {
		"name": "The Dark Spire", "main": true, "chapter": "Chapter I: The Last Warden",
		"giver": "Brenna Gale, Harbourmaster of Saltwick",
		"summary": "The light of the Veilspire above the vale went out three nights ago. The Wardens kept it burning for a thousand years. Find out why.",
	},
}

var states: Dictionary = {}
## Story flags set by dialogue and events (e.g. "met_brenna").
var flags: Dictionary = {}
var inventory: Inventory


func _ready() -> void:
	if state(STORY_QUEST) == "none":
		states[STORY_QUEST] = "active"


func state(id: String) -> String:
	return states.get(id, "none")


func start(id: String) -> void:
	states[id] = "active"
	changed.emit()


func set_flag(flag: String) -> void:
	if not flags.get(flag, false):
		flags[flag] = true
		changed.emit()


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


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


## Steps of a quest: Array of {"text": String, "done": bool}. The first not-done step is "current".
func steps(id: String) -> Array:
	match id:
		"the_last_warden":
			return [
				{"text": "Wake beneath the Veilspire.", "done": true},
				{"text": "Find help in Saltwick, the fishing village on the coast to the south-east.", "done": has_flag("met_brenna")},
				{"text": "Help Brenna Gale with the Hollowed (Ashes on the Shore).", "done": state("ashes_on_the_shore") == "done"},
				{"text": "Find out why the Veilspire's light went out (The Dark Spire).", "done": state("the_dark_spire") == "done"},
			]
		"ashes_on_the_shore":
			var need: int = int(QUESTS[id]["needed"])
			return [
				{"text": "Talk to Brenna Gale at the pier head in Saltwick.", "done": state(id) != "none"},
				{"text": "Defeat the Hollowed at the old ruins and collect Veil Dust (%d/%d)." % [progress(id) if state(id) == "active" else (need if state(id) == "done" else 0), need], "done": state(id) == "done" or progress(id) >= need},
				{"text": "Return to Brenna Gale in Saltwick.", "done": state(id) == "done"},
			]
		"the_dark_spire":
			return [
				{"text": "Hear Brenna out about the Veilspire.", "done": state(id) != "none"},
				{"text": "Climb the crag to the Veilspire. (The path is not open yet. Coming soon.)", "done": false},
			]
	return []


func current_step(id: String) -> String:
	for st: Dictionary in steps(id):
		if not st["done"]:
			return st["text"]
	return ""


## Two short lines for the HUD tracker: the story step and the active side quest.
func tracker_text() -> String:
	var lines: Array[String] = []
	var story_quest: String = "the_dark_spire" if state("the_dark_spire") == "active" else STORY_QUEST
	var step: String = current_step(story_quest)
	if step != "":
		lines.append("Story: " + step)
	for id: String in QUESTS.keys():
		if not QUESTS[id].get("main", false) and state(id) == "active":
			lines.append("%s: %s" % [QUESTS[id]["name"], current_step(id)])
	return "\n".join(lines)


## Marker over a quest giver: "!" new quest, "?" ready to hand in, "" nothing.
func giver_marker() -> String:
	if can_complete("ashes_on_the_shore"):
		return "?"
	if state("ashes_on_the_shore") == "none":
		return "!"
	if state("ashes_on_the_shore") == "done" and state("the_dark_spire") == "none":
		return "!"
	return ""
