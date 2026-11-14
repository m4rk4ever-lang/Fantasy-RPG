shader_type spatial;
render_mode cull_disabled;
// Hand-painted look for characters and armour: a top-down "painted" gradient, a soft two-tone
// light ramp with a cool shadow colour, a small highlight on metal and a warm rim on the edges.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec3 shadow_tint : source_color = vec3(0.38, 0.38, 0.52);
uniform float rim_amount = 0.25;
uniform float spec_amount = 0.05;
uniform float flash = 0.0;

varying float topness;

void vertex() {
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	topness = wn.y * 0.5 + 0.5;
}

void fragment() {
	vec3 c = albedo.rgb * texture(albedo_tex, UV).rgb;
	ALBEDO = mix(c * mix(0.72, 1.08, topness), vec3(1.0, 0.95, 0.85), flash);
	ROUGHNESS = 0.7;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-0.2, 0.5, ndl);
	vec3 lit = mix(shadow_tint, vec3(1.0), ramp);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR * ATTENUATION / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float sp = pow(max(dot(NORMAL, h), 0.0), 32.0) * spec_amount;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount * ramp;
	SPECULAR_LIGHT += (sp + rim) * LIGHT_COLOR * ATTENUATION / PI;
}
