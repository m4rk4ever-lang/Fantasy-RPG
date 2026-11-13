class_name Ambience
extends Node3D
## Small life around the player: drifting pollen by day, fireflies at night, butterflies over the grass.
## Everything follows the player, so a handful of particles makes the whole valley feel alive.

var target: Node3D
var arena: TestArena

var _motes: CPUParticles3D
var _motes_mat: StandardMaterial3D
var _butterflies: Array[Node3D] = []
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_target: Node3D, p_arena: TestArena) -> void:
	target = p_target
	arena = p_arena
	_noise.frequency = 0.08
	_rng.seed = 99
	top_level = true
	_build_motes()
	_build_butterflies()


func _build_motes() -> void:
	_motes = CPUParticles3D.new()
	_motes.amount = 70
	_motes.lifetime = 6.0
	_motes.preprocess = 6.0
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(18, 2.5, 18)
	_motes.direction = Vector3(1, 0.2, 0.3)
	_motes.spread = 180.0
	_motes.gravity = Vector3(0.15, 0.03, 0.05)
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	_motes.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	_motes_mat = StandardMaterial3D.new()
	_motes_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_motes_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_motes_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_motes_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_motes_mat.albedo_texture = CombatFx.soft_dot()
	_motes_mat.albedo_color = Color(1.0, 0.97, 0.85, 0.55)
	q.material = _motes_mat
	_motes.mesh = q
	add_child(_motes)


func _build_butterflies() -> void:
	var colors: Array[Color] = [Color("6ec3f0"), Color("e6e1d3"), Color("f2c14e"), Color("6ec3f0"), Color("d9552e"), Color("e6e1d3")]
	for i: int in colors.size():
		var b := Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.8
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.name = "L" if side < 0.0 else "R"
			b.add_child(pivot)
			var w := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.14, 0.12)
			w.mesh = qm
			w.material_override = mat
			w.rotation.x = -PI * 0.5
			w.position.x = 0.07 * side
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(w)
		b.set_meta("seed", _rng.randf() * 100.0)
		b.set_meta("home", Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12)))
		add_child(b)
		_butterflies.append(b)


## 0 = full day, 1 = night. Called by the game root from DayNight.
func set_night(night: float) -> void:
	_motes_mat.albedo_color = Color(1.0, 0.97, 0.85, 0.5).lerp(Color(0.85, 1.0, 0.45, 0.95), night)
	_motes.scale_amount_min = lerpf(0.8, 1.6, night)
	_motes.scale_amount_max = lerpf(1.2, 2.4, night)
	for b: Node3D in _butterflies:
		b.visible = night < 0.5


func _process(delta: float) -> void:
	if target == null:
		return
	_time += delta
	_motes.global_position = target.global_position + Vector3.UP * 1.5
	for b: Node3D in _butterflies:
		if not b.visible:
			continue
		var sd: float = b.get_meta("seed")
		var home: Vector3 = b.get_meta("home")
		var c: Vector3 = target.global_position + home
		var p := Vector3(
			c.x + _noise.get_noise_2d(_time * 6.0, sd) * 6.0,
			0.0,
			c.z + _noise.get_noise_2d(sd, _time * 6.0) * 6.0)
		p.y = arena.height_at(p.x, p.z) + 0.6 + absf(sin(_time * 2.3 + sd)) * 0.5
		var vel: Vector3 = p - b.global_position
		b.global_position = b.global_position.lerp(p, 1.0 - exp(-3.0 * delta)) if b.global_position.distance_to(p) < 15.0 else p
		if vel.length() > 0.01:
			b.rotation.y = atan2(vel.x, vel.z)
		var flap: float = sin(_time * 22.0 + sd) * 1.1
		(b.get_node("L") as Node3D).rotation.z = flap
		(b.get_node("R") as Node3D).rotation.z = -flap
