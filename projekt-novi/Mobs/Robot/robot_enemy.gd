extends CharacterBody2D

@export var move_speed: float = 85.0
@export var preferred_distance: float = 300.0
@export var too_close_distance: float = 150.0
@export var attack_range: float = 750.0
@export var attack_cooldown: float = 2.2
@export var max_health: int = 2
@export var contact_damage: int = 1

const PROJECTILE_SCENE: PackedScene = preload("res://Mobs/Robot/robot_projectile.tscn")

var player: Node2D
var health: int
var attack_timer: float = 1.0
var strafe_sign: float = 1.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_find_player()
	$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	$ContactArea.body_entered.connect(_on_contact_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance <= 0.001:
		velocity = Vector2.ZERO
	else:
		var direction: Vector2 = to_player.normalized()
		var desired_direction: Vector2

		if distance > preferred_distance:
			desired_direction = direction
		elif distance < too_close_distance:
			desired_direction = -direction
		else:
			desired_direction = direction.orthogonal() * strafe_sign

		velocity = desired_direction.normalized() * move_speed

	move_and_slide()

	if is_instance_valid(player):
		$Sprite2D.flip_h = player.global_position.x < global_position.x

	attack_timer -= delta
	if distance <= attack_range and attack_timer <= 0.0:
		_shoot()
		attack_timer = attack_cooldown

func _find_player() -> void:
	var grouped_player: Node = get_tree().get_first_node_in_group("player")
	if grouped_player is Node2D:
		player = grouped_player as Node2D
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var named_player: Node = current_scene.get_node_or_null("Player")
		if named_player is Node2D:
			player = named_player as Node2D

func _shoot() -> void:
	if not is_instance_valid(player):
		return

	var projectile: Area2D = PROJECTILE_SCENE.instantiate() as Area2D
	if projectile == null:
		return

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	var direction: Vector2 = (player.global_position - global_position).normalized()
	projectile.set("direction", direction)
	projectile.set("damage", 1)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("bullets"):
		return

	if is_instance_valid(area):
		area.queue_free()

	take_damage(1)

func take_damage(amount: int) -> void:
	health -= amount
	$Sprite2D.modulate = Color(1.0, 0.45, 0.45, 1.0)
	$HitFlashTimer.start()
	queue_redraw()

	if health <= 0:
		queue_free()

func _on_contact_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_damage_player(body, contact_damage)

func _damage_player(body: Node, amount: int) -> void:
	if body.has_method("take_damage"):
		body.call("take_damage", amount)
		return

	var hits: int = int(body.get_meta("robot_hits", 0)) + 1
	body.set_meta("robot_hits", hits)

	if hits >= 3:
		body.queue_free()

func _is_player(body: Node) -> bool:
	return body == player or body.is_in_group("player") or body.name == "Player"

func _on_strafe_timer_timeout() -> void:
	strafe_sign *= -1.0

func _on_hit_flash_timer_timeout() -> void:
	$Sprite2D.modulate = Color.WHITE

func _draw() -> void:
	var width: float = 70.0
	var ratio: float = clamp(float(health) / float(max_health), 0.0, 1.0)
	draw_rect(Rect2(-width * 0.5, -82.0, width, 7.0), Color(0.12, 0.02, 0.02, 0.9), true)
	draw_rect(Rect2(-width * 0.5, -82.0, width * ratio, 7.0), Color(1.0, 0.08, 0.12, 1.0), true)
