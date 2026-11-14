extends Node3D
## Game root: assembles world, player, camera and UI, and wires their signals.

const PLAYER_SPAWN := Vector3(0.0, 0.0, 6.0)
const AUTOSAVE_SECONDS: float = 60.0

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
var undercroft: Undercroft
var in_dungeon: bool = false
var _overworld_env: Dictionary = {}
var _undercroft_spawned: bool = false
var dialogue: DialogueWindow
var brenna_talk: BrennaDialogue
var ambience: Ambience
var spire_interior: SpireInterior
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
	player.combat.fury_changed.connect(hud.set_resource)
	hud.set_resource(0.0, PlayerCombat.MAX_FURY)

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

	# --- Undercroft (first dungeon) ---
	undercroft = Undercroft.new()
	undercroft.name = "Undercroft"
	add_child(undercroft)
	undercroft.build()
	undercroft.boss_defeated.connect(func() -> void:
		player.quests.set_flag("keeper_defeated")
		hud.show_banner("The Keeper falls", "Relight the beacon"))
	undercroft.beacon_lit.connect(_on_beacon_lit)
	arena.spire_path.reached_door.connect(_on_spire_door)
	_setup_spire_interior()
	Quality.apply(arena, Quality.load_level())
	_load_save.call_deferred()
	# --- Audio (V.8): procedural sound, ambience and music; see scripts/audio/ ---
	var audio := AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.setup(player, arena)
	# --- End audio ---


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
	if pos.y > -100.0:  # Dungeons sit far below; their floor is not the terrain.
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
	if player.global_position.y > 14.0 and Vector2(player.global_position.x, player.global_position.z).distance_to(TestArena.CLIFF_CENTER) < 30.0:
		area = "The Warden's Stair"
	if in_dungeon:
		area = "Undercroft of the Veilspire"
	if spire_interior != null and spire_interior.is_inside:
		area = _area
	if area != _area:
		_area = area
		hud.show_banner(area, "Fishing village of the Saltbound" if area == "Saltwick" else ("Dungeon · Level 3-5" if in_dungeon else ("The way up to the first Veilspire" if area == "The Warden's Stair" else "Beneath the first Veilspire")))
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
	if from.y < -100.0:
		return true  # Inside the Undercroft: walls handle everything.
	if arena.height_at(to.x, to.z) > TestArena.WATER_LEVEL + 0.35:
		return true
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(to.x, from.y + 1.0, to.z), Vector3(to.x, from.y - 1.5, to.z), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return not hit.is_empty() and (hit["position"] as Vector3).y > TestArena.WATER_LEVEL + 0.4


## Loot table of a Hollowed: always dust and coins, sometimes claws or a sigil.
func _drop_loot(at: Vector3, extra: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var items: Array = [["coins", rng.randi_range(5, 15)], ["veil_dust", rng.randi_range(1, 2)]]
	if rng.randf() < 0.35:
		items.append(["hollow_fang", 1])
	if rng.randf() < 0.12:
		items.append(["warden_sigil", 1])
	items.append_array(extra)
	var drop := LootDrop.new()
	drop.items = items
	add_child(drop)
	var gy: float = at.y - 0.25 if at.y < -100.0 else arena.height_at(at.x, at.z) + 0.05
	drop.global_position = Vector3(at.x, gy, at.z)
	drop.picked_up.connect(_on_loot_picked)


func _on_loot_picked(items: Array) -> void:
	for it: Array in items:
		if player.inventory.add(it[0], it[1]):
			var item_name: String = "coins" if it[0] == "coins" else Inventory.item_data(it[0])["name"]
			hud.toast("+%d %s" % [it[1], item_name], it[0])
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
	if npc == arena.undercroft_door:
		_try_enter_undercroft()
	elif npc == undercroft.exit_portal:
		_exit_undercroft()
	elif npc == undercroft.brazier:
		if undercroft.brazier.enabled:
			undercroft.light_beacon()
	elif npc == arena.village.brenna:
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
	_debug_url_hook()


## Test hook for the web build: ?test=undercroft walks straight into the Undercroft (used by tools/web_check.mjs).
func _debug_url_hook() -> void:
	if not OS.has_feature("web"):
		return
	var q: Variant = JavaScriptBridge.eval("window.location.search", true)
	if typeof(q) == TYPE_STRING and String(q).contains("test=undercroft"):
		use_save = false
		player.quests.start("the_dark_spire")
		await get_tree().create_timer(1.0).timeout
		print("TEST: entering Undercroft")
		_try_enter_undercroft()
		await get_tree().create_timer(4.0).timeout
		print("TEST: inside at ", player.global_position)


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


## Reaching the sealed door at the top of the Warden's Stair.
func _on_spire_door() -> void:
	if player.quests.has_flag("reached_spire"):
		return
	player.quests.set_flag("reached_spire")
	if spire_interior.can_enter():
		hud.show_banner("The Veilspire", "The runes of the Veil stir")
	else:
		hud.show_banner("The Veilspire", "The door is sealed by the Veil")


# --- Veilspire, first floor (V.6b): optional hall above the Undercroft ---
func _setup_spire_interior() -> void:
	spire_interior = SpireInterior.new()
	spire_interior.name = "SpireInterior"
	add_child(spire_interior)
	spire_interior.setup(player, arena, camera_rig)
	spire_interior.entered.connect(func() -> void:
		ambience.visible = false
		_area = "The Veilspire"
		if spire_interior.is_cleared():
			hud.show_banner("The Veilspire", "The Hall of the First Oath lies silent")
		else:
			hud.show_banner("The Veilspire", "Hall of the First Oath"))
	spire_interior.exited.connect(func() -> void: ambience.visible = true)
	player.died.connect(func() -> void: ambience.visible = true)
	spire_interior.enemy_died.connect(_on_spire_enemy_died)
	spire_interior.boss_slammed.connect(func(pos: Vector3) -> void:
		fx.slam(pos)
		camera_rig.add_trauma(0.6))
	spire_interior.floor_cleared.connect(func() -> void:
		hud.show_banner("The Hall of the First Oath", "Warden-Husk Corvane is at rest. The stair above is broken."))


func _on_spire_enemy_died(en: Hollow, is_boss: bool) -> void:
	var gained: int = Progression.kill_xp(en.level, player.progression.level) * (4 if is_boss else 1)
	player.progression.add_xp(gained)
	if gained > 0:
		hud.toast("+%d XP" % gained)
	var extra: Array = [["coins", 60], ["veil_dust", 4], ["warden_sigil", 1]] if is_boss else []
	_drop_loot(en.global_position, extra)
	camera_rig.add_trauma(0.6 if is_boss else 0.35)
	fx.hitstop(0.2 if is_boss else 0.12)
# --- End Veilspire, first floor ---


## Load after the world, nav grid and UI exist. Called deferred from _ready.
func _load_save() -> void:
	if not use_save:
		return
	var data: Dictionary = SaveGame.read()
	if data.is_empty():
		return
	SaveGame.apply(data, player, hud.action_bar)
	player._apply_progression()
	spire_interior.handle_game_loaded()
	hud.toast("Welcome back, Warden.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save()


func _try_enter_undercroft() -> void:
	var q: QuestLog = player.quests
	if q.state("the_dark_spire") == "none":
		hud.toast("A cold draft seeps from the sealed door. Perhaps someone in Saltwick knows more.")
		return
	if q.state("the_dark_spire") == "done":
		hud.toast("The Undercroft is quiet now. The beacon burns above.")
	_enter_undercroft()


func _enter_undercroft() -> void:
	in_dungeon = true
	player.clear_orders()
	lock_on.set_target(null)
	player.global_position = undercroft.entrance_point
	player.velocity = Vector3.ZERO
	player.face_direction(Vector3.FORWARD)
	camera_rig.set_angles(0.0, deg_to_rad(-26.0))
	camera_rig.global_position = player.global_position + Vector3.UP * camera_rig.height_offset
	player.quests.set_flag("entered_undercroft")
	# Dungeon lighting: dark and grim (SMAAK.md), the torches do the work.
	var env: Environment = arena.environment
	_overworld_env = {"running": arena.day_night.running}
	arena.day_night.running = false
	arena.sun.visible = false
	arena.moon.visible = false
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1e2125")
	env.ambient_light_color = Color("8f8c80")
	env.ambient_light_energy = 1.15
	env.fog_light_color = Color("2a2e35")
	env.fog_density = 0.012
	_set_hero_lantern(true)
	env.fog_height_density = 0.0
	env.glow_intensity = 0.15
	ambience.visible = false
	if not _undercroft_spawned and player.quests.state("the_dark_spire") != "done":
		_undercroft_spawned = true
		for h: Hollow in undercroft.spawn_enemies(player):
			h.died.connect(_on_dungeon_enemy_died)
			if h.is_boss:
				h.phase_two.connect(_on_boss_phase_two)


var _lantern: OmniLight3D


## A warm lantern glow around the hero in dungeons, so the hero and nearby foes always read.
func _set_hero_lantern(on: bool) -> void:
	if _lantern == null:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color("ffc98a")
		_lantern.light_energy = 1.1
		_lantern.omni_range = 7.0
		_lantern.position = Vector3(0, 2.2, 0.3)
		player.add_child(_lantern)
	_lantern.visible = on


func _on_dungeon_enemy_died(en: Hollow) -> void:
	var gained: int = Progression.kill_xp(en.level, player.progression.level) * (4 if en.is_boss else 1)
	player.progression.add_xp(gained)
	hud.toast("+%d XP" % gained)
	camera_rig.add_trauma(0.35)
	_drop_loot(en.global_position)


func _on_boss_phase_two(b: Hollow) -> void:
	hud.show_banner("Aldric calls the Hollowed", "")
	for k: int in 2:
		var add := Hollow.new()
		add.level = 3
		add.max_health = 50.0
		add.attack_damage = 10.0
		undercroft.add_child(add)
		add.global_position = b.global_position + Vector3(-4.0 + 8.0 * k, 0.3, 4.0)
		add.home = add.global_position
		add.target = player
		add.died.connect(_on_dungeon_enemy_died)


func _exit_undercroft() -> void:
	in_dungeon = false
	_set_hero_lantern(false)
	player.clear_orders()
	lock_on.set_target(null)
	player.global_position = arena.undercroft_door_outside
	player.velocity = Vector3.ZERO
	camera_rig.global_position = player.global_position + Vector3.UP * camera_rig.height_offset
	var env: Environment = arena.environment
	env.background_mode = Environment.BG_SKY
	env.fog_density = 0.0012
	env.fog_height_density = 0.0015
	env.glow_intensity = 0.5
	arena.day_night.running = bool(_overworld_env.get("running", true))
	arena.day_night.apply()
	ambience.visible = true


func _on_beacon_lit() -> void:
	var q: Dictionary = player.quests.finish("the_dark_spire")
	player.progression.add_xp(int(q.get("reward_xp", 0)))
	arena.light_beacon()
	hud.show_banner("Chapter I complete", "The Veilspire burns again")
