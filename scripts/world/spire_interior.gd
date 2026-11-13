class_name SpireInterior
extends Node3D
## First floor of the Veilspire: the first small dungeon (roadmap V.6b). Dark and grim.
## The hall is built far below the overworld in the same scene, so entering is a fade and a teleport,
## not a scene switch. While the hero is inside, the shared Environment is swapped to a dungeon look
## and the day/night cycle is paused; both are restored on the way out.
## Encounter: three Hollowed and the mini-boss Warden-Husk Corvane.

signal entered
signal exited
signal enemy_died(enemy: Hollow, is_boss: bool)
signal boss_slammed(pos: Vector3)
signal floor_cleared

## World position of the hall's floor centre: straight below the crag, far under the terrain.
const ORIGIN := Vector3(18.0, -200.0, -78.0)
const RADIUS: float = 11.0
const WALL_H: float = 15.0
const SEGS: int = 24
const CLEARED_FLAG := "spire_floor_1_cleared"

# SMAAK.md dungeon palette.
const COL_NIGHT := Color("353a42")
const COL_EARTH := Color("4a483e")
const COL_SILHOUETTE := Color("1e2125")
const COL_MOON := Color("c9c6b8")
const COL_FIRE := Color("d9552e")
const COL_IRON := Color("23262b")
const COL_RUNE := Color("6ec3f0")

const ENV_INSIDE: Dictionary = {
	"background_mode": Environment.BG_COLOR,
	"background_color": Color("090a0d"),
	"ambient_light_color": Color("5d6a88"),
	"ambient_light_energy": 0.8,
	"fog_light_color": Color("15181d"),
	"fog_light_energy": 1.0,
	"fog_density": 0.028,
	"fog_height_density": 0.0,
	"fog_sun_scatter": 0.0,
	"adjustment_saturation": 0.95,
	"glow_intensity": 0.75,
}

var player: Player
var arena: TestArena
var camera_rig: CameraRig
var is_inside: bool = false
## Seconds for each half of the fade. 0 = instant (tests).
var fade_time: float = 0.45
var boss: WardenHusk
var enemies: Array[Hollow] = []

var _busy: bool = false
var _rng := RandomNumberGenerator.new()
var _env_saved: Dictionary = {}
var _day_was_running: bool = true
var _saved_nav: NavGrid
var _fade: ColorRect
var _fire_lights: Array[OmniLight3D] = []
var _fire_base: Array[float] = []
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _motes: CPUParticles3D
var _flames: Array[CPUParticles3D] = []
var _entry: Area3D
var _door_dir := Vector3.FORWARD


func setup(p_player: Player, p_arena: TestArena, p_camera: CameraRig) -> void:
	player = p_player
	arena = p_arena
	camera_rig = p_camera
	position = ORIGIN
	_rng.seed = 4711
	_noise.frequency = 0.9
	_build_shell()
	_build_props()
	_build_lights()
	_build_motes()
	_build_exit()
	_build_entry_trigger()
	_build_fade()
	_set_active(false)
	player.died.connect(_on_player_died)


func is_cleared() -> bool:
	return player.quests.has_flag(CLEARED_FLAG)


## The door opens for a Warden who has climbed the stair on the quest "The Dark Spire".
func can_enter() -> bool:
	return player.quests.state("the_dark_spire") != "none" and player.quests.has_flag("reached_spire")


## Where the hero stands after stepping inside (world space).
func entry_point() -> Vector3:
	return ORIGIN + Vector3(0.0, 0.15, 7.4)


## Where the hero stands after leaving: in front of the sealed door on the crag (world space).
func exit_point() -> Vector3:
	var d: Vector3 = arena.spire_path.door_position
	return Vector3(d.x, TestArena.CRAG_TOP + 0.4, d.z) + _door_dir * 3.8


# --- Entering and leaving ---

func request_enter() -> void:
	if _busy or is_inside or not can_enter():
		return
	player.quests.set_flag("spire_door_opened")
	_flare_runes()
	_transition(_do_enter, 0.4)


func request_exit() -> void:
	if _busy or not is_inside:
		return
	_transition(_do_exit, 0.0)


func _transition(switch: Callable, lead: float) -> void:
	if fade_time <= 0.0:
		switch.call()
		return
	_busy = true
	var tw := create_tween()
	if lead > 0.0:
		tw.tween_interval(lead)
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(switch)
	tw.tween_interval(0.25)
	tw.tween_property(_fade, "color:a", 0.0, fade_time * 1.6)
	tw.tween_callback(func() -> void: _busy = false)


func _do_enter() -> void:
	is_inside = true
	_set_active(true)
	_apply_environment(true)
	_saved_nav = player.nav
	player.nav = null  # The nav grid only covers the overworld: inside, click orders walk straight.
	_place_player(entry_point(), Vector3(0, 0, -1))
	if camera_rig != null:
		camera_rig.set_angles(0.0, deg_to_rad(-14.0))
	_spawn_encounter()
	player.quests.set_flag("entered_spire")
	entered.emit()


func _do_exit() -> void:
	_leave_state()
	_place_player(exit_point(), _door_dir)
	if camera_rig != null:
		camera_rig.set_angles(atan2(_door_dir.x, _door_dir.z), deg_to_rad(-20.0))
	exited.emit()


## Restores the overworld look and removes the encounter (it resets on the next visit).
func _leave_state() -> void:
	if not is_inside:
		return
	is_inside = false
	_apply_environment(false)
	_clear_encounter()
	_set_active(false)
	if _saved_nav != null:
		player.nav = _saved_nav


func _place_player(at: Vector3, facing: Vector3) -> void:
	player.clear_orders()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.face_direction(facing)
	if camera_rig != null:
		camera_rig.global_position = at + Vector3.UP * camera_rig.height_offset


## Falling inside: main revives the hero in the vale after 1.5 s. Fade out and restore the world.
func _on_player_died() -> void:
	if not is_inside:
		return
	if fade_time <= 0.0:
		_leave_state()
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.2)
	tw.tween_interval(0.4)
	tw.tween_callback(_leave_state)
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: _busy = false)


func _set_active(on: bool) -> void:
	visible = on
	set_process(on)
	_motes.emitting = on
	for f: CPUParticles3D in _flames:
		f.emitting = on


func _apply_environment(inside: bool) -> void:
	var env: Environment = arena.environment
	var dn: DayNight = arena.day_night
	if inside:
		_env_saved.clear()
		for k: String in ENV_INSIDE.keys():
			_env_saved[k] = env.get(k)
			env.set(k, ENV_INSIDE[k])
		_day_was_running = dn.running
		dn.running = false
		arena.sun.visible = false
		arena.moon.visible = false
	else:
		for k: String in _env_saved.keys():
			env.set(k, _env_saved[k])
		_env_saved.clear()
		dn.running = _day_was_running
		dn.apply()


## The Veil runes on the sealed door flare before the hero is let through.
func _flare_runes() -> void:
	var glow: MeshInstance3D = arena.spire_path.get_node_or_null("RuneGlow") as MeshInstance3D
	if glow == null or not (glow.material_override is StandardMaterial3D):
		return
	var gm: StandardMaterial3D = glow.material_override
	var base: float = gm.emission_energy_multiplier
	var tw := create_tween()
	tw.tween_property(gm, "emission_energy_multiplier", 9.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(gm, "emission_energy_multiplier", base, 1.2)


## After a save is loaded: a save made inside resumes in front of the sealed door (the encounter
## resets anyway), and a load while inside puts the overworld back.
func handle_game_loaded() -> void:
	var saved_inside: bool = player.global_position.y < ORIGIN.y + 60.0
	_leave_state()
	if saved_inside:
		_place_player(exit_point(), _door_dir)


# --- Encounter ---

func _spawn_encounter() -> void:
	_clear_encounter()
	if is_cleared():
		return
	var spots: Array = [[Vector3(-4.6, 0.2, 1.2), 3], [Vector3(4.8, 0.2, 0.2), 3], [Vector3(1.6, 0.2, -3.2), 4]]
	for i: int in spots.size():
		var lvl: int = spots[i][1]
		var e := Hollow.new()
		e.name = "SpireHollow%d" % i
		e.level = lvl
		e.max_health = 60.0 + 18.0 * (lvl - 2)
		e.attack_damage = 14.0 + 2.0 * (lvl - 2)
		e.aggro_range = 7.0
		e.leash_range = 26.0
		add_child(e)
		e.position = spots[i][0]
		e.home = e.global_position
		e.target = player
		e.died.connect(func(en: Hollow) -> void: _on_enemy_died(en, false))
		enemies.append(e)
	boss = WardenHusk.new()
	boss.name = "WardenHusk"
	add_child(boss)
	boss.position = Vector3(0.0, 0.2, -6.0)
	boss.home = boss.global_position
	boss.target = player
	boss._facing = 0.0  # Faces the door.
	boss.died.connect(func(en: Hollow) -> void: _on_enemy_died(en, true))
	boss.slammed.connect(func(pos: Vector3) -> void: boss_slammed.emit(pos))
	enemies.append(boss)


func _clear_encounter() -> void:
	for e: Hollow in enemies:
		if is_instance_valid(e) and not e.is_dead():
			e.queue_free()
	enemies.clear()
	boss = null


func _on_enemy_died(en: Hollow, is_boss: bool) -> void:
	enemy_died.emit(en, is_boss)
	if is_boss:
		player.quests.set_flag(CLEARED_FLAG)
		floor_cleared.emit()


# --- Geometry ---

## Point on a circle of radius `r` at angle `a`. a = 0 is the door (+Z), a = PI the back wall.
func _polar(a: float, r: float, y: float = 0.0) -> Vector3:
	return Vector3(sin(a) * r, y, cos(a) * r)


## Transform at a polar position whose local +Z points outward (toward the wall).
func _polar_xf(a: float, r: float, y: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, a), _polar(a, r, y))


func _jit(c: Color, amt: float) -> Color:
	var f: float = _rng.randf_range(-amt, amt)
	return c.lightened(f) if f > 0.0 else c.darkened(-f)


## Quad whose front face looks along `facing`.
func _quad(kit: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, facing: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(facing) >= 0.0:
		kit._quad(Transform3D.IDENTITY, a, b, c, d, col)
	else:
		kit._quad(Transform3D.IDENTITY, a, d, c, b, col)


func _add_mesh(kit: MeshKit, mat: Material, mesh_name: String, shadows: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = kit.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _glow_material(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _add_shape(body: StaticBody3D, shape: Shape3D, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


## Floor of worn flagstones, the round wall (inward faces only, so a camera that slips outside
## still looks in), pilasters, a string course and the collision for all of it.
func _build_shell() -> void:
	var kit := MeshKit.new()
	var body := StaticBody3D.new()
	body.name = "Shell"
	body.collision_layer = 1
	add_child(body)
	# Flagstone rings. A pale inlay ring marks the Warden's circle at the back of the hall.
	var radii: Array[float] = [0.0, 1.5, 3.1, 4.7, 6.3, 7.9, 9.5, RADIUS + 0.3]
	for k: int in radii.size() - 1:
		var n: int = 8 + 7 * k
		var off: float = _rng.randf() * TAU
		for i: int in n:
			var a0: float = off + TAU * i / n
			var a1: float = off + TAU * (i + 1) / n
			var col: Color = _jit(COL_NIGHT.lerp(COL_EARTH, _rng.randf()).lightened(0.16), 0.1)
			if k == 0:
				_quad(kit, Vector3.ZERO, _polar(a0, radii[1]), _polar((a0 + a1) * 0.5, radii[1]), _polar(a1, radii[1]), Vector3.UP, col)
			else:
				_quad(kit, _polar(a0, radii[k]), _polar(a0, radii[k + 1]), _polar(a1, radii[k + 1]), _polar(a1, radii[k]), Vector3.UP, col)
	# Dark underlay: the rings have different facet counts, so their edges do not meet exactly.
	for i: int in SEGS:
		kit._tri(Transform3D.IDENTITY, Vector3(0, -0.04, 0), _polar(TAU * (i + 1) / SEGS, RADIUS + 0.6, -0.04), _polar(TAU * i / SEGS, RADIUS + 0.6, -0.04), COL_SILHOUETTE)
	var circle := Vector3(0.0, 0.0, -6.0)
	for i: int in 20:
		var a0: float = TAU * i / 20.0
		var a1: float = TAU * (i + 0.82) / 20.0
		_quad(kit, circle + _polar(a0, 2.9, 0.012), circle + _polar(a0, 3.2, 0.012), circle + _polar(a1, 3.2, 0.012), circle + _polar(a1, 2.9, 0.012), Vector3.UP, COL_MOON.darkened(0.45))
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = RADIUS + 1.5
	floor_shape.height = 1.0
	_add_shape(body, floor_shape, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	# Wall bands: damp and dark at the foot, fading into shadow toward the unseen roof.
	var bands: Array[float] = [0.0, 1.3, 4.6, 8.6, WALL_H]
	var band_cols: Array[Color] = [Color("2a2e34"), COL_NIGHT, COL_NIGHT.darkened(0.18), COL_SILHOUETTE]
	for i: int in SEGS:
		var a0: float = TAU * (i - 0.5) / SEGS
		var a1: float = TAU * (i + 0.5) / SEGS
		var mid: float = TAU * i / SEGS
		for b: int in bands.size() - 1:
			var col: Color = _jit(band_cols[b], 0.1)
			_quad(kit, _polar(a0, RADIUS, bands[b]), _polar(a1, RADIUS, bands[b]), _polar(a1, RADIUS, bands[b + 1]), _polar(a0, RADIUS, bands[b + 1]), -_polar(mid, 1.0), col)
		# String course ledge and, on every other facet, a pilaster running up into the dark.
		kit.box(_polar_xf(mid, RADIUS - 0.12, 4.6), Vector3(3.0, 0.28, 0.4), COL_NIGHT.lightened(0.06))
		if i % 2 == 1:
			kit.box(_polar_xf(mid, RADIUS - 0.2, WALL_H * 0.5), Vector3(0.95, WALL_H, 0.55), _jit(COL_NIGHT.darkened(0.08), 0.05))
			kit.box(_polar_xf(mid, RADIUS - 0.3, 0.35), Vector3(1.25, 0.7, 0.8), Color("2a2e34"))
		var wall_shape := BoxShape3D.new()
		wall_shape.size = Vector3(3.2, WALL_H, 1.0)
		_add_shape(body, wall_shape, _polar_xf(mid, RADIUS + 0.45, WALL_H * 0.5))
	# Two charred roof beams crossing high up: silhouettes against the gloom.
	kit.box(Transform3D(Basis(Vector3.UP, 0.7), Vector3(0, 11.0, 0)), Vector3(RADIUS * 2.0, 0.55, 0.55), COL_SILHOUETTE)
	kit.box(Transform3D(Basis(Vector3.UP, 2.3) * Basis(Vector3.RIGHT, 0.06), Vector3(0, 12.2, 0)), Vector3(RADIUS * 2.0, 0.55, 0.55), COL_SILHOUETTE)
	_add_mesh(kit, MeshKit.vertex_color_material(0.92), "ShellMesh")


## Pillars (two broken), the broken spiral stair along the wall, fallen masonry and banners.
func _build_props() -> void:
	var kit := MeshKit.new()
	var body := StaticBody3D.new()
	body.name = "Props"
	body.collision_layer = 1
	add_child(body)
	var stone: Color = COL_NIGHT.lightened(0.1)
	# Six pillars around the hall. The axis from the door to the Warden's circle stays open.
	var heights: Array[float] = [9.0, 2.3, 9.0, 9.0, 4.2, 9.0]
	for k: int in 6:
		var a: float = PI / 6.0 + k * PI / 3.0
		var p: Vector3 = _polar(a, 6.4)
		var h: float = heights[k]
		kit.box(Transform3D(Basis(Vector3.UP, a), p + Vector3.UP * 0.25), Vector3(1.6, 0.5, 1.6), _jit(stone.darkened(0.1), 0.04))
		kit.box(Transform3D(Basis(Vector3.UP, a), p + Vector3.UP * 0.62), Vector3(1.3, 0.24, 1.3), _jit(stone, 0.04))
		kit.cylinder(Transform3D(Basis.IDENTITY, p + Vector3.UP * (0.74 + h * 0.5)), 0.5, 0.58, h, 8, _jit(stone, 0.05))
		if h > 8.0:
			kit.box(Transform3D(Basis(Vector3.UP, a), p + Vector3.UP * (0.74 + h + 0.2)), Vector3(1.4, 0.4, 1.4), stone)
			kit.box(Transform3D(Basis(Vector3.UP, a), p + Vector3.UP * (0.74 + h + 0.6)), Vector3(1.8, 0.4, 1.8), stone.darkened(0.1))
		else:
			# Snapped shaft: a slanted cap and the fallen drums beside it.
			kit.cylinder(Transform3D(Basis(Vector3.RIGHT, 0.35), p + Vector3.UP * (0.74 + h + 0.12)), 0.3, 0.5, 0.3, 8, stone.darkened(0.15))
			var fall: Vector3 = _polar(a + 0.9, 1.0).normalized()
			for d: int in 3:
				var dp: Vector3 = p + fall * (1.7 + d * 1.45) + Vector3.UP * 0.52
				var lay := Basis(fall.cross(Vector3.UP).normalized(), PI * 0.5 + _rng.randf_range(-0.12, 0.12)) * Basis(Vector3.UP, _rng.randf() * TAU)
				kit.cylinder(Transform3D(lay, dp), 0.5, 0.54, 1.15, 8, _jit(stone, 0.06))
				var drum := SphereShape3D.new()
				drum.radius = 0.6
				_add_shape(body, drum, Transform3D(Basis.IDENTITY, dp))
			_rubble(kit, p + fall * 1.0, 1.3, 9, 0.5)
		var col_shape := CylinderShape3D.new()
		col_shape.radius = 0.75
		col_shape.height = minf(h + 0.8, 4.0)
		_add_shape(body, col_shape, Transform3D(Basis.IDENTITY, p + Vector3.UP * col_shape.height * 0.5))
	# Broken spiral stair: cantilevered steps climbing the left wall toward the door, then nothing.
	var a_start: float = PI * 1.1
	for i: int in 27:
		if i in [8, 9, 17, 22, 24, 25]:
			continue
		var a: float = a_start + i * 0.085
		var y: float = 1.5 + i * 0.34
		var depth: float = 2.3 if i < 20 else 1.5
		kit.box(_polar_xf(a, RADIUS - depth * 0.5 - 0.05, y), Vector3(0.98, 0.3, depth), _jit(stone.darkened(0.05), 0.07))
		if i % 4 == 0:
			kit.box(_polar_xf(a, RADIUS - 0.5, y - 0.55), Vector3(0.5, 0.8, 0.9), stone.darkened(0.2))  # Corbel.
	# The lowest flight has collapsed into a heap at the foot of the stair.
	var heap: Vector3 = _polar(a_start - 0.14, RADIUS - 1.5)
	_rubble(kit, heap, 1.7, 16, 0.75)
	kit.box(Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), 0.8) * Basis(Vector3.RIGHT, 0.35), heap + Vector3(0.6, 0.5, 0.9)), Vector3(1.0, 0.3, 2.2), stone)
	kit.box(Transform3D(Basis(Vector3(0.1, 1, -0.3).normalized(), 2.1) * Basis(Vector3.FORWARD, 0.5), heap + Vector3(-0.9, 0.35, 0.3)), Vector3(1.0, 0.3, 2.0), stone.darkened(0.08))
	var heap_shape := SphereShape3D.new()
	heap_shape.radius = 1.5
	_add_shape(body, heap_shape, Transform3D(Basis.IDENTITY, heap + Vector3.UP * 0.2))
	# Fallen masonry elsewhere, kept clear of the fighting floor.
	_rubble(kit, _polar(PI * 0.78, RADIUS - 1.4), 1.4, 12, 0.7)
	_rubble(kit, _polar(PI * 0.36, RADIUS - 1.2), 1.0, 8, 0.55)
	_rubble(kit, _polar(PI * 1.72, RADIUS - 1.1), 0.9, 7, 0.5)
	var pile := SphereShape3D.new()
	pile.radius = 1.2
	_add_shape(body, pile, Transform3D(Basis.IDENTITY, _polar(PI * 0.78, RADIUS - 1.4) + Vector3.UP * 0.1))
	# Tattered Warden banners between the pilasters at the back.
	for s: float in [-1.0, 1.0]:
		var ba: float = PI + s * TAU / SEGS * 2.0
		var bx: Transform3D = _polar_xf(ba, RADIUS - 0.1, 6.3)
		kit.box(bx, Vector3(1.3, 3.4, 0.05), Color("27324f"))
		kit.box(_polar_xf(ba, RADIUS - 0.12, 8.1), Vector3(1.6, 0.12, 0.12), COL_IRON)
		kit.box(_polar_xf(ba, RADIUS - 0.13, 6.9), Vector3(0.45, 0.45, 0.06), COL_MOON.darkened(0.35))
		kit.wedge(Transform3D(bx.basis * Basis(Vector3.RIGHT, PI * 0.5), _polar(ba, RADIUS - 0.1, 4.25) + bx.basis.x * 0.3), Vector3(0.6, 0.05, 0.75), Color("27324f"))
	_add_mesh(kit, MeshKit.vertex_color_material(0.9), "PropsMesh", true)


func _rubble(kit: MeshKit, at: Vector3, spread: float, count: int, size: float) -> void:
	for i: int in count:
		var a: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * spread
		var s: float = size * _rng.randf_range(0.35, 1.0) * (1.25 - r / spread * 0.6)
		var rot := Basis(Vector3(_rng.randf() - 0.5, 1.0, _rng.randf() - 0.5).normalized(), _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5))
		kit.box(Transform3D(rot, at + Vector3(cos(a) * r, s * 0.32, sin(a) * r)), Vector3(s * 1.3, s * 0.75, s), _jit(COL_NIGHT.lerp(COL_EARTH, _rng.randf() * 0.6).lightened(0.06), 0.1))


## Two braziers by the Warden's circle, torches at the door and cold moonlight through a high slit.
## Three OmniLights and one SpotLight in total (Compatibility renderer: keep lights per mesh low).
func _build_lights() -> void:
	var kit := MeshKit.new()
	var fire := MeshKit.new()
	var moon := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		var p := Vector3(4.1 * s, 0.0, -7.3)
		kit.cylinder(Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.08), 0.42, 0.5, 0.16, 8, COL_IRON)
		kit.cylinder(Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.6), 0.09, 0.14, 0.95, 6, COL_IRON)
		kit.cylinder(Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.22), 0.62, 0.3, 0.36, 8, COL_IRON.lightened(0.05))
		fire.cylinder(Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.39), 0.5, 0.52, 0.06, 8, COL_FIRE)
		_add_flame(p + Vector3.UP * 1.45, 1.0)
		_add_fire_light(p + Vector3.UP * 2.3, 3.6, 13.0)
	# Wall torches beside the exit: iron brackets with small flames, sharing one light.
	for s: float in [-1.0, 1.0]:
		var ta: float = s * 0.24
		kit.box(_polar_xf(ta, RADIUS - 0.35, 2.5), Vector3(0.12, 0.12, 0.6), COL_IRON)
		kit.cylinder(Transform3D(Basis.IDENTITY, _polar(ta, RADIUS - 0.62, 2.65)), 0.13, 0.07, 0.45, 6, COL_IRON)
		fire.cylinder(Transform3D(Basis.IDENTITY, _polar(ta, RADIUS - 0.62, 2.9)), 0.1, 0.12, 0.06, 6, COL_FIRE)
		_add_flame(_polar(ta, RADIUS - 0.62, 2.95), 0.55)
	_add_fire_light(Vector3(0.0, 3.2, RADIUS - 2.2), 2.4, 11.0)
	# The slit window high in the back wall, and the moonlight that falls on the Warden's circle.
	var win := Vector3(0.0, 10.0, -(RADIUS - 0.08))
	moon.box(Transform3D(Basis.IDENTITY, win), Vector3(0.6, 3.6, 0.1), COL_MOON)
	for s: float in [-1.0, 1.0]:
		kit.box(Transform3D(Basis(Vector3.UP, s * 0.5), win + Vector3(0.62 * s, 0, 0.25)), Vector3(0.3, 4.2, 0.9), COL_SILHOUETTE.lightened(0.05))
	kit.box(Transform3D(Basis.IDENTITY, win + Vector3(0, -2.05, 0.3)), Vector3(1.6, 0.3, 0.9), COL_NIGHT)
	var spot := SpotLight3D.new()
	spot.name = "Moonlight"
	spot.light_color = COL_MOON.lerp(Color("aebfe0"), 0.45)
	spot.light_energy = 5.0
	spot.spot_range = 20.0
	spot.spot_angle = 17.0
	spot.spot_angle_attenuation = 0.7
	spot.spot_attenuation = 0.5
	spot.shadow_enabled = true
	add_child(spot)
	var spot_at: Vector3 = win + Vector3(0, 0.4, 0.5)
	spot.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -5.6) - spot_at, Vector3.UP), spot_at)
	# Visible shaft: two faint additive sheets from the slit down to the floor.
	var shaft := MeshKit.new()
	var foot := Vector3(0.0, 0.05, -5.2)
	var shaft_col := Color(0.79, 0.8, 0.84, 1.0)
	shaft._quad(Transform3D.IDENTITY, win + Vector3(-0.3, 1.7, 0.1), win + Vector3(0.3, 1.7, 0.1), foot + Vector3(1.5, 0, 1.6), foot + Vector3(-1.5, 0, 1.6), shaft_col)
	shaft._quad(Transform3D.IDENTITY, win + Vector3(-0.3, -1.7, 0.1), win + Vector3(0.3, -1.7, 0.1), foot + Vector3(1.5, 0, -1.6), foot + Vector3(-1.5, 0, -1.6), shaft_col)
	for s: float in [-1.0, 1.0]:
		shaft._quad(Transform3D.IDENTITY, win + Vector3(0.3 * s, 1.7, 0.1), win + Vector3(0.3 * s, -1.7, 0.1), foot + Vector3(1.5 * s, 0, -1.6), foot + Vector3(1.5 * s, 0, 1.6), shaft_col)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.albedo_color = Color(0.79, 0.8, 0.86, 0.026)
	sm.disable_fog = true
	_add_mesh(shaft, sm, "MoonShaft")
	_add_mesh(kit, MeshKit.vertex_color_material(0.7), "LightFittings", true)
	_add_mesh(fire, _glow_material(COL_FIRE, 3.0), "Embers")
	_add_mesh(moon, _glow_material(COL_MOON, 1.3), "MoonSlit")


func _add_fire_light(at: Vector3, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = COL_FIRE.lerp(Color("ffb070"), 0.45)
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.position = at
	add_child(l)
	_fire_lights.append(l)
	_fire_base.append(energy)


func _add_flame(at: Vector3, size: float) -> void:
	var f := CPUParticles3D.new()
	f.amount = 12
	f.lifetime = 0.7
	f.preprocess = 0.7
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.22 * size
	f.direction = Vector3.UP
	f.spread = 12.0
	f.gravity = Vector3(0, 1.6, 0)
	f.initial_velocity_min = 0.5 * size
	f.initial_velocity_max = 1.1 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(1, 0))
	f.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.82, 0.45, 0.9))
	grad.set_color(1, Color(COL_FIRE.r, COL_FIRE.g, COL_FIRE.b, 0.0))
	f.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6) * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = CombatFx.soft_dot()
	m.disable_fog = true
	q.material = m
	f.mesh = q
	f.position = at
	add_child(f)
	_flames.append(f)


## Slow dust drifting through the hall; it catches the moonlight and the fire.
func _build_motes() -> void:
	_motes = CPUParticles3D.new()
	_motes.name = "Dust"
	_motes.amount = 60
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(8.0, 3.5, 8.0)
	_motes.direction = Vector3(0.3, -1.0, 0.1)
	_motes.spread = 60.0
	_motes.gravity = Vector3(0.0, -0.015, 0.0)
	_motes.initial_velocity_min = 0.03
	_motes.initial_velocity_max = 0.14
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	_motes.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = CombatFx.soft_dot()
	m.albedo_color = Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, 0.4)
	q.material = m
	_motes.mesh = q
	_motes.position = Vector3(0, 4.0, 0)
	add_child(_motes)


## The way out: the inside of the sealed door, its runes dim, and a trigger in front of it.
func _build_exit() -> void:
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var z: float = RADIUS - 0.25
	for s: float in [-1.0, 1.0]:
		kit.box(Transform3D(Basis.IDENTITY, Vector3(1.3 * s, 1.95, z)), Vector3(0.6, 3.9, 0.7), COL_NIGHT.lightened(0.12))
	kit.box(Transform3D(Basis.IDENTITY, Vector3(0, 4.1, z)), Vector3(3.2, 0.55, 0.75), COL_NIGHT.lightened(0.12))
	kit.box(Transform3D(Basis.IDENTITY, Vector3(0, 4.15, z - 0.05)), Vector3(0.7, 0.8, 0.8), COL_NIGHT.lightened(0.2))
	kit.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.9, z + 0.05)), Vector3(2.0, 3.8, 0.25), Color("1b1a1d"))
	for y: float in [0.8, 1.9, 3.0]:
		kit.box(Transform3D(Basis.IDENTITY, Vector3(0, y, z - 0.1)), Vector3(2.05, 0.12, 0.08), COL_IRON)
	var rp := Vector3(0, 2.1, z - 0.1)
	for k: int in 12:
		var a: float = TAU * k / 12.0
		glow.box(Transform3D(Basis(Vector3.BACK, a), rp + Vector3(cos(a + PI * 0.5) * 0.62, sin(a + PI * 0.5) * 0.62, 0)), Vector3(0.08, 0.3, 0.04), COL_RUNE)
	for s: float in [-0.25, 0.0, 0.25]:
		glow.box(Transform3D(Basis.IDENTITY, rp + Vector3(s, 0, 0)), Vector3(0.07, 0.75 - absf(s), 0.04), COL_RUNE)
	_add_mesh(kit, MeshKit.vertex_color_material(0.85), "ExitDoor")
	_add_mesh(glow, _glow_material(COL_RUNE, 1.6), "ExitRunes")
	var area := Area3D.new()
	area.name = "ExitTrigger"
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	cs.shape = sph
	area.add_child(cs)
	area.position = Vector3(0, 1.0, RADIUS - 1.0)
	add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player and is_inside:
			request_exit())


## Overworld side: stepping right up to the sealed door (closer than the "reached the door" trigger).
func _build_entry_trigger() -> void:
	var door: Vector3 = arena.spire_path.door_position
	_door_dir = Vector3(door.x - TestArena.CLIFF_CENTER.x, 0.0, door.z - TestArena.CLIFF_CENTER.y).normalized()
	_entry = Area3D.new()
	_entry.name = "EntryTrigger"
	_entry.top_level = true
	_entry.collision_layer = 0
	_entry.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.9
	cs.shape = sph
	_entry.add_child(cs)
	add_child(_entry)
	_entry.global_position = door + _door_dir * 1.3 + Vector3.UP
	_entry.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			request_enter())


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 60
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _process(delta: float) -> void:
	_time += delta
	for i: int in _fire_lights.size():
		var n: float = _noise.get_noise_2d(_time * 9.0, i * 37.0)
		_fire_lights[i].light_energy = _fire_base[i] * (0.86 + 0.2 * n + 0.05 * sin(_time * 23.0 + i))
