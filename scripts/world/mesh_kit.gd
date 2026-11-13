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


func is_empty() -> bool:
	return _count == 0


func commit() -> ArrayMesh:
	_st.generate_normals()
	return _st.commit()


static func vertex_color_material(roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	return m
