class_name Player
extends CharacterBody3D
## Third-person hero controller: walk, sprint, dash with i-frames, click orders.
## No jumping (owner feedback 13-11-2026): the hero steps up ledges up to `step_height` by itself,
## so click-to-move never gets stuck on stairs, piers or rocks.
## Movement is camera-relative and keeps momentum through acceleration curves.

signal stamina_changed(value: float, max_value: float)
signal health_changed(value: float, max_value: float)
signal dashed
signal landed(impact: float)
signal hurt(amount: float, from_dir: Vector3)
signal died
## Fired when auto-retaliate makes the hero fight back against `attacker`.
signal retaliated(attacker: Node3D)
signal auto_retaliate_changed(on: bool)
## Reached an NPC the player clicked: open the conversation.
signal talk_reached(npc: Node3D)
signal run_changed(on: bool)

@export var walk_speed: float = 6.5
@export var sprint_speed: float = 10.5
@export var ground_accel: float = 55.0
@export var ground_decel: float = 45.0
@export var air_accel: float = 16.0
@export var turn_speed: float = 14.0
@export var jump_velocity: float = 9.5
@export var step_height: float = 0.5
@export var gravity: float = 26.0
@export var fall_gravity_mult: float = 1.45
@export var coyote_time: float = 0.13
@export var jump_buffer_time: float = 0.14
@export var dash_speed: float = 21.0
@export var dash_time: float = 0.19
@export var dash_cooldown: float = 0.28
@export var dash_iframes: float = 0.28
@export var dash_cost: float = 18.0
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 14.0
@export var stamina_regen_delay: float = 0.45
@export var sprint_drain: float = 4.0
@export var max_health: float = 100.0

## Set by tests or AI to drive movement without real input. Ignored when zero.
var debug_move_input: Vector2 = Vector2.ZERO
var camera_basis_source: Node3D
## Optional world rule: Callable(from: Vector3, to: Vector3) -> bool. False blocks the move (e.g. water).
var walkable_check: Callable

var stamina: float = 100.0
var health: float = 100.0
var is_sprinting: bool = false
var is_dashing: bool = false
var air_dashes_left: int = 1

var model: HeroModel
var combat: PlayerCombat
var progression: Progression
var inventory: Inventory
var quests: QuestLog
## Base max health before skill-tree bonuses.
var base_max_health: float = 100.0
## Enemy the hero is locked onto (set by the lock-on system). Null = free.
var lock_target: Node3D
## Monster the hero walks to and auto-attacks (set by clicking it). Null = no auto combat.
var attack_target: Node3D
## RuneScape-style: when idle and hit by a monster, target it and fight back.
var auto_retaliate: bool = true
## Run toggle (RuneScape run orb): running drains stamina; at zero the hero walks until it refills.
var run_enabled: bool = true
## Distance at which auto-attacks start.
@export var auto_attack_range: float = 2.1
var talk_target: Node3D
## Pathfinding grid for click orders (set by the game root). Null = walk straight.
var nav: NavGrid
var _path := PackedVector3Array()
var _path_i: int = 0
var _path_goal: Vector3 = Vector3.ZERO
var _repath_timer: float = 0.0
var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _iframe_timer: float = 0.0
var _regen_wait: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _was_on_floor: bool = true
var _last_fall_speed: float = 0.0
var _facing: float = 0.0
var _prev_hvel: Vector3 = Vector3.ZERO
var _knockback: Vector3 = Vector3.ZERO
var _hurt_timer: float = 0.0
var _wish: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	model = HeroModel.new()
	model.name = "Model"
	model.glb_path = "res://assets/models/quaternius/adventurer.glb"
	model.hide_meshes = ["Backpack"]
	model.heroic = true
	model.tints = {"Green": Color("3d5ba9"), "LightGreen": Color("5b6c9e"), "Brown2": Color("4a3426")}
	add_child(model)
	stamina = max_stamina
	health = max_health
	_facing = rotation.y
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)
	quests = QuestLog.new()
	quests.name = "Quests"
	quests.inventory = inventory
	add_child(quests)
	progression = Progression.new()
	progression.name = "Progression"
	add_child(progression)
	progression.ranks_changed.connect(_apply_progression)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self)
	combat.skill_used.connect(_on_skill_used)


func is_invulnerable() -> bool:
	if combat and combat.current_name == "surge" and combat.phase != PlayerCombat.Phase.RECOVERY:
		return true
	return _iframe_timer > 0.0


## Click-to-move (RuneScape style). WASD input cancels it.
func set_move_target(point: Vector3) -> void:
	_move_target = point
	_has_move_target = true
	attack_target = null
	talk_target = null
	_repath_timer = 0.0


func set_talk_target(npc: Node3D) -> void:
	talk_target = npc
	_has_move_target = false
	attack_target = null
	_repath_timer = 0.0


func clear_orders() -> void:
	_has_move_target = false
	attack_target = null


func get_move_input() -> Vector2:
	if debug_move_input != Vector2.ZERO:
		return debug_move_input.limit_length(1.0)
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _camera_relative(input: Vector2) -> Vector3:
	var yaw: float = 0.0
	if camera_basis_source:
		yaw = camera_basis_source.global_rotation.y
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return (right * input.x - forward * input.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_run"):
		set_run(not run_enabled)
	elif event.is_action_pressed("toggle_retaliate"):
		set_auto_retaliate(not auto_retaliate)
	elif event.is_action_pressed("attack_light"):
		combat.request_light()



func request_jump() -> void:
	_jump_buffer = jump_buffer_time


func try_dash() -> bool:
	if _dash_cd > 0.0 or is_dashing:
		return false
	if stamina <= 0.0:
		return false
	if not is_on_floor() and air_dashes_left <= 0:
		return false
	if _hurt_timer > 0.15:
		return false
	combat.cancel()  # Dodging always cancels an attack.
	var dir: Vector3 = _camera_relative(get_move_input())
	if dir.length_squared() < 0.01:
		dir = -model.global_transform.basis.z if model else Vector3.FORWARD
	dir.y = 0.0
	_dash_dir = dir.normalized()
	if not is_on_floor():
		air_dashes_left -= 1
	is_dashing = true
	_dash_timer = dash_time
	_iframe_timer = dash_iframes
	_spend_stamina(dash_cost * maxf(0.1, 1.0 + progression.stat("dodge_cost_mult")))
	_facing = atan2(-_dash_dir.x, -_dash_dir.z)
	if model:
		model.impulse_squash(-0.25)
	dashed.emit()
	return true


## Attacks never get blocked by stamina (forgiving): they just drain what is left.
func spend_stamina_soft(amount: float) -> void:
	_spend_stamina(amount)


func get_wish_direction() -> Vector3:
	return _wish


func get_facing_vector() -> Vector3:
	return Vector3(-sin(_facing), 0.0, -cos(_facing))


func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = stamina_regen_delay
	stamina_changed.emit(stamina, max_stamina)


## Re-apply passive stats after the skill tree changes.
func _apply_progression() -> void:
	var old_max: float = max_health
	max_health = base_max_health + progression.stat("max_health")
	health = minf(health + maxf(max_health - old_max, 0.0), max_health)
	health_changed.emit(health, max_health)


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


func set_run(on: bool) -> void:
	run_enabled = on
	run_changed.emit(on)


func set_auto_retaliate(on: bool) -> void:
	auto_retaliate = on
	auto_retaliate_changed.emit(on)


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, attacker: Node3D = null) -> bool:
	if is_invulnerable() or health <= 0.0:
		return false
	amount *= maxf(0.2, 1.0 + progression.stat("damage_taken_mult"))
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	combat.cancel()
	_knockback = knockback
	_hurt_timer = 0.3
	_iframe_timer = 0.45  # Brief mercy invulnerability after a hit.
	if model:
		model.impulse_squash(0.3)
	hurt.emit(amount, knockback.normalized())
	model.play_reaction("hurt")
	# Only retaliate when the player isn't busy with their own orders or direct control.
	if auto_retaliate and attacker and is_instance_valid(attacker) and attack_target == null and not _has_move_target and get_move_input().length() < 0.2:
		attack_target = attacker
		retaliated.emit(attacker)
	if health <= 0.0:
		model.play_reaction("death")
		died.emit()
	return true


## Full restore, used on respawn.
func revive(at: Vector3) -> void:
	model.play_reaction("revive")
	global_position = at
	velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	var input: Vector2 = get_move_input()
	var wish: Vector3 = _camera_relative(input)
	if input.length() > 0.2:
		# Direct control always wins over click orders.
		_has_move_target = false
		attack_target = null
		talk_target = null
	else:
		wish = _order_wish()
	_wish = wish
	var locked: bool = lock_target != null and is_instance_valid(lock_target)
	var on_floor: bool = is_on_floor()

	if on_floor:
		_coyote = coyote_time
		air_dashes_left = 1
	else:
		_coyote -= delta

	is_sprinting = run_enabled and wish.length() > 0.2 and stamina > 0.0 and on_floor
	if is_sprinting:
		stamina = maxf(stamina - sprint_drain * delta, 0.0)
		_regen_wait = 0.2
		stamina_changed.emit(stamina, max_stamina)

	if is_dashing:
		_dash_timer -= delta
		var t: float = 1.0 - clampf(_dash_timer / dash_time, 0.0, 1.0)
		var spd: float = lerpf(dash_speed, sprint_speed * 0.8, t * t)
		velocity.x = _dash_dir.x * spd
		velocity.z = _dash_dir.z * spd
		velocity.y = maxf(velocity.y, 0.0) if not on_floor else velocity.y
		if _dash_timer <= 0.0:
			is_dashing = false
			_dash_cd = dash_cooldown
	elif _hurt_timer > 0.0:
		_hurt_timer -= delta
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, 40.0 * delta)
	elif combat.locks_movement():
		var av: Vector3 = combat.get_attack_velocity()
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(av, 90.0 * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		var hover: float = combat.get_hover()
		if hover > 0.0 and not on_floor:
			velocity.y = maxf(velocity.y, 0.0) * 0.5 + hover * 0.3
	else:
		var target_speed: float = (sprint_speed if is_sprinting else walk_speed) * (1.0 + progression.stat("move_speed_mult"))
		var target: Vector3 = wish * target_speed
		var hvel := Vector3(velocity.x, 0, velocity.z)
		var rate: float
		if on_floor:
			rate = ground_accel if target.length_squared() > 0.01 else ground_decel
		else:
			rate = air_accel
		hvel = hvel.move_toward(target, rate * delta)
		velocity.x = hvel.x
		velocity.z = hvel.z
		if locked and not is_sprinting:
			var to_t: Vector3 = lock_target.global_position - global_position
			if Vector2(to_t.x, to_t.z).length() > 0.3:
				_facing = atan2(-to_t.x, -to_t.z)
		elif wish.length_squared() > 0.01:
			_facing = atan2(-wish.x, -wish.z)

	# Gravity with a heavier fall for a snappy arc.
	if not on_floor:
		var g: float = gravity * (fall_gravity_mult if velocity.y < 0.0 else 1.0)
		if is_dashing:
			g *= 0.15
		elif combat.get_hover() > 0.0:
			g *= 0.25
		velocity.y -= g * delta
		_last_fall_speed = minf(_last_fall_speed, velocity.y)

	# Jump with coyote time and buffering. Jumping cancels a dash and keeps its momentum.
	if _jump_buffer > 0.0 and _coyote > 0.0 and not combat.locks_movement():
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		is_dashing = false
		if model:
			model.impulse_squash(-0.35)

	_block_unwalkable(delta)
	var pre_move_h := Vector3(velocity.x, 0, velocity.z)
	move_and_slide()
	# Auto step-up: blocked by a low ledge while walking on the ground -> climb it.
	if on_floor and is_on_wall() and pre_move_h.length() > 0.5 and not is_dashing:
		_try_step(pre_move_h * delta * 1.5)

	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		var impact: float = clampf(-_last_fall_speed / 20.0, 0.0, 1.0)
		if model:
			model.impulse_squash(0.15 + impact * 0.6)
		landed.emit(impact)
		_last_fall_speed = 0.0
	_was_on_floor = now_on_floor

	_update_model(delta)


## Movement wanted by click orders: walk to a clicked point, or chase and auto-attack a monster.
## Click orders follow a path from the NavGrid (around houses, fences, water), RuneScape style.
## The last stretch to the target is steered directly.
func _order_wish() -> Vector3:
	var w: Vector3 = _order_wish_raw()
	if w.length_squared() < 0.0001:
		_path = PackedVector3Array()
		return w
	if nav == null or not nav.covers(global_position):
		# No grid here (dungeons): steer around pillars and rubble locally.
		_path = PackedVector3Array()
		return _steer_around(w)
	var goal: Vector3 = _order_goal()
	var flat := Vector3(global_position.x, 0, global_position.z)
	var goal_flat := Vector3(goal.x, 0, goal.z)
	if flat.distance_to(goal_flat) < 2.5:
		return _steer_around(w)
	_repath_timer -= get_physics_process_delta_time()
	# Re-plan only when the goal moved or now and then. An unreachable goal used to trigger a full A*
	# search every physics frame (a big stutter in the browser, owner 14-11-2026).
	if _path_goal.distance_to(goal_flat) > 1.5 or _repath_timer <= 0.0:
		_path = nav.find_path(global_position, goal)
		_path_i = 0
		_path_goal = goal_flat
		_repath_timer = 1.5
	while _path_i < _path.size() - 1 and flat.distance_to(Vector3(_path[_path_i].x, 0, _path[_path_i].z)) < 0.8:
		_path_i += 1
	if _path_i >= _path.size():
		return w
	var wp: Vector3 = _path[_path_i]
	var d := Vector3(wp.x - flat.x, 0, wp.z - flat.z)
	if d.length() < 0.05:
		return w
	return d.normalized() * w.length()


## Local avoidance: if something solid is right ahead at body height, turn toward the clearest side.
func _steer_around(w: Vector3) -> Vector3:
	var flat := Vector3(w.x, 0, w.z)
	if flat.length_squared() < 0.0001:
		return w
	var dir: Vector3 = flat.normalized()
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 0.9
	for ang: float in [0.0, 0.6, -0.6, 1.1, -1.1, 1.6, -1.6]:
		var d: Vector3 = dir.rotated(Vector3.UP, ang)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.4, 1)
		q.exclude = [get_rid()]
		if space.intersect_ray(q).is_empty():
			return d * w.length()
	return w


func _order_goal() -> Vector3:
	if talk_target and is_instance_valid(talk_target):
		return talk_target.global_position
	if attack_target and is_instance_valid(attack_target):
		return attack_target.global_position
	return _move_target


func _order_wish_raw() -> Vector3:
	if talk_target and is_instance_valid(talk_target):
		var tt: Vector3 = talk_target.global_position - global_position
		tt.y = 0.0
		if tt.length() > 2.0:
			return tt.normalized()
		var npc: Node3D = talk_target
		talk_target = null
		face_direction(tt.normalized())
		talk_reached.emit(npc)
		return Vector3.ZERO
	if attack_target and (not is_instance_valid(attack_target) or (attack_target.has_method("is_dead") and attack_target.call("is_dead"))):
		attack_target = null
	if attack_target:
		var to: Vector3 = attack_target.global_position - global_position
		to.y = 0.0
		if to.length() > auto_attack_range:
			return to.normalized()
		if not combat.is_busy() or combat.phase == PlayerCombat.Phase.RECOVERY:
			combat.request_light()
		return Vector3.ZERO
	if _has_move_target:
		var to2: Vector3 = _move_target - global_position
		to2.y = 0.0
		if to2.length() < 0.35:
			_has_move_target = false
			return Vector3.ZERO
		return to2.normalized() * clampf(to2.length() / 1.2, 0.3, 1.0)
	return Vector3.ZERO


func _on_skill_used(id: String) -> void:
	if id == "second_wind":
		health = minf(health + 35.0, max_health)
		stamina = max_stamina
		health_changed.emit(health, max_health)
		stamina_changed.emit(stamina, max_stamina)


func _tick_timers(delta: float) -> void:
	_jump_buffer -= delta
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_iframe_timer = maxf(_iframe_timer - delta, 0.0)
	if _regen_wait > 0.0:
		_regen_wait -= delta
	elif stamina < max_stamina and not is_dashing:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)


func _update_model(delta: float) -> void:
	if model == null:
		return
	var spin: float = combat.get_spin() if combat else 0.0
	if spin != 0.0:
		model.rotation.y = _facing + spin
	else:
		model.rotation.y = lerp_angle(model.rotation.y, _facing, 1.0 - exp(-turn_speed * delta))
	var hvel := Vector3(velocity.x, 0, velocity.z)
	var accel: Vector3 = (hvel - _prev_hvel) / maxf(delta, 0.0001)
	_prev_hvel = hvel
	var fwd: Vector3 = -model.global_transform.basis.z
	var accel_lean: float = clampf(accel.dot(fwd) / 60.0, -0.6, 0.6)
	var ratio: float = hvel.length() / sprint_speed * 1.15
	model.animate(delta, ratio if is_on_floor() else 0.4, is_on_floor(), velocity.y, accel_lean, is_dashing)


## Stop at the water's edge (and pier sides). Slides along the edge when only one axis is blocked.
func _block_unwalkable(delta: float) -> void:
	if not walkable_check.is_valid():
		return
	var h := Vector3(velocity.x, 0, velocity.z)
	if h.length() < 0.01:
		return
	var look: float = maxf(0.45, h.length() * delta * 2.0)
	var from: Vector3 = global_position
	if walkable_check.call(from, from + h.normalized() * look):
		return
	var ok_x: bool = absf(h.x) > 0.01 and walkable_check.call(from, from + Vector3(signf(h.x) * look, 0, 0))
	var ok_z: bool = absf(h.z) > 0.01 and walkable_check.call(from, from + Vector3(0, 0, signf(h.z) * look))
	velocity.x = h.x if ok_x else 0.0
	velocity.z = h.z if ok_z else 0.0
	if not ok_x and not ok_z and _has_move_target:
		_has_move_target = false  # Clicked into the sea: stop at the shore.


func _try_step(h_motion: Vector3) -> bool:
	if h_motion.length() < 0.001:
		return false
	var up := Vector3.UP * step_height
	if test_move(global_transform, up):
		return false
	var t: Transform3D = global_transform.translated(up)
	if test_move(t, h_motion):
		return false
	t = t.translated(h_motion)
	var col := KinematicCollision3D.new()
	if test_move(t, Vector3.DOWN * (step_height + 0.05), col):
		var landing: Vector3 = t.origin + col.get_travel()
		if landing.y > global_position.y + 0.02 and col.get_normal().y > 0.7:
			global_position = landing
			return true
	return false


func get_speed_ratio() -> float:
	return Vector2(velocity.x, velocity.z).length() / sprint_speed


## Instantly turn the hero to face a world-space direction (spawn, cutscenes, screenshots).
func face_direction(dir: Vector3) -> void:
	_facing = atan2(-dir.x, -dir.z)
	if model:
		model.rotation.y = _facing
