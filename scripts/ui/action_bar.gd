class_name ActionBar
extends HBoxContainer
## Action bar with 8 slots (keys 1-8). Holds skills and consumables (food, later potions).
## Drag a skill from the skill tree or food from the backpack onto a slot; drag between slots to
## swap; right-click a slot to clear it. Holds no gameplay logic: the game root reacts to signals.

signal slot_activated(index: int)
signal slot_assigned(index: int, entry: Dictionary)

const SLOTS: int = 8
const SLOT_SIZE := Vector2(58, 58)
const COL_PANEL := Color(0.12, 0.13, 0.16, 0.85)
const COL_FRAME := Color("e6e1d3")
const COL_FIRE := Color("d9552e")
const COL_EMPTY := Color(0.4, 0.42, 0.48)

var entries: Array[Dictionary] = []
var _buttons: Array[SlotButton] = []


class SlotButton:
	extends Button
	var index: int = 0
	var bar: ActionBar
	var style: StyleBoxFlat
	var icon_node: SkillBar.Icon
	var sweep: SkillBar.Sweep
	var time_label: Label
	var count_label: Label
	var usable: bool = true

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var e: Dictionary = bar.entries[index]
		if e.is_empty():
			return null
		var preview := ColorRect.new()
		preview.color = e.get("color", COL_FRAME)
		preview.size = Vector2(36, 36)
		set_drag_preview(preview)
		var data: Dictionary = e.duplicate()
		data["from_bar"] = index
		return data

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("type")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		bar.drop(index, data as Dictionary)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				bar.assign(index, {})
				accept_event()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	entries.resize(SLOTS)
	for i: int in SLOTS:
		entries[i] = {}
		_buttons.append(_make_button(i))
		_refresh_slot(i)


func _make_button(i: int) -> SlotButton:
	var b := SlotButton.new()
	b.index = i
	b.bar = self
	b.custom_minimum_size = SLOT_SIZE
	b.pivot_offset = SLOT_SIZE * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.style = StyleBoxFlat.new()
	b.style.bg_color = COL_PANEL
	b.style.set_border_width_all(2)
	b.style.set_corner_radius_all(6)
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, b.style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: slot_activated.emit(i))
	add_child(b)
	b.icon_node = SkillBar.Icon.new()
	b.add_child(b.icon_node)
	b.sweep = SkillBar.Sweep.new()
	b.sweep.visible = false
	b.add_child(b.sweep)
	b.time_label = _overlay_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	b.add_child(b.time_label)
	b.count_label = _overlay_label(13, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	b.count_label.offset_right = -4
	b.count_label.offset_bottom = -1
	b.add_child(b.count_label)
	var key := Label.new()
	key.text = str(i + 1)
	key.position = Vector2(5, 1)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", COL_FRAME)
	key.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	key.add_theme_constant_override("outline_size", 4)
	b.add_child(key)
	return b


func _overlay_label(size: int, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COL_FRAME)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


## Entry: {} (empty) or {"type": "skill"|"item", "id", "name", "desc", "color", "icon": int, "cooldown"}.
func assign(index: int, entry: Dictionary) -> void:
	var e: Dictionary = entry.duplicate()
	e.erase("from_bar")
	entries[index] = e
	_refresh_slot(index)
	slot_assigned.emit(index, e)


func drop(index: int, data: Dictionary) -> void:
	if data.has("from_bar"):
		var from: int = data["from_bar"]
		if from == index:
			return
		var other: Dictionary = entries[index]
		assign(index, data)
		assign(from, other)
		return
	# A skill or item may only be on the bar once: move it instead of duplicating.
	for i: int in SLOTS:
		if entries[i].get("type", "") == data.get("type", "") and entries[i].get("id", "") == data.get("id", ""):
			assign(i, {})
	assign(index, data)


func _refresh_slot(i: int) -> void:
	var b: SlotButton = _buttons[i]
	var e: Dictionary = entries[i]
	var empty: bool = e.is_empty()
	b.icon_node.visible = not empty
	b.count_label.text = ""
	b.sweep.visible = false
	b.time_label.visible = false
	b.style.border_color = COL_EMPTY if empty else COL_FRAME
	if empty:
		b.tooltip_text = "Empty slot. Drag a skill from the skill tree (K) or food from the backpack (I) here."
		return
	b.icon_node.kind = int(e.get("icon", 0))
	b.icon_node.tint = e.get("color", COL_FRAME)
	b.icon_node.queue_redraw()
	var extra: String = ("\nCooldown: %ss" % str(e.get("cooldown", 0))) if e.get("type", "") == "skill" else "\nClick or press %d to use." % (i + 1)
	b.tooltip_text = "%s\n%s%s\nRight-click to remove." % [e.get("name", ""), e.get("desc", ""), extra]


func set_cooldown(i: int, remaining: float, total: float) -> void:
	var b: SlotButton = _buttons[i]
	if remaining <= 0.0 or total <= 0.0:
		b.sweep.visible = false
		b.time_label.visible = false
		return
	b.sweep.fraction = remaining / total
	b.sweep.visible = true
	b.sweep.queue_redraw()
	b.time_label.text = "%.1f" % remaining if remaining < 10.0 else str(int(ceil(remaining)))
	b.time_label.visible = true


func set_usable(i: int, usable: bool) -> void:
	var b: SlotButton = _buttons[i]
	if b.usable == usable:
		return
	b.usable = usable
	b.icon_node.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.4)
	if not entries[i].is_empty():
		b.style.border_color = COL_FRAME if usable else COL_FIRE


func set_count(i: int, count: int) -> void:
	_buttons[i].count_label.text = str(count)


func flash(i: int) -> void:
	var b: SlotButton = _buttons[i]
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * 1.12, 0.07)
	tw.tween_property(b, "scale", Vector2.ONE, 0.11)
