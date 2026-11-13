class_name XpBar
extends Control
## Thin gold XP line across the bottom of the screen with the level in a small shield.
## A shine sweeps over the line on level up.

const SHIELD_W := 30.0
const LINE_H := 5.0

var value: float = 0.0
var max_value: float = 100.0
var level: int = 1
var _shown: float = 0.0
var _shine: float = -1.0
var _tween: Tween
var _shine_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 38)


func set_xp(xp: float, to_next: float, new_level: int) -> void:
	var leveled: bool = new_level > level
	value = xp
	max_value = maxf(to_next, 1.0)
	level = new_level
	var target: float = fraction()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if leveled:
		_shown = 0.0
		play_shine()
	if is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_shown, _shown, target, UiStyle.ANIM)
	else:
		_set_shown(target)


func fraction() -> float:
	return clampf(value / max_value, 0.0, 1.0)


func is_shining() -> bool:
	return _shine >= 0.0


func play_shine() -> void:
	if not is_inside_tree():
		return
	if _shine_tween != null and _shine_tween.is_valid():
		_shine_tween.kill()
	_shine = 0.0
	_shine_tween = create_tween()
	_shine_tween.tween_method(_set_shine, 0.0, 1.0, 0.5)
	_shine_tween.tween_callback(func() -> void: _set_shine(-1.0))


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _set_shine(v: float) -> void:
	_shine = v
	queue_redraw()


func _draw() -> void:
	var y: float = size.y - 10.0
	var x0: float = 8.0 + SHIELD_W + 4.0
	var x1: float = size.x - 10.0
	var w: float = x1 - x0
	# Track.
	draw_rect(Rect2(x0 - 1, y - 1, w + 2, LINE_H + 2), UiStyle.OUTLINE)
	draw_rect(Rect2(x0, y, w, LINE_H), Color(UiStyle.SLATE_LIGHT, 0.95))
	# Fill with a lighter top edge.
	var fw: float = w * _shown
	if fw > 0.5:
		draw_rect(Rect2(x0, y, fw, LINE_H), UiStyle.GOLD)
		draw_rect(Rect2(x0, y, fw, 1.5), UiStyle.GOLD_LIGHT)
	# Tenth marks.
	for i: int in range(1, 10):
		var tx: float = x0 + w * float(i) / 10.0
		draw_line(Vector2(tx, y), Vector2(tx, y + LINE_H), Color(0, 0, 0, 0.45), 1.0)
	# Shine on level up: a bright band sweeping left to right.
	if _shine >= 0.0:
		var sw: float = 160.0
		var sx: float = x0 - sw + (w + sw) * _shine
		var a: float = clampf(sx, x0, x1)
		var m: float = clampf(sx + sw * 0.5, x0, x1)
		var b: float = clampf(sx + sw, x0, x1)
		var clear := Color(1, 1, 1, 0)
		var bright := Color(1, 1, 1, 0.95)
		if m > a:
			draw_polygon(PackedVector2Array([Vector2(a, y - 2), Vector2(m, y - 2), Vector2(m, y + LINE_H + 2), Vector2(a, y + LINE_H + 2)]),
				PackedColorArray([clear, bright, bright, clear]))
		if b > m:
			draw_polygon(PackedVector2Array([Vector2(m, y - 2), Vector2(b, y - 2), Vector2(b, y + LINE_H + 2), Vector2(m, y + LINE_H + 2)]),
				PackedColorArray([bright, clear, clear, bright]))
	# Shield with the level.
	var c := Vector2(8.0 + SHIELD_W * 0.5, size.y - 19.0)
	draw_colored_polygon(_shield(c, 15.0, 17.0), UiStyle.OUTLINE)
	draw_colored_polygon(_shield(c, 13.5, 15.5), UiStyle.GOLD if _shine < 0.0 else UiStyle.GOLD_LIGHT)
	draw_colored_polygon(_shield(c, 11.5, 13.5), UiStyle.SLATE_DARK)
	var font: Font = get_theme_default_font()
	var txt: String = str(level)
	var fs: int = 14 if level < 100 else 11
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.33 - 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.GOLD_LIGHT)


func _shield(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-hw, -hh), c + Vector2(hw, -hh), c + Vector2(hw, hh * 0.15),
		c + Vector2(hw * 0.55, hh * 0.7), c + Vector2(0, hh), c + Vector2(-hw * 0.55, hh * 0.7), c + Vector2(-hw, hh * 0.15)])
