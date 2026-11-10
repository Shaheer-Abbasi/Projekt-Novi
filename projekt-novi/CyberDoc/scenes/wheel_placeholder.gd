extends Control
## Draws a colored wheel so you can test without art.
## Later, replace this node with a TextureRect holding your real wheel image.

@export var wedge_count: int = 6
## Text drawn in each wedge, clockwise from the top (set by the shop from its wedge table).
@export var labels: PackedStringArray = []
@export var label_font_size: int = 22

const COLORS := [
	Color("#ff2a6d"), Color("#05d9e8"), Color("#d1f7ff"),
	Color("#7700ff"), Color("#ffb400"), Color("#00ff9f"),
]


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var step := TAU / wedge_count
	for i in wedge_count:
		var pts := PackedVector2Array([c])
		var a0 := -PI / 2.0 + i * step
		for s in 21:
			var a := a0 + step * s / 20.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, COLORS[i % COLORS.size()])
	draw_arc(c, r, 0.0, TAU, 64, Color.WHITE, 4.0)
	_draw_labels(c, r, step)


## Each label sits in the outer part of its wedge (the middle is covered by the Cyberdoc),
## written across the wedge so it turns with the wheel.
func _draw_labels(c: Vector2, r: float, step: float) -> void:
	var font := get_theme_default_font()
	for i in mini(labels.size(), wedge_count):
		var mid := -PI / 2.0 + (i + 0.5) * step
		var text := labels[i]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size).x
		# bottom half: turn the text over so it does not read upside down at rest,
		# and slide it toward the wheel's side so the Cyberdoc standing in front does not hide it
		var turn := mid + PI / 2.0
		var dist := 0.8
		if sin(mid) > 0.0:
			dist = 0.74
			turn = mid - PI / 2.0
			mid -= signf(cos(mid)) * step * 0.18
		draw_set_transform(c + Vector2(cos(mid), sin(mid)) * r * dist, turn)
		var pos := Vector2(-w / 2.0, label_font_size * 0.35)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, 6, Color(0.05, 0.05, 0.1))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
