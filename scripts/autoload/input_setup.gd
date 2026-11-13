extends Node
## Registers all input actions in code so bindings live in one readable place.
## Keyboard + mouse and gamepad are bound side by side.

const STICK_DEADZONE: float = 0.2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_action("move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("look_left", [_key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_action("look_right", [_key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_action("look_up", [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action("look_down", [_key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add_action("sprint", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])
	_add_action("dodge", [_key(KEY_SPACE), _key(KEY_ALT), _key(KEY_C), _mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_B), _button(JOY_BUTTON_A)])
	_add_action("attack_light", [_key(KEY_J), _button(JOY_BUTTON_X)])
	_add_action("click", [_mouse(MOUSE_BUTTON_LEFT)])
	_add_action("skill_1", [_key(KEY_1), _key(KEY_E), _button(JOY_BUTTON_Y)])
	_add_action("skill_2", [_key(KEY_2), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_add_action("skill_3", [_key(KEY_3), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action("skill_4", [_key(KEY_4), _button(JOY_BUTTON_BACK)])
	_add_action("zoom_in", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_EQUAL)])
	_add_action("zoom_out", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_MINUS)])
	_add_action("lock_on", [_key(KEY_Q), _key(KEY_TAB), _button(JOY_BUTTON_RIGHT_STICK)])
	_add_action("toggle_retaliate", [_key(KEY_R), _button(JOY_BUTTON_DPAD_UP)])
	_add_action("skill_tree", [_key(KEY_K), _button(JOY_BUTTON_DPAD_DOWN)])
	_add_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])


func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


func _key(code: Key) -> InputEvent:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


func _mouse(button: MouseButton) -> InputEvent:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


func _button(button: JoyButton) -> InputEvent:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEvent:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
