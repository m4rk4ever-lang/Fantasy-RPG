class_name SkyShard
extends Node3D
## A shard of the Sundered Crown hanging in the sky above the valley: the far landmark.
## Faceted crystal with a glowing core, orbiting rock fragments and slow rune rings.

const COL_CRYSTAL := Color("6ec3f0")
const COL_DEEP := Color("3d5ba9")
const COL_ROCK := Color("5b6c9e")

var _crystal: Node3D
var _rings: Array[Node3D] = []
var _rocks: Node3D
var _time: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	_base_y = position.y
	var I := Transform3D.IDENTITY
	_crystal = Node3D.new()
	add_child(_crystal)
	var k := MeshKit.new()
	# Long double-ended crystal, slightly asymmetric for a broken look.
	k.loft(I, [[-16.0, 0.3, 0.3, 0.0, COL_DEEP], [-6.0, 5.0, 4.2, 0.4, COL_DEEP], [2.0, 6.2, 5.0, 0.0, COL_CRYSTAL], [8.0, 4.6, 3.8, -0.5, COL_CRYSTAL], [13.0, 0.4, 0.4, -0.8, COL_CRYSTAL]], 6)
	# Smaller crystals growing off the main one.
	for i: int in 4:
		var a: float = TAU * i / 4.0 + 0.4
		var xf := Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.6), Vector3(cos(a) * 3.0, -3.0 + i, sin(a) * 3.0))
		k.loft(xf, [[-1.0, 0.2, 0.2, 0.0, COL_DEEP], [2.0, 1.6, 1.4, 0.0, COL_CRYSTAL], [6.0, 0.2, 0.2, 0.0, COL_CRYSTAL]], 5)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color("6ec3f0")
	m.emission_energy_multiplier = 1.4
	m.roughness = 0.2
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crystal.add_child(mi)

	# Rune rings: thin glowing tori at different tilts.
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.75, 0.92, 1.0)
	for r: int in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 9.0 + r * 2.5
		torus.outer_radius = 9.25 + r * 2.5
		torus.rings = 48
		torus.ring_segments = 3
		ring.mesh = torus
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot := Node3D.new()
		pivot.rotation = Vector3(0.35 * (r - 1), 0.0, 0.25 * r)
		pivot.add_child(ring)
		add_child(pivot)
		_rings.append(pivot)

	# Orbiting rock fragments torn from the ground.
	_rocks = Node3D.new()
	add_child(_rocks)
	var rk := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i2: int in 9:
		var a2: float = TAU * i2 / 9.0
		var rad: float = rng.randf_range(14.0, 20.0)
		var sz: float = rng.randf_range(0.8, 2.2)
		var xf2 := Transform3D(Basis.from_euler(Vector3(rng.randf() * PI, rng.randf() * PI, 0)), Vector3(cos(a2) * rad, rng.randf_range(-6.0, 6.0), sin(a2) * rad))
		rk.loft(xf2, [[-sz, sz * 0.3, sz * 0.3, 0.0, COL_ROCK], [0.0, sz, sz * 0.8, 0.0, COL_ROCK], [sz * 0.6, sz * 0.4, sz * 0.4, 0.0, COL_ROCK.lightened(0.2)]], 5)
	var rmi := MeshInstance3D.new()
	rmi.mesh = rk.commit()
	rmi.material_override = MeshKit.vertex_color_material(0.9)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rocks.add_child(rmi)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.25) * 2.0
	_crystal.rotation.y += delta * 0.06
	_rocks.rotation.y -= delta * 0.04
	for i: int in _rings.size():
		_rings[i].rotate_object_local(Vector3.UP, delta * (0.1 + i * 0.05) * (1.0 if i % 2 == 0 else -1.0))
