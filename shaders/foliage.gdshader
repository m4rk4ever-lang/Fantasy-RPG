shader_type spatial;
// Foliage with gentle wind sway. Sway grows with height above the object's origin.

uniform vec3 base_color : source_color = vec3(0.298, 0.706, 0.416);
uniform vec3 tip_color : source_color = vec3(0.55, 0.82, 0.45);
uniform float sway_strength = 0.12;
uniform float sway_speed = 1.3;
uniform float height_ref = 4.0;

varying float h;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.13 + origin.z * 0.17;
	h = clamp(VERTEX.y / height_ref + 0.6, 0.0, 1.5);
	float w = sin(TIME * sway_speed + phase) * 0.7 + sin(TIME * sway_speed * 2.3 + phase * 1.7) * 0.3;
	VERTEX.x += w * sway_strength * h * h;
	VERTEX.z += w * sway_strength * 0.5 * h * h;
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, clamp(h * 0.8, 0.0, 1.0));
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	RIM = 0.4;
	RIM_TINT = 0.5;
}
