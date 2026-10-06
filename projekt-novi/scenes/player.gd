extends CharacterBody2D
signal shoot
signal health_changed(current_health: int, max_health: int)

var speed : int
var can_shoot : bool
var screen_size : Vector2
var max_health : int = 3
var health : int = 3

func _ready():
	screen_size = get_viewport_rect().size
	position = screen_size / 2
	speed = 200
	can_shoot = true
	XpManager.leveled_up.connect(_on_leveled_up)
	max_health = 3 + XpManager.bonus_health
	health = max_health

func get_input():
	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir.normalized() * speed
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot:
		var dir = get_global_mouse_position() - position
		shoot.emit(position, dir)
		can_shoot = false
		$ShotTimer.start()
	
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		
		
	
func _physics_process(_delta):
	get_input()
	move_and_slide()
	position = position.clamp(Vector2.ZERO, screen_size)
	
	var mouse = get_local_mouse_position()
	var angle = snappedf(mouse.angle(), PI / 4) / (PI / 4)
	angle = wrapi(int(angle), 0, 8)
	
	$AnimatedSprite2D.animation = "walk" + str(angle)
	
	if velocity.length() != 0:
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.frame = 0
	


func _on_shot_timer_timeout() -> void:
	can_shoot = true


func _on_leveled_up(_new_level: int) -> void:
	max_health = 3 + XpManager.bonus_health
	health += 1
	health_changed.emit(health, max_health)


func take_damage(amount: int) -> void:
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0:
		queue_free()
		
	
	
