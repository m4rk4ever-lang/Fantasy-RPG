shader_type spatial;
render_mode cull_disabled;
// Stylized sea. Vertex color R = water depth (0 shore .. 1 deep), baked from the terrain.
// Gives shallow turquoise, deep royal blue, animated shore foam and sun glints. No depth texture needed.

uniform vec3 shallow_color : source_color = vec3(0.36, 0.80, 0.85);
uniform vec3 mid_color : source_color = vec3(0.25, 0.58, 0.82);
uniform vec3 deep_color : source_color = vec3(0.17, 0.32, 0.62);
uniform vec3 foam_color : source_color = vec3(0.96, 0.97, 0.95);
uniform float wave_height = 0.14;
uniform bool flat_far = false;

varying float depth;
varying vec3 wpos;

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

float waves(vec2 p, float t) {
	return sin(p.x * 0.35 + t * 1.1) * 0.5
		+ sin(p.y * 0.27 - t * 0.9 + p.x * 0.1) * 0.35
		+ sin((p.x + p.y) * 0.6 + t * 1.7) * 0.15;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = flat_far ? 1.0 : COLOR.r;
	if (!flat_far) {
		float amp = wave_height * smoothstep(0.0, 0.25, depth);
		float h = waves(wpos.xz, TIME) * amp;
		VERTEX.y += h;
		float e = 0.5;
		float hx = waves(wpos.xz + vec2(e, 0.0), TIME) * amp;
		float hz = waves(wpos.xz + vec2(0.0, e), TIME) * amp;
		NORMAL = normalize(vec3(h - hx, e, h - hz));
	}
}

void fragment() {
	vec3 col = mix(shallow_color, mid_color, smoothstep(0.0, 0.25, depth));
	col = mix(col, deep_color, smoothstep(0.25, 0.9, depth));
	// Ripple detail.
	float r = vnoise(wpos.xz * 0.45 + vec2(TIME * 0.3, TIME * 0.2)) * vnoise(wpos.xz * 0.8 - vec2(TIME * 0.25, 0.0));
	col += vec3(0.06, 0.08, 0.08) * smoothstep(0.25, 0.6, r);
	// Shore foam: bands that roll in toward the beach.
	float band = sin(depth * 60.0 - TIME * 2.2 + vnoise(wpos.xz * 0.6) * 4.0);
	float foam = smoothstep(0.08, 0.0, depth) + smoothstep(0.7, 1.0, band) * smoothstep(0.12, 0.02, depth);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * 0.9);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	RIM = 0.25;
	RIM_TINT = 0.8;
}
