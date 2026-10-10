extends Node
## Round stats: in-round currency, kill count, and survival time.
## Autoloaded as "RoundStats" so any script can read it.
##
## It hooks enemies up automatically the same way XpManager does
## (listens for nodes being added), so whoever spawns an enemy doesn't
## have to remember to connect anything.
##
## Each enemy can only pay out ONCE: we remember the instance id of every
## enemy we've rewarded, so a double "died"/"defeated" emit is ignored.

signal currency_changed(amount: int)
signal kills_changed(count: int)
signal survival_time_changed(seconds: float)

## Currency for a normal enemy. Placeholder value; tune as needed.
const ENEMY_REWARD: int = 10
## Currency for a boss (anything in the "boss" group).
const BOSS_REWARD: int = 100

var currency: int = 0
var kills: int = 0
var survival_time: float = 0.0

var _rewarded: Dictionary = {}  # enemy instance id -> true


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# Temp enemies + boss (BossNPC extends EnemyNPC): died(enemy)
	if node is EnemyNPC:
		if not node.died.is_connected(register_kill):
			node.died.connect(register_kill)
	# Andrew's Robot: defeated() has no argument, so pass the node along ourselves
	elif node.has_signal("defeated"):
		var cb := register_kill.bind(node)
		if not node.is_connected("defeated", cb):
			node.connect("defeated", cb)


## Call when an enemy dies. Safe to call more than once for the same enemy.
func register_kill(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if _rewarded.has(id):
		return
	_rewarded[id] = true

	kills += 1
	add_currency(BOSS_REWARD if enemy.is_in_group("boss") else ENEMY_REWARD)
	kills_changed.emit(kills)


func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	currency += amount
	currency_changed.emit(currency)


func set_survival_time(seconds: float) -> void:
	survival_time = maxf(seconds, 0.0)
	survival_time_changed.emit(survival_time)


## Call when a new round starts.
func reset() -> void:
	currency = 0
	kills = 0
	survival_time = 0.0
	_rewarded.clear()
	currency_changed.emit(currency)
	kills_changed.emit(kills)
	survival_time_changed.emit(survival_time)
