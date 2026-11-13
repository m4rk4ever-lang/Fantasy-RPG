class_name Villager
extends Node3D
## Simple ambient villager: walks a route of waypoints, pauses, looks around.
## Reuses the hero rig (HeroModel) with plain clothes and no sword. No physics: snaps to terrain.

var route: Array[Vector3] = []
var outfit: Dictionary = {}
var arena: TestArena
var speed: float = 1.7

var _model: HeroModel
var _index: int = 0
var _wait: float = 0.0
var _facing: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_model = HeroModel.new()
	_model.with_sword = false
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


func _ground(p: Vector3) -> Vector3:
	if arena == null:
		return p
	# Routes that go over the water follow the pier deck.
	return Vector3(p.x, maxf(arena.height_at(p.x, p.z), 0.61), p.z)


func _process(delta: float) -> void:
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
