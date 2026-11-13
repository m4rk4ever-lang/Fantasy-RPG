class_name CombatFx
extends Node3D
## Hit feedback: hitstop, impact sparks with a flash, and a ground ring for heavy slams.

const SPARK_COLOR := Color("fff3d6")
const VEIL_COLOR := Color("c9c6b8")

## Tests switch hitstop off: headless runs unthrottled, so real-time freezes span many frames.
var hitstop_enabled: bool = true
var _hitstop_until: int = 0
var _spark_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_mat.albedo_texture = soft_dot()
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mat.albedo_color = Color(1.0, 0.95, 0.85, 0.9)
	_flash_mat.albedo_texture = soft_dot()
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.8)


## Freeze time briefly so hits feel heavy. Overlapping calls extend, never stack.
func hitstop(duration: float) -> void:
	if not hitstop_enabled:
		return
	var until: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	Engine.time_scale = 0.03


func _process(_delta: float) -> void:
	# Real-time check every frame, so a hitstop can never get stuck.
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0


func impact(pos: Vector3, dir: Vector3, strength: float = 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(14 + 14 * strength)
	p.lifetime = 0.35
	p.local_coords = false
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0 * (0.7 + strength * 0.5)
	p.gravity = Vector3(0, -14, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
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
	q.material = _spark_mat
	p.mesh = q
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

	# Bright flash sprite that pops and fades.
	var flash := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.9, 0.9) * (0.8 + strength * 0.5)
	flash.mesh = fq
	var fm: StandardMaterial3D = _flash_mat.duplicate()
	flash.material_override = fm
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	flash.global_position = pos
	var tw := flash.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 1.6, 0.12)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.14)
	tw.chain().tween_callback(flash.queue_free)


func slam(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	var rm: StandardMaterial3D = _ring_mat.duplicate()
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.1
	ring.scale = Vector3(0.5, 0.2, 0.5)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.8, 0.2, 3.8), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
	impact(pos + Vector3.UP * 0.2, Vector3.UP, 1.3)
