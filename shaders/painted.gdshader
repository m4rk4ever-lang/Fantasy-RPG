shader_type spatial;
render_mode cull_disabled;
// Stylized-realistic surface for characters, armour, bark and stone: natural light with a soft
// terminator, a gentle top-down sky gradient, a metal highlight, a subtle rim, and optional
// triplanar surface detail (grain, bark, stone) so materials read as real materials.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float detail_amount = 0.0;
uniform vec3 detail_scale = vec3(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.46, 0.47, 0.54);
uniform float rim_amount = 0.25;
uniform float spec_amount = 0.05;
uniform float flash = 0.0;

varying float topness;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	topness = wnrm.y * 0.5 + 0.5;
}

void fragment() {
	vec3 c = albedo.rgb * texture(albedo_tex, UV).rgb * COLOR.rgb;
	if (detail_amount > 0.0) {
		vec3 w = pow(abs(wnrm), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 p = wpos * detail_scale;
		float d = texture(detail_tex, p.yz).r * w.x + texture(detail_tex, p.xz).r * w.y + texture(detail_tex, p.xy).r * w.z;
		float d2 = texture(detail_tex, p.xz * 3.7 + 0.31).r;
		c *= 1.0 + ((d * 0.7 + d2 * 0.3) - 0.5) * detail_amount * 1.6;
	}
	ALBEDO = mix(c * mix(0.86, 1.04, topness), vec3(1.0, 0.95, 0.85), flash);
	ROUGHNESS = 0.75;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-0.3, 0.7, ndl);
	vec3 lit = mix(shadow_tint, vec3(1.0), ramp);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR * ATTENUATION / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float sp = pow(max(dot(NORMAL, h), 0.0), 48.0) * spec_amount;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * rim_amount * ramp;
	SPECULAR_LIGHT += (sp + rim) * LIGHT_COLOR * ATTENUATION / PI;
}
