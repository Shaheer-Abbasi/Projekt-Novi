extends Control

@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel


func _ready() -> void:
	XpManager.xp_changed.connect(_on_xp_changed)
	XpManager.leveled_up.connect(_on_leveled_up)
	_on_xp_changed(XpManager.current_xp, XpManager.xp_to_next)
	_on_leveled_up(XpManager.level)

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	xp_bar.max_value = xp_to_next
	xp_bar.value = current_xp


func _on_leveled_up(new_level: int) -> void:
	level_label.text = "Level " + str(new_level)
	
