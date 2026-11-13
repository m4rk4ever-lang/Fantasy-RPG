class_name LockOn
extends Node3D
## Targeting (RuneScape style): the selected monster gets a marker and a health bar.
## Select by left-clicking a monster (see ClickController) or press Q to cycle through nearby ones.
## The camera never turns by itself; targeting only drives the hero, the marker and the HUD.

signal target_changed(target: Node3D)

const MAX_RANGE: float = 28.0

var player: Player
var camera_rig: CameraRig
var target: Node3D

var _marker: MeshInstance3D
var _ring: MeshInstance3D
var _time: float = 0.0


func setup(p: Player, rig: CameraRig) -> void:
	player = p
	camera_rig = rig
	top_level = true
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("e6e1d3")
	m.no_depth_test = true
	m.render_priority = 10
	_marker = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.22, 0.26, 0.22)
	_marker.mesh = prism
	_marker.material_override = m
	_marker.rotation.x = PI  # Point down at the target.
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)
	# Ground ring under the target, in fire color: reads as "hostile, selected".
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 32
	torus.ring_segments = 3
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("d9552e")
	_ring.material_override = rm
	_ring.scale = Vector3(1, 0.1, 1)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on"):
		var nxt: Node3D = _find_best(target)
		if nxt:
			set_target(nxt)
			player.attack_target = nxt


func set_target(t: Node3D) -> void:
	if t == target:
		return
	target = t
	player.lock_target = t
	_marker.visible = t != null
	_ring.visible = t != null
	target_changed.emit(t)


## Nearest living monster in range, preferring ones in front of the camera. Skips `exclude`.
func _find_best(exclude: Node3D) -> Node3D:
	var cam: Camera3D = camera_rig.camera
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var best: Node3D = null
	var best_score: float = INF
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		var en := e as Node3D
		if en == null or en == exclude:
			continue
		var d: float = (en.global_position - player.global_position).length()
		if d > MAX_RANGE:
			continue
		var facing: float = cam_fwd.dot((en.global_position - cam.global_position).normalized())
		var score: float = d * (1.6 - facing)
		if score < best_score:
			best_score = score
			best = en
	if best == null and exclude and is_instance_valid(exclude):
		return exclude
	return best


func _process(delta: float) -> void:
	_time += delta
	if target and (not is_instance_valid(target) or (target.has_method("is_dead") and target.call("is_dead"))):
		set_target(null)
	if target and player.global_position.distance_to(target.global_position) > MAX_RANGE * 1.3:
		set_target(null)
	if target:
		_marker.global_position = target.global_position + Vector3.UP * (2.45 + sin(_time * 4.0) * 0.08)
		_marker.rotation.y += delta * 2.5
		_ring.global_position = target.global_position + Vector3.UP * 0.06
