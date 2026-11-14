class_name ArmorKit
extends RefCounted
## Smooth armour pieces generated in code, in a hand-painted style (thick gold rims, layered plates).
## Style reference: stylized MMO armour (owner, 14-11-2026). Own design; nothing is copied.


## Hand-painted look: light is "painted in" with a top-down gradient, a soft two-tone ramp and a rim.
static func painted(color: Color, rim: float = 0.25, metal: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/painted.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rim_amount", rim)
	m.set_shader_parameter("spec_amount", 0.35 if metal else 0.05)
	return m


## Ellipsoid cap (dome) around +Y, from the top down to `theta_max` radians, over the angle range
## [phi0, phi1]. A gold rim tube runs along the lower edge when rim_mat is given.
## Returns [shell_mesh, rim_mesh_or_null].
static func shell(rx: float, ry: float, rz: float, theta_max: float, phi0: float = 0.0, phi1: float = TAU,
		thickness: float = 0.025, rim_radius: float = 0.022, rings: int = 10, segs: int = 28) -> Array:
	var full: bool = is_equal_approx(phi1 - phi0, TAU)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = segs if full else segs + 1
	var outer: Array[PackedVector3Array] = []
	for r: int in rings + 1:
		var th: float = theta_max * float(r) / rings
		var row := PackedVector3Array()
		for c: int in cols:
			var ph: float = phi0 + (phi1 - phi0) * float(c) / (segs if not full else segs)
			row.append(Vector3(sin(th) * cos(ph) * rx, cos(th) * ry, sin(th) * sin(ph) * rz))
		outer.append(row)
	var wrap: int = cols if full else cols - 1
	for layer: int in 2:
		var k: float = 1.0 if layer == 0 else (1.0 - thickness / maxf(ry, 0.01))
		for r: int in rings:
			for c: int in wrap:
				var c2: int = (c + 1) % cols
				var a: Vector3 = outer[r][c] * k
				var b: Vector3 = outer[r][c2] * k
				var d: Vector3 = outer[r + 1][c] * k
				var e: Vector3 = outer[r + 1][c2] * k
				var tri: Array = [a, d, b, b, d, e] if layer == 0 else [a, b, d, b, e, d]
				for v: Vector3 in tri:
					st.add_vertex(v)
	st.index()
	st.generate_normals()
	var shell_mesh: ArrayMesh = st.commit()
	# Rim: a tube along the bottom edge.
	var edge := PackedVector3Array()
	for c: int in cols:
		edge.append(outer[rings][c])
	if full:
		edge.append(outer[rings][0])
	return [shell_mesh, tube(edge, rim_radius)]


## A tube of radius `r` along a polyline (smooth normals).
static func tube(path: PackedVector3Array, r: float, sides: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i: int in path.size():
		var t: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var up: Vector3 = Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
		var n: Vector3 = t.cross(up).normalized()
		var b: Vector3 = t.cross(n).normalized()
		var ring := PackedVector3Array()
		for s: int in sides:
			var a: float = TAU * float(s) / sides
			ring.append(path[i] + (n * cos(a) + b * sin(a)) * r)
		rings.append(ring)
	for i: int in path.size() - 1:
		for s: int in sides:
			var s2: int = (s + 1) % sides
			for v: Vector3 in [rings[i][s], rings[i][s2], rings[i + 1][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


## Tapered band (bracer, greave, boot cuff): open cylinder with thickness and gold rims top and bottom.
## Returns [band_mesh, rim_top, rim_bottom].
static func band(r_top: float, r_bottom: float, height: float, rim_radius: float = 0.016, segs: int = 24) -> Array:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 2
	var top := PackedVector3Array()
	var bot := PackedVector3Array()
	for s: int in segs + 1:
		var a: float = TAU * float(s) / segs
		top.append(Vector3(cos(a) * r_top, height * 0.5, sin(a) * r_top))
		bot.append(Vector3(cos(a) * r_bottom, -height * 0.5, sin(a) * r_bottom))
	return [cm, tube(top, rim_radius), tube(bot, rim_radius)]


## Fur tufts: a ring of alpha-cut cards (reuses the leaf texture as strands) for collars and pauldron trims.
static func fur_ring(radius: float, count: int, length: float, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i: int in count:
		var a: float = TAU * (float(i) + rng.randf() * 0.5) / count
		var out := Vector3(cos(a), 0, sin(a))
		var p: Vector3 = out * radius
		var side := Vector3(-out.z, 0, out.x) * length * 0.35
		var tip: Vector3 = p + out * length * 0.6 + Vector3.DOWN * length * 0.7
		var quad: Array = [p - side, p + side, tip + side * 0.6, tip - side * 0.6]
		var uvs: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.set_normal((out + Vector3.UP * 0.5).normalized())
			st.add_vertex(quad[k])
	return st.commit()
