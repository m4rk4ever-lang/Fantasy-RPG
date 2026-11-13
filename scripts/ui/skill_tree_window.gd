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
	UiStyle.apply(panel, true, 18)
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
		var col_box := Branch.new()
		col_box.add_theme_constant_override("separation", 14)
		col_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_branches.add_child(col_box)
		var title := _label(br["name"], 18, c["color"].lightened(0.25))
		col_box.add_child(title)
		var nodes: Array = br["nodes"]
		for i: int in nodes.size():
			col_box.add_child(_node_button(nodes[i], c, own))


func _node_button(n: Dictionary, c: Dictionary, own: bool) -> TreeNode:
	var b := TreeNode.new()
	var rank: int = progression.get_rank(n["id"]) if own else 0
	b.skill_id = n.get("skill", "")
	b.learned = own and rank > 0
	var max_rank: int = int(n.get("max", 1))
	var kind: String = "Active skill" if n["kind"] == "active" else "Passive"
	b.title = n["name"]
	b.sub = kind
	b.active = n["kind"] == "active"
	b.rank = rank
	b.max_rank = max_rank
	b.class_col = c["color"]
	b.tooltip_text = "%s (%s)\n%s%s" % [n["name"], kind, n["desc"], "\nDrag onto the action bar." if n["kind"] == "active" else ""]
	var can: bool = own and progression.can_rank_up(n["id"])
	b.can = can
	b.disabled = not can
	b.pressed.connect(func() -> void: progression.rank_up(n["id"]))
	return b


## One branch of the tree: a title and its nodes, with connecting lines drawn between the circles.
class Branch:
	extends VBoxContainer

	func _ready() -> void:
		sort_children.connect(queue_redraw)

	func _draw() -> void:
		var prev: TreeNode = null
		for ch: Node in get_children():
			var n := ch as TreeNode
			if n == null:
				continue
			if prev != null:
				var a: Vector2 = prev.position + prev.circle_center()
				var b: Vector2 = n.position + n.circle_center()
				var lit: bool = prev.rank > 0 and n.rank > 0
				var col: Color = UiStyle.GOLD if lit else (prev.class_col.darkened(0.1) if prev.rank > 0 else Color("5b6c9e").darkened(0.25))
				draw_line(a, b, UiStyle.OUTLINE, 6.0, true)
				draw_line(a, b, col, 3.0, true)
			prev = n


## A node of the skill tree: a round icon with the rank, name and kind next to it.
## Gold ring when ranked, grass ring when a point can be spent, dim when out of reach.
class TreeNode:
	extends Button
	var skill_id: String = ""
	var learned: bool = false

	## Learned active skills can be dragged onto the action bar.
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if skill_id == "" or not learned:
			return null
		var e: Dictionary = PlayerCombat.skill_entry(skill_id)
		var preview := ColorRect.new()
		preview.color = e.get("color", Color.WHITE)
		preview.size = Vector2(36, 36)
		set_drag_preview(preview)
		return e

	const R := 22.0
	var title: String = ""
	var sub: String = ""
	var active: bool = false
	var rank: int = 0
	var max_rank: int = 1
	var can: bool = false
	var class_col: Color = Color("3d5ba9")
	var _hover: bool = false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(250, 52)
		for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func circle_center() -> Vector2:
		return Vector2(R + 6.0, size.y * 0.5)

	func _draw() -> void:
		var c: Vector2 = circle_center()
		var ranked: bool = rank > 0
		if _hover and can:
			var hl := StyleBoxFlat.new()
			hl.bg_color = Color(UiStyle.GRASS, 0.14)
			hl.set_corner_radius_all(int(size.y * 0.5))
			draw_style_box(hl, Rect2(Vector2.ZERO, size))
		var ring: Color = Color("5b6c9e").darkened(0.2)
		if ranked:
			ring = UiStyle.GOLD
		elif can:
			ring = UiStyle.GRASS
		var fill: Color = class_col.darkened(0.35) if ranked else UiStyle.SLATE_DARK
		draw_circle(c, R + 2.0, UiStyle.OUTLINE)
		draw_circle(c, R, ring)
		draw_circle(c, R - 3.0, fill)
		draw_circle(c + Vector2(0, -2), R - 9.0, fill.lightened(0.14))
		if rank >= max_rank:
			draw_arc(c, R - 4.5, 0.0, TAU, 40, UiStyle.GOLD_LIGHT, 1.0, true)
		# Active skills carry a small diamond on top of the ring, passives stay plain.
		if active:
			UiStyle.draw_gem(self, c + Vector2(0, -R), 3.5)
		var font: Font = get_theme_default_font()
		var txt: String = "%d/%d" % [rank, max_rank]
		var bright: bool = ranked or can
		var tcol: Color = UiStyle.STONE if bright else UiStyle.STONE.darkened(0.45)
		var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		draw_string(font, c + Vector2(-ts.x * 0.5, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.GOLD_LIGHT if ranked else tcol)
		var tx: float = c.x + R + 12.0
		draw_string(font, Vector2(tx, size.y * 0.5 - 3.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx, 15, tcol)
		var scol: Color = UiStyle.GRASS if (can and not ranked) else (class_col.lightened(0.35) if ranked else UiStyle.STONE.darkened(0.55))
		var stxt: String = sub + ("  ·  click to learn" if can and not ranked else ("  ·  click to improve" if can else ""))
		draw_string(font, Vector2(tx, size.y * 0.5 + 15.0), stxt, HORIZONTAL_ALIGNMENT_LEFT, size.x - tx, 12, scol)
