shader_type spatial;
// Readable building materials in code, no texture files: cut stone blocks with mortar, overlapping
// roof tiles, wood grain and weathered plaster. The material comes from the vertex colour alpha
// (set by MeshKit users) or from `override_id`:
//   ~0.2 plaster   ~0.4 stone blocks   ~0.6 wood   ~0.8 roof tiles   1.0 plain
// Patterns are projected on the surface plane in world space, so they line up across meshes.

uniform float override_id = -1.0;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool cylindrical = false;   // Columns: wrap the stone pattern around the vertical axis.
uniform float block_h = 0.34;
uniform float block_w = 0.62;
uniform float moss = 0.35;          // Moss and grime on upward faces of stone.

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 obj_origin;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 7.1) * 0.2;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	obj_origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float id = override_id >= 0.0 ? override_id : COLOR.a;
	vec3 base = COLOR.rgb * albedo_color.rgb;
	vec3 n = normalize(wnrm);
	// Surface plane coordinates: u along the surface horizontally, v up (walls) or down-slope (roofs).
	vec3 t = abs(n.y) < 0.97 ? normalize(cross(vec3(0.0, 1.0, 0.0), n)) : vec3(1.0, 0.0, 0.0);
	vec3 b = normalize(cross(n, t));
	float u = dot(wpos, t);
	float v = dot(wpos, b);
	if (cylindrical && abs(n.y) < 0.97) {
		vec2 d = wpos.xz - obj_origin.xz;
		u = atan(d.y, d.x) * max(length(d), 0.3);
		v = wpos.y;
	}
	vec3 col = base;
	float rough = 0.85;
	float grain = fbm(vec2(u, v) * 3.0);

	if (id < 0.3) {
		// Plaster: soft mottling, rain streaks running down.
		float streak = vnoise(vec2(u * 5.0, v * 0.6)) * 0.5 + 0.5;
		col *= 0.9 + grain * 0.14;
		col *= mix(1.0, 0.86, smoothstep(0.65, 0.95, streak) * 0.5);
	} else if (id < 0.5) {
		// Cut stone blocks in running bond, with mortar joints and worn edges.
		float row = floor(v / block_h);
		// Irregular bond: each course is shifted by a random amount, blocks vary in width.
		float off = (mod(row, 2.0) * 0.5 + hash(vec2(row, 1.7)) * 0.35) * block_w;
		float bw = block_w * (0.8 + hash(vec2(row, 9.1)) * 0.5);
		float colm = floor((u + off) / bw);
		vec2 f = vec2(fract((u + off) / bw) * bw, fract(v / block_h) * block_h);
		float edge = min(min(f.x, bw - f.x), min(f.y, block_h - f.y));
		float mortar = 1.0 - smoothstep(0.01, 0.022, edge + (vnoise(vec2(u, v) * 18.0) - 0.5) * 0.012);
		float bevel = smoothstep(0.015, 0.07, edge);
		float tone = hash(vec2(row, colm) + 0.37);
		vec3 stone = base * (0.9 + tone * 0.16) * (0.86 + grain * 0.26);
		stone *= mix(0.88, 1.0, bevel);
		col = mix(stone, base * 0.66, mortar);
		// Weathering: large stains and darker, damper stone low down.
		col *= 0.84 + 0.2 * fbm(vec2(u, v) * 0.35 + 11.0);
		// Upward faces gather moss and dirt.
		float up = smoothstep(0.55, 0.95, n.y);
		float m = smoothstep(0.45, 0.75, fbm(wpos.xz * 1.3 + wpos.y)) * moss;
		col = mix(col, vec3(0.30, 0.38, 0.18) * (0.8 + grain * 0.4), up * m);
		rough = 0.9;
	} else if (id < 0.7) {
		// Wood: fine grain along the member, darker knots.
		float g = vnoise(vec2(u * 2.5, v * 22.0)) * 0.6 + vnoise(vec2(u * 22.0, v * 2.5)) * 0.4;
		float knot = smoothstep(0.82, 0.95, vnoise(vec2(u, v) * 3.3));
		col *= 0.82 + g * 0.3;
		col *= 1.0 - knot * 0.25;
		rough = 0.8;
	} else if (id < 0.9) {
		// Roof tiles: overlapping rows down the slope, each tile rounded with a shadowed lower lip.
		float tile_h = 0.26;
		float tile_w = 0.24;
		float row = floor(v / tile_h);
		float off = mod(row, 2.0) * 0.5 * tile_w;
		float colm = floor((u + off) / tile_w);
		float fy = fract(v / tile_h);
		float fx = fract((u + off) / tile_w);
		float round_sh = 0.78 + 0.22 * sin(fx * 3.14159);
		float lip = mix(1.0, 0.62, smoothstep(0.7, 1.0, fy));
		float gap = smoothstep(0.0, 0.06, fx) * smoothstep(1.0, 0.94, fx);
		float tone = hash(vec2(row, colm) + 0.71);
		col = base * (0.84 + tone * 0.26) * round_sh * lip * mix(0.6, 1.0, gap);
		// Weathering: lichen and dirt patches.
		col = mix(col, col * vec3(0.9, 0.95, 0.75), smoothstep(0.6, 0.85, fbm(wpos.xz * 0.5)) * 0.5);
		rough = 0.7;
	} else {
		col *= 0.92 + grain * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}
