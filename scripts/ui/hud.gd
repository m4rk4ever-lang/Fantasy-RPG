class_name Hud
extends CanvasLayer
## Minimal in-game HUD: health and stamina bars, FPS readout and a control hint.

const COL_HEALTH := Color("d9552e")
const COL_STAMINA := Color("4cb46a")
const COL_FRAME := Color("e6e1d3")
const COL_BACK := Color(0.12, 0.13, 0.16, 0.65)

var action_bar: ActionBar
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
var xp_bar: XpBar
var target_bar: TargetBar
var portrait: Portrait
var resource_orb: Orb
var _tracker_panel: PanelContainer
var _target_level: Label
var _banner: Label
var _skills_button: Button
var _retaliate_button: Button
var _retaliate_style: StyleBoxFlat
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _fps_label: Label
var _hint: Label
var _hint_timer: float = 12.0
var _target_root: PanelContainer
var _target_label: Label
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
	# XP: thin gold line across the full bottom width, level in a small shield (docs/UI.md).
	xp_bar = XpBar.new()
	xp_bar.anchor_left = 0.0
	xp_bar.anchor_right = 1.0
	xp_bar.anchor_top = 1.0
	xp_bar.anchor_bottom = 1.0
	xp_bar.offset_top = -38
	root.add_child(xp_bar)

	_fps_label = Label.new()
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -120
	_fps_label.offset_top = 12
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_fps_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_fps_label)

	_hint = Label.new()
	_hint.text = "WASD move · Click monster to attack · 1-8 action bar · Shift/Space run on/off · Middle mouse / arrows rotate · Scroll zoom · R auto retaliate · K skills · I backpack · L quests · Esc pause"
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.offset_left = -560
	_hint.offset_right = 560
	_hint.offset_top = 16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", COL_FRAME)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_font_size_override("font_size", 13)
	root.add_child(_hint)

	# Target frame: name + level, fire bar with a white trailing damage segment.
	_target_root = PanelContainer.new()
	_target_root.anchor_left = 0.5
	_target_root.anchor_right = 0.5
	_target_root.offset_left = -190
	_target_root.offset_right = 190
	_target_root.offset_top = 56
	_target_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_root.visible = false
	UiStyle.apply(_target_root, false, 10)
	root.add_child(_target_root)
	var target_box := VBoxContainer.new()
	target_box.add_theme_constant_override("separation", 5)
	target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_root.add_child(target_box)
	var target_row := HBoxContainer.new()
	target_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_box.add_child(target_row)
	_target_label = Label.new()
	_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_label.clip_text = true
	_target_label.add_theme_color_override("font_color", COL_FRAME)
	UiStyle.outline(_target_label)
	_target_label.add_theme_font_size_override("font_size", 16)
	target_row.add_child(_target_label)
	_target_level = Label.new()
	_target_level.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	UiStyle.outline(_target_level)
	_target_level.add_theme_font_size_override("font_size", 14)
	target_row.add_child(_target_level)
	target_bar = TargetBar.new()
	target_box.add_child(target_bar)

	var bar_holder := CenterContainer.new()
	bar_holder.anchor_left = 0.0
	bar_holder.anchor_right = 1.0
	bar_holder.anchor_top = 1.0
	bar_holder.anchor_bottom = 1.0
	bar_holder.offset_top = -104
	bar_holder.offset_bottom = -24
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_holder)
	action_bar = ActionBar.new()
	bar_holder.add_child(action_bar)

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
	_toasts.offset_top = -330
	_toasts.offset_bottom = -170
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	# Run toggle next to the health orb (RuneScape run orb).
	_run_button = Button.new()
	_run_button.focus_mode = Control.FOCUS_NONE
	_run_button.anchor_top = 1.0
	_run_button.anchor_bottom = 1.0
	_run_button.offset_left = 226
	_run_button.offset_right = 316
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

	# Class resource orb (V.12): Fury for the Vanguard.
	resource_orb = Orb.new()
	resource_orb.liquid = Color("d9a441")
	resource_orb.anchor_top = 1.0
	resource_orb.anchor_bottom = 1.0
	resource_orb.offset_left = 134
	resource_orb.offset_right = 214
	resource_orb.offset_top = -124
	resource_orb.offset_bottom = -44
	resource_orb.value = 0.0
	resource_orb.tooltip_text = "Fury: builds with every hit, fades out of combat. Surge Strike and Whirlwind spend it."
	root.add_child(resource_orb)

	# Hero portrait next to the health orb.
	portrait = Portrait.new("hero", 46.0)
	portrait.anchor_top = 1.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = 226
	portrait.offset_right = 272
	portrait.offset_top = -80
	portrait.offset_bottom = -34
	root.add_child(portrait)

	# Quest tracker, top right, in the shared panel style.
	_tracker_panel = PanelContainer.new()
	_tracker_panel.anchor_left = 1.0
	_tracker_panel.anchor_right = 1.0
	_tracker_panel.offset_left = -344
	_tracker_panel.offset_right = -24
	_tracker_panel.offset_top = 40
	_tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker_panel.visible = false
	UiStyle.apply(_tracker_panel, false, 10)
	root.add_child(_tracker_panel)
	_tracker = Label.new()
	_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker.custom_minimum_size = Vector2(300, 0)
	_tracker.add_theme_font_size_override("font_size", 14)
	_tracker.add_theme_color_override("font_color", Color("f2d48a"))
	UiStyle.outline(_tracker)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker_panel.add_child(_tracker)

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


func set_resource(value: float, max_value: float) -> void:
	if resource_orb:
		resource_orb.value = value
		resource_orb.max_value = max_value


func set_stamina(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	health_orb.arc_value = value / maxf(max_value, 1.0)


## Small message bottom-left (loot, eating). Fades after a few seconds.
## item_id: optional item whose icon is shown in front of the text (loot).
func toast(text: String, item_id: String = "") -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	if item_id != "":
		var icon := ItemIcon.new(item_id, 22.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color("f2d48a"))
	UiStyle.outline(l, 5)
	row.add_child(l)
	_toasts.add_child(row)
	while _toasts.get_child_count() > 6:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := row.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.8)
	tw.tween_callback(row.queue_free)


func set_tracker(text: String) -> void:
	_tracker.text = text
	_tracker_panel.visible = text.strip_edges() != ""
	_tracker_panel.reset_size()


func set_xp(xp: int, xp_to_next: int, level: int) -> void:
	xp_bar.set_xp(xp, xp_to_next, level)


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
	_target_label.text = str(enemy.get("display_name"))
	_target_level.text = "Lv %d" % int(lvl) if lvl != null else ""
	target_bar.set_health(float(enemy.get("health")), float(enemy.get("max_health")), true)
	if enemy.has_signal("health_changed"):
		enemy.health_changed.connect(_on_target_health_changed)
	_target_root.visible = true


func _on_target_health_changed(value: float, max_value: float) -> void:
	target_bar.set_health(value, max_value)


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
