class_name RingFX
extends Node2D
## Expanding ring flash. Used for shockwaves, impacts, deaths, boss attacks.
## No art needed. Just call RingFX.spawn(...).

var radius: float = 100.0
var color: Color = Color.WHITE
var duration: float = 0.35
var _t: float = 0.0


static func spawn(parent: Node, pos: Vector2, r: float, c: Color, dur: float = 0.35) -> RingFX:
	var fx := RingFX.new()
	fx.radius = r
	fx.color = c
	fx.duration = dur
	parent.add_child(fx)
	fx.global_position = pos
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var r := radius * (1.0 - pow(1.0 - k, 3.0))
	var a := 1.0 - k
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.18 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color.r, color.g, color.b, a), 4.0)
