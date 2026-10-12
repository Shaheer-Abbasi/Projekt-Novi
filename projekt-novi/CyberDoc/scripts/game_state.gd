extends Node
## Temporary stand-in so Cyberdoc runs. If your currency/inventory already lives
## in RoundStats or elsewhere, point the three GameState lines in cyberdoc_shop.gd there instead.

var currency: int = 500
var inventory: Array[Dictionary] = []


func add_item(item: Dictionary) -> void:
	inventory.append(item)
	print("Cyberdoc gave you: ", item.name)


func save_game() -> void:
	pass # hook up save system here
