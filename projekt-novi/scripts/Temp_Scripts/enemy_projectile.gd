class_name EnemyProjectile
extends Area2D
## Enemy projectile, drawn in code (no art needed).
##   laser = false -> glowing red orb (the boss's nova)
##   laser = true  -> red laser streak (the Shooter enemy). Same look as the Robot's laser.
## Physics layers: mask 2 = player body (layer 2).

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var damage: float = 8.0
var lifetime: float = 4.0
var laser: bool = false


static func spawn(parent: Node, pos: Vector2, dir: Vector2, spd: float, dmg: float, as_laser: bool = false) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.collision_layer = 0
	p.collision_mask = 2
	p.monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 8.0 if as_laser else 9.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	p.add_child(cs)
	p.direction = dir.normalized()
	p.speed = spd
	p.damage = dmg
	p.laser = as_laser
	if as_laser:
		p.lifetime = 2.0   # like the Robot's laser: flies about 2 seconds, then fades out of existence
	parent.add_child(p)
	p.global_position = pos
	if as_laser:
		p.rotation = p.direction.angle()   # the streak points the way it flies
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
	if laser:
		# Same drawing as your Robot's laser (robot_projectile.gd)
		draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.0, 0.08, 0.20))
		draw_line(Vector2(-16.0, 0.0), Vector2(13.0, 0.0), Color(1.0, 0.04, 0.08, 0.40), 7.0)
		draw_line(Vector2(-15.0, 0.0), Vector2(14.0, 0.0), Color(1.0, 0.15, 0.12, 1.0), 3.0)
		draw_line(Vector2(-12.0, 0.0), Vector2(15.0, 0.0), Color(1.0, 0.85, 0.8, 1.0), 1.0)
	else:
		draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.1, 0.15, 0.30))
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.3, 0.3))
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.9))
