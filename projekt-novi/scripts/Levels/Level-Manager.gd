extends Node

var current_level: int = 1
var level_unlocked: int = 1
var max_level: int = 5 #update once levels have been decided 

func _unlock_level(level_to_unlock: int) -> void:
	if level_to_unlock > level_unlocked:
		level_unlocked = level_to_unlock


func _load_level(level_to_load: int) -> String:
	if level_to_load > max_level:
		return "" # change this to return "add credits scence here for end of game"
	return str("res://scenes/Levels/", level_to_load,".tscn")
