class_name UiStyle
extends RefCounted
## Shared look for every window and HUD panel (docs/UI.md): dark slate panel, thin stone border,
## gold inner border for important windows and small crown-point ornaments drawn in code.

const SLATE_DARK := Color("1e2125")
const SLATE_LIGHT := Color("353a42")
const STONE := Color("e6e1d3")
const GOLD := Color("d9a441")
const GOLD_LIGHT := Color("f2d48a")
const FIRE := Color("d9552e")
const GRASS := Color("4cb46a")
const OUTLINE := Color(0.07, 0.08, 0.1, 0.9)
const ANIM := 0.2

static var _tooltip_theme: Theme


## Panel stylebox: slate, 95% opaque, thin stone border, rounded corners.
static func panel(margin: int = 14, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(SLATE_DARK, 0.95)
	sb.border_color = STONE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


## Flat button look that matches the panels.
static func button_box(border: Color, bg: Color = Color(SLATE_LIGHT, 0.9), radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


## Applies the shared panel look to a PanelContainer and adds the ornament layer.
## important: gold inner border and a crown on the top edge.
static func apply(p: PanelContainer, important: bool = false, margin: int = 14) -> void:
	p.add_theme_stylebox_override("panel", panel(margin))
	p.theme = tooltip_theme()
	var f := Frame.new()
	f.important = important
	p.add_child(f)
	p.move_child(f, 0)


## Dark outline so text stays readable over the 3D world.
static func outline(l: Control, size: int = 4) -> void:
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", size)


## Theme that gives tooltips the panel look. Set it on a root Control.
static func tooltip_theme() -> Theme:
	if _tooltip_theme == null:
		_tooltip_theme = Theme.new()
		var sb := panel(8, 6)
		sb.border_color = GOLD
		sb.shadow_size = 3
		_tooltip_theme.set_stylebox("panel", "TooltipPanel", sb)
		_tooltip_theme.set_color("font_color", "TooltipLabel", STONE)
		_tooltip_theme.set_font_size("font_size", "TooltipLabel", 14)
	return _tooltip_theme


## Small crown point: a diamond with a light core.
static func draw_gem(ci: CanvasItem, at: Vector2, r: float = 4.0) -> void:
	ci.draw_colored_polygon(_diamond(at, r + 1.5), OUTLINE)
	ci.draw_colored_polygon(_diamond(at, r), GOLD)
	ci.draw_colored_polygon(_diamond(at + Vector2(0, -r * 0.2), r * 0.45), GOLD_LIGHT)


## Three-point crown, base centred on at, pointing up.
static func draw_crown(ci: CanvasItem, at: Vector2, w: float = 13.0, h: float = 9.0) -> void:
	var pts := PackedVector2Array([
		at + Vector2(-w, 2), at + Vector2(-w, -h * 0.7), at + Vector2(-w * 0.5, -h * 0.15),
		at + Vector2(0, -h), at + Vector2(w * 0.5, -h * 0.15), at + Vector2(w, -h * 0.7), at + Vector2(w, 2),
		at + Vector2(-w, 2)])
	ci.draw_polyline(pts, OUTLINE, 3.5, true)
	# Convex pieces only: band plus three points.
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-w, 2), at + Vector2(-w, -h * 0.15), at + Vector2(w, -h * 0.15), at + Vector2(w, 2)]), GOLD)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-w, -h * 0.15), at + Vector2(-w, -h * 0.7), at + Vector2(-w * 0.5, -h * 0.15)]), GOLD)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-w * 0.5, -h * 0.15), at + Vector2(0, -h), at + Vector2(w * 0.5, -h * 0.15)]), GOLD)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(w * 0.5, -h * 0.15), at + Vector2(w, -h * 0.7), at + Vector2(w, -h * 0.15)]), GOLD)
	ci.draw_line(at + Vector2(-w + 1.5, 0.5), at + Vector2(w - 1.5, 0.5), GOLD_LIGHT, 1.0, true)


static func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


## Ornament layer of a panel. Sits as the first child of a PanelContainer and draws over the
## whole panel (behind the content): soft top gradient, gold inner border, corner points.
class Frame:
	extends Control
	var important: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var p := get_parent() as Control
		if p != null:
			p.resized.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var p := get_parent() as Control
		if p == null:
			return
		var o: Vector2 = -position
		var s: Vector2 = p.size
		# Slate gradient: lighter at the top, like a title bar that fades into the panel.
		var gh: float = minf(s.y - 3.0, 120.0)
		var top := Color(UiStyle.SLATE_LIGHT, 0.95)
		var bottom := Color(UiStyle.SLATE_LIGHT, 0.0)
		draw_polygon(
			PackedVector2Array([o + Vector2(3, 3), o + Vector2(s.x - 3, 3), o + Vector2(s.x - 3, gh), o + Vector2(3, gh)]),
			PackedColorArray([top, top, bottom, bottom]))
		if important:
			var inner := StyleBoxFlat.new()
			inner.draw_center = false
			inner.border_color = Color(UiStyle.GOLD, 0.85)
			inner.set_border_width_all(1)
			inner.set_corner_radius_all(5)
			inner.anti_aliasing = true
			draw_style_box(inner, Rect2(o + Vector2(4, 4), s - Vector2(8, 8)))
			UiStyle.draw_crown(self, o + Vector2(s.x * 0.5, 1.0))
		var r: float = 4.0 if important else 3.0
		var d: float = 4.5
		for c: Vector2 in [Vector2(d, d), Vector2(s.x - d, d), Vector2(d, s.y - d), Vector2(s.x - d, s.y - d)]:
			UiStyle.draw_gem(self, o + c, r)
