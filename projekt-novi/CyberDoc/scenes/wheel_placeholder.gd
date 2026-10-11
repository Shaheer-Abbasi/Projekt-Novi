extends Control
## Draws a colored wheel so you can test without art.
## Later, replace this node with a TextureRect holding your real wheel image.

@export var wedge_count: int = 6

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
