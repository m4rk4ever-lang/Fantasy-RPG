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

var _label: Label3D
var _line_timer: float = 0.0
var _line_index: int = 0

var _model: HeroModel
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
	add_child(_model)
	_model.scale = Vector3.ONE * 0.95
	if not route.is_empty():
		global_position = _ground(route[0])
		_index = 1 % route.size()
	_wait = _rng.randf_range(0.0, 3.0)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.25
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
		_model.animate(delta, 0.0, true, 0.0, 0.0, false)
		return
	var moving: float = 0.0
	if _wait > 0.0:
		_wait -= delta
	else:
		var target: Vector3 = _ground(route[_index])
		var to: Vector3 = target - global_position
		to.y = 0.0
		if to.length() < 0.3:
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
		_line_index += 1
		_line_timer = 7.0
	_label.visible = _line_timer > 1.5  # Short pause between lines.
