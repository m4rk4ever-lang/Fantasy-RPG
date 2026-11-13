shader_type spatial;
render_mode cull_disabled;
// Grass tufts (MultiMesh): wind sway, color variation per instance, fade-out with distance.

uniform vec3 root_color : source_color = vec3(0.17, 0.45, 0.25);
uniform vec3 tip_color : source_color = vec3(0.36, 0.64, 0.36);
uniform vec3 dry_tip : source_color = vec3(0.62, 0.74, 0.40);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.6;
uniform float fade_start = 34.0;
uniform float fade_end = 52.0;

varying float tip;
varying float variation;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	variation = hash(origin.xz);
	tip = clamp(VERTEX.y / 0.4, 0.0, 1.0);
	float dist = length(origin - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	VERTEX.y *= fade;
	float gust = sin(TIME * 0.35 + origin.x * 0.03) * 0.5 + 0.5;
	float w = sin(TIME * wind_speed + origin.x * 0.35 + origin.z * 0.22) * (0.6 + gust * 0.6);
	vec3 wind_dir = vec3(1.0, 0.0, 0.4);
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * wind_dir) * w * wind_strength * tip * tip;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 tipc = mix(tip_color, dry_tip, smoothstep(0.6, 1.0, variation) * 0.7);
	ALBEDO = mix(root_color, tipc, tip) * (0.9 + variation * 0.2);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.25, 0.35, 0.15);
}
