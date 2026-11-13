class_name AudioDirector
extends Node
## Owns all game audio: buses, pooled SFX players, ambience loops and the music mix.
## Sounds come from SoundBank (synthesized at startup). Wire it with setup(); it then
## listens to player, combat, enemy, loot, quest and UI signals by itself.
##
## Music: sustained pad loops crossfade through a D dorian progression over a low drone,
## with a sequenced harp arpeggio on top. A looping combat layer fades in while Hollowed
## are aggro'd near the player and fades out a few seconds after the fight ends.

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"

const CHORD_SECONDS: float = 8.0
const HARP_STEP: float = 0.5
const COMBAT_RANGE: float = 22.0
const COMBAT_HOLD: float = 4.0

## Harp notes per chord, in semitones above the pluck sample (A3).
const HARP_NOTES: Array[Array] = [
	[5, 8, 12, 17, 20, 24],
	[3, 7, 10, 15, 19, 22],
	[-2, 2, 5, 10, 14, 17],
	[0, 5, 7, 12, 17, 19],
]
## Index into HARP_NOTES per step; -1 rests.
const HARP_PATTERN: Array[int] = [0, 2, 3, -1, 4, 3, 2, -1, 1, 3, 5, -1, 4, -1, 2, -1]

var bank: SoundBank
var player: Player
var arena: TestArena
## 0 = exploration, 1 = full combat layer. Read by tests.
var combat_mix: float = 0.0
var sfx_played: int = 0

var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _sfx3d: Array[AudioStreamPlayer3D] = []
var _sfx3d_i: int = 0
var _harp: Array[AudioStreamPlayer] = []
var _harp_i: int = 0
var _pads: Array[AudioStreamPlayer] = []
var _pad_gain: Array[float] = [0.0, 0.0]
var _pad_active: int = 0
var _chord: int = 0
var _chord_t: float = 0.0
var _harp_t: float = 0.0
var _harp_step: int = 0
var _drone: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _sea: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _gull: AudioStreamPlayer
var _gull_t: float = 6.0
var _music_fade: float = 0.0
var _combat_target: float = 0.0
var _combat_hold: float = 0.0
var _combat_check: float = 0.0
var _step_t: float = 0.0
var _time: float = 0.0
var _unlocked: bool = true
var _enemy_health: Dictionary = {}
var _quest_states: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Creates the Music, SFX and Ambience buses under Master (idempotent).
static func ensure_buses() -> void:
	for bus: StringName in [BUS_MUSIC, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	ensure_buses()
	bank = SoundBank.new()
	bank.generate()
	print("SoundBank generated %d streams in %d ms" % [bank.streams.size(), bank.generation_ms])
	# Browsers keep audio suspended until the first user gesture: stay silent until then.
	_unlocked = not OS.has_feature("web")

	for i: int in 10:
		_sfx.append(_make_player(BUS_SFX))
	for i: int in 6:
		var p := AudioStreamPlayer3D.new()
		p.bus = BUS_SFX
		p.unit_size = 9.0
		p.max_distance = 60.0
		p.attenuation_filter_cutoff_hz = 20500.0
		add_child(p)
		_sfx3d.append(p)
	for i: int in 5:
		_harp.append(_make_player(BUS_MUSIC, "pluck"))
	for i: int in 2:
		_pads.append(_make_player(BUS_MUSIC))
	_drone = _make_player(BUS_MUSIC, "drone")
	_combat = _make_player(BUS_MUSIC, "combat")
	_sea = _make_player(BUS_AMBIENCE, "sea")
	_wind = _make_player(BUS_AMBIENCE, "wind")
	_crickets = _make_player(BUS_AMBIENCE, "crickets")
	_gull = _make_player(BUS_AMBIENCE, "gull")
	_pads[0].stream = bank.pad_chords[0]
	_pad_gain[0] = 1.0
	if _unlocked:
		_start_loops()


func _make_player(bus: StringName, stream_id: String = "") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -60.0
	if stream_id != "":
		p.stream = bank.get_stream(stream_id)
	add_child(p)
	return p


## Hooks the director to the game. Enemies, loot drops and buttons that appear later
## are picked up through SceneTree.node_added.
func setup(p_player: Player, p_arena: TestArena) -> void:
	player = p_player
	arena = p_arena
	player.hurt.connect(func(_a: float, _d: Vector3) -> void: play("player_hurt", -3.0, 1.0, 0.06))
	player.died.connect(func() -> void: play("hollow_death", -6.0, 0.6))
	player.dashed.connect(func() -> void: play("swing_light", -8.0, 0.7, 0.05))
	player.landed.connect(func(impact: float) -> void:
		play(_step_sound(), linear_to_db(clampf(0.35 + impact, 0.3, 1.0)) - 4.0, 0.7, 0.05))
	var combat: PlayerCombat = player.combat
	combat.attack_started.connect(_on_attack_started)
	combat.hit_landed.connect(func(_t: Node3D, _pos: Vector3, attack: Dictionary) -> void:
		var dmg: float = attack.get("damage", 10.0)
		play("hit", -5.0 + clampf(dmg / 10.0, 0.0, 4.0), clampf(1.15 - dmg / 80.0, 0.75, 1.15), 0.07))
	combat.heavy_impact.connect(func(_pos: Vector3) -> void: play("slam", -2.0, 1.0, 0.05))
	combat.skill_used.connect(_on_skill_used)
	player.progression.leveled_up.connect(func(_lvl: int) -> void: play("level_up", -4.0))
	for id: String in QuestLog.QUESTS:
		_quest_states[id] = player.quests.state(id)
	player.quests.changed.connect(_on_quests_changed)
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		_hook_node(e)
	for b: Node in get_tree().root.find_children("*", "BaseButton", true, false):
		_hook_node(b)
	get_tree().node_added.connect(_hook_node)


func _hook_node(n: Node) -> void:
	if n is Hollow:
		var e: Hollow = n
		if not e.died.is_connected(_on_enemy_died):
			e.died.connect(_on_enemy_died)
			e.health_changed.connect(_on_enemy_health.bind(e))
	elif n is LootDrop:
		(n as LootDrop).picked_up.connect(func(_items: Array) -> void: play("coin", -6.0, 1.0, 0.08))
	elif n is BaseButton:
		var b: BaseButton = n
		if not b.pressed.is_connected(_on_ui_click):
			b.pressed.connect(_on_ui_click)


# --- Playback -----------------------------------------------------------------

## Plays a one-shot on the SFX bus. `jitter` randomizes pitch by +/- that fraction.
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.0) -> void:
	if not _unlocked or bank == null or not bank.streams.has(id):
		return
	var p: AudioStreamPlayer = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = bank.get_stream(id)
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch * (1.0 + _rng.randf_range(-jitter, jitter)), 0.05)
	p.play()
	sfx_played += 1


## Plays a one-shot at a world position.
func play_at(id: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.0) -> void:
	if not _unlocked or bank == null or not bank.streams.has(id):
		return
	var p: AudioStreamPlayer3D = _sfx3d[_sfx3d_i]
	_sfx3d_i = (_sfx3d_i + 1) % _sfx3d.size()
	p.stream = bank.get_stream(id)
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch * (1.0 + _rng.randf_range(-jitter, jitter)), 0.05)
	p.play()
	sfx_played += 1


func _start_loops() -> void:
	for p: AudioStreamPlayer in [_pads[_pad_active], _drone, _sea, _wind, _crickets]:
		if not p.playing:
			p.play()


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch or event is InputEventJoypadButton) and event.is_pressed():
		_unlocked = true
		_start_loops()


static func _db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.001))


# --- Signal handlers ----------------------------------------------------------

func _on_attack_started(attack_name: String) -> void:
	match attack_name:
		"heavy":
			play("swing_heavy", -4.0, 1.0, 0.05)
		"surge", "whirlwind":
			pass  # Covered by the skill sound.
		_:
			play("swing_light", -6.0, 1.0, 0.1)


func _on_skill_used(id: String) -> void:
	match id:
		"cleave":
			play("cleave", -4.0)
		"surge":
			play("surge", -3.0)
		"whirlwind":
			play("whirlwind", -3.0)
		"second_wind":
			play("second_wind", -5.0)


func _on_enemy_health(value: float, _max_value: float, e: Hollow) -> void:
	var key: int = e.get_instance_id()
	var before: float = _enemy_health.get(key, value + 1.0 if value < _max_value else value)
	_enemy_health[key] = value
	if value < before and value > 0.0:
		play_at("hollow_hurt", e.global_position + Vector3.UP, 0.0, 1.0, 0.12)


func _on_enemy_died(e: Hollow) -> void:
	_enemy_health.erase(e.get_instance_id())
	play_at("hollow_death", e.global_position + Vector3.UP, 2.0, 1.0, 0.08)


func _on_quests_changed() -> void:
	for id: String in QuestLog.QUESTS:
		var s: String = player.quests.state(id)
		if s == "done" and _quest_states.get(id, "none") != "done":
			play("quest_complete", -3.0)
		_quest_states[id] = s


func _on_ui_click() -> void:
	play("ui_click", -8.0, 1.0, 0.04)


# --- Per-frame mix ------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_time += delta
	if not _unlocked:
		return
	var in_world: bool = player != null and arena != null and is_instance_valid(player)
	if in_world and not get_tree().paused:
		_update_footsteps(delta)
		_update_combat_state(delta)
	_update_music(delta)
	if in_world:
		_update_ambience(delta)


func _step_sound() -> String:
	var pos: Vector3 = player.global_position
	# Standing clearly above the terrain means a pier, bridge or floor: hard surface.
	return "step_stone" if pos.y - arena.height_at(pos.x, pos.z) > 0.3 else "step_grass"


func _update_footsteps(delta: float) -> void:
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if not player.is_on_floor() or speed < 1.2:
		_step_t = minf(_step_t, 0.08)
		return
	_step_t -= delta
	if _step_t > 0.0:
		return
	_step_t = clampf(2.1 / speed, 0.26, 0.5)
	var id: String = _step_sound()
	var pos: Vector3 = player.global_position
	var pitch: float = 1.0
	var vol: float = -9.0 if player.is_sprinting else -12.0
	if id == "step_stone":
		pitch = 0.8  # Planks sound lower than the click itself.
	elif arena.height_at(pos.x, pos.z) < TestArena.WATER_LEVEL + 1.0:
		pitch = 0.75  # Wet sand at the waterline.
	play(id, vol, pitch, 0.12)


func _update_combat_state(delta: float) -> void:
	_combat_check -= delta
	_combat_hold = maxf(_combat_hold - delta, 0.0)
	if _combat_check <= 0.0:
		_combat_check = 0.25
		if _enemies_engaged():
			_combat_hold = COMBAT_HOLD
	_combat_target = 1.0 if _combat_hold > 0.0 else 0.0


## True while a living Hollowed near the player is chasing or fighting.
func _enemies_engaged() -> bool:
	if player.health <= 0.0:
		return false
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Hollow
		if e == null or not e.is_inside_tree() or e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		match e.state:
			Hollow.State.CHASE, Hollow.State.WINDUP, Hollow.State.ATTACK, Hollow.State.RECOVER, Hollow.State.STAGGER:
				if e.global_position.distance_to(player.global_position) < COMBAT_RANGE:
					return true
	return false


func _update_music(delta: float) -> void:
	_music_fade = minf(_music_fade + delta / 4.0, 1.0)
	# Combat comes in fast (1.2 s) and leaves slowly (3.5 s).
	var rate: float = 1.0 / 1.2 if _combat_target > combat_mix else 1.0 / 3.5
	combat_mix = move_toward(combat_mix, _combat_target, delta * rate)
	var explore: float = _music_fade * (1.0 - 0.55 * combat_mix)

	# Pad progression: the next chord fades in on the idle player.
	_chord_t += delta
	if _chord_t >= CHORD_SECONDS:
		_chord_t -= CHORD_SECONDS
		_chord = (_chord + 1) % bank.pad_chords.size()
		_pad_active = 1 - _pad_active
		_pads[_pad_active].stream = bank.pad_chords[_chord]
		_pads[_pad_active].play()
		_harp_step = 0
		_harp_t = 0.0
	for i: int in 2:
		var target: float = 1.0 if i == _pad_active else 0.0
		_pad_gain[i] = move_toward(_pad_gain[i], target, delta / 2.5)
		# Slow swell so the sustained loop breathes like a bowed section.
		var swell: float = 0.82 + 0.18 * sin(_time * 0.7)
		_pads[i].volume_db = _db(_pad_gain[i] * explore * swell * 0.5)
		if _pad_gain[i] <= 0.0 and i != _pad_active and _pads[i].playing:
			_pads[i].stop()
	_drone.volume_db = _db(_music_fade * 0.42)

	# Harp arpeggio, thinned out while fighting.
	_harp_t -= delta
	if _harp_t <= 0.0:
		_harp_t += HARP_STEP
		var slot: int = HARP_PATTERN[_harp_step % HARP_PATTERN.size()]
		_harp_step += 1
		if slot >= 0 and combat_mix < 0.5 and _music_fade > 0.3:
			var notes: Array = HARP_NOTES[_chord]
			var semis: int = notes[slot]
			var p: AudioStreamPlayer = _harp[_harp_i]
			_harp_i = (_harp_i + 1) % _harp.size()
			p.pitch_scale = pow(2.0, float(semis) / 12.0)
			p.volume_db = _db(0.34 * explore * _rng.randf_range(0.75, 1.0))
			p.play()

	if combat_mix > 0.0 and not _combat.playing:
		_combat.play()
	elif combat_mix <= 0.0 and _combat.playing:
		_combat.stop()
	_combat.volume_db = _db(combat_mix * combat_mix * 0.6)


func _update_ambience(delta: float) -> void:
	var pos: Vector3 = player.global_position
	var sd: float = arena.sea_distance(pos.x, pos.z)
	var night: float = arena.day_night.night_factor if arena.day_night != null else 0.0
	# Sea: audible from the village on, full at the waterline.
	var sea: float = smoothstep(TestArena.SHORE_S - 55.0, TestArena.SHORE_S - 2.0, sd)
	_sea.volume_db = _db(0.06 + 0.7 * sea)
	# Wind: stronger on high ground and in the open, a little calmer at night.
	var height: float = clampf((pos.y - 1.0) / 8.0, 0.0, 1.0)
	var gust: float = 0.7 + 0.3 * sin(_time * 0.23) * sin(_time * 0.071 + 1.3)
	_wind.volume_db = _db((0.2 + 0.3 * height) * gust * (1.0 - 0.25 * night))
	_crickets.volume_db = _db(smoothstep(0.45, 0.95, night) * (1.0 - 0.7 * sea) * 0.3)
	# Gulls by day around Saltwick and the bay.
	_gull_t -= delta
	if _gull_t <= 0.0:
		_gull_t = _rng.randf_range(5.0, 13.0)
		if night < 0.35 and sd > 6.0 and not get_tree().paused:
			_gull.volume_db = _db(_rng.randf_range(0.12, 0.3) * smoothstep(6.0, 20.0, sd))
			_gull.pitch_scale = _rng.randf_range(0.88, 1.12)
			_gull.play()
