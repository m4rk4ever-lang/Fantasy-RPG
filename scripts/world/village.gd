class_name Village
extends Node3D
## Saltholm (in-game "Saltwick"): a fishing village of the Saltbound on the bay shore.
## Timber-framed houses on stone feet, a pier with moored boats, chimney smoke, gulls and villagers.
## All static geometry is merged into one vertex-colored mesh (one draw call).

const COL_PLASTER := Color(0.902, 0.882, 0.827, 0.2)  # alpha = material id (architecture shader)
const COL_STONE := Color(0.725, 0.702, 0.639, 0.4)
const COL_STONE_DARK := Color(0.557, 0.541, 0.494, 0.4)
const COL_TIMBER := Color(0.353, 0.239, 0.169, 0.6)
const COL_PLANK := Color(0.541, 0.392, 0.275, 0.6)
const COL_PLANK_DARK := Color(0.42, 0.29, 0.2, 0.6)
const COL_GLASS := Color("2a3448")
const COL_BRASS := Color("d9a441")
const COL_SHUTTER := Color("3d5ba9")
const COL_LEAF := Color("3c9a58")
const COL_BLOOMS: Array[Color] = [Color("d9552e"), Color("e6e1d3"), Color("d9a441")]
const COL_ROOF_A := Color(0.36, 0.40, 0.52, 0.8)  # slate tiles, blue-grey
const COL_ROOF_B := Color(0.55, 0.33, 0.25, 0.8)  # fired clay tiles
const COL_ROPE := Color("c9b48a")
const COL_SAIL := Color("e6e1d3")

var arena: TestArena
var brenna: Villager
var _kit := MeshKit.new()
var _glow_kit := MeshKit.new()
var _boats: Array[Node3D] = []
var _boat_phase: Array[float] = []
var _gulls: Array[Node3D] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _sea() -> Vector3:
	return Vector3(TestArena.SEA_DIR.x, 0, TestArena.SEA_DIR.y)


func _along() -> Vector3:
	return Vector3(-TestArena.SEA_DIR.y, 0, TestArena.SEA_DIR.x)


## World point at `s` meters toward the sea and `t` meters along the shore.
func _spot(s: float, t: float) -> Vector3:
	var p: Vector3 = _sea() * s + _along() * t
	p.y = arena.height_at(p.x, p.z)
	return p


func _facing_sea() -> Basis:
	var d: Vector3 = _sea()
	return Basis(Vector3.UP, atan2(d.x, d.z))


func build(p_arena: TestArena) -> void:
	arena = p_arena
	_rng.seed = 4711
	# Organic layout (owner 14-11-2026: no copies in a straight line). Houses stand along a winding lane
	# from the gate to the pier head and turn their fronts to it; sizes, storeys and roofs differ.
	var houses: Array[Vector4] = [  # s, t, width, storeys
		Vector4(14.5, -6.0, 5.8, 1), Vector4(15.8, 10.5, 5.2, 1), Vector4(20.5, -15.0, 6.6, 2),
		Vector4(27.5, -14.5, 6.0, 1), Vector4(29.5, 8.5, 6.8, 2), Vector4(19.5, 16.0, 5.4, 1),
		Vector4(24.5, 26.0, 6.0, 2),
	]
	for i: int in houses.size():
		var h: Vector4 = houses[i]
		var at: Vector3 = _spot(h.x, h.y)
		var lane: Vector3 = _lane_point_near(at)
		var face: Vector3 = Vector3(lane.x - at.x, 0, lane.z - at.z).normalized()
		var roof: Color = (COL_ROOF_A if _rng.randf() < 0.5 else COL_ROOF_B).lerp(Color(0.45, 0.38, 0.33, 0.8), _rng.randf() * 0.25)
		roof.a = 0.8
		_house(at, h.z, 4.4 + _rng.randf() * 1.2, int(h.w), roof, i, face)
	_pier(-4.0)
	_pier_short(19.0)
	_props()
	_village_life()

	var mi := MeshInstance3D.new()
	mi.name = "VillageMesh"
	mi.mesh = _kit.commit()
	mi.material_override = MeshKit.architecture_material()
	add_child(mi)
	var glow := MeshInstance3D.new()
	glow.name = "VillageGlow"
	glow.mesh = _glow_kit.commit()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.emission_enabled = true
	gm.emission = Color("ffb35c")
	gm.emission_energy_multiplier = 1.4
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

	_boats_build()
	_gulls_build()
	_villagers()
	brenna = spawn_brenna()


func _collider(xf: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.transform = xf
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


## One timber-framed house. Local +Z is the front (facing the sea).
## The village lane in (s, t): gate, square, pier head, with a branch along the shore.
const LANE: Array[Vector2] = [Vector2(10.0, 1.0), Vector2(16.0, 3.0), Vector2(21.0, 0.5), Vector2(24.5, -5.5), Vector2(30.0, -4.0)]
const LANE_B: Array[Vector2] = [Vector2(21.0, 0.5), Vector2(23.0, 9.0), Vector2(25.5, 18.0), Vector2(30.5, 24.0)]


func _lane_point_near(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d: float = INF
	for path: Array[Vector2] in [LANE, LANE_B]:
		for i: int in path.size() - 1:
			var a: Vector3 = _spot(path[i].x, path[i].y)
			var b: Vector3 = _spot(path[i + 1].x, path[i + 1].y)
			var ab: Vector3 = b - a
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var q: Vector3 = a + ab * t
			var d: float = Vector2(q.x - p.x, q.z - p.z).length()
			if d < best_d:
				best_d = d
				best = q
	return best


func _house(at: Vector3, width: float, depth: float, storeys: int, roof_col: Color, index: int, face: Vector3 = Vector3.ZERO) -> void:
	var basis: Basis = _facing_sea().rotated(Vector3.UP, _rng.randf_range(-0.12, 0.12))
	if face != Vector3.ZERO:
		basis = Basis(Vector3.UP, atan2(face.x, face.z) + _rng.randf_range(-0.1, 0.1))
	# Find the lowest and highest ground under the footprint.
	var lo: float = INF
	var hi: float = -INF
	for cx: float in [-0.5, 0.5]:
		for cz: float in [-0.5, 0.5]:
			var q: Vector3 = at + basis * Vector3(cx * width, 0, cz * depth)
			var gy: float = arena.height_at(q.x, q.z)
			lo = minf(lo, gy)
			hi = maxf(hi, gy)
	var floor_y: float = hi + 0.45
	arena.add_ground_spot(at, maxf(width, depth) * 0.9, 0.85)
	var origin := Vector3(at.x, floor_y, at.z)
	var xf := Transform3D(basis, origin)
	var wall_h: float = 2.7 * storeys
	var found_h: float = floor_y - lo + 0.3

	# Stone foundation.
	_kit.box(xf * Transform3D(Basis(), Vector3(0, -found_h * 0.5, 0)), Vector3(width + 0.35, found_h, depth + 0.35), COL_STONE)
	# Plaster walls.
	_kit.box(xf * Transform3D(Basis(), Vector3(0, wall_h * 0.5, 0)), Vector3(width, wall_h, depth), COL_PLASTER)
	_collider(xf * Transform3D(Basis(), Vector3(0, (wall_h - found_h) * 0.5, 0)), Vector3(width + 0.35, wall_h + found_h, depth + 0.35))
	# Timber frame: posts on front and back, beams at each storey.
	var t: float = 0.16
	var hw: float = width * 0.5
	var hd: float = depth * 0.5
	var posts: int = int(width / 1.6) + 1
	for side: float in [-1.0, 1.0]:
		for k: int in posts + 1:
			var px: float = lerpf(-hw, hw, float(k) / posts)
			_kit.box(xf * Transform3D(Basis(), Vector3(px, wall_h * 0.5, side * (hd + 0.03))), Vector3(t, wall_h, 0.08), COL_TIMBER)
		for f: int in storeys + 1:
			var by: float = minf(f * 2.7, wall_h - 0.08)
			_kit.box(xf * Transform3D(Basis(), Vector3(0, by, side * (hd + 0.04))), Vector3(width + 0.1, t, 0.1), COL_TIMBER)
		# Side walls: corner posts are shared; add a mid post and beams.
		_kit.box(xf * Transform3D(Basis(), Vector3(side * (hw + 0.03), wall_h * 0.5, 0)), Vector3(0.08, wall_h, t), COL_TIMBER)
		for f2: int in storeys + 1:
			var by2: float = minf(f2 * 2.7, wall_h - 0.08)
			_kit.box(xf * Transform3D(Basis(), Vector3(side * (hw + 0.04), by2, 0)), Vector3(0.1, t, depth + 0.1), COL_TIMBER)
	# Diagonal braces on the upper storey give the classic timber look.
	if storeys > 1:
		for k2: int in [0, posts - 1]:
			var x0: float = lerpf(-hw, hw, float(k2) / posts)
			var x1: float = lerpf(-hw, hw, float(k2 + 1) / posts)
			var mid := Vector3((x0 + x1) * 0.5, 4.05, hd + 0.05)
			var ang: float = atan2(2.7, x1 - x0)
			var len: float = Vector2(x1 - x0, 2.7).length()
			_kit.box(xf * Transform3D(Basis(Vector3.BACK, ang if k2 == 0 else -ang), mid), Vector3(len, t, 0.08), COL_TIMBER)
	# Door with frame.
	_kit.box(xf * Transform3D(Basis(), Vector3(0, 1.0, hd + 0.06)), Vector3(1.1, 2.0, 0.08), COL_PLANK_DARK)
	_kit.box(xf * Transform3D(Basis(), Vector3(0, 2.07, hd + 0.08)), Vector3(1.5, t, 0.14), COL_TIMBER)
	for ds: float in [-1.0, 1.0]:
		_kit.box(xf * Transform3D(Basis(), Vector3(ds * 0.63, 1.0, hd + 0.08)), Vector3(0.14, 2.0, 0.14), COL_TIMBER)
		# Plank seams and iron strap hinges.
		_kit.box(xf * Transform3D(Basis(), Vector3(ds * 0.18, 1.0, hd + 0.1)), Vector3(0.03, 1.96, 0.02), COL_PLANK_DARK.darkened(0.35))
	for hy: float in [0.5, 1.55]:
		_kit.box(xf * Transform3D(Basis(), Vector3(-0.2, hy, hd + 0.11)), Vector3(0.7, 0.07, 0.02), COL_GLASS)
	_kit.box(xf * Transform3D(Basis(), Vector3(0.4, 1.02, hd + 0.13)), Vector3(0.07, 0.07, 0.06), COL_BRASS)  # Handle.
	# Front step.
	_kit.box(xf * Transform3D(Basis(), Vector3(0, -0.2, hd + 0.6)), Vector3(1.6, 0.4, 0.8), COL_STONE)
	# Windows: front and sides, each storey. Lit windows glow at dusk.
	for f3: int in storeys:
		var wy: float = 1.5 + f3 * 2.7
		for wx: float in [-hw * 0.55, hw * 0.55]:
			if f3 == 0 and absf(wx) < 1.0:
				continue
			_window(xf * Transform3D(Basis(), Vector3(wx, wy, hd + 0.05)), (index + f3) % 3 == 0, true, f3 == 0 or index % 2 == 0, index + f3)
		for side2: float in [-1.0, 1.0]:
			_window(xf * Transform3D(Basis(Vector3.UP, side2 * PI * 0.5), Vector3(side2 * (hw + 0.05), wy, 0)), false)
	# Roof: ridge along local X, with overhang.
	var roof_h: float = 1.6 + depth * 0.18
	_kit.gable(xf * Transform3D(Basis(), Vector3(0, wall_h, 0)), Vector3(width + 0.9, roof_h, depth + 1.1), roof_col)
	for side3: float in [-1.0, 1.0]:
		_kit.gable_wall(xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side3 * (hw + 0.02), wall_h, 0)), depth, roof_h * (depth / (depth + 1.1)), COL_PLASTER)
	# Ridge beam, eaves boards and barge boards give the roof a finished, thick edge.
	var rl: float = width + 0.9
	var rd: float = (depth + 1.1) * 0.5
	_kit.box(xf * Transform3D(Basis(), Vector3(0, wall_h + roof_h + 0.02, 0)), Vector3(rl + 0.16, 0.16, 0.2), COL_TIMBER)
	var slope: float = atan2(roof_h, rd)
	var slope_len: float = Vector2(roof_h, rd).length()
	for rs: float in [-1.0, 1.0]:
		_kit.box(xf * Transform3D(Basis(), Vector3(0, wall_h + 0.01, rs * rd)), Vector3(rl + 0.06, 0.12, 0.12), COL_TIMBER)
		for re: float in [-1.0, 1.0]:
			_kit.box(xf * Transform3D(Basis(Vector3.RIGHT, rs * slope), Vector3(re * rl * 0.5, wall_h + roof_h * 0.5 + 0.03, rs * rd * 0.5)), Vector3(0.1, 0.18, slope_len + 0.1), COL_TIMBER)
	# Chimney with smoke.
	var ch := Vector3(hw * 0.5, wall_h + roof_h * 0.6, -hd * 0.3)
	_kit.box(xf * Transform3D(Basis(), ch), Vector3(0.7, roof_h * 1.4, 0.7), COL_STONE_DARK)
	_kit.box(xf * Transform3D(Basis(), ch + Vector3(0, roof_h * 0.7 + 0.05, 0)), Vector3(0.9, 0.14, 0.9), COL_STONE)
	# Chimney cap: a stone band below the slab and a clay pot on top.
	_kit.box(xf * Transform3D(Basis(), ch + Vector3(0, roof_h * 0.7 - 0.22, 0)), Vector3(0.78, 0.1, 0.78), COL_STONE)
	_kit.cylinder(xf * Transform3D(Basis(), ch + Vector3(0, roof_h * 0.7 + 0.26, 0)), 0.17, 0.22, 0.3, 6, Color("a8553a"))
	_kit.cylinder(xf * Transform3D(Basis(), ch + Vector3(0, roof_h * 0.7 + 0.415, 0)), 0.12, 0.12, 0.02, 6, COL_GLASS.darkened(0.4))
	_smoke(xf * (ch + Vector3(0, roof_h * 0.7 + 0.2, 0)))


## Window in local XY, facing +Z: frame with lintel and sill, glazing bars, optional shutters
## and a flower box.
func _window(xf: Transform3D, lit: bool, shutters: bool = false, flowers: bool = false, seed_i: int = 0) -> void:
	_kit.box(xf, Vector3(0.9, 1.0, 0.06), COL_TIMBER)
	if lit:
		_glow_kit.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.02)), Vector3(0.7, 0.8, 0.05), Color("ffcf8a"))
	else:
		_kit.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.02)), Vector3(0.7, 0.8, 0.05), COL_GLASS)
	_kit.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.05)), Vector3(0.08, 0.8, 0.04), COL_TIMBER)
	_kit.box(xf * Transform3D(Basis(), Vector3(0, 0.08, 0.05)), Vector3(0.7, 0.06, 0.04), COL_TIMBER)
	_kit.box(xf * Transform3D(Basis(), Vector3(0, -0.52, 0.06)), Vector3(1.0, 0.08, 0.16), COL_TIMBER)
	_kit.box(xf * Transform3D(Basis(), Vector3(0, 0.54, 0.05)), Vector3(1.06, 0.1, 0.12), COL_TIMBER)
	if shutters:
		for side: float in [-1.0, 1.0]:
			# Open shutter, folded back against the wall at a slight angle, with two battens.
			var sx := xf * Transform3D(Basis(Vector3.UP, side * 0.22), Vector3(side * 0.66, 0, 0.05))
			_kit.box(sx, Vector3(0.38, 0.98, 0.05), COL_SHUTTER)
			for by: float in [-0.3, 0.3]:
				_kit.box(sx * Transform3D(Basis(), Vector3(0, by, 0.03)), Vector3(0.38, 0.08, 0.02), COL_SHUTTER.darkened(0.25))
	if flowers:
		# Flower box on brackets: planter, a strip of leaves and a few blooms.
		var bx := xf * Transform3D(Basis(), Vector3(0, -0.66, 0.2))
		_kit.box(bx, Vector3(0.96, 0.2, 0.24), COL_PLANK)
		_kit.box(bx * Transform3D(Basis(), Vector3(0, 0.07, 0.125)), Vector3(0.98, 0.05, 0.02), COL_PLANK_DARK)
		_kit.box(bx * Transform3D(Basis(), Vector3(0, 0.14, 0)), Vector3(0.9, 0.12, 0.2), COL_LEAF)
		for i: int in 5:
			var fx: float = -0.36 + i * 0.18
			var fy: float = 0.22 + 0.04 * float((i * 2 + seed_i) % 3)
			var bloom: Color = COL_BLOOMS[(i + seed_i) % COL_BLOOMS.size()]
			_kit.box(bx * Transform3D(Basis(Vector3.UP, 0.6 * i), Vector3(fx, fy, 0.03 * float((i + seed_i) % 2))), Vector3(0.11, 0.09, 0.11), bloom)
			_kit.box(bx * Transform3D(Basis(), Vector3(fx + 0.09, 0.2, -0.04)), Vector3(0.08, 0.1, 0.08), COL_LEAF.lightened(0.12))


func _smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.35, 0.08, 0.15)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.85, 0.85, 0.5))
	grad.set_color(1, Color(0.9, 0.92, 0.95, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = CombatFx.soft_dot()
	q.material = m
	p.mesh = q
	add_child(p)
	p.global_position = at


## Long pier on posts, walkable, with a lantern at the end.
func _pier(t: float) -> void:
	var start_s: float = TestArena.SHORE_S - 9.0
	var end_s: float = TestArena.SHORE_S + 18.0
	var deck_y: float = 0.55
	var basis: Basis = _facing_sea()
	var a: Vector3 = _sea() * start_s + _along() * t
	var b: Vector3 = _sea() * end_s + _along() * t
	var length: float = end_s - start_s
	var mid: Vector3 = (a + b) * 0.5
	mid.y = deck_y
	var xf := Transform3D(basis, mid)
	# Planks with small gaps and alternating tone.
	var n: int = int(length / 0.5)
	for i: int in n:
		var z: float = -length * 0.5 + (i + 0.5) * (length / n)
		_kit.box(xf * Transform3D(Basis(), Vector3(0, 0, z)), Vector3(2.6, 0.12, length / n - 0.05), COL_PLANK if i % 2 == 0 else COL_PLANK.darkened(0.08))
	_collider(xf * Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(2.6, 0.3, length))
	# Posts down into the sea, and side beams.
	var k: int = 0
	var z2: float = -length * 0.5 + 0.5
	while z2 < length * 0.5:
		for side: float in [-1.15, 1.15]:
			_kit.cylinder(xf * Transform3D(Basis(), Vector3(side, -2.0, z2)), 0.13, 0.15, 4.4, 6, COL_TIMBER)
		z2 += 2.6
		k += 1
	for side2: float in [-1.3, 1.3]:
		_kit.box(xf * Transform3D(Basis(), Vector3(side2, -0.12, 0)), Vector3(0.14, 0.18, length), COL_TIMBER)
	# Railing posts with rope on the last half.
	var zr: float = 0.0
	while zr < length * 0.5:
		for side3: float in [-1.2, 1.2]:
			_kit.box(xf * Transform3D(Basis(), Vector3(side3, 0.5, zr)), Vector3(0.12, 0.9, 0.12), COL_TIMBER)
		zr += 2.0
	for side4: float in [-1.2, 1.2]:
		_kit.box(xf * Transform3D(Basis(), Vector3(side4, 0.85, length * 0.25)), Vector3(0.05, 0.05, length * 0.5), COL_ROPE)
	# Lantern post at the end.
	var lp := Vector3(1.0, 0.0, length * 0.5 - 0.4)
	_kit.box(xf * Transform3D(Basis(), lp + Vector3(0, 1.3, 0)), Vector3(0.16, 2.6, 0.16), COL_TIMBER)
	_kit.box(xf * Transform3D(Basis(), lp + Vector3(-0.3, 2.55, 0)), Vector3(0.7, 0.12, 0.12), COL_TIMBER)
	_glow_kit.box(xf * Transform3D(Basis(), lp + Vector3(-0.55, 2.25, 0)), Vector3(0.3, 0.4, 0.3), Color("ffcf8a"))


func _pier_short(t: float) -> void:
	var start_s: float = TestArena.SHORE_S - 6.0
	var length: float = 10.0
	var basis: Basis = _facing_sea()
	var mid: Vector3 = _sea() * (start_s + length * 0.5) + _along() * t
	mid.y = 0.45
	var xf := Transform3D(basis, mid)
	_kit.box(xf, Vector3(2.0, 0.12, length), COL_PLANK)
	_collider(xf * Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(2.0, 0.3, length))
	var z: float = -length * 0.5 + 0.5
	while z < length * 0.5:
		for side: float in [-0.9, 0.9]:
			_kit.cylinder(xf * Transform3D(Basis(), Vector3(side, -2.0, z)), 0.12, 0.14, 4.3, 6, COL_TIMBER)
		z += 3.0


func _barrel(at: Vector3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at + Vector3(0, 0.45, 0))
	_kit.cylinder(xf, 0.36, 0.36, 0.9, 10, COL_PLANK)
	_collider(xf, Vector3(0.7, 0.9, 0.7))
	for y: float in [-0.3, 0.3]:
		_kit.cylinder(xf * Transform3D(Basis(), Vector3(0, y, 0)), 0.38, 0.38, 0.07, 10, COL_STONE_DARK)


func _crate(at: Vector3, size: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at + Vector3(0, size * 0.5, 0))
	_kit.box(xf, Vector3.ONE * size, COL_PLANK)
	_collider(xf, Vector3.ONE * size)
	_kit.box(xf, Vector3(size + 0.04, size * 0.2, size + 0.04), COL_PLANK_DARK)


## The fence follows the lie of the land instead of a ruler: it bends gently in and out.
func _fence_s(t: float) -> float:
	return 10.0 + sin(t * 0.13) * 1.6 + sin(t * 0.41 + 1.3) * 0.5


## Daily life in Saltwick: a well on the little square, a fish stall, a hand cart, a washing line,
## lantern posts along the lane and a signpost at the gate. Placed with a purpose, never in a row.
func _village_life() -> void:
	# Well: round stone wall, two posts, a little roof, a rope and bucket.
	var w: Vector3 = _spot(19.2, 5.0)
	arena.add_ground_spot(w, 2.2, 0.8)
	var wx := Transform3D(Basis(Vector3.UP, 0.3), w)
	_kit.cylinder(wx * Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.85, 0.95, 0.9, 14, COL_STONE)
	_kit.cylinder(wx * Transform3D(Basis(), Vector3(0, 0.92, 0)), 0.95, 0.95, 0.08, 14, COL_STONE_DARK)
	for sx: float in [-0.8, 0.8]:
		_kit.box(wx * Transform3D(Basis(), Vector3(sx, 1.4, 0)), Vector3(0.14, 1.9, 0.14), COL_TIMBER)
	_kit.box(wx * Transform3D(Basis(), Vector3(0, 2.0, 0)), Vector3(1.8, 0.1, 0.1), COL_TIMBER)
	_kit.gable(wx * Transform3D(Basis(), Vector3(0, 2.3, 0)), Vector3(2.0, 0.55, 1.3), Color(0.55, 0.33, 0.25, 0.8))
	_kit.box(wx * Transform3D(Basis(), Vector3(0, 1.65, 0)), Vector3(0.03, 0.7, 0.03), COL_ROPE)
	_kit.cylinder(wx * Transform3D(Basis(), Vector3(0, 1.2, 0)), 0.16, 0.13, 0.26, 8, COL_PLANK_DARK)
	_collider(wx * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.9, 1.2, 1.9))
	# Fish stall: trestle table under a striped awning, baskets of fish.
	var st: Vector3 = _spot(26.0, 3.0)
	arena.add_ground_spot(st, 2.6, 0.7)
	var sx2 := Transform3D(Basis(Vector3.UP, atan2(-_sea().x, -_sea().z) + 0.25), st)
	_kit.box(sx2 * Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(2.4, 0.08, 1.0), COL_PLANK)
	for lx: float in [-1.05, 1.05]:
		for lz: float in [-0.4, 0.4]:
			_kit.box(sx2 * Transform3D(Basis(), Vector3(lx, 0.42, lz)), Vector3(0.08, 0.84, 0.08), COL_TIMBER)
		_kit.box(sx2 * Transform3D(Basis(), Vector3(lx, 1.3, -0.55)), Vector3(0.08, 2.6, 0.08), COL_TIMBER)
	for k: int in 6:
		var stripe: Color = Color(0.70, 0.25, 0.20, 1.0) if k % 2 == 0 else Color(0.90, 0.86, 0.76, 1.0)
		_kit.box(sx2 * Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(-1.05 + k * 0.42, 2.35, -0.05)), Vector3(0.42, 0.03, 1.3), stripe)
	for b: int in 3:
		var bp := Vector3(-0.7 + b * 0.7, 0.98, 0.05)
		_kit.cylinder(sx2 * Transform3D(Basis(), bp), 0.26, 0.22, 0.2, 10, COL_ROPE)
		_kit.box(sx2 * Transform3D(Basis(Vector3.UP, b * 0.7), bp + Vector3(0, 0.1, 0)), Vector3(0.36, 0.06, 0.12), Color(0.62, 0.66, 0.70, 1.0))
	_collider(sx2 * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(2.5, 1.2, 1.2))
	# Hand cart, one wheel off, leaning on its shafts.
	var cp: Vector3 = _spot(17.0, -1.6)
	var cx := Transform3D(Basis(Vector3.UP, 0.9).rotated(Vector3.UP, 0.0), cp)
	_kit.box(cx * Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.75, 0)), Vector3(1.2, 0.08, 1.8), COL_PLANK)
	for side: float in [-0.62, 0.62]:
		_kit.box(cx * Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(side, 0.95, 0)), Vector3(0.06, 0.35, 1.8), COL_PLANK_DARK)
		_kit.box(cx * Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(side * 0.6, 0.45, 1.6)), Vector3(0.07, 0.07, 1.6), COL_TIMBER)
	_kit.cylinder(cx * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.7, 0.42, -0.3)), 0.42, 0.42, 0.08, 12, COL_PLANK_DARK)
	_kit.cylinder(cx * Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.4), Vector3(-1.1, 0.05, -0.6)), 0.42, 0.42, 0.08, 12, COL_PLANK_DARK)
	_collider(cx * Transform3D(Basis(), Vector3(0, 0.6, 0.2)), Vector3(1.4, 1.2, 2.4))
	# Washing line between two posts behind the houses, with cloths of different colours.
	var a: Vector3 = _spot(18.0, 13.2)
	var b2: Vector3 = _spot(21.5, 12.4)
	for pp: Vector3 in [a, b2]:
		_kit.box(Transform3D(Basis(), pp + Vector3(0, 1.0, 0)), Vector3(0.1, 2.0, 0.1), COL_TIMBER)
	var dir: Vector3 = b2 - a
	var mid: Vector3 = (a + b2) * 0.5 + Vector3(0, 1.85, 0)
	_kit.box(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), mid), Vector3(0.02, 0.02, dir.length()), COL_ROPE)
	var cloths: Array[Color] = [Color(0.85, 0.82, 0.74, 1.0), Color(0.36, 0.42, 0.62, 1.0), Color(0.62, 0.35, 0.28, 1.0), Color(0.85, 0.82, 0.74, 1.0)]
	for c: int in cloths.size():
		var f: float = (c + 0.6) / (cloths.size() + 0.2)
		var cpp: Vector3 = a.lerp(b2, f) + Vector3(0, 1.85 - 0.35 - sin(f * PI) * 0.12, 0)
		_kit.box(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), cpp), Vector3(0.02, 0.62 + (c % 2) * 0.2, 0.55), cloths[c])
	# Lantern posts along the lane, slightly off its edge, each a little different.
	for lp: Vector2 in [Vector2(13.0, 3.9), Vector2(22.6, -2.6), Vector2(27.5, -6.6), Vector2(24.8, 12.0)]:
		var p: Vector3 = _spot(lp.x, lp.y)
		var h: float = 2.4 + _rng.randf_range(-0.15, 0.2)
		_kit.box(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p + Vector3(0, h * 0.5, 0)), Vector3(0.14, h, 0.14), COL_TIMBER)
		_kit.box(Transform3D(Basis(), p + Vector3(0.25, h - 0.05, 0)), Vector3(0.55, 0.08, 0.08), COL_TIMBER)
		_glow_kit.box(Transform3D(Basis(), p + Vector3(0.45, h - 0.32, 0)), Vector3(0.24, 0.32, 0.24), Color("ffcf8a"))
		_collider(Transform3D(Basis(), p + Vector3(0, 1.0, 0)), Vector3(0.25, 2.0, 0.25))
	# Signpost at the gate, its arm pointing up the vale.
	var sp: Vector3 = _spot(_fence_s(-1.5) - 0.8, -1.8)
	_kit.box(Transform3D(Basis(), sp + Vector3(0, 1.2, 0)), Vector3(0.14, 2.4, 0.14), COL_TIMBER)
	var arm_dir: Vector3 = -_sea()
	_kit.box(Transform3D(Basis(Vector3.UP, atan2(arm_dir.x, arm_dir.z) + PI * 0.5), sp + Vector3(0, 2.0, 0) + arm_dir * 0.4), Vector3(0.9, 0.24, 0.05), COL_PLANK)
	var lbl := Label3D.new()
	lbl.text = "Saltwick"
	lbl.font_size = 28
	lbl.pixel_size = 0.004
	lbl.modulate = Color("2a1f17")
	lbl.outline_size = 0
	lbl.position = sp + Vector3(0, 2.25, 0) + _sea() * 0.08
	lbl.rotation.y = atan2(_sea().x, _sea().z) + PI
	add_child(lbl)
	_collider(Transform3D(Basis(), sp + Vector3(0, 1.0, 0)), Vector3(0.25, 2.0, 0.25))


func _props() -> void:
	# Barrels and crates near the pier head and between houses.
	var spots: Array[Vector2] = [Vector2(31.5, -6.5), Vector2(32.0, -1.8), Vector2(31.8, 3.2), Vector2(24.0, -9.8), Vector2(23.0, 13.0), Vector2(31.0, 16.5)]
	for i: int in spots.size():
		var p: Vector3 = _spot(spots[i].x, spots[i].y)
		if i % 2 == 0:
			_barrel(p)
			_barrel(p + _along() * 0.8 + _sea() * 0.2)
		else:
			_crate(p, 0.8)
			_crate(p + _along() * 0.9, 0.6)
			_crate(p + Vector3(0, 0.8, 0), 0.55)
	# Fish drying racks on the beach.
	for t: float in [8.0, 30.0]:
		var base: Vector3 = _spot(33.5, t)
		var xf := Transform3D(_facing_sea(), base)
		for x: float in [-1.6, 1.6]:
			_kit.box(xf * Transform3D(Basis(), Vector3(x, 0.9, 0)), Vector3(0.12, 1.8, 0.12), COL_TIMBER)
		_collider(xf * Transform3D(Basis(), Vector3(0, 0.9, 0)), Vector3(3.4, 1.8, 0.3))
		_kit.box(xf * Transform3D(Basis(), Vector3(0, 1.75, 0)), Vector3(3.4, 0.1, 0.1), COL_TIMBER)
		for f: int in 6:
			_kit.box(xf * Transform3D(Basis(), Vector3(-1.25 + f * 0.5, 1.35, 0)), Vector3(0.14, 0.7, 0.05), Color("9fa8b8"))
	# A low fence along the landward side of the village.
	for k: int in 18:
		var fp: Vector3 = _spot(_fence_s(-26.0 + k * 3.0), -26.0 + k * 3.0)
		# Old posts lean a little, each its own way.
		var fx := Transform3D(_facing_sea().rotated(_along(), _rng.randf_range(-0.06, 0.06)).rotated(_sea(), _rng.randf_range(-0.05, 0.05)), fp)
		_kit.box(fx * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(0.14, 1.1, 0.14), COL_TIMBER)
		_collider(fx * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(0.2, 1.1, 0.2))
		# Gate: segments 9 and 10 stay open where the path from the vale comes in.
		if k == 9 or k == 11:
			_kit.box(fx * Transform3D(Basis(), Vector3(0, 0.9, 0)), Vector3(0.22, 1.8, 0.22), COL_TIMBER)
			_kit.box(fx * Transform3D(Basis(), Vector3(0, 1.85, 0)), Vector3(0.34, 0.12, 0.34), COL_STONE)
		if k < 17 and k != 9 and k != 10:
			var nxt: Vector3 = _spot(_fence_s(-26.0 + (k + 1) * 3.0), -26.0 + (k + 1) * 3.0)
			var midp: Vector3 = (fp + nxt) * 0.5
			var dir: Vector3 = nxt - fp
			var yaw: float = atan2(dir.x, dir.z)
			var pitch: float = -atan2(dir.y, Vector2(dir.x, dir.z).length())
			var rail := Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0)), midp)
			for ry: float in [0.45, 0.85]:
				_kit.box(rail * Transform3D(Basis(), Vector3(0, ry, 0)), Vector3(0.08, 0.1, dir.length()), COL_PLANK_DARK)
			# Fences block walking (no clipping through them).
			_collider(rail * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(0.25, 1.2, dir.length() + 0.15))
	# Lantern posts along the path.
	for t2: float in [-16.0, -4.5, 7.5, 19.0]:
		var lp: Vector3 = _spot(20.5, t2)
		var lx := Transform3D(_facing_sea(), lp)
		_kit.box(lx * Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(0.16, 2.4, 0.16), COL_TIMBER)
		_collider(lx * Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(0.3, 2.4, 0.3))
		_kit.box(lx * Transform3D(Basis(), Vector3(0, 2.45, 0)), Vector3(0.45, 0.08, 0.45), COL_STONE_DARK)
		_glow_kit.box(lx * Transform3D(Basis(), Vector3(0, 2.2, 0)), Vector3(0.28, 0.4, 0.28), Color("ffcf8a"))


## A clinker-built fishing boat to scale (5.6 m long, 1.9 m beam, ~0.85 m deep): a rounded hull with a
## sharp bow and a transom stern, a painted strake, thwarts, a mast with a boom and furled sail, oars,
## a coil of rope and a heap of nets. Wood uses the architecture shader (alpha 0.6 = wood grain).
func _boat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L: float = 5.6
	var beam: float = 1.9
	var depth: float = 0.85
	var stations: int = 14
	var arc: int = 10
	var outer: Array[PackedVector3Array] = []
	var inner: Array[PackedVector3Array] = []
	for k: int in stations + 1:
		var t: float = lerpf(-1.0, 1.0, float(k) / stations)  # -1 stern, +1 bow
		var w: float
		if t > 0.0:
			w = beam * 0.5 * pow(maxf(cos(t * PI * 0.5), 0.0), 0.75)
		else:
			w = beam * 0.5 * (1.0 - 0.35 * t * t)
		var sheer: float = depth + 0.28 * t * t + (0.1 * t if t > 0.0 else 0.0)
		var keel: float = 0.06 * t * t
		var o := PackedVector3Array()
		var n := PackedVector3Array()
		for a: int in arc + 1:
			var ang: float = PI * float(a) / arc
			var x: float = w * cos(ang)
			var y: float = sheer - (sheer - keel) * pow(sin(ang), 0.55)
			var z: float = t * L * 0.5
			o.append(Vector3(x, y, z))
			var wi: float = maxf(w - 0.05, 0.0)
			n.append(Vector3(wi * cos(ang), y + 0.05 * pow(sin(ang), 0.55), z))
		outer.append(o)
		inner.append(n)
	var wood := Color(0.42, 0.30, 0.21, 0.6)
	var paint := Color(0.24, 0.36, 0.66, 0.6)
	var inside := Color(0.55, 0.42, 0.30, 0.6)
	for k: int in stations:
		for a: int in arc:
			var c_out: Color = paint if (a == 0 or a == arc - 1) else wood.darkened(0.06 * float(a % 2))
			for v: Vector3 in [outer[k][a], outer[k + 1][a], outer[k][a + 1], outer[k][a + 1], outer[k + 1][a], outer[k + 1][a + 1]]:
				st.set_color(c_out)
				st.add_vertex(v)
			for v2: Vector3 in [inner[k][a], inner[k][a + 1], inner[k + 1][a], inner[k][a + 1], inner[k + 1][a + 1], inner[k + 1][a]]:
				st.set_color(inside)
				st.add_vertex(v2)
		# Gunwale caps on both sides.
		for a2: int in [0, arc]:
			for v3: Vector3 in [outer[k][a2], inner[k][a2], outer[k + 1][a2], inner[k][a2], inner[k + 1][a2], outer[k + 1][a2]]:
				st.set_color(wood.darkened(0.2))
				st.add_vertex(v3)
	# Transom: close the stern.
	for a3: int in arc:
		var c0: Vector3 = (outer[0][0] + outer[0][arc]) * 0.5
		for v4: Vector3 in [c0, outer[0][a3 + 1], outer[0][a3]]:
			st.set_color(wood)
			st.add_vertex(v4)
	st.generate_normals()
	var hull: ArrayMesh = st.commit()
	# Fittings with MeshKit, merged into the same mesh.
	var k2 := MeshKit.new()
	var plank := Color(0.54, 0.40, 0.28, 0.6)
	for tz: float in [-1.2, 0.3, 1.5]:
		k2.box(Transform3D(Basis(), Vector3(0, 0.62, tz)), Vector3(beam * 0.82 - absf(tz) * 0.12, 0.06, 0.26), plank)
	var mast := Vector3(0, 0.0, 0.9)
	k2.cylinder(Transform3D(Basis(), mast + Vector3(0, 2.4, 0)), 0.07, 0.09, 4.6, 8, COL_TIMBER)
	# Boom with the furled sail lashed along it.
	k2.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), mast + Vector3(0, 1.45, -1.3)), 0.05, 0.05, 2.7, 6, COL_TIMBER)
	k2.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), mast + Vector3(0, 1.58, -1.25)), 0.16, 0.13, 2.4, 8, Color(0.85, 0.80, 0.68, 1.0))
	# Oars resting across the thwarts.
	for ox: float in [-0.35, 0.35]:
		k2.box(Transform3D(Basis(Vector3.UP, 0.08 * signf(ox)), Vector3(ox, 0.7, -0.2)), Vector3(0.06, 0.05, 3.0), plank)
		k2.box(Transform3D(Basis(Vector3.UP, 0.08 * signf(ox)), Vector3(ox, 0.7, -1.65)), Vector3(0.16, 0.02, 0.5), plank)
	# Rope coil and a heap of nets in the stern.
	k2.cylinder(Transform3D(Basis(), Vector3(0.3, 0.3, -1.9)), 0.22, 0.22, 0.1, 10, COL_ROPE)
	k2.box(Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.25, 0.32, -1.6)), Vector3(0.7, 0.25, 0.6), Color(0.24, 0.27, 0.25, 1.0))
	var fit: ArrayMesh = k2.commit()
	for i: int in fit.get_surface_count():
		hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fit.surface_get_arrays(i))
	return hull


func _boats_build() -> void:
	var mesh: ArrayMesh = _boat_mesh()
	var mat := MeshKit.architecture_material()
	var spots: Array[Vector2] = [Vector2(TestArena.SHORE_S + 6.0, -6.6), Vector2(TestArena.SHORE_S + 12.0, -1.4), Vector2(TestArena.SHORE_S + 2.0, 21.8), Vector2(TestArena.SHORE_S + 20.0, 10.0)]
	for i: int in spots.size():
		var b := MeshInstance3D.new()
		b.mesh = mesh
		b.material_override = mat
		var p: Vector3 = _sea() * spots[i].x + _along() * spots[i].y
		p.y = TestArena.WATER_LEVEL - 0.38  # About 0.4 m draught.
		b.position = p
		# Moored boats lie parallel to the pier, bow out to sea; the fourth swings at anchor.
		b.rotation.y = atan2(_sea().x, _sea().z) + (_rng.randf_range(-0.04, 0.04) if i < 3 else 0.7)
		add_child(b)
		_boats.append(b)
		_boat_phase.append(_rng.randf() * TAU)


func _gulls_build() -> void:
	var k := MeshKit.new()
	var white := Color("f2f2ee")
	var grey := Color("9aa2b0")
	k.box(Transform3D(Basis(), Vector3.ZERO), Vector3(0.14, 0.12, 0.5), white)
	var wing_l := MeshKit.new()
	wing_l.box(Transform3D(Basis(), Vector3(-0.38, 0, 0)), Vector3(0.75, 0.03, 0.22), grey)
	var wing_r := MeshKit.new()
	wing_r.box(Transform3D(Basis(), Vector3(0.38, 0, 0)), Vector3(0.75, 0.03, 0.22), grey)
	var body_mesh: ArrayMesh = k.commit()
	var wl: ArrayMesh = wing_l.commit()
	var wr: ArrayMesh = wing_r.commit()
	var mat := MeshKit.vertex_color_material(0.9)
	for i: int in 6:
		var g := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = mat
		g.add_child(body)
		for m: ArrayMesh in [wl, wr]:
			var w := MeshInstance3D.new()
			w.mesh = m
			w.material_override = mat
			w.name = "WingL" if m == wl else "WingR"
			g.add_child(w)
		for c: Node in g.get_children():
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		g.set_meta("radius", _rng.randf_range(10.0, 26.0))
		g.set_meta("height", _rng.randf_range(9.0, 18.0))
		g.set_meta("speed", _rng.randf_range(0.18, 0.32) * (1.0 if i % 2 == 0 else -1.0))
		g.set_meta("phase", _rng.randf() * TAU)
		g.set_meta("center", _sea() * (TestArena.SHORE_S + _rng.randf_range(-4.0, 14.0)) + _along() * _rng.randf_range(-12.0, 12.0))
		_gulls.append(g)


func _villagers() -> void:
	var outfits: Array[Dictionary] = [
		# Fishmonger in a work apron, fisherman in an oilskin hat, hooded elder.
		{"tunic": Color("8a6446"), "cloak": Color("4a483e"), "hair": Color("2c241e"), "kind": "apron", "hair_style": 1},
		{"tunic": Color("5b6c9e"), "cloak": Color("d9a441").darkened(0.12), "hair": Color("b07a45"), "kind": "hat", "trousers": Color("4a483e")},
		{"tunic": Color("4cb46a").darkened(0.35), "cloak": Color("6b4a33"), "hair": Color("8e8a7e"), "kind": "hood", "skin": Color("dba987")},
	]
	var routes: Array[Array] = [
		[Vector2(16.5, 2.5), Vector2(21.0, 0.5), Vector2(24.5, -5.5), Vector2(23.0, 9.0), Vector2(25.5, 18.0)],
		[Vector2(31.0, -6.0), Vector2(TestArena.SHORE_S + 12.0, -4.0)],
		[Vector2(33.0, 6.0), Vector2(33.5, 30.0), Vector2(29.0, 20.0)],
	]
	var barks: Array = [
		["Fresh fish! Well. Fresh-ish.", "The gulls have unionised again. They want more bread.", "If you see a Hollow, tell it we're closed.", "Morvaine gives, Morvaine takes. Mostly my nets."],
		["Mind the third plank. And the fourth. Actually, mind all of them.", "A Warden? I thought your lot were a bedtime story.", "The sea remembers everything. Unlike my brother-in-law."],
		["Back in my day the Veil only took your keys.", "That shard has hung there since Tuesday. Rude, really.", "Gods singing the world into being. Can't even hum, myself.", "They say the Unsung had a lovely voice. Nobody remembers."],
	]
	for i: int in outfits.size():
		var v := Villager.new()
		v.outfit = outfits[i]
		var bl: Array[String] = []
		bl.assign(barks[i])
		v.lines = bl
		var pts: Array[Vector3] = []
		for r: Vector2 in routes[i]:
			var p: Vector3 = _sea() * r.x + _along() * r.y
			p.y = 0.0
			pts.append(p)
		v.route = pts
		v.arena = arena
		add_child(v)


## Brenna Gale, harbourmaster: quest giver at the pier head.
func spawn_brenna() -> Villager:
	var b := Villager.new()
	b.display_name = "Brenna Gale"
	b.outfit = {"tunic": Color("3d5ba9").darkened(0.2), "cloak": Color("c9b48a"), "hair": Color("8e8a7e"), "hair_style": 2}
	var p: Vector3 = _sea() * 30.5 + _along() * -2.3
	b.route = [p]
	b.face_dir = -_sea()
	b.arena = arena
	var bl: Array[String] = ["Warden! A word, if you have a moment. Or several."]
	b.lines = bl
	add_child(b)
	return b


func _process(delta: float) -> void:
	_time += delta
	for i: int in _boats.size():
		var b: Node3D = _boats[i]
		var ph: float = _boat_phase[i]
		b.position.y = TestArena.WATER_LEVEL - 0.38 + sin(_time * 1.1 + ph) * 0.08
		b.rotation.x = sin(_time * 0.9 + ph) * 0.04
		b.rotation.z = sin(_time * 1.3 + ph * 1.7) * 0.06
	for g: Node3D in _gulls:
		var ang: float = _time * float(g.get_meta("speed")) + float(g.get_meta("phase"))
		var r: float = g.get_meta("radius")
		var c: Vector3 = g.get_meta("center")
		var h: float = float(g.get_meta("height")) + sin(_time * 0.5 + ang) * 1.5
		g.position = c + Vector3(cos(ang) * r, h, sin(ang) * r)
		var sp: float = signf(float(g.get_meta("speed")))
		var tangent := Vector3(-sin(ang), 0, cos(ang)) * sp
		g.rotation.y = atan2(tangent.x, tangent.z)
		g.rotation.z = -0.3 * sp
		var flap: float = sin(_time * 7.0 + float(g.get_meta("phase")) * 3.0)
		flap = flap * 0.5 if fmod(_time + float(g.get_meta("phase")), 4.0) < 1.6 else 0.12  # Flap, then glide.
		(g.get_node("WingL") as Node3D).rotation.z = -flap
		(g.get_node("WingR") as Node3D).rotation.z = flap
