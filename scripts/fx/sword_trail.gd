class_name SwordTrail
extends MeshInstance3D
## Ribbon trail between two moving points (sword base and tip). Fades out by age.

const MAX_AGE: float = 0.16
const MAX_SAMPLES: int = 24

var emitting: bool = false
var color: Color = Color(0.85, 0.93, 1.0)

var _base: Node3D
var _tip: Node3D
var _samples: Array[Dictionary] = []
var _imesh := ImmediateMesh.new()


func setup(base: Node3D, tip: Node3D) -> void:
	_base = base
	_tip = tip
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	material_override = mat


func _process(delta: float) -> void:
	if _base == null:
		return
	for s: Dictionary in _samples:
		s["age"] = (s["age"] as float) + delta
	while not _samples.is_empty() and (_samples[0]["age"] as float) > MAX_AGE:
		_samples.pop_front()
	if emitting:
		_samples.append({"a": _base.global_position, "b": _tip.global_position, "age": 0.0})
		if _samples.size() > MAX_SAMPLES:
			_samples.pop_front()
	_rebuild()


func _rebuild() -> void:
	_imesh.clear_surfaces()
	if _samples.size() < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s: Dictionary in _samples:
		var life: float = 1.0 - clampf((s["age"] as float) / MAX_AGE, 0.0, 1.0)
		var c := Color(color, 0.0)
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(s["a"])
		_imesh.surface_set_color(Color(color, 0.75 * life * life))
		_imesh.surface_add_vertex(s["b"])
	_imesh.surface_end()
