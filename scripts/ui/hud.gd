class_name Hud
extends CanvasLayer
## Minimal in-game HUD: health and stamina bars, FPS readout and a control hint.

const COL_HEALTH := Color("d9552e")
const COL_STAMINA := Color("4cb46a")
const COL_FRAME := Color("e6e1d3")
const COL_BACK := Color(0.12, 0.13, 0.16, 0.65)

var skill_bar: SkillBar
var health_orb: Orb
## Emitted when the player clicks the auto-retaliate button.
signal retaliate_clicked
signal skills_clicked
signal backpack_clicked
signal run_clicked
var _run_button: Button
var _run_style: StyleBoxFlat
var _backpack_button: Button
var _toasts: VBoxContainer
var _tracker: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _banner: Label
var _skills_button: Button
var _retaliate_button: Button
var _retaliate_style: StyleBoxFlat
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _fps_label: Label
var _hint: Label
var _hint_timer: float = 12.0
var _target_root: VBoxContainer
var _target_label: Label
var _target_bar: ProgressBar
var _target: Node
var _flash_rect: ColorRect
var _flash_tween: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.position = Vector2(32, 0)
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -150
	box.offset_left = 28
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	_health_bar = _make_bar(COL_HEALTH, Vector2(300, 16))
	_stamina_bar = _make_bar(COL_STAMINA, Vector2(220, 10))
	# Health orb with the stamina arc around it (see docs/UI.md). The bars stay as data holders.
	health_orb = Orb.new()
	health_orb.custom_minimum_size = Vector2(104, 104)
	health_orb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(health_orb)
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	box.add_child(xp_row)
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", COL_FRAME)
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_level_label.add_theme_constant_override("outline_size", 4)
	_level_label.add_theme_font_size_override("font_size", 13)
	xp_row.add_child(_level_label)
	_xp_bar = _make_bar(Color("d9a441"), Vector2(240, 7))
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(_xp_bar)

	_fps_label = Label.new()
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -120
	_fps_label.offset_top = 12
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_fps_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_fps_label)

	_hint = Label.new()
	_hint.text = "WASD move · Click monster to attack · 1-4 skills · Shift/Space run on/off · Middle mouse / arrows rotate · Scroll zoom · R auto retaliate · K skills · I backpack · L quests · Esc pause"
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.offset_left = -560
	_hint.offset_right = 560
	_hint.offset_top = 16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", COL_FRAME)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_font_size_override("font_size", 15)
	root.add_child(_hint)

	_target_root = VBoxContainer.new()
	_target_root.anchor_left = 0.5
	_target_root.anchor_right = 0.5
	_target_root.offset_left = -210
	_target_root.offset_right = 210
	_target_root.offset_top = 56
	_target_root.add_theme_constant_override("separation", 4)
	_target_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_root.visible = false
	root.add_child(_target_root)
	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_color_override("font_color", COL_FRAME)
	_target_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_target_label.add_theme_constant_override("outline_size", 4)
	_target_label.add_theme_font_size_override("font_size", 16)
	_target_root.add_child(_target_label)
	_target_bar = _make_bar(COL_HEALTH, Vector2(420, 12))
	_target_root.add_child(_target_bar)

	var bar_holder := CenterContainer.new()
	bar_holder.anchor_left = 0.0
	bar_holder.anchor_right = 1.0
	bar_holder.anchor_top = 1.0
	bar_holder.anchor_bottom = 1.0
	bar_holder.offset_top = -104
	bar_holder.offset_bottom = -24
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_holder)
	skill_bar = SkillBar.new()
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.add_child(skill_bar)

	# Auto-retaliate toggle (RuneScape style), bottom right.
	_retaliate_button = Button.new()
	_retaliate_button.focus_mode = Control.FOCUS_NONE
	_retaliate_button.anchor_left = 1.0
	_retaliate_button.anchor_right = 1.0
	_retaliate_button.anchor_top = 1.0
	_retaliate_button.anchor_bottom = 1.0
	_retaliate_button.offset_left = -208
	_retaliate_button.offset_right = -24
	_retaliate_button.offset_top = -84
	_retaliate_button.offset_bottom = -32
	_retaliate_button.tooltip_text = "Auto retaliate (R): fight back automatically when a monster attacks you."
	_retaliate_style = StyleBoxFlat.new()
	_retaliate_style.bg_color = COL_BACK
	_retaliate_style.set_border_width_all(2)
	_retaliate_style.set_corner_radius_all(6)
	for st: String in ["normal", "hover", "pressed"]:
		_retaliate_button.add_theme_stylebox_override(st, _retaliate_style)
	_retaliate_button.add_theme_color_override("font_color", COL_FRAME)
	_retaliate_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_retaliate_button.add_theme_font_size_override("font_size", 14)
	_retaliate_button.pressed.connect(func() -> void: retaliate_clicked.emit())
	root.add_child(_retaliate_button)
	set_retaliate(true)

	_skills_button = Button.new()
	_skills_button.focus_mode = Control.FOCUS_NONE
	_skills_button.anchor_left = 1.0
	_skills_button.anchor_right = 1.0
	_skills_button.anchor_top = 1.0
	_skills_button.anchor_bottom = 1.0
	_skills_button.offset_left = -208
	_skills_button.offset_right = -24
	_skills_button.offset_top = -140
	_skills_button.offset_bottom = -92
	var sk_style: StyleBoxFlat = _retaliate_style.duplicate()
	sk_style.border_color = Color("d9a441")
	for st2: String in ["normal", "hover", "pressed"]:
		_skills_button.add_theme_stylebox_override(st2, sk_style)
	_skills_button.add_theme_color_override("font_color", COL_FRAME)
	_skills_button.add_theme_font_size_override("font_size", 14)
	_skills_button.text = "Skill tree  [K]"
	_skills_button.pressed.connect(func() -> void: skills_clicked.emit())
	root.add_child(_skills_button)

	_backpack_button = Button.new()
	_backpack_button.focus_mode = Control.FOCUS_NONE
	_backpack_button.anchor_left = 1.0
	_backpack_button.anchor_right = 1.0
	_backpack_button.anchor_top = 1.0
	_backpack_button.anchor_bottom = 1.0
	_backpack_button.offset_left = -208
	_backpack_button.offset_right = -24
	_backpack_button.offset_top = -196
	_backpack_button.offset_bottom = -148
	var bp_style: StyleBoxFlat = _retaliate_style.duplicate()
	bp_style.border_color = Color("8a6446")
	for st3: String in ["normal", "hover", "pressed"]:
		_backpack_button.add_theme_stylebox_override(st3, bp_style)
	_backpack_button.add_theme_color_override("font_color", COL_FRAME)
	_backpack_button.add_theme_font_size_override("font_size", 14)
	_backpack_button.text = "Backpack  [I]"
	_backpack_button.pressed.connect(func() -> void: backpack_clicked.emit())
	root.add_child(_backpack_button)

	_toasts = VBoxContainer.new()
	_toasts.anchor_top = 1.0
	_toasts.anchor_bottom = 1.0
	_toasts.offset_left = 34
	_toasts.offset_top = -260
	_toasts.offset_bottom = -120
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	# Run toggle next to the health orb (RuneScape run orb).
	_run_button = Button.new()
	_run_button.focus_mode = Control.FOCUS_NONE
	_run_button.anchor_top = 1.0
	_run_button.anchor_bottom = 1.0
	_run_button.offset_left = 140
	_run_button.offset_right = 230
	_run_button.offset_top = -120
	_run_button.offset_bottom = -84
	_run_button.tooltip_text = "Run (Shift or Space): faster, but uses stamina. With no stamina you walk until it refills."
	_run_style = StyleBoxFlat.new()
	_run_style.bg_color = COL_BACK
	_run_style.set_border_width_all(2)
	_run_style.set_corner_radius_all(16)
	for st4: String in ["normal", "hover", "pressed"]:
		_run_button.add_theme_stylebox_override(st4, _run_style)
	_run_button.add_theme_color_override("font_color", COL_FRAME)
	_run_button.add_theme_font_size_override("font_size", 14)
	_run_button.pressed.connect(func() -> void: run_clicked.emit())
	root.add_child(_run_button)
	set_run(true)

	_tracker = Label.new()
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.offset_left = -470
	_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker.offset_right = -24
	_tracker.offset_top = 40
	_tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker.add_theme_font_size_override("font_size", 14)
	_tracker.add_theme_color_override("font_color", Color("f2d48a"))
	_tracker.add_theme_color_override("font_outline_color", Color(0.12, 0.13, 0.16, 0.9))
	_tracker.add_theme_constant_override("outline_size", 5)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tracker)

	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color("f2d48a"))
	_banner.add_theme_color_override("font_outline_color", Color(0.12, 0.13, 0.16, 0.9))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(COL_HEALTH, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash_rect)


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
	health_orb.value = value
	health_orb.max_value = max_value


func set_stamina(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	health_orb.arc_value = value / maxf(max_value, 1.0)


## Small message bottom-left (loot, eating). Fades after a few seconds.
func toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color("f2d48a"))
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.13, 0.16, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func set_tracker(text: String) -> void:
	_tracker.text = text


func set_xp(xp: int, xp_to_next: int, level: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = xp
	_level_label.text = "Lv %d" % level


func set_skill_points(points: int) -> void:
	_skills_button.text = "Skill tree  [K]" if points <= 0 else "Skill tree  [K]   +%d" % points


## Big centered message that fades (level up, area names).
func show_banner(text: String, sub: String = "") -> void:
	_banner.text = text if sub == "" else "%s\n%s" % [text, sub]
	var tw := create_tween()
	_banner.modulate.a = 0.0
	tw.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func set_run(on: bool) -> void:
	_run_button.text = "Run: %s" % ("ON" if on else "OFF")
	_run_style.border_color = Color("4cb46a") if on else Color("8e8a7e")


func set_retaliate(on: bool) -> void:
	_retaliate_button.text = "Auto retaliate: %s  [R]" % ("ON" if on else "OFF")
	_retaliate_style.border_color = Color("4cb46a") if on else Color("d9552e")


func set_hint_visible(v: bool) -> void:
	_hint.visible = v


func set_target(enemy: Node) -> void:
	if _target != null and is_instance_valid(_target) and _target.has_signal("health_changed"):
		if _target.health_changed.is_connected(_on_target_health_changed):
			_target.health_changed.disconnect(_on_target_health_changed)
	_target = null
	if enemy == null or not is_instance_valid(enemy):
		_target_root.visible = false
		return
	_target = enemy
	var lvl: Variant = enemy.get("level")
	_target_label.text = str(enemy.get("display_name")) + ("  (Level %d)" % int(lvl) if lvl != null else "")
	_on_target_health_changed(float(enemy.get("health")), float(enemy.get("max_health")))
	if enemy.has_signal("health_changed"):
		enemy.health_changed.connect(_on_target_health_changed)
	_target_root.visible = true


func _on_target_health_changed(value: float, max_value: float) -> void:
	_target_bar.max_value = max_value
	_target_bar.value = value


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = Color(COL_HEALTH, 0.25)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.3)


func _process(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
		_target_root.visible = false
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(_hint, "modulate:a", 0.0, 1.5)
