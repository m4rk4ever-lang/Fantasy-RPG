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
	var dn: DayNight = (main.get("arena") as TestArena).day_night
	dn.running = false
	dn.time_of_day = 9.5
	dn.apply()

	# 1. Overview: behind the hero, looking up the valley at the watchtower.
	rig.set_angles(-0.23, deg_to_rad(-6.0))
	player.debug_move_input = Vector2(0, -0.0001)
	await _wait(40)
	await _save("01_overzicht.png")

	# 2. Combat: hero mid-swing against a Hollowed, with lock-on and trail. Time slowed for a clean frame.
	var fx: CombatFx = main.get("fx")
	fx.hitstop_enabled = false
	var foes: Array[Node] = get_nodes_in_group(&"enemies")
	for f: Node in foes:
		f.process_mode = Node.PROCESS_MODE_DISABLED
	var arena: TestArena = main.get("arena")
	var spot := Vector3(3.0, 0.0, -2.0)
	spot.y = arena.height_at(spot.x, spot.z)
	player.global_position = spot
	player.velocity = Vector3.ZERO
	player.debug_move_input = Vector2.ZERO
	var foe: Hollow = foes[0]
	foe.global_position = spot + Vector3(-0.6, 0.0, -2.0)
	foe.process_mode = Node.PROCESS_MODE_INHERIT
	foe.attack_damage = 0.0
	foe.state = Hollow.State.WINDUP
	if foes.size() > 1:
		(foes[1] as Node3D).global_position = spot + Vector3(3.5, 0.0, -5.0)
		foes[1].process_mode = Node.PROCESS_MODE_INHERIT
	player.face_direction((foe.global_position - spot).normalized())
	var lock: LockOn = main.get("lock_on")
	lock.set_target(foe)
	rig.set_angles(0.55, deg_to_rad(-12.0))
	await _wait(12)
	Engine.time_scale = 0.06
	player.combat.request_light()
	for i: int in 60:
		await _wait(1)
		if player.combat.phase == PlayerCombat.Phase.ACTIVE and player.combat.current_name == "light_1":
			pass
		if player.combat.phase == PlayerCombat.Phase.RECOVERY:
			break
	await _save("02_gevecht.png")
	Engine.time_scale = 1.0
	lock.set_target(null)

	# 3. Landmark: free camera framing the cliff and tower against the mountains.
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 2500.0
	main.add_child(cam)
	cam.global_position = Vector3(-30.0, 14.0, -10.0)
	cam.look_at(Vector3(-2.0, 46.0, -100.0))
	cam.current = true
	await _wait(10)
	await _save("03_landmark.png")

	# 4. Hero and Hollowed close-up: shows both procedural character designs.
	for f: Node in get_nodes_in_group(&"enemies"):
		f.process_mode = Node.PROCESS_MODE_DISABLED
	var foe2: Hollow = get_nodes_in_group(&"enemies")[0]
	foe2.global_position = Vector3(-6.0, arena.height_at(-6.0, -3.8) + 0.05, -3.8)
	foe2.process_mode = Node.PROCESS_MODE_DISABLED
	foe2.target = null
	foe2.state = Hollow.State.IDLE
	foe2.set("_facing", atan2(2.0, -2.2))
	player.global_position = Vector3(-4.0, arena.height_at(-4.0, -6.0) + 0.05, -6.0)
	player.velocity = Vector3.ZERO
	player.face_direction(Vector3(2.2, 0, -3.2))
	await _wait(30)
	cam.global_position = player.global_position + Vector3(2.2, 1.7, -3.2)
	cam.look_at(player.global_position + Vector3(0, 1.1, 0))
	cam.fov = 45.0
	await _wait(5)
	await _save("04_held.png")

	# 5b. Village on the bay (by day).
	var sea := Vector3(TestArena.SEA_DIR.x, 0, TestArena.SEA_DIR.y)
	var along := Vector3(-TestArena.SEA_DIR.y, 0, TestArena.SEA_DIR.x)
	cam.fov = 60.0
	cam.global_position = sea * (TestArena.SHORE_S + 14.0) + along * -26.0 + Vector3.UP * 7.0
	cam.look_at(sea * 24.0 + along * 2.0 + Vector3.UP * 2.0)
	await _wait(8)
	await _save("06_dorp.png")

	# 5c. A villager talking to the hero (humor in the world).
	var villager: Villager = null
	for c: Node in arena.get_node("Village").get_children():
		if c is Villager:
			villager = c  # The last one walks the beach: open view from the sea side.
	if villager:
		villager.process_mode = Node.PROCESS_MODE_DISABLED
		var vp: Vector3 = villager.global_position
		player.global_position = vp + along * 1.7 + Vector3.UP * 0.3
		player.face_direction(-along)
		await _wait(10)
		villager.process_mode = Node.PROCESS_MODE_INHERIT
		villager.speed = 0.0
		await _wait(4)
		cam.fov = 50.0
		cam.global_position = vp + sea * 4.5 + along * 0.9 + Vector3.UP * 2.0
		cam.look_at(vp + along * 0.9 + Vector3.UP * 1.5)
		await _wait(4)
		await _save("07_dorpeling.png")

	# 5d. Skill tree window with some progress.
	var prog: Progression = player.progression
	prog.add_xp(700)
	for nid: String in ["keen_edge", "keen_edge", "whirlwind", "second_wind", "surge"]:
		prog.rank_up(nid)
	prog.set_allegiance("saltbound")
	var tree_win: SkillTreeWindow = main.get_node("SkillTree")
	tree_win.toggle()
	await _wait(6)
	await _save("08_skilltree.png")
	tree_win.toggle()

	# 5e. Talking to Brenna in Saltwick, quest tracker and backpack open.
	var brenna: Villager = arena.village.brenna
	player.global_position = brenna.global_position + sea * 1.9 + along * 0.6 + Vector3.UP * 0.3
	player.face_direction(-sea)
	player.inventory.add("veil_dust", 3)
	player.inventory.add("hollow_fang", 2)
	player.inventory.add("coins", 42)
	player.quests.start("ashes_on_the_shore")
	await _wait(6)
	cam.fov = 55.0
	cam.global_position = brenna.global_position + sea * 5.5 + along * 3.5 + Vector3.UP * 2.6
	cam.look_at(brenna.global_position + sea * 1.0 + Vector3.UP * 0.9)
	var dlg: DialogueWindow = main.get("dialogue")
	(main.get("brenna_talk") as BrennaDialogue).call("_why")
	(main.get_node("Backpack") as InventoryWindow).toggle()
	await _wait(6)
	await _save("09_quest.png")
	dlg.close()
	(main.get_node("Backpack") as InventoryWindow).toggle()

	# 5. Dusk over the valley: day-night cycle.
	dn.time_of_day = 19.2
	dn.apply()
	cam.fov = 62.0
	cam.global_position = sea * (TestArena.SHORE_S + 17.0) + along * -10.0 + Vector3.UP * 4.5
	cam.look_at(Vector3(18.0, 26.0, -78.0))
	await _wait(8)
	await _save("05_avond.png")
	quit(0)
