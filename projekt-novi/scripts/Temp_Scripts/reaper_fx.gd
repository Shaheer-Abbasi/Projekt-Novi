class_name ReaperFX
extends Node2D
## Purple effects for Reaper's abilities, drawn in code (no art needed).
## Visual only: the abilities deal their own damage.

enum Shape { ARC, LINE, MARK }

const PURPLE := Color(0.72, 0.3, 1.0)

var shape: Shape = Shape.ARC
var radius: float = 200.0
var spread: float = PI
var dir: Vector2 = Vector2.RIGHT
var to: Vector2 = Vector2.ZERO
var color: Color = PURPLE
var duration: float = 0.3
var _t: float = 0.0


## A scythe sweep: a thick arc of `spread` radians facing `dir`.
static func arc(parent: Node, pos: Vector2, facing: Vector2, r: float, spread_rad: float, dur: float = 0.25) -> ReaperFX:
	var fx := _make(parent, pos, Shape.ARC, dur)
	fx.dir = facing.normalized()
	fx.radius = r
	fx.spread = spread_rad
	return fx


## A shadow trail from `from` to `end` (global positions).
static func trail(parent: Node, from: Vector2, end: Vector2, dur: float = 0.35) -> ReaperFX:
	var fx := _make(parent, from, Shape.LINE, dur)
	fx.to = end - from
	return fx


## A mark that hovers over a target and follows it.
static func mark(target: Node2D, dur: float) -> ReaperFX:
	var fx := _make(target, target.global_position, Shape.MARK, dur)
	fx.position = Vector2(0, -70)
	fx.radius = 18.0
	return fx


static func _make(parent: Node, pos: Vector2, s: Shape, dur: float) -> ReaperFX:
	var fx := ReaperFX.new()
	fx.shape = s
	fx.duration = dur
	fx.z_index = 5
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
	var c := Color(color, 1.0 - k)
	match shape:
		Shape.ARC:
			var a := dir.angle()
			var r := radius * (0.85 + 0.15 * k)
			draw_arc(Vector2.ZERO, r, a - spread / 2.0, a + spread / 2.0, 32, c, 22.0 * (1.0 - k) + 4.0)
			draw_arc(Vector2.ZERO, r * 0.8, a - spread / 2.0, a + spread / 2.0, 32, Color(1, 1, 1, 0.6 * (1.0 - k)), 3.0)
		Shape.LINE:
			draw_line(Vector2.ZERO, to, c, 26.0 * (1.0 - k) + 2.0)
			draw_line(Vector2.ZERO, to, Color(1, 1, 1, 0.5 * (1.0 - k)), 4.0)
		Shape.MARK:
			var pulse := 1.0 + 0.15 * sin(_t * 10.0)
			draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 24, Color(color, 0.95), 3.0)
			draw_line(Vector2(0, -radius * 0.6), Vector2(0, radius * 0.6), Color(color, 0.95), 3.0)
			draw_line(Vector2(-radius * 0.6, 0), Vector2(radius * 0.6, 0), Color(color, 0.95), 3.0)
