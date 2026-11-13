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
## Villagers wear no armor or cape.
var armored: bool = true
## Mesh kits per pivot while building; `metal` selects the shiny armor material.
var _kits: Dictionary = {}

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


func _ready() -> void:
	_build()


func _pivot(parent: Node3D, pos: Vector3, pivot_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	# Low-poly anatomy: every body part is a faceted loft of elliptical rings with
	# real proportions (about 7.5 heads tall). Clothing is painted per ring band, armor is
	# a separate metallic shell. One cloth mesh + one metal mesh per animated pivot.
	var sk: Color = col_skin
	var skin_dark: Color = col_skin.darkened(0.12)
	hips = _pivot(self, Vector3(0, 0.95, 0), "Hips")
	torso = _pivot(hips, Vector3(0, 0.08, 0), "Torso")
	head = _pivot(torso, Vector3(0, 0.6, 0), "Head")
	arm_l = _pivot(torso, Vector3(-0.215, 0.5, 0), "ArmL")
	arm_r = _pivot(torso, Vector3(0.215, 0.5, 0), "ArmR")
	fore_l = _pivot(arm_l, Vector3(0, -0.28, 0), "ForeL")
	fore_r = _pivot(arm_r, Vector3(0, -0.28, 0), "ForeR")
	leg_l = _pivot(hips, Vector3(-0.095, -0.05, 0), "LegL")
	leg_r = _pivot(hips, Vector3(0.095, -0.05, 0), "LegR")
	shin_l = _pivot(leg_l, Vector3(0, -0.43, 0), "ShinL")
	shin_r = _pivot(leg_r, Vector3(0, -0.43, 0), "ShinR")
	cape = _pivot(torso, Vector3(0, 0.53, 0.115), "Cape")
	sword = _pivot(fore_r, Vector3(0, -0.27, 0), "Sword")
	sword_base = _pivot(sword, Vector3(0, 0, -0.18), "SwordBase")
	sword_tip = _pivot(sword, Vector3(0, 0, -1.12), "SwordTip")

	var I := Transform3D.IDENTITY
	var trousers: Color = col_leather
	var shirt: Color = col_tunic

	# --- Pelvis, belt, skirt ---
	var k: MeshKit = _kit(hips)
	k.loft(I, [[-0.13, 0.15, 0.105, 0.0, trousers], [-0.04, 0.165, 0.115, 0.0, trousers], [0.06, 0.155, 0.105, 0.0, shirt], [0.1, 0.145, 0.1, 0.0, shirt]], 10)
	k.loft(I, [[0.03, 0.172, 0.122, 0.0, col_boot], [0.1, 0.168, 0.12, 0.0, col_boot]], 10, false, false)
	k.box(Transform3D(Basis(), Vector3(0, 0.065, -0.125)), Vector3(0.07, 0.06, 0.02), col_gold)
	k.box(Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.15, 0.03, -0.085)), Vector3(0.08, 0.1, 0.05), col_leather.darkened(0.15))  # Pouch.
	# Tabard skirt: flares out, gold hem.
	var skirt_len: float = 0.36 if armored else 0.2
	k.loft(I, [[0.06, 0.17, 0.125, 0.0, shirt], [0.06 - skirt_len, 0.22, 0.16, 0.0, col_gold], [0.06 - skirt_len - 0.025, 0.222, 0.162, 0.0, col_gold]], 10, false, false)

	# --- Torso: waist, ribs, chest, shoulders, neck ---
	k = _kit(torso)
	k.loft(I, [
		[0.0, 0.145, 0.1, 0.0, shirt], [0.12, 0.15, 0.105, -0.005, shirt], [0.25, 0.17, 0.115, -0.01, shirt],
		[0.38, 0.19, 0.122, -0.015, shirt], [0.47, 0.2, 0.115, -0.01, shirt], [0.55, 0.16, 0.1, 0.0, sk],
		[0.6, 0.065, 0.06, 0.005, sk],
	], 10)
	if armored:
		var m: MeshKit = _kit(torso, true)
		# Cuirass: sculpted breastplate and backplate shell with a gold rim.
		m.loft(I, [[0.17, 0.165, 0.118, -0.01, col_gold], [0.2, 0.17, 0.122, -0.012, col_plate], [0.3, 0.183, 0.13, -0.022, col_plate], [0.4, 0.2, 0.136, -0.03, col_plate], [0.48, 0.2, 0.125, -0.018, col_gold], [0.5, 0.18, 0.11, -0.01, col_gold]], 10, false, false)
		# Ridge down the breastplate.
		m.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.33, -0.16)), Vector3(0.03, 0.025, 0.24), col_plate.lightened(0.1))
		# Gorget.
		m.loft(I, [[0.5, 0.12, 0.09, 0.0, col_plate], [0.57, 0.085, 0.07, 0.0, col_gold]], 10, false, false)
	# Royal sash (diagonal) and collar.
	k.box(Transform3D(Basis(Vector3.BACK, 0.75), Vector3(0.0, 0.32, -0.142)), Vector3(0.07, 0.5, 0.02), col_cloak if not armored else col_tunic.lightened(0.08))

	# --- Head: neck, jaw, cheekbones, brow, crown ---
	k = _kit(head)
	k.loft(I, [
		[0.0, 0.055, 0.05, 0.005, sk], [0.06, 0.05, 0.05, 0.0, sk], [0.085, 0.066, 0.07, -0.025, sk],
		[0.13, 0.082, 0.09, -0.018, sk], [0.18, 0.088, 0.098, -0.008, sk], [0.225, 0.09, 0.102, 0.0, sk],
		[0.28, 0.08, 0.094, 0.008, sk], [0.32, 0.05, 0.065, 0.012, sk], [0.34, 0.015, 0.02, 0.012, sk],
	], 10, false, true)
	# Chin, nose, brow ridge, ears, eyes.
	k.box(Transform3D(Basis(), Vector3(0, 0.095, -0.085)), Vector3(0.05, 0.035, 0.03), skin_dark)
	k.wedge(Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0.175, -0.108)), Vector3(0.028, 0.05, 0.035), skin_dark)
	k.box(Transform3D(Basis(), Vector3(0, 0.218, -0.095)), Vector3(0.13, 0.018, 0.025), skin_dark)
	for side: float in [-1.0, 1.0]:
		k.box(Transform3D(Basis(Vector3.UP, side * 0.3), Vector3(0.088 * side, 0.18, 0.005)), Vector3(0.02, 0.05, 0.035), skin_dark)
		k.box(Transform3D(Basis(), Vector3(0.036 * side, 0.198, -0.096)), Vector3(0.026, 0.013, 0.01), Color("1e2125"))
		k.box(Transform3D(Basis(), Vector3(0.036 * side, 0.212, -0.098)), Vector3(0.034, 0.008, 0.012), col_hair)  # Brows.
	# Hair: swept cap plus a tied tail.
	k.loft(I, [[0.19, 0.097, 0.11, 0.022, col_hair], [0.25, 0.1, 0.112, 0.012, col_hair], [0.3, 0.088, 0.103, 0.012, col_hair], [0.345, 0.05, 0.07, 0.014, col_hair], [0.365, 0.01, 0.02, 0.014, col_hair]], 10, false, true)
	k.box(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.14, 0.105)), Vector3(0.05, 0.16, 0.04), col_hair)

	# --- Arms: deltoid, biceps, elbow / forearm, wrist, hand ---
	for side2: float in [-1.0, 1.0]:
		var arm: Node3D = arm_l if side2 < 0.0 else arm_r
		var fore: Node3D = fore_l if side2 < 0.0 else fore_r
		k = _kit(arm)
		k.loft(I, [[0.03, 0.06, 0.06, 0.0, shirt], [-0.06, 0.066, 0.062, 0.0, shirt], [-0.16, 0.052, 0.054, -0.005, shirt], [-0.27, 0.043, 0.045, 0.0, shirt], [-0.3, 0.04, 0.042, 0.0, shirt]], 8)
		if armored:
			var pm: MeshKit = _kit(arm, true)
			# Layered pauldron with a gold trim lip.
			pm.loft(Transform3D(Basis(), Vector3(0.015 * side2, 0, 0)), [[0.09, 0.03, 0.03, 0.0, col_plate], [0.06, 0.085, 0.085, 0.0, col_plate], [-0.02, 0.105, 0.1, 0.0, col_plate], [-0.06, 0.108, 0.104, 0.0, col_gold], [-0.075, 0.1, 0.097, 0.0, col_gold]], 10, true, false)
			pm.loft(Transform3D(Basis(), Vector3(0.02 * side2, 0, 0)), [[-0.07, 0.085, 0.085, 0.0, col_plate], [-0.12, 0.09, 0.088, 0.0, col_plate], [-0.13, 0.085, 0.083, 0.0, col_gold]], 10, false, false)
		k = _kit(fore)
		k.loft(I, [[0.0, 0.042, 0.044, 0.0, shirt], [-0.06, 0.047, 0.044, -0.004, col_leather], [-0.2, 0.036, 0.031, 0.0, col_leather], [-0.225, 0.034, 0.03, 0.0, sk]], 8, true, false)
		# Bracer trim and hand (palm block, fingers, thumb).
		k.loft(I, [[-0.19, 0.04, 0.035, 0.0, col_gold], [-0.205, 0.04, 0.035, 0.0, col_gold]], 8, false, false)
		k.loft(I, [[-0.225, 0.036, 0.022, 0.0, sk], [-0.27, 0.04, 0.02, 0.0, sk], [-0.31, 0.034, 0.017, -0.004, skin_dark], [-0.325, 0.02, 0.012, -0.006, skin_dark]], 6, false, true)
		k.box(Transform3D(Basis(Vector3.BACK, side2 * 0.4), Vector3(-0.03 * side2, -0.255, -0.012)), Vector3(0.016, 0.05, 0.018), sk)

	# --- Legs: thigh, knee / calf, ankle, foot ---
	for side3: float in [-1.0, 1.0]:
		var leg: Node3D = leg_l if side3 < 0.0 else leg_r
		var shin: Node3D = shin_l if side3 < 0.0 else shin_r
		k = _kit(leg)
		k.loft(I, [[0.04, 0.085, 0.09, 0.0, trousers], [-0.08, 0.083, 0.085, -0.005, trousers], [-0.25, 0.066, 0.068, -0.004, trousers], [-0.42, 0.05, 0.052, 0.0, trousers], [-0.45, 0.048, 0.05, 0.0, trousers]], 8)
		k = _kit(shin)
		var boot_top: float = -0.16 if armored else -0.26
		k.loft(I, [[0.02, 0.05, 0.052, 0.0, trousers], [-0.1, 0.054, 0.058, 0.012, trousers], [boot_top, 0.052, 0.054, 0.008, col_boot], [-0.33, 0.04, 0.042, 0.0, col_boot], [-0.43, 0.04, 0.045, -0.005, col_boot]], 8, false, true)
		k.loft(I, [[boot_top + 0.02, 0.06, 0.062, 0.008, col_boot.lightened(0.08)], [boot_top - 0.02, 0.058, 0.06, 0.008, col_boot.lightened(0.08)]], 8, false, false)
		# Foot: heel block and tapered toe.
		k.box(Transform3D(Basis(), Vector3(0, -0.425, -0.02)), Vector3(0.085, 0.07, 0.12), col_boot)
		k.wedge(Transform3D(Basis(), Vector3(0, -0.435, -0.12)), Vector3(0.085, 0.05, 0.11), col_boot)
		if armored:
			var km: MeshKit = _kit(shin, true)
			km.loft(Transform3D(Basis(), Vector3(0, 0, -0.02)), [[0.06, 0.03, 0.02, -0.03, col_plate], [0.02, 0.06, 0.05, -0.035, col_plate], [-0.04, 0.055, 0.045, -0.03, col_gold], [-0.05, 0.05, 0.04, -0.028, col_gold]], 8, true, false)

	# --- Cape: two layered panels and a fringed hem ---
	k = _kit(cape)
	if armored:
		var cape_len: float = 0.92
		k.box(Transform3D(Basis(), Vector3(0, -cape_len * 0.5, 0)), Vector3(0.44, cape_len, 0.02), col_cloak)
		k.box(Transform3D(Basis(), Vector3(0, -0.2, 0.012)), Vector3(0.48, 0.38, 0.02), col_cloak.darkened(0.12))
		k.box(Transform3D(Basis(), Vector3(0, -cape_len + 0.03, 0.0)), Vector3(0.45, 0.04, 0.025), col_gold)
		for f: int in 9:
			var fx: float = -0.2 + f * 0.05
			k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(fx, -cape_len - 0.03, 0)), Vector3(0.035, 0.012, 0.07), col_gold.darkened(0.15))
		k.box(Transform3D(Basis(), Vector3(0, 0.0, -0.01)), Vector3(0.48, 0.05, 0.04), col_gold)

	# --- Sword: fullered blade, swept crossguard, wrapped grip, gem pommel ---
	if with_sword:
		var sm: MeshKit = _kit(sword, true)
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.6)), Vector3(0.07, 0.016, 0.86), col_steel)
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.56)), Vector3(0.018, 0.02, 0.7), col_steel.darkened(0.3))  # Fuller.
		sm.wedge(Transform3D(Basis(), Vector3(0, 0, -1.08)), Vector3(0.07, 0.016, 0.1), col_steel)
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.14)), Vector3(0.24, 0.04, 0.045), col_gold)
		for side4: float in [-1.0, 1.0]:
			sm.wedge(Transform3D(Basis(Vector3.UP, -side4 * PI * 0.5), Vector3(0.14 * side4, 0, -0.16)), Vector3(0.045, 0.04, 0.07), col_gold)
		sm.loft(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), [[-0.12, 0.022, 0.022, 0.0, col_leather], [0.1, 0.02, 0.02, 0.0, col_leather]], 6)
		sm.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, 0.12)), Vector3(0.05, 0.05, 0.05), col_gold)
		var gem := MeshKit.new()
		gem.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, 0.12)), Vector3(0.056, 0.03, 0.056), Color("6ec3f0"))
		var gm := MeshInstance3D.new()
		gm.mesh = gem.commit()
		var gmat := StandardMaterial3D.new()
		gmat.vertex_color_use_as_albedo = true
		gmat.emission_enabled = true
		gmat.emission = Color("6ec3f0")
		gmat.emission_energy_multiplier = 1.5
		gm.material_override = gmat
		sword.add_child(gm)

	_commit_kits()


func _kit(pivot: Node3D, metal: bool = false) -> MeshKit:
	var key: String = str(pivot.get_instance_id()) + ("m" if metal else "c")
	if not _kits.has(key):
		_kits[key] = [MeshKit.new(), pivot, metal]
	return _kits[key][0]


func _commit_kits() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = 0.78
	cloth.rim_enabled = true
	cloth.rim = 0.3
	cloth.rim_tint = 0.6
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.roughness = 0.38
	metal.metallic = 0.55
	metal.rim_enabled = true
	metal.rim = 0.4
	metal.rim_tint = 0.4
	for key: String in _kits.keys():
		var entry: Array = _kits[key]
		var kit: MeshKit = entry[0]
		if kit.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		mi.material_override = metal if entry[2] else cloth
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(entry[1] as Node3D).add_child(mi)
	_kits.clear()


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
