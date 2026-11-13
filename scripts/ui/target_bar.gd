class_name TargetBar
extends Control
## Enemy health bar: fire-coloured fill with a white trailing segment that shows the damage
## just dealt and catches up after a short delay.

const TRAIL_DELAY := 0.35

var value: float = 1.0
var max_value: float = 1.0
var trail: float = 1.0  ## Fraction (0..1) where the white segment ends.
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 12)


func fraction() -> float:
	return clampf(value / maxf(max_value, 0.001), 0.0, 1.0)


## snap: no trail (new target).
func set_health(v: float, m: float, snap: bool = false) -> void:
	value = v
	max_value = m
	var f: float = fraction()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if snap or f >= trail or not is_inside_tree():
		trail = f
	else:
		_tween = create_tween()
		_tween.tween_interval(TRAIL_DELAY)
		_tween.tween_method(_set_trail, trail, f, UiStyle.ANIM)
	queue_redraw()


func _set_trail(t: float) -> void:
	trail = t
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UiStyle.OUTLINE)
	var inner := r.grow(-1.5)
	draw_rect(inner, Color(UiStyle.SLATE_LIGHT, 0.95))
	var f: float = fraction()
	if trail > f:
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * f, 0), Vector2(inner.size.x * (trail - f), inner.size.y)), Color(1, 1, 1, 0.92))
	if f > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * f, inner.size.y)), UiStyle.FIRE)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * f, 2.0)), UiStyle.FIRE.lightened(0.3))
	draw_rect(r, UiStyle.STONE, false, 1.0)
