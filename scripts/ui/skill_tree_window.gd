class_name SkillTreeWindow
extends CanvasLayer
## Character window (K): class tabs, the class skill tree (3 branches x 4 nodes) and faction allegiance.
## The game keeps running while it is open (RuneScape style); clicks on the panel do not reach the world.

const COL_PANEL := Color(0.12, 0.13, 0.16, 0.98)
const COL_STONE := Color("e6e1d3")
const COL_ROYAL := Color("3d5ba9")
const COL_SLATE := Color("5b6c9e")
const COL_GRASS := Color("4cb46a")
const COL_FIRE := Color("d9552e")
const COL_GOLD := Color("d9a441")

var progression: Progression
var _root: Control
var _shown_class: String = "vanguard"
var _tabs: HBoxContainer
var _header: Label
var _role: Label
var _branches: HBoxContainer
var _faction_option: OptionButton
var _faction_desc: Label


func setup(p: Progression) -> void:
	progression = p
	layer = 6
	_build()
	_root.visible = false
	progression.ranks_changed.connect(_refresh)
	progression.xp_changed.connect(func(_a: int, _b: int, _c: int) -> void: _refresh())


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_tree"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("pause"):
		_root.visible = false
		get_viewport().set_input_as_handled()


func _style(bg: Color, border: Color, radius: int = 6, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _label(text: String, size: int, color: Color = COL_STONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(COL_PANEL, COL_STONE, 10, 2))
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	_header = _label("", 22)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	var close := Button.new()
	close.text = "Close [K]"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_stylebox_override("normal", _style(COL_PANEL, COL_SLATE))
	close.add_theme_stylebox_override("hover", _style(COL_PANEL, COL_STONE))
	close.pressed.connect(toggle)
	top.add_child(close)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	box.add_child(_tabs)
	for c: Dictionary in ClassData.CLASSES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = c["name"] + ("" if c["playable"] else "  (soon)")
		b.set_meta("class_id", c["id"])
		b.pressed.connect(func() -> void:
			_shown_class = c["id"]
			_refresh())
		_tabs.add_child(b)
	_role = _label("", 15, COL_STONE.darkened(0.15))
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_role)

	_branches = HBoxContainer.new()
	_branches.add_theme_constant_override("separation", 14)
	box.add_child(_branches)

	box.add_child(HSeparator.new())
	var fac_row := HBoxContainer.new()
	fac_row.add_theme_constant_override("separation", 10)
	box.add_child(fac_row)
	fac_row.add_child(_label("Allegiance:", 16))
	_faction_option = OptionButton.new()
	_faction_option.focus_mode = Control.FOCUS_NONE
	for f: Dictionary in ClassData.FACTIONS:
		_faction_option.add_item(f["name"] if f["ascendant"] == "" else "%s  (%s)" % [f["name"], f["ascendant"]])
	_faction_option.item_selected.connect(func(i: int) -> void:
		progression.set_allegiance(ClassData.FACTIONS[i]["id"])
		_refresh())
	fac_row.add_child(_faction_option)
	_faction_desc = _label("", 14, COL_STONE.darkened(0.15))
	_faction_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_faction_desc)
	box.add_child(_label("Your allegiance never limits your class.", 13, COL_SLATE.lightened(0.3)))


func _refresh() -> void:
	if progression == null:
		return
	var c: Dictionary = ClassData.get_class_data(_shown_class)
	var own: bool = _shown_class == progression.class_id
	_header.text = "%s   ·   Level %d   ·   %d skill point%s" % [ClassData.get_class_data(progression.class_id)["name"], progression.level, progression.skill_points, "" if progression.skill_points == 1 else "s"]
	_role.text = c["role"] + ("" if c["playable"] else "  This class is not playable yet. Coming soon.")
	for b: Node in _tabs.get_children():
		var btn := b as Button
		var active: bool = btn.get_meta("class_id") == _shown_class
		var col: Color = ClassData.get_class_data(btn.get_meta("class_id"))["color"]
		btn.add_theme_stylebox_override("normal", _style(col.darkened(0.55) if active else COL_PANEL, col if active else COL_SLATE))
		btn.add_theme_stylebox_override("hover", _style(col.darkened(0.45), col))
	for i2: int in ClassData.FACTIONS.size():
		if ClassData.FACTIONS[i2]["id"] == progression.faction_id:
			_faction_option.selected = i2
	var fac: Dictionary = ClassData.get_faction(progression.faction_id)
	_faction_desc.text = fac["desc"]
	for child: Node in _branches.get_children():
		child.queue_free()
	for br: Dictionary in c["branches"]:
		var col_box := VBoxContainer.new()
		col_box.add_theme_constant_override("separation", 6)
		col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_branches.add_child(col_box)
		var title := _label(br["name"], 18, c["color"].lightened(0.25))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_box.add_child(title)
		var nodes: Array = br["nodes"]
		for i: int in nodes.size():
			if i > 0:
				var link := _label("|", 12, COL_SLATE)
				link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				col_box.add_child(link)
			col_box.add_child(_node_button(nodes[i], c, own))


func _node_button(n: Dictionary, c: Dictionary, own: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 52)
	var rank: int = progression.get_rank(n["id"]) if own else 0
	var max_rank: int = int(n.get("max", 1))
	var kind: String = "Active skill" if n["kind"] == "active" else "Passive"
	b.text = "%s\n%s  %d/%d" % [n["name"], kind, rank, max_rank]
	b.tooltip_text = "%s (%s)\n%s" % [n["name"], kind, n["desc"]]
	var can: bool = own and progression.can_rank_up(n["id"])
	var border: Color = COL_SLATE
	var bg: Color = COL_PANEL
	if rank >= max_rank:
		border = COL_GOLD
		bg = c["color"].darkened(0.6)
	elif rank > 0:
		border = c["color"]
		bg = c["color"].darkened(0.7)
	elif can:
		border = COL_GRASS
	b.add_theme_stylebox_override("normal", _style(bg, border))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), border.lightened(0.2)))
	b.add_theme_stylebox_override("disabled", _style(bg, border))
	b.add_theme_color_override("font_color", COL_STONE if (rank > 0 or can) else COL_STONE.darkened(0.45))
	b.add_theme_color_override("font_disabled_color", COL_STONE if rank > 0 else COL_STONE.darkened(0.45))
	b.add_theme_font_size_override("font_size", 14)
	b.disabled = not can
	b.pressed.connect(func() -> void: progression.rank_up(n["id"]))
	return b
