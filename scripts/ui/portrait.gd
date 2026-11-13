class_name Portrait
extends Control
## Round portrait drawn in code: a simple stylised silhouette in a stone ring.
## kind "hero": helmet silhouette. kind "brenna": hooded villager. Anything else: initial letter.

var kind: String = "":
	set(v):
		kind = v
		queue_redraw()
var accent: Color = UiStyle.GOLD


func _init(k: String = "", px: float = 64.0) -> void:
	kind = k
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)


## Portrait kind for a speaker name; unknown speakers fall back to their initial.
static func kind_for(speaker: String) -> String:
	var s: String = speaker.strip_edges()
	if s.to_lower().begins_with("brenna"):
		return "brenna"
	return s


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 1.0
	draw_circle(c, r, UiStyle.OUTLINE)
	draw_circle(c, r - 1.5, UiStyle.STONE)
	draw_circle(c, r - 3.0, UiStyle.SLATE_DARK)
	draw_circle(c + Vector2(0, -r * 0.15), r * 0.72, UiStyle.SLATE_LIGHT)
	var s: float = r / 32.0
	draw_set_transform(c, 0.0, Vector2(s, s))
	match kind:
		"hero":
			var steel := UiStyle.STONE.darkened(0.12)
			# Shoulders.
			draw_colored_polygon(PackedVector2Array([Vector2(-20, 24), Vector2(-13, 12), Vector2(13, 12), Vector2(20, 24)]), steel.darkened(0.45))
			# Helmet dome and cheek guards.
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(-10, -15), Vector2(-4, -21), Vector2(4, -21), Vector2(10, -15), Vector2(12, -4)]), steel)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(-4, -4), Vector2(-5, 13), Vector2(-10, 9)]), steel)
			draw_colored_polygon(PackedVector2Array([Vector2(12, -4), Vector2(10, 9), Vector2(5, 13), Vector2(4, -4)]), steel)
			# Visor slit and nose guard.
			draw_rect(Rect2(-9, -6, 18, 3.5), UiStyle.SLATE_DARK)
			draw_rect(Rect2(-1.5, -8, 3, 14), steel.lightened(0.3))
			# Crest in the accent colour, light edge on the dome.
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -20), Vector2(0, -27), Vector2(2, -20)]), accent)
			draw_polyline(PackedVector2Array([Vector2(-9, -14), Vector2(-4, -19), Vector2(3, -19)]), Color.WHITE, 1.5, true)
		"brenna":
			var cloth := Color("5b6c9e")
			# Shoulders and hood.
			draw_colored_polygon(PackedVector2Array([Vector2(-21, 24), Vector2(-14, 10), Vector2(14, 10), Vector2(21, 24)]), cloth.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, 8), Vector2(-13, -10), Vector2(-6, -20), Vector2(6, -20), Vector2(13, -10), Vector2(14, 8)]), cloth)
			# Face in the hood opening.
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -9), Vector2(0, -13), Vector2(7, -9), Vector2(6, 3), Vector2(0, 8), Vector2(-6, 3)]), Color("e8c9a8"))
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -9), Vector2(0, -13), Vector2(7, -9), Vector2(0, -7)]), Color("8a6446"))
			draw_circle(Vector2(-2.8, -2.5), 1.1, UiStyle.SLATE_DARK)
			draw_circle(Vector2(2.8, -2.5), 1.1, UiStyle.SLATE_DARK)
			# Clasp in gold.
			draw_colored_polygon(PackedVector2Array([Vector2(0, 8), Vector2(3, 11.5), Vector2(0, 15), Vector2(-3, 11.5)]), UiStyle.GOLD)
		_:
			var letter: String = kind.substr(0, 1).to_upper() if kind != "" else "?"
			var font: Font = get_theme_default_font()
			var fs: int = 34
			var ts: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			draw_string(font, Vector2(-ts.x * 0.5, fs * 0.34), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.GOLD_LIGHT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
