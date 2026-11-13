class_name CombatFx
extends Node3D
## Hit feedback: hitstop, impact sparks with a flash, ground dust and a slam ring.
## Performance: every effect is pooled (no node or material creation during combat) and
## all materials are pre-warmed on the first frames, so WebGL never compiles a shader mid-fight.

const SPARK_COLOR := Color("fff3d6")
const VEIL_COLOR := Color("c9c6b8")
const SPARK_POOL: int = 6
const FLASH_POOL: int = 6
const DUST_POOL: int = 10
const RING_POOL: int = 2
## Time scale during hitstop. Not a full freeze: a near-freeze reads as a frame drop on the web.
const HITSTOP_SCALE: float = 0.2
const HITSTOP_MAX: float = 0.08

## Tests switch hitstop off: headless runs unthrottled, so real-time freezes span many frames.
var hitstop_enabled: bool = true
## Material used by enemies for their white hit flash; shared so it is pre-warmed here.
var hit_flash_material: StandardMaterial3D

var _hitstop_until: int = 0
var _sparks: Array[CPUParticles3D] = []
var _flashes: Array[MeshInstance3D] = []
var _dusts: Array[CPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _i_spark: int = 0
var _i_flash: int = 0
var _i_dust: int = 0
var _i_ring: int = 0
var _prewarm_frames: int = 0

static var _soft_dot: GradientTexture2D


## Shared round, soft-edged sprite for particles (avoids square quads).
static func soft_dot() -> GradientTexture2D:
	if _soft_dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.8))
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = g
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(1.0, 0.5)
		_soft_dot.width = 64
		_soft_dot.height = 64
	return _soft_dot


static func make_hit_flash_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1, 1, 1, 0)
	return m


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.albedo_texture = soft_dot()
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust_mat.vertex_color_use_as_albedo = true
	dust_mat.albedo_texture = soft_dot()
	hit_flash_material = make_hit_flash_material()

	for i: int in SPARK_POOL:
		_sparks.append(_make_sparks(spark_mat))
	for i: int in FLASH_POOL:
		_flashes.append(_make_flash())
	for i: int in DUST_POOL:
		_dusts.append(_make_dust(dust_mat))
	for i: int in RING_POOL:
		_rings.append(_make_ring())
	# Pre-warm: one invisible-sized draw of every material next to the camera's view.
	var warm := MeshInstance3D.new()
	warm.name = "PrewarmHitFlash"
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.01
	warm.mesh = bm
	warm.material_override = hit_flash_material
	add_child(warm)
	_prewarm_frames = 3
	for p: CPUParticles3D in [_sparks[0], _dusts[0]]:
		p.scale_amount_min = 0.001
		p.scale_amount_max = 0.001
		p.emitting = true
	for m: MeshInstance3D in [_flashes[0], _rings[0]]:
		m.visible = true
		m.scale = Vector3.ONE * 0.001


func _make_sparks(mat: StandardMaterial3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.35
	p.local_coords = false
	p.spread = 55.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -14, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, SPARK_COLOR)
	grad.set_color(1, Color(VEIL_COLOR, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = mat
	p.mesh = q
	add_child(p)
	return p


func _make_flash() -> MeshInstance3D:
	var flash := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.0, 1.0)
	flash.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_color = Color(1.0, 0.95, 0.85, 0.0)
	fm.albedo_texture = soft_dot()
	flash.material_override = fm
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	add_child(flash)
	return flash


func _make_dust(mat: StandardMaterial3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.amount = 16
	p.lifetime = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.25
	p.emission_ring_inner_radius = 0.0
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.6
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.93, 0.9, 0.82, 0.55))
	grad.set_color(1, Color(0.93, 0.9, 0.82, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.material = mat
	p.mesh = q
	add_child(p)
	return p


func _make_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.albedo_color = Color(0.9, 0.95, 1.0, 0.0)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	return ring


## Place pre-warm draws in front of the active camera for a few frames, then hide them.
func _process(_delta: float) -> void:
	if _prewarm_frames > 0:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			var at: Vector3 = cam.global_position - cam.global_transform.basis.z * 2.0
			for n: Node3D in [_sparks[0], _dusts[0], _flashes[0], _rings[0], get_node("PrewarmHitFlash") as Node3D]:
				n.global_position = at
		_prewarm_frames -= 1
		if _prewarm_frames == 0:
			get_node("PrewarmHitFlash").queue_free()
			_flashes[0].visible = false
			_rings[0].visible = false
			_flashes[0].scale = Vector3.ONE
			_rings[0].scale = Vector3.ONE
	# Real-time check every frame, so a hitstop can never get stuck.
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0


## Slow time briefly so hits feel heavy. Overlapping calls extend, never stack.
func hitstop(duration: float) -> void:
	if not hitstop_enabled:
		return
	duration = minf(duration, HITSTOP_MAX)
	var until: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	Engine.time_scale = HITSTOP_SCALE


func impact(pos: Vector3, dir: Vector3, strength: float = 1.0) -> void:
	var p: CPUParticles3D = _sparks[_i_spark]
	_i_spark = (_i_spark + 1) % SPARK_POOL
	p.global_position = pos
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.initial_velocity_max = 11.0 * (0.7 + strength * 0.5)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.restart()

	var flash: MeshInstance3D = _flashes[_i_flash]
	_i_flash = (_i_flash + 1) % FLASH_POOL
	var fm := flash.material_override as StandardMaterial3D
	flash.global_position = pos
	flash.scale = Vector3.ONE * (0.8 + strength * 0.5)
	flash.visible = true
	fm.albedo_color.a = 0.9
	var tw := flash.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * (1.4 + strength * 0.6), 0.12)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.14)
	tw.chain().tween_callback(flash.hide)


func slam(pos: Vector3) -> void:
	var ring: MeshInstance3D = _rings[_i_ring]
	_i_ring = (_i_ring + 1) % RING_POOL
	var rm := ring.material_override as StandardMaterial3D
	ring.global_position = pos + Vector3.UP * 0.1
	ring.scale = Vector3(0.5, 0.2, 0.5)
	ring.visible = true
	rm.albedo_color.a = 0.8
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.8, 0.2, 3.8), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.hide)
	impact(pos + Vector3.UP * 0.2, Vector3.UP, 1.3)
	dust(pos, 1.2)


## Soft ground dust (landing, dash, sprint steps). Tinted toward warm stone so it reads on grass.
func dust(pos: Vector3, strength: float = 1.0) -> void:
	var p: CPUParticles3D = _dusts[_i_dust]
	_i_dust = (_i_dust + 1) % DUST_POOL
	p.global_position = pos + Vector3.UP * 0.1
	p.initial_velocity_max = 1.6 + strength
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3 + strength * 0.5
	p.restart()
