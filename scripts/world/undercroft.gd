class_name Undercroft
extends Node3D
## The Undercroft of the Veilspire: the first small dungeon (end of Chapter I).
## Dark and grim (SMAAK.md dungeon palette): night grey stone, earth, torches in fire color.
## Built far away from the overworld; entering teleports the hero and switches the lighting.

signal boss_defeated
signal beacon_lit

const ORIGIN := Vector3(400.0, -200.0, 0.0)
const COL_STONE := Color("353a42")
const COL_STONE_LIGHT := Color("4a4f58")
const COL_EARTH := Color("4a483e")
const COL_DARK := Color("1e2125")
const COL_MOON := Color("c9c6b8")
const COL_FIRE := Color("d9552e")
const WALL_H: float = 6.0

var entrance_point: Vector3
var exit_portal: Interactable
var brazier: Interactable
var boss: Hollow
var _kit := MeshKit.new()
var _glow := MeshKit.new()
var _lights: Array[OmniLight3D] = []
var _flames: Array[Node3D] = []
var _time: float = 0.0
var _beacon_flame: Node3D


func build() -> void:
	entrance_point = ORIGIN + Vector3(0, 0.2, 3.5)
	# Entry hall, corridor, Hall of Wardens, corridor, Beacon Chamber (north = -Z).
	_room(Vector3(0, 0, 0), Vector2(14, 14), {"n": true})
	_corridor(Vector3(0, 0, -17), 20.0)
	_room(Vector3(0, 0, -36), Vector2(18, 18), {"n": true, "s": true})
	_corridor(Vector3(0, 0, -55), 20.0)
	_room(Vector3(0, 0, -77), Vector2(24, 24), {"s": true})
	# Pillars in the Hall of Wardens and broken statues.
	for px: float in [-5.0, 5.0]:
		for pz: float in [-31.0, -41.0]:
			_pillar(Vector3(px, 0, pz))
	for px2: float in [-8.0, 8.0]:
		for pz2: float in [-70.0, -84.0]:
			_pillar(Vector3(px2, 0, pz2))
	# Rubble and bones.
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	for i: int in 26:
		var p := Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-88.0, -2.0))
		var sz: float = rng.randf_range(0.25, 0.7)
		_kit.box(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf() * 0.3), ORIGIN + p + Vector3(0, sz * 0.4, 0)), Vector3(sz, sz * 0.8, sz * 1.2), COL_STONE_LIGHT if i % 3 else COL_EARTH)
	# Torches along the walls: emissive flames, a few real lights.
	var torch_spots: Array[Vector3] = [Vector3(-6.6, 3, -2), Vector3(6.6, 3, -2), Vector3(-2.6, 3, -17), Vector3(2.6, 3, -22),
		Vector3(-8.6, 3, -36), Vector3(8.6, 3, -36), Vector3(-2.6, 3, -55), Vector3(-11.6, 3, -72), Vector3(11.6, 3, -72), Vector3(-11.6, 3, -84), Vector3(11.6, 3, -84)]
	for t: int in torch_spots.size():
		_torch(torch_spots[t], t % 2 == 0 or t >= 7)
	# The great beacon brazier at the back of the chamber (unlit until the Keeper falls).
	var bpos := Vector3(0, 0, -86)
	_kit.cylinder(Transform3D(Basis(), ORIGIN + bpos + Vector3(0, 0.5, 0)), 1.6, 1.9, 1.0, 10, COL_STONE_LIGHT)
	_kit.cylinder(Transform3D(Basis(), ORIGIN + bpos + Vector3(0, 1.25, 0)), 1.3, 1.0, 0.5, 10, COL_DARK)
	_kit.cylinder(Transform3D(Basis(), ORIGIN + bpos + Vector3(0, 1.6, 0)), 1.6, 1.4, 0.25, 10, Color("d9a441"))
	_collider(ORIGIN + bpos + Vector3(0, 0.9, 0), Vector3(3.2, 1.8, 3.2))
	brazier = Interactable.new()
	brazier.display_name = ""
	brazier.enabled = false
	add_child(brazier)
	brazier.global_position = ORIGIN + bpos + Vector3(0, 0, 2.2)
	_beacon_flame = _flame(ORIGIN + bpos + Vector3(0, 2.2, 0), 3.0)
	_beacon_flame.visible = false

	# Exit portal in the entry hall: a pale archway.
	var ex := Vector3(0, 0, 6.2)
	for sx: float in [-1.6, 1.6]:
		_kit.box(Transform3D(Basis(), ORIGIN + ex + Vector3(sx, 1.8, 0)), Vector3(0.6, 3.6, 0.6), COL_STONE_LIGHT)
	_kit.box(Transform3D(Basis(), ORIGIN + ex + Vector3(0, 3.8, 0)), Vector3(4.0, 0.6, 0.7), COL_STONE_LIGHT)
	_glow.box(Transform3D(Basis(), ORIGIN + ex + Vector3(0, 1.75, 0.1)), Vector3(2.6, 3.5, 0.1), COL_MOON)
	exit_portal = Interactable.new()
	exit_portal.display_name = "Way out"
	add_child(exit_portal)
	exit_portal.global_position = ORIGIN + ex + Vector3(0, 0, -1.2)

	var mi := MeshInstance3D.new()
	mi.mesh = _kit.commit()
	mi.material_override = MeshKit.vertex_color_material(0.95)
	add_child(mi)
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.emission_enabled = true
	gm.emission = Color(1, 1, 1)
	gm.emission_energy_multiplier = 1.2
	var gmi := MeshInstance3D.new()
	gmi.mesh = _glow.commit()
	gmi.material_override = gm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)


func _collider(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


## Room centered at `c` (local), size (x, z). `doors` opens 6 m gaps: n/s.
func _room(c: Vector3, size: Vector2, doors: Dictionary) -> void:
	var hw: float = size.x * 0.5
	var hd: float = size.y * 0.5
	var base: Vector3 = ORIGIN + c
	# Floor with a slight tile pattern.
	_collider(base + Vector3(0, -0.5, 0), Vector3(size.x + 2, 1.0, size.y + 2))
	# Solid slab under the tiles so the grout never shows the void below.
	_kit.box(Transform3D(Basis(), base + Vector3(0, -0.35, 0)), Vector3(size.x + 2, 0.6, size.y + 2), COL_DARK)
	var tiles: int = int(size.x / 2.0)
	var rows: int = int(size.y / 2.0)
	for i: int in tiles:
		for j: int in rows:
			var tp: Vector3 = base + Vector3(-hw + 1.0 + i * 2.0, -0.05, -hd + 1.0 + j * 2.0)
			_kit.box(Transform3D(Basis(), tp), Vector3(1.94, 0.1, 1.94), COL_STONE if (i + j) % 2 == 0 else COL_STONE.darkened(0.12))
	# Ceiling (blocks the sun, keeps it dark).
	_kit.box(Transform3D(Basis(), base + Vector3(0, WALL_H + 0.4, 0)), Vector3(size.x + 2, 0.8, size.y + 2), COL_DARK)
	# Walls: east/west solid, north/south with an optional doorway.
	for sx: float in [-1.0, 1.0]:
		_wall(base + Vector3(sx * (hw + 0.5), 0, 0), Vector3(1.0, WALL_H, size.y + 2))
	for side: String in ["n", "s"]:
		var z: float = -hd - 0.5 if side == "n" else hd + 0.5
		if doors.get(side, false):
			var seg: float = (size.x - 6.0) * 0.5
			for sx2: float in [-1.0, 1.0]:
				_wall(base + Vector3(sx2 * (3.0 + seg * 0.5), 0, z), Vector3(seg, WALL_H, 1.0))
			_kit.box(Transform3D(Basis(), base + Vector3(0, WALL_H - 0.6, z)), Vector3(6.0, 1.2, 1.0), COL_STONE_LIGHT)
		else:
			_wall(base + Vector3(0, 0, z), Vector3(size.x + 2, WALL_H, 1.0))


func _corridor(c: Vector3, length: float) -> void:
	var base: Vector3 = ORIGIN + c
	_collider(base + Vector3(0, -0.5, 0), Vector3(8, 1.0, length))
	_kit.box(Transform3D(Basis(), base + Vector3(0, -0.35, 0)), Vector3(8, 0.6, length), COL_DARK)
	for k: int in int(length / 2.0):
		_kit.box(Transform3D(Basis(), base + Vector3(0, -0.05, -length * 0.5 + 1.0 + k * 2.0)), Vector3(5.9, 0.1, 1.94), COL_EARTH if k % 2 else COL_STONE)
	_kit.box(Transform3D(Basis(), base + Vector3(0, WALL_H + 0.4, 0)), Vector3(8, 0.8, length), COL_DARK)
	for sx: float in [-1.0, 1.0]:
		_wall(base + Vector3(sx * 3.5, 0, 0), Vector3(1.0, WALL_H, length))
	# Arches every few meters.
	var z: float = -length * 0.5 + 3.0
	while z < length * 0.5:
		for sx2: float in [-1.0, 1.0]:
			_kit.box(Transform3D(Basis(), base + Vector3(sx2 * 2.85, WALL_H * 0.5, z)), Vector3(0.5, WALL_H, 0.6), COL_STONE_LIGHT)
		_kit.box(Transform3D(Basis(), base + Vector3(0, WALL_H - 0.3, z)), Vector3(6.0, 0.6, 0.6), COL_STONE_LIGHT)
		z += 5.0


func _wall(center_floor: Vector3, size: Vector3) -> void:
	var c: Vector3 = center_floor + Vector3(0, size.y * 0.5, 0)
	_kit.box(Transform3D(Basis(), c), size, COL_STONE)
	# A darker plinth and an earth band give the stone some weight.
	_kit.box(Transform3D(Basis(), center_floor + Vector3(0, 0.3, 0)), size * Vector3(1.04, 0, 1.04) + Vector3(0, 0.6, 0), COL_EARTH)
	_collider(c, size)


func _pillar(p: Vector3) -> void:
	var base: Vector3 = ORIGIN + p
	_kit.box(Transform3D(Basis(), base + Vector3(0, 0.3, 0)), Vector3(1.6, 0.6, 1.6), COL_STONE_LIGHT)
	_kit.cylinder(Transform3D(Basis(), base + Vector3(0, WALL_H * 0.5, 0)), 0.55, 0.6, WALL_H, 8, COL_STONE)
	_kit.box(Transform3D(Basis(), base + Vector3(0, WALL_H - 0.3, 0)), Vector3(1.5, 0.6, 1.5), COL_STONE_LIGHT)
	_collider(base + Vector3(0, WALL_H * 0.5, 0), Vector3(1.3, WALL_H, 1.3))


func _torch(p: Vector3, with_light: bool) -> void:
	var w: Vector3 = ORIGIN + p
	var inward: float = -signf(p.x) if absf(p.x) > 1.0 else 0.0
	_kit.box(Transform3D(Basis(), w + Vector3(inward * 0.15, -0.3, 0)), Vector3(0.12, 0.6, 0.12), COL_EARTH)
	_kit.box(Transform3D(Basis(), w + Vector3(inward * 0.15, 0.05, 0)), Vector3(0.22, 0.12, 0.22), Color("8e8a7e"))
	_flames.append(_flame(w + Vector3(inward * 0.15, 0.3, 0), 0.45))
	if with_light and _lights.size() < 8:
		var l := OmniLight3D.new()
		l.light_color = Color("ff9a55")
		l.light_energy = 3.0
		l.omni_range = 14.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		add_child(l)
		l.global_position = w + Vector3(inward * 0.8, 0.4, 0)
		_lights.append(l)


func _flame(at: Vector3, size: float) -> Node3D:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.25
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.6 * size + 0.3
	p.initial_velocity_max = 1.2 * size + 0.5
	p.gravity = Vector3(0, 1.0, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	grad.add_point(0.4, Color(0.85, 0.33, 0.18, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(0.3, 0.1, 0.05, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = CombatFx.soft_dot()
	q.material = m
	p.mesh = q
	add_child(p)
	p.global_position = at
	return p


## Spawns the Hollowed and the Keeper. Returns the list (the game root wires loot and XP).
func spawn_enemies(hero: Node3D) -> Array[Hollow]:
	var out: Array[Hollow] = []
	var spots: Array[Vector3] = [Vector3(-4, 0, -34), Vector3(4, 0, -38), Vector3(0, 0, -42), Vector3(0, 0, -58)]
	for s: Vector3 in spots:
		var h := Hollow.new()
		h.level = 3
		h.max_health = 80.0
		h.attack_damage = 12.0
		h.aggro_range = 11.0
		h.leash_range = 14.0
		add_child(h)
		h.global_position = ORIGIN + s + Vector3(0, 0.3, 0)
		h.home = h.global_position
		h.target = hero
		out.append(h)
	boss = Hollow.new()
	boss.display_name = "Aldric, the Lightless Keeper"
	boss.level = 5
	boss.max_health = 420.0
	boss.attack_damage = 22.0
	boss.attack_range = 2.8
	boss.windup_time = 0.85
	boss.move_speed = 3.6
	boss.aggro_range = 13.0
	boss.leash_range = 30.0
	boss.is_boss = true
	boss.stagger_every = 4
	add_child(boss)
	(boss.get_node("Model") as Node3D).scale = Vector3.ONE * 1.6
	boss.global_position = ORIGIN + Vector3(0, 0.3, -80)
	boss.home = boss.global_position
	boss.target = hero
	boss.died.connect(func(_b: Hollow) -> void:
		brazier.enabled = true
		brazier.set_label("Relight the beacon")
		boss_defeated.emit())
	out.append(boss)
	# A cold, pale light over the Keeper: the "lightless" glow of the Veil, so he reads in the dark.
	var cold := OmniLight3D.new()
	cold.light_color = Color("c9c6b8")
	cold.light_energy = 1.6
	cold.omni_range = 16.0
	add_child(cold)
	cold.global_position = ORIGIN + Vector3(0, 4.5, -78)
	return out


func light_beacon() -> void:
	_beacon_flame.visible = true
	brazier.enabled = false
	brazier.set_label("")
	var l := OmniLight3D.new()
	l.light_color = Color("ffd08a")
	l.light_energy = 4.0
	l.omni_range = 22.0
	add_child(l)
	l.global_position = ORIGIN + Vector3(0, 3.5, -86)
	beacon_lit.emit()


func _process(delta: float) -> void:
	_time += delta
	# Only the three torches nearest the camera cast real light: the Compatibility renderer draws an
	# extra pass per light per mesh, and Safari's WebGL gave up with all of them on (owner, 13-11-2026).
	var cam: Camera3D = get_viewport().get_camera_3d()
	var ref: Vector3 = cam.global_position if cam else ORIGIN
	var order: Array = range(_lights.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _lights[a].global_position.distance_squared_to(ref) < _lights[b].global_position.distance_squared_to(ref))
	for k: int in order.size():
		var i: int = order[k]
		_lights[i].visible = k < 3
		_lights[i].light_energy = 2.8 + sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i) * 0.12
