extends Node3D
## Game root: assembles world, player, camera and UI, and wires their signals.

const PLAYER_SPAWN := Vector3(0.0, 0.0, 6.0)

var arena: TestArena
var player: Player
var camera_rig: CameraRig
var hud: Hud


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


func _on_player_dashed() -> void:
	camera_rig.kick_fov(6.0)


func _on_player_landed(impact: float) -> void:
	if impact > 0.35:
		camera_rig.add_trauma(impact * 0.45)
