extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _shot(cam: Camera3D, path: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	var arena: TestArena = main.get("arena")
	arena.day_night.running = false
	arena.day_night.time_of_day = 15.0
	arena.day_night.apply()
	main.get_node("Hud").set("visible", false)
	var player: Player = main.get_node("Player")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.fov = 40
	for i in 10: await process_frame
	var p := player.global_position
	var f := -player.model.global_transform.basis.z
	var r := f.cross(Vector3.UP)
	var views := [f * 3.0 + r * 0.8, -f * 3.0 + r * 0.8, r * 3.0]
	var k := 0
	for v: Vector3 in views:
		cam.global_position = p + v + Vector3.UP * 1.4
		cam.look_at(p + Vector3.UP * 1.0)
		await _shot(cam, "/tmp/claude-0/prev/gear%d.png" % k)
		k += 1
	quit()
