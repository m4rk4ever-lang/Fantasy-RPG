class_name WardenHusk
extends Hollow
## Warden-Husk Aldric: mini-boss of the Veilspire's first floor. A bigger, ember-eyed Hollowed
## that once wore the Warden's oath. Slow, heavy overhead slam with a long, clear telegraph:
## a ring of fire grows on the floor where the blow will land, so stepping out is always possible.

signal slammed(pos: Vector3)

const COL_EMBER := Color("d9552e")
const SLAM_RADIUS: float = 3.1
const SLAM_REACH: float = 2.0

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _poise_hits: int = 0


func _init() -> void:
	display_name = "Warden-Husk Aldric"
	level = 5
	max_health = 340.0
	move_speed = 3.1
	aggro_range = 9.0
	leash_range = 30.0
	attack_range = 2.9
	attack_damage = 30.0
	windup_time = 1.15
	attack_time = 0.3
	recover_time = 1.35


func _ready() -> void:
	super._ready()
	_model.scale = Vector3.ONE * 1.6
	# Scorched, rust-dark tint over the shared Hollow vertex colors.
	_body_mat.albedo_color = Color(1.0, 0.72, 0.62)
	for c: Node in get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
			var cap := CapsuleShape3D.new()
			cap.radius = 0.7
			cap.height = 3.0
			(c as CollisionShape3D).shape = cap
			(c as CollisionShape3D).position.y = 1.5
	_wisps.position.y *= 1.6
	_wisps.amount = _wisps.amount * 2
	_wisps.color = Color(COL_EMBER.r, COL_EMBER.g, COL_EMBER.b, 0.7)
	# Telegraph: a flat ring of fire on the floor that fills in while the slam winds up.
	_ring = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	_ring.mesh = disc
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(COL_EMBER.r, COL_EMBER.g, COL_EMBER.b, 0.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 2.0


## Poise: the Husk shrugs off hits while it winds up or swings, and only staggers on every third hit.
func take_hit(damage: float, knockback: Vector3, hit_pos: Vector3) -> void:
	if state == State.DEAD:
		return
	_poise_hits += 1
	var lethal: bool = health - damage <= 0.0
	if lethal or (_poise_hits >= 3 and state != State.WINDUP and state != State.ATTACK):
		_poise_hits = 0
		super.take_hit(damage, knockback * 0.4, hit_pos)
		return
	health = maxf(health - damage, 0.0)
	health_changed.emit(health, max_health)
	_flash = 1.0


func _die(knockback: Vector3) -> void:
	_ring.visible = false
	super._die(knockback * 0.5)


func _slam_point() -> Vector3:
	return global_position + _facing_vec() * SLAM_REACH


func _physics_process(delta: float) -> void:
	# The slam is an area hit around the impact point; it replaces the base frontal swipe.
	if state == State.ATTACK and not _hit_done and _t + delta > attack_time * 0.5:
		_hit_done = true
		var at: Vector3 = _slam_point()
		if target != null and is_instance_valid(target) and float(target.get("health")) > 0.0:
			var d: Vector3 = target.global_position - at
			d.y = 0.0
			if d.length() < SLAM_RADIUS and target.has_method("take_damage"):
				var push: Vector3 = d.normalized() if d.length() > 0.1 else _facing_vec()
				target.call("take_damage", attack_damage, push * 11.0, self)
		slammed.emit(at)
	super._physics_process(delta)
	if state == State.ATTACK:
		# Heavy blow: almost no lunge (the base Hollow darts forward).
		velocity.x *= 0.2
		velocity.z *= 0.2
	_update_ring()


func _update_ring() -> void:
	match state:
		State.WINDUP:
			var k: float = clampf(_t / windup_time, 0.0, 1.0)
			_ring.visible = true
			_ring.position = _facing_vec() * SLAM_REACH + Vector3.UP * 0.06
			_ring.scale = Vector3(SLAM_RADIUS, 1.0, SLAM_RADIUS) * lerpf(0.35, 1.0, k)
			_ring_mat.albedo_color.a = lerpf(0.12, 0.55, k * k)
		State.ATTACK:
			_ring_mat.albedo_color.a = 0.75
		_:
			if _ring.visible:
				_ring_mat.albedo_color.a = move_toward(_ring_mat.albedo_color.a, 0.0, 0.06)
				if _ring_mat.albedo_color.a <= 0.0:
					_ring.visible = false


func _animate(delta: float, speed: float) -> void:
	super._animate(delta, speed)
	# Ember eyes instead of the pale Veil blue; both arms come down for the slam.
	var c: Color = _eye_mat.albedo_color
	var e: float = maxf(c.r, maxf(c.g, c.b))
	_eye_mat.albedo_color = Color(1.0 * e, 0.42 * e, 0.2 * e)
	if state == State.WINDUP or state == State.ATTACK:
		_arm_l.rotation = Vector3(_arm_r.rotation.x, 0, -_arm_r.rotation.z)
