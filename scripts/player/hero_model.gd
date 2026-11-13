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

const CAPE_LEN: float = 0.94
## Fraction of the cape length where the lower flap hinges.
const CAPE_SPLIT: float = 0.5

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
## Villager outfit: "" (plain), "apron", "hood" or "hat" (fisherman's sou'wester with beard).
var outfit_kind: String = ""
## Hair shape: 0 = swept with tied tail, 1 = short crop, 2 = bun with side locks.
var hair_style: int = 0
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
## Lower half of the cape: trails behind the upper half for a softer cloth read.
var cape_low: Node3D
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
	cape_low = _pivot(cape, Vector3(0, -CAPE_LEN * CAPE_SPLIT, _cape_z(CAPE_SPLIT)), "CapeLow")
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
	# Buckle: gold frame around a dark centre, with a belt tongue hanging off to one side.
	k.box(Transform3D(Basis(), Vector3(0, 0.065, -0.125)), Vector3(0.075, 0.066, 0.02), col_gold)
	k.box(Transform3D(Basis(), Vector3(0, 0.065, -0.134)), Vector3(0.04, 0.034, 0.012), col_boot.darkened(0.2))
	k.box(Transform3D(Basis(Vector3.BACK, 0.12), Vector3(-0.05, 0.0, -0.132)), Vector3(0.028, 0.11, 0.012), col_boot)
	k.box(Transform3D(Basis(Vector3.BACK, 0.12), Vector3(-0.056, -0.058, -0.133)), Vector3(0.03, 0.014, 0.014), col_gold)
	# Pouches: one on each hip, with a lighter flap and a gold stud.
	var pouch_col: Color = col_leather.darkened(0.15)
	for ps: float in [-1.0, 1.0]:
		var pw: float = 0.085 if ps > 0.0 else 0.065
		var pxf := Transform3D(Basis(Vector3.UP, -ps * 0.75), Vector3(0.135 * ps, 0.02, -0.078))
		k.box(pxf, Vector3(pw, 0.1, 0.05), pouch_col)
		k.box(pxf * Transform3D(Basis(), Vector3(0, 0.03, -0.006)), Vector3(pw + 0.01, 0.045, 0.05), col_leather.lightened(0.08))
		k.box(pxf * Transform3D(Basis(), Vector3(0, 0.012, -0.034)), Vector3(0.016, 0.016, 0.01), col_gold)
	# Tabard skirt: flares out, gold hem.
	var skirt_len: float = 0.36 if armored else 0.2
	k.loft(I, [[0.06, 0.17, 0.125, 0.0, shirt], [0.06 - skirt_len, 0.22, 0.16, 0.0, col_gold], [0.06 - skirt_len - 0.025, 0.222, 0.162, 0.0, col_gold]], 10, false, false)

	if outfit_kind == "apron":
		# Work apron: a pale panel hanging from the belt over the front of the skirt.
		var apron := Color("d8d2c2")
		k.quad(I, Vector3(-0.105, 0.09, -0.136), Vector3(0.105, 0.09, -0.136), Vector3(0.135, -0.19, -0.178), Vector3(-0.135, -0.19, -0.178), apron, true)
		k.box(Transform3D(Basis(Vector3.RIGHT, 0.14), Vector3(0.05, -0.08, -0.166)), Vector3(0.09, 0.07, 0.012), apron.darkened(0.12))  # Pocket.

	# --- Torso: waist, ribs, chest, shoulders, neck ---
	k = _kit(torso)
	k.loft(I, [
		[0.0, 0.145, 0.1, 0.0, shirt], [0.12, 0.15, 0.105, -0.005, shirt], [0.25, 0.17, 0.115, -0.01, shirt],
		[0.38, 0.19, 0.122, -0.015, shirt], [0.47, 0.2, 0.115, -0.01, shirt], [0.55, 0.16, 0.1, 0.0, shirt],
		[0.585, 0.085, 0.072, 0.003, sk], [0.6, 0.065, 0.06, 0.005, sk],
	], 10)
	if armored:
		var m: MeshKit = _kit(torso, true)
		# Cuirass: sculpted breastplate and backplate shell with a gold rim.
		m.loft(I, [[0.17, 0.165, 0.118, -0.01, col_gold], [0.2, 0.17, 0.122, -0.012, col_plate], [0.3, 0.183, 0.13, -0.022, col_plate], [0.4, 0.2, 0.136, -0.03, col_plate], [0.48, 0.2, 0.125, -0.018, col_gold], [0.5, 0.18, 0.11, -0.01, col_gold]], 10, false, false)
		# Ridge down the breastplate.
		m.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.33, -0.16)), Vector3(0.03, 0.025, 0.24), col_plate.lightened(0.1))
		# Gorget.
		m.loft(I, [[0.5, 0.12, 0.09, 0.0, col_plate], [0.57, 0.085, 0.07, 0.0, col_gold]], 10, false, false)
	if outfit_kind == "apron":
		# Apron bib with shoulder straps.
		var bib := Color("d8d2c2")
		k.quad(I, Vector3(-0.1, 0.04, -0.118), Vector3(0.1, 0.04, -0.118), Vector3(0.085, 0.37, -0.148), Vector3(-0.085, 0.37, -0.148), bib, true)
		for bs: float in [-1.0, 1.0]:
			k.box(Transform3D(Basis(Vector3.RIGHT, -0.22) * Basis(Vector3.BACK, bs * 0.2), Vector3(0.1 * bs, 0.45, -0.132)), Vector3(0.026, 0.2, 0.014), bib.darkened(0.1))
	elif outfit_kind == "hood":
		# Short mantle under the hood, with a wooden toggle.
		k.loft(I, [[0.4, 0.225, 0.14, 0.0, col_cloak.darkened(0.1)], [0.47, 0.215, 0.135, 0.0, col_cloak], [0.56, 0.15, 0.11, 0.01, col_cloak], [0.61, 0.085, 0.085, 0.015, col_cloak]], 10, false, false)
		k.box(Transform3D(Basis(), Vector3(0, 0.5, -0.135)), Vector3(0.03, 0.05, 0.02), col_leather.darkened(0.2))
	elif outfit_kind == "hat":
		# Oilskin collar turned up against the wind.
		k.loft(I, [[0.5, 0.15, 0.11, 0.0, col_cloak.darkened(0.1)], [0.6, 0.1, 0.095, 0.01, col_cloak.darkened(0.1)]], 10, false, false)
	# Royal sash (diagonal) and collar.
	if outfit_kind != "apron" and outfit_kind != "hood":
		k.box(Transform3D(Basis(Vector3.BACK, 0.75), Vector3(0.0, 0.32, -0.142)), Vector3(0.07, 0.5, 0.02), col_cloak if not armored else col_tunic.lightened(0.08))

	# --- Head: neck, jaw, cheekbones, brow, crown ---
	k = _kit(head)
	k.loft(I, [
		[0.0, 0.055, 0.05, 0.005, sk], [0.06, 0.05, 0.05, 0.0, sk], [0.085, 0.066, 0.07, -0.025, sk],
		[0.13, 0.082, 0.09, -0.018, sk], [0.18, 0.088, 0.098, -0.008, sk], [0.225, 0.09, 0.102, 0.0, sk],
		[0.28, 0.08, 0.094, 0.008, sk], [0.32, 0.05, 0.065, 0.012, sk], [0.34, 0.015, 0.02, 0.012, sk],
	], 10, false, true)
	_build_face(k, sk, skin_dark)
	_build_headwear(k)

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
			pm.loft(Transform3D(Basis(), Vector3(0.02 * side2, 0, 0)), [[-0.07, 0.085, 0.085, 0.0, col_plate.darkened(0.08)], [-0.12, 0.09, 0.088, 0.0, col_gold], [-0.135, 0.085, 0.083, 0.0, col_gold]], 10, false, false)
			# Third lame, raised crest along the top and a gold rivet on the outer face.
			pm.loft(Transform3D(Basis(), Vector3(0.022 * side2, 0, 0)), [[-0.13, 0.074, 0.074, 0.0, col_plate.darkened(0.14)], [-0.17, 0.078, 0.077, 0.0, col_gold], [-0.182, 0.073, 0.072, 0.0, col_gold]], 10, false, false)
			pm.box(Transform3D(Basis(Vector3.BACK, -side2 * 0.5), Vector3(0.06 * side2, 0.07, 0)), Vector3(0.11, 0.022, 0.03), col_gold)
			pm.box(Transform3D(Basis(), Vector3(0.118 * side2, -0.02, 0)), Vector3(0.016, 0.03, 0.03), col_gold)
		k = _kit(fore)
		k.loft(I, [[0.0, 0.042, 0.044, 0.0, shirt], [-0.06, 0.047, 0.044, -0.004, col_leather], [-0.2, 0.036, 0.031, 0.0, col_leather], [-0.225, 0.034, 0.03, 0.0, sk]], 8, true, false)
		# Bracer trim and hand (palm block, fingers, thumb).
		k.loft(I, [[-0.19, 0.04, 0.035, 0.0, col_gold], [-0.205, 0.04, 0.035, 0.0, col_gold]], 8, false, false)
		_build_hand(k, side2, sk, skin_dark, with_sword and side2 > 0.0)

	# --- Legs: thigh, knee / calf, ankle, foot ---
	for side3: float in [-1.0, 1.0]:
		var leg: Node3D = leg_l if side3 < 0.0 else leg_r
		var shin: Node3D = shin_l if side3 < 0.0 else shin_r
		k = _kit(leg)
		k.loft(I, [[0.04, 0.085, 0.09, 0.0, trousers], [-0.08, 0.083, 0.085, -0.005, trousers], [-0.25, 0.066, 0.068, -0.004, trousers], [-0.42, 0.05, 0.052, 0.0, trousers], [-0.45, 0.048, 0.05, 0.0, trousers]], 8)
		k = _kit(shin)
		var boot_top: float = -0.16 if armored else -0.26
		k.loft(I, [[0.02, 0.05, 0.052, 0.0, trousers], [-0.1, 0.054, 0.058, 0.012, trousers], [boot_top, 0.052, 0.054, 0.008, col_boot], [-0.33, 0.04, 0.042, 0.0, col_boot], [-0.43, 0.04, 0.045, -0.005, col_boot]], 8, false, true)
		# Folded cuff: flares out at the top, with a darker lip underneath.
		var cuff: Color = col_boot.lightened(0.12)
		k.loft(I, [[boot_top + 0.035, 0.066, 0.068, 0.008, cuff], [boot_top - 0.025, 0.06, 0.062, 0.008, col_boot.darkened(0.25)], [boot_top - 0.035, 0.054, 0.056, 0.008, col_boot.darkened(0.25)]], 8, false, false)
		k.loft(I, [[boot_top + 0.035, 0.066, 0.068, 0.008, cuff], [boot_top + 0.03, 0.05, 0.052, 0.008, cuff]], 8, false, false)
		# Ankle strap with buckle, and a dark sole.
		k.loft(I, [[-0.325, 0.045, 0.047, 0.0, col_leather.lightened(0.05)], [-0.35, 0.044, 0.046, 0.0, col_leather.lightened(0.05)]], 8, false, false)
		k.box(Transform3D(Basis(), Vector3(0.03 * side3, -0.337, -0.04)), Vector3(0.022, 0.03, 0.012), col_gold if armored else col_steel.darkened(0.25))
		k.box(Transform3D(Basis(), Vector3(0, -0.458, -0.035)), Vector3(0.095, 0.022, 0.16), col_boot.darkened(0.4))
		# Foot: heel block and tapered toe.
		k.box(Transform3D(Basis(), Vector3(0, -0.425, -0.02)), Vector3(0.085, 0.07, 0.12), col_boot)
		k.wedge(Transform3D(Basis(), Vector3(0, -0.435, -0.12)), Vector3(0.085, 0.05, 0.11), col_boot)
		if armored:
			var km: MeshKit = _kit(shin, true)
			km.loft(Transform3D(Basis(), Vector3(0, 0, -0.02)), [[0.06, 0.03, 0.02, -0.03, col_plate], [0.02, 0.06, 0.05, -0.035, col_plate], [-0.04, 0.055, 0.045, -0.03, col_gold], [-0.05, 0.05, 0.04, -0.028, col_gold]], 8, true, false)

	# --- Cape: curved, pleated panels in two hinged halves, gold edge trim and hem ---
	if armored:
		_build_cape()

	# --- Sword: fullered blade, swept crossguard, wrapped grip, gem pommel ---
	if with_sword:
		var sm: MeshKit = _kit(sword, true)
		# Blade: flat core, bevelled bright edges, dark fuller on both faces, ricasso and tip.
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.61)), Vector3(0.05, 0.02, 0.84), col_steel.darkened(0.08))
		for es: float in [-1.0, 1.0]:
			sm.box(Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0.027 * es, 0, -0.61)), Vector3(0.02, 0.02, 0.84), col_steel.lightened(0.25))
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.52)), Vector3(0.016, 0.026, 0.6), col_steel.darkened(0.38))  # Fuller.
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.215)), Vector3(0.085, 0.028, 0.07), col_steel.darkened(0.2))  # Ricasso.
		sm.wedge(Transform3D(Basis(), Vector3(0, 0, -1.08)), Vector3(0.078, 0.02, 0.12), col_steel.lightened(0.1))
		# Crossguard: swept arms with flared tips, raised centre lozenge with a blue inlay.
		sm.box(Transform3D(Basis(), Vector3(0, 0, -0.15)), Vector3(0.2, 0.036, 0.04), col_gold)
		for side4: float in [-1.0, 1.0]:
			sm.box(Transform3D(Basis(Vector3.UP, -side4 * 0.45), Vector3(0.135 * side4, 0, -0.168)), Vector3(0.09, 0.03, 0.034), col_gold.darkened(0.08))
			sm.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0.18 * side4, 0, -0.19)), Vector3(0.04, 0.042, 0.04), col_gold.lightened(0.1))
		sm.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, -0.15)), Vector3(0.062, 0.05, 0.062), col_gold.lightened(0.08))
		sm.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, -0.15)), Vector3(0.03, 0.058, 0.03), col_tunic)
		# Grip: leather with gold wire bands, then the pommel.
		sm.loft(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), [[-0.12, 0.022, 0.022, 0.0, col_leather], [0.1, 0.02, 0.02, 0.0, col_leather]], 6)
		for band: int in 3:
			sm.box(Transform3D(Basis(), Vector3(0, 0, -0.07 + band * 0.06)), Vector3(0.048, 0.048, 0.012), col_gold.darkened(0.1))
		sm.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, 0.125)), Vector3(0.056, 0.05, 0.056), col_gold)
		var gem := MeshKit.new()
		gem.box(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, 0.125)), Vector3(0.036, 0.062, 0.036), Color("6ec3f0"))
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


## Face details on top of the skull loft: chin, nose, brow, cheek planes, ears, eyes, mouth.
func _build_face(k: MeshKit, sk: Color, skin_dark: Color) -> void:
	k.box(Transform3D(Basis(), Vector3(0, 0.095, -0.085)), Vector3(0.05, 0.035, 0.03), skin_dark)
	k.wedge(Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0.172, -0.11)), Vector3(0.03, 0.055, 0.04), skin_dark)
	k.box(Transform3D(Basis(), Vector3(0, 0.22, -0.096)), Vector3(0.14, 0.02, 0.026), skin_dark)
	# Mouth: a thin dark line.
	k.box(Transform3D(Basis(), Vector3(0, 0.128, -0.099)), Vector3(0.04, 0.007, 0.012), sk.darkened(0.4))
	for side: float in [-1.0, 1.0]:
		# Ear.
		k.box(Transform3D(Basis(Vector3.UP, side * 0.3), Vector3(0.09 * side, 0.18, 0.005)), Vector3(0.02, 0.055, 0.035), skin_dark)
		# Eye: dark socket facet with a tiny highlight, strong brow above.
		k.box(Transform3D(Basis(), Vector3(0.037 * side, 0.199, -0.097)), Vector3(0.032, 0.017, 0.012), Color("1e2125"))
		k.box(Transform3D(Basis(), Vector3(0.031 * side, 0.203, -0.1)), Vector3(0.008, 0.007, 0.009), Color("e6e1d3"))
		k.box(Transform3D(Basis(Vector3.BACK, -side * 0.18), Vector3(0.038 * side, 0.2155, -0.101)), Vector3(0.042, 0.011, 0.014), col_hair.darkened(0.1))


## Hair, hood or hat, depending on `outfit_kind` and `hair_style`.
func _build_headwear(k: MeshKit) -> void:
	var I := Transform3D.IDENTITY
	var hair: Color = col_hair
	var hair_hi: Color = col_hair.lightened(0.12)
	if outfit_kind == "hood":
		# Soft hood set back from the face, with a pointed crown and a folded front rim.
		var hood: Color = col_cloak
		k.loft(I, [[0.03, 0.115, 0.105, 0.045, hood], [0.17, 0.112, 0.112, 0.04, hood], [0.3, 0.092, 0.105, 0.04, hood], [0.365, 0.03, 0.05, 0.06, hood]], 10, false, true)
		k.loft(I, [[0.12, 0.118, 0.03, -0.045, hood.lightened(0.1)], [0.3, 0.1, 0.03, -0.04, hood.lightened(0.1)], [0.345, 0.05, 0.03, -0.03, hood.lightened(0.1)]], 8, false, true)
		k.wedge(Transform3D(Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.UP, PI), Vector3(0, 0.34, 0.13)), Vector3(0.07, 0.05, 0.14), hood.darkened(0.08))
		k.box(Transform3D(Basis(), Vector3(0, 0.235, -0.088)), Vector3(0.11, 0.03, 0.03), hair)  # Fringe under the rim.
		return
	if outfit_kind == "hat":
		# Fisherman's sou'wester: wide sloping brim (longer at the back) and a domed crown.
		var hat: Color = col_cloak
		k.loft(I, [[0.238, 0.185, 0.205, 0.04, hat.darkened(0.1)], [0.262, 0.15, 0.165, 0.03, hat], [0.275, 0.105, 0.115, 0.012, hat]], 10, true, false)
		k.loft(I, [[0.27, 0.105, 0.115, 0.012, hat], [0.34, 0.095, 0.105, 0.012, hat.lightened(0.06)], [0.375, 0.05, 0.06, 0.012, hat.lightened(0.06)]], 10, false, true)
		k.loft(I, [[0.272, 0.108, 0.118, 0.012, col_leather], [0.29, 0.106, 0.116, 0.012, col_leather]], 10, false, false)  # Hat band.
		# Hair under the brim, plus a full beard and moustache.
		k.loft(I, [[0.15, 0.094, 0.1, 0.028, hair], [0.26, 0.097, 0.106, 0.02, hair]], 10, false, false)
		k.loft(I, [[0.15, 0.07, 0.05, -0.062, hair], [0.1, 0.066, 0.055, -0.066, hair], [0.045, 0.035, 0.035, -0.078, hair_hi]], 8, true, true)
		k.box(Transform3D(Basis(), Vector3(0, 0.142, -0.106)), Vector3(0.06, 0.014, 0.016), hair_hi)
		return
	# Hair cap shared by all styles.
	k.loft(I, [[0.19, 0.098, 0.111, 0.022, hair], [0.25, 0.102, 0.114, 0.012, hair], [0.3, 0.09, 0.105, 0.012, hair_hi], [0.345, 0.052, 0.072, 0.014, hair_hi], [0.365, 0.01, 0.02, 0.014, hair_hi]], 10, false, true)
	match hair_style:
		1:
			# Short crop: blunt fringe and sideburns.
			k.box(Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(0, 0.25, -0.092)), Vector3(0.15, 0.04, 0.03), hair)
			for sb: float in [-1.0, 1.0]:
				k.box(Transform3D(Basis(), Vector3(0.088 * sb, 0.2, -0.03)), Vector3(0.018, 0.08, 0.04), hair)
		2:
			# Bun on the crown with locks framing the face and covering the neck.
			k.loft(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.31, 0.1)), [[-0.04, 0.03, 0.03, 0.0, hair], [-0.015, 0.052, 0.052, 0.0, hair], [0.03, 0.05, 0.05, 0.0, hair_hi], [0.05, 0.02, 0.02, 0.0, hair_hi]], 8, true, true)
			k.box(Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(0, 0.255, -0.09)), Vector3(0.14, 0.035, 0.03), hair)
			k.box(Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.13, 0.095)), Vector3(0.15, 0.17, 0.035), hair)
			for sl: float in [-1.0, 1.0]:
				k.box(Transform3D(Basis(Vector3.BACK, sl * 0.08), Vector3(0.092 * sl, 0.17, -0.035)), Vector3(0.022, 0.17, 0.05), hair)
		_:
			# Swept hair: asymmetric fringe, side locks, back tufts and a tied tail (clear silhouette).
			for f: int in 4:
				var fx: float = -0.055 + f * 0.036
				var fl: float = 0.05 + 0.014 * float((f * 3) % 4)
				k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.25) * Basis(Vector3.BACK, 0.25), Vector3(fx, 0.262 - fl * 0.5, -0.094)), Vector3(0.04, 0.026, fl), hair_hi if f % 2 == 0 else hair)
			for st: float in [-1.0, 1.0]:
				k.box(Transform3D(Basis(Vector3.BACK, st * 0.1), Vector3(0.09 * st, 0.2, -0.04)), Vector3(0.02, 0.1, 0.045), hair)
				k.wedge(Transform3D(Basis(Vector3.UP, PI + st * 0.45) * Basis(Vector3.RIGHT, 0.05), Vector3(0.055 * st, 0.26, 0.105)), Vector3(0.07, 0.05, 0.09), hair)
			k.wedge(Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.325, 0.085)), Vector3(0.08, 0.045, 0.11), hair_hi)
			k.box(Transform3D(Basis(), Vector3(0, 0.2, 0.118)), Vector3(0.05, 0.04, 0.035), col_gold if armored else col_cloak)  # Tie.
			k.box(Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.12, 0.125)), Vector3(0.055, 0.15, 0.04), hair)
			k.wedge(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.3), Vector3(0, 0.02, 0.152)), Vector3(0.05, 0.035, 0.07), hair_hi)
	if armored:
		# Warden's circlet: a thin gold band with a blue stone at the brow.
		var m: MeshKit = _kit(head, true)
		m.loft(I, [[0.238, 0.104, 0.117, 0.012, col_gold], [0.258, 0.103, 0.116, 0.012, col_gold]], 10, false, false)
		m.box(Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 0.25, -0.103)), Vector3(0.03, 0.03, 0.016), col_gold.lightened(0.1))
		m.box(Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 0.25, -0.11)), Vector3(0.016, 0.016, 0.012), Color("6ec3f0"))


## Hand with fingers as blocks. `fist` wraps the fingers around the sword grip (which runs along Z).
func _build_hand(k: MeshKit, side: float, sk: Color, skin_dark: Color, fist: bool) -> void:
	if fist:
		k.box(Transform3D(Basis(), Vector3(0, -0.258, 0.0)), Vector3(0.056, 0.062, 0.07), sk)
		for i: int in 4:
			# Knuckle blocks stacked along the grip, on the outside of the hand.
			var fz: float = -0.027 + i * 0.018
			k.box(Transform3D(Basis(), Vector3(0.032 * side, -0.266, fz)), Vector3(0.018, 0.05, 0.015), skin_dark if i % 2 == 0 else sk)
			k.box(Transform3D(Basis(), Vector3(0.012 * side, -0.294, fz)), Vector3(0.04, 0.014, 0.015), sk)
		k.box(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(-0.012 * side, -0.25, -0.042)), Vector3(0.02, 0.022, 0.045), skin_dark)  # Thumb.
		return
	# Open, relaxed hand: palm block, four fingers in two curled segments, and a thumb.
	k.box(Transform3D(Basis(), Vector3(0, -0.257, 0.0)), Vector3(0.072, 0.066, 0.028), sk)
	for j: int in 4:
		var fx: float = -0.027 + j * 0.018
		var fl: float = 0.042 - absf(float(j) - 1.5) * 0.005
		var base := Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(fx, -0.29, 0.0))
		k.box(base * Transform3D(Basis(), Vector3(0, -fl * 0.5, 0)), Vector3(0.0155, fl, 0.02), sk if j % 2 == 0 else skin_dark)
		var tip := base * Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, -fl, 0))
		k.box(tip * Transform3D(Basis(), Vector3(0, -0.015, 0)), Vector3(0.0145, 0.03, 0.018), skin_dark if j % 2 == 0 else sk)
	k.box(Transform3D(Basis(Vector3.BACK, side * 0.5) * Basis(Vector3.RIGHT, 0.35), Vector3(-0.042 * side, -0.262, -0.012)), Vector3(0.018, 0.05, 0.02), skin_dark)


## Backward offset of the cape at length fraction `v` (0 = collar, 1 = hem): it flares away from the legs.
func _cape_z(v: float) -> float:
	return 0.02 + 0.13 * v * v


func _cape_point(u: float, v: float) -> Vector3:
	# u: -0.5..0.5 across the back. The cape wraps the shoulders at the top and fans out below.
	var half_w: float = lerpf(0.235, 0.33, v)
	var wrap: float = 4.0 * u * u
	var pleat: float = 0.016 * v * cos(u * TAU * 3.0)
	return Vector3(u * 2.0 * half_w, -CAPE_LEN * v, _cape_z(v) - wrap * lerpf(0.075, 0.02, v) + pleat)


func _build_cape() -> void:
	var us: Array[float] = [-0.5, -0.455, -0.3, -0.15, 0.0, 0.15, 0.3, 0.455, 0.5]
	var vs: Array[float] = [0.0, 0.25, 0.5, 0.74, 0.95, 1.0]
	var split_row: int = 2
	var low_origin := Vector3(0, -CAPE_LEN * CAPE_SPLIT, _cape_z(CAPE_SPLIT))
	var lining: Color = col_tunic.darkened(0.25)
	var I := Transform3D.IDENTITY
	for r: int in vs.size() - 1:
		var lower: bool = r >= split_row
		var k: MeshKit = _kit(cape_low if lower else cape)
		var off: Vector3 = low_origin if lower else Vector3.ZERO
		for c: int in us.size() - 1:
			var trim: bool = c == 0 or c == us.size() - 2 or r == vs.size() - 2
			var col: Color = col_gold if trim else (col_cloak if c % 2 == 1 else col_cloak.darkened(0.16))
			if not trim:
				col = col.darkened(0.05 * r)
			# Corners counter-clockwise seen from behind the hero (+Z).
			var a: Vector3 = _cape_point(us[c], vs[r + 1]) - off
			var b: Vector3 = _cape_point(us[c + 1], vs[r + 1]) - off
			var d: Vector3 = _cape_point(us[c], vs[r]) - off
			var e: Vector3 = _cape_point(us[c + 1], vs[r]) - off
			k.quad(I, a, b, e, d, col, true, col_gold.darkened(0.2) if trim else lining)
	# Short mantle layer over the shoulders, collar bar and two round clasps.
	var k2: MeshKit = _kit(cape)
	var widen := Vector3(1.06, 1, 1)
	var back := Vector3(0, 0, 0.014)
	for c2: int in us.size() - 1:
		var a2: Vector3 = _cape_point(us[c2], 0.3) * widen + back
		var b2: Vector3 = _cape_point(us[c2 + 1], 0.3) * widen + back
		var d2: Vector3 = _cape_point(us[c2], 0.0) * widen + back
		var e2: Vector3 = _cape_point(us[c2 + 1], 0.0) * widen + back
		var drop := Vector3.ZERO
		k2.quad(I, a2 + drop, b2 + drop, e2, d2, col_cloak.darkened(0.2), true)
		var lip := Vector3(0, 0, 0.003)
		k2.quad(I, a2 + drop + Vector3(0, -0.022, 0) + lip, b2 + drop + Vector3(0, -0.022, 0) + lip, b2 + drop + lip, a2 + drop + lip, col_gold, true)
	k2.box(Transform3D(Basis(), Vector3(0, 0.0, 0.0)), Vector3(0.4, 0.045, 0.045), col_gold)
	var m: MeshKit = _kit(torso, true)
	for side: float in [-1.0, 1.0]:
		m.cylinder(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.15 * side, 0.475, -0.128)), 0.03, 0.036, 0.02, 6, col_gold)


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
	# Idle: slow weight shift from foot to foot (hips slide and tilt, feet stay planted).
	var idle: float = (1.0 - amp) * (1.0 - _air_blend)
	var sway: float = sin(_time * 0.75) * idle
	var breath: float = sin(_time * 2.0) * idle
	hips.position.y = 0.95 - 0.03 * amp + bob * (1.0 - _air_blend) - absf(sway) * 0.006
	hips.position.x = sway * 0.016
	hips.rotation = Vector3(-_lean * 0.35 - 0.12 * amp - 0.5 * _dash_blend, s * 0.14 * amp, sway * 0.035 - c * 0.04 * amp)
	leg_l.rotation.z = -hips.rotation.z + sway * 0.012
	leg_r.rotation.z = -hips.rotation.z + sway * 0.012

	# Locomotion upper body.
	# Walk and run: shoulders twist against the hips, arms counter-swing the legs and the
	# elbow closes on the forward swing. Idle: chest rises with the breath, shoulders settle.
	var breathe: float = breath * 0.022
	var loco := {
		"torso": Vector3(-0.08 * amp + breathe, -s * 0.26 * amp, -sway * 0.045 + c * 0.03 * amp),
		"r_arm": Vector3(s * run_amp * 1.15 - 0.15 * amp + breath * 0.02, 0, 0.12 + 0.15 * _air_blend + breath * 0.015 + sway * 0.03),
		"r_fore": Vector3(0.35 + 0.55 * amp + 0.35 * amp * s, 0, 0),
		"l_arm": Vector3(-s * run_amp * 1.15 - breath * 0.02, 0, -0.12 - 0.5 * _air_blend - breath * 0.015 + sway * 0.03),
		"l_fore": Vector3(0.25 + 0.6 * amp - 0.35 * amp * s, 0, 0),
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

	torso.scale = Vector3(1.0, 1.0 + breath * 0.008, 1.0 + breath * 0.02)
	# The head stays level and looks ahead while the shoulders twist; idle: slow look around.
	head.rotation = Vector3(0.1 * amp + _lean * 0.15 - breathe * 0.6, s * 0.2 * amp + sin(_time * 0.43) * 0.14 * idle, sway * 0.03)
	# Cape trails behind (negative pitch swings it away from the back); the lower half lags.
	var flap: float = sin(_time * 7.0) * 0.06 * amp
	var cape_lift: float = 0.03 + 0.55 * amp + 0.5 * _air_blend * (1.0 if vertical < 0.0 else 0.2) + 0.6 * _dash_blend
	cape.rotation = Vector3(-cape_lift - flap - breath * 0.01, 0, sin(_time * 3.1) * 0.04 * amp + sway * 0.03)
	cape_low.rotation = Vector3(-0.22 * amp - sin(_time * 7.0 - 1.1) * 0.12 * amp - sin(_time * 1.3) * 0.025 * idle + 0.25 * _dash_blend, 0, 0)


func _blend(loco: Dictionary, key: String, w: float) -> Vector3:
	var a: Vector3 = loco[key]
	if w <= 0.0 or not action_pose.has(key):
		return a
	var b: Vector3 = action_pose[key]
	return a.lerp(b, w)


## Kick the squash spring. Positive = squash down (landing), negative = stretch (take-off).
func impulse_squash(amount: float) -> void:
	_squash_vel += amount * 9.0
