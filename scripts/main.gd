extends Node3D
## Game root: assembles world, player, camera and UI, and wires their signals.

const PLAYER_SPAWN := Vector3(0.0, 0.0, 6.0)
const AUTOSAVE_SECONDS: float = 20.0

## Tests and screenshots switch saving off so they always start fresh.
var use_save: bool = true
var _autosave_timer: float = AUTOSAVE_SECONDS

var arena: TestArena
var player: Player
var camera_rig: CameraRig
var hud: Hud
var fx: CombatFx
var lock_on: LockOn
var clicks: ClickController
var nav: NavGrid
var dialogue: DialogueWindow
var brenna_talk: BrennaDialogue
var ambience: Ambience
var _last_night: float = -1.0
var _area: String = ""
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
	player.walkable_check = _is_walkable
	nav = NavGrid.new()
	nav.name = "NavGrid"
	add_child(nav)
	_build_nav.call_deferred()

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
	# Action bar: the four Vanguard skills on 1-4, slots 5-8 free for more skills or food.
	for i: int in PlayerCombat.SKILLS.size():
		hud.action_bar.assign(i, skill_entry(PlayerCombat.SKILLS[i]["id"]))
	hud.action_bar.slot_activated.connect(_activate_slot)
	player.combat.skill_used.connect(_on_skill_used)
	player.retaliated.connect(func(attacker: Node3D) -> void: lock_on.set_target(attacker))
	player.auto_retaliate_changed.connect(hud.set_retaliate)
	player.run_changed.connect(hud.set_run)
	hud.run_clicked.connect(func() -> void: player.set_run(not player.run_enabled))
	# --- Progression and skill tree ---
	var tree_window := SkillTreeWindow.new()
	tree_window.name = "SkillTree"
	add_child(tree_window)
	tree_window.setup(player.progression)
	hud.skills_clicked.connect(tree_window.toggle)
	var prog: Progression = player.progression
	prog.xp_changed.connect(hud.set_xp)
	prog.xp_changed.connect(func(_x: int, _n: int, _l: int) -> void: hud.set_skill_points(prog.skill_points))
	prog.ranks_changed.connect(func() -> void: hud.set_skill_points(prog.skill_points))
	prog.leveled_up.connect(func(lvl: int) -> void:
		hud.show_banner("Level %d" % lvl, "A skill point awaits. Press K.")
		fx.impact(player.global_position + Vector3.UP * 1.2, Vector3.UP, 1.4))
	hud.set_xp(prog.xp, prog.xp_to_next(), prog.level)
	hud.set_skill_points(prog.skill_points)
	# --- Backpack ---
	var inv_window := InventoryWindow.new()
	inv_window.name = "Backpack"
	add_child(inv_window)
	inv_window.setup(player.inventory)
	inv_window.item_used.connect(_on_item_used)
	hud.backpack_clicked.connect(inv_window.toggle)
	# --- Quests and dialogue ---
	var quest_window := QuestLogWindow.new()
	quest_window.name = "QuestLog"
	add_child(quest_window)
	quest_window.setup(player.quests)
	dialogue = DialogueWindow.new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	brenna_talk = BrennaDialogue.new(dialogue, player.quests, player.progression, hud)
	player.talk_reached.connect(_on_talk_reached)
	var update_tracker := func() -> void:
		hud.set_tracker(player.quests.tracker_text())
		arena.village.brenna.set_marker(player.quests.giver_marker())
	player.quests.changed.connect(update_tracker)
	player.inventory.changed.connect(update_tracker)
	update_tracker.call_deferred()
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
	pause_menu.save_requested.connect(func() -> void:
		if _save():
			hud.toast("Game saved."))
	# --- End pause menu ---
	_load_save.call_deferred()


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
	e.died.connect(func(en: Hollow) -> void: _on_enemy_died(index, en))


func _on_enemy_died(index: int, en: Hollow) -> void:
	var gained: int = Progression.kill_xp(en.level, player.progression.level)
	player.progression.add_xp(gained)
	if gained > 0:
		hud.toast("+%d XP" % gained)
	_drop_loot(en.global_position)
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
	for i: int in ActionBar.SLOTS:
		var e: Dictionary = hud.action_bar.entries[i]
		if e.get("type", "") == "skill" and e.get("id", "") == id:
			hud.action_bar.flash(i)
	match id:
		"surge":
			fx.dust(player.global_position, 1.0)
			camera_rig.kick_fov(8.0)
		"second_wind":
			fx.impact(player.global_position + Vector3.UP * 1.2, Vector3.UP, 0.6)
			fx.dust(player.global_position, 0.6)


func _process(delta: float) -> void:
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		_save()
	# Area names (English in-game names).
	var area: String = "Saltwick" if arena.sea_distance(player.global_position.x, player.global_position.z) > 12.0 else "Warden's Vale"
	if area != _area:
		_area = area
		hud.show_banner(area, "Fishing village of the Saltbound" if area == "Saltwick" else "Beneath the first Veilspire")
	var night: float = arena.day_night.night_factor
	if absf(night - _last_night) > 0.02:
		_last_night = night
		ambience.set_night(night)
	_update_action_bar()
	# Dust puffs from sprint footsteps.
	if player.is_sprinting and player.is_on_floor():
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.17
			fx.dust(player.global_position, 0.15)
	else:
		_step_timer = 0.0


## Land is walkable; water only where a structure (pier) carries you.
func _is_walkable(from: Vector3, to: Vector3) -> bool:
	if arena.height_at(to.x, to.z) > TestArena.WATER_LEVEL + 0.35:
		return true
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(to.x, from.y + 1.0, to.z), Vector3(to.x, from.y - 1.5, to.z), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return not hit.is_empty() and (hit["position"] as Vector3).y > TestArena.WATER_LEVEL + 0.4


## Loot table of a Hollowed: always dust and coins, sometimes claws or a sigil.
func _drop_loot(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var items: Array = [["coins", rng.randi_range(5, 15)], ["veil_dust", rng.randi_range(1, 2)]]
	if rng.randf() < 0.35:
		items.append(["hollow_fang", 1])
	if rng.randf() < 0.12:
		items.append(["warden_sigil", 1])
	var drop := LootDrop.new()
	drop.items = items
	add_child(drop)
	drop.global_position = Vector3(at.x, arena.height_at(at.x, at.z) + 0.05, at.z)
	drop.picked_up.connect(_on_loot_picked)


func _on_loot_picked(items: Array) -> void:
	for it: Array in items:
		if player.inventory.add(it[0], it[1]):
			var item_name: String = "coins" if it[0] == "coins" else Inventory.item_data(it[0])["name"]
			hud.toast("+%d %s" % [it[1], item_name])
		else:
			hud.toast("Your backpack is full.")


func _on_item_used(id: String) -> void:
	var data: Dictionary = Inventory.item_data(id)
	if data.has("heal") and player.health < player.max_health:
		player.inventory.remove(id, 1)
		player.heal(float(data["heal"]))
		hud.toast("You eat the %s." % data["name"].to_lower())
	elif data.has("heal"):
		hud.toast("You are not hungry. Or hurt.")


func _on_talk_reached(npc: Node3D) -> void:
	if npc == arena.village.brenna:
		brenna_talk.start()
	elif npc is Villager and not (npc as Villager).lines.is_empty():
		hud.toast((npc as Villager).lines[0])


## Physics needs one frame to register the static colliders before the grid can be probed.
func _build_nav() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t0: int = Time.get_ticks_msec()
	nav.build(arena)
	player.nav = nav
	print("NavGrid built in %d ms" % (Time.get_ticks_msec() - t0))


## Action-bar entry for a combat skill (also used by drag-and-drop from the skill tree).
static func skill_entry(id: String) -> Dictionary:
	return PlayerCombat.skill_entry(id)


static func item_entry(id: String) -> Dictionary:
	var d: Dictionary = Inventory.item_data(id)
	if d.is_empty():
		return {}
	return {"type": "item", "id": id, "name": d["name"], "desc": d["desc"], "color": d["color"], "icon": 4}


func _unhandled_input(event: InputEvent) -> void:
	for i: int in ActionBar.SLOTS:
		if event.is_action_pressed("skill_%d" % (i + 1)):
			_activate_slot(i)
			get_viewport().set_input_as_handled()
			return


func _activate_slot(i: int) -> void:
	var e: Dictionary = hud.action_bar.entries[i]
	match e.get("type", ""):
		"skill":
			player.combat.use_skill(e["id"])
		"item":
			if player.inventory.count_of(e["id"]) > 0:
				_on_item_used(e["id"])
				hud.action_bar.flash(i)
			else:
				hud.toast("You have no %s left." % e["name"])


func _update_action_bar() -> void:
	for i: int in ActionBar.SLOTS:
		var e: Dictionary = hud.action_bar.entries[i]
		match e.get("type", ""):
			"skill":
				var id: String = e["id"]
				hud.action_bar.set_cooldown(i, player.combat.get_cooldown(id), float(e["cooldown"]))
				var unlocked: bool = player.combat.is_skill_unlocked(id)
				hud.action_bar.set_usable(i, unlocked and (player.combat.get_cooldown(id) > 0.0 or player.combat.is_skill_usable(id)))
			"item":
				var n: int = player.inventory.count_of(e["id"])
				hud.action_bar.set_count(i, n)
				hud.action_bar.set_usable(i, n > 0)


func _save() -> bool:
	if not use_save:
		return false
	return SaveGame.save(player, hud.action_bar)


## Load after the world, nav grid and UI exist. Called deferred from _ready.
func _load_save() -> void:
	if not use_save:
		return
	var data: Dictionary = SaveGame.read()
	if data.is_empty():
		return
	SaveGame.apply(data, player, hud.action_bar)
	player._apply_progression()
	hud.toast("Welcome back, Warden.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save()
