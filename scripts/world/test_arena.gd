class_name TestArena
extends Node3D
## Phase 1 test area: a green valley with a flat arena in the middle,
## valley walls, a cliff with a watchtower and a ring of snowy mountains on the horizon.
## Everything is generated in code from a fixed seed so every run looks the same.

const TERRAIN_SIZE: float = 240.0
const CELL: float = 2.0
const CLIFF_CENTER := Vector2(18.0, -78.0)
const PEAK_DIR: float = deg_to_rad(-20.0)  # Direction of the great peak (from +X toward -Z).

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var terrain_material: ShaderMaterial
var sun: DirectionalLight3D
var environment: Environment


func _ready() -> void:
	_noise.seed = 1337
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_detail.seed = 4242
	_detail.frequency = 0.06
	_build_environment()
	_build_terrain()
	_build_far_mountains()
	_build_watchtower()
	_build_ruins()
	_build_arena_props()
	_scatter_trees()


## Terrain height at world x/z. Flat arena in the middle, rising valley walls, a cliff plateau.
func height_at(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var flat_blend: float = smoothstep(20.0, 48.0, r)
	var hills: float = (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 9.0 + _detail.get_noise_2d(x, z) * 0.8
	var walls: float = pow(smoothstep(55.0, 118.0, r), 1.6) * 34.0
	var h: float = flat_blend * (hills + walls)
	var cd: float = Vector2(x, z).distance_to(CLIFF_CENTER)
	var cliff: float = pow(smoothstep(30.0, 16.0, cd), 0.7) * 30.0
	h = maxf(h, cliff + (_detail.get_noise_2d(x * 0.5, z * 0.5)) * 1.2 * smoothstep(30.0, 16.0, cd))
	return h


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3f86d6")
	sky_mat.sky_horizon_color = Color("a8dcf6")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color("a8dcf6")
	sky_mat.ground_bottom_color = Color("5b6c9e")
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	environment.ambient_light_sky_contribution = 0.6
	environment.ambient_light_color = Color("e8e0cc")
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	# Atmospheric perspective: distance fog tinted like the horizon sky.
	environment.fog_enabled = true
	environment.fog_light_color = Color("a6cdea")
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.25
	environment.fog_density = 0.0017
	environment.fog_sky_affect = 0.0
	environment.fog_height = 8.0
	environment.fog_height_density = 0.0015
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.1

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.6
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-140.0), 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.2
	add_child(sun)


func _build_terrain() -> void:
	var n: int = int(TERRAIN_SIZE / CELL) + 1
	var half: float = TERRAIN_SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j: int in n:
		for i: int in n:
			heights[j * n + i] = height_at(-half + i * CELL, -half + j * CELL)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in n:
		for i: int in n:
			st.set_uv(Vector2(i, j) / float(n - 1))
			st.add_vertex(Vector3(-half + i * CELL, heights[j * n + i], -half + j * CELL))
	for j: int in n - 1:
		for i: int in n - 1:
			var a: int = j * n + i
			var b: int = a + 1
			var c: int = a + n
			var d: int = c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("snow_height", 70.0)
	terrain_material.set_shader_parameter("rock_slope", 0.6)
	terrain_material.set_shader_parameter("strata_freq", 0.7)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_material
	body.add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(CELL, 1.0, CELL)
	body.add_child(cs)


## Ring of mountains beyond the playable valley. Visual only.
func _build_far_mountains() -> void:
	var seg: int = 128
	var rings: int = 18
	var r0: float = 110.0
	var r1: float = 900.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ridge := FastNoiseLite.new()
	ridge.seed = 99
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 5
	ridge.frequency = 0.004
	for k: int in rings + 1:
		var t: float = float(k) / rings
		var r: float = lerpf(r0, r1, pow(t, 1.4))
		for s: int in seg + 1:
			var ang: float = TAU * float(s) / seg
			var x: float = cos(ang) * r
			var z: float = sin(ang) * r
			var profile: float = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.75, 1.0, t))
			var h: float = (ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 150.0 * profile + 28.0 * smoothstep(0.0, 0.1, t)
			# One dominant snow peak as a far landmark.
			var dang: float = absf(angle_difference(ang, PEAK_DIR))
			h += exp(-dang * dang * 40.0) * exp(-pow((r - 420.0) / 120.0, 2.0)) * 260.0
			st.add_vertex(Vector3(x, h - 4.0, z))
	for k: int in rings:
		for s: int in seg:
			var a: int = k * (seg + 1) + s
			var b: int = a + 1
			var c: int = a + seg + 1
			var d: int = c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "FarMountains"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("snow_height", 150.0)
	mat.set_shader_parameter("snow_blend", 20.0)
	mat.set_shader_parameter("strata_freq", 0.12)
	mat.set_shader_parameter("strata_amount", 0.3)
	mat.set_shader_parameter("rock_color", Color("4f5d8c"))
	mat.set_shader_parameter("rock_light", Color("8d97b3"))
	mat.set_shader_parameter("grass_color", Color("3f8f62"))
	mat.set_shader_parameter("grass_dark", Color("2f6e55"))
	mat.set_shader_parameter("rock_slope", 0.82)
	mat.set_shader_parameter("detail_scale", 0.02)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _stone_mat(color: Color = Color("e6e1d3"), roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _add_static(parent: Node3D, mesh: Mesh, mat: Material, xform: Transform3D, shape: Shape3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	parent.add_child(mi)
	if shape:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.transform = xform
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
	return mi


func _cyl(top: float, bottom: float, height: float, segs: int = 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segs
	return c


## Watchtower on the cliff: the main landmark visible from the arena.
func _build_watchtower() -> void:
	var root := Node3D.new()
	root.name = "Watchtower"
	var base_y: float = height_at(CLIFF_CENTER.x, CLIFF_CENTER.y)
	root.position = Vector3(CLIFF_CENTER.x, base_y - 0.5, CLIFF_CENTER.y)
	add_child(root)
	var stone := _stone_mat(Color("e6e1d3"))
	var stone_dark := _stone_mat(Color("b9b3a3"))
	var roof := _stone_mat(Color("3d5ba9"), 0.55)
	var trim := _stone_mat(Color("5b6c9e"), 0.7)
	_add_static(root, _cyl(4.6, 5.4, 4.0, 24), stone_dark, Transform3D(Basis(), Vector3(0, 2.0, 0)), CylinderShape3D.new())
	_add_static(root, _cyl(3.4, 4.0, 22.0, 24), stone, Transform3D(Basis(), Vector3(0, 15.0, 0)))
	_add_static(root, _cyl(4.3, 3.6, 2.0, 24), stone_dark, Transform3D(Basis(), Vector3(0, 27.0, 0)))
	# Crenellations.
	for i: int in 12:
		var a: float = TAU * i / 12.0
		_add_static(root, BoxMesh.new(), stone, Transform3D(Basis(Vector3.UP, a).scaled(Vector3(1.0, 1.2, 0.8)), Vector3(cos(a) * 4.0, 28.6, sin(a) * 4.0)))
	_add_static(root, _cyl(2.6, 2.6, 5.0, 20), stone, Transform3D(Basis(), Vector3(0, 30.5, 0)))
	_add_static(root, _cyl(0.0, 3.6, 7.5, 20), roof, Transform3D(Basis(), Vector3(0, 36.7, 0)))
	_add_static(root, _cyl(3.65, 3.65, 0.5, 20), trim, Transform3D(Basis(), Vector3(0, 33.0, 0)))
	# Windows: dark slits.
	var dark := _stone_mat(Color("1e2125"))
	for i: int in 4:
		var a: float = TAU * i / 4.0 + 0.4
		for level: float in [10.0, 18.0, 30.5]:
			var rad: float = 3.55 if level < 25.0 else 2.62
			_add_static(root, BoxMesh.new(), dark, Transform3D(Basis(Vector3.UP, -a).scaled(Vector3(0.5, 1.6, 0.3)), Vector3(cos(a) * rad, level, sin(a) * rad)))
	# Banner on a pole.
	_add_static(root, _cyl(0.08, 0.08, 4.0, 8), dark, Transform3D(Basis(), Vector3(0, 42.0, 0)))
	var flag := _stone_mat(Color("3d5ba9"), 0.8)
	flag.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_static(root, BoxMesh.new(), flag, Transform3D(Basis().scaled(Vector3(2.2, 1.1, 0.05)), Vector3(1.15, 43.3, 0)))


## Broken stone arches and pillars near the arena edge: a mid-ground focal point.
func _build_ruins() -> void:
	var root := Node3D.new()
	root.name = "Ruins"
	add_child(root)
	var stone := _stone_mat(Color("ddd7c6"))
	var moss := _stone_mat(Color("6f9c5e"))
	var spots: Array[Vector3] = [Vector3(-16, 0, -12), Vector3(-10, 0, -19), Vector3(-3, 0, -22), Vector3(5, 0, -21)]
	var heights: Array[float] = [6.5, 4.0, 7.2, 2.4]
	for i: int in spots.size():
		var p: Vector3 = spots[i]
		p.y = height_at(p.x, p.z)
		var h: float = heights[i]
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, h, 1.4)
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, h, 1.4)
		_add_static(root, bm, stone, Transform3D(Basis(Vector3.UP, i * 0.3), p + Vector3(0, h * 0.5, 0)), box)
		var cap := BoxMesh.new()
		cap.size = Vector3(1.8, 0.4, 1.8)
		_add_static(root, cap, stone, Transform3D(Basis(Vector3.UP, i * 0.3), p + Vector3(0, h + 0.2, 0)))
		var moss_m := BoxMesh.new()
		moss_m.size = Vector3(1.85, 0.12, 1.85)
		_add_static(root, moss_m, moss, Transform3D(Basis(Vector3.UP, i * 0.3), p + Vector3(0, h + 0.45, 0)))
	# A lintel across the first two pillars forms an arch.
	var lintel := BoxMesh.new()
	lintel.size = Vector3(1.4, 0.8, 9.0)
	var a: Vector3 = spots[0]
	var b: Vector3 = spots[1]
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = (b - a)
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z))
	_add_static(root, lintel, stone, Transform3D(basis, Vector3(mid.x, 4.4, mid.z)))
	# Fallen blocks.
	for k: int in 6:
		var q := Vector3(-12.0 + k * 2.7, 0, -15.0 - (k % 3) * 2.0)
		q.y = height_at(q.x, q.z) + 0.35
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(1.2, 0.7, 0.9)
		var sh := BoxShape3D.new()
		sh.size = bm2.size
		_add_static(root, bm2, stone, Transform3D(Basis(Vector3(0.2, 1, 0.1).normalized(), k * 1.3), q), sh)


## Steps and platforms to test jumping, plus a few rocks.
func _build_arena_props() -> void:
	var root := Node3D.new()
	root.name = "ArenaProps"
	add_child(root)
	var stone := _stone_mat(Color("d8d2c2"))
	var trim := _stone_mat(Color("5b6c9e"), 0.7)
	var steps: Array[Vector4] = [Vector4(10, 0.5, 6, 3.0), Vector4(13, 1.3, 8.5, 2.6), Vector4(15.5, 2.2, 11.5, 2.4), Vector4(17.5, 3.2, 15, 3.4)]
	for s: Vector4 in steps:
		var size := Vector3(s.w, s.y * 2.0, s.w)
		var bm := BoxMesh.new()
		bm.size = size
		var sh := BoxShape3D.new()
		sh.size = size
		_add_static(root, bm, stone, Transform3D(Basis(), Vector3(s.x, 0, s.z)), sh)
		var rim := BoxMesh.new()
		rim.size = Vector3(s.w + 0.1, 0.15, s.w + 0.1)
		_add_static(root, rim, trim, Transform3D(Basis(), Vector3(s.x, s.y - 0.07, s.z)))
	# Rounded boulders.
	var rock_mat := _stone_mat(Color("a9a597"), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in 14:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(22.0, 60.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		p.y = height_at(p.x, p.z)
		var sm := SphereMesh.new()
		var rad: float = rng.randf_range(0.8, 2.4)
		sm.radius = rad
		sm.height = rad * 1.4
		sm.radial_segments = 9
		sm.rings = 5
		var sh := SphereShape3D.new()
		sh.radius = rad * 0.7
		_add_static(root, sm, rock_mat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.2))), p), sh)


func _scatter_trees() -> void:
	var root := Node3D.new()
	root.name = "Trees"
	add_child(root)
	var trunk_mat := _stone_mat(Color("6b4a33"), 0.9)
	var leaf_round := ShaderMaterial.new()
	leaf_round.shader = preload("res://shaders/foliage.gdshader")
	leaf_round.set_shader_parameter("base_color", Color("3f9a59"))
	leaf_round.set_shader_parameter("tip_color", Color("7fcf6e"))
	var leaf_pine := ShaderMaterial.new()
	leaf_pine.shader = preload("res://shaders/foliage.gdshader")
	leaf_pine.set_shader_parameter("base_color", Color("2a6b4a"))
	leaf_pine.set_shader_parameter("tip_color", Color("4a9a62"))
	leaf_pine.set_shader_parameter("sway_strength", 0.08)
	leaf_pine.set_shader_parameter("height_ref", 7.0)

	var trunk := _cyl(0.22, 0.32, 3.0, 8)
	var crown := SphereMesh.new()
	crown.radius = 1.9
	crown.height = 3.4
	crown.radial_segments = 10
	crown.rings = 6
	var cone_a := _cyl(0.0, 2.2, 3.4, 9)
	var cone_b := _cyl(0.0, 1.7, 2.9, 9)
	var cone_c := _cyl(0.0, 1.2, 2.3, 9)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var placed: int = 0
	var tries: int = 0
	while placed < 70 and tries < 600:
		tries += 1
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(26.0, 105.0)
		var x: float = cos(ang) * dist
		var z: float = sin(ang) * dist
		if Vector2(x, z).distance_to(CLIFF_CENTER) < 14.0:
			continue
		if x > -22.0 and x < 10.0 and z < -8.0 and z > -28.0:
			continue  # Keep the ruins readable.
		var y: float = height_at(x, z)
		# Avoid steep slopes.
		var slope: float = absf(height_at(x + 1.5, z) - y) + absf(height_at(x, z + 1.5) - y)
		if slope > 2.0:
			continue
		var tree := Node3D.new()
		tree.position = Vector3(x, y - 0.1, z)
		tree.rotation.y = rng.randf() * TAU
		var s: float = rng.randf_range(0.85, 1.35)
		tree.scale = Vector3.ONE * s
		root.add_child(tree)
		var is_pine: bool = y > 9.0 or rng.randf() < 0.35
		var tmi := MeshInstance3D.new()
		tmi.mesh = trunk
		tmi.material_override = trunk_mat
		tmi.position.y = 1.5
		tree.add_child(tmi)
		if is_pine:
			for layer: Array in [[cone_a, 3.6], [cone_b, 5.2], [cone_c, 6.6]]:
				var c := MeshInstance3D.new()
				c.mesh = layer[0]
				c.material_override = leaf_pine
				c.position.y = layer[1]
				tree.add_child(c)
		else:
			for off: Vector3 in [Vector3(0, 4.2, 0), Vector3(0.9, 3.6, 0.3), Vector3(-0.7, 3.8, -0.6)]:
				var c2 := MeshInstance3D.new()
				c2.mesh = crown
				c2.material_override = leaf_round
				c2.position = off
				c2.scale = Vector3.ONE * (1.0 if off.x == 0.0 else 0.7)
				tree.add_child(c2)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 3.0
		cs.shape = cyl
		cs.position.y = 1.5
		body.add_child(cs)
		tree.add_child(body)
		placed += 1
