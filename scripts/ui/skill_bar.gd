class_name SkillBar
extends HBoxContainer
## RuneScape-style ability bar. Displays cooldown and usable state, reports clicks.
## Holds no gameplay logic.

signal skill_clicked(id: String)

const COL_PANEL := Color(0.12, 0.13, 0.16, 0.8)
const COL_FRAME := Color("e6e1d3")
const COL_FIRE := Color("d9552e")
const SLOT_SIZE := Vector2(64, 64)

var _slots: Dictionary = {}  # id -> Slot


class Icon:
	extends Control
	var kind: int = 0
	var tint: Color = Color.WHITE
	var mark_color: Color = Color("e6e1d3")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var c := size * 0.5
		var base := StyleBoxFlat.new()
		base.bg_color = tint.darkened(0.15)
		base.set_corner_radius_all(10)
		base.anti_aliasing = true
		draw_style_box(base, Rect2(c - Vector2(21, 21), Vector2(42, 42)))
		var hi := StyleBoxFlat.new()
		hi.bg_color = tint.lightened(0.12)
		hi.set_corner_radius_all(7)
		hi.anti_aliasing = true
		draw_style_box(hi, Rect2(c - Vector2(17, 17), Vector2(34, 34)))
		var shadow := Color(0, 0, 0, 0.5)
		var w := 4.0
		match kind:
			4:  # item: faceted gem / food token
				var d := PackedVector2Array([c + Vector2(0, -12), c + Vector2(11, 0), c + Vector2(0, 12), c + Vector2(-11, 0)])
				draw_colored_polygon(d, mark_color)
				draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), shadow, 2.0, true)
			0:  # downward chevron, doubled (slam)
				for dy in [-7.0, 3.0]:
					var o := Vector2(0, dy)
					var pts := PackedVector2Array([c + o + Vector2(-11, -4), c + o + Vector2(0, 6), c + o + Vector2(11, -4)])
					var pts_s := PackedVector2Array([pts[0] + Vector2(0, 1.5), pts[1] + Vector2(0, 1.5), pts[2] + Vector2(0, 1.5)])
					draw_polyline(pts_s, shadow, w, true)
					draw_polyline(pts, mark_color, w, true)
			1:  # arrow pointing right
				draw_line(c + Vector2(-12, 1.5), c + Vector2(11, 1.5), shadow, w, true)
				draw_polyline(PackedVector2Array([c + Vector2(2, -9.5), c + Vector2(12, 1.5), c + Vector2(2, 12.5)]), shadow, w, true)
				draw_line(c + Vector2(-12, 0), c + Vector2(11, 0), mark_color, w, true)
				draw_polyline(PackedVector2Array([c + Vector2(2, -11), c + Vector2(12, 0), c + Vector2(2, 11)]), mark_color, w, true)
			2:  # ring
				draw_arc(c + Vector2(0, 1.5), 10.0, 0.0, TAU, 40, shadow, w, true)
				draw_arc(c, 10.0, 0.0, TAU, 40, mark_color, w, true)
			3:  # plus
				draw_line(c + Vector2(-11, 1.5), c + Vector2(11, 1.5), shadow, w + 1, true)
				draw_line(c + Vector2(0, -9.5), c + Vector2(0, 12.5), shadow, w + 1, true)
				draw_line(c + Vector2(-11, 0), c + Vector2(11, 0), mark_color, w + 1, true)
				draw_line(c + Vector2(0, -11), c + Vector2(0, 11), mark_color, w + 1, true)


class Sweep:
	extends Control
	var fraction: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	## Radial sweep (clockwise from 12 o'clock) over the remaining cooldown, like RuneScape.
	func _draw() -> void:
		var f: float = clampf(fraction, 0.0, 1.0)
		if f <= 0.0:
			return
		var c: Vector2 = size * 0.5
		var r: float = size.length() * 0.5
		var pts := PackedVector2Array([c])
		var steps: int = maxi(2, int(48 * f))
		var start: float = -PI * 0.5 + TAU * (1.0 - f)
		for i: int in steps + 1:
			var a: float = start + TAU * f * float(i) / steps
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
			p.x = clampf(p.x, 3.0, size.x - 3.0)
			p.y = clampf(p.y, 3.0, size.y - 3.0)
			pts.append(p)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.62))


class Slot:
	var id: String
	var button: Button
	var style: StyleBoxFlat
	var icon: Icon
	var sweep: Sweep
	var time_label: Label
	var usable: bool = true
	var tween: Tween
	var total_cd: float = 0.0


func setup(skills: Array[Dictionary]) -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in skills.size():
		_build_slot(skills[i], i)


func _build_slot(skill: Dictionary, index: int) -> void:
	var slot := Slot.new()
	slot.id = str(skill.get("id", ""))
	slot.total_cd = float(skill.get("cooldown", 0.0))

	var btn := Button.new()
	btn.custom_minimum_size = SLOT_SIZE
	btn.size = SLOT_SIZE
	btn.pivot_offset = SLOT_SIZE * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.clip_contents = false
	btn.tooltip_text = "%s\n%s\nCooldown: %ss" % [
		str(skill.get("name", "")), str(skill.get("description", "")), _fmt_num(slot.total_cd)]

	slot.style = StyleBoxFlat.new()
	slot.style.bg_color = COL_PANEL
	slot.style.border_color = COL_FRAME
	slot.style.set_border_width_all(2)
	slot.style.set_corner_radius_all(6)
	slot.style.anti_aliasing = true
	btn.add_theme_stylebox_override("normal", slot.style)
	btn.add_theme_stylebox_override("hover", slot.style)
	btn.add_theme_stylebox_override("pressed", slot.style)
	btn.add_theme_stylebox_override("disabled", slot.style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(func() -> void: skill_clicked.emit(slot.id))
	add_child(btn)

	slot.icon = Icon.new()
	slot.icon.kind = index
	slot.icon.tint = skill.get("color", COL_FRAME)
	btn.add_child(slot.icon)

	slot.sweep = Sweep.new()
	slot.sweep.visible = false
	btn.add_child(slot.sweep)

	slot.time_label = Label.new()
	slot.time_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.time_label.add_theme_color_override("font_color", COL_FRAME)
	slot.time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	slot.time_label.add_theme_constant_override("outline_size", 5)
	slot.time_label.add_theme_font_size_override("font_size", 20)
	slot.time_label.visible = false
	btn.add_child(slot.time_label)

	var key := Label.new()
	key.text = str(skill.get("key_label", ""))
	key.position = Vector2(6, 2)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_color_override("font_color", COL_FRAME)
	key.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	key.add_theme_constant_override("outline_size", 4)
	key.add_theme_font_size_override("font_size", 13)
	btn.add_child(key)

	slot.button = btn
	_slots[slot.id] = slot


func set_cooldown(id: String, remaining: float, total: float) -> void:
	var slot := _slots.get(id) as Slot
	if slot == null:
		return
	if remaining <= 0.0 or total <= 0.0:
		slot.sweep.visible = false
		slot.time_label.visible = false
		return
	slot.sweep.fraction = remaining / total
	slot.sweep.visible = true
	slot.sweep.queue_redraw()
	slot.time_label.text = "%.1f" % remaining if remaining < 10.0 else str(int(ceil(remaining)))
	slot.time_label.visible = true


func set_usable(id: String, usable: bool) -> void:
	var slot := _slots.get(id) as Slot
	if slot == null:
		return
	if slot.usable == usable:
		return
	slot.usable = usable
	slot.icon.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.45)
	if slot.tween == null or not slot.tween.is_running():
		slot.style.border_color = _base_border(slot)


func flash(id: String) -> void:
	var slot := _slots.get(id) as Slot
	if slot == null:
		return
	if slot.tween != null and slot.tween.is_valid():
		slot.tween.kill()
	slot.button.pivot_offset = slot.button.size * 0.5
	slot.style.border_color = Color.WHITE
	slot.tween = create_tween().set_parallel(true)
	slot.tween.tween_property(slot.button, "scale", Vector2(1.12, 1.12), 0.09)
	slot.tween.chain().tween_property(slot.button, "scale", Vector2.ONE, 0.09)
	slot.tween.tween_property(slot.style, "border_color", _base_border(slot), 0.18)


func _base_border(slot: Slot) -> Color:
	return COL_FRAME if slot.usable else COL_FIRE


func _fmt_num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
