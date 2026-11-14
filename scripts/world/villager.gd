class_name Villager
extends Node3D
## Simple ambient villager: walks a route of waypoints, pauses, looks around.
## Reuses the hero rig (HeroModel) with plain clothes and no sword. No physics: snaps to terrain.

var route: Array[Vector3] = []
var outfit: Dictionary = {}
var arena: TestArena
var speed: float = 1.7
## Things this villager says when the hero is near. Epic world, but people still joke.
var lines: Array[String] = []
## Named NPCs can be clicked to talk (group "npcs") and show a name tag.
var display_name: String = ""
var face_dir: Vector3 = Vector3.ZERO
var _tag: Label3D
var _marker: Label3D

var _label: Label3D
var _line_timer: float = 0.0
var _line_index: int = 0

var _model: HeroModel
## Path for the current leg of the route (around houses, fences, crates), from the NavGrid.
var _leg: PackedVector3Array = PackedVector3Array()
var _leg_i: int = 0
var _leg_for: int = -1
var _index: int = 0
var _wait: float = 0.0
var _facing: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_model = HeroModel.new()
	_model.with_sword = false
	_model.armored = false
	_model.col_tunic = outfit.get("tunic", HeroModel.COLOR_TUNIC)
	_model.col_cloak = outfit.get("cloak", HeroModel.COLOR_CLOAK)
	_model.col_hair = outfit.get("hair", HeroModel.COLOR_HAIR)
	_model.col_plate = outfit.get("tunic", HeroModel.COLOR_TUNIC).darkened(0.15)
	_model.col_leather = outfit.get("trousers", HeroModel.COLOR_LEATHER)
	_model.col_skin = outfit.get("skin", HeroModel.COLOR_SKIN)
	# Outfit variation: "kind" is "", "apron", "hood" or "hat"; "hair_style" picks the hair shape.
	_model.outfit_kind = outfit.get("kind", "")
	_model.hair_style = outfit.get("hair_style", 1)
	# Imported CC0 body (smooth, animated); clothes recoloured to the outfit.
	_model.glb_path = "res://assets/models/quaternius/%s.glb" % ("hooded_adventurer" if _model.outfit_kind == "hood" or _model.hair_style == 2 else "adventurer")
	_model.idle_anim = "Idle"
	_model.walk_rate = 6.5
	_model.hide_meshes = ["Backpack"]
	_model.tints = {"Green": _model.col_tunic, "LightGreen": _model.col_cloak, "Hair": _model.col_hair, "Brown2": _model.col_leather}
	add_child(_model)
	_model.scale = Vector3.ONE * 0.95
	if not route.is_empty():
		global_position = _ground(route[0])
		_index = 1 % route.size()
	_wait = _rng.randf_range(0.0, 3.0)
	if display_name != "":
		add_to_group(&"npcs")
		_tag = Label3D.new()
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.text = display_name
		_tag.position.y = 2.0
		_tag.font_size = 32
		_tag.pixel_size = 0.004
		_tag.outline_size = 8
		_tag.modulate = Color("f2d48a")
		_tag.outline_modulate = Color(0.12, 0.13, 0.16, 0.9)
		add_child(_tag)
		if face_dir != Vector3.ZERO:
			_facing = atan2(-face_dir.x, -face_dir.z)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.25 if display_name == "" else 2.45
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.outline_size = 10
	_label.modulate = Color("e6e1d3")
	_label.outline_modulate = Color(0.12, 0.13, 0.16, 0.9)
	_label.width = 600.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)
	_line_index = _rng.randi() % maxi(lines.size(), 1)


func _ground(p: Vector3) -> Vector3:
	if arena == null:
		return p
	# Routes that go over the water follow the pier deck.
	return Vector3(p.x, maxf(arena.height_at(p.x, p.z), 0.61), p.z)


func _process(delta: float) -> void:
	_update_bark(delta)
	if route.size() < 2:
		_model.rotation.y = _facing
		_model.animate(delta, 0.0, true, 0.0, 0.0, false)
		return
	var moving: float = 0.0
	if _wait > 0.0:
		_wait -= delta
	else:
		var target: Vector3 = _ground(route[_index])
		# Plan the leg once, around obstacles, when the grid is ready (piers stay straight lines).
		if _leg_for != _index:
			_leg_for = _index
			_leg_i = 0
			_leg = PackedVector3Array()
			var nav: NavGrid = get_tree().get_first_node_in_group(&"navgrid") as NavGrid
			if nav and nav.ready_built and arena and arena.height_at(target.x, target.z) > TestArena.WATER_LEVEL + 0.35:
				_leg = nav.find_path(global_position, target)
		var goal: Vector3 = target
		while _leg_i < _leg.size():
			var wp: Vector3 = _leg[_leg_i]
			if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() < 0.6 and _leg_i < _leg.size() - 1:
				_leg_i += 1
				continue
			goal = Vector3(wp.x, target.y, wp.z) if _leg_i < _leg.size() - 1 else target
			break
		var to: Vector3 = goal - global_position
		to.y = 0.0
		var to_final: Vector3 = target - global_position
		to_final.y = 0.0
		if to_final.length() < 0.3:
			_index = (_index + 1) % route.size()
			_wait = _rng.randf_range(2.0, 6.0)
		else:
			var step: Vector3 = to.normalized() * speed * delta
			global_position = _ground(global_position + step)
			_facing = lerp_angle(_facing, atan2(-to.x, -to.z), 1.0 - exp(-6.0 * delta))
			moving = speed / 10.5 * 1.15
	_model.rotation.y = _facing
	_model.animate(delta, moving, true, 0.0, 0.0, false)


func _update_bark(delta: float) -> void:
	if _marker and _marker.visible:
		_marker.position.y = 2.75 + sin(Time.get_ticks_msec() * 0.004) * 0.08
	if lines.is_empty():
		return
	var hero: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var near: bool = hero != null and hero.global_position.distance_to(global_position) < 6.0
	if not near:
		_label.visible = false
		_line_timer = 0.0
		return
	_line_timer -= delta
	if _line_timer <= 0.0:
		_label.text = lines[_line_index % lines.size()]
		get_tree().call_group(&"chat_log", &"add_chat", display_name if display_name != "" else "Villager", _label.text)
		_line_index += 1
		_line_timer = 7.0
	_label.visible = _line_timer > 1.5  # Short pause between lines.


## Quest marker above the head: "!" (new quest) or "?" (ready to hand in). Empty hides it.
func set_marker(text: String) -> void:
	if _marker == null:
		_marker = Label3D.new()
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.position.y = 2.75
		_marker.font_size = 96
		_marker.pixel_size = 0.005
		_marker.outline_size = 14
		_marker.modulate = Color("f2c14e")
		_marker.outline_modulate = Color(0.12, 0.13, 0.16, 0.9)
		_marker.no_depth_test = true
		add_child(_marker)
	_marker.text = text
	_marker.visible = text != ""
