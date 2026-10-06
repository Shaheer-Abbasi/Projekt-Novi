class_name EnemyProjectile
extends Area2D
## Boss/enemy projectile. Drawn in code, no art needed.
## Physics layers: mask 2 = player body (layer 2).

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var damage: float = 8.0
var lifetime: float = 4.0


static func spawn(parent: Node, pos: Vector2, dir: Vector2, spd: float, dmg: float) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.collision_layer = 0
	p.collision_mask = 2
	p.monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	p.add_child(cs)
	p.direction = dir.normalized()
	p.speed = spd
	p.damage = dmg
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.1, 0.15, 0.30))
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.3, 0.3))
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.9))
