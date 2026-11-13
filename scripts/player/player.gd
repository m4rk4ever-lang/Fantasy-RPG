class_name Player
extends CharacterBody3D
## Third-person hero controller: walk, sprint, jump (coyote time + buffer), dash with i-frames.
## Movement is camera-relative and keeps momentum through acceleration curves.

signal stamina_changed(value: float, max_value: float)
signal health_changed(value: float, max_value: float)
signal dashed
signal landed(impact: float)
signal hurt(amount: float, from_dir: Vector3)
signal died

@export var walk_speed: float = 6.5
@export var sprint_speed: float = 10.5
@export var ground_accel: float = 55.0
@export var ground_decel: float = 45.0
@export var air_accel: float = 16.0
@export var turn_speed: float = 14.0
@export var jump_velocity: float = 9.5
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
@export var stamina_regen: float = 40.0
@export var stamina_regen_delay: float = 0.45
@export var sprint_drain: float = 10.0
@export var max_health: float = 100.0

## Set by tests or AI to drive movement without real input. Ignored when zero.
var debug_move_input: Vector2 = Vector2.ZERO
var camera_basis_source: Node3D

var stamina: float = 100.0
var health: float = 100.0
var is_sprinting: bool = false
var is_dashing: bool = false
var air_dashes_left: int = 1

var model: HeroModel
var combat: PlayerCombat
## Enemy the hero is locked onto (set by the lock-on system). Null = free.
var lock_target: Node3D
## Monster the hero walks to and auto-attacks (set by clicking it). Null = no auto combat.
var attack_target: Node3D
## Distance at which auto-attacks start.
@export var auto_attack_range: float = 2.1
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
	add_child(model)
	stamina = max_stamina
	health = max_health
	_facing = rotation.y
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
	if event.is_action_pressed("jump"):
		_jump_buffer = jump_buffer_time
	elif event.is_action_released("jump") and velocity.y > 0.0 and not is_dashing:
		velocity.y *= 0.5  # Variable jump height.
	elif event.is_action_pressed("dodge"):
		try_dash()
	elif event.is_action_pressed("attack_light"):
		combat.request_light()
	else:
		for i: int in 4:
			if event.is_action_pressed("skill_%d" % (i + 1)):
				combat.use_skill(PlayerCombat.SKILLS[i]["id"])


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
	_spend_stamina(dash_cost)
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


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> bool:
	if is_invulnerable() or health <= 0.0:
		return false
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	combat.cancel()
	_knockback = knockback
	_hurt_timer = 0.3
	_iframe_timer = 0.45  # Brief mercy invulnerability after a hit.
	if model:
		model.impulse_squash(0.3)
	hurt.emit(amount, knockback.normalized())
	if health <= 0.0:
		died.emit()
	return true


## Full restore, used on respawn.
func revive(at: Vector3) -> void:
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

	is_sprinting = Input.is_action_pressed("sprint") and wish.length() > 0.2 and stamina > 0.0 and on_floor
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
		var target_speed: float = sprint_speed if is_sprinting else walk_speed
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

	move_and_slide()

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
func _order_wish() -> Vector3:
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


func get_speed_ratio() -> float:
	return Vector2(velocity.x, velocity.z).length() / sprint_speed


## Instantly turn the hero to face a world-space direction (spawn, cutscenes, screenshots).
func face_direction(dir: Vector3) -> void:
	_facing = atan2(-dir.x, -dir.z)
	if model:
		model.rotation.y = _facing
