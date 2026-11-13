extends Node3D
## Game root: assembles world, player, camera and UI, and wires their signals.

const PLAYER_SPAWN := Vector3(0.0, 0.0, 6.0)

var arena: TestArena
var player: Player
var camera_rig: CameraRig
var hud: Hud
var fx: CombatFx
var lock_on: LockOn
var clicks: ClickController
var ambience: Ambience
var _last_night: float = -1.0
var _step_timer: float = 0.0
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
	camera_rig.set_angles(0.0, deg_to_rad(-24.0))
	camera_rig.set_zoom(8.0)
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
	clicks = ClickController.new()
	clicks.name = "ClickController"
	add_child(clicks)
	clicks.setup(player, camera_rig, lock_on)
	hud.skill_bar.setup(PlayerCombat.SKILLS)
	hud.skill_bar.skill_clicked.connect(func(id: String) -> void: player.combat.use_skill(id))
	player.combat.skill_used.connect(_on_skill_used)
	player.retaliated.connect(func(attacker: Node3D) -> void: lock_on.set_target(attacker))
	player.auto_retaliate_changed.connect(hud.set_retaliate)
	hud.retaliate_clicked.connect(func() -> void: player.set_auto_retaliate(not player.auto_retaliate))
	for i: int in _enemy_spawns.size():
		_spawn_enemy(i)
	# --- End combat ---

	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup(player, arena)

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
	if player.is_on_floor():
		fx.dust(player.global_position, 0.8)


func _on_player_landed(impact: float) -> void:
	fx.dust(player.global_position, 0.3 + impact)
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


func _on_skill_used(id: String) -> void:
	hud.skill_bar.flash(id)
	match id:
		"surge":
			fx.dust(player.global_position, 1.0)
			camera_rig.kick_fov(8.0)
		"second_wind":
			fx.impact(player.global_position + Vector3.UP * 1.2, Vector3.UP, 0.6)
			fx.dust(player.global_position, 0.6)


func _process(delta: float) -> void:
	var night: float = arena.day_night.night_factor
	if absf(night - _last_night) > 0.02:
		_last_night = night
		ambience.set_night(night)
	for sk: Dictionary in PlayerCombat.SKILLS:
		var id: String = sk["id"]
		hud.skill_bar.set_cooldown(id, player.combat.get_cooldown(id), sk["cooldown"])
		hud.skill_bar.set_usable(id, player.combat.get_cooldown(id) > 0.0 or player.combat.is_skill_usable(id))
	# Dust puffs from sprint footsteps.
	if player.is_sprinting and player.is_on_floor():
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.17
			fx.dust(player.global_position, 0.15)
	else:
		_step_timer = 0.0
