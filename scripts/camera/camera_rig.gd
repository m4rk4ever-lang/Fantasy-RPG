class_name CameraRig
extends Node3D
## Third-person orbit camera in the RuneScape style: it never turns by itself.
## Rotate with middle-mouse drag, arrow keys or the right stick; zoom with the scroll wheel.
## SpringArm3D collision, speed-based FOV kick and trauma-based screen shake.

@export var target_path: NodePath
@export var arm_length: float = 7.5
@export var min_zoom: float = 3.0
@export var max_zoom: float = 18.0
@export var height_offset: float = 1.55
@export var mouse_sensitivity: float = 0.005
@export var stick_sensitivity: float = 3.2
@export var min_pitch: float = deg_to_rad(-75.0)
@export var max_pitch: float = deg_to_rad(10.0)
@export var base_fov: float = 68.0
@export var sprint_fov: float = 76.0
@export var follow_sharpness: float = 14.0

var yaw_node: Node3D
var pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D
var target: Node3D
## Set externally (e.g. lock-on) to steer the yaw toward a world point. Null = free look.
var look_target: Node3D

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-24.0)
var _zoom_target: float = 7.5
var _dragging: bool = false
var _trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _fov_kick: float = 0.0


func _ready() -> void:
	top_level = true
	yaw_node = Node3D.new()
	yaw_node.name = "Yaw"
	add_child(yaw_node)
	pitch_node = Node3D.new()
	pitch_node.name = "Pitch"
	yaw_node.add_child(pitch_node)
	spring = SpringArm3D.new()
	spring.name = "SpringArm"
	spring.spring_length = arm_length
	spring.collision_mask = 1
	spring.margin = 0.25
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	spring.position = Vector3.ZERO
	pitch_node.add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = base_fov
	camera.far = 2500.0
	camera.near = 0.08
	spring.add_child(camera)
	camera.current = true
	_noise.seed = 7
	_noise.frequency = 1.0
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target:
		set_target(target)


func set_target(t: Node3D) -> void:
	target = t
	if t is CollisionObject3D:
		spring.add_excluded_object((t as CollisionObject3D).get_rid())
	global_position = t.global_position + Vector3.UP * height_offset


## Instantly place the camera at given yaw/pitch (radians). Used by screenshots and spawn.
func set_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, min_pitch, max_pitch)
	_apply_angles()


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func kick_fov(amount: float) -> void:
	_fov_kick = maxf(_fov_kick, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clampf(_zoom_target * 0.88, min_zoom, max_zoom)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clampf(_zoom_target / 0.88, min_zoom, max_zoom)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch -= mm.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, min_pitch, max_pitch)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		if event.is_action("zoom_in"):
			_zoom_target = clampf(_zoom_target * 0.88, min_zoom, max_zoom)
		elif event.is_action("zoom_out"):
			_zoom_target = clampf(_zoom_target / 0.88, min_zoom, max_zoom)


func _process(delta: float) -> void:
	_time += delta
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= stick.x * stick_sensitivity * delta
	_pitch -= stick.y * stick_sensitivity * 0.7 * delta
	_pitch = clampf(_pitch, min_pitch, max_pitch)
	spring.spring_length = lerpf(spring.spring_length, _zoom_target, 1.0 - exp(-10.0 * delta))

	if look_target and is_instance_valid(look_target) and target:
		var to: Vector3 = look_target.global_position - target.global_position
		var want_yaw: float = atan2(-to.x, -to.z)
		_yaw = lerp_angle(_yaw, want_yaw, 1.0 - exp(-8.0 * delta))
		var flat: float = Vector2(to.x, to.z).length()
		var want_pitch: float = clampf(-0.26 + atan2(to.y, maxf(flat, 1.0)) * 0.5, min_pitch, max_pitch)
		_pitch = lerpf(_pitch, want_pitch, 1.0 - exp(-5.0 * delta))

	if target:
		var goal: Vector3 = target.global_position + Vector3.UP * height_offset
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * delta))

	_apply_angles()

	# Speed-based FOV: sprinting and dashing widen the view.
	var speed_ratio: float = 0.0
	if target and target.has_method("get_speed_ratio"):
		speed_ratio = target.call("get_speed_ratio")
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 30.0)
	var want_fov: float = lerpf(base_fov, sprint_fov, clampf((speed_ratio - 0.62) / 0.38, 0.0, 1.0)) + _fov_kick
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-6.0 * delta))

	# Trauma shake (squared falloff feels better than linear).
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var shake: float = _trauma * _trauma
	camera.h_offset = _noise.get_noise_2d(_time * 30.0, 0.0) * 0.25 * shake
	camera.v_offset = _noise.get_noise_2d(0.0, _time * 30.0) * 0.25 * shake
	camera.rotation.z = _noise.get_noise_2d(_time * 25.0, 50.0) * 0.06 * shake


func _apply_angles() -> void:
	yaw_node.rotation.y = _yaw
	pitch_node.rotation.x = _pitch


func set_zoom(distance: float) -> void:
	_zoom_target = clampf(distance, min_zoom, max_zoom)
	spring.spring_length = _zoom_target


func get_yaw_node() -> Node3D:
	return yaw_node
