class_name Hollow
extends CharacterBody3D
## The Hollowed: a husk emptied by the Veil. First enemy type.
## State machine: IDLE -> CHASE -> WINDUP -> ATTACK -> RECOVER, with STAGGER and DEAD.
## Telegraphs clearly (eyes flare, arm rises) so dodging always feels fair.

signal health_changed(value: float, max_value: float)
signal died(enemy: Hollow)
signal attacked(enemy: Hollow)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD }

const COL_BODY := Color("353a42")
const COL_DARK := Color("1e2125")
const COL_CLOTH := Color("4a483e")
const COL_BONE := Color("c9c6b8")
const COL_EYE := Color("bfe6ff")

@export var display_name: String = "Hollowed Warden"
@export var max_health: float = 60.0
@export var move_speed: float = 4.2
@export var aggro_range: float = 13.0
@export var attack_range: float = 2.1
@export var attack_damage: float = 14.0
@export var windup_time: float = 0.62
@export var attack_time: float = 0.22
@export var recover_time: float = 0.75

var health: float = 60.0
var state: State = State.IDLE
var target: Node3D
var home: Vector3

var _t: float = 0.0
var _cooldown: float = 1.0
var _knock: Vector3 = Vector3.ZERO
var _facing: float = 0.0
var _phase: float = 0.0
var _flash: float = 0.0
var _hit_done: bool = false
var _idle_wander: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var _model: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _eye_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _flash_meshes: Array[MeshInstance3D] = []
var _body_mat: StandardMaterial3D
var _overlay_on: bool = false
var _wisps: CPUParticles3D


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	health = max_health
	home = global_position
	_rng.randomize()
	_facing = _rng.randf() * TAU
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)
	_build_model()


func is_dead() -> bool:
	return state == State.DEAD


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.3


func _mesh(parent: Node3D, kit: MeshKit, _metal: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = _body_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	_flash_meshes.append(mi)


func _build_model() -> void:
	_body_mat = MeshKit.vertex_color_material(0.85)
	# Same material features as CombatFx's pre-warmed flash, so no shader compile on first hit.
	_flash_mat = CombatFx.make_hit_flash_material()
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = COL_EYE

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var hips := Node3D.new()
	hips.position.y = 0.95
	_model.add_child(hips)
	_torso = Node3D.new()
	_torso.position.y = 0.08
	hips.add_child(_torso)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, -0.1)
	_torso.add_child(_head)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.23, 0.5, 0.03)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.23, 0.5, 0.03)
	_torso.add_child(_arm_l)
	_torso.add_child(_arm_r)
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.1, -0.05, 0)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.1, -0.05, 0)
	hips.add_child(_leg_l)
	hips.add_child(_leg_r)

	# Low-poly anatomy like the hero, but gaunt: thin waist, ribs, long arms, ragged Warden robes.
	var I := Transform3D.IDENTITY
	var rag: Color = COL_CLOTH
	var k := MeshKit.new()
	# Robe skirt with a tattered hem (wedges pointing down).
	k.loft(I, [[0.08, 0.15, 0.11, 0.0, rag], [-0.2, 0.2, 0.15, 0.01, rag], [-0.62, 0.27, 0.21, 0.02, rag.darkened(0.15)]], 9, false, false)
	for f: int in 11:
		var a: float = TAU * f / 11.0
		var len: float = 0.12 + fmod(f * 0.37, 0.14)
		k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, -a), Vector3(cos(a) * 0.26, -0.62 - len * 0.5, sin(a) * 0.2)), Vector3(0.1, 0.02, len), rag.darkened(0.2))
	_mesh(hips, k, false)

	k = MeshKit.new()
	# Emaciated torso: narrow waist, visible rib bands, bony shoulders.
	k.loft(I, [[0.0, 0.11, 0.08, 0.0, COL_BODY], [0.15, 0.12, 0.085, 0.0, COL_BODY], [0.25, 0.15, 0.1, -0.01, COL_DARK], [0.3, 0.155, 0.105, -0.01, COL_BODY], [0.36, 0.165, 0.11, -0.012, COL_DARK], [0.41, 0.17, 0.11, -0.012, COL_BODY], [0.5, 0.19, 0.11, 0.0, COL_BODY], [0.57, 0.12, 0.09, 0.0, COL_BODY], [0.62, 0.05, 0.05, -0.04, COL_BODY]], 9)
	# Bone spurs along the spine.
	for b: int in 5:
		k.wedge(Transform3D(Basis(Vector3.RIGHT, PI - 0.5), Vector3(0, 0.18 + b * 0.09, 0.1 + b * 0.008)), Vector3(0.03, 0.03, 0.09 + b * 0.012), COL_BONE)
	# Torn hood mantle over the shoulders.
	k.loft(I, [[0.46, 0.2, 0.14, 0.02, rag], [0.58, 0.17, 0.13, 0.03, rag], [0.66, 0.08, 0.08, 0.0, rag]], 9, false, false)
	_mesh(_torso, k, false)

	k = MeshKit.new()
	# Skull-like face in a deep hood.
	k.loft(I, [[0.0, 0.05, 0.05, 0.0, COL_DARK], [0.06, 0.06, 0.07, -0.03, COL_DARK], [0.12, 0.075, 0.085, -0.02, COL_DARK], [0.2, 0.08, 0.09, 0.0, COL_DARK], [0.27, 0.06, 0.075, 0.01, COL_DARK], [0.3, 0.02, 0.03, 0.01, COL_DARK]], 8)
	k.loft(I, [[0.04, 0.13, 0.13, 0.03, rag], [0.18, 0.125, 0.135, 0.02, rag], [0.3, 0.09, 0.11, 0.03, rag], [0.36, 0.02, 0.05, 0.05, rag]], 9, false, true)
	k.wedge(Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.33, 0.08)), Vector3(0.06, 0.03, 0.22), rag)  # Hood point.
	_mesh(_head, k, false)
	var eye := SphereMesh.new()
	eye.radius = 0.022
	eye.height = 0.044
	eye.radial_segments = 6
	eye.rings = 3
	for side: float in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.mesh = eye
		e.material_override = _eye_mat
		e.position = Vector3(0.035 * side, 0.15, -0.085)
		_head.add_child(e)

	for arm: Node3D in [_arm_l, _arm_r]:
		k = MeshKit.new()
		# Long, thin arm: shoulder knob, wasted biceps, knobbly elbow, forearm, claw hand.
		k.loft(I, [[0.03, 0.05, 0.05, 0.0, COL_BODY], [-0.08, 0.05, 0.05, 0.0, COL_BODY], [-0.3, 0.035, 0.035, 0.0, COL_BODY], [-0.36, 0.045, 0.045, 0.0, COL_BONE], [-0.42, 0.035, 0.035, 0.0, COL_DARK], [-0.72, 0.028, 0.026, 0.0, COL_DARK], [-0.78, 0.045, 0.025, 0.0, COL_DARK]], 7)
		for c: int in 3:
			var cx: float = (c - 1) * 0.03
			k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.15), Vector3(cx, -0.9, -0.02)), Vector3(0.022, 0.016, 0.24), COL_BONE)
		# Rag sleeve.
		k.loft(I, [[0.05, 0.07, 0.07, 0.0, rag], [-0.2, 0.075, 0.075, 0.01, rag.darkened(0.15)]], 7, false, false)
		_mesh(arm, k, false)

	for leg: Node3D in [_leg_l, _leg_r]:
		k = MeshKit.new()
		k.loft(I, [[0.03, 0.07, 0.07, 0.0, COL_DARK], [-0.4, 0.045, 0.045, 0.0, COL_DARK], [-0.46, 0.05, 0.05, -0.01, COL_BONE], [-0.85, 0.03, 0.03, 0.0, COL_DARK], [-0.9, 0.035, 0.08, -0.04, COL_DARK]], 7)
		_mesh(leg, k, false)

	# Veil wisps drifting off the body.
	_wisps = CPUParticles3D.new()
	_wisps.amount = 14
	_wisps.lifetime = 1.6
	_wisps.local_coords = false
	_wisps.position.y = 1.1
	_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_wisps.emission_sphere_radius = 0.35
	_wisps.direction = Vector3.UP
	_wisps.spread = 25.0
	_wisps.gravity = Vector3(0, 0.5, 0)
	_wisps.initial_velocity_min = 0.2
	_wisps.initial_velocity_max = 0.5
	_wisps.scale_amount_min = 0.6
	_wisps.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	_wisps.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wm.albedo_color = Color(0.79, 0.78, 0.72, 0.35)
	wm.vertex_color_use_as_albedo = true
	wm.albedo_texture = CombatFx.soft_dot()
	quad.material = wm
	_wisps.mesh = quad
	add_child(_wisps)


## Called by the player's attacks.
func take_hit(damage: float, knockback: Vector3, _hit_pos: Vector3) -> void:
	if state == State.DEAD:
		return
	health = maxf(health - damage, 0.0)
	health_changed.emit(health, max_health)
	_flash = 1.0
	_knock = knockback
	_knock.y = 0.0
	if health <= 0.0:
		_die(knockback)
		return
	# Forgiving combat: every hit staggers and interrupts the enemy's attack.
	_enter(State.STAGGER)
	_cooldown = maxf(_cooldown, 0.5)
	if knockback.length() > 0.1:
		_facing = atan2(knockback.x, knockback.z)  # Face the attacker.


func _die(knockback: Vector3) -> void:
	_enter(State.DEAD)
	collision_layer = 0
	remove_from_group(&"enemies")
	_wisps.emitting = false
	_knock = knockback * 1.3
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_model, "scale", Vector3(1.2, 0.02, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _enter(s: State) -> void:
	state = s
	_t = 0.0
	_hit_done = false


func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown -= delta
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	_flash_mat.albedo_color = Color(1.0, 0.95, 0.85, _flash * 0.6)
	# The overlay is an extra transparent pass per mesh: only attach it while flashing.
	var want_overlay: bool = _flash > 0.0
	if want_overlay != _overlay_on:
		_overlay_on = want_overlay
		for mi: MeshInstance3D in _flash_meshes:
			mi.material_overlay = _flash_mat if want_overlay else null

	var hv := Vector3.ZERO
	var to_target := Vector3.ZERO
	var dist: float = INF
	if target and is_instance_valid(target):
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
	var target_alive: bool = target != null and is_instance_valid(target) and float(target.get("health")) > 0.0

	match state:
		State.IDLE:
			if _t > 2.5:
				_t = 0.0
				var ang: float = _rng.randf() * TAU
				_idle_wander = (home + Vector3(cos(ang), 0, sin(ang)) * 3.0 - global_position)
				_idle_wander.y = 0.0
			if _idle_wander.length() > 0.5:
				hv = _idle_wander.normalized() * 1.2
				_idle_wander -= hv * delta
				_face_toward(hv, delta, 4.0)
			if target_alive and dist < aggro_range:
				_enter(State.CHASE)
		State.CHASE:
			if not target_alive or dist > aggro_range * 1.6:
				_enter(State.IDLE)
			elif dist > attack_range * 0.85:
				hv = to_target.normalized() * move_speed
				_face_toward(to_target, delta, 8.0)
			else:
				_face_toward(to_target, delta, 10.0)
				if _cooldown <= 0.0:
					_enter(State.WINDUP)
			hv += _separation() * 2.0
		State.WINDUP:
			_face_toward(to_target, delta, 5.0)  # Tracks a little, then commits.
			if _t >= windup_time:
				_enter(State.ATTACK)
				attacked.emit(self)
		State.ATTACK:
			hv = _facing_vec() * 7.5 * (1.0 - _t / attack_time)
			if not _hit_done and _t > attack_time * 0.3 and target_alive:
				var fwd: Vector3 = _facing_vec()
				if dist < attack_range + 0.6 and fwd.dot(to_target.normalized()) > 0.35:
					_hit_done = true
					if target.has_method("take_damage"):
						target.call("take_damage", attack_damage, fwd * 9.0)
			if _t >= attack_time:
				_enter(State.RECOVER)
		State.RECOVER:
			if _t >= recover_time:
				_cooldown = _rng.randf_range(0.8, 1.8)
				_enter(State.CHASE)
		State.STAGGER:
			hv = _knock
			_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
			if _t >= 0.38:
				_enter(State.CHASE)
		State.DEAD:
			hv = _knock
			_knock = _knock.move_toward(Vector3.ZERO, 12.0 * delta)

	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_animate(delta, Vector2(hv.x, hv.z).length())


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		if e == self:
			continue
		var d: Vector3 = global_position - (e as Node3D).global_position
		d.y = 0.0
		var l: float = d.length()
		if l < 1.8 and l > 0.01:
			push += d / l * (1.8 - l)
	return push


func _facing_vec() -> Vector3:
	return Vector3(sin(_facing), 0, cos(_facing))


func _face_toward(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	_facing = lerp_angle(_facing, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


func _animate(delta: float, speed: float) -> void:
	# Model faces +Z in local space after this rotation (front of the face is -Z, so add PI).
	_model.rotation.y = _facing + PI
	_phase += delta * (2.0 + speed * 2.2)
	var s: float = sin(_phase)
	var amp: float = clampf(speed / move_speed, 0.0, 1.0)
	_leg_l.rotation.x = s * 0.6 * amp
	_leg_r.rotation.x = -s * 0.6 * amp
	var arm_l := Vector3(-s * 0.4 * amp + 0.2, 0, -0.15)
	var arm_r := Vector3(s * 0.4 * amp + 0.2, 0, 0.15)
	var torso_x: float = -0.2 + sin(_phase * 0.5) * 0.04
	var eye: float = 1.0
	match state:
		State.WINDUP:
			var k: float = clampf(_t / windup_time, 0.0, 1.0)
			var e: float = k * k * (3.0 - 2.0 * k)
			arm_r = arm_r.lerp(Vector3(2.7, 0, 0.5), e)
			arm_l = arm_l.lerp(Vector3(1.0, 0, -0.4), e)
			torso_x = lerpf(torso_x, 0.35, e)
			eye = 1.0 + 3.0 * e
		State.ATTACK:
			var k2: float = clampf(_t / attack_time, 0.0, 1.0)
			arm_r = Vector3(2.7, 0, 0.5).lerp(Vector3(0.2, 0, -0.3), 1.0 - pow(1.0 - k2, 3.0))
			arm_l = Vector3(1.0, 0, -0.4).lerp(Vector3(-0.4, 0, -0.2), k2)
			torso_x = lerpf(0.35, -0.6, k2)
			eye = 3.0
		State.RECOVER:
			arm_r = Vector3(0.2, 0, -0.3).lerp(arm_r, clampf(_t / recover_time, 0.0, 1.0))
			torso_x = lerpf(-0.6, torso_x, clampf(_t / recover_time, 0.0, 1.0))
		State.STAGGER:
			var k3: float = sin(clampf(_t / 0.38, 0.0, 1.0) * PI)
			torso_x = lerpf(torso_x, 0.55, k3)
			arm_l = arm_l.lerp(Vector3(-0.6, 0, -0.8), k3)
			arm_r = arm_r.lerp(Vector3(-0.6, 0, 0.8), k3)
		State.DEAD:
			torso_x = lerpf(torso_x, 1.2, clampf(_t * 3.0, 0.0, 1.0))
			eye = maxf(0.0, 1.0 - _t * 2.0)
	_arm_l.rotation = arm_l
	_arm_r.rotation = arm_r
	# Torso pitch: positive tilts back, negative hunches forward.
	_torso.rotation.x = torso_x
	_head.rotation.x = -torso_x * 0.4
	_eye_mat.albedo_color = Color(COL_EYE.r * eye, COL_EYE.g * eye, COL_EYE.b * eye)
