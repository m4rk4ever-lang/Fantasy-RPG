class_name Orb
extends Control
## Round resource orb (health, later class resource): liquid with a moving surface,
## a stone rim with a small crown point, the value in the middle and an optional outer arc (stamina).

var value: float = 100.0
var max_value: float = 100.0
var liquid: Color = Color("d9552e")
var arc_value: float = -1.0  ## 0..1, < 0 hides the arc.
var arc_color: Color = Color("4cb46a")
var _shown: float = 1.0
var _time: float = 0.0
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(92, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	var target: float = clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	_shown = lerpf(_shown, target, 1.0 - exp(-8.0 * delta))
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 8.0
	# Back.
	draw_circle(c, r, Color(0.08, 0.09, 0.11, 0.92))
	# Liquid: circle clipped below a wavy surface.
	var level_y: float = c.y + r - 2.0 * r * _shown
	var pts := PackedVector2Array()
	var n: int = 40
	for i: int in n + 1:
		var a: float = PI * float(i) / n  # Bottom half sweep from right to left.
		var x: float = c.x + cos(a) * r
		var y_circle: float = c.y + sin(a) * r
		pts.append(Vector2(x, y_circle))
	# Up the left side to the surface, then the wave back to the right.
	var surface := PackedVector2Array()
	for i2: int in n + 1:
		var x2: float = c.x - r + 2.0 * r * float(i2) / n
		var dy: float = sqrt(maxf(r * r - pow(x2 - c.x, 2.0), 0.0))
		var wave: float = sin(_time * 2.4 + x2 * 0.12) * 2.2 + sin(_time * 1.3 - x2 * 0.07) * 1.4
		var y2: float = clampf(level_y + wave, c.y - dy, c.y + dy)
		surface.append(Vector2(x2, y2))
	var poly := PackedVector2Array()
	for i3: int in n + 1:
		var x3: float = c.x - r + 2.0 * r * float(i3) / n
		var dy3: float = sqrt(maxf(r * r - pow(x3 - c.x, 2.0), 0.0))
		poly.append(Vector2(x3, c.y + dy3))
	for i4: int in range(n, -1, -1):
		poly.append(surface[i4])
	if _shown > 0.005:
		draw_colored_polygon(poly, liquid)
		draw_polyline(surface, liquid.lightened(0.35), 1.5, true)
	# Glass highlight.
	draw_arc(c + Vector2(-r * 0.2, -r * 0.25), r * 0.55, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.18), 3.0, true)
	# Stone rim with gold inner line.
	draw_arc(c, r + 2.0, 0.0, TAU, 64, Color("8e8a7e"), 5.0, true)
	draw_arc(c, r - 0.5, 0.0, TAU, 64, Color("d9a441"), 1.5, true)
	# Crown point on top.
	var top: Vector2 = c + Vector2(0, -r - 4.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-7, 3), top + Vector2(0, -9), top + Vector2(7, 3)]), Color("d9a441"))
	# Outer arc (stamina), clockwise from bottom-left.
	if arc_value >= 0.0:
		draw_arc(c, r + 7.5, PI * 0.75, PI * 0.75 + PI * 1.5, 48, Color(0.08, 0.09, 0.11, 0.8), 4.0, true)
		if arc_value > 0.0:
			draw_arc(c, r + 7.5, PI * 0.75, PI * 0.75 + PI * 1.5 * clampf(arc_value, 0.0, 1.0), 48, arc_color, 3.0, true)
	# Value.
	var txt: String = str(int(round(value)))
	var fs: int = 18
	var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, c + Vector2(-w * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.08, 0.09, 0.11, 0.9))
	draw_string(_font, c + Vector2(-w * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e6e1d3"))
