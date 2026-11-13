class_name ItemIcon
extends Control
## Vector item icon drawn in code: one shape, one accent colour, a light inner glow.
## Designed on a 32 px grid and scaled to the control size.

var item_id: String = "":
	set(v):
		item_id = v
		queue_redraw()


func _init(id: String = "", px: float = 32.0) -> void:
	item_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)


static func has_icon(id: String) -> bool:
	return id in ["coins", "veil_dust", "warden_sigil", "hollow_fang", "salted_fish"]


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 32.0
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	var dark := Color(0.07, 0.08, 0.1, 0.9)
	match item_id:
		"coins":
			var col := Color("d9a441")
			for o: Vector2 in [Vector2(-5, 5), Vector2(6, 3), Vector2(0, -5)]:
				draw_circle(o, 8.5, dark)
				draw_circle(o, 7.0, col)
				draw_circle(o, 4.5, col.lightened(0.35))
				draw_arc(o, 4.5, 0.0, TAU, 20, col.darkened(0.25), 1.0, true)
		"veil_dust":
			var col2 := Color("c9c6b8")
			var pile := PackedVector2Array([Vector2(-12, 10), Vector2(-6, 2), Vector2(0, -3), Vector2(7, 2), Vector2(12, 10)])
			_shape(pile, col2.darkened(0.25), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 9), Vector2(-2, 3), Vector2(0, 1), Vector2(4, 4), Vector2(7, 9)]), col2.lightened(0.3))
			for p: Vector2 in [Vector2(-7, -8), Vector2(6, -10), Vector2(1, -12)]:
				_shape(_diamond(p, 2.6), Color("6ec3f0").lightened(0.5), dark)
		"warden_sigil":
			var col3 := Color("d9a441")
			var sh := PackedVector2Array([Vector2(-10, -11), Vector2(10, -11), Vector2(10, 1), Vector2(6, 8), Vector2(0, 12), Vector2(-6, 8), Vector2(-10, 1)])
			_shape(sh, col3.darkened(0.2), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -7), Vector2(6, -7), Vector2(6, 0), Vector2(0, 7), Vector2(-6, 0)]), col3.lightened(0.3))
			# Crown mark: band plus three points.
			var mark: Color = col3.darkened(0.5)
			draw_rect(Rect2(-4, -1.5, 8, 3), mark)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -1.5), Vector2(-4, -5), Vector2(-1.5, -1.5)]), mark)
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -1.5), Vector2(0, -6), Vector2(2, -1.5)]), mark)
			draw_colored_polygon(PackedVector2Array([Vector2(1.5, -1.5), Vector2(4, -5), Vector2(4, -1.5)]), mark)
		"hollow_fang":
			var col4 := Color("e6e1d3")
			var claw := PackedVector2Array([Vector2(-11, -8), Vector2(-3, -12), Vector2(6, -7), Vector2(11, 3), Vector2(10, 12), Vector2(4, 2), Vector2(-3, -3), Vector2(-9, -3)])
			draw_polyline(_closed(claw), dark, 3.0, true)
			# Split the concave claw into convex pieces.
			draw_colored_polygon(PackedVector2Array([claw[0], claw[1], claw[6], claw[7]]), col4.darkened(0.12))
			draw_colored_polygon(PackedVector2Array([claw[1], claw[2], claw[5], claw[6]]), col4.darkened(0.12))
			draw_colored_polygon(PackedVector2Array([claw[2], claw[3], claw[4], claw[5]]), col4.darkened(0.12))
			draw_polyline(PackedVector2Array([Vector2(-7, -7), Vector2(-2, -8.5), Vector2(4, -4.5), Vector2(8, 3)]), Color.WHITE, 2.0, true)
			draw_line(Vector2(-11, -8), Vector2(-9, -3), Color("d9552e"), 2.0, true)
		"salted_fish":
			var col5 := Color("6ec3f0")
			var body := PackedVector2Array([Vector2(-13, 0), Vector2(-7, -6), Vector2(1, -7), Vector2(7, -3), Vector2(7, 3), Vector2(1, 7), Vector2(-7, 6)])
			var tail := PackedVector2Array([Vector2(6, 0), Vector2(13, -7), Vector2(11, 0), Vector2(13, 7)])
			draw_polyline(_closed(tail), dark, 3.0, true)
			draw_colored_polygon(PackedVector2Array([tail[0], tail[1], tail[2]]), col5.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([tail[0], tail[2], tail[3]]), col5.darkened(0.25))
			_shape(body, col5.darkened(0.1), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(-5, -3.5), Vector2(1, -4), Vector2(4, -1), Vector2(0, 2), Vector2(-5, 2.5)]), col5.lightened(0.4))
			draw_circle(Vector2(-8, -1.5), 1.4, dark)
		_:
			var data: Dictionary = Inventory.item_data(item_id)
			var col6: Color = data.get("color", Color("e6e1d3"))
			_shape(_diamond(Vector2.ZERO, 11.0), col6.darkened(0.15), dark)
			draw_colored_polygon(_diamond(Vector2(0, -1), 5.5), col6.lightened(0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shape(pts: PackedVector2Array, fill: Color, line: Color) -> void:
	draw_polyline(_closed(pts), line, 3.0, true)
	draw_colored_polygon(pts, fill)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c


func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
