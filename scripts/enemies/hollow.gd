class_name Hollow
extends CharacterBody3D
## The Hollowed: a husk emptied by the Veil. First enemy type.
## State machine: IDLE -> CHASE -> WINDUP -> ATTACK -> RECOVER, with STAGGER and DEAD.
## Telegraphs clearly (eyes flare, arm rises) so dodging always feels fair.

signal health_changed(value: float, max_value: float)
signal died(enemy: Hollow)
signal attacked(enemy: Hollow)
## Bosses only: fired once when health drops below half.
signal phase_two(enemy: Hollow)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD, RETURN }

const COL_BODY := Color("353a42")
const COL_DARK := Color("1e2125")
const COL_CLOTH := Color("4a483e")
const COL_BONE := Color("c9c6b8")
const COL_EYE := Color("bfe6ff")
## Cold Veil light leaking through cracks in the husk.
const COL_VEIL := Color("7fc4f2")

@export var display_name: String = "Hollowed Warden"
@export var level: int = 2
## Bosses: stagger only every N hits (poise), knockback reduced, phase two at 50% health.
@export var is_boss: bool = false
@export var stagger_every: int = 1
var _hits_taken: int = 0
var _phase_two_done: bool = false
@export var max_health: float = 60.0
@export var move_speed: float = 4.2
@export var aggro_range: float = 13.0
## Leash: a Hollow never chases further than this from its home. Then it walks back and heals.
@export var leash_range: float = 16.0
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
var _glow_mat: StandardMaterial3D
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
	# Same shader variant as the eyes (unshaded, albedo only): no extra shader compile.
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.albedo_color = COL_VEIL

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

	# Gaunt husk in the remains of a Warden's robe. One merged mesh per animated pivot, plus
	# two tiny unshaded glow meshes (rib cracks, eye sockets) for the cold Veil light.
	var I := Transform3D.IDENTITY
	var rag: Color = COL_CLOTH
	var rag_dark: Color = COL_CLOTH.darkened(0.14)
	var rag_light: Color = COL_CLOTH.lightened(0.2)
	var husk: Color = COL_BODY.lightened(0.14)
	var bone_dim: Color = COL_BONE.darkened(0.3)
	var glow := MeshKit.new()

	# --- Hips: dark under-robe, layered tattered strips, rope belt ---
	var k := MeshKit.new()
	k.loft(I, [[0.08, 0.14, 0.1, 0.0, rag_dark], [-0.2, 0.18, 0.135, 0.01, rag_dark], [-0.5, 0.215, 0.165, 0.02, rag_dark.darkened(0.2)]], 9, false, false)
	for f: int in 9:
		var a0: float = TAU * (f + 0.5) / 9.0
		_rag_strip(k, a0, 0.07, 0.5 + fmod(f * 0.23, 0.26), 0.2, rag_dark if f % 2 == 0 else rag.darkened(0.12), 0.0)
	for f2: int in 7:
		var a1: float = TAU * f2 / 7.0 + 0.2
		_rag_strip(k, a1, 0.09, 0.3 + fmod(f2 * 0.31, 0.3), 0.17, rag if f2 % 2 == 0 else rag_light, 0.022)
	k.loft(I, [[0.1, 0.152, 0.112, 0.0, COL_BONE.darkened(0.45)], [0.06, 0.156, 0.116, 0.0, COL_BONE.darkened(0.45)]], 9, false, false)
	k.box(Transform3D(Basis(Vector3.BACK, 0.2), Vector3(0.07, -0.02, -0.125)), Vector3(0.02, 0.16, 0.02), COL_BONE.darkened(0.45))
	k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.085, -0.14, -0.128)), Vector3(0.035, 0.02, 0.09), COL_BONE)
	_mesh(hips, k, false)

	# --- Torso: wasted waist, open rib cage with glowing cracks, bony shoulders, torn mantle ---
	k = MeshKit.new()
	k.loft(I, [[0.0, 0.105, 0.078, 0.0, husk], [0.14, 0.1, 0.075, 0.0, husk], [0.22, 0.14, 0.095, -0.008, COL_DARK], [0.44, 0.168, 0.108, -0.012, husk], [0.5, 0.19, 0.11, 0.0, husk], [0.57, 0.12, 0.09, 0.0, husk], [0.62, 0.05, 0.05, -0.04, husk]], 9)
	# Ribs: four bone pairs angled down from the sternum, with Veil light in the gaps.
	for r: int in 4:
		var ry: float = 0.245 + r * 0.055
		var rw: float = 0.1 + r * 0.012
		for side: float in [-1.0, 1.0]:
			k.box(Transform3D(Basis(Vector3.UP, side * 0.42) * Basis(Vector3.BACK, side * 0.28), Vector3(side * (0.03 + rw * 0.5), ry - 0.012, -0.098 - r * 0.003)), Vector3(rw, 0.024, 0.03), COL_BONE if r % 2 == 0 else bone_dim.lightened(0.15))
			if r < 3:
				glow.box(Transform3D(Basis(Vector3.UP, side * 0.42) * Basis(Vector3.BACK, side * 0.28), Vector3(side * (0.035 + rw * 0.4), ry + 0.016, -0.093 - r * 0.003)), Vector3(rw * 0.7, 0.01, 0.024), COL_VEIL)
	k.box(Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(0, 0.34, -0.116)), Vector3(0.032, 0.24, 0.026), COL_BONE)
	# Jagged crack down the belly and a faint line along the spine.
	var crack: Array[Vector3] = [Vector3(0.0, 0.2, 0.5), Vector3(0.022, 0.155, -0.6), Vector3(-0.004, 0.105, 0.45), Vector3(0.016, 0.06, -0.3)]
	for cp: Vector3 in crack:
		glow.box(Transform3D(Basis(Vector3.BACK, cp.z), Vector3(cp.x, cp.y, -0.079)), Vector3(0.012, 0.07, 0.012), COL_VEIL)
	for sp: int in 4:
		glow.box(Transform3D(Basis(), Vector3(0, 0.225 + sp * 0.09, 0.094 + sp * 0.006)), Vector3(0.014, 0.04, 0.02), COL_VEIL)
	# Bone spurs along the spine.
	for b2: int in 5:
		k.wedge(Transform3D(Basis(Vector3.RIGHT, PI - 0.5), Vector3(0, 0.18 + b2 * 0.09, 0.1 + b2 * 0.008)), Vector3(0.035, 0.035, 0.1 + b2 * 0.016), COL_BONE)
	# Torn mantle: open at the chest, ragged strips hanging over shoulders and back.
	k.loft(I, [[0.47, 0.21, 0.135, 0.03, rag], [0.57, 0.17, 0.125, 0.035, rag_light], [0.65, 0.08, 0.08, 0.02, rag_light]], 9, false, false)
	var mantle: Array[float] = [0.35, 0.95, 1.5, 2.1, 2.75, 3.6, 4.3, 5.0, 5.7]
	for mi2: int in mantle.size():
		var ma: float = mantle[mi2]
		var front: bool = sin(ma) < -0.3
		var mlen: float = (0.1 if front else 0.2) + fmod(mi2 * 0.37, 0.16)
		_rag_strip(k, ma, 0.5, mlen, 0.14, rag if mi2 % 2 == 0 else rag_dark, 0.07, 0.04)
	# Broken shoulder bone jutting through the cloth.
	k.wedge(Transform3D(Basis(Vector3.BACK, 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 0.6, 0.02)), Vector3(0.05, 0.04, 0.2), COL_BONE)
	k.wedge(Transform3D(Basis(Vector3.BACK, -0.75) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.21, 0.57, 0.03)), Vector3(0.04, 0.035, 0.12), bone_dim)
	_mesh(_torso, k, false)
	var glow_mi := MeshInstance3D.new()
	glow_mi.mesh = glow.commit()
	glow_mi.material_override = _glow_mat
	glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_torso.add_child(glow_mi)

	# --- Head: pale skull with hollow sockets and a hanging jaw, deep hood set back from the face ---
	k = MeshKit.new()
	var skull: Color = COL_BONE.darkened(0.38)
	k.loft(I, [[0.0, 0.045, 0.045, 0.0, COL_DARK], [0.06, 0.05, 0.06, -0.03, skull.darkened(0.25)], [0.11, 0.07, 0.082, -0.022, skull], [0.2, 0.08, 0.09, -0.002, skull], [0.27, 0.062, 0.076, 0.008, skull], [0.3, 0.02, 0.03, 0.01, skull]], 8)
	k.box(Transform3D(Basis(), Vector3(0, 0.205, -0.088)), Vector3(0.13, 0.02, 0.022), skull.lightened(0.12))  # Brow ridge.
	k.box(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.055, -0.07)), Vector3(0.075, 0.035, 0.05), skull.darkened(0.1))  # Hanging jaw.
	k.box(Transform3D(Basis(), Vector3(0, 0.09, -0.09)), Vector3(0.06, 0.035, 0.016), COL_DARK)  # Open mouth.
	k.wedge(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.135, -0.097)), Vector3(0.024, 0.012, 0.035), COL_DARK)  # Nose cavity.
	var eyes := MeshKit.new()
	for side2: float in [-1.0, 1.0]:
		k.box(Transform3D(Basis(Vector3.BACK, side2 * 0.2), Vector3(0.037 * side2, 0.168, -0.089)), Vector3(0.046, 0.04, 0.014), COL_DARK)  # Socket.
		k.box(Transform3D(Basis(Vector3.UP, -side2 * 0.6), Vector3(0.062 * side2, 0.12, -0.066)), Vector3(0.03, 0.05, 0.012), skull.darkened(0.35))  # Cheek hollow.
		eyes.box(Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0.037 * side2, 0.166, -0.095)), Vector3(0.017, 0.017, 0.01), COL_EYE)
	k.loft(I, [[0.0, 0.125, 0.105, 0.065, rag], [0.15, 0.132, 0.118, 0.06, rag], [0.28, 0.108, 0.118, 0.05, rag_light], [0.355, 0.03, 0.05, 0.075, rag_light]], 9, false, true)
	# Hood rim: a peak over the brow and ragged flaps beside the cheeks.
	k.wedge(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.292, -0.075)), Vector3(0.2, 0.05, 0.13), rag_light)
	for side3: float in [-1.0, 1.0]:
		k.box(Transform3D(Basis(Vector3.UP, side3 * 0.25) * Basis(Vector3.BACK, -side3 * 0.1), Vector3(0.108 * side3, 0.16, -0.03)), Vector3(0.022, 0.25, 0.075), rag)
		k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.11 * side3, -0.005, -0.03)), Vector3(0.022, 0.07, 0.1), rag_dark)
	k.wedge(Transform3D(Basis(Vector3.RIGHT, 0.45) * Basis(Vector3.UP, PI), Vector3(0, 0.32, 0.16)), Vector3(0.09, 0.05, 0.22), rag)  # Hood point.
	_mesh(_head, k, false)
	var eye_mi := MeshInstance3D.new()
	eye_mi.mesh = eyes.commit()
	eye_mi.material_override = _eye_mat
	eye_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(eye_mi)

	# --- Arms: long and thin, torn sleeve, bone elbow, four-fingered claw hand ---
	for arm: Node3D in [_arm_l, _arm_r]:
		var as2: float = -1.0 if arm == _arm_l else 1.0
		k = MeshKit.new()
		k.loft(I, [[0.03, 0.05, 0.05, 0.0, husk], [-0.08, 0.048, 0.048, 0.0, husk], [-0.3, 0.033, 0.033, 0.0, husk], [-0.36, 0.046, 0.046, 0.0, COL_BONE], [-0.42, 0.034, 0.034, 0.0, COL_DARK], [-0.72, 0.027, 0.025, 0.0, COL_DARK], [-0.79, 0.046, 0.024, 0.0, COL_DARK]], 7)
		# Sleeve stump with hanging tatters.
		k.loft(I, [[0.06, 0.072, 0.072, 0.0, rag], [-0.16, 0.078, 0.078, 0.01, rag_dark]], 7, false, false)
		for t: int in 4:
			var ta: float = TAU * t / 4.0 + 0.6 + as2 * 0.3
			var tl: float = 0.14 + fmod(t * 0.41, 0.2)
			var top := Vector3(cos(ta) * 0.078, -0.16, sin(ta) * 0.078 + 0.01)
			var tang := Vector3(-sin(ta), 0, cos(ta)) * 0.04
			k.tri(I, top - tang, top + tang, top + Vector3(cos(ta) * 0.02, -tl, sin(ta) * 0.02), rag if t % 2 == 0 else rag_dark, true)
		# Wrist wrap, then the claw: finger bones fan out and end in long pale talons.
		k.loft(I, [[-0.66, 0.034, 0.032, 0.0, rag_light], [-0.71, 0.033, 0.031, 0.0, rag_light]], 7, false, false)
		for c: int in 4:
			var spread: float = (c - 1.5) * 0.2
			var fxf := Transform3D(Basis(Vector3.BACK, spread) * Basis(Vector3.RIGHT, 0.18), Vector3((c - 1.5) * 0.024, -0.79, 0.0))
			k.box(fxf * Transform3D(Basis(), Vector3(0, -0.045, 0)), Vector3(0.017, 0.09, 0.017), COL_DARK.lightened(0.08))
			var claw_len: float = 0.2 - absf(c - 1.5) * 0.025
			k.wedge(fxf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.35), Vector3(0, -0.09 - claw_len * 0.45, -claw_len * 0.17)), Vector3(0.02, 0.018, claw_len), COL_BONE)
		# Thumb talon.
		k.wedge(Transform3D(Basis(Vector3.BACK, -as2 * 0.9) * Basis(Vector3.RIGHT, -PI * 0.5 + 0.5), Vector3(-as2 * 0.06, -0.83, -0.02)), Vector3(0.02, 0.018, 0.13), COL_BONE)
		_mesh(arm, k, false)

	# --- Legs: thin shanks with a bone knee, rag wraps and clawed feet ---
	for leg: Node3D in [_leg_l, _leg_r]:
		k = MeshKit.new()
		k.loft(I, [[0.03, 0.07, 0.07, 0.0, COL_DARK], [-0.4, 0.045, 0.045, 0.0, COL_DARK], [-0.46, 0.052, 0.052, -0.01, COL_BONE], [-0.52, 0.036, 0.036, 0.0, husk], [-0.85, 0.03, 0.03, 0.0, COL_DARK], [-0.9, 0.04, 0.085, -0.04, COL_DARK]], 7)
		k.loft(I, [[-0.6, 0.04, 0.04, 0.0, rag], [-0.7, 0.037, 0.037, 0.0, rag_dark], [-0.74, 0.036, 0.036, 0.0, rag_dark]], 7, false, false)
		for tc: int in 3:
			k.wedge(Transform3D(Basis(Vector3.UP, (tc - 1) * -0.35), Vector3((tc - 1) * 0.028, -0.885, -0.14)), Vector3(0.022, 0.025, 0.08), COL_BONE)
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


## One tattered cloth strip hanging from an elliptical ring: a double-sided quad ending in a point.
## `angle` around Y, `top_y` where it starts, `length` down, `width` at the top, `out` extra radius.
func _rag_strip(k: MeshKit, angle: float, top_y: float, length: float, width: float, col: Color, out: float, flare: float = 0.14) -> void:
	var dir := Vector3(cos(angle), 0, sin(angle))
	var tang := Vector3(-sin(angle), 0, cos(angle))
	var top: Vector3 = Vector3(dir.x * (0.15 + out), top_y, dir.z * (0.11 + out))
	var bot: Vector3 = Vector3(dir.x * (0.15 + out + flare * length), top_y - length, dir.z * (0.11 + out + flare * length) + 0.02)
	var hw: float = width * 0.5
	var a: Vector3 = top - tang * hw
	var b: Vector3 = top + tang * hw
	var c: Vector3 = bot + tang * hw * 0.8
	var d: Vector3 = bot - tang * hw * 0.8
	var I := Transform3D.IDENTITY
	k.quad(I, a, b, c, d, col, true)
	# Torn end: an off-centre point.
	k.tri(I, d, c, bot + tang * hw * 0.3 + Vector3(dir.x * 0.02, -0.07 - length * 0.12, dir.z * 0.02), col.darkened(0.12), true)


## Called by the player's attacks.
func take_hit(damage: float, knockback: Vector3, _hit_pos: Vector3) -> void:
	if state == State.DEAD:
		return
	health = maxf(health - damage, 0.0)
	health_changed.emit(health, max_health)
	_flash = 1.0
	_knock = knockback * (0.25 if is_boss else 1.0)
	_knock.y = 0.0
	if health <= 0.0:
		_die(knockback)
		return
	if is_boss and not _phase_two_done and health < max_health * 0.5:
		_phase_two_done = true
		windup_time *= 0.75
		move_speed *= 1.25
		phase_two.emit(self)
	_hits_taken += 1
	if _hits_taken % maxi(stagger_every, 1) != 0:
		if state == State.IDLE:
			_enter(State.CHASE)
		return
	# Forgiving combat: hits stagger and interrupt the enemy's attack.
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
			var from_home: float = Vector2(global_position.x - home.x, global_position.z - home.z).length()
			if not target_alive:
				_enter(State.IDLE)
			elif from_home > leash_range or dist > aggro_range * 1.4:
				_enter(State.RETURN)
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
						target.call("take_damage", attack_damage, fwd * 9.0, self)
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
		State.RETURN:
			# Walk home, ignore the player, regenerate (RuneScape-style reset).
			var to_home: Vector3 = home - global_position
			to_home.y = 0.0
			if to_home.length() < 1.2:
				_enter(State.IDLE)
			else:
				hv = to_home.normalized() * move_speed * 1.2
				_face_toward(to_home, delta, 8.0)
			if health < max_health:
				health = minf(health + max_health * 0.5 * delta, max_health)
				health_changed.emit(health, max_health)
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
	# Veil light in the cracks: slow pulse, flares with the eyes on a windup, dies with the husk.
	var pulse: float = (0.62 + 0.2 * sin(_phase * 0.7)) * clampf(0.6 + eye * 0.4, 0.0, 1.6)
	_glow_mat.albedo_color = Color(COL_VEIL.r * pulse, COL_VEIL.g * pulse, COL_VEIL.b * pulse)
