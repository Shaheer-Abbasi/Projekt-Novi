class_name DeathEffects
extends Node
## Drop this node into any level (story or roguelike). Every enemy that dies there BLINKS a different color, then DISINTEGRATES
## into little pixels that drift away, glow like embers and fade, instead of vanishing the instant it dies.
## A StoryLevel adds one for you; add your own to change the settings (the level then uses yours), or to use it in your regular game scene.

@export var enabled: bool = true

@export_group("Blink (the different color)")
## The color the enemy flashes just after it dies.
@export var blink_color: Color = Color(1.0, 0.25, 0.2)
## How many times it flashes.
@export_range(1, 10) var blink_flashes: int = 3
## How long the blinking lasts, in seconds.
@export var blink_seconds: float = 0.45

@export_group("Disintegrate and fade")
## ON: it breaks into pixels that fly away. OFF: it just turns the blink color and fades out.
@export var disintegrate: bool = true
## How long the disintegration and fade take, in seconds. (Blink + this = the whole effect.)
@export var disintegrate_seconds: float = 2.0
## The glow the flying pixels turn into.
@export var ember_color: Color = Color(1.0, 0.55, 0.15)
## Size of one flying pixel, in the sprite's own pixels. Smaller = finer dust (and more of it).
@export_range(1, 16) var pixel_size: int = 4
## How far the pixels drift, in screen pixels.
@export var spread: float = 70.0
## How far they also float upward.
@export var rise: float = 50.0

@export_group("Bosses")
## A boss's effect lasts this many times longer...
@export var boss_longer_by: float = 1.5
## ...and its pixels drift this many times further.
@export var boss_bigger_spread: float = 1.6

var _hooked: Dictionary = {}


func _ready() -> void:
	add_to_group("death_effects")
	get_tree().node_added.connect(_on_node_added)
	for e in get_tree().get_nodes_in_group("enemies"):     # enemies that are already there
		_hook(e)


## How long the whole effect lasts, in seconds (the cinematic holds the camera at least this long).
func total_seconds(boss: bool = false) -> float:
	return (blink_seconds + disintegrate_seconds) * (boss_longer_by if boss else 1.0)


func _on_node_added(node: Node) -> void:
	if node is EnemyNPC:
		_hook(node)


func _hook(node: Node) -> void:
	if node == null or _hooked.has(node.get_instance_id()) or not node.has_signal("died"):
		return
	_hooked[node.get_instance_id()] = true
	node.connect("died", _on_died)


func _on_died(enemy: Node) -> void:
	if not enabled or not (enemy is Node2D):
		return
	var fx := DeathEffect.spawn(enemy as Node2D, self)
	if fx != null:
		enemy.visible = false          # the effect replaces the enemy's own picture, so it never shows twice
