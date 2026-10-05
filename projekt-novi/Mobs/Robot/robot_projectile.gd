extends Area2D

@export var speed: float = 400.0
@export var damage: int = 1
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	rotation = direction.angle()
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	else:
		var hits: int = int(body.get_meta("robot_hits", 0)) + 1
		body.set_meta("robot_hits", hits)
		if hits >= 3:
			body.queue_free()

	queue_free()

func _is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.0, 0.08, 0.20))
	draw_line(Vector2(-16.0, 0.0), Vector2(13.0, 0.0), Color(1.0, 0.04, 0.08, 0.40), 7.0)
	draw_line(Vector2(-15.0, 0.0), Vector2(14.0, 0.0), Color(1.0, 0.15, 0.12, 1.0), 3.0)
	draw_line(Vector2(-12.0, 0.0), Vector2(15.0, 0.0), Color(1.0, 0.85, 0.8, 1.0), 1.0)
