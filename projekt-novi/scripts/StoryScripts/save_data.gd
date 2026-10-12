class_name SaveData
extends RefCounted
## A tiny save file (user://save.cfg) for things that must survive closing the game.
## Right now it remembers one thing: whether the player has already seen the tutorial.
##
## To see the tutorial again as a brand-new player:
##   - in Godot: Project > Open User Data Folder, then delete save.cfg
##   - or call SaveData.reset_tutorial() from anywhere

const PATH := "user://save.cfg"


static func get_flag(key: String, default_value: bool = false) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return default_value
	return bool(cfg.get_value("flags", key, default_value))


static func set_flag(key: String, value: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # fine if the file does not exist yet
	cfg.set_value("flags", key, value)
	cfg.save(PATH)


static func is_tutorial_done() -> bool:
	return get_flag("tutorial_done")


static func mark_tutorial_done() -> void:
	set_flag("tutorial_done", true)


static func reset_tutorial() -> void:
	set_flag("tutorial_done", false)
