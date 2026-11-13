class_name DialogueWindow
extends CanvasLayer
## Conversation panel at the bottom of the screen: speaker, text and up to four answers.
## Answers are clickable or picked with keys 1-4 (the skill keys are blocked while talking).

const COL_PANEL := Color(0.12, 0.13, 0.16, 0.96)
const COL_STONE := Color("e6e1d3")
const COL_GOLD := Color("d9a441")
const COL_SLATE := Color("5b6c9e")

var portrait: Portrait
var _root: Control
var _speaker: Label
var _text: Label
var _answers: VBoxContainer
var _callbacks: Array[Callable] = []


func _ready() -> void:
	layer = 7
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.apply(panel, true, 16)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -344
	panel.offset_bottom = -126
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	portrait = Portrait.new("", 84.0)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 18)
	_speaker.add_theme_color_override("font_color", COL_GOLD)
	box.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(620, 0)
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", COL_STONE)
	box.add_child(_text)
	_answers = VBoxContainer.new()
	_answers.add_theme_constant_override("separation", 4)
	box.add_child(_answers)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


## options: Array of [label: String, callback: Callable]
func show_line(speaker: String, text: String, options: Array) -> void:
	_speaker.text = speaker
	portrait.kind = Portrait.kind_for(speaker)
	_text.text = text
	_callbacks.clear()
	for c: Node in _answers.get_children():
		c.queue_free()
	for i: int in options.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%d. %s" % [i + 1, options[i][0]]
		b.flat = true
		b.add_theme_color_override("font_color", COL_STONE)
		b.add_theme_color_override("font_hover_color", COL_GOLD)
		b.add_theme_font_size_override("font_size", 15)
		var cb: Callable = options[i][1]
		_callbacks.append(cb)
		b.pressed.connect(func() -> void: _pick(cb))
		_answers.add_child(b)
	_root.visible = true


func close() -> void:
	_root.visible = false


func _pick(cb: Callable) -> void:
	close()
	cb.call()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k: int = (event as InputEventKey).physical_keycode - KEY_1
		if k >= 0 and k < _callbacks.size():
			get_viewport().set_input_as_handled()
			_pick(_callbacks[k])
