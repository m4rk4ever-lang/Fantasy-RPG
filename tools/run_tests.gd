extends SceneTree

const PLAYER_SPAWN_FOR_TESTS := Vector3(0.0, 1.6, 6.0)
## Headless smoke tests. Run: godot --headless -s tools/run_tests.gd
## Exits with code 0 on success, 1 on any failure.

var _failures: Array[String] = []
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	print("== Veilspire smoke tests ==")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene loads")
	_main = packed.instantiate()
	root.add_child(_main)
	await _frames(30)

	var player: Player = _main.get_node_or_null("Player")
	_check(player != null, "player exists")
	if player == null:
		_finish()
		return
	_check(player.is_on_floor(), "player stands on the ground after spawn")
	var enemies: Array[Node] = get_nodes_in_group(&"enemies")
	_check(enemies.size() >= 1, "enemies spawned (%d)" % enemies.size())
	# Park the enemies so movement tests are deterministic.
	for e: Node in enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED

	# Movement: push forward for one second.
	var start: Vector3 = player.global_position
	player.debug_move_input = Vector2(0, -1)
	await _frames(60)
	player.debug_move_input = Vector2.ZERO
	var moved: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(moved > 3.0, "player walks forward (moved %.2f m)" % moved)

	# No jumping: the hero steps up a 0.4 m ledge by walking into it.
	await _frames(20)
	var ledge := StaticBody3D.new()
	var lcs := CollisionShape3D.new()
	var lbox := BoxShape3D.new()
	lbox.size = Vector3(4.0, 0.8, 4.0)
	lcs.shape = lbox
	ledge.add_child(lcs)
	root.add_child(ledge)
	var yaw_node: Node3D = (_main.get("camera_rig") as CameraRig).get_yaw_node()
	var fwd0: Vector3 = -yaw_node.global_transform.basis.z
	fwd0.y = 0.0
	fwd0 = fwd0.normalized()
	ledge.global_position = player.global_position + fwd0 * 3.2
	var y_before: float = player.global_position.y
	await _frames(3)
	player.debug_move_input = Vector2(0, -1)
	var max_y: float = y_before
	for _i: int in 60:
		await _frames(1)
		max_y = maxf(max_y, player.global_position.y)
	player.debug_move_input = Vector2.ZERO
	_check(max_y > y_before + 0.3, "hero steps up a 0.4 m ledge without jumping (dy %.2f)" % (max_y - y_before))
	ledge.queue_free()
	await _frames(60)
	_check(player.is_on_floor(), "hero back on the ground")

	# Dash: fast burst, costs stamina, grants i-frames.
	var st0: float = player.stamina
	var p0: Vector3 = player.global_position
	var ok: bool = player.try_dash()
	_check(ok, "dash starts")
	_check(player.is_invulnerable(), "dash grants i-frames")
	_check(not player.take_damage(10.0), "damage ignored during i-frames")
	await _frames(12)
	var dash_dist: float = Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	_check(dash_dist > 2.5, "dash covers distance (%.2f m)" % dash_dist)
	_check(player.stamina < st0, "dash spends stamina")
	await _frames(40)
	_check(player.take_damage(10.0), "damage applies outside i-frames")
	_check(is_equal_approx(player.health, player.max_health - 10.0), "health reduced by damage")

	# Stamina regenerates.
	var st1: float = player.stamina
	await _frames(60)
	_check(player.stamina > st1 or player.stamina >= player.max_stamina, "stamina regenerates")

	_check(is_equal_approx(Engine.time_scale, 1.0), "hitstop always ends (time scale %.2f)" % Engine.time_scale)
	(_main.get("fx") as CombatFx).hitstop_enabled = false
	# Combat: an enemy right in front of the hero dies after enough light combos.
	for e: Node in enemies:
		e.queue_free()
	await _frames(2)
	var foe := Hollow.new()
	root.add_child(foe)
	var fwd: Vector3 = player.get_facing_vector()
	foe.global_position = player.global_position + fwd * 1.8 + Vector3.UP * 0.2
	foe.target = player
	foe.attack_damage = 0.0
	var died: Array[bool] = [false]
	foe.died.connect(func(_x: Hollow) -> void: died[0] = true)
	await _frames(5)
	var hp0: float = foe.health
	var hits: Array[int] = [0]
	player.combat.hit_landed.connect(func(_t: Node3D, _p: Vector3, _a: Dictionary) -> void: hits[0] += 1)
	for i: int in 40:
		if died[0]:
			break
		player.combat.request_light()
		await _frames(8)
	_check(hits[0] > 0, "light attacks land hits (%d)" % hits[0])
	_check(died[0] or foe.health < hp0, "enemy takes damage")
	_check(died[0], "enemy dies after enough damage")
	await _frames(40)

	# RuneScape-style: clicking a monster makes the hero walk to it and auto-attack until it dies.
	var foe2 := Hollow.new()
	root.add_child(foe2)
	foe2.global_position = player.global_position + player.get_facing_vector() * 7.0 + Vector3.UP * 0.2
	foe2.attack_damage = 0.0
	var died2: Array[bool] = [false]
	foe2.died.connect(func(_x: Hollow) -> void: died2[0] = true)
	await _frames(3)
	player.attack_target = foe2
	player.lock_target = foe2
	for i: int in 60:
		if died2[0]:
			break
		await _frames(10)
	_check(died2[0], "auto-attack walks to the clicked monster and kills it")
	_check(player.attack_target == null, "auto-attack stops after the kill")

	# Auto retaliate: an idle hero hit by a monster targets it; switched off, nothing happens.
	var foe3 := Hollow.new()
	root.add_child(foe3)
	foe3.global_position = player.global_position + Vector3(3.0, 0.2, 0.0)
	await _frames(40)
	player.attack_target = null
	player.set_auto_retaliate(false)
	player.take_damage(1.0, Vector3.ZERO, foe3)
	_check(player.attack_target == null, "auto retaliate off: no counterattack")
	await _frames(40)
	player.set_auto_retaliate(true)
	player.take_damage(1.0, Vector3.ZERO, foe3)
	_check(player.attack_target == foe3, "auto retaliate on: hero targets the attacker")
	foe3.queue_free()
	player.attack_target = null
	await _frames(5)

	# The sea is off limits: walking toward the bay stops at the shoreline.
	var arena_t: TestArena = _main.get("arena")
	var sea := Vector3(TestArena.SEA_DIR.x, 0, TestArena.SEA_DIR.y)
	var shore_start: Vector3 = sea * (TestArena.SHORE_S - 12.0) + Vector3(-TestArena.SEA_DIR.y, 0, TestArena.SEA_DIR.x) * 6.0
	shore_start.y = arena_t.height_at(shore_start.x, shore_start.z) + 0.2
	player.global_position = shore_start
	player.velocity = Vector3.ZERO
	await _frames(5)
	player.set_move_target(shore_start + sea * 40.0)
	await _frames(240)
	var ground_here: float = arena_t.height_at(player.global_position.x, player.global_position.z)
	_check(ground_here > TestArena.WATER_LEVEL, "hero stops at the water's edge (ground %.2f)" % ground_here)
	player.clear_orders()
	player.global_position = PLAYER_SPAWN_FOR_TESTS
	await _frames(30)

	# Leash: a Hollow lured far from home walks back and heals.
	var lure := Hollow.new()
	root.add_child(lure)
	lure.global_position = player.global_position + Vector3(4.0, 0.2, 0.0)
	lure.home = lure.global_position + Vector3(40.0, 0.0, 0.0)
	lure.target = player
	lure.attack_damage = 0.0
	await _frames(5)
	lure.health = 20.0
	lure.state = Hollow.State.CHASE
	await _frames(20)
	_check(lure.state == Hollow.State.RETURN, "Hollow beyond its leash returns home")
	await _frames(60)
	_check(lure.health > 20.0, "returning Hollow regenerates")
	lure.queue_free()
	await _frames(2)

	# Skills: use, then cooldown blocks reuse.
	await _frames(30)
	_check(player.combat.use_skill("whirlwind"), "skill Whirlwind activates")
	_check(not player.combat.use_skill("whirlwind"), "skill is on cooldown after use")
	_check(player.combat.get_cooldown("whirlwind") > 9.0, "cooldown runs (%.1f s)" % player.combat.get_cooldown("whirlwind"))
	await _frames(60)
	player.take_damage(30.0)
	await _frames(50)
	var hp_before: float = player.health
	_check(player.combat.use_skill("second_wind"), "skill Second Wind activates")
	_check(player.health > hp_before, "Second Wind heals")
	_check(not player.combat.is_skill_usable("surge"), "Surge Strike needs a target in range")
	await _frames(30)
	player.combat.request_heavy()
	await _frames(5)
	_check(player.combat.is_busy(), "heavy attack starts")
	player.try_dash()
	_check(not player.combat.is_busy(), "dodge cancels attack")
	Engine.time_scale = 1.0

	# Frame time indication (headless, physics only).
	var t0: int = Time.get_ticks_usec()
	await _frames(60)
	var ms: float = float(Time.get_ticks_usec() - t0) / 60000.0
	print("  INFO  headless frame time %.2f ms" % ms)

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("== ALL TESTS PASSED ==")
		quit(0)
	else:
		print("== %d FAILURE(S) ==" % _failures.size())
		quit(1)
