class_name HeroModel
extends Node3D
## Procedurally built, stylized hero with a code-driven animation rig.
## The model faces -Z. All motion (walk cycle, lean, squash and stretch) is computed in code.

const COLOR_TUNIC := Color("3d5ba9")
const COLOR_CLOAK := Color("5b6c9e")
const COLOR_PLATE := Color("8a93a6")
const COLOR_SKIN := Color("e9b894")
const COLOR_HAIR := Color("4a3426")
const COLOR_LEATHER := Color("6b4a33")
const COLOR_BOOT := Color("3a2c24")
const COLOR_STEEL := Color("cfd6df")
const COLOR_GOLD := Color("d9a441")

## Per-instance colors (villagers reuse this rig with their own clothes).
var col_tunic: Color = COLOR_TUNIC
var col_cloak: Color = COLOR_CLOAK
var col_plate: Color = COLOR_PLATE
var col_skin: Color = COLOR_SKIN
var col_hair: Color = COLOR_HAIR
var col_leather: Color = COLOR_LEATHER
var col_boot: Color = COLOR_BOOT
var col_steel: Color = COLOR_STEEL
var col_gold: Color = COLOR_GOLD
## Villagers carry no sword.
var with_sword: bool = true

## Pose blending: 0 = full locomotion, 1 = upper body fully driven by `action_pose`.
var action_weight: float = 0.0
## Rotations (radians) for upper body joints while an action plays. Keys: torso, r_arm, r_fore, l_arm, l_fore.
var action_pose: Dictionary = {}

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var cape: Node3D
var sword: Node3D
var sword_tip: Node3D
var sword_base: Node3D

var _phase: float = 0.0
var _squash: float = 0.0
var _squash_vel: float = 0.0
var _lean: float = 0.0
var _air_blend: float = 0.0
var _dash_blend: float = 0.0
var _time: float = 0.0
var _materials: Dictionary = {}


func _ready() -> void:
	_build()


func _mat(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	_materials[key] = m
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3, pivot_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 6
	return c


func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 18
	s.rings = 10
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _build() -> void:
	hips = _pivot(self, Vector3(0, 0.95, 0), "Hips")
	_part(hips, _capsule(0.19, 0.42), _mat(col_leather), Vector3(0, 0.02, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.85))
	# Belt with buckle.
	_part(hips, _box(Vector3(0.44, 0.07, 0.3)), _mat(col_boot, 0.5), Vector3(0, 0.1, 0))
	_part(hips, _box(Vector3(0.08, 0.07, 0.03)), _mat(col_gold, 0.3, 0.8), Vector3(0, 0.1, -0.16))
	# Tunic skirt.
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.2
	skirt.bottom_radius = 0.27
	skirt.height = 0.3
	skirt.radial_segments = 16
	_part(hips, skirt, _mat(col_tunic), Vector3(0, -0.08, 0), Vector3.ZERO, Vector3(1, 1, 0.8))

	torso = _pivot(hips, Vector3(0, 0.08, 0), "Torso")
	_part(torso, _capsule(0.22, 0.62), _mat(col_tunic), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.05, 1, 0.75))
	# Breastplate.
	_part(torso, _capsule(0.2, 0.42), _mat(col_plate, 0.45, 0.3), Vector3(0, 0.36, -0.06), Vector3.ZERO, Vector3(1.0, 0.95, 0.62))
	# Royal-blue sash across the plate.
	_part(torso, _box(Vector3(0.08, 0.5, 0.3)), _mat(col_tunic, 0.6), Vector3(0.02, 0.36, -0.05), Vector3(0, 0, 0.7))
	# Pauldrons.
	for side: float in [-1.0, 1.0]:
		_part(torso, _sphere(0.12), _mat(col_plate, 0.45, 0.3), Vector3(0.27 * side, 0.54, 0), Vector3.ZERO, Vector3(1.15, 0.8, 1.1))

	head = _pivot(torso, Vector3(0, 0.64, 0), "Head")
	_part(head, _capsule(0.06, 0.14), _mat(col_skin), Vector3(0, 0.02, 0))
	_part(head, _sphere(0.135), _mat(col_skin, 0.8), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(0.95, 1.08, 1.0))
	# Hair: cap plus a swept tail.
	_part(head, _sphere(0.145), _mat(col_hair, 0.9), Vector3(0, 0.19, 0.025), Vector3(-0.2, 0, 0), Vector3(1.0, 0.85, 1.05))
	_part(head, _capsule(0.05, 0.22), _mat(col_hair, 0.9), Vector3(0, 0.12, 0.13), Vector3(0.5, 0, 0))
	# Eyes give the head a readable facing.
	for side: float in [-1.0, 1.0]:
		_part(head, _sphere(0.018), _mat(Color("1e2125"), 0.4), Vector3(0.045 * side, 0.16, -0.125))

	cape = _pivot(torso, Vector3(0, 0.56, 0.15), "Cape")
	_part(cape, _box(Vector3(0.46, 0.85, 0.03)), _mat(col_cloak, 0.85), Vector3(0, -0.42, 0))
	_part(cape, _box(Vector3(0.5, 0.06, 0.05)), _mat(col_gold, 0.3, 0.8), Vector3(0, 0.0, -0.01))

	arm_l = _pivot(torso, Vector3(-0.29, 0.5, 0), "ArmL")
	arm_r = _pivot(torso, Vector3(0.29, 0.5, 0), "ArmR")
	for arm: Node3D in [arm_l, arm_r]:
		_part(arm, _capsule(0.07, 0.34), _mat(col_tunic), Vector3(0, -0.14, 0))
	fore_l = _pivot(arm_l, Vector3(0, -0.3, 0), "ForeL")
	fore_r = _pivot(arm_r, Vector3(0, -0.3, 0), "ForeR")
	for fore: Node3D in [fore_l, fore_r]:
		_part(fore, _capsule(0.065, 0.3), _mat(col_leather, 0.6), Vector3(0, -0.13, 0))
		_part(fore, _sphere(0.065), _mat(col_skin), Vector3(0, -0.3, 0))

	# Sword in the right hand. Blade points along the hand's local -Z when held forward.
	sword = _pivot(fore_r, Vector3(0, -0.3, 0), "Sword")
	sword_base = _pivot(sword, Vector3(0, 0, -0.18), "SwordBase")
	sword_tip = _pivot(sword, Vector3(0, 0, -1.05), "SwordTip")
	if with_sword:
		_part(sword, _box(Vector3(0.045, 0.045, 0.2)), _mat(col_leather, 0.6), Vector3(0, 0, 0.0))
		_part(sword, _box(Vector3(0.26, 0.05, 0.05)), _mat(col_gold, 0.3, 0.8), Vector3(0, 0, -0.12))
		_part(sword, _box(Vector3(0.07, 0.018, 0.82)), _mat(col_steel, 0.2, 0.9), Vector3(0, 0, -0.55))
		var tip := PrismMesh.new()
		tip.size = Vector3(0.07, 0.14, 0.018)
		_part(sword, tip, _mat(col_steel, 0.2, 0.9), Vector3(0, 0, -1.02), Vector3(-PI / 2, 0, 0))
		_part(sword, _sphere(0.035), _mat(col_gold, 0.3, 0.8), Vector3(0, 0, 0.12))

	leg_l = _pivot(hips, Vector3(-0.11, -0.04, 0), "LegL")
	leg_r = _pivot(hips, Vector3(0.11, -0.04, 0), "LegR")
	for leg: Node3D in [leg_l, leg_r]:
		_part(leg, _capsule(0.085, 0.46), _mat(col_leather, 0.75), Vector3(0, -0.2, 0))
	shin_l = _pivot(leg_l, Vector3(0, -0.43, 0), "ShinL")
	shin_r = _pivot(leg_r, Vector3(0, -0.43, 0), "ShinR")
	for shin: Node3D in [shin_l, shin_r]:
		_part(shin, _capsule(0.08, 0.4), _mat(col_boot, 0.6), Vector3(0, -0.2, 0))
		_part(shin, _box(Vector3(0.13, 0.08, 0.24)), _mat(col_boot, 0.6), Vector3(0, -0.43, -0.05))
		_part(shin, _sphere(0.07), _mat(col_plate, 0.45, 0.3), Vector3(0, -0.02, -0.05), Vector3.ZERO, Vector3(1, 1, 0.8))

	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Called by the controller every frame.
## speed_ratio: 0 idle, ~0.6 walk, 1 sprint. vertical: vertical velocity.
func animate(delta: float, speed_ratio: float, on_floor: bool, vertical: float, accel_lean: float, dashing: bool) -> void:
	_time += delta
	var moving: float = clampf(speed_ratio, 0.0, 1.2)
	_phase = fmod(_phase + delta * lerpf(0.0, 11.0, clampf(moving, 0.0, 1.0)) + delta * 4.0 * moving, TAU)
	_air_blend = move_toward(_air_blend, 0.0 if on_floor else 1.0, delta * 8.0)
	_dash_blend = move_toward(_dash_blend, 1.0 if dashing else 0.0, delta * 14.0)
	_lean = lerpf(_lean, accel_lean, 1.0 - exp(-delta * 8.0))

	# Squash and stretch: a damped spring around 0.
	_squash_vel += (-_squash * 260.0 - _squash_vel * 16.0) * delta
	_squash += _squash_vel * delta
	var stretch: float = clampf(vertical * 0.012, -0.08, 0.1) * _air_blend
	var sy: float = 1.0 - _squash + stretch
	var sxz: float = 1.0 / sqrt(maxf(sy, 0.2))
	scale = Vector3(sxz, sy, sxz)

	var s: float = sin(_phase)
	var c: float = cos(_phase)
	var amp: float = clampf(moving, 0.0, 1.0)
	var run_amp: float = 0.55 * amp + 0.25 * maxf(moving - 0.65, 0.0)

	# Legs.
	var leg_swing: float = s * run_amp * 1.3
	var ground_l := Vector2(leg_swing, maxf(0.0, -c) * 1.2 * amp)
	var ground_r := Vector2(-leg_swing, maxf(0.0, c) * 1.2 * amp)
	var air_l := Vector2(0.7, 1.2)
	var air_r := Vector2(-0.3, 0.5)
	var l: Vector2 = ground_l.lerp(air_l, _air_blend)
	var r: Vector2 = ground_r.lerp(air_r, _air_blend)
	var dash_leg := Vector2(-0.6, 0.9)
	l = l.lerp(Vector2(0.9, 1.4), _dash_blend)
	r = r.lerp(dash_leg, _dash_blend)
	leg_l.rotation = Vector3(l.x, 0, 0)
	shin_l.rotation = Vector3(-l.y, 0, 0)
	leg_r.rotation = Vector3(r.x, 0, 0)
	shin_r.rotation = Vector3(-r.y, 0, 0)

	# Hips bob and lean.
	var bob: float = absf(s) * 0.07 * amp
	hips.position.y = 0.95 - 0.03 * amp + bob * (1.0 - _air_blend)
	hips.rotation = Vector3(-_lean * 0.35 - 0.12 * amp - 0.5 * _dash_blend, s * 0.12 * amp, 0)

	# Locomotion upper body.
	var breathe: float = sin(_time * 2.2) * 0.02 * (1.0 - amp)
	var loco := {
		"torso": Vector3(-0.08 * amp + breathe, -s * 0.18 * amp, 0),
		"r_arm": Vector3(s * run_amp * 1.1 - 0.15 * amp, 0, 0.12 + 0.15 * _air_blend),
		"r_fore": Vector3(0.35 + 0.6 * amp, 0, 0),
		"l_arm": Vector3(-s * run_amp * 1.1, 0, -0.12 - 0.5 * _air_blend),
		"l_fore": Vector3(0.25 + 0.7 * amp, 0, 0),
	}
	# Dash pose: arms swept back.
	if _dash_blend > 0.0:
		loco["r_arm"] = (loco["r_arm"] as Vector3).lerp(Vector3(-0.9, 0, 0.5), _dash_blend)
		loco["l_arm"] = (loco["l_arm"] as Vector3).lerp(Vector3(-0.9, 0, -0.5), _dash_blend)
	var w: float = clampf(action_weight, 0.0, 1.0)
	torso.rotation = _blend(loco, "torso", w)
	arm_r.rotation = _blend(loco, "r_arm", w)
	fore_r.rotation = _blend(loco, "r_fore", w)
	arm_l.rotation = _blend(loco, "l_arm", w)
	fore_l.rotation = _blend(loco, "l_fore", w)

	# Sword rests angled down-back while running, held forward in actions.
	var rest_sword := Vector3(-1.2, 0, 0)
	var act_sword: Vector3 = action_pose.get("sword", Vector3(-PI / 2, 0, 0))
	sword.rotation = rest_sword.lerp(act_sword, w)

	head.rotation = Vector3(0.1 * amp + _lean * 0.15, s * 0.1 * amp, 0)
	cape.rotation = Vector3(0.15 + 0.9 * amp + 0.5 * _air_blend * signf(-vertical) + 0.6 * _dash_blend + sin(_time * 7.0) * 0.05 * amp, 0, sin(_time * 3.1) * 0.04)


func _blend(loco: Dictionary, key: String, w: float) -> Vector3:
	var a: Vector3 = loco[key]
	if w <= 0.0 or not action_pose.has(key):
		return a
	var b: Vector3 = action_pose[key]
	return a.lerp(b, w)


## Kick the squash spring. Positive = squash down (landing), negative = stretch (take-off).
func impulse_squash(amount: float) -> void:
	_squash_vel += amount * 9.0
