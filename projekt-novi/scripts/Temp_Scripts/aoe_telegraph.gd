class_name AoETelegraph
extends Node2D
## A red warning circle that detonates after `duration`, damaging the
## player if they are still inside. Used by the boss "slam" attack.

var radius: float = 150.0
var duration: float = 0.9
var damage: float = 10.0
var _t: float = 0.0


static func spawn(parent: Node, pos: Vector2, r: float, dur: float, dmg: float) -> AoETelegraph:
	var t := AoETelegraph.new()
	t.radius = r
	t.duration = dur
	t.damage = dmg
	parent.add_child(t)
	t.global_position = pos
	return t


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		_detonate()
		return
	queue_redraw()


func _detonate() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.global_position.distance_to(global_position) <= radius:
		player.take_damage(damage)
	RingFX.spawn(get_parent(), global_position, radius, Color(1.0, 0.3, 0.2), 0.3)
	queue_free()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.1, 0.1, 0.10 + 0.15 * k))
	draw_circle(Vector2.ZERO, radius * k, Color(1.0, 0.2, 0.1, 0.25))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.25, 0.2, 0.9), 3.0)
