class_name LockOn
extends Node3D
## Lock-on targeting: toggle with "lock_on", switch targets with a right-stick or mouse flick.
## Drives the camera's look target, the hero's facing and the HUD target bar.

signal target_changed(target: Node3D)

const MAX_RANGE: float = 24.0
const FLICK_MOUSE: float = 28.0
const FLICK_STICK: float = 0.75

var player: Player
var camera_rig: CameraRig
var target: Node3D

var _marker: MeshInstance3D
var _flick_ready: bool = true
var _time: float = 0.0


func setup(p: Player, rig: CameraRig) -> void:
	player = p
	camera_rig = rig
	top_level = true
	_marker = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.22, 0.26, 0.22)
	_marker.mesh = prism
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("e6e1d3")
	m.no_depth_test = true
	m.render_priority = 10
	_marker.material_override = m
	_marker.rotation.x = PI  # Point down at the target.
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on"):
		if target:
			set_target(null)
		else:
			set_target(_find_best(null, 0.0))
	elif target and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var dx: float = (event as InputEventMouseMotion).relative.x
		if absf(dx) > FLICK_MOUSE and _flick_ready:
			_switch(signf(dx))
			_flick_ready = false
			get_tree().create_timer(0.3).timeout.connect(func() -> void: _flick_ready = true)


func set_target(t: Node3D) -> void:
	if t == target:
		return
	target = t
	player.lock_target = t
	camera_rig.look_target = t
	_marker.visible = t != null
	target_changed.emit(t)


func _switch(side: float) -> void:
	var nxt: Node3D = _find_best(target, side)
	if nxt:
		set_target(nxt)


## Best target: in front of the camera and close. With side != 0, only candidates on that side of the current target.
func _find_best(exclude: Node3D, side: float) -> Node3D:
	var cam: Camera3D = camera_rig.camera
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var cam_right: Vector3 = cam.global_transform.basis.x
	var best: Node3D = null
	var best_score: float = INF
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		var en := e as Node3D
		if en == null or en == exclude:
			continue
		var to: Vector3 = en.global_position - player.global_position
		var d: float = to.length()
		if d > MAX_RANGE:
			continue
		var from_cam: Vector3 = (en.global_position - cam.global_position).normalized()
		var facing: float = cam_fwd.dot(from_cam)
		if side == 0.0 and facing < 0.2 and d > 6.0:
			continue
		var score: float = d * (1.6 - facing)
		if side != 0.0 and exclude:
			var lateral: float = (en.global_position - exclude.global_position).dot(cam_right)
			if signf(lateral) != side:
				continue
			score = absf(lateral) + d * 0.3
		if score < best_score:
			best_score = score
			best = en
	return best


func _process(delta: float) -> void:
	_time += delta
	if target and (not is_instance_valid(target) or (target.has_method("is_dead") and target.call("is_dead"))):
		var old: Node3D = target if is_instance_valid(target) else null
		set_target(null)
		set_target(_find_best(old, 0.0))
	if target and player.global_position.distance_to(target.global_position) > MAX_RANGE * 1.3:
		set_target(null)
	if target and _flick_ready:
		var sx: float = Input.get_axis("look_left", "look_right")
		if absf(sx) > FLICK_STICK:
			_switch(signf(sx))
			_flick_ready = false
			get_tree().create_timer(0.35).timeout.connect(func() -> void: _flick_ready = true)
	if target:
		var top: Vector3 = target.global_position + Vector3.UP * (2.45 + sin(_time * 4.0) * 0.08)
		_marker.global_position = top
		_marker.rotation.y += delta * 2.5
