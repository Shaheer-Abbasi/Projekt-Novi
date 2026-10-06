extends Node

signal xp_changed(current_xp: int, xp_to_next: int)
signal leveled_up(new_level: int)

const BASE_XP: int = 100
const GROWTH: float = 1.25
const ENEMY_XP: int = 25

@export var run_tests_on_start: bool = false

var current_xp: int = 0
var level: int = 1
var xp_to_next: int = BASE_XP
var attack_damage: int = 1
var bonus_health: int = 0


func _ready() -> void:
	if run_tests_on_start:
		run_tests()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.has_signal("defeated"):
		node.connect("defeated", _on_enemy_defeated)


func _on_enemy_defeated() -> void:
	add_xp(ENEMY_XP)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	# can level more than once
	while current_xp >= xp_to_next:
		level_up()
	xp_changed.emit(current_xp, xp_to_next)


func level_up() -> void:
	current_xp -= xp_to_next
	level += 1
	xp_to_next = int(BASE_XP * pow(GROWTH, level - 1))
	attack_damage += 1
	bonus_health += 1
	leveled_up.emit(level)


func reset() -> void:
	current_xp = 0
	level = 1
	xp_to_next = BASE_XP
	attack_damage = 1
	bonus_health = 0
	xp_changed.emit(current_xp, xp_to_next)


func check(test_name: String, passed: bool) -> void:
	print("PASS: " if passed else "FAIL: ", test_name)


func run_tests() -> void:
	reset()
	add_xp(50)
	check("partial xp", level == 1 and current_xp == 50)

	add_xp(50)
	check("exact level up", level == 2 and current_xp == 0 and xp_to_next == 125)

	add_xp(130)
	check("leftover xp", level == 3 and current_xp == 5)

	reset()
	add_xp(300)
	check("multi level", level == 3 and current_xp == 75)

	add_xp(-20)
	check("negative xp", level == 3 and current_xp == 75)

	reset()
	check("reset", level == 1 and current_xp == 0)
	
	
