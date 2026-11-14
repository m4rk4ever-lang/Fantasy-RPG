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
## Worn paths (xz start, xz end), also kept free of trees, bushes and stones.
var path_segs: Array[Vector4] = []
## Tree trunk positions (xz), so bushes and stones keep their distance.
var tree_spots: Array[Vector2] = []
var _ground_spots: Array[Vector4] = []


## Register trodden earth around an object's foot (shown by the terrain shader).
func add_ground_spot(p: Vector3, radius: float, strength: float = 1.0) -> void:
	if _ground_spots.size() < 64:
		_ground_spots.append(Vector4(p.x, p.z, radius, strength))


func _apply_ground_spots() -> void:
	terrain_material.set_shader_parameter("ground_spots", _ground_spots)
	terrain_material.set_shader_parameter("spot_count", _ground_spots.size())


## Can vegetation or a stone stand here without clipping into the village, ruins, crag, stair,
## lookout, paths or a tree? (Owner: things must not stand inside each other, 14-11-2026.)
func is_clear(x: float, z: float, margin: float = 0.0, tree_gap: float = 0.0) -> bool:
	var p := Vector2(x, z)
	# Saltwick: everything seaward of the fence (s > 6) along the village front.
	var sd: float = x * SEA_DIR.x + z * SEA_DIR.y
	var td: float = -x * SEA_DIR.y + z * SEA_DIR.x
	if sd > 6.0 - margin and absf(td) < 34.0 + margin:
		return false
	if p.distance_to(CLIFF_CENTER) < 26.0 + margin:
		return false
	if x > -22.0 - margin and x < 10.0 + margin and z < -6.0 + margin and z > -28.0 - margin:
		return false  # Ruins.
	if p.length() < 9.0:
		return false  # Lookout platform and the arena centre.
	for sg: Vector4 in path_segs:
		var a := Vector2(sg.x, sg.y)
		var b := Vector2(sg.z, sg.w)
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < 2.6 + margin:
			return false
	if tree_gap > 0.0:
		for q: Vector2 in tree_spots:
			if q.distance_to(p) < tree_gap:
				return false
	return true


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
	# The old jump-test lookout stood in the middle of Saltwick's square; removed (14-11-2026).
	_scatter_trees()
	_scatter_undergrowth()
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
	_apply_ground_spots()


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
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	# Atmospheric perspective: distance fog tinted like the horizon sky.
	environment.fog_enabled = true
	environment.fog_light_color = Color("b6c4cf")
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.25
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.0
	environment.fog_height = 8.0
	environment.fog_height_density = 0.0015
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.95
	environment.adjustment_contrast = 1.08

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
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
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
	# Worn paths: Saltwick gate to the vale, on to the ruins and to the foot of the Veilspire's crag.
	var segs: Array[Vector4] = [
		Vector4(27.0, 21.0, 14.0, 10.0), Vector4(14.0, 10.0, 3.0, 2.0), Vector4(3.0, 2.0, -3.0, -12.0),
		Vector4(3.0, 2.0, 4.0, -30.0), Vector4(4.0, -30.0, 4.0, -52.0), Vector4(4.0, -52.0, 6.0, -60.0),
	]
	# Saltwick's lane (same points as Village.LANE / LANE_B, in s/t coordinates toward the sea).
	var sea := Vector2(SEA_DIR.x, SEA_DIR.y)
	var along := Vector2(-SEA_DIR.y, SEA_DIR.x)
	for lane: Array in [[Vector2(10.0, 1.0), Vector2(16.0, 3.0), Vector2(21.0, 0.5), Vector2(24.5, -5.5), Vector2(30.0, -4.0)], [Vector2(21.0, 0.5), Vector2(23.0, 9.0), Vector2(25.5, 18.0), Vector2(30.5, 24.0)]]:
		for i: int in lane.size() - 1:
			var a: Vector2 = sea * (lane[i] as Vector2).x + along * (lane[i] as Vector2).y
			var b: Vector2 = sea * (lane[i + 1] as Vector2).x + along * (lane[i + 1] as Vector2).y
			segs.append(Vector4(a.x, a.y, b.x, b.y))
	path_segs = segs
	terrain_material.set_shader_parameter("path_segs", segs)
	terrain_material.set_shader_parameter("path_count", segs.size())
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
	mat.set_shader_parameter("grass_color", Color("55702e"))
	mat.set_shader_parameter("grass_dark", Color("344c22"))
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
	st.index()  # Merge shared vertices: smooth, rounded rock instead of facets.
	st.generate_normals()
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
	add_ground_spot(undercroft_door_outside, 3.2, 0.9)

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
	var rock_mat: Material = ArmorKit.painted(Color("8a8984"), 0.1, false, 0.75, Vector3(0.9, 0.9, 0.9))
	var rocks: Array[ArrayMesh] = [Flora.boulder(11), Flora.boulder(23), Flora.boulder(37)]
	for n: int in 16:
		var ang: float = rng.randf() * TAU
		var dist: float = _crag_radius(0, ang) + rng.randf_range(0.5, 5.0)
		var p := Vector3(cos(ang) * dist + CLIFF_CENTER.x, 0, sin(ang) * dist + CLIFF_CENTER.y)
		p.y = height_at(p.x, p.z)
		var rad: float = rng.randf_range(0.7, 2.2)
		var sm := SphereMesh.new()
		sm.radius = rad
		sm.height = rad * 1.5
		sm.radial_segments = 14
		sm.rings = 7
		var sh := SphereShape3D.new()
		sh.radius = rad * 0.7
		add_ground_spot(p, rad * 1.7, 0.8)
		_add_static(self, rocks[n % 3], rock_mat, Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3(1.2, rng.randf_range(0.8, 1.1), 1.0) * rad), p), sh)


## Watchtower on the cliff: the main landmark visible from the arena.
func _build_watchtower() -> void:
	var root := Node3D.new()
	root.name = "Watchtower"
	root.position = Vector3(CLIFF_CENTER.x, CRAG_TOP - 0.3, CLIFF_CENTER.y)
	add_child(root)
	var stone: Material = MeshKit.architecture_material(0.4, Color("e6e1d3"), true)
	var stone_dark: Material = MeshKit.architecture_material(0.4, Color("b9b3a3"), true)
	var roof: Material = MeshKit.architecture_material(0.8, Color("4f5d7a"))
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
	var stone: Material = MeshKit.architecture_material(0.4, Color("cfc8b6"), true)
	var moss: Material = MeshKit.architecture_material(0.4, Color("6f8a4e"))
	var spots: Array[Vector3] = [Vector3(-16, 0, -12), Vector3(-10, 0, -19), Vector3(-3, 0, -22), Vector3(5, 0, -21)]
	var heights: Array[float] = [6.5, 4.0, 7.2, 2.4]
	for i: int in spots.size():
		var p: Vector3 = spots[i]
		p.y = height_at(p.x, p.z)
		var h: float = heights[i]
		add_ground_spot(p, 2.3, 0.9)
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, h, 1.4)
		# Round fluted column with a stepped base and capital (smooth, weathered), instead of a box.
		var shaft := _cyl(0.58, 0.66, h - 0.6, 20)
		_add_static(root, shaft, stone, Transform3D(Basis(Vector3.UP, i * 0.3), p + Vector3(0, h * 0.5, 0)), box)
		_add_static(root, _cyl(0.85, 0.92, 0.35, 20), stone, Transform3D(Basis(), p + Vector3(0, 0.17, 0)))
		_add_static(root, _cyl(0.74, 0.84, 0.2, 20), stone, Transform3D(Basis(), p + Vector3(0, 0.45, 0)))
		_add_static(root, _cyl(0.84, 0.66, 0.3, 20), stone, Transform3D(Basis(), p + Vector3(0, h - 0.15, 0)))
		var cap := BoxMesh.new()
		cap.size = Vector3(1.8, 0.4, 1.8)
		_add_static(root, cap, stone, Transform3D(Basis(Vector3.UP, i * 0.3), p + Vector3(0, h + 0.2, 0)))
		var moss_m := _cyl(0.95, 0.95, 0.1, 20)
		_add_static(root, moss_m, moss, Transform3D(Basis(Vector3.UP, i * 0.3), p + Vector3(0, h + 0.42, 0)))
	# A lintel across the first two pillars forms an arch.
	var lintel := BoxMesh.new()
	lintel.size = Vector3(1.4, 0.8, 9.0)
	var a: Vector3 = spots[0]
	var b: Vector3 = spots[1]
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = (b - a)
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z))
	_add_static(root, lintel, stone, Transform3D(basis, Vector3(mid.x, minf(height_at(a.x, a.z), height_at(b.x, b.z)) + 4.4, mid.z)))
	_build_ruin_story(root, stone)
	# Fallen blocks.
	for k: int in 6:
		var q := Vector3(-12.0 + k * 2.7, 0, -15.0 - (k % 3) * 2.0)
		q.y = height_at(q.x, q.z) + 0.35
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(1.2, 0.7, 0.9)
		var sh := BoxShape3D.new()
		sh.size = bm2.size
		_add_static(root, bm2, stone, Transform3D(Basis(Vector3(0.2, 1, 0.1).normalized(), k * 1.3), q), sh)


## The ruins tell what happened: a Warden statue toppled from its plinth (only the feet remain),
## its sword snapped beside it; ivy climbs the columns; a worn floor of flagstones; and a rune of the
## Veil still glows faintly in the floor where the Wardens once swore their oath.
func _build_ruin_story(root: Node3D, stone: Material) -> void:
	var worn_floor := Vector3(-8.0, 0, -17.0)
	add_ground_spot(worn_floor, 7.5, 0.5)
	var kit := MeshKit.new()
	var sc := Color(0.80, 0.78, 0.72, 0.4)
	# Broken flagstone floor: uneven slabs, some missing, some tilted.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1919
	for gx: int in range(-3, 4):
		for gz: int in range(-2, 3):
			if rng.randf() < 0.3:
				continue
			var q := worn_floor + Vector3(gx * 1.55 + rng.randf_range(-0.1, 0.1), 0, gz * 1.55 + rng.randf_range(-0.1, 0.1))
			q.y = height_at(q.x, q.z) + 0.04
			var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.07)).rotated(Vector3.UP, rng.randf_range(-0.08, 0.08))
			kit.box(Transform3D(tilt, q), Vector3(1.45, 0.18, 1.45), sc.darkened(rng.randf() * 0.12))
	# Plinth with the statue's feet still standing on it.
	var plinth := worn_floor + Vector3(2.5, 0, 3.2)
	plinth.y = height_at(plinth.x, plinth.z)
	kit.box(Transform3D(Basis(), plinth + Vector3(0, 0.5, 0)), Vector3(1.9, 1.0, 1.9), sc)
	kit.box(Transform3D(Basis(), plinth + Vector3(0, 1.08, 0)), Vector3(2.1, 0.16, 2.1), sc.lightened(0.05))
	for fx: float in [-0.3, 0.3]:
		kit.box(Transform3D(Basis(), plinth + Vector3(fx, 1.45, 0.05)), Vector3(0.36, 0.6, 0.62), sc)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.1, 2.0, 2.1)
	col.shape = bs
	var body := StaticBody3D.new()
	body.position = plinth + Vector3(0, 1.0, 0)
	body.add_child(col)
	root.add_child(body)
	# The toppled statue, lying in pieces on the grass (a Warden in plate, 3.6 m tall when standing).
	var lie := plinth + Vector3(-2.6, 0, 1.0)
	lie.y = height_at(lie.x, lie.z)
	var down := Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, 0.6)
	kit.loft(Transform3D(down, lie + Vector3(0, 0.55, 0)), [
		[-1.2, 0.42, 0.34, 0.0, sc], [-0.4, 0.48, 0.36, 0.0, sc], [0.4, 0.62, 0.44, 0.0, sc], [1.0, 0.58, 0.42, 0.0, sc], [1.15, 0.3, 0.26, 0.0, sc]], 10)
	kit.loft(Transform3D(down, lie + Vector3(0, 0.45, 0) + down * Vector3(0, 1.7, 0)), [
		[-0.2, 0.2, 0.22, 0.0, sc], [0.0, 0.27, 0.3, 0.0, sc], [0.35, 0.25, 0.28, 0.0, sc], [0.5, 0.12, 0.14, 0.0, sc]], 10)
	# The broken stone sword: blade in two pieces.
	kit.box(Transform3D(Basis(Vector3.UP, 1.2), lie + Vector3(1.4, 0.12, -1.2)), Vector3(0.18, 0.12, 1.6), sc.darkened(0.08))
	kit.box(Transform3D(Basis(Vector3.UP, 0.7), lie + Vector3(2.4, 0.1, -2.1)), Vector3(0.18, 0.1, 1.0), sc.darkened(0.08))
	kit.box(Transform3D(Basis(Vector3.UP, 1.2), lie + Vector3(0.75, 0.15, -0.8)), Vector3(0.7, 0.14, 0.16), sc)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = MeshKit.architecture_material()
	root.add_child(mi)
	# Ivy climbing two columns: clumps of small leaves hugging the stone.
	var ivy_mat: ShaderMaterial = leaf_material(Color("3f6a2a"), Color("102410"))
	ivy_mat.set_shader_parameter("sway_strength", 0.01)
	var ivy_mesh: ArrayMesh = leaf_crown_mesh(0.55, 0.7, 18, 77)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ivy_mesh
	var xs: Array[Transform3D] = []
	for c: Vector3 in [Vector3(-16, 0, -12), Vector3(-3, 0, -22)]:
		var base_y: float = height_at(c.x, c.z)
		for k: int in 9:
			var a: float = rng.randf() * TAU
			var y: float = base_y + rng.randf_range(0.3, 4.8) * (1.0 - k / 14.0)
			xs.append(Transform3D(Basis().scaled(Vector3(0.9, 1.2, 0.9)), Vector3(c.x + cos(a) * 0.62, y, c.z + sin(a) * 0.62)))
	mm.instance_count = xs.size()
	for i: int in xs.size():
		mm.set_instance_transform(i, xs[i])
	var ivy := MultiMeshInstance3D.new()
	ivy.multimesh = mm
	ivy.material_override = ivy_mat
	root.add_child(ivy)
	# The oath rune: a faint ring of Veil light in the floor, slowly pulsing.
	var rune := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.05
	tm.rings = 32
	tm.ring_segments = 4
	rune.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("6ec3f0")
	rune.material_override = rm
	rune.scale = Vector3(1.0, 0.05, 1.0)
	rune.position = Vector3(worn_floor.x, height_at(worn_floor.x, worn_floor.z) + 0.16, worn_floor.z)
	root.add_child(rune)
	var tw := rune.create_tween().set_loops()
	tw.tween_property(rm, "albedo_color", Color("2c5f80"), 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rm, "albedo_color", Color("6ec3f0"), 2.4).set_trans(Tween.TRANS_SINE)


## Steps and platforms to test jumping, plus a few rocks.
func _build_arena_props() -> void:
	var root := Node3D.new()
	root.name = "ArenaProps"
	add_child(root)
	var stone: Material = MeshKit.architecture_material(0.4, Color("d8d2c2"))
	var trim := _stone_mat(Color("5b6c9e"), 0.7)
	# Overlook: a stone stair up to a small platform. Steps are low enough to walk up (no jumping).
	var top := Vector3(17.5, 0, 14.5)
	add_ground_spot(top, 4.8, 0.7)
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
	var trunk_mat: Material = _stone_mat(Color("6b4a33"), 0.9)
	var leaf_round := ShaderMaterial.new()
	leaf_round.shader = preload("res://shaders/foliage.gdshader")
	leaf_round.set_shader_parameter("base_color", Color("3f9a59"))
	leaf_round.set_shader_parameter("tip_color", Color("7fcf6e"))
	var leaf_pine: ShaderMaterial = ShaderMaterial.new()
	leaf_pine.shader = preload("res://shaders/foliage.gdshader")
	leaf_pine.set_shader_parameter("base_color", Color("2a6b4a"))
	leaf_pine.set_shader_parameter("tip_color", Color("4a9a62"))
	leaf_pine.set_shader_parameter("sway_strength", 0.08)
	leaf_pine.set_shader_parameter("height_ref", 7.0)

	var ptrunk: ArrayMesh = Flora.pine_trunk()
	var pine: ArrayMesh = Flora.pine_canopy(8.2, 2.7, 10, 3)
	trunk_mat = ArmorKit.painted(Color("5a4636"), 0.05, false, 0.9, Vector3(3.0, 0.35, 3.0))
	leaf_pine = Flora.needle_material(Color("4f6e3c"), Color("112516"))
	leaf_round = leaf_material(Color("4d7a2a"), Color("112811"))

	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var placed: int = 0
	var tries: int = 0
	var parts: Dictionary = {"ptrunk": [], "pine": [], "oak0": [], "oak1": [], "oak2": []}
	var placed_at: Array[Vector2] = []
	while placed < 70 and tries < 2000:
		tries += 1
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(20.0, 105.0)
		var x: float = cos(ang) * dist
		var z: float = sin(ang) * dist
		# Groves, glades and the odd lone tree instead of an even sprinkle.
		var grove: float = _noise.get_noise_2d(x * 0.7 + 50.0, z * 0.7 - 20.0)
		if grove < 0.0 and rng.randf() > 0.12:
			continue
		if Vector2(x, z).distance_to(CLIFF_CENTER) < 25.0:
			continue
		if not is_clear(x, z, 1.5):
			continue  # Keep village, ruins, paths and the crag clear.
		var y: float = height_at(x, z)
		if y < 1.6 or sea_distance(x, z) > SHORE_S - 16.0:
			continue  # Keep beach and village clear.
		# Avoid steep slopes.
		var slope: float = absf(height_at(x + 1.5, z) - y) + absf(height_at(x, z + 1.5) - y)
		if slope > 2.0:
			continue
		var crowded: bool = false
		for q: Vector2 in placed_at:
			if q.distance_to(Vector2(x, z)) < 4.2:
				crowded = true
				break
		if crowded:
			continue
		placed_at.append(Vector2(x, z))
		tree_spots.append(Vector2(x, z))
		var tree := Node3D.new()
		tree.position = Vector3(x, y - 0.1, z)
		tree.rotation.y = rng.randf() * TAU
		var s: float = rng.randf_range(0.85, 1.35)
		tree.scale = Vector3.ONE * s
		root.add_child(tree)
		var is_pine: bool = y > 9.0 or rng.randf() < 0.35
		var txf: Transform3D = tree.transform
		if is_pine:
			parts["ptrunk"].append(txf)
			parts["pine"].append(txf)
		else:
			parts["oak%d" % (placed % 3)].append(txf)
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
	var sets: Array = [["ptrunk", ptrunk, trunk_mat], ["pine", pine, leaf_pine]]
	for v: int in 3:
		var oak: Array = Flora.broadleaf(700 + v * 13)
		sets.append(["oak%d" % v, oak[0], trunk_mat])
		sets.append(["oak%d" % v, oak[1], leaf_round])
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


## Bushes and small stones: fill the space between trees, ruins and paths so the vale feels lived-in.
func _scatter_undergrowth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var bush_x: Array = []
	var stone_x: Array = []
	var tries: int = 0
	while (bush_x.size() < 160 or stone_x.size() < 70) and tries < 4000:
		tries += 1
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(14.0, 100.0)
		var x: float = cos(ang) * dist
		var z: float = sin(ang) * dist
		if not is_clear(x, z, 0.5, 2.6):
			continue
		var y: float = height_at(x, z)
		if y < 1.6 or sea_distance(x, z) > SHORE_S - 16.0:
			continue
		var slope: float = absf(height_at(x + 1.0, z) - y) + absf(height_at(x, z + 1.0) - y)
		if slope > 1.4:
			continue
		var close: bool = false
		for t2: Transform3D in bush_x + stone_x:
			if Vector2(t2.origin.x, t2.origin.z).distance_to(Vector2(x, z)) < 1.8:
				close = true
				break
		if close:
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(x, y - 0.05, z))
		if bush_x.size() < 160 and rng.randf() < 0.7:
			bush_x.append(xf)
		elif stone_x.size() < 70:
			stone_x.append(Transform3D(xf.basis.scaled(Vector3.ONE * rng.randf_range(0.25, 0.55)), xf.origin))
	var bush_mat: ShaderMaterial = leaf_material(Color("4f7530"), Color("132813"))
	bush_mat.set_shader_parameter("sway_strength", 0.04)
	var sets: Array = [[leaf_crown_mesh(0.95, 0.7, 26, 41), bush_mat, bush_x, Vector3(0, 0.55, 0)],
		[Flora.boulder(53, 10), ArmorKit.painted(Color("85837d"), 0.1, false, 0.75, Vector3(1.6, 1.6, 1.6)), stone_x, Vector3(0, 0.1, 0)]]
	for e: Array in sets:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e[0]
		var xs: Array = e[2]
		mm.instance_count = xs.size()
		for i: int in xs.size():
			var t: Transform3D = xs[i]
			mm.set_instance_transform(i, Transform3D(t.basis, t.origin + t.basis * (e[3] as Vector3)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = e[1]
		mmi.visibility_range_end = 90.0
		add_child(mmi)
	# Solid: the hero, Hollowed and click-to-move paths go around bushes and stones.
	var body := StaticBody3D.new()
	body.name = "Undergrowth"
	body.collision_layer = 1
	add_child(body)
	for t3: Transform3D in bush_x:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.75 * t3.basis.get_scale().x
		cs.shape = sh
		cs.position = t3.origin + Vector3(0, 0.45, 0)
		body.add_child(cs)
	for t4: Transform3D in stone_x:
		var cs2 := CollisionShape3D.new()
		var sh2 := SphereShape3D.new()
		sh2.radius = 0.85 * t4.basis.get_scale().x
		cs2.shape = sh2
		cs2.position = t4.origin + Vector3(0, 0.1, 0)
		body.add_child(cs2)


static var _leaf_tex: ImageTexture


## A card texture with a clump of leaves (white, alpha-cut). Generated once.
static func leaf_texture() -> ImageTexture:
	if _leaf_tex:
		return _leaf_tex
	var n: int = 128
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k: int in 22:
		var c := Vector2(rng.randf_range(22, 106), rng.randf_range(22, 106))
		var ang: float = rng.randf() * TAU
		var ax := Vector2(cos(ang), sin(ang))
		var ay := Vector2(-ax.y, ax.x)
		var ln: float = rng.randf_range(13, 20)
		var wd: float = ln * 0.45
		var tone: float = rng.randf_range(0.55, 1.0)
		for y: int in range(int(c.y - ln), int(c.y + ln) + 1):
			for x: int in range(int(c.x - ln), int(c.x + ln) + 1):
				if x < 0 or y < 0 or x >= n or y >= n:
					continue
				var d := Vector2(x, y) - c
				var u: float = d.dot(ax) / ln
				var v: float = d.dot(ay) / (wd * (1.0 - absf(u) * 0.6))
				if u * u + v * v <= 1.0:
					var vein: float = 1.0 - 0.25 * exp(-v * v * 30.0)
					img.set_pixel(x, y, Color(tone * vein, tone * vein, tone * vein, 1.0))
	img.generate_mipmaps()
	_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


static func leaf_material(light: Color, dark: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/leaf_cards.gdshader")
	m.set_shader_parameter("leaf_tex", leaf_texture())
	m.set_shader_parameter("light_color", light)
	m.set_shader_parameter("dark_color", dark)
	return m


## A crown of leaf cards inside an ellipsoid. Normals point out from the centre (soft volume shading),
## vertex colour red = how sunlit the card sits (top and outside bright, inside dark).
static func leaf_crown_mesh(radius: float, height_radius: float, cards: int, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i: int in cards:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.8, 1), rng.randf_range(-1, 1)).normalized()
		var depth: float = pow(rng.randf(), 0.5)
		var p := Vector3(dir.x * radius, dir.y * height_radius, dir.z * radius) * (0.35 + 0.65 * depth)
		var size: float = rng.randf_range(1.4, 2.0)
		var nrm: Vector3 = Vector3(p.x / radius, p.y / height_radius, p.z / radius).normalized()
		var tangent: Vector3 = nrm.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()).normalized()
		if tangent.length_squared() < 0.01:
			tangent = Vector3.RIGHT
		var bit: Vector3 = nrm.cross(tangent).normalized()
		var sun: float = clampf(0.25 + 0.5 * depth + 0.35 * nrm.y, 0.0, 1.0)
		var corners: Array[Vector3] = [p + (-tangent - bit) * size * 0.5, p + (tangent - bit) * size * 0.5, p + (tangent + bit) * size * 0.5, p + (-tangent + bit) * size * 0.5]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(sun, 0, 0))
			st.set_uv(uvs[k])
			st.set_normal(Vector3(corners[k].x / radius, corners[k].y / height_radius, corners[k].z / radius).normalized())
			st.add_vertex(corners[k])
	return st.commit()


func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Many thin blades instead of a few broad ones: reads as real grass, not paper leaves.
	for b: int in 11:
		var ang: float = rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14))
		var h: float = rng.randf_range(0.2, 0.42)
		var w: float = 0.016
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
	while xforms.size() < 9000 and tries < 30000:
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
