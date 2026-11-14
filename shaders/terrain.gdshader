shader_type spatial;
// Stylized terrain: grass on flats, layered rock on slopes, snow above a height line.
// Pure procedural noise, no textures, so it stays crisp at any distance.

uniform vec3 grass_color : source_color = vec3(0.31, 0.47, 0.18);
uniform vec3 grass_dark : source_color = vec3(0.20, 0.32, 0.13);
uniform vec3 grass_dry : source_color = vec3(0.60, 0.56, 0.30);
uniform vec3 rock_color : source_color = vec3(0.42, 0.42, 0.43);
uniform vec3 rock_light : source_color = vec3(0.70, 0.67, 0.61);
uniform vec3 snow_color : source_color = vec3(0.95, 0.97, 1.0);
uniform vec3 sand_color : source_color = vec3(0.80, 0.73, 0.57);
uniform float sand_height = -100.0;
uniform float snow_height = 60.0;
uniform float snow_blend = 12.0;
uniform float rock_slope = 0.78;
uniform float detail_scale = 0.08;
uniform float strata_freq = 1.6;
uniform float strata_amount = 0.45;

// Dirt paths: up to 8 segments (xz start, xz end), painted where the walker would go.
uniform vec4 path_segs[16];
uniform int path_count = 0;
uniform float path_width = 1.6;
uniform vec3 path_color : source_color = vec3(0.52, 0.43, 0.31);
uniform vec3 path_edge : source_color = vec3(0.40, 0.42, 0.24);
uniform float flowers = 1.0;
// Trodden earth around buildings, columns and rocks (xz, radius, strength): objects grow out of the ground.
uniform vec4 ground_spots[64];
uniform int spot_count = 0;

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
	// Painterly brush strokes: stretched noise in two directions, a warm sunlit mottle on top.
	float stroke = vnoise(world_pos.xz * vec2(0.9, 5.5) + n * 3.0) * 0.5 + vnoise(world_pos.xz * vec2(5.0, 1.1) - n * 2.0) * 0.5;
	grass *= 0.93 + stroke * 0.14;
	float fine = vnoise(world_pos.xz * 9.0) * 0.6 + vnoise(world_pos.xz * 23.0) * 0.4;
	grass *= 0.86 + fine * 0.26;
	float soil = smoothstep(0.66, 0.8, fbm(world_pos.xz * 0.9 + 5.0)) * (1.0 - patches * 0.3);
	grass = mix(grass, vec3(0.36, 0.30, 0.21) * (0.85 + fine * 0.3), soil * 0.55);
	float mottle = smoothstep(0.55, 0.8, fbm(world_pos.xz * 0.045 + 31.0));
	grass = mix(grass, grass * vec3(1.12, 1.1, 0.86), mottle * 0.6);
	// Flowers: tiny specks of white, yellow and violet on the flats.
	vec2 fc = floor(world_pos.xz * 2.2);
	float fh = hash(fc);
	if (flowers > 0.5 && fh > 0.972) {
		vec2 fp = fract(world_pos.xz * 2.2) - 0.5 + (vec2(hash(fc + 3.1), hash(fc + 7.7)) - 0.5) * 0.5;
		float fd = smoothstep(0.16, 0.1, length(fp));
		vec3 fcol = fh > 0.99 ? vec3(0.62, 0.52, 0.86) : (fh > 0.981 ? vec3(0.98, 0.86, 0.35) : vec3(0.97, 0.96, 0.92));
		grass = mix(grass, fcol, fd * (1.0 - patches * 0.5));
	}
	// Dirt paths with a soft worn edge.
	float pd = 1e5;
	for (int i = 0; i < 16; i++) {
		if (i >= path_count) {
			break;
		}
		vec2 a = path_segs[i].xy;
		vec2 b = path_segs[i].zw;
		vec2 ab = b - a;
		float t = clamp(dot(world_pos.xz - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		pd = min(pd, length(world_pos.xz - (a + ab * t)));
	}
	float wob = (fbm(world_pos.xz * 0.6) - 0.5) * 0.9;
	float path_w = 1.0 - smoothstep(path_width * 0.55, path_width, pd + wob);
	float edge_w = 1.0 - smoothstep(path_width, path_width * 1.6, pd + wob);
	// Earth and darker, flattened grass around the feet of objects.
	float worn = 0.0;
	for (int k = 0; k < 64; k++) {
		if (k >= spot_count) {
			break;
		}
		vec4 sp = ground_spots[k];
		float d = length(world_pos.xz - sp.xy) / sp.z + (fbm(world_pos.xz * 1.7 + float(k)) - 0.5) * 0.35;
		worn = max(worn, (1.0 - smoothstep(0.75, 1.15, d)) * sp.w);
	}
	grass = mix(grass, vec3(0.30, 0.26, 0.19) * (0.85 + n2 * 0.3), worn * 0.75);
	grass = mix(grass, path_edge, edge_w * 0.5);
	grass = mix(grass, path_color * (0.88 + n2 * 0.2), path_w);

	// Horizontal strata on rock read as cliffs from far away.
	float strata = sin(world_pos.y * strata_freq + n * 6.0) * 0.5 + 0.5;
	vec3 rock = mix(rock_color, rock_light, strata * strata_amount + n2 * 0.25);
	float grain = vnoise(world_pos.xz * 6.0 + world_pos.y * 3.0) * 0.5 + vnoise(world_pos.xy * 11.0) * 0.5;
	rock *= 0.82 + grain * 0.34;
	rock = mix(rock, rock * vec3(0.78, 0.86, 0.72), smoothstep(0.55, 0.75, fbm(world_pos.xz * 0.3 + world_pos.y * 0.2)) * 0.6);

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
