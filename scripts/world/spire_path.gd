class_name SpirePath
extends Node3D
## The Warden's Stair: a stone path cut into the crag that winds up to the Veilspire's door.
## Built from samples along a spiral that hugs the faceted rock (see TestArena._build_crag).
## Deck and crag top sit on the walkway collision layer, so click-to-move can plan over them.

signal reached_door

## Collision layer 5: surfaces the nav grid may walk on above the terrain heightmap.
const WALKWAY_LAYER: int = 16
const SAMPLES: int = 150
const SWEEP: float = TAU * 0.86
const WIDTH: float = 5.4
## Deck centre sits this far outside the rock face (inner edge is cut ~0.9 m into the rock).
const OUT: float = 1.8
const WALL_DEPTH: float = 3.6
const FLAT_END: float = 0.86  # Fraction of the path where it reaches the plateau height.

const COL_SLAB := Color("d9d3c2")
const COL_SLAB_B := Color("cbc5b3")
const COL_JOINT := Color("a9a393")
const COL_WALL := Color("9c9a92")
const COL_WALL_DARK := Color("7d7f86")
const COL_TRIM := Color("5b6c9e")
const COL_BANNER := Color("3d5ba9")
const COL_IRON := Color("2a2d33")
const COL_RUNE := Color("6ec3f0")

var arena: TestArena
var door_position: Vector3
var _centre: Vector3
var _pts: Array[Vector3] = []  # Deck centre line (world).
var _out: Array[Vector3] = []  # Outward unit vector per sample (xz).
var _fwd: Array[Vector3] = []  # Forward unit vector per sample (xz).
var _door_fired: bool = false


func build(p_arena: TestArena) -> void:
	arena = p_arena
	_centre = Vector3(TestArena.CLIFF_CENTER.x, 0.0, TestArena.CLIFF_CENTER.y)
	_sample_path()
	_build_deck()
	_build_parapet_and_lamps()
	_build_gate()
	_build_door()


## Rock radius of the crag at height `h` and angle `ang` (interpolated between profile rings).
func rock_radius(h: float, ang: float) -> float:
	var prof: Array[Vector2] = TestArena.CRAG_PROFILE
	var k: int = 0
	while k < prof.size() - 2 and prof[k + 1].x < h:
		k += 1
	var t: float = clampf(inverse_lerp(prof[k].x, prof[k + 1].x, h), 0.0, 1.0)
	return lerpf(_ring_radius(k, ang), _ring_radius(k + 1, ang), t)


## The crag mesh is built from 36 segments; interpolate between its vertices.
func _ring_radius(k: int, ang: float) -> float:
	var seg: float = 36.0
	var f: float = fposmod(ang, TAU) / TAU * seg
	var i0: int = int(floor(f))
	var a0: float = TAU * i0 / seg
	var a1: float = TAU * (i0 + 1) / seg
	return lerpf(arena._crag_radius(k, a0), arena._crag_radius(k, a1), f - i0)


func _sample_path() -> void:
	var to_valley := Vector2(-TestArena.CLIFF_CENTER.x, -TestArena.CLIFF_CENTER.y).normalized()
	# Start beside the Undercroft door (which faces the valley) and wind away from it.
	var a_start: float = atan2(to_valley.y, to_valley.x) + 0.5
	# Ground height at the foot of the stair.
	var h0: float = 7.0
	for it: int in 3:
		var r0: float = rock_radius(h0, a_start) + OUT + 1.0
		h0 = arena.height_at(_centre.x + cos(a_start) * r0, _centre.z + sin(a_start) * r0) - 0.25
	var top: float = TestArena.CRAG_TOP + 0.12
	var raw_r: Array[float] = []
	var hs: Array[float] = []
	var angs: Array[float] = []
	for i: int in SAMPLES:
		var u: float = float(i) / (SAMPLES - 1)
		var ang: float = a_start + u * SWEEP
		var e: float = clampf(u / FLAT_END, 0.0, 1.0)
		var h: float = lerpf(h0, top, e * e * (3.0 - 2.0 * e) * 0.35 + e * 0.65)
		hs.append(h)
		angs.append(ang)
		raw_r.append(rock_radius(minf(h, TestArena.CRAG_TOP - 0.01), ang) + OUT)
	for i: int in SAMPLES:
		var sum: float = 0.0
		var n: int = 0
		for j: int in range(maxi(0, i - 5), mini(SAMPLES, i + 6)):
			sum += raw_r[j]
			n += 1
		var rock: float = rock_radius(minf(hs[i], TestArena.CRAG_TOP - 0.01), angs[i])
		var r: float = clampf(sum / n, rock + 1.1, rock + 2.4)
		var u: float = float(i) / (SAMPLES - 1)
		# On the plateau the path turns inward toward the tower door.
		var inward: float = smoothstep(FLAT_END - 0.02, 1.0, u)
		r = lerpf(r, 8.6, inward)
		_pts.append(_centre + Vector3(cos(angs[i]) * r, hs[i], sin(angs[i]) * r))
		_out.append(Vector3(cos(angs[i]), 0.0, sin(angs[i])))
	for i: int in SAMPLES:
		var a: Vector3 = _pts[maxi(i - 1, 0)]
		var b: Vector3 = _pts[mini(i + 1, SAMPLES - 1)]
		var f := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		_fwd.append(f)
		# Recompute "out" as the perpendicular of the travel direction, so the deck never twists.
		var side := Vector3(-f.z, 0.0, f.x)
		if side.dot(_out[i]) < 0.0:
			side = -side
		_out[i] = side


## Quad with automatic winding so its front face points along `outward`.
func _q(kit: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(outward) < 0.0:
		kit._quad(Transform3D.IDENTITY, a, d, c, b, col)
	else:
		kit._quad(Transform3D.IDENTITY, a, b, c, d, col)


func _build_deck() -> void:
	var kit := MeshKit.new()
	var hw: float = WIDTH * 0.5
	for i: int in SAMPLES - 1:
		var p0: Vector3 = _pts[i]
		var p1: Vector3 = _pts[i + 1]
		var o0: Vector3 = _out[i]
		var o1: Vector3 = _out[i + 1]
		var in0: Vector3 = p0 - o0 * hw
		var in1: Vector3 = p1 - o1 * hw
		var ou0: Vector3 = p0 + o0 * hw
		var ou1: Vector3 = p1 + o1 * hw
		# Flagstones: alternate tones, with a darker joint strip every third segment.
		var col: Color = COL_SLAB if (i / 2) % 2 == 0 else COL_SLAB_B
		if i % 3 == 2:
			col = COL_JOINT
		# Curb strip along the outer edge in slate blue.
		var c0: Vector3 = ou0 - o0 * 0.35
		var c1: Vector3 = ou1 - o1 * 0.35
		_q(kit, in0, in1, c1, c0, Vector3.UP, col)
		_q(kit, c0, c1, ou1 + Vector3.UP * 0.06, ou0 + Vector3.UP * 0.06, Vector3.UP, COL_TRIM)
		# Retaining wall under the outer edge, and its underside back into the rock.
		var d0: Vector3 = ou0 + Vector3.DOWN * WALL_DEPTH
		var d1: Vector3 = ou1 + Vector3.DOWN * WALL_DEPTH
		var wcol: Color = COL_WALL if (i / 4) % 2 == 0 else COL_WALL.darkened(0.06)
		_q(kit, ou0 + Vector3.UP * 0.06, ou1 + Vector3.UP * 0.06, d1, d0, o0, wcol)
		var b0: Vector3 = in0 + Vector3.DOWN * WALL_DEPTH
		var b1: Vector3 = in1 + Vector3.DOWN * WALL_DEPTH
		_q(kit, d0, d1, b1, b0, Vector3.DOWN, COL_WALL_DARK)
		# Buttress every 12 segments.
		if i % 12 == 6:
			var bp: Vector3 = ou0 + o0 * 0.35 + Vector3.DOWN * (WALL_DEPTH * 0.5 + 0.3)
			var bas := Basis.looking_at(-o0, Vector3.UP)
			kit.box(Transform3D(bas, bp), Vector3(0.9, WALL_DEPTH - 0.4, 0.8), COL_WALL_DARK)
	# End caps so the deck reads as solid stone.
	for idx: int in [0, SAMPLES - 1]:
		var p: Vector3 = _pts[idx]
		var o: Vector3 = _out[idx]
		var f: Vector3 = _fwd[idx] * (-1.0 if idx == 0 else 1.0)
		_q(kit, p - o * hw, p + o * hw, p + o * hw + Vector3.DOWN * WALL_DEPTH, p - o * hw + Vector3.DOWN * WALL_DEPTH, f, COL_WALL)
	var mesh: ArrayMesh = kit.commit()
	var body := StaticBody3D.new()
	body.name = "StairDeck"
	body.collision_layer = 1 | WALKWAY_LAYER
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MeshKit.vertex_color_material(0.9)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)


func _build_parapet_and_lamps() -> void:
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var body := StaticBody3D.new()
	body.name = "StairParapet"
	body.collision_layer = 1
	add_child(body)
	var hw: float = WIDTH * 0.5
	var i: int = 2
	var end_i: int = int((SAMPLES - 1) * (FLAT_END + 0.02))
	while i < end_i:
		var j: int = mini(i + 3, end_i)
		var a: Vector3 = _pts[i] + _out[i] * (hw - 0.2)
		var b: Vector3 = _pts[j] + _out[j] * (hw - 0.2)
		var mid: Vector3 = (a + b) * 0.5 + Vector3.UP * 0.3
		var dir: Vector3 = b - a
		var len: float = dir.length()
		var bas := Basis.looking_at(dir.normalized(), Vector3.UP)
		var size := Vector3(0.42, 0.6, len + 0.08)
		kit.box(Transform3D(bas, mid), size, COL_WALL)
		kit.box(Transform3D(bas, mid + Vector3.UP * 0.33), Vector3(0.5, 0.08, len + 0.1), COL_SLAB)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.42, 1.2, len)
		cs.shape = bs
		cs.transform = Transform3D(bas, mid + Vector3.UP * 0.3)
		body.add_child(cs)
		# Lamp posts with a warm lantern every ~20 samples.
		if i % 20 == 5:
			var lp: Vector3 = a + Vector3.UP * 0.6
			kit.box(Transform3D(Basis(), lp + Vector3.UP * 0.9), Vector3(0.22, 1.8, 0.22), COL_IRON)
			kit.box(Transform3D(Basis(), lp + Vector3.UP * 1.85), Vector3(0.5, 0.1, 0.5), COL_IRON)
			kit.box(Transform3D(Basis(), lp + Vector3.UP * 2.35), Vector3(0.44, 0.08, 0.44), COL_IRON)
			kit.cylinder(Transform3D(Basis(), lp + Vector3.UP * 2.55), 0.0, 0.32, 0.3, 4, COL_TRIM)
			glow.box(Transform3D(Basis(), lp + Vector3.UP * 2.1), Vector3(0.32, 0.42, 0.32), Color("ffd08a"))
		i = j
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = MeshKit.vertex_color_material()
	add_child(mi)
	var gmi := MeshInstance3D.new()
	gmi.name = "LampGlow"
	gmi.mesh = glow.commit()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.emission_enabled = true
	gm.emission = Color("ffb35c")
	gm.emission_energy_multiplier = 1.6
	gmi.material_override = gm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)


## Stone gate with blue banners at the foot of the stair.
func _build_gate() -> void:
	var kit := MeshKit.new()
	var p: Vector3 = _pts[3]
	var o: Vector3 = _out[3]
	var f: Vector3 = _fwd[3]
	var bas := Basis.looking_at(f, Vector3.UP)
	var body := StaticBody3D.new()
	body.name = "StairGate"
	body.collision_layer = 1
	add_child(body)
	var hw: float = WIDTH * 0.5 + 0.55
	for s: float in [-1.0, 1.0]:
		var base: Vector3 = p + o * hw * s
		var gy: float = maxf(arena.height_at(base.x, base.z), p.y - 1.0)
		var hgt: float = p.y + 4.6 - gy
		kit.box(Transform3D(bas, Vector3(base.x, gy + hgt * 0.5, base.z)), Vector3(1.0, hgt, 1.0), COL_WALL)
		kit.box(Transform3D(bas, Vector3(base.x, p.y + 4.75, base.z)), Vector3(1.25, 0.3, 1.25), COL_SLAB)
		kit.box(Transform3D(bas, Vector3(base.x, gy + 0.25, base.z)), Vector3(1.3, 0.5, 1.3), COL_WALL_DARK)
		# Banner hanging on the valley side of each pillar.
		var bpos: Vector3 = base - f * 0.53 + Vector3(0, p.y + 3.0 - base.y, 0)
		kit.box(Transform3D(bas, bpos), Vector3(0.75, 2.3, 0.05), COL_BANNER)
		kit.wedge(Transform3D(bas.rotated(bas.x, -PI * 0.5), bpos + Vector3.DOWN * 1.35), Vector3(0.75, 0.05, 0.4), COL_BANNER)
		kit.box(Transform3D(bas, bpos + Vector3.UP * 0.2), Vector3(0.3, 0.3, 0.06), Color("e6e1d3"))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.0, hgt, 1.0)
		cs.shape = bs
		cs.transform = Transform3D(bas, Vector3(base.x, gy + hgt * 0.5, base.z))
		body.add_child(cs)
	# Lintel with a slate-blue keystone.
	kit.box(Transform3D(bas, p + Vector3.UP * 5.2), Vector3(WIDTH + 2.4, 0.7, 1.1), COL_SLAB)
	kit.box(Transform3D(bas, p + Vector3.UP * 5.25), Vector3(0.8, 1.0, 1.2), COL_TRIM)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = MeshKit.vertex_color_material()
	add_child(mi)


## The sealed door of the Veilspire, on the side where the stair arrives. Blue runes of the Veil glow on it.
func _build_door() -> void:
	var end: Vector3 = _pts[SAMPLES - 1]
	var dir := Vector3(end.x - _centre.x, 0.0, end.z - _centre.z).normalized()
	var base_y: float = TestArena.CRAG_TOP - 0.3
	var door_base := Vector3(_centre.x, base_y, _centre.z) + dir * 5.25
	door_position = door_base
	var bas := Basis.looking_at(dir, Vector3.UP)  # -Z of the basis points outward.
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	# Arch frame: two jambs, a lintel and a pointed cap.
	for s: float in [-1.0, 1.0]:
		kit.box(Transform3D(bas, door_base + bas.x * 1.25 * s + Vector3.UP * 1.9), Vector3(0.55, 3.8, 0.7), COL_SLAB)
	kit.box(Transform3D(bas, door_base + Vector3.UP * 4.0), Vector3(3.1, 0.55, 0.75), COL_SLAB)
	kit.box(Transform3D(bas, door_base + Vector3.UP * 4.0 - bas.z * 0.05), Vector3(0.7, 0.8, 0.8), COL_TRIM)
	# Door leaves: dark iron-bound wood.
	kit.box(Transform3D(bas, door_base + Vector3.UP * 1.85 + bas.z * 0.1), Vector3(1.95, 3.7, 0.25), Color("2b2a2e"))
	for y: float in [0.8, 1.9, 3.0]:
		kit.box(Transform3D(bas, door_base + Vector3.UP * y - bas.z * 0.05), Vector3(2.0, 0.12, 0.08), COL_IRON)
	# Steps up to the threshold.
	kit.box(Transform3D(bas, door_base - bas.z * 0.9 + Vector3.UP * 0.1), Vector3(3.4, 0.3, 1.3), COL_WALL)
	# Veil runes: a ring and three vertical strokes, glowing pale blue.
	var rp: Vector3 = door_base + Vector3.UP * 2.1 - bas.z * 0.04
	for k: int in 12:
		var a: float = TAU * k / 12.0
		var q: Vector3 = rp + bas.x * cos(a) * 0.62 + Vector3.UP * sin(a) * 0.62
		glow.box(Transform3D(bas.rotated(bas.z, a), q), Vector3(0.08, 0.3, 0.04), COL_RUNE)
	for s: float in [-0.25, 0.0, 0.25]:
		glow.box(Transform3D(bas, rp + bas.x * s), Vector3(0.07, 0.75 - absf(s), 0.04), COL_RUNE)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = MeshKit.vertex_color_material()
	add_child(mi)
	var gmi := MeshInstance3D.new()
	gmi.name = "RuneGlow"
	gmi.mesh = glow.commit()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.emission_enabled = true
	gm.emission = COL_RUNE
	gm.emission_energy_multiplier = 2.2
	gmi.material_override = gm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)
	var light := OmniLight3D.new()
	light.light_color = COL_RUNE
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position = rp - bas.z * 1.2
	add_child(light)
	# Trigger: walking up to the door.
	var area := Area3D.new()
	area.name = "DoorTrigger"
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.0
	cs.shape = sph
	area.position = door_base - bas.z * 1.5 + Vector3.UP
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_door_body)


func _on_door_body(b: Node3D) -> void:
	if b is Player and not _door_fired:
		_door_fired = true
		reached_door.emit()


## Deck point nearest to the stair foot and the top, for tests and screenshots.
func foot() -> Vector3:
	return _pts[1]


func top() -> Vector3:
	return _pts[SAMPLES - 1]


func point_at(u: float) -> Vector3:
	return _pts[clampi(int(u * (SAMPLES - 1)), 0, SAMPLES - 1)]
