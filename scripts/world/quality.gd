class_name Quality
extends RefCounted
## Graphics quality (V.10): Low, Medium, High. Trades render resolution, shadows and grass for speed.
## The choice is stored in user://settings.cfg (IndexedDB in the browser).

const NAMES: Array[String] = ["Low", "Medium", "High"]
const PATH := "user://settings.cfg"


static func default_level() -> int:
	# Browsers on high-DPI laptops are fill-rate bound: start one step down.
	return 1 if OS.has_feature("web") else 2


static func load_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		return clampi(int(cfg.get_value("graphics", "quality", default_level())), 0, 2)
	return default_level()


static func save_level(level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("graphics", "quality", level)
	cfg.save(PATH)


static func apply(arena: TestArena, level: int) -> void:
	var vp: Viewport = arena.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][level]
	vp.msaa_3d = Viewport.MSAA_DISABLED if level == 0 else Viewport.MSAA_2X
	if arena.day_night:
		arena.day_night.shadows_allowed = level > 0
	if arena.sun:
		arena.sun.shadow_enabled = level > 0 and arena.sun.visible
		arena.sun.directional_shadow_max_distance = 45.0 if level == 1 else 60.0
		arena.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if level == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var grass: MultiMeshInstance3D = arena.find_child("Grass", true, false) as MultiMeshInstance3D
	if grass and grass.multimesh:
		var total: int = grass.multimesh.instance_count
		grass.multimesh.visible_instance_count = [0, int(total * 0.6), -1][level]
		grass.visible = level > 0
	if arena.environment:
		arena.environment.glow_enabled = level > 0



## Interface size (owner 14-11-2026): scales menus, orbs, bars and windows together.
static func load_ui_scale() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		return clampf(float(cfg.get_value("interface", "scale", 1.0)), 0.7, 1.6)
	return 1.0


static func apply_ui_scale(tree: SceneTree, value: float) -> void:
	tree.root.content_scale_factor = clampf(value, 0.7, 1.6)


static func save_ui_scale(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("interface", "scale", value)
	cfg.save(PATH)
