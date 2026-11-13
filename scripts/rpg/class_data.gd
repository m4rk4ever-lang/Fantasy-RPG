class_name ClassData
extends RefCounted
## Static data for classes, skill trees and factions.
## Each class has 3 branches of 4 nodes. Actives map to combat skills; passives add stats per rank.
## Stat keys: damage_mult, max_health, damage_taken_mult, move_speed_mult, cooldown_mult,
## dodge_cost_mult, execute_bonus (extra damage vs targets under 30% health).

const CLASSES: Array[Dictionary] = [
	{
		"id": "vanguard", "name": "Vanguard", "playable": true, "color": Color("3d5ba9"),
		"role": "Melee. Sword and steel, in the thick of it.",
		"branches": [
			{"name": "Blade", "nodes": [
				{"id": "cleave", "name": "Cleave", "kind": "active", "skill": "cleave", "max": 1, "free": true, "desc": "Two-handed slam. The shockwave hits everything around the impact."},
				{"id": "keen_edge", "name": "Keen Edge", "kind": "passive", "max": 3, "requires": "cleave", "stats": {"damage_mult": 0.08}, "desc": "+8% damage per rank."},
				{"id": "whirlwind", "name": "Whirlwind", "kind": "active", "skill": "whirlwind", "max": 1, "requires": "keen_edge", "desc": "Spin twice, striking every enemy around you."},
				{"id": "executioner", "name": "Executioner", "kind": "passive", "max": 2, "requires": "whirlwind", "stats": {"execute_bonus": 0.25}, "desc": "+25% damage per rank against enemies below 30% health."},
			]},
			{"name": "Bulwark", "nodes": [
				{"id": "second_wind", "name": "Second Wind", "kind": "active", "skill": "second_wind", "max": 1, "desc": "Restore 35 health and all stamina."},
				{"id": "iron_skin", "name": "Iron Skin", "kind": "passive", "max": 3, "requires": "second_wind", "stats": {"max_health": 15.0}, "desc": "+15 maximum health per rank."},
				{"id": "unbroken", "name": "Unbroken", "kind": "passive", "max": 2, "requires": "iron_skin", "stats": {"damage_taken_mult": -0.1}, "desc": "Take 10% less damage per rank."},
				{"id": "last_stand", "name": "Last Stand", "kind": "passive", "max": 1, "requires": "unbroken", "stats": {"max_health": 40.0}, "desc": "+40 maximum health. Wardens do not fall easily."},
			]},
			{"name": "Momentum", "nodes": [
				{"id": "surge", "name": "Surge Strike", "kind": "active", "skill": "surge", "max": 1, "desc": "Dash to your target and cut through it. Untouchable while dashing."},
				{"id": "fleet_foot", "name": "Fleet Foot", "kind": "passive", "max": 2, "requires": "surge", "stats": {"move_speed_mult": 0.06}, "desc": "+6% movement speed per rank."},
				{"id": "battle_rhythm", "name": "Battle Rhythm", "kind": "passive", "max": 2, "requires": "fleet_foot", "stats": {"cooldown_mult": -0.1}, "desc": "Skill cooldowns 10% shorter per rank."},
				{"id": "relentless", "name": "Relentless", "kind": "passive", "max": 1, "requires": "battle_rhythm", "stats": {"dodge_cost_mult": -0.5}, "desc": "Dodging costs half the stamina."},
			]},
		],
	},
	{
		"id": "ranger", "name": "Ranger", "playable": false, "color": Color("4cb46a"),
		"role": "Ranged. Bow, traps and the wind at your back.",
		"branches": [
			{"name": "Marksman", "nodes": [{"id": "piercing_shot", "name": "Piercing Shot", "kind": "active", "max": 1, "desc": "An arrow that passes through every enemy in a line."}, {"id": "steady_aim", "name": "Steady Aim", "kind": "passive", "max": 1, "desc": "+8% ranged damage per rank."}, {"id": "volley", "name": "Volley", "kind": "active", "max": 1, "desc": "Rain arrows on an area."}, {"id": "headhunter", "name": "Headhunter", "kind": "passive", "max": 1, "desc": "Critical hits deal more damage."}]},
			{"name": "Trapper", "nodes": [{"id": "snare", "name": "Snare", "kind": "active", "max": 1, "desc": "Root an enemy in place."}, {"id": "barbed", "name": "Barbed Traps", "kind": "passive", "max": 1, "desc": "Traps make enemies bleed."}, {"id": "decoy", "name": "Decoy", "kind": "active", "max": 1, "desc": "A straw Warden that draws aggro. Surprisingly convincing."}, {"id": "ambush", "name": "Ambush", "kind": "passive", "max": 1, "desc": "First hit on an unaware enemy deals double damage."}]},
			{"name": "Wind", "nodes": [{"id": "roll", "name": "Wind Step", "kind": "active", "max": 1, "desc": "A long evasive roll."}, {"id": "light_feet", "name": "Light Feet", "kind": "passive", "max": 1, "desc": "+movement speed."}, {"id": "gale_arrow", "name": "Gale Arrow", "kind": "active", "max": 1, "desc": "Knocks enemies back."}, {"id": "tailwind", "name": "Tailwind", "kind": "passive", "max": 1, "desc": "Shorter cooldowns while moving."}]},
		],
	},
	{
		"id": "arcanist", "name": "Arcanist", "playable": false, "color": Color("6ec3f0"),
		"role": "Magic. Frost, flame and the old song of the Ascendants.",
		"branches": [
			{"name": "Frost", "nodes": [{"id": "frost_bolt", "name": "Frost Bolt", "kind": "active", "max": 1, "desc": "Slows the target."}, {"id": "deep_cold", "name": "Deep Cold", "kind": "passive", "max": 1, "desc": "Slows last longer."}, {"id": "ice_wall", "name": "Ice Wall", "kind": "active", "max": 1, "desc": "Raise a wall of ice."}, {"id": "shatter", "name": "Shatter", "kind": "passive", "max": 1, "desc": "Frozen enemies take extra damage."}]},
			{"name": "Flame", "nodes": [{"id": "fireball", "name": "Fireball", "kind": "active", "max": 1, "desc": "Explodes on impact."}, {"id": "kindling", "name": "Kindling", "kind": "passive", "max": 1, "desc": "Burning lasts longer."}, {"id": "flame_wave", "name": "Flame Wave", "kind": "active", "max": 1, "desc": "A cone of fire."}, {"id": "inferno", "name": "Inferno", "kind": "passive", "max": 1, "desc": "Fire spreads between enemies."}]},
			{"name": "Aether", "nodes": [{"id": "blink", "name": "Blink", "kind": "active", "max": 1, "desc": "Teleport a short distance."}, {"id": "focus", "name": "Focus", "kind": "passive", "max": 1, "desc": "+mana regeneration."}, {"id": "arcane_orb", "name": "Arcane Orb", "kind": "active", "max": 1, "desc": "A slow orb that hits everything it passes."}, {"id": "resonance", "name": "Resonance", "kind": "passive", "max": 1, "desc": "Spells echo once."}]},
		],
	},
	{
		"id": "priest", "name": "Priest", "playable": false, "color": Color("e6e1d3"),
		"role": "Light and mercy. Heals allies, burns the Hollowed.",
		"branches": [
			{"name": "Light", "nodes": [{"id": "smite", "name": "Smite", "kind": "active", "max": 1, "desc": "Holy damage, extra against the Hollowed."}, {"id": "radiance", "name": "Radiance", "kind": "passive", "max": 1, "desc": "+holy damage."}, {"id": "sunburst", "name": "Sunburst", "kind": "active", "max": 1, "desc": "Damage and blind around you."}, {"id": "dawnbringer", "name": "Dawnbringer", "kind": "passive", "max": 1, "desc": "Smite heals you."}]},
			{"name": "Mercy", "nodes": [{"id": "mend", "name": "Mend", "kind": "active", "max": 1, "desc": "Heal over time."}, {"id": "grace", "name": "Grace", "kind": "passive", "max": 1, "desc": "+healing done."}, {"id": "sanctuary", "name": "Sanctuary", "kind": "active", "max": 1, "desc": "A circle that shields everyone inside."}, {"id": "martyr", "name": "Martyr", "kind": "passive", "max": 1, "desc": "Healing others also heals you."}]},
			{"name": "Judgement", "nodes": [{"id": "condemn", "name": "Condemn", "kind": "active", "max": 1, "desc": "Mark an enemy to take more damage."}, {"id": "zeal", "name": "Zeal", "kind": "passive", "max": 1, "desc": "+attack speed after healing."}, {"id": "verdict", "name": "Verdict", "kind": "active", "max": 1, "desc": "A heavy hammer blow."}, {"id": "absolution", "name": "Absolution", "kind": "passive", "max": 1, "desc": "Killing a marked enemy resets Condemn."}]},
		],
	},
	{
		"id": "warlock", "name": "Warlock", "playable": false, "color": Color("d9552e"),
		"role": "Dark pacts. Curses, drained life and things that should stay asleep.",
		"branches": [
			{"name": "Shadow", "nodes": [{"id": "shadow_bolt", "name": "Shadow Bolt", "kind": "active", "max": 1, "desc": "Dark damage at range."}, {"id": "gloom", "name": "Gloom", "kind": "passive", "max": 1, "desc": "+dark damage."}, {"id": "eclipse", "name": "Eclipse", "kind": "active", "max": 1, "desc": "Darkness that blinds enemies."}, {"id": "void_touched", "name": "Void-Touched", "kind": "passive", "max": 1, "desc": "Shadow Bolt pierces."}]},
			{"name": "Pact", "nodes": [{"id": "summon_shade", "name": "Summon Shade", "kind": "active", "max": 1, "desc": "A shade fights at your side. It does not like you."}, {"id": "binding", "name": "Binding", "kind": "passive", "max": 1, "desc": "Summons last longer."}, {"id": "dark_bargain", "name": "Dark Bargain", "kind": "active", "max": 1, "desc": "Trade health for power."}, {"id": "covenant", "name": "Covenant", "kind": "passive", "max": 1, "desc": "Your shade grows stronger."}]},
			{"name": "Blight", "nodes": [{"id": "drain_life", "name": "Drain Life", "kind": "active", "max": 1, "desc": "Steal health over time."}, {"id": "rot", "name": "Rot", "kind": "passive", "max": 1, "desc": "Curses spread on death."}, {"id": "wither", "name": "Wither", "kind": "active", "max": 1, "desc": "Reduces enemy damage."}, {"id": "plague_lord", "name": "Plague Lord", "kind": "passive", "max": 1, "desc": "Curses last forever. Almost."}]},
		],
	},
]

const FACTIONS: Array[Dictionary] = [
	{"id": "", "name": "Unpledged", "ascendant": "", "desc": "Neutral, as a Warden should be. For now."},
	{"id": "gilded_lantern", "name": "The Gilded Lantern", "ascendant": "Aurel, the Dawnwright", "desc": "Paladins and judges of the white cities. Rebuild the Crown, under their law."},
	{"id": "saltbound", "name": "The Saltbound", "ascendant": "Morvaine, the Tidemother", "desc": "Coastal clans, fishers and privateers. Freedom above all. Distrust every crown."},
	{"id": "rootsworn", "name": "The Rootsworn", "ascendant": "Vyrr, the Thornfather", "desc": "Druids and beastfolk. The Veil is a necessary autumn."},
	{"id": "ashen_host", "name": "The Ashen Host", "ascendant": "Kaeloth, the Ember King", "desc": "Armies and smiths. The shards are weapons."},
	{"id": "pale_archive", "name": "The Pale Archive", "ascendant": "Isseth, the Veiled", "desc": "Scholars and necromancers. Remember everything, whatever the price."},
	{"id": "high_hold", "name": "The High Hold", "ascendant": "Orun, the Stonewarden", "desc": "Mountain clans. They built the Veilspires with the Wardens."},
]


static func get_class_data(class_id: String) -> Dictionary:
	for c: Dictionary in CLASSES:
		if c["id"] == class_id:
			return c
	return {}


static func get_node_data(class_id: String, node_id: String) -> Dictionary:
	var c: Dictionary = get_class_data(class_id)
	for b: Dictionary in c.get("branches", []):
		for n: Dictionary in b["nodes"]:
			if n["id"] == node_id:
				return n
	return {}


static func get_faction(faction_id: String) -> Dictionary:
	for f: Dictionary in FACTIONS:
		if f["id"] == faction_id:
			return f
	return FACTIONS[0]
