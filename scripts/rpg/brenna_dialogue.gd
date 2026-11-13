class_name BrennaDialogue
extends RefCounted
## Conversation with Brenna Gale, harbourmaster of Saltwick. Epic world, dry humour.

const SPEAKER := "Brenna Gale, Harbourmaster"

var window: DialogueWindow
var quests: QuestLog
var progression: Progression
var hud: Hud


func _init(w: DialogueWindow, q: QuestLog, p: Progression, h: Hud) -> void:
	window = w
	quests = q
	progression = p
	hud = h


func start() -> void:
	match quests.state("ashes_on_the_shore"):
		"none":
			_greet()
		"active":
			if quests.can_complete("ashes_on_the_shore"):
				_turn_in()
			else:
				window.show_line(SPEAKER, "Still here? The Hollowed are still there. Five handfuls of Veil Dust, Warden. I'll count them twice.", [["I'm on it.", _bye]])
		_:
			_after()


func _greet() -> void:
	window.show_line(SPEAKER, "A Warden. In Saltwick. And I thought the strangest thing this week was the shard hanging over the vale.", [
		["What is that shard?", _shard],
		["Do you need help?", _offer],
		["Farewell.", _bye],
	])


func _shard() -> void:
	window.show_line(SPEAKER, "A piece of the Crown, the old folk say. Ever since it appeared the Hollowed walk at night, and the sea sounds... quieter. Morvaine doesn't like quiet. Neither do I.", [
		["Do you need help?", _offer],
		["Farewell.", _bye],
	])


func _offer() -> void:
	window.show_line(SPEAKER, "The husks by the old ruins drift down to the beach after dark. They frighten the gulls, and the gulls then frighten me. Put them to rest and bring me five handfuls of Veil Dust as proof.", [
		["I'll do it.", _accept],
		["Why me?", _why],
		["Not now.", _bye],
	])


func _why() -> void:
	window.show_line(SPEAKER, "You're the one with the sword. I have a ledger. Have you ever tried to stab a Hollowed with a ledger? Neither have I, and I'd like to keep it that way.", [
		["Fair. I'll do it.", _accept],
		["Not now.", _bye],
	])


func _accept() -> void:
	quests.start("ashes_on_the_shore")
	hud.show_banner("Quest started", "Ashes on the Shore")
	window.show_line(SPEAKER, "Good. The ruins are inland, past the fence. Mind the claws. And if you find any of my nets out there, no, you didn't.", [["Farewell.", _bye]])


func _turn_in() -> void:
	var q: Dictionary = quests.complete("ashes_on_the_shore")
	progression.add_xp(int(q.get("reward_xp", 0)))
	hud.show_banner("Quest complete", "Ashes on the Shore")
	window.show_line(SPEAKER, "Five handfuls. Cold as a winter tide. The Pale Archive will pay me good coin for these, so here is some of yours. And fish. Everyone gets fish.", [["What now?", _after]])


func _after() -> void:
	if quests.state("the_dark_spire") == "none":
		quests.start("the_dark_spire")
	window.show_line(SPEAKER, "Now? Look up. The Veilspire's light went out three nights ago. The Wardens kept it burning for a thousand years. If anyone should find out why, it's you. The path up the crag isn't finished, mind. Neither is half of Saltwick.", [["I'll see what I can do.", _bye]])


func _bye() -> void:
	window.close()
