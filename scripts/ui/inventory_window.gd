class_name InventoryWindow
extends CanvasLayer
## Backpack panel (I), RuneScape style: 4 x 7 slots on the right side of the screen.
## Click a consumable to use it. The game keeps running while it is open.

signal item_used(id: String)

const COL_PANEL := Color(0.12, 0.13, 0.16, 0.95)
const COL_STONE := Color("e6e1d3")
const COL_SLATE := Color("5b6c9e")
const COL_GOLD := Color("d9a441")

var inventory: Inventory
var _root: Control
var _grid: GridContainer
var _coins: Label


func setup(inv: Inventory) -> void:
	inventory = inv
	layer = 5
	_build()
	_root.visible = false
	inventory.changed.connect(_refresh)


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_refresh()


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()


func _style(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.apply(panel, false, 12)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -272
	panel.offset_right = -24
	panel.offset_top = -562
	panel.offset_bottom = -206
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := Label.new()
	title.text = "Backpack"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_STONE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var coin_icon := ItemIcon.new("coins", 20.0)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coin_icon)
	_coins = Label.new()
	_coins.add_theme_color_override("font_color", COL_GOLD)
	_coins.add_theme_font_size_override("font_size", 16)
	top.add_child(_coins)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(_grid)
	for i: int in Inventory.SLOTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(50, 38)
		# Slots with a light inset: darker than the panel, thin dark border.
		b.add_theme_stylebox_override("normal", _style(Color(0.08, 0.09, 0.1, 0.85), Color(0.26, 0.28, 0.32), 4))
		b.add_theme_stylebox_override("hover", _style(Color(0.14, 0.15, 0.18, 0.95), COL_STONE, 4))
		b.add_theme_stylebox_override("pressed", _style(Color(0.14, 0.15, 0.18, 0.95), COL_GOLD, 4))
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", COL_STONE)
		var idx: int = i
		b.pressed.connect(func() -> void: _on_slot(idx))
		_grid.add_child(b)


func _on_slot(i: int) -> void:
	var s: Dictionary = inventory.slots[i]
	if s.is_empty():
		return
	if Inventory.item_data(s["id"]).has("heal"):
		item_used.emit(s["id"])


func _refresh() -> void:
	_coins.text = "%d coins" % inventory.coins
	for i: int in Inventory.SLOTS:
		var b := _grid.get_child(i) as Button
		var s: Dictionary = inventory.slots[i]
		for c: Node in b.get_children():
			c.queue_free()
		if s.is_empty():
			b.text = ""
			b.tooltip_text = ""
			continue
		var data: Dictionary = Inventory.item_data(s["id"])
		var icon := ItemIcon.new(s["id"], 30.0)
		icon.position = Vector2(10, 4)
		b.add_child(icon)
		b.text = ""
		if int(s["count"]) > 1:
			var n := Label.new()
			n.text = str(int(s["count"]))
			n.set_anchors_preset(Control.PRESET_FULL_RECT)
			n.offset_right = -4
			n.offset_bottom = -1
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.add_theme_font_size_override("font_size", 12)
			n.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
			UiStyle.outline(n, 4)
			b.add_child(n)
		b.tooltip_text = "%s\n%s%s" % [data["name"], data["desc"], "\nClick to eat." if data.has("heal") else ""]
