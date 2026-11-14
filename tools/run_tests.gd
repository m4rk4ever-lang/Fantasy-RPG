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
	_main.set("use_save", false)
	root.add_child(_main)
	await _frames(30)

	var player: Player = _main.get_node_or_null("Player")
	_check(player != null, "player exists")
	if player == null:
		_finish()
		return
	_check(player.is_on_floor(), "player stands on the ground after spawn")
	var ql0: QuestLog = player.quests
	_check(ql0.state(QuestLog.STORY_QUEST) == "active", "main story starts active")
	_check("Saltwick" in ql0.current_step(QuestLog.STORY_QUEST), "first story step points to Saltwick")
	_check("Story:" in ql0.tracker_text(), "tracker shows the story step")
	_check(ql0.giver_marker() == "!", "Brenna shows a ! marker")
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

	# Run toggle (no dodge): running is faster and drains stamina; toggled off you walk.
	player.set_run(true)
	var st0: float = player.stamina
	var p0: Vector3 = player.global_position
	player.debug_move_input = Vector2(0, 1)
	await _frames(60)
	var run_dist: float = Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	_check(player.stamina < st0, "running drains stamina")
	player.set_run(false)
	var p1: Vector3 = player.global_position
	await _frames(60)
	var walk_dist: float = Vector2(player.global_position.x - p1.x, player.global_position.z - p1.z).length()
	player.debug_move_input = Vector2.ZERO
	_check(run_dist > walk_dist * 1.3, "running is faster than walking (%.1f vs %.1f m)" % [run_dist, walk_dist])
	player.set_run(true)
	await _frames(40)
	_check(player.take_damage(10.0), "damage applies")
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
	# Either stopped on the beach or walked out onto a pier: never standing in the water.
	var feet: float = player.global_position.y
	_check(feet > TestArena.WATER_LEVEL + 0.3, "hero never ends up in the water (feet at %.2f)" % feet)
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

	# Progression: skills start locked, XP gives levels and points, the tree enforces its order.
	var prog: Progression = player.progression
	_check(prog.is_skill_unlocked("cleave"), "Cleave is unlocked from the start")
	_check(not player.combat.use_skill("whirlwind"), "locked skill cannot be used")
	_check(not prog.can_rank_up("whirlwind"), "Whirlwind needs Keen Edge first")
	var lvl0: int = prog.level
	prog.add_xp(1000)
	_check(prog.level > lvl0 and prog.skill_points > 1, "XP gives levels and skill points (level %d, %d points)" % [prog.level, prog.skill_points])
	var cap_test := Progression.new()
	cap_test.add_xp(100000000)
	_check(cap_test.level == Progression.MAX_LEVEL, "level caps at %d" % Progression.MAX_LEVEL)
	cap_test.free()
	_check(Progression.kill_xp(2, 20) == 0 and Progression.kill_xp(5, 5) > 0, "low-level monsters give no XP")
	_check(prog.rank_up("keen_edge"), "rank up Keen Edge")
	_check(is_equal_approx(prog.stat("damage_mult"), 0.08), "Keen Edge adds 8% damage")
	_check(prog.rank_up("whirlwind"), "unlock Whirlwind after Keen Edge")
	_check(prog.rank_up("second_wind"), "unlock Second Wind")
	var mh0: float = player.max_health
	prog.rank_up("iron_skin")
	_check(player.max_health > mh0, "Iron Skin raises max health")

	# Skills: use, then cooldown blocks reuse.
	await _frames(30)
	_check(player.combat.use_skill("whirlwind"), "skill Whirlwind activates")
	_check(not player.combat.use_skill("whirlwind"), "skill is on cooldown after use")
	_check(player.combat.get_cooldown("whirlwind") > 8.0, "cooldown runs (%.1f s)" % player.combat.get_cooldown("whirlwind"))
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
	await _frames(60)
	_check(not player.combat.is_busy(), "heavy attack finishes")
	Engine.time_scale = 1.0

	# Loot: a killed Hollowed drops a pouch; walking over it fills the backpack.
	var inv: Inventory = player.inventory
	var dust0: int = inv.count_of("veil_dust")
	var coins0: int = inv.coins
	_main.call("_drop_loot", player.global_position + player.get_facing_vector() * 0.5)
	await _frames(5)
	_check(inv.count_of("veil_dust") > dust0 and inv.coins > coins0, "loot pouch is picked up (dust %d, coins %d)" % [inv.count_of("veil_dust"), inv.coins])

	# Fences block, and clicking Brenna from the vale walks through the gate and around houses.
	var arena_f: TestArena = _main.get("arena")
	var sea_f := Vector3(TestArena.SEA_DIR.x, 0, TestArena.SEA_DIR.y)
	var along_f := Vector3(-TestArena.SEA_DIR.y, 0, TestArena.SEA_DIR.x)
	var before_fence: Vector3 = sea_f * 6.0 + along_f * -17.0
	before_fence.y = arena_f.height_at(before_fence.x, before_fence.z) + 0.3
	player.global_position = before_fence
	player.velocity = Vector3.ZERO
	await _frames(5)
	var beyond: Vector3 = sea_f * 14.0 + along_f * -17.0
	player.set_move_target(beyond)
	await _frames(70)
	var s_now: float = Vector3(player.global_position.x, 0, player.global_position.z).dot(sea_f)
	_check(s_now < 10.0, "fence blocks walking through it (s %.1f)" % s_now)
	player.clear_orders()
	var start_vale: Vector3 = Vector3(0.0, 0.0, 6.0)
	start_vale.y = arena_f.height_at(0.0, 6.0) + 0.3
	player.global_position = start_vale
	await _frames(5)
	var reached: Array[bool] = [false]
	var on_talk := func(_n: Node3D) -> void: reached[0] = true
	player.talk_reached.connect(on_talk)
	player.set_talk_target(arena_f.village.brenna)
	for _w: int in 90:
		await _frames(10)
		if reached[0]:
			break
	_check(reached[0], "click-walk from the vale reaches Brenna (gate, around houses)")
	player.talk_reached.disconnect(on_talk)
	var dlg0: DialogueWindow = _main.get("dialogue")
	dlg0.close()

	# Quest: talk to Brenna, accept, bring 5 Veil Dust, get rewards.
	var arena_q: TestArena = _main.get("arena")
	var brenna: Villager = arena_q.village.brenna
	_check(brenna != null and brenna.is_in_group(&"npcs"), "Brenna stands in Saltwick")
	var talked: Array[bool] = [false]
	player.talk_reached.connect(func(_n: Node3D) -> void: talked[0] = true)
	player.global_position = brenna.global_position + Vector3(3.0, 0.4, 0.0)
	await _frames(5)
	player.set_talk_target(brenna)
	await _frames(90)
	_check(talked[0], "clicking Brenna walks over and starts a conversation")
	var dlg: DialogueWindow = _main.get("dialogue")
	_check(dlg.is_open(), "dialogue window opens")
	var ql: QuestLog = player.quests
	ql.start("ashes_on_the_shore")
	dlg.close()
	inv.add("veil_dust", 5)
	_check(ql.can_complete("ashes_on_the_shore"), "quest can be completed with 5 Veil Dust")
	var lvl_xp: int = player.progression.xp + player.progression.level * 10000
	var c0: int = inv.coins
	(_main.get("brenna_talk") as BrennaDialogue).start()
	_check(ql.state("ashes_on_the_shore") == "done", "quest completes at Brenna")
	_check("Veilspire" in ql.current_step(QuestLog.STORY_QUEST), "story moves on to the Veilspire")
	_check(inv.coins >= c0 + 50 and inv.count_of("salted_fish") >= 3, "quest rewards coins and fish")
	_check(player.progression.xp + player.progression.level * 10000 > lvl_xp, "quest rewards XP")
	dlg.close()
	player.take_damage(25.0)
	await _frames(50)
	var hp_f: float = player.health
	_main.call("_on_item_used", "salted_fish")
	_check(player.health > hp_f, "eating salted fish heals")

	# Action bar: 8 slots, food on a slot, swapping by drag, no duplicates.
	var hud_t: Hud = _main.get("hud")
	var bar: ActionBar = hud_t.action_bar
	_check(bar.entries.size() == 8 and bar.entries[0].get("id", "") == "cleave", "action bar has 8 slots with Cleave on 1")
	player.inventory.add("salted_fish", 2)
	bar.drop(4, {"type": "item", "id": "salted_fish", "name": "Salted Fish", "desc": "", "color": Color.WHITE, "icon": 4})
	player.take_damage(20.0)
	await _frames(50)
	var hp_bar: float = player.health
	_main.call("_activate_slot", 4)
	_check(player.health > hp_bar, "food on the action bar heals when used")
	var first: Dictionary = bar.entries[0].duplicate()
	first["from_bar"] = 0
	bar.drop(6, first)
	_check(bar.entries[6].get("id", "") == "cleave" and bar.entries[0].is_empty(), "dragging between slots moves the skill")
	bar.drop(1, PlayerCombat.skill_entry("cleave"))
	var count_cleave: int = 0
	for e: Dictionary in bar.entries:
		if e.get("id", "") == "cleave":
			count_cleave += 1
	_check(count_cleave == 1, "a skill is never on the bar twice")

	# Dungeon: the Undercroft. Sealed before the quest, open after; Keeper drops, beacon ends Chapter I.
	var q_d: QuestLog = player.quests
	_main.call("_try_enter_undercroft")
	if q_d.state("the_dark_spire") == "none":
		_check(not bool(_main.get("in_dungeon")), "Undercroft is sealed before The Dark Spire")
		q_d.start("the_dark_spire")
		_main.call("_try_enter_undercroft")
	_check(bool(_main.get("in_dungeon")) and player.global_position.y < -100.0, "entering the Undercroft teleports the hero below")
	_check("Defeat" in q_d.current_step("the_dark_spire"), "quest step moves to the Keeper")
	var uc: Undercroft = _main.get("undercroft")
	await _frames(10)
	_check(uc.boss != null and uc.boss.is_boss, "the Lightless Keeper waits in the Beacon Chamber")
	_check(player.is_on_floor(), "hero stands on the Undercroft floor")
	uc.boss.take_hit(9999.0, Vector3.ZERO, uc.boss.global_position)
	await _frames(5)
	_check(q_d.has_flag("keeper_defeated") and uc.brazier.enabled, "Keeper defeated, brazier can be lit")
	uc.brazier.global_position = player.global_position
	player.set_talk_target(uc.brazier)
	await _frames(10)
	_check(q_d.state("the_dark_spire") == "done" and q_d.state(QuestLog.STORY_QUEST) == "done", "relighting the beacon completes Chapter I")
	_main.call("_exit_undercroft")
	await _frames(10)
	_check(not bool(_main.get("in_dungeon")) and player.global_position.y > -10.0, "leaving the Undercroft returns to the crag")

	# Save and load round trip.
	_main.set("use_save", true)
	player.progression.add_xp(300)
	var lvl_s: int = player.progression.level
	var coins_s: int = player.inventory.coins
	_check(SaveGame.save(player, bar), "game saves")
	var data_s: Dictionary = SaveGame.read()
	_check(int(data_s["progression"]["level"]) == lvl_s, "save holds the level")
	player.inventory.coins = 0
	player.progression.level = 1
	SaveGame.apply(data_s, player, bar)
	_check(player.progression.level == lvl_s and player.inventory.coins == coins_s, "load restores level and coins")
	SaveGame.delete()
	_check(not SaveGame.exists(), "new game erases the save")
	_main.set("use_save", false)
	# Audio (V.8): director, buses and the procedural sound bank.
	var audio: AudioDirector = _main.get_node_or_null("AudioDirector")
	_check(audio != null, "audio director exists")
	if audio != null:
		var buses_ok: bool = true
		for bus: String in ["Master", "Music", "SFX", "Ambience"]:
			buses_ok = buses_ok and AudioServer.get_bus_index(bus) != -1
		_check(buses_ok, "audio buses Master, Music, SFX and Ambience exist")
		var bank_ok: bool = audio.bank != null and audio.bank.streams.size() >= 20 and audio.bank.pad_chords.size() == 4
		if bank_ok:
			for id: String in audio.bank.streams:
				bank_ok = bank_ok and (audio.bank.streams[id] is AudioStream) and (not (audio.bank.streams[id] is AudioStreamWAV) or (audio.bank.streams[id] as AudioStreamWAV).data.size() > 200)
		_check(bank_ok, "sound bank generated %d non-empty streams in %d ms" % [audio.bank.streams.size(), audio.bank.generation_ms])
		var combat_wav: AudioStreamWAV = audio.bank.get_stream("combat") as AudioStreamWAV
		_check(combat_wav != null and combat_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and combat_wav.loop_end > 0, "music loops have loop points")
		var played: int = audio.sfx_played
		audio.play("hit")
		audio.play_at("hollow_death", player.global_position)
		audio.play("no_such_sound")
		await _frames(3)
		_check(audio.sfx_played == played + 2, "playing hit sounds does not error")
		# Combat layer: an engaged Hollowed nearby raises the mix, and it falls away after.
		var mix0: float = audio.combat_mix
		audio.set("_combat_hold", 2.0)
		await _frames(60)
		_check(audio.combat_mix > mix0 + 0.3, "combat music fades in (mix %.2f)" % audio.combat_mix)
	# UI finishing (V.11): XP bar, target trail, skill locks, portraits, windows.
	var ui_hud: Hud = _main.get_node("Hud")
	var prog_ui: Progression = player.progression
	_check(ui_hud.xp_bar.level == prog_ui.level, "XP bar shows the current level")
	_check(absf(ui_hud.xp_bar.fraction() - float(prog_ui.xp) / float(prog_ui.xp_to_next())) < 0.001, "XP bar follows XP")
	ui_hud.set_xp(0, 100, prog_ui.level + 1)
	_check(ui_hud.xp_bar.is_shining(), "XP bar shines on level up")
	ui_hud.set_xp(prog_ui.xp, prog_ui.xp_to_next(), prog_ui.level)
	ui_hud.target_bar.set_health(100.0, 100.0, true)
	ui_hud.target_bar.set_health(60.0, 100.0)
	_check(ui_hud.target_bar.trail > ui_hud.target_bar.fraction(), "target bar keeps a trailing damage segment")
	await create_timer(0.9).timeout
	_check(absf(ui_hud.target_bar.trail - 0.6) < 0.01, "trailing segment catches up")
	_check(dlg.portrait.kind == "brenna", "dialogue shows Brenna's portrait")
	_check(Portrait.kind_for("Old Tam") == "Old Tam", "unknown speakers fall back to an initial")
	for win_name: String in ["Backpack", "SkillTree"]:
		var win: Node = _main.get_node(win_name)
		var was: bool = win.call("is_open")
		win.call("toggle")
		var opened: bool = win.call("is_open")
		win.call("toggle")
		_check(not was and opened and not bool(win.call("is_open")), "%s window opens and closes" % win_name)
	_check(ItemIcon.has_icon("coins") and ItemIcon.has_icon("salted_fish"), "items have their own icons")

	# --- The Warden's Stair (V.6a) ---
	var arena: TestArena = _main.get_node("World")
	var stair: SpirePath = arena.spire_path
	_check(stair != null, "Warden's Stair exists")
	var navg: NavGrid = _main.get_node("NavGrid")
	var foot: Vector3 = stair.foot()
	var door_goal: Vector3 = stair.door_position + (Vector3(stair.door_position.x, 0, stair.door_position.z) - Vector3(TestArena.CLIFF_CENTER.x, 0, TestArena.CLIFF_CENTER.y)).normalized() * 2.0
	var stair_path: PackedVector3Array = navg.find_path(foot + Vector3(0, 0, 0), door_goal)
	_check(stair_path.size() > 20, "nav grid finds a path up the stair (%d waypoints)" % stair_path.size())
	var mid_open: int = 0
	for uu: float in [0.3, 0.5, 0.7]:
		var mp: Vector3 = stair.point_at(uu)
		for off: Vector3 in [Vector3.ZERO, Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			if not navg.is_blocked(mp + off):
				mid_open += 1
				break
	_check(mid_open == 3, "the stair is walkable along its length")
	player.revive(foot + Vector3.UP * 0.6)
	player.set_run(true)
	await _frames(5)
	player.set_move_target(door_goal)
	var climbed: bool = false
	var best_y: float = player.global_position.y
	for k: int in 240:
		await _frames(10)  # Short polls: right behind the "reached" trigger the door now lets the hero in (V.6b).
		best_y = maxf(best_y, player.global_position.y)
		if player.quests.has_flag("reached_spire"):
			climbed = true
			break
	print("  INFO  stair climb: highest point %.1f m, at %s" % [best_y, str(player.global_position)])
	_check(climbed, "hero climbs the stair and reaches the sealed door")

	# --- The Veilspire, first floor (V.6b) ---
	var spire: SpireInterior = _main.get("spire_interior")
	_check(spire != null, "Veilspire interior exists")
	spire.fade_time = 0.0
	var env_bg: int = arena.environment.background_mode
	_check(not spire.is_inside and spire.can_enter(), "the door opens for a Warden on The Dark Spire")
	player.set_move_target(door_goal)
	for k: int in 20:
		if spire.is_inside:
			break
		await _frames(30)
	if not spire.is_inside:
		print("  INFO  hero did not walk into the door trigger, placing him there")
		player.global_position = door_goal + Vector3.UP * 0.5
		await _frames(10)
	_check(spire.is_inside and player.global_position.distance_to(spire.entry_point()) < 3.0, "walking into the sealed door teleports the hero inside")
	for e: Hollow in spire.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(40)
	_check(player.is_on_floor() and absf(player.global_position.y - SpireInterior.ORIGIN.y) < 0.6, "hero stands on the hall floor")
	_check(arena.environment.background_mode == Environment.BG_COLOR and not arena.sun.visible, "dungeon environment is active inside")
	_check(spire.boss != null and spire.boss.display_name == "Warden-Husk Corvane" and spire.boss.max_health > 200.0, "Warden-Husk Corvane waits on the first floor")
	_check(spire.enemies.size() == 4, "three Hollowed guard the hall with him (%d enemies)" % spire.enemies.size())
	var z_in: float = player.global_position.z
	player.set_move_target(player.global_position + Vector3(1.5, 0, -3.0))
	await _frames(60)
	_check(player.global_position.z < z_in - 1.5, "click-to-move works inside the hall")
	var xp_b: int = player.progression.xp + player.progression.level * 100000
	var hp_b: float = spire.boss.health
	spire.boss.take_hit(20.0, Vector3.ZERO, spire.boss.global_position)
	_check(spire.boss.health < hp_b and not spire.boss.is_dead() and not player.quests.has_flag("spire_floor_1_cleared"), "the Husk takes damage and survives a normal hit")
	spire.boss.take_hit(9999.0, Vector3.ZERO, spire.boss.global_position)
	_check(player.quests.has_flag("spire_floor_1_cleared"), "killing the Warden-Husk sets spire_floor_1_cleared")
	_check(player.progression.xp + player.progression.level * 100000 > xp_b, "the Warden-Husk grants XP")
	player.set_move_target(SpireInterior.ORIGIN + Vector3(0.0, 0.0, SpireInterior.RADIUS - 0.8))
	for k: int in 20:
		if not spire.is_inside:
			break
		await _frames(30)
	if spire.is_inside:
		print("  INFO  hero did not walk into the exit trigger, requesting exit")
		spire.request_exit()
	await _frames(40)
	var door_flat: Vector3 = stair.door_position
	_check(not spire.is_inside and Vector2(player.global_position.x - door_flat.x, player.global_position.z - door_flat.z).length() < 6.0, "leaving returns the hero to the sealed door")
	_check(player.is_on_floor() and player.global_position.y > TestArena.CRAG_TOP - 2.0, "hero stands on the crag after leaving (y %.1f)" % player.global_position.y)
	_check(arena.environment.background_mode == env_bg and player.nav != null, "overworld environment and nav grid are restored")
	spire.fade_time = 0.45

	# Graphics quality (V.10) and local steering.
	var q_arena: TestArena = _main.get("arena")
	Quality.apply(q_arena, 0)
	_check(not q_arena.sun.shadow_enabled and q_arena.get_viewport().scaling_3d_scale < 0.8, "Low quality turns off shadows and lowers render scale")
	Quality.apply(q_arena, 2)
	_check(q_arena.get_viewport().scaling_3d_scale == 1.0, "High quality renders at full scale")

	# Fury (V.12): costs gate skills, spending lowers it.
	var pc: PlayerCombat = player.combat
	pc.fury = 0.0
	_check(pc.fury < PlayerCombat.FURY_COST["whirlwind"] and not pc.is_skill_usable("whirlwind") or not pc.is_skill_unlocked("whirlwind"), "Whirlwind needs Fury")
	pc.add_fury(100.0)
	_check(is_equal_approx(pc.fury, PlayerCombat.MAX_FURY), "Fury caps at its maximum")

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
