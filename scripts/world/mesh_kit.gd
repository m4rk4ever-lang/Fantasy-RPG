class_name MeshKit
extends RefCounted
## Builds one merged, vertex-colored, flat-shaded mesh from many simple shapes.
## A whole house (or village) becomes a single draw call, which keeps the web build fast.

var _st := SurfaceTool.new()
var _count: int = 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_smooth_group(0xFFFFFFFF)  # Flat shading: crisp, stylized faces.


func _tri(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_st.set_color(col)
	_st.add_vertex(xf * a)
	_st.set_color(col)
	_st.add_vertex(xf * b)
	_st.set_color(col)
	_st.add_vertex(xf * c)
	_count += 1


func _quad(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	# a-b-c-d counter-clockwise seen from outside; Godot front faces are clockwise, so emit reversed.
	_tri(xf, a, c, b, col)
	_tri(xf, a, d, c, col)


## Axis-aligned box of `size` centered at the transform's origin.
func box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h: Vector3 = size * 0.5
	var p := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var shade_top: Color = col.lightened(0.04)
	_quad(xf, p[4], p[5], p[6], p[7], col)  # +Z
	_quad(xf, p[1], p[0], p[3], p[2], col)  # -Z
	_quad(xf, p[5], p[1], p[2], p[6], col)  # +X
	_quad(xf, p[0], p[4], p[7], p[3], col)  # -X
	_quad(xf, p[7], p[6], p[2], p[3], shade_top)  # +Y
	_quad(xf, p[0], p[1], p[5], p[4], col.darkened(0.2))  # -Y


## Gable roof: ridge along local X. `size` = (length, height, depth). Overhang included by caller.
func gable(xf: Transform3D, size: Vector3, col: Color) -> void:
	var l: float = size.x * 0.5
	var hh: float = size.y
	var d: float = size.z * 0.5
	var a := Vector3(-l, 0, -d)
	var b := Vector3(l, 0, -d)
	var c := Vector3(l, 0, d)
	var e := Vector3(-l, 0, d)
	var r0 := Vector3(-l, hh, 0)
	var r1 := Vector3(l, hh, 0)
	_quad(xf, b, a, r0, r1, col)  # front slope (-Z)
	_quad(xf, e, c, r1, r0, col.darkened(0.06))  # back slope (+Z)
	_tri(xf, a, r0, e, col.darkened(0.1))  # gable ends (thin, roof colored)
	_tri(xf, c, r1, b, col.darkened(0.1))
	_quad(xf, a, b, c, e, col.darkened(0.3))  # underside


## Gable wall triangle (fills the wall under a gable roof). Width along X, apex up.
func gable_wall(xf: Transform3D, width: float, height: float, col: Color) -> void:
	var l: float = width * 0.5
	_tri(xf, Vector3(-l, 0, 0), Vector3(0, height, 0), Vector3(l, 0, 0), col)
	_tri(xf, Vector3(-l, 0, 0), Vector3(l, 0, 0), Vector3(0, height, 0), col)


## Upright cylinder (prism with `segs` sides), centered at origin, height along Y.
func cylinder(xf: Transform3D, radius_top: float, radius_bottom: float, height: float, segs: int, col: Color) -> void:
	var h: float = height * 0.5
	for i: int in segs:
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var b0 := Vector3(cos(a0) * radius_bottom, -h, sin(a0) * radius_bottom)
		var b1 := Vector3(cos(a1) * radius_bottom, -h, sin(a1) * radius_bottom)
		var t0 := Vector3(cos(a0) * radius_top, h, sin(a0) * radius_top)
		var t1 := Vector3(cos(a1) * radius_top, h, sin(a1) * radius_top)
		_quad(xf, b0, t0, t1, b1, col)
		if radius_top > 0.0:
			_tri(xf, Vector3(0, h, 0), t0, t1, col.lightened(0.04))


## Lofted body segment: elliptical cross-sections stacked along Y (faceted, low-poly anatomy).
## Each ring: [y, radius_x, radius_z, offset_z, color] (+ optional offset_x as 6th entry).
## The band between ring i and i+1 takes ring i's color. Rings may go up or down.
func loft(xf: Transform3D, rings: Array, segs: int = 8, cap_start: bool = true, cap_end: bool = true) -> void:
	var rs: Array = rings.duplicate()
	var bands: Array[Color] = []
	for i: int in rs.size() - 1:
		bands.append(rs[i][4])
	var caps: Array[bool] = [cap_start, cap_end]
	if float(rs[0][0]) > float(rs[rs.size() - 1][0]):
		rs.reverse()
		bands.reverse()
		caps.reverse()
	var pts: Array[PackedVector3Array] = []
	for r: Array in rs:
		var row := PackedVector3Array()
		var ox: float = r[5] if r.size() > 5 else 0.0
		for i: int in segs:
			# Offset by half a segment so a flat face points forward (-Z): reads cleaner.
			var a: float = TAU * (float(i) + 0.5) / segs
			row.append(Vector3(cos(a) * float(r[1]) + ox, float(r[0]), sin(a) * float(r[2]) + float(r[3])))
		pts.append(row)
	for k: int in rs.size() - 1:
		for i: int in segs:
			var j: int = (i + 1) % segs
			_quad(xf, pts[k][i], pts[k + 1][i], pts[k + 1][j], pts[k][j], bands[k])
	if caps[0]:
		var c0 := Vector3.ZERO
		for p: Vector3 in pts[0]:
			c0 += p
		c0 /= segs
		for i: int in segs:
			_tri(xf, c0, pts[0][(i + 1) % segs], pts[0][i], bands[0])
	if caps[1]:
		var last: int = rs.size() - 1
		var c1 := Vector3.ZERO
		for p: Vector3 in pts[last]:
			c1 += p
		c1 /= segs
		for i: int in segs:
			_tri(xf, c1, pts[last][i], pts[last][(i + 1) % segs], bands[bands.size() - 1])


## Wedge (triangular prism) pointing along -Z: noses, claws, blade tips, fringe.
func wedge(xf: Transform3D, size: Vector3, col: Color) -> void:
	var w: float = size.x * 0.5
	var h: float = size.y * 0.5
	var d: float = size.z * 0.5
	var a := Vector3(-w, -h, d)
	var b := Vector3(w, -h, d)
	var c := Vector3(w, h, d)
	var e := Vector3(-w, h, d)
	var tip := Vector3(0, 0, -d)
	_quad(xf, a, b, c, e, col)  # back face (+Z)
	_tri(xf, tip, a, b, col.darkened(0.15))  # bottom
	_tri(xf, tip, c, e, col.lightened(0.05))  # top
	_tri(xf, tip, b, c, col)  # right
	_tri(xf, tip, e, a, col)  # left


## Free quad from four corners, counter-clockwise seen from the front (capes, rags, shutters).
## `double_sided` also emits the back face (slightly darker unless `back_col` is given).
func quad(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, double_sided: bool = false, back_col: Color = Color(0, 0, 0, 0)) -> void:
	_quad(xf, a, b, c, d, col)
	if double_sided:
		var bc: Color = back_col if back_col.a > 0.0 else col.darkened(0.18)
		_quad(xf, d, c, b, a, bc)


## Free triangle, counter-clockwise seen from the front. Optionally double-sided.
func tri(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, col: Color, double_sided: bool = false) -> void:
	_tri(xf, a, c, b, col)
	if double_sided:
		_tri(xf, a, b, c, col.darkened(0.18))


## Number of triangles added so far (polygon budget checks).
func tri_count() -> int:
	return _count


func is_empty() -> bool:
	return _count == 0


func commit() -> ArrayMesh:
	_st.generate_normals()
	return _st.commit()


## Building materials (stone blocks, roof tiles, wood grain, plaster) from the vertex colour alpha.
## See shaders/architecture.gdshader. `override_id` >= 0 forces one material for the whole mesh.
static func architecture_material(override_id: float = -1.0, color: Color = Color.WHITE, cylindrical: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/architecture.gdshader")
	m.set_shader_parameter("override_id", override_id)
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("cylindrical", cylindrical)
	if cylindrical:
		# Column drums: tall courses, few vertical joints.
		m.set_shader_parameter("block_h", 0.62)
		m.set_shader_parameter("block_w", 2.4)
	return m


static func vertex_color_material(roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	return m
