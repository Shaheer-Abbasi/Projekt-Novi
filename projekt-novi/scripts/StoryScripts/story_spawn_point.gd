@tool
class_name StorySpawnPoint
extends Marker2D
## A spot where enemies appear. Place these as children of a StoryEncounter, anywhere you want
## enemies to come from, and set what and how many in the Inspector.
## In the editor each one is drawn with its kind and count, so you can see your layout.

enum Kind { GRUNT, RUNNER, TANK, SHOOTER, BOSS }

const KIND_COLORS := [Color(1, 1, 1), Color(1, 0.85, 0.2), Color(0.4, 0.65, 1), Color(1, 0.4, 0.4), Color(0.8, 0.4, 1)]
const KIND_NAMES := ["GRUNT", "RUNNER", "TANK", "SHOOTER", "BOSS"]

## What spawns here.
@export var kind: Kind = Kind.GRUNT:
	set(value):
		kind = value
		queue_redraw()
## How many enemies this point spawns.
@export var count: int = 1:
	set(value):
		count = maxi(value, 0)
		queue_redraw()
## Enemies appear at random spots within this many pixels of the point. 0 = exactly on the point.
@export var scatter_radius: float = 40.0:
	set(value):
		scatter_radius = maxf(value, 0.0)
		queue_redraw()
## Seconds after the encounter starts before this point begins spawning.
@export var start_delay: float = 0.0
## Seconds between each enemy from this point. 0 = all at once.
@export var spawn_interval: float = 0.0
## Optional: your own stats (HP, damage, speed...) for enemies from THIS point only.
## Leave empty to use the level's stats for this kind. (Bosses use a BossStats.)
@export var stats_override: EnemyStats


func _draw() -> void:
	if not Engine.is_editor_hint():
		return                       # invisible while playing
	var col: Color = KIND_COLORS[kind]
	draw_circle(Vector2.ZERO, 14.0, Color(col.r, col.g, col.b, 0.55))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, col, 2.0)
	if scatter_radius > 0.0:
		draw_arc(Vector2.ZERO, scatter_radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.45), 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-40.0, -22.0), "%dx %s" % [count, KIND_NAMES[kind]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)

@export_group("Quick tuning for this point only (0 = leave as is)")
## Health of every enemy from this point.
@export var hp_override: float = 0.0
## Damage of every enemy from this point.
@export var damage_override: float = 0.0
## Bosses only. 2.0 = the boss attacks half as often (handy for a tutorial boss).
@export var boss_attack_slowdown: float = 1.0
