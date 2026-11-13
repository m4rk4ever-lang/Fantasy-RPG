class_name Inventory
extends Node
## RuneScape-style backpack: 28 slots, stackable items, coins kept separately.

signal changed

const SLOTS: int = 28
const ITEMS: Dictionary = {
	"veil_dust": {"name": "Veil Dust", "desc": "What is left of a Hollowed. Faintly cold. The Pale Archive pays for it.", "stack": true, "color": Color("c9c6b8"), "value": 4},
	"warden_sigil": {"name": "Warden's Sigil", "desc": "A tarnished badge of the Wardens. Someone wore this once, and forgot.", "stack": true, "color": Color("d9a441"), "value": 15},
	"hollow_fang": {"name": "Hollow Claw", "desc": "Long, bone-white and still sharp. Do not use as a toothpick.", "stack": true, "color": Color("e6e1d3"), "value": 8},
	"salted_fish": {"name": "Salted Fish", "desc": "Heals 20 health. Tastes like the sea, mostly the salty part.", "stack": true, "color": Color("6ec3f0"), "value": 3, "heal": 20.0},
}

var coins: int = 0
## Each slot: {} or {"id": String, "count": int}
var slots: Array[Dictionary] = []


func _init() -> void:
	slots.resize(SLOTS)
	for i: int in SLOTS:
		slots[i] = {}


static func item_data(id: String) -> Dictionary:
	return ITEMS.get(id, {})


func add(id: String, count: int = 1) -> bool:
	if id == "coins":
		coins += count
		changed.emit()
		return true
	var data: Dictionary = item_data(id)
	if data.is_empty():
		return false
	if data.get("stack", false):
		for s: Dictionary in slots:
			if s.get("id", "") == id:
				s["count"] = int(s["count"]) + count
				changed.emit()
				return true
	for i: int in SLOTS:
		if slots[i].is_empty():
			slots[i] = {"id": id, "count": count}
			changed.emit()
			return true
	return false  # Backpack full.


func count_of(id: String) -> int:
	var total: int = 0
	for s: Dictionary in slots:
		if s.get("id", "") == id:
			total += int(s["count"])
	return total


func remove(id: String, count: int = 1) -> bool:
	if count_of(id) < count:
		return false
	var left: int = count
	for i: int in SLOTS:
		if left <= 0:
			break
		if slots[i].get("id", "") == id:
			var take: int = mini(left, int(slots[i]["count"]))
			slots[i]["count"] = int(slots[i]["count"]) - take
			left -= take
			if int(slots[i]["count"]) <= 0:
				slots[i] = {}
	changed.emit()
	return true
