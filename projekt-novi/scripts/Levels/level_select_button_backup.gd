extends BaseButton
## Level select button. Works on a normal Button OR a TextureButton
## (both are kinds of BaseButton, which is why this script can go on either).

## Which level this button opens. 0 = automatic: its position among its siblings
## (1st button = level 1, 2nd = level 2, ...). Set a number here to choose it yourself.
@export var level: int = 0

var is_unlocked: bool = false


func _ready() -> void:
	if level <= 0:
		level = get_index() + 1
	_show_number()
	is_unlocked = level <= LevelManager.level_unlocked
	modulate.a = 1.0 if is_unlocked else 0.5


## A normal Button shows the number as its text. A TextureButton can't show text,
## so it fills in a Label child instead (add a Label under the TextureButton if you want a number).
func _show_number() -> void:
	if "text" in self:
		set("text", str(level))
	else:
		for c in get_children():
			if c is Label:
				c.text = str(level)


func _pressed() -> void:
	if is_unlocked:
		LevelManager.current_level = level
		get_tree().call_deferred("change_scene_to_file", LevelManager._load_level(level))
