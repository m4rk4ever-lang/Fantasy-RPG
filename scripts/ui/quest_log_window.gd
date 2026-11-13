class_name QuestLogWindow
extends CanvasLayer
## Quest log (L): active and completed quests with their objective.

var quests: QuestLog
var _root: Control
var _list: VBoxContainer


func setup(q: QuestLog) -> void:
	quests = q
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 0.96)
	sb.border_color = Color("e6e1d3")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 24
	panel.offset_right = 444
	panel.offset_top = -200
	panel.offset_bottom = 120
	_root.add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	panel.add_child(_list)
	_root.visible = false
	quests.changed.connect(_refresh)
	quests.inventory.changed.connect(_refresh)


func toggle() -> void:
	_root.visible = not _root.visible
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		toggle()
		get_viewport().set_input_as_handled()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _refresh() -> void:
	if not _root.visible:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	_list.add_child(_label("Quest log  [L]", 20, Color("e6e1d3")))
	var any: bool = false
	for id: String in QuestLog.QUESTS.keys():
		var st: String = quests.state(id)
		if st == "none":
			continue
		any = true
		var q: Dictionary = QuestLog.QUESTS[id]
		var head: String = q["name"] + ("  (complete)" if st == "done" else "")
		_list.add_child(_label(head, 17, Color("4cb46a") if st == "done" else Color("f2d48a")))
		_list.add_child(_label(q["summary"], 14, Color("e6e1d3").darkened(0.1)))
		if st == "active" and q.has("item"):
			_list.add_child(_label("%s: %d/%d" % [Inventory.item_data(q["item"])["name"], quests.progress(id), int(q["needed"])], 14, Color("6ec3f0")))
		_list.add_child(_label("Given by " + q["giver"], 12, Color("5b6c9e").lightened(0.3)))
	if not any:
		_list.add_child(_label("No quests yet. Someone in Saltwick looks like they need help.", 14, Color("e6e1d3").darkened(0.2)))
