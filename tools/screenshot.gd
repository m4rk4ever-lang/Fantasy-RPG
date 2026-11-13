extends SceneTree
## Captures fixed-viewpoint screenshots for the changelog.
## Run: xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 -s tools/screenshot.gd -- <out_dir>

var _out_dir: String = "res://docs/screenshots/latest"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") else _out_dir)
	_run.call_deferred()


func _wait(n: int) -> void:
	for i: int in n:
		await process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var abs_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	img.save_png(abs_path)
	print("saved ", abs_path)


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(10)
	var player: Player = main.get_node("Player")
	var rig: CameraRig = main.get_node("CameraRig")
	var hud: Hud = main.get_node("Hud")
	hud.set_hint_visible(false)

	# 1. Overview: behind the hero, looking up the valley at the watchtower.
	rig.set_angles(-0.23, deg_to_rad(-6.0))
	player.debug_move_input = Vector2(0, -0.0001)
	await _wait(40)
	await _save("01_overzicht.png")

	# 2. Action: sprinting hero mid-stride, camera from the side.
	rig.set_angles(0.0, deg_to_rad(-8.0))
	await _wait(5)
	player.debug_move_input = Vector2(-1.0, -0.25)
	Input.action_press("sprint")
	await _wait(32)
	await _save("02_actie.png")
	Input.action_release("sprint")
	player.debug_move_input = Vector2.ZERO

	# 3. Landmark: free camera framing the cliff and tower against the mountains.
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 2500.0
	main.add_child(cam)
	cam.global_position = Vector3(-30.0, 14.0, -10.0)
	cam.look_at(Vector3(18.0, 40.0, -78.0))
	cam.current = true
	await _wait(10)
	await _save("03_landmark.png")

	# 4. Hero close-up: shows the procedural character design.
	player.global_position = Vector3(-4.0, 0.05, -6.0)
	player.velocity = Vector3.ZERO
	player.face_direction(Vector3(2.2, 0, -3.2))
	await _wait(30)
	cam.global_position = player.global_position + Vector3(2.2, 1.7, -3.2)
	cam.look_at(player.global_position + Vector3(0, 1.1, 0))
	cam.fov = 45.0
	await _wait(5)
	await _save("04_held.png")
	quit(0)
