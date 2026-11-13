shader_type spatial;
render_mode cull_disabled;
// Painterly tree crowns: clusters of alpha-cut leaf cards with spherical normals,
// so the crown shades as one soft volume (light top, cool shadowed underside) and sways in the wind.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
uniform vec3 light_color : source_color = vec3(0.56, 0.82, 0.38);
uniform vec3 dark_color : source_color = vec3(0.13, 0.40, 0.25);
uniform float sway_strength = 0.1;
uniform float alpha_cut = 0.5;

varying float shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.13 + origin.z * 0.17 + VERTEX.y * 0.6;
	float w = sin(TIME * 1.2 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.9) * 0.3;
	VERTEX.x += w * sway_strength * (0.6 + COLOR.r);
	VERTEX.z += w * sway_strength * 0.5;
	shade = COLOR.r;  // 0 inside the crown, 1 on the sunny top.
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	vec3 c = mix(dark_color, light_color, clamp(shade * 0.85 + t.r * 0.25, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	BACKLIGHT = vec3(0.35, 0.45, 0.15);
	RIM = 0.25;
	RIM_TINT = 0.6;
}
