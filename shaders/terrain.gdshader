shader_type spatial;
// Stylized terrain: grass on flats, layered rock on slopes, snow above a height line.
// Pure procedural noise, no textures, so it stays crisp at any distance.

uniform vec3 grass_color : source_color = vec3(0.26, 0.62, 0.36);
uniform vec3 grass_dark : source_color = vec3(0.17, 0.45, 0.25);
uniform vec3 grass_dry : source_color = vec3(0.60, 0.72, 0.30);
uniform vec3 rock_color : source_color = vec3(0.46, 0.49, 0.58);
uniform vec3 rock_light : source_color = vec3(0.80, 0.77, 0.70);
uniform vec3 snow_color : source_color = vec3(0.95, 0.97, 1.0);
uniform vec3 sand_color : source_color = vec3(0.89, 0.84, 0.69);
uniform float sand_height = -100.0;
uniform float snow_height = 60.0;
uniform float snow_blend = 12.0;
uniform float rock_slope = 0.78;
uniform float detail_scale = 0.08;
uniform float strata_freq = 1.6;
uniform float strata_amount = 0.45;

varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz * detail_scale;
	float n = fbm(p);
	float n2 = fbm(p * 4.0 + 13.0);
	float patches = smoothstep(0.35, 0.75, fbm(p * 0.35 + 7.0));

	vec3 grass = mix(grass_color, grass_dark, n * 0.7);
	grass = mix(grass, grass_dry, patches * 0.45);
	grass *= 0.92 + n2 * 0.16;

	// Horizontal strata on rock read as cliffs from far away.
	float strata = sin(world_pos.y * strata_freq + n * 6.0) * 0.5 + 0.5;
	vec3 rock = mix(rock_color, rock_light, strata * strata_amount + n2 * 0.25);

	float slope = world_nrm.y;
	float rock_w = 1.0 - smoothstep(rock_slope - 0.06, rock_slope + 0.06, slope + (n - 0.5) * 0.12);
	vec3 col = mix(grass, rock, rock_w);

	float sand_w = 1.0 - smoothstep(sand_height - 0.4, sand_height + 0.5, world_pos.y + (n2 - 0.5) * 0.6);
	col = mix(col, sand_color * (0.92 + n2 * 0.12), sand_w);
	// Wet sand darkens toward the waterline.
	col *= mix(1.0, 0.78, 1.0 - smoothstep(-0.9, -0.2, world_pos.y));

	float snow_w = smoothstep(snow_height - snow_blend, snow_height + snow_blend, world_pos.y + (n - 0.5) * 18.0);
	snow_w *= smoothstep(0.35, 0.6, slope);
	col = mix(col, snow_color, snow_w);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.7, snow_w);
	SPECULAR = 0.25;
}
