class_name PlayerCombat
extends Node
## Melee combat for the hero: 3-hit light combo, heavy slam, air slashes.
## Attacks are data-driven phases (windup, active, recovery). Dodging cancels any attack.
## Hit detection is a forgiving arc in front of the hero, sampled every physics frame.

signal attack_started(attack_name: String)
signal hit_landed(target: Node3D, hit_position: Vector3, attack: Dictionary)
signal heavy_impact(position: Vector3)

const ENEMY_GROUP := &"enemies"

## Pose keys: torso, r_arm, r_fore, l_arm, l_fore, sword. Values are Euler rotations.
const ATTACKS: Dictionary = {
	"light_1": {
		"windup": 0.07, "active": 0.12, "recovery": 0.2, "combo_window": 0.32,
		"damage": 12.0, "reach": 2.7, "arc": 120.0, "lunge": 7.0, "stamina": 6.0,
		"knockback": 3.5, "hitstop": 0.05, "shake": 0.22, "next": "light_2",
		"from": {"torso": Vector3(0.0, -0.7, 0.0), "r_arm": Vector3(1.2, -1.3, 0.2), "r_fore": Vector3(0.3, 0, 0), "l_arm": Vector3(0.4, 0, -0.4), "l_fore": Vector3(0.8, 0, 0), "sword": Vector3(-1.45, 0, 0)},
		"to": {"torso": Vector3(-0.1, 0.75, 0.0), "r_arm": Vector3(1.35, 1.25, 0.0), "r_fore": Vector3(0.1, 0, 0), "l_arm": Vector3(-0.3, 0, -0.5), "l_fore": Vector3(0.5, 0, 0), "sword": Vector3(-1.6, 0, 0)},
	},
	"light_2": {
		"windup": 0.06, "active": 0.12, "recovery": 0.2, "combo_window": 0.32,
		"damage": 12.0, "reach": 2.7, "arc": 120.0, "lunge": 7.5, "stamina": 6.0,
		"knockback": 3.5, "hitstop": 0.05, "shake": 0.22, "next": "light_3",
		"from": {"torso": Vector3(-0.05, 0.75, 0.0), "r_arm": Vector3(1.3, 1.25, 0.0), "r_fore": Vector3(0.2, 0, 0), "l_arm": Vector3(-0.3, 0, -0.5), "l_fore": Vector3(0.5, 0, 0), "sword": Vector3(-1.6, 0, 0)},
		"to": {"torso": Vector3(-0.1, -0.8, 0.0), "r_arm": Vector3(1.25, -1.35, 0.3), "r_fore": Vector3(0.1, 0, 0), "l_arm": Vector3(0.5, 0, -0.3), "l_fore": Vector3(0.9, 0, 0), "sword": Vector3(-1.45, 0, 0)},
	},
	"light_3": {
		"windup": 0.13, "active": 0.12, "recovery": 0.32, "combo_window": 0.0,
		"damage": 20.0, "reach": 3.0, "arc": 90.0, "lunge": 10.0, "stamina": 8.0,
		"knockback": 7.0, "hitstop": 0.09, "shake": 0.4, "next": "",
		"from": {"torso": Vector3(0.3, 0.0, 0.0), "r_arm": Vector3(2.9, -0.15, 0.1), "r_fore": Vector3(0.4, 0, 0), "l_arm": Vector3(2.6, 0, -0.1), "l_fore": Vector3(0.6, 0, 0), "sword": Vector3(-1.2, 0, 0)},
		"to": {"torso": Vector3(-0.45, 0.0, 0.0), "r_arm": Vector3(0.7, -0.1, 0.0), "r_fore": Vector3(0.0, 0, 0), "l_arm": Vector3(0.8, 0, 0.1), "l_fore": Vector3(0.2, 0, 0), "sword": Vector3(-1.5, 0, 0)},
	},
	"heavy": {
		"windup": 0.3, "active": 0.1, "recovery": 0.42, "combo_window": 0.0,
		"damage": 34.0, "reach": 3.4, "arc": 150.0, "lunge": 5.0, "stamina": 22.0,
		"knockback": 11.0, "hitstop": 0.13, "shake": 0.65, "next": "", "slam_radius": 3.6,
		"from": {"torso": Vector3(0.45, 0.25, 0.0), "r_arm": Vector3(3.1, 0.2, 0.15), "r_fore": Vector3(0.6, 0, 0), "l_arm": Vector3(3.0, -0.2, -0.15), "l_fore": Vector3(0.6, 0, 0), "sword": Vector3(-1.0, 0, 0)},
		"to": {"torso": Vector3(-0.65, 0.0, 0.0), "r_arm": Vector3(0.55, 0.15, 0.0), "r_fore": Vector3(0.0, 0, 0), "l_arm": Vector3(0.6, -0.15, 0.0), "l_fore": Vector3(0.1, 0, 0), "sword": Vector3(-1.7, 0, 0)},
	},
	"air_1": {
		"windup": 0.05, "active": 0.12, "recovery": 0.16, "combo_window": 0.3,
		"damage": 11.0, "reach": 2.8, "arc": 160.0, "lunge": 4.0, "stamina": 5.0,
		"knockback": 3.0, "hitstop": 0.05, "shake": 0.2, "next": "air_2", "hover": 3.5,
		"from": {"torso": Vector3(0.1, -0.8, 0.0), "r_arm": Vector3(1.4, -1.4, 0.3), "r_fore": Vector3(0.2, 0, 0), "l_arm": Vector3(0.6, 0, -0.8), "l_fore": Vector3(0.6, 0, 0), "sword": Vector3(-1.5, 0, 0)},
		"to": {"torso": Vector3(-0.2, 0.9, 0.0), "r_arm": Vector3(1.0, 1.4, -0.2), "r_fore": Vector3(0.1, 0, 0), "l_arm": Vector3(-0.2, 0, -0.9), "l_fore": Vector3(0.4, 0, 0), "sword": Vector3(-1.6, 0, 0)},
	},
	"air_2": {
		"windup": 0.05, "active": 0.12, "recovery": 0.22, "combo_window": 0.0,
		"damage": 14.0, "reach": 2.8, "arc": 160.0, "lunge": 4.0, "stamina": 5.0,
		"knockback": 5.0, "hitstop": 0.07, "shake": 0.3, "next": "", "hover": 2.5,
		"from": {"torso": Vector3(0.1, 0.85, 0.0), "r_arm": Vector3(1.1, 1.4, -0.2), "r_fore": Vector3(0.2, 0, 0), "l_arm": Vector3(-0.2, 0, -0.9), "l_fore": Vector3(0.4, 0, 0), "sword": Vector3(-1.6, 0, 0)},
		"to": {"torso": Vector3(-0.2, -0.9, 0.0), "r_arm": Vector3(1.3, -1.4, 0.3), "r_fore": Vector3(0.1, 0, 0), "l_arm": Vector3(0.6, 0, -0.8), "l_fore": Vector3(0.6, 0, 0), "sword": Vector3(-1.45, 0, 0)},
	},
	"surge": {
		"windup": 0.22, "active": 0.14, "recovery": 0.3, "combo_window": 0.0,
		"damage": 26.0, "reach": 3.0, "arc": 110.0, "lunge": 6.0, "stamina": 0.0,
		"knockback": 8.0, "hitstop": 0.08, "shake": 0.45, "next": "", "dash_to_target": 24.0,
		"from": {"torso": Vector3(-0.5, -0.4, 0.0), "r_arm": Vector3(-0.6, -0.3, 0.6), "r_fore": Vector3(0.3, 0, 0), "l_arm": Vector3(0.9, 0, -0.3), "l_fore": Vector3(0.4, 0, 0), "sword": Vector3(-1.4, 0, 0)},
		"to": {"torso": Vector3(-0.35, 0.6, 0.0), "r_arm": Vector3(1.5, 0.9, 0.0), "r_fore": Vector3(0.0, 0, 0), "l_arm": Vector3(-0.4, 0, -0.6), "l_fore": Vector3(0.3, 0, 0), "sword": Vector3(-1.6, 0, 0)},
	},
	"whirlwind": {
		"windup": 0.12, "active": 0.42, "recovery": 0.25, "combo_window": 0.0,
		"damage": 22.0, "reach": 3.3, "arc": 360.0, "lunge": 2.0, "stamina": 0.0,
		"knockback": 7.0, "hitstop": 0.06, "shake": 0.35, "next": "", "spin": TAU * 2.0,
		"from": {"torso": Vector3(0.0, -0.5, 0.0), "r_arm": Vector3(1.55, -1.5, 0.1), "r_fore": Vector3(0.05, 0, 0), "l_arm": Vector3(0.6, 0, -1.2), "l_fore": Vector3(0.3, 0, 0), "sword": Vector3(-1.55, 0, 0)},
		"to": {"torso": Vector3(0.0, -0.5, 0.0), "r_arm": Vector3(1.55, -1.5, 0.1), "r_fore": Vector3(0.05, 0, 0), "l_arm": Vector3(0.6, 0, -1.2), "l_fore": Vector3(0.3, 0, 0), "sword": Vector3(-1.55, 0, 0)},
	},
}

## Ability bar. Attack-type skills start an entry of ATTACKS; "second_wind" is a self-heal.
const SKILLS: Array[Dictionary] = [
	{"id": "cleave", "attack": "heavy", "name": "Cleave", "description": "Two-handed slam. Shockwave hits everything around the impact.", "key_label": "1", "cooldown": 5.0, "color": Color("d9552e")},
	{"id": "surge", "attack": "surge", "name": "Surge Strike", "description": "Dash to your target and cut through it. Needs a target within 10 m.", "key_label": "2", "cooldown": 8.0, "color": Color("3d5ba9")},
	{"id": "whirlwind", "attack": "whirlwind", "name": "Whirlwind", "description": "Spin twice, striking every enemy around you.", "key_label": "3", "cooldown": 10.0, "color": Color("5b6c9e")},
	{"id": "second_wind", "attack": "", "name": "Second Wind", "description": "Restore 35 health and all stamina.", "key_label": "4", "cooldown": 30.0, "color": Color("4cb46a")},
]
const SURGE_RANGE: float = 10.0

signal skill_used(id: String)

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

var player: Player
var current: Dictionary = {}
var current_name: String = ""
var phase: Phase = Phase.NONE
var trail: SwordTrail

var _t: float = 0.0
var _queued: String = ""
var _hit_this_swing: Array[Node3D] = []
var _air_chain_used: bool = false
var _cooldowns: Dictionary = {}
var _spin: float = 0.0


const SKILL_ICONS: Dictionary = {"cleave": 0, "surge": 1, "whirlwind": 2, "second_wind": 3}


## Action-bar entry for a skill.
static func skill_entry(id: String) -> Dictionary:
	for sk: Dictionary in SKILLS:
		if sk["id"] == id:
			return {"type": "skill", "id": id, "name": sk["name"], "desc": sk["description"], "color": sk["color"], "icon": SKILL_ICONS.get(id, 0), "cooldown": sk["cooldown"]}
	return {}


func get_skill(id: String) -> Dictionary:
	for sk: Dictionary in SKILLS:
		if sk["id"] == id:
			return sk
	return {}


func get_cooldown(id: String) -> float:
	return maxf(_cooldowns.get(id, 0.0), 0.0)


func is_skill_unlocked(id: String) -> bool:
	return player.progression == null or player.progression.is_skill_unlocked(id)


func is_skill_usable(id: String) -> bool:
	if not is_skill_unlocked(id) or get_cooldown(id) > 0.0:
		return false
	if id == "surge":
		var t: Node3D = _skill_target()
		return t != null
	return true


func _skill_target() -> Node3D:
	var t: Node3D = player.lock_target
	if t and is_instance_valid(t) and not (t.has_method("is_dead") and t.call("is_dead")):
		if t.global_position.distance_to(player.global_position) <= SURGE_RANGE:
			return t
	return null


## Use a skill from the ability bar. Skills interrupt light attacks (but not other skills).
func use_skill(id: String) -> bool:
	var sk: Dictionary = get_skill(id)
	if sk.is_empty() or not is_skill_usable(id) or player.is_dashing:
		return false
	if phase != Phase.NONE and SKILLS.any(func(x: Dictionary) -> bool: return x["attack"] == current_name):
		return false
	var atk: String = sk["attack"]
	if atk == "heavy" and not player.is_on_floor():
		return false
	if atk != "":
		cancel()
		_start(atk)
	_cooldowns[id] = float(sk["cooldown"]) * maxf(0.3, 1.0 + player.progression.stat("cooldown_mult"))
	skill_used.emit(id)
	return true


func setup(p: Player) -> void:
	player = p
	trail = SwordTrail.new()
	trail.name = "SwordTrail"
	player.add_child.call_deferred(trail)
	trail.setup.call_deferred(player.model.sword_base, player.model.sword_tip)


func is_busy() -> bool:
	return phase != Phase.NONE


## True while the attack still owns the hero's movement (windup/active and early recovery).
func locks_movement() -> bool:
	if phase == Phase.WINDUP or phase == Phase.ACTIVE:
		return true
	return phase == Phase.RECOVERY and _t < current.get("recovery", 0.0) * 0.6


func cancel() -> void:
	if phase == Phase.NONE:
		return
	phase = Phase.NONE
	current = {}
	current_name = ""
	_queued = ""
	trail.emitting = false


func request_light() -> void:
	if player.is_dashing:
		return
	var on_floor: bool = player.is_on_floor()
	if phase == Phase.NONE:
		if on_floor:
			_start("light_1")
		elif not _air_chain_used:
			_start("air_1")
		return
	# Buffer the next hit of the combo.
	var nxt: String = current.get("next", "")
	if nxt != "":
		_queued = nxt


func request_heavy() -> void:
	if player.is_dashing:
		return
	if phase == Phase.NONE or (phase == Phase.RECOVERY):
		if player.is_on_floor():
			_start("heavy")
		else:
			_queued = ""


func _start(attack_name: String) -> void:
	var data: Dictionary = ATTACKS[attack_name]
	current = data
	current_name = attack_name
	phase = Phase.WINDUP
	_t = 0.0
	_queued = ""
	_hit_this_swing.clear()
	if attack_name.begins_with("air"):
		_air_chain_used = true
	player.spend_stamina_soft(data["stamina"])
	_aim_at_best_target()
	attack_started.emit(attack_name)


## Soft auto-aim: turn toward the lock target, or the best enemy near the input direction.
func _aim_at_best_target() -> void:
	var origin: Vector3 = player.global_position
	var want: Vector3 = player.get_wish_direction()
	if want.length_squared() < 0.01:
		want = player.get_facing_vector()
	var best: Node3D = player.lock_target
	if best == null or not is_instance_valid(best):
		best = null
		var best_score: float = INF
		for e: Node in player.get_tree().get_nodes_in_group(ENEMY_GROUP):
			var en := e as Node3D
			if en == null or (en.has_method("is_dead") and en.call("is_dead")):
				continue
			var to: Vector3 = en.global_position - origin
			to.y = 0.0
			var d: float = to.length()
			if d > 5.5:
				continue
			var ang: float = rad_to_deg(want.angle_to(to.normalized())) if d > 0.01 else 0.0
			if ang > 70.0:
				continue
			var score: float = d + ang * 0.03
			if score < best_score:
				best_score = score
				best = en
	if best:
		var dir: Vector3 = best.global_position - origin
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			player.face_direction(dir.normalized())
	elif want.length_squared() > 0.01:
		player.face_direction(want.normalized())


func _physics_process(delta: float) -> void:
	for k: String in _cooldowns.keys():
		_cooldowns[k] = (_cooldowns[k] as float) - delta
	if current.has("spin") and (phase == Phase.ACTIVE):
		_spin += current["spin"] / current["active"] * delta
	elif phase == Phase.NONE or not current.has("spin"):
		_spin = 0.0
	if phase == Phase.NONE:
		if player and player.is_on_floor():
			_air_chain_used = false
		_update_pose(delta)
		return
	_t += delta
	match phase:
		Phase.WINDUP:
			if _t >= current["windup"]:
				phase = Phase.ACTIVE
				_t = 0.0
				trail.emitting = true
		Phase.ACTIVE:
			_detect_hits()
			if _t >= current["active"]:
				phase = Phase.RECOVERY
				_t = 0.0
				trail.emitting = false
				if current.has("slam_radius"):
					heavy_impact.emit(player.global_position + player.get_facing_vector() * 1.6)
		Phase.RECOVERY:
			var window: float = current.get("combo_window", 0.0)
			if _queued != "" and _t >= current["recovery"] * 0.25:
				var nxt: String = _queued
				var air: bool = nxt.begins_with("air")
				if air == (not player.is_on_floor()) or not air:
					_start(nxt)
					_update_pose(delta)
					return
			if _t >= maxf(current["recovery"], window):
				phase = Phase.NONE
				current = {}
				current_name = ""
	_update_pose(delta)


## Horizontal velocity the attack wants this frame (lunge forward during windup/active).
func get_attack_velocity() -> Vector3:
	if phase == Phase.NONE:
		return Vector3.ZERO
	var fwd: Vector3 = player.get_facing_vector()
	if current.has("dash_to_target") and (phase == Phase.WINDUP or phase == Phase.ACTIVE):
		var t: Node3D = player.lock_target
		if t and is_instance_valid(t):
			var to: Vector3 = t.global_position - player.global_position
			to.y = 0.0
			if to.length() > 1.6:
				player.face_direction(to.normalized())
				return to.normalized() * float(current["dash_to_target"])
			return Vector3.ZERO
	var lunge: float = current.get("lunge", 0.0)
	var target: Node3D = _nearest_in_front(1.4)
	if target:
		lunge *= 0.15  # Already in range: don't run through the enemy.
	match phase:
		Phase.WINDUP:
			return fwd * lunge * 0.5
		Phase.ACTIVE:
			return fwd * lunge
		_:
			return fwd * lunge * maxf(0.0, 0.3 - _t * 2.0)


## Extra model yaw (radians) for spinning attacks.
func get_spin() -> float:
	return _spin


func get_hover() -> float:
	return current.get("hover", 0.0) if phase != Phase.NONE else 0.0


func _nearest_in_front(max_dist: float) -> Node3D:
	var origin: Vector3 = player.global_position
	var fwd: Vector3 = player.get_facing_vector()
	for e: Node in player.get_tree().get_nodes_in_group(ENEMY_GROUP):
		var en := e as Node3D
		if en == null:
			continue
		var to: Vector3 = en.global_position - origin
		to.y = 0.0
		if to.length() < max_dist and fwd.dot(to.normalized()) > 0.3:
			return en
	return null


func _detect_hits() -> void:
	var origin: Vector3 = player.global_position
	var fwd: Vector3 = player.get_facing_vector()
	var reach: float = current["reach"]
	var half_arc: float = current["arc"] * 0.5
	var slam: float = current.get("slam_radius", 0.0)
	for e: Node in player.get_tree().get_nodes_in_group(ENEMY_GROUP):
		var en := e as Node3D
		if en == null or _hit_this_swing.has(en):
			continue
		if en.has_method("is_dead") and en.call("is_dead"):
			continue
		var to: Vector3 = en.global_position - origin
		if absf(to.y) > 2.2:
			continue
		to.y = 0.0
		var d: float = to.length()
		var in_arc: bool = d <= reach and (d < 0.6 or rad_to_deg(fwd.angle_to(to / d)) <= half_arc)
		var in_slam: bool = slam > 0.0 and d <= slam
		if not (in_arc or in_slam):
			continue
		_hit_this_swing.append(en)
		var dir: Vector3 = to.normalized() if d > 0.01 else fwd
		var hit_pos: Vector3 = en.global_position + Vector3.UP * 1.1 - dir * 0.35
		if en.has_method("take_hit"):
			en.call("take_hit", _damage_against(en), dir * current["knockback"], hit_pos)
		hit_landed.emit(en, hit_pos, current)


## Attack damage with skill-tree bonuses (Keen Edge, Executioner).
func _damage_against(en: Node3D) -> float:
	var dmg: float = float(current["damage"])
	if player.progression:
		dmg *= 1.0 + player.progression.stat("damage_mult")
		var hp: float = float(en.get("health"))
		var mhp: float = float(en.get("max_health"))
		if mhp > 0.0 and hp / mhp < 0.3:
			dmg *= 1.0 + player.progression.stat("execute_bonus")
	return dmg


func _update_pose(delta: float) -> void:
	var model: HeroModel = player.model if player else null
	if model == null:
		return
	if phase == Phase.NONE:
		model.action_weight = move_toward(model.action_weight, 0.0, delta * 6.0)
		return
	var from: Dictionary = current["from"]
	var to: Dictionary = current["to"]
	var k: float
	match phase:
		Phase.WINDUP:
			# Anticipation: pull slightly past the start pose.
			k = -0.12 * sin(clampf(_t / current["windup"], 0.0, 1.0) * PI)
		Phase.ACTIVE:
			var a: float = clampf(_t / current["active"], 0.0, 1.0)
			k = 1.0 - pow(1.0 - a, 3.0)  # Fast snap through the swing.
		_:
			# Follow-through overshoot then settle.
			var r: float = clampf(_t / current["recovery"], 0.0, 1.0)
			k = 1.0 + 0.08 * sin(r * PI)
	var pose: Dictionary = {}
	for key: String in from.keys():
		var a2: Vector3 = from[key]
		var b2: Vector3 = to[key]
		pose[key] = a2.lerp(b2, k)
	model.action_pose = pose
	var target_w: float = 1.0
	if phase == Phase.RECOVERY:
		target_w = 1.0 - smoothstep(0.55, 1.0, _t / current["recovery"])
	model.action_weight = move_toward(model.action_weight, target_w, delta * 18.0)
