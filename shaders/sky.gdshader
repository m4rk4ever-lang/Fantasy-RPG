shader_type sky;
// Stylized sky: gradient, sun disc with glow, moon, stars and drifting fbm clouds.
// Colors are driven per time of day by DayNight.

uniform vec3 top_color : source_color = vec3(0.25, 0.53, 0.84);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.86, 0.96);
uniform vec3 ground_color : source_color = vec3(0.36, 0.42, 0.62);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.7, 0.85);
uniform float cloud_cover = 0.48;
uniform float cloud_speed = 0.006;
uniform float star_amount = 0.0;
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
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
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.02 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, h));

	// Sun: disc plus wide warm glow.
	float sd = dot(dir, LIGHT0_DIRECTION);
	if (LIGHT0_ENABLED) {
		float glow = pow(max(sd, 0.0), 12.0) * 0.35 + pow(max(sd, 0.0), 180.0) * 0.6;
		col += sun_color * glow * LIGHT0_ENERGY;
		col = mix(col, sun_color * 3.0, smoothstep(0.9993, 0.9996, sd) * LIGHT0_ENERGY);
	}

	// Moon.
	float md = dot(dir, normalize(moon_dir));
	col = mix(col, vec3(0.86, 0.87, 0.92) * 1.6, smoothstep(0.9985, 0.999, md));
	col += vec3(0.5, 0.6, 0.8) * pow(max(md, 0.0), 60.0) * 0.15;

	// Stars.
	if (star_amount > 0.0 && h > 0.0) {
		vec2 sp = dir.xz / (h + 0.3) * 160.0;
		float s = step(0.996, hash(floor(sp)));
		col += vec3(s) * star_amount * smoothstep(0.0, 0.3, h);
	}

	// Clouds on a virtual plane above the camera.
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * 0.9;
		uv += TIME * cloud_speed * vec2(1.0, 0.35);
		float n = fbm(uv * 1.3);
		float c = smoothstep(cloud_cover, cloud_cover + 0.22, n);
		float shade = smoothstep(cloud_cover, cloud_cover + 0.4, fbm(uv * 1.3 + vec2(0.05, 0.04)));
		vec3 cc = mix(cloud_color, cloud_shade, shade * 0.8);
		// Clouds near the sun get a lit rim.
		cc += sun_color * pow(max(sd, 0.0), 8.0) * 0.4;
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, cc, c * fade * 0.92);
	}
	COLOR = col;
}
