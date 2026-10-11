extends Area2D
## Cyberdoc in the level. Collision layer = npc (3), mask = player (2) only,
## so the only body that can ever enter his range is the player.

@export var shop_scene: PackedScene = preload("res://CyberDoc/scenes/cyberdoc_shop.tscn")

var player_in_range := false
var shop_open := false

@onready var prompt: Label = $Prompt


func _ready() -> void:
	_move_to_random_spawn()
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _move_to_random_spawn() -> void:
	var spots := get_tree().get_nodes_in_group("cyberdoc_spawn")
	if spots.is_empty():
		return
	global_position = spots.pick_random().global_position

func _on_body_entered(_body: Node2D) -> void:
	player_in_range = true
	prompt.show()


func _on_body_exited(_body: Node2D) -> void:
	player_in_range = false
	prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not shop_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_shop()


func _open_shop() -> void:
	shop_open = true
	prompt.hide()
	var shop := shop_scene.instantiate()
	shop.closed.connect(_on_shop_closed)
	get_tree().current_scene.add_child(shop)


func _on_shop_closed() -> void:
	set_deferred("shop_open", false)
	prompt.visible = player_in_range
