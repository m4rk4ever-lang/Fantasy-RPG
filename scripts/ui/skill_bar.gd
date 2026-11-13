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
		match kind % 4:
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


## Small padlock for skills that are not learned yet.
class Lock:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 2)
		var dark := Color(0.07, 0.08, 0.1, 0.95)
		var stone := Color("e6e1d3")
		draw_arc(c + Vector2(0, -5), 7.0, PI, TAU, 16, dark, 6.0, true)
		draw_arc(c + Vector2(0, -5), 7.0, PI, TAU, 16, stone, 3.0, true)
		draw_rect(Rect2(c + Vector2(-11.5, -5.5), Vector2(23, 18)), dark)
		draw_rect(Rect2(c + Vector2(-10, -4), Vector2(20, 15)), stone)
		draw_rect(Rect2(c + Vector2(-10, -4), Vector2(20, 3)), Color.WHITE)
		draw_circle(c + Vector2(0, 2.5), 2.6, Color("d9552e"))
		draw_rect(Rect2(c + Vector2(-1, 3), Vector2(2, 5)), Color("d9552e"))


## Slot button with a tooltip in the shared panel style: name, cooldown, description.
class SlotButton:
	extends Button
	var skill: Dictionary = {}
	var locked: bool = false

	func _make_custom_tooltip(_for_text: String) -> Object:
		return SkillBar.build_tooltip(skill, locked)


class Slot:
	var id: String
	var lock: Lock
	var locked: bool = false
	var cooling: bool = false
	var button: SlotButton
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
	theme = UiStyle.tooltip_theme()
	for i in skills.size():
		_build_slot(skills[i], i)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()


## Curved stone bar behind the slots: flat base, shallow arch on top, gold inner line.
func _draw() -> void:
	if size.x < 8.0:
		return
	var pad: float = 12.0
	var rise: float = 7.0
	var x0: float = -pad
	var x1: float = size.x + pad
	var y1: float = size.y + pad - 2.0
	var arch := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps: int = 24
	for i: int in steps + 1:
		var t: float = float(i) / steps
		var bump: float = sin(t * PI) * rise
		arch.append(Vector2(lerpf(x0, x1, t), -pad + 2.0 - bump))
		inner.append(Vector2(lerpf(x0 + 4.0, x1 - 4.0, t), -pad + 6.0 - bump))
	var poly := arch.duplicate()
	poly.append(Vector2(x1, y1))
	poly.append(Vector2(x0, y1))
	# Convex (arch bulges outward), so one polygon is safe.
	draw_colored_polygon(poly, Color(UiStyle.SLATE_DARK, 0.95))
	var band := arch.duplicate()
	band.append(Vector2(x1, 6.0))
	band.append(Vector2(x0, 6.0))
	draw_colored_polygon(band, Color(UiStyle.SLATE_LIGHT, 0.9))
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, UiStyle.STONE, 1.5, true)
	draw_polyline(inner, Color(UiStyle.GOLD, 0.85), 1.0, true)
	UiStyle.draw_crown(self, Vector2(size.x * 0.5, -pad + 3.0 - rise), 10.0, 7.0)
	UiStyle.draw_gem(self, Vector2(x0, -pad + 2.0), 3.0)
	UiStyle.draw_gem(self, Vector2(x1, -pad + 2.0), 3.0)


static func build_tooltip(skill: Dictionary, locked: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var name_l := Label.new()
	name_l.text = str(skill.get("name", ""))
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	box.add_child(name_l)
	var cd := Label.new()
	var cd_v: float = float(skill.get("cooldown", 0.0))
	cd.text = "Cooldown: %ss   ·   Key %s" % [str(int(cd_v)) if is_equal_approx(cd_v, roundf(cd_v)) else "%.1f" % cd_v, str(skill.get("key_label", ""))]
	cd.add_theme_font_size_override("font_size", 13)
	cd.add_theme_color_override("font_color", Color("6ec3f0"))
	box.add_child(cd)
	var desc := Label.new()
	desc.text = str(skill.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(260, 0)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UiStyle.STONE)
	box.add_child(desc)
	if locked:
		var lk := Label.new()
		lk.text = "Locked. Learn it in the skill tree [K]."
		lk.add_theme_font_size_override("font_size", 13)
		lk.add_theme_color_override("font_color", UiStyle.FIRE.lightened(0.2))
		box.add_child(lk)
	return box


func _build_slot(skill: Dictionary, index: int) -> void:
	var slot := Slot.new()
	slot.id = str(skill.get("id", ""))
	slot.total_cd = float(skill.get("cooldown", 0.0))

	var btn := SlotButton.new()
	btn.skill = skill
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

	slot.lock = Lock.new()
	slot.lock.visible = false
	btn.add_child(slot.lock)

	var key := Label.new()
	key.text = str(skill.get("key_label", ""))
	key.position = Vector2(6, 1)
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
		if slot.cooling:
			slot.cooling = false
			flash_ready(id)
		return
	slot.cooling = true
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
	if not slot.locked:
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
	slot.style.set_border_width_all(2)
	slot.tween = create_tween().set_parallel(true)
	slot.tween.tween_property(slot.button, "scale", Vector2(1.12, 1.12), 0.09)
	slot.tween.chain().tween_property(slot.button, "scale", Vector2.ONE, 0.09)
	slot.tween.tween_property(slot.style, "border_color", _base_border(slot), 0.18)


## Gold rim that lights up briefly when a skill comes off cooldown.
func flash_ready(id: String) -> void:
	var slot := _slots.get(id) as Slot
	if slot == null or slot.locked:
		return
	if slot.tween != null and slot.tween.is_valid():
		slot.tween.kill()
	slot.button.scale = Vector2.ONE
	slot.style.border_color = UiStyle.GOLD_LIGHT
	slot.style.set_border_width_all(3)
	slot.tween = create_tween()
	slot.tween.tween_property(slot.style, "border_color", UiStyle.GOLD, 0.1)
	slot.tween.tween_property(slot.style, "border_color", _base_border(slot), 0.15)
	slot.tween.tween_callback(func() -> void: slot.style.set_border_width_all(2))


## Locked skills are dimmed and show a padlock.
func set_locked(id: String, locked: bool) -> void:
	var slot := _slots.get(id) as Slot
	if slot == null or slot.locked == locked:
		return
	slot.locked = locked
	slot.button.locked = locked
	slot.lock.visible = locked
	slot.icon.modulate = Color(0.55, 0.55, 0.6, 0.35) if locked else (Color.WHITE if slot.usable else Color(1, 1, 1, 0.45))
	if slot.tween == null or not slot.tween.is_running():
		slot.style.border_color = _base_border(slot)


func is_locked(id: String) -> bool:
	var slot := _slots.get(id) as Slot
	return slot != null and slot.locked


func _base_border(slot: Slot) -> Color:
	if slot.locked:
		return Color("8e8a7e")
	return COL_FRAME if slot.usable else COL_FIRE


func _fmt_num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
