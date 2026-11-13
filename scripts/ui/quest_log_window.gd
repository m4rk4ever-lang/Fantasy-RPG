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
	UiStyle.apply(panel, true, 16)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 24
	panel.offset_right = 444
	panel.offset_top = -310
	panel.offset_bottom = 190
	_root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
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
	_list.add_child(_label("Quest log  [L]", 20, UiStyle.GOLD_LIGHT))
	# Main story: chapter title, then each story quest with its steps.
	var chapter: String = ""
	for id: String in QuestLog.QUESTS.keys():
		var q: Dictionary = QuestLog.QUESTS[id]
		if not q.get("main", false) or quests.state(id) == "none":
			continue
		if q["chapter"] != chapter:
			chapter = q["chapter"]
			_list.add_child(_label("Story · " + chapter, 15, Color("6ec3f0")))
		_add_quest(id)
	_list.add_child(HSeparator.new())
	_list.add_child(_label("Side quests", 15, Color("6ec3f0")))
	var any_side: bool = false
	for id2: String in QuestLog.QUESTS.keys():
		if QuestLog.QUESTS[id2].get("main", false) or quests.state(id2) == "none":
			continue
		any_side = true
		_add_quest(id2)
	if not any_side:
		_list.add_child(_label("None yet. Someone in Saltwick looks like they need help.", 13, Color("e6e1d3").darkened(0.25)))


func _add_quest(id: String) -> void:
	var q: Dictionary = QuestLog.QUESTS[id]
	var st: String = quests.state(id)
	_list.add_child(_label(q["name"] + ("  (complete)" if st == "done" else ""), 17, Color("4cb46a") if st == "done" else Color("f2d48a")))
	_list.add_child(_label(q["summary"], 13, Color("e6e1d3").darkened(0.12)))
	var current_marked: bool = false
	for step: Dictionary in quests.steps(id):
		var text: String = step["text"]
		if step["done"]:
			_list.add_child(_label("  ✓  " + text, 14, Color("e6e1d3").darkened(0.4)))
		elif not current_marked:
			current_marked = true
			_list.add_child(_label("  ▸  " + text, 14, Color("f2d48a")))
		else:
			_list.add_child(_label("  ○  " + text, 14, Color("e6e1d3").darkened(0.55)))
