class_name Hud
extends CanvasLayer
## Minimal in-game HUD: health and stamina bars, FPS readout and a control hint.

const COL_HEALTH := Color("d9552e")
const COL_STAMINA := Color("4cb46a")
const COL_FRAME := Color("e6e1d3")
const COL_BACK := Color(0.12, 0.13, 0.16, 0.65)

var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _fps_label: Label
var _hint: Label
var _hint_timer: float = 12.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.position = Vector2(32, 0)
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -86
	box.offset_left = 32
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	_health_bar = _make_bar(COL_HEALTH, Vector2(300, 16))
	_stamina_bar = _make_bar(COL_STAMINA, Vector2(220, 10))
	box.add_child(_health_bar)
	box.add_child(_stamina_bar)

	_fps_label = Label.new()
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -120
	_fps_label.offset_top = 12
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_fps_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_fps_label)

	_hint = Label.new()
	_hint.text = "WASD move · Shift sprint · Space jump · Right mouse / Alt dodge · Click to capture mouse"
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.offset_left = -360
	_hint.offset_right = 360
	_hint.offset_top = 16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", COL_FRAME)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_font_size_override("font_size", 15)
	root.add_child(_hint)


func _make_bar(fill: Color, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BACK
	bg.border_color = COL_FRAME
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	fg.border_color = Color(0, 0, 0, 0)
	fg.set_border_width_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func set_health(value: float, max_value: float) -> void:
	_health_bar.max_value = max_value
	_health_bar.value = value


func set_stamina(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value


func set_hint_visible(v: bool) -> void:
	_hint.visible = v


func _process(delta: float) -> void:
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(_hint, "modulate:a", 0.0, 1.5)
