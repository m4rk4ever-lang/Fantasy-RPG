extends SceneTree
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

	# Movement: push forward for one second.
	var start: Vector3 = player.global_position
	player.debug_move_input = Vector2(0, -1)
	await _frames(60)
	player.debug_move_input = Vector2.ZERO
	var moved: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(moved > 3.0, "player walks forward (moved %.2f m)" % moved)

	# Jump: should leave the ground then land again.
	await _frames(20)
	var y0: float = player.global_position.y
	player.request_jump()
	await _frames(12)
	_check(player.global_position.y > y0 + 0.5, "player jumps (dy %.2f)" % (player.global_position.y - y0))
	await _frames(90)
	_check(player.is_on_floor(), "player lands after jump")

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
