class_name Flora
extends RefCounted
## Detailed stylized vegetation and rocks, generated once and drawn with MultiMesh:
## branching trunks with root flare, pines from drooping needle-branch cards, bushes, and
## smooth noise-shaped boulders. Hand-painted look (owner: environment must be more detailed, 14-11-2026).

static var _needle_tex: ImageTexture


## A tapered trunk with a root flare and two branches that lead to the side crowns
## (side crowns sit at (0.9, 3.6, 0.3) and (-0.7, 3.8, -0.6), the main crown at (0, 4.2, 0)).
static func broadleaf_trunk() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_limb(st, Vector3(0, -0.2, 0), Vector3(0.05, 4.0, 0.02), 0.36, 0.14, 10, true)
	_limb(st, Vector3(0, 2.2, 0), Vector3(0.85, 3.4, 0.28), 0.15, 0.06, 7, false)
	_limb(st, Vector3(0, 2.5, 0), Vector3(-0.65, 3.6, -0.55), 0.14, 0.05, 7, false)
	st.index()
	st.generate_normals()
	return st.commit()


## A trunk for pines: straight, tapering to a point inside the canopy.
static func pine_trunk() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_limb(st, Vector3(0, -0.2, 0), Vector3(0, 7.5, 0), 0.3, 0.03, 9, true)
	st.index()
	st.generate_normals()
	return st.commit()


static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, flare: bool) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up2: Vector3 = axis.cross(side).normalized()
	var rings: int = 6
	var pts: Array[PackedVector3Array] = []
	for r: int in rings + 1:
		var t: float = float(r) / rings
		var rad: float = lerpf(r0, r1, t)
		if flare:
			rad *= 1.0 + 0.9 * pow(1.0 - t, 6.0)
		# A gentle bend makes the trunk feel grown, not extruded.
		var c: Vector3 = a.lerp(b, t) + side * sin(t * PI) * 0.08
		var row := PackedVector3Array()
		for s: int in sides:
			var ang: float = TAU * float(s) / sides
			var bump: float = 1.0 + (0.18 * sin(ang * 3.0 + t * 4.0) if flare else 0.0) * pow(1.0 - t, 3.0)
			row.append(c + (side * cos(ang) + up2 * sin(ang)) * rad * bump)
		pts.append(row)
	for r: int in rings:
		var shade: float = lerpf(0.75, 1.1, float(r) / rings)
		for s: int in sides:
			var s2: int = (s + 1) % sides
			for p: Vector3 in [pts[r][s], pts[r + 1][s], pts[r][s2], pts[r][s2], pts[r + 1][s], pts[r + 1][s2]]:
				st.set_color(Color(shade, shade, shade))
				st.add_vertex(p)


## Needle-branch texture: a central twig with many thin needles, alpha-cut.
static func needle_texture() -> ImageTexture:
	if _needle_tex:
		return _needle_tex
	var w: int = 128
	var img := Image.create(w, w, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	# A spruce branch: a filled, tapering body with jagged needle edges (reads as dense foliage
	# at a distance, still shows needles up close). UV y runs from the trunk (0) to the tip (1).
	for y: int in w:
		var t: float = float(y) / (w - 1)
		var half: float = lerpf(0.3, 0.46, sin(t * PI * 0.85)) * w * (1.0 - t * 0.55)
		for x: int in w:
			var dx: float = absf(x - w * 0.5)
			var jag: float = (sin(y * 1.7 + (1.0 if x > w / 2 else 0.0) * 2.0) * 0.5 + 0.5) * 7.0
			if dx < half - jag:
				var tone: float = 0.55 + 0.45 * (1.0 - dx / maxf(half, 1.0)) * rng.randf_range(0.8, 1.0)
				img.set_pixel(x, y, Color(tone, tone, tone, 1.0))
	# Needle strokes over the body for texture.
	for k: int in 240:
		var t2: float = rng.randf()
		var base := Vector2(w * 0.5, 4 + t2 * (w - 8))
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var len: float = lerpf(50.0, 18.0, t2) * rng.randf_range(0.7, 1.0)
		var dir := Vector2(side, 0.6).normalized()
		var tone2: float = rng.randf_range(0.75, 1.0)
		for i: int in int(len):
			var p: Vector2 = base + dir * i
			for dx2: int in 3:
				var x2: int = int(p.x) + dx2 - 1
				var y2: int = int(p.y)
				if x2 >= 0 and y2 >= 0 and x2 < w and y2 < w:
					img.set_pixel(x2, y2, Color(tone2, tone2, tone2, 1.0))
	img.generate_mipmaps()
	_needle_tex = ImageTexture.create_from_image(img)
	return _needle_tex


static func needle_material(light: Color, dark: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/leaf_cards.gdshader")
	m.set_shader_parameter("leaf_tex", needle_texture())
	m.set_shader_parameter("light_color", light)
	m.set_shader_parameter("dark_color", dark)
	m.set_shader_parameter("sway_strength", 0.05)
	m.set_shader_parameter("alpha_cut", 0.35)
	return m


## Pine canopy: tiers of drooping branch cards around the trunk, wide at the bottom, narrow on top.
## Vertex colour red = light (top and outer tips bright, inner and lower dark).
static func pine_canopy(height: float, base_radius: float, tiers: int, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for t: int in tiers:
		var k: float = float(t) / maxf(tiers - 1, 1)
		var y: float = lerpf(1.6, height - 0.4, k)
		var rad: float = lerpf(base_radius, 0.35, pow(k, 0.9))
		var count: int = int(lerpf(13.0, 6.0, k))
		for i: int in count:
			var a: float = TAU * (float(i) + rng.randf() * 0.4) / count + t * 0.6
			var out := Vector3(cos(a), 0, sin(a))
			var side := Vector3(-out.z, 0, out.x)
			var root: Vector3 = Vector3(0, y, 0) + out * 0.1
			var tip: Vector3 = Vector3(0, y - rad * 0.85 - 0.3, 0) + out * rad
			var wdt: float = rad * 0.85 + 0.45
			var corners: Array = [root - side * wdt * 0.25, root + side * wdt * 0.25, tip + side * wdt * 0.5, tip - side * wdt * 0.5]
			var uvs: Array = [Vector2(0.3, 0), Vector2(0.7, 0), Vector2(1, 1), Vector2(0, 1)]
			var light: Array = [0.15 + k * 0.4, 0.15 + k * 0.4, 0.55 + k * 0.45, 0.55 + k * 0.45]
			for q: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = corners[q]
				st.set_color(Color(clampf(light[q], 0.0, 1.0), 0, 0))
				st.set_uv(uvs[q])
				st.set_normal((Vector3(p.x, 0.0, p.z).normalized() + Vector3.UP * 0.6).normalized())
				st.add_vertex(p)
	return st.commit()


## A smooth boulder: a sphere pushed in and out by noise, flattened at the base.
static func boulder(seed: int, detail: int = 14) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = detail * 2
	sm.rings = detail
	var arrays: Array = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var n: float = noise.get_noise_3dv(v * 1.3) * 0.28 + noise.get_noise_3dv(v * 3.1) * 0.08
		v *= 1.0 + n
		# Facet planes: a few large flattened faces read as cleft stone.
		v.y = maxf(v.y, -0.45)
		v.y *= 0.72
		verts[i] = v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i: int in idx.size():
		var p: Vector3 = verts[idx[i]]
		var shade: float = 0.8 + 0.25 * clampf(p.y + 0.3, 0.0, 1.0)
		st.set_color(Color(shade, shade, shade))
		st.add_vertex(p)
	st.index()
	st.generate_normals()
	return st.commit()
