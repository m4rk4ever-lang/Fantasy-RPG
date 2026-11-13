class_name LootDrop
extends Node3D
## A pouch of loot on the ground. Picked up automatically when the hero walks over it.

signal picked_up(items: Array)

## Array of [id, count]
var items: Array = []
var _time: float = 0.0
var _pouch: Node3D
var _life: float = 120.0


func _ready() -> void:
	add_to_group(&"loot")
	_pouch = Node3D.new()
	add_child(_pouch)
	var k := MeshKit.new()
	var leather := Color("8a6446")
	k.loft(Transform3D.IDENTITY, [[0.0, 0.12, 0.1, 0.0, leather], [0.12, 0.17, 0.15, 0.0, leather], [0.24, 0.1, 0.09, 0.0, leather.darkened(0.15)], [0.28, 0.06, 0.05, 0.0, Color("d9a441")], [0.34, 0.09, 0.08, 0.0, leather]], 8)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = MeshKit.vertex_color_material(0.7)
	_pouch.add_child(mi)
	# Soft glow ring so loot reads from a distance.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.4
	torus.rings = 24
	torus.ring_segments = 3
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("f2d48a")
	ring.material_override = rm
	ring.scale = Vector3(1, 0.1, 1)
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _process(delta: float) -> void:
	_time += delta
	_life -= delta
	_pouch.position.y = 0.05 + absf(sin(_time * 2.0)) * 0.06
	_pouch.rotation.y += delta * 1.2
	if _life <= 0.0:
		queue_free()
		return
	var hero: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if hero and hero.global_position.distance_to(global_position) < 1.6:
		picked_up.emit(items)
		queue_free()
