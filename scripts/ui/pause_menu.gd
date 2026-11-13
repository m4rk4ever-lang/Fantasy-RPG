class_name PauseMenu
extends CanvasLayer
## Pause menu: resume, controls list, restart and sensitivity sliders.

signal sensitivity_changed(mouse: float, stick: float)

const COL_PANEL := Color(0.12, 0.13, 0.16, 0.85)
const COL_STONE := Color("e6e1d3")
const COL_ACCENT := Color("3d5ba9")
const COL_SLATE := Color("5b6c9e")
const COL_DANGER := Color("d9552e")

const CONTROLS: Array[Array] = [
	["Move", "WASD or click the ground", "Left stick"],
	["Attack", "Left-click a monster", "X"],
	["Skills", "1 2 3 4", "Y, RB, LB, Back"],
	["Rotate camera", "Middle mouse drag or arrows", "Right stick"],
	["Zoom", "Scroll wheel or + -", "-"],
	["Sprint", "Shift", "L3"],
	["Dodge", "Space, right mouse, Alt or C", "B or A"],
	["Target nearest", "Q", "R3"],
	["Skill tree and allegiance", "K", "D-pad down"],
	["Auto retaliate on/off", "R or click the button", "D-pad up"],
	["Pause", "Esc or P", "Start"],
]

var mouse_sensitivity: float = 0.005
var stick_sensitivity: float = 3.2

var _root: Control
var _resume_button: Button
var _controls_button: Button
var _controls_panel: PanelContainer
var _mouse_slider: HSlider
var _stick_slider: HSlider
var _open: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	center.add_child(row)

	var panel := _make_panel()
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_STONE)
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_resume_button = _make_button("Resume")
	_resume_button.pressed.connect(close)
	box.add_child(_resume_button)

	_controls_button = _make_button("Controls")
	_controls_button.pressed.connect(_on_controls_pressed)
	box.add_child(_controls_button)

	var restart_button := _make_button("Restart")
	restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(restart_button)

	_mouse_slider = _add_slider(box, "Mouse sensitivity", 0.001, 0.012, 0.0002, mouse_sensitivity)
	_stick_slider = _add_slider(box, "Stick sensitivity", 1.0, 6.0, 0.1, stick_sensitivity)
	_mouse_slider.value_changed.connect(_on_slider_changed)
	_stick_slider.value_changed.connect(_on_slider_changed)

	_controls_panel = _make_panel()
	_controls_panel.visible = false
	row.add_child(_controls_panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	_controls_panel.add_child(grid)
	for header: String in ["Action", "Keyboard / mouse", "Gamepad"]:
		grid.add_child(_make_cell(header, COL_SLATE))
	for entry: Array in CONTROLS:
		for i: int in entry.size():
			grid.add_child(_make_cell(entry[i] as String, COL_STONE))


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_STONE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_cell(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 16)
	return l


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_color_override("font_color", COL_STONE)
	b.add_theme_color_override("font_hover_color", COL_STONE)
	b.add_theme_color_override("font_pressed_color", COL_STONE)
	b.add_theme_color_override("font_focus_color", COL_STONE)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _button_box(Color(COL_SLATE, 0.35), COL_SLATE))
	b.add_theme_stylebox_override("hover", _button_box(Color(COL_ACCENT, 0.7), COL_STONE))
	b.add_theme_stylebox_override("pressed", _button_box(COL_ACCENT, COL_STONE))
	b.add_theme_stylebox_override("focus", _button_box(Color(COL_ACCENT, 0.7), COL_STONE))
	return b


func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb


func _add_slider(parent: Control, label_text: String, min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var l := Label.new()
	l.text = label_text
	l.add_theme_color_override("font_color", COL_STONE)
	l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	s.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(COL_SLATE, 0.4)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = COL_ACCENT
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	parent.add_child(s)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _open:
		return
	_open = true
	_mouse_slider.set_value_no_signal(mouse_sensitivity)
	_stick_slider.set_value_no_signal(stick_sensitivity)
	_controls_panel.visible = false
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_open() -> bool:
	return _open


func _on_controls_pressed() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _on_restart_pressed() -> void:
	_open = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_slider_changed(_value: float) -> void:
	mouse_sensitivity = _mouse_slider.value
	stick_sensitivity = _stick_slider.value
	sensitivity_changed.emit(mouse_sensitivity, stick_sensitivity)
