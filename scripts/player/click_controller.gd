class_name ClickController
extends Node3D
## RuneScape-style mouse control: left-click a monster to target and auto-attack it,
## left-click the ground to walk there. The cursor turns into a hand over monsters.
## Monster picking is forgiving: anything within PICK_RADIUS of the mouse ray counts.

const PICK_RADIUS: float = 0.9
const RAY_LENGTH: float = 400.0

var player: Player
var camera_rig: CameraRig
var lock_on: LockOn

var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _hover: Node3D


func setup(p: Player, rig: CameraRig, lock: LockOn) -> void:
	player = p
	camera_rig = rig
	lock_on = lock
	top_level = true
	_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.36
	torus.rings = 24
	torus.ring_segments = 3
	_marker.mesh = torus
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.albedo_color = Color(0.9, 0.88, 0.8, 0.0)
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.scale = Vector3(1, 0.15, 1)
	add_child(_marker)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event.is_action_pressed("click") and event is InputEventMouseButton:
		_click((event as InputEventMouseButton).position)


func _ray(screen_pos: Vector2) -> Array[Vector3]:
	var cam: Camera3D = camera_rig.camera
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	return [from, dir]


## Closest living monster whose body (a vertical segment) passes near the mouse ray.
func pick_enemy(screen_pos: Vector2) -> Node3D:
	return _pick_group(screen_pos, &"enemies")


func pick_npc(screen_pos: Vector2) -> Node3D:
	return _pick_group(screen_pos, &"npcs")


func _pick_group(screen_pos: Vector2, group: StringName) -> Node3D:
	var r: Array[Vector3] = _ray(screen_pos)
	var from: Vector3 = r[0]
	var dir: Vector3 = r[1]
	var best: Node3D = null
	var best_t: float = INF
	for e: Node in get_tree().get_nodes_in_group(group):
		var en := e as Node3D
		if en == null or (en.has_method("is_dead") and en.call("is_dead")):
			continue
		# Sample the body from feet to head; take the nearest point to the ray.
		for h: float in [0.3, 0.9, 1.5, 2.0]:
			var p: Vector3 = en.global_position + Vector3.UP * h
			var t: float = (p - from).dot(dir)
			if t <= 0.0:
				continue
			var d: float = (from + dir * t).distance_to(p)
			if d < PICK_RADIUS and t < best_t:
				best_t = t
				best = en
	return best


func pick_ground(screen_pos: Vector2) -> Variant:
	var r: Array[Vector3] = _ray(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * RAY_LENGTH, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit["position"]


func _update_hover(screen_pos: Vector2) -> void:
	var en: Node3D = pick_enemy(screen_pos)
	if en == null:
		en = pick_npc(screen_pos)
	if en != _hover:
		_hover = en
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if en else Input.CURSOR_ARROW)


func _click(screen_pos: Vector2) -> void:
	var en: Node3D = pick_enemy(screen_pos)
	if en:
		lock_on.set_target(en)
		player.attack_target = en
		return
	var npc: Node3D = pick_npc(screen_pos)
	if npc:
		player.set_talk_target(npc)
		return
	var p: Variant = pick_ground(screen_pos)
	if p != null:
		player.set_move_target(p)
		_show_marker(p)


func _show_marker(p: Vector3) -> void:
	_marker.global_position = p + Vector3.UP * 0.05
	_marker.scale = Vector3(1.4, 0.15, 1.4)
	_marker_mat.albedo_color.a = 0.9
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_marker, "scale", Vector3(0.6, 0.15, 0.6), 0.35)
	tw.tween_property(_marker_mat, "albedo_color:a", 0.0, 0.45)
