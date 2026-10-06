extends Control

@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var health_label: Label = $HealthLabel
@onready var player = $"../../Player"


func _ready() -> void:
	XpManager.xp_changed.connect(_on_xp_changed)
	XpManager.leveled_up.connect(_on_leveled_up)
	player.health_changed.connect(_on_health_changed)
	_on_xp_changed(XpManager.current_xp, XpManager.xp_to_next)
	_on_leveled_up(XpManager.level)
	_on_health_changed(player.health, player.max_health)

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	xp_bar.max_value = xp_to_next
	xp_bar.value = current_xp


func _on_leveled_up(new_level: int) -> void:
	level_label.text = "Level " + str(new_level)
	
func _on_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "Health: " + str(current_health) + " / " + str(max_health)
	

	
