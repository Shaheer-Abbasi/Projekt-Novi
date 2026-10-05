extends Button

var level: int = 1
var is_unlocked: bool = false

func _ready() -> void:
	level = get_index()+1
	text = str(level)
	is_unlocked = level <= LevelManager.level_unlocked
	modulate.a = 1.0 if is_unlocked else 0.5

func _pressed() -> void:
	if is_unlocked:
		LevelManager.current_level = level
		get_tree().call_deferred("change_scene_to_file", LevelManager._load_level(level))
