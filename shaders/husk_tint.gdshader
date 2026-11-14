shader_type spatial;
// Hollowed: desaturates the imported atlas and tints it toward cold, ashen tones,
// with a faint Veil-blue rim so the husks read against grass.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 tint : source_color = vec3(0.78, 0.80, 0.86);
uniform vec3 rim_color : source_color = vec3(0.43, 0.76, 0.94);
uniform float rim_amount = 0.35;
uniform float flash = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * base_color.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ash = vec3(pow(l, 0.85)) * tint * 1.15;
	ALBEDO = mix(ash, vec3(1.0, 0.95, 0.85), flash);
	ROUGHNESS = 0.8;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * rim * rim_amount + vec3(flash * 0.6);
}

// Same painted light as the hero (painted.gdshader): soft two-tone ramp with a cool shadow colour.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-0.2, 0.5, ndl);
	DIFFUSE_LIGHT += mix(vec3(0.36, 0.38, 0.52), vec3(1.0), ramp) * LIGHT_COLOR * ATTENUATION / PI;
}
