extends Node3D
## Game root: assembles world, player, camera and UI, and wires their signals.

const PLAYER_SPAWN := Vector3(0.0, 0.0, 6.0)

var arena: TestArena
var player: Player
var camera_rig: CameraRig
var hud: Hud
var fx: CombatFx
var lock_on: LockOn
var _enemy_spawns: Array[Vector3] = [Vector3(-6.0, 0.0, -10.0), Vector3(7.0, 0.0, -14.0), Vector3(-1.0, 0.0, -24.0)]


func _ready() -> void:
	arena = TestArena.new()
	arena.name = "World"
	add_child(arena)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = PLAYER_SPAWN + Vector3.UP * (arena.height_at(PLAYER_SPAWN.x, PLAYER_SPAWN.z) + 0.1)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.set_target(player)
	camera_rig.set_angles(0.0, deg_to_rad(-12.0))
	player.camera_basis_source = camera_rig.get_yaw_node()

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	player.stamina_changed.connect(hud.set_stamina)
	player.health_changed.connect(hud.set_health)
	hud.set_stamina(player.stamina, player.max_stamina)
	hud.set_health(player.health, player.max_health)

	player.dashed.connect(_on_player_dashed)
	player.landed.connect(_on_player_landed)
	player.hurt.connect(_on_player_hurt)
	player.died.connect(_on_player_died)

	# --- Combat ---
	fx = CombatFx.new()
	fx.name = "CombatFx"
	add_child(fx)
	player.combat.hit_landed.connect(_on_hit_landed)
	player.combat.heavy_impact.connect(_on_heavy_impact)
	lock_on = LockOn.new()
	lock_on.name = "LockOn"
	add_child(lock_on)
	lock_on.setup(player, camera_rig)
	lock_on.target_changed.connect(hud.set_target)
	for i: int in _enemy_spawns.size():
		_spawn_enemy(i)
	# --- End combat ---

	# --- Pause menu ---
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.mouse_sensitivity = camera_rig.mouse_sensitivity
	pause_menu.stick_sensitivity = camera_rig.stick_sensitivity
	add_child(pause_menu)
	pause_menu.sensitivity_changed.connect(_on_sensitivity_changed)
	# --- End pause menu ---


func _on_player_dashed() -> void:
	camera_rig.kick_fov(6.0)


func _on_player_landed(impact: float) -> void:
	if impact > 0.35:
		camera_rig.add_trauma(impact * 0.45)


func _on_sensitivity_changed(mouse: float, stick: float) -> void:
	camera_rig.mouse_sensitivity = mouse
	camera_rig.stick_sensitivity = stick


func _spawn_enemy(index: int) -> void:
	var at: Vector3 = _enemy_spawns[index]
	at.y = arena.height_at(at.x, at.z) + 0.2
	var e := Hollow.new()
	e.name = "Hollow%d" % index
	add_child(e)
	e.global_position = at
	e.home = at
	e.target = player
	e.died.connect(func(_en: Hollow) -> void: _on_enemy_died(index))


func _on_enemy_died(index: int) -> void:
	camera_rig.add_trauma(0.35)
	fx.hitstop(0.12)
	# Training valley: the Hollowed reform after a while.
	get_tree().create_timer(7.0).timeout.connect(func() -> void: _spawn_enemy(index))


func _on_hit_landed(_target: Node3D, pos: Vector3, attack: Dictionary) -> void:
	fx.hitstop(attack.get("hitstop", 0.05))
	fx.impact(pos, (pos - player.global_position - Vector3.UP).normalized(), attack.get("damage", 10.0) / 14.0)
	camera_rig.add_trauma(attack.get("shake", 0.2))


func _on_heavy_impact(pos: Vector3) -> void:
	pos.y = arena.height_at(pos.x, pos.z)
	fx.slam(pos)
	camera_rig.add_trauma(0.45)


func _on_player_hurt(_amount: float, _dir: Vector3) -> void:
	hud.flash_damage()
	camera_rig.add_trauma(0.5)
	fx.hitstop(0.06)


func _on_player_died() -> void:
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		var at: Vector3 = PLAYER_SPAWN + Vector3.UP * (arena.height_at(PLAYER_SPAWN.x, PLAYER_SPAWN.z) + 0.1)
		player.revive(at))
