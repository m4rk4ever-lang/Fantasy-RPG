class_name DayNight
extends Node
## Day-night cycle. Moves sun and moon, and blends sky, fog and ambient colors between keyframes.
## Night stays readable: moonlight is cool and fairly bright (no pitch-black nights).

@export var time_of_day: float = 9.5  ## Hours, 0..24.
@export var day_length_minutes: float = 16.0  ## Real minutes for a full 24h cycle.
@export var running: bool = true

## Turned off by the Low graphics quality.
var shadows_allowed: bool = true
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
## 0 = day, 1 = night. Read by ambient effects.
var night_factor: float = 0.0

## hour, sky top, horizon, fog, ambient, sun color, sun energy, cloud color, cloud shade, stars
var _keys: Array = [
	[0.0, Color("16213f"), Color("2c3b63"), Color("27355a"), Color("4a5a86"), Color("9fb3d9"), 0.0, Color("4b5878"), Color("2a3352"), 1.0],
	[5.0, Color("1f2c52"), Color("4f5f8f"), Color("46557f"), Color("5a6a96"), Color("ffb489"), 0.0, Color("6b7699"), Color("3a4466"), 0.6],
	[6.5, Color("4a76b8"), Color("f2b89a"), Color("d8b8a8"), Color("b9a6a4"), Color("ffc28f"), 0.7, Color("ffd9c2"), Color("b88f99"), 0.0],
	[8.5, Color("4b7fbe"), Color("b3d0e3"), Color("b2c6d6"), Color("dcdccf"), Color("fff1dc"), 1.45, Color("ffffff"), Color("a6b5d6"), 0.0],
	[13.0, Color("4a7ec0"), Color("b0cee2"), Color("b2c6d6"), Color("e2e1d6"), Color("fff6e8"), 1.6, Color("ffffff"), Color("9eb0d4"), 0.0],
	[17.0, Color("4d7bb6"), Color("c2d4e0"), Color("b9c8d4"), Color("d9d2c4"), Color("ffe2bc"), 1.35, Color("fff4e6"), Color("a8afcf"), 0.0],
	[19.0, Color("3d5ba9"), Color("f0a37a"), Color("d79d86"), Color("b28f8f"), Color("ff9c66"), 0.65, Color("ffc9a6"), Color("8f6f8c"), 0.0],
	[20.5, Color("1f2c52"), Color("5b6c9e"), Color("4d5b86"), Color("5a6a96"), Color("ff9c66"), 0.0, Color("6b7699"), Color("3a4466"), 0.5],
	[24.0, Color("16213f"), Color("2c3b63"), Color("27355a"), Color("4a5a86"), Color("9fb3d9"), 0.0, Color("4b5878"), Color("2a3352"), 1.0],
]


func setup(p_sun: DirectionalLight3D, p_moon: DirectionalLight3D, p_env: Environment, p_sky: ShaderMaterial) -> void:
	sun = p_sun
	moon = p_moon
	environment = p_env
	sky_material = p_sky
	apply()


func _process(delta: float) -> void:
	if not running or sun == null:
		return
	time_of_day = fmod(time_of_day + delta * 24.0 / (day_length_minutes * 60.0), 24.0)
	apply()


func is_night() -> bool:
	return time_of_day < 6.0 or time_of_day > 20.0


func apply() -> void:
	var k: Array = _sample(time_of_day)
	# Sun path: rises in the east (+X), sets in the west, tilted south.
	var day_t: float = (time_of_day - 6.0) / 14.0  # 0 at 6:00, 1 at 20:00
	var elev: float = sin(clampf(day_t, 0.0, 1.0) * PI) * deg_to_rad(62.0)
	var azim: float = lerpf(deg_to_rad(-100.0), deg_to_rad(-260.0), day_t)
	sun.rotation = Vector3(-maxf(elev, deg_to_rad(4.0)), azim, 0)
	sun.light_color = k[5]
	sun.light_energy = k[6]
	sun.visible = k[6] > 0.01
	sun.shadow_enabled = sun.visible and shadows_allowed
	var night_w: float = 1.0 - clampf(k[6] / 0.6, 0.0, 1.0)
	night_factor = night_w
	moon.light_energy = 0.45 * night_w
	moon.visible = moon.light_energy > 0.01
	moon.rotation = Vector3(deg_to_rad(-50.0), azim + PI, 0)

	environment.ambient_light_color = k[4]
	environment.ambient_light_energy = lerpf(0.42, 0.85, night_w)
	environment.fog_light_color = k[3]
	sky_material.set_shader_parameter("top_color", k[1])
	sky_material.set_shader_parameter("horizon_color", k[2])
	sky_material.set_shader_parameter("ground_color", (k[3] as Color).darkened(0.25))
	sky_material.set_shader_parameter("sun_color", k[5])
	sky_material.set_shader_parameter("cloud_color", k[7])
	sky_material.set_shader_parameter("cloud_shade", k[8])
	sky_material.set_shader_parameter("star_amount", k[9])
	sky_material.set_shader_parameter("moon_dir", moon.global_transform.basis.z if moon.is_inside_tree() else Vector3.DOWN)


func _sample(t: float) -> Array:
	for i: int in _keys.size() - 1:
		var a: Array = _keys[i]
		var b: Array = _keys[i + 1]
		if t >= a[0] and t <= b[0]:
			var f: float = (t - a[0]) / maxf(b[0] - a[0], 0.001)
			f = f * f * (3.0 - 2.0 * f)
			var out: Array = [t]
			for j: int in range(1, a.size()):
				if a[j] is Color:
					out.append((a[j] as Color).lerp(b[j], f))
				else:
					out.append(lerpf(a[j], b[j], f))
			return out
	return _keys[0]
