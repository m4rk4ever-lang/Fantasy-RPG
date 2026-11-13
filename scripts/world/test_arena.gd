class_name TestArena
extends Node3D
## Phase 1 test area: a green valley with a flat arena in the middle,
## valley walls, a cliff with a watchtower and a ring of snowy mountains on the horizon.
## Everything is generated in code from a fixed seed so every run looks the same.

const TERRAIN_SIZE: float = 240.0
const CELL: float = 2.0
const CLIFF_CENTER := Vector2(18.0, -78.0)
const CRAG_TOP: float = 32.0
## The valley opens to the sea toward the south-east. `s` = distance along SEA_DIR.
const SEA_DIR := Vector2(0.781, 0.625)
const SHORE_S: float = 42.0
const WATER_LEVEL: float = -0.6
## Inland ground sits this far above the sea, so sand only shows on the beach.
const LAND_BASE: float = 1.3
## Crag profile: (height, radius) rings from base to top. Short steep steps make grassy ledges.
const CRAG_PROFILE: Array[Vector2] = [
	Vector2(-1.0, 22.0), Vector2(5.0, 20.5), Vector2(9.0, 19.5), Vector2(9.8, 17.6),
	Vector2(16.0, 16.8), Vector2(20.5, 16.0), Vector2(21.2, 14.6), Vector2(27.0, 14.0),
	Vector2(31.0, 13.4), Vector2(32.0, 12.6),
]
const PEAK_DIR: float = deg_to_rad(-20.0)  # Direction of the great peak (from +X toward -Z).

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var terrain_material: ShaderMaterial
var sun: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
var moon: DirectionalLight3D
var day_night: DayNight
var village: Village
var undercroft_door: Interactable
var undercroft_door_outside: Vector3
var beacon_light: OmniLight3D
var spire_path: SpirePath


func _ready() -> void:
	_noise.seed = 1337
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_detail.seed = 4242
	_detail.frequency = 0.06
	_build_environment()
	_build_terrain()
	_build_far_mountains()
	_build_crag()
	_build_watchtower()
	spire_path = SpirePath.new()
	spire_path.name = "SpirePath"
	add_child(spire_path)
	spire_path.build(self)
	_build_ruins()
	_build_arena_props()
	_scatter_trees()
	_scatter_grass()
	_build_water()
	var shard := SkyShard.new()
	shard.name = "SkyShard"
	shard.position = Vector3(-62.0, 88.0, -175.0)
	shard.scale = Vector3.ONE * 1.5
	shard.rotation = Vector3(0.0, 0.0, 0.18)
	add_child(shard)
	village = Village.new()
	village.name = "Village"
	add_child(village)
	village.build(self)


## Terrain height at world x/z. Flat arena in the middle, rising valley walls, a cliff plateau.
func height_at(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var flat_blend: float = smoothstep(20.0, 48.0, r)
	var hills: float = (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 9.0 + _detail.get_noise_2d(x, z) * 0.8
	var walls: float = pow(smoothstep(55.0, 118.0, r), 1.6) * 34.0
	var h: float = flat_blend * (hills + walls)
	var cd: float = Vector2(x, z).distance_to(CLIFF_CENTER)
	# Gentle mound under the crag; the rock itself is a separate faceted mesh (see _build_crag).
	# The crag stands free: the valley wall dips into a grassy hollow around it, so the stair stays in the open.
	h = lerpf(h, minf(h, 6.5 + maxf(cd - 30.0, 0.0) * 0.6), smoothstep(56.0, 30.0, cd))
	var mound: float = smoothstep(36.0, 18.0, cd) * 7.0
	h = maxf(h, mound)
	# Coast: the valley walls fall away toward the bay, then a beach slopes into the sea.
	var sd: float = sea_distance(x, z)
	h *= 1.0 - smoothstep(14.0, SHORE_S - 6.0, sd) * 0.92
	var sea_t: float = smoothstep(SHORE_S - 6.0, SHORE_S + 10.0, sd)
	h = lerpf(h + LAND_BASE, -6.0, sea_t)
	return h


## Signed distance toward the sea, with a wavy shoreline.
func sea_distance(x: float, z: float) -> float:
	return x * SEA_DIR.x + z * SEA_DIR.y + _noise.get_noise_2d(x * 1.7 + 300.0, z * 1.7) * 7.0


func _build_environment() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Flat ambient color driven by DayNight: cheaper than sky radiance with an animated sky.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.55
	environment.ambient_light_color = Color("dcdccf")
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
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
	environment.fog_density = 0.0012
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

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("c9d4f0")
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, environment, sky_material)


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
	terrain_material.set_shader_parameter("sand_height", 0.9)
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
			# Open the ring toward the sea so the bay has a horizon.
			var sea_ang: float = absf(angle_difference(ang, atan2(SEA_DIR.y, SEA_DIR.x)))
			h = lerpf(-30.0, h, smoothstep(0.35, 0.95, sea_ang))
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


func _crag_radius(ring: int, ang: float) -> float:
	var base: float = CRAG_PROFILE[ring].y
	var n: float = _noise.get_noise_2d(cos(ang) * 60.0 + ring * 3.0, sin(ang) * 60.0)
	var ridges: float = sin(ang * 7.0 + ring * 0.7) * 0.04 + sin(ang * 13.0) * 0.025
	return base * (1.0 + n * 0.22 + ridges)


## Faceted rock crag with grassy ledges: the cliff the Veilspire stands on.
## Flat-shaded triangles keep it crisp and stylized at any distance.
func _build_crag() -> void:
	var seg: int = 36
	var rings: int = CRAG_PROFILE.size()
	var pts: Array[PackedVector3Array] = []
	for k: int in rings:
		var row := PackedVector3Array()
		for i: int in seg:
			var ang: float = TAU * float(i) / seg
			var r: float = _crag_radius(k, ang)
			row.append(Vector3(cos(ang) * r, CRAG_PROFILE[k].x, sin(ang) * r))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	for k: int in rings - 1:
		for i: int in seg:
			var j: int = (i + 1) % seg
			var a: Vector3 = pts[k][i]
			var b: Vector3 = pts[k][j]
			var c: Vector3 = pts[k + 1][i]
			var d: Vector3 = pts[k + 1][j]
			for v: Vector3 in [a, b, c, b, d, c]:
				st.add_vertex(v)
	# Top cap (fan).
	var top: PackedVector3Array = pts[rings - 1]
	var centre := Vector3(0, CRAG_PROFILE[rings - 1].x + 0.2, 0)
	for i: int in seg:
		var j: int = (i + 1) % seg
		for v: Vector3 in [centre, top[i], top[j]]:
			st.add_vertex(v)
	st.generate_normals()  # Vertices are not shared, so normals are per-face (flat).
	var mesh: ArrayMesh = st.commit()

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("snow_height", 400.0)
	mat.set_shader_parameter("rock_slope", 0.55)
	mat.set_shader_parameter("strata_freq", 0.9)
	mat.set_shader_parameter("strata_amount", 0.35)
	mat.set_shader_parameter("rock_color", Color("6f7893"))
	mat.set_shader_parameter("rock_light", Color("c9c3b3"))

	var body := StaticBody3D.new()
	body.name = "Crag"
	body.collision_layer = 1 | SpirePath.WALKWAY_LAYER  # Plateau on top is walkable for the nav grid.
	body.position = Vector3(CLIFF_CENTER.x, 0.0, CLIFF_CENTER.y)
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)

	# Door into the Undercroft, at the foot of the crag on the valley side.
	var to_vale := Vector2(-CLIFF_CENTER.x, -CLIFF_CENTER.y).normalized()
	var door_ang: float = atan2(to_vale.y, to_vale.x)
	var door_r: float = _crag_radius(0, door_ang) * 0.93
	var door_pos := Vector3(CLIFF_CENTER.x + cos(door_ang) * door_r, 0, CLIFF_CENTER.y + sin(door_ang) * door_r)
	door_pos.y = height_at(door_pos.x, door_pos.z)
	var door_basis := Basis(Vector3.UP, atan2(to_vale.x, to_vale.y))
	var dk := MeshKit.new()
	var frame := Color("b9b3a3")
	for sx: float in [-1.7, 1.7]:
		dk.box(Transform3D(door_basis, door_pos + door_basis * Vector3(sx, 1.9, 0.0)), Vector3(0.8, 3.8, 1.2), frame)
	dk.box(Transform3D(door_basis, door_pos + door_basis * Vector3(0, 4.0, 0.0)), Vector3(4.6, 0.8, 1.3), frame)
	dk.box(Transform3D(door_basis, door_pos + door_basis * Vector3(0, 1.8, -0.35)), Vector3(2.6, 3.6, 0.4), Color("1e2125"))
	dk.box(Transform3D(door_basis, door_pos + door_basis * Vector3(0, 0.08, 1.2)), Vector3(4.0, 0.16, 2.0), frame)
	var dmi := MeshInstance3D.new()
	dmi.mesh = dk.commit()
	dmi.material_override = MeshKit.vertex_color_material(0.9)
	add_child(dmi)
	var rune := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(0.8, 0.8)
	rune.mesh = rq
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color("6ec3f0")
	rmat.albedo_texture = CombatFx.soft_dot()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rune.material_override = rmat
	rune.transform = Transform3D(door_basis, door_pos + door_basis * Vector3(0, 4.0, 0.7))
	add_child(rune)
	undercroft_door = Interactable.new()
	undercroft_door.display_name = "Undercroft of the Veilspire"
	add_child(undercroft_door)
	undercroft_door.global_position = door_pos + door_basis * Vector3(0, 0, 1.6)
	undercroft_door_outside = door_pos + door_basis * Vector3(0, 0.3, 3.5)

	# Beacon on top of the Veilspire: dark until the Keeper falls.
	beacon_light = OmniLight3D.new()
	beacon_light.light_color = Color("ffd08a")
	beacon_light.light_energy = 0.0
	beacon_light.omni_range = 30.0
	add_child(beacon_light)
	beacon_light.global_position = Vector3(CLIFF_CENTER.x, CRAG_TOP + 44.0, CLIFF_CENTER.y)

	# Fallen boulders around the foot of the crag.
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var rock_mat := _stone_mat(Color("8e94a6"), 0.95)
	for n: int in 16:
		var ang: float = rng.randf() * TAU
		var dist: float = _crag_radius(0, ang) + rng.randf_range(0.5, 5.0)
		var p := Vector3(cos(ang) * dist + CLIFF_CENTER.x, 0, sin(ang) * dist + CLIFF_CENTER.y)
		p.y = height_at(p.x, p.z)
		var rad: float = rng.randf_range(0.7, 2.2)
		var sm := SphereMesh.new()
		sm.radius = rad
		sm.height = rad * 1.5
		sm.radial_segments = 6
		sm.rings = 3
		var sh := SphereShape3D.new()
		sh.radius = rad * 0.7
		_add_static(self, sm, rock_mat, Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3(1.2, rng.randf_range(0.6, 1.0), 1.0)), p), sh)


## Watchtower on the cliff: the main landmark visible from the arena.
func _build_watchtower() -> void:
	var root := Node3D.new()
	root.name = "Watchtower"
	root.position = Vector3(CLIFF_CENTER.x, CRAG_TOP - 0.3, CLIFF_CENTER.y)
	add_child(root)
	var stone := _stone_mat(Color("e6e1d3"))
	var stone_dark := _stone_mat(Color("b9b3a3"))
	var roof := _stone_mat(Color("3d5ba9"), 0.55)
	var trim := _stone_mat(Color("5b6c9e"), 0.7)
	var base_shape := CylinderShape3D.new()
	base_shape.radius = 5.0
	base_shape.height = 4.0
	_add_static(root, _cyl(4.6, 5.4, 4.0, 24), stone_dark, Transform3D(Basis(), Vector3(0, 2.0, 0)), base_shape)
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
	_add_static(root, lintel, stone, Transform3D(basis, Vector3(mid.x, minf(height_at(a.x, a.z), height_at(b.x, b.z)) + 4.4, mid.z)))
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
	# Overlook: a stone stair up to a small platform. Steps are low enough to walk up (no jumping).
	var top := Vector3(17.5, 0, 14.5)
	var base_y: float = height_at(top.x, top.z)
	var plat_h: float = 2.8
	var psize := Vector3(4.6, plat_h + 2.0, 4.6)
	var pm := BoxMesh.new()
	pm.size = psize
	var ps := BoxShape3D.new()
	ps.size = psize
	_add_static(root, pm, stone, Transform3D(Basis(), Vector3(top.x, base_y + plat_h - psize.y * 0.5, top.z)), ps)
	var prim := BoxMesh.new()
	prim.size = Vector3(4.8, 0.16, 4.8)
	_add_static(root, prim, trim, Transform3D(Basis(), Vector3(top.x, base_y + plat_h - 0.07, top.z)))
	var d := Vector3(-0.707, 0, -0.707)
	var yaw: float = atan2(d.x, d.z)
	var n_steps: int = 8
	for i: int in n_steps:
		var rise: float = plat_h - (i + 1) * (plat_h / (n_steps + 1))
		var c: Vector3 = top + d * (2.3 + 0.45 + i * 0.9)
		var gy: float = height_at(c.x, c.z)
		var h: float = base_y + rise - gy + 1.0
		if h <= 1.05:
			break
		var sz := Vector3(2.4, h, 0.92)
		var bm := BoxMesh.new()
		bm.size = sz
		var sh := BoxShape3D.new()
		sh.size = sz
		_add_static(root, bm, stone, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, base_y + rise - h * 0.5, c.z)), sh)
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
	var parts: Dictionary = {"trunk": [], "crown": [], "cone_a": [], "cone_b": [], "cone_c": []}
	while placed < 70 and tries < 600:
		tries += 1
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(26.0, 105.0)
		var x: float = cos(ang) * dist
		var z: float = sin(ang) * dist
		if Vector2(x, z).distance_to(CLIFF_CENTER) < 25.0:
			continue
		if x > -22.0 and x < 10.0 and z < -8.0 and z > -28.0:
			continue  # Keep the ruins readable.
		var y: float = height_at(x, z)
		if y < 1.6 or sea_distance(x, z) > SHORE_S - 16.0:
			continue  # Keep beach and village clear.
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
		var txf: Transform3D = tree.transform
		parts["trunk"].append(txf * Transform3D(Basis(), Vector3(0, 1.5, 0)))
		if is_pine:
			parts["cone_a"].append(txf * Transform3D(Basis(), Vector3(0, 3.6, 0)))
			parts["cone_b"].append(txf * Transform3D(Basis(), Vector3(0, 5.2, 0)))
			parts["cone_c"].append(txf * Transform3D(Basis(), Vector3(0, 6.6, 0)))
		else:
			for off: Vector3 in [Vector3(0, 4.2, 0), Vector3(0.9, 3.6, 0.3), Vector3(-0.7, 3.8, -0.6)]:
				var cs2: float = 1.0 if off.x == 0.0 else 0.7
				parts["crown"].append(txf * Transform3D(Basis().scaled(Vector3.ONE * cs2), off))
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
	# One MultiMesh per part: the whole forest is five draw calls.
	var sets: Array = [["trunk", trunk, trunk_mat], ["crown", crown, leaf_round], ["cone_a", cone_a, leaf_pine], ["cone_b", cone_b, leaf_pine], ["cone_c", cone_c, leaf_pine]]
	for entry: Array in sets:
		var xfs: Array = parts[entry[0]]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry[1]
		mm.instance_count = xfs.size()
		for i: int in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Trees_" + str(entry[0])
		mmi.multimesh = mm
		mmi.material_override = entry[2]
		root.add_child(mmi)


func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b: int in 5:
		var ang: float = rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var h: float = rng.randf_range(0.22, 0.4)
		var w: float = 0.045
		var side := Vector3(cos(ang), 0, sin(ang)) * w
		var lean := Vector3(-sin(ang), 0, cos(ang)) * rng.randf_range(0.05, 0.15)
		var p0: Vector3 = off - side
		var p1: Vector3 = off + side
		var p2: Vector3 = off + lean * 0.5 - side * 0.6 + Vector3.UP * h * 0.55
		var p3: Vector3 = off + lean * 0.5 + side * 0.6 + Vector3.UP * h * 0.55
		var p4: Vector3 = off + lean + Vector3.UP * h
		for v: Vector3 in [p0, p1, p2, p1, p3, p2, p2, p3, p4]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


## Wind-swept grass tufts around the arena. One MultiMesh: a single draw call.
func _scatter_grass() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _grass_tuft_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var xforms: Array[Transform3D] = []
	var tries: int = 0
	while xforms.size() < 14000 and tries < 40000:
		tries += 1
		var r: float = sqrt(rng.randf()) * 62.0
		var a: float = rng.randf() * TAU
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		var y: float = height_at(x, z)
		if y < 0.9:
			continue  # No grass on the beach.
		var slope: float = absf(height_at(x + 1.0, z) - y) + absf(height_at(x, z + 1.0) - y)
		if slope > 0.9:
			continue
		# Thin out in patches so the ground keeps some rhythm.
		if _noise.get_noise_2d(x * 3.0, z * 3.0) < -0.15:
			continue
		var s: float = rng.randf_range(0.6, 1.15)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		xforms.append(Transform3D(basis, Vector3(x, y - 0.02, z)))
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grass.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Sea: a detailed wave grid over the bay plus a flat far plane to the horizon.
## Water depth per vertex (from the terrain) drives shallow color and shore foam without a depth texture.
func _build_water() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	var size: float = 220.0
	var cell: float = 2.0
	var n: int = int(size / cell)
	var center := Vector2(SEA_DIR.x, SEA_DIR.y) * (SHORE_S + 40.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in n + 1:
		for i: int in n + 1:
			var x: float = center.x - size * 0.5 + i * cell
			var z: float = center.y - size * 0.5 + j * cell
			var depth: float = WATER_LEVEL - height_at(x, z) if absf(x) < 120.0 and absf(z) < 120.0 else 8.0
			st.set_color(Color(clampf(depth / 6.0, 0.0, 1.0), 0, 0))
			st.add_vertex(Vector3(x, WATER_LEVEL, z))
	for j: int in n:
		for i: int in n:
			var a: int = j * (n + 1) + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + 1)
			st.add_index(a + n + 2)
			st.add_index(a + n + 1)
	var near := MeshInstance3D.new()
	near.name = "WaterNear"
	near.mesh = st.commit()
	near.material_override = mat
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(near)

	var far := MeshInstance3D.new()
	far.name = "WaterFar"
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	far.mesh = pm
	var far_mat: ShaderMaterial = mat.duplicate()
	far_mat.set_shader_parameter("flat_far", true)
	far.material_override = far_mat
	far.position = Vector3(0, WATER_LEVEL - 0.25, 0)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)


## Relit beacon: a bright star above the Veilspire's roof, visible from the whole vale.
func light_beacon() -> void:
	beacon_light.light_energy = 6.0
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.4
	sm.height = 2.8
	orb.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.9, 0.65)
	orb.material_override = m
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	orb.global_position = beacon_light.global_position
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(14, 14)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_color = Color(1.0, 0.82, 0.5, 0.8)
	hm.albedo_texture = CombatFx.soft_dot()
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	halo.global_position = beacon_light.global_position
