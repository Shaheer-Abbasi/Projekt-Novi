class_name StoryEncounter
extends Area2D
## One fight (or one story beat) in a story level. Put StorySpawnPoint nodes under it to say
## where enemies appear, then fill in the Inspector:
##   - WHEN it starts      (level start / player walks into its zone / after another encounter / from code)
##   - WHAT must be done   (defeat everything, or "Tanks = 5, Grunts = 3"...)
##   - MESSAGES            ("Defeat all the enemies to move on to the next stage!")
##   - DOORS               (open a door, lock the player in during the fight, reveal an exit)
## Roguelike mode does not use this at all.

signal started
## The moment the requirements are met (doors open, message shown).
signal cleared
## After the cleared conversation (if any) has ended. "After Encounter" waits for this one.
signal finished
signal progress_changed(text: String)

enum Trigger { LEVEL_START, PLAYER_ENTERS_ZONE, AFTER_ENCOUNTER, MANUAL }

const KIND_LABELS := ["Grunts", "Runners", "Tanks", "Shooters", "Bosses"]

@export var encounter_name: String = "Encounter"

@export_group("When it starts")
@export var trigger: Trigger = Trigger.LEVEL_START
## Only for "After Encounter": this one starts when that encounter is completely finished
## (cleared, and its "cleared" conversation has ended).
@export var after_encounter: StoryEncounter
## For "Player Enters Zone": draw the zone by adding a CollisionShape2D child to this node.

@export_group("What the player must do")
## ON: defeat EVERY enemy this encounter spawns. OFF: use the amounts below instead.
@export var defeat_all: bool = true
@export var grunts_to_defeat: int = 0
@export var runners_to_defeat: int = 0
@export var tanks_to_defeat: int = 0
@export var shooters_to_defeat: int = 0
@export var bosses_to_defeat: int = 0
## Extra kills of ANY enemy, after the specific amounts above are met.
## Example: Tanks = 5 and Any Other = 3 means "5 tanks, then 3 more of anything".
@export var any_other_to_defeat: int = 0

@export_group("Walk to a place (optional)")
## Optional: an Area2D (with a CollisionShape2D) the player must ALSO walk into before this encounter counts as done.
## Use it for "run to the next room". With no spawn points, walking there is the whole encounter.
@export var must_reach: Area2D

@export_group("Messages")
## Shown at the top of the screen when the encounter starts. Leave empty for none.
@export_multiline var start_message: String = "Defeat all the enemies to move on to the next stage!"
## Show a live counter under the message, like "Tanks 2/5   Grunts 1/3".
@export var show_progress: bool = true
## Shown briefly when the encounter is cleared. Leave empty for none.
@export var clear_message: String = "Area cleared!"
## How long the start / clear messages stay up. 0 = the start message stays until the area is cleared.
@export var message_seconds: float = 5.0
## TYPE THE CONVERSATION RIGHT HERE (played, game frozen, when the encounter starts, before the enemies appear).
## One line per line:   VOW: What do they say?     A line with no NAME: is said by the previous speaker. Lines starting with # are notes.
@export_multiline var start_dialogue_text: String = ""
## Same, but played after the area is cleared.
@export_multiline var clear_dialogue_text: String = ""
## (Advanced) A DialogueSequence file to reuse in several places. If the text above is filled in, the text wins.
@export var start_dialogue: DialogueSequence
## A conversation played after the encounter is cleared.
@export var clear_dialogue: DialogueSequence

@export_group("Key prompt (freezes the game until the player presses the key)")
## EASIEST: choose the ability this section teaches. The player is GIVEN it if they do not have it yet (for the rest of this
## level only), the HUD shows it, and the pop-up shows the key it really is. Leave on "(by key below)" to use the next setting instead.
@export_enum("(by key below)", "AbilityFanBurst", "AbilityShockwave", "AbilityBouquet", "AbilityDash", "AbilityUltimate") var prompt_ability: String = "(by key below)"
## Off = never give the ability: if the player does not have it, there is no pop-up.
@export var grant_ability_if_missing: bool = true
## Shows a pop-up like "FAN BURST ... PRESS [ 1 ]" and freezes the game until that key is pressed, then fires the ability.
## (Only used when the setting above is "(by key below)".)
@export_enum("(none)", "ability_1", "ability_2", "ability_3", "ability_4", "ability_5") var prompt_action: String = "(none)"
## The pop-up's title. Empty = the ability's name.
@export var prompt_title: String = ""
## The pop-up's text. Empty = a built-in description of the ability.
@export_multiline var prompt_text: String = ""
enum PromptWhen { AFTER_ENEMIES_APPEAR, WHEN_SHOT_INCOMING }
## After Enemies Appear: shortly after the enemies spawn. When Shot Incoming: when a laser is about to hit the player (for the Dash).
@export var prompt_when: PromptWhen = PromptWhen.AFTER_ENEMIES_APPEAR
## Seconds after the enemies appear before the pop-up (After Enemies Appear).
@export var prompt_delay: float = 0.8
## When Shot Incoming: give up after this many seconds if no shot ever comes.
@export var prompt_wait_limit: float = 15.0

@export_group("Doors and gates")
## Doors that BLOCK the way until the area is cleared. Solid and visible at first; they fade out and stop blocking when cleared.
@export var open_when_cleared: Array[Node]
## Doors that CLOSE when the fight starts (locking the player in) and open when it is cleared.
@export var lock_during_fight: Array[Node]
## Things that APPEAR when cleared (an exit arrow, a portal...). Hidden and non-solid until then.
@export var reveal_when_cleared: Array[Node]
## How long doors take to fade in / out.
@export var door_fade_seconds: float = 0.6

@export_group("After it is cleared")
## ON for the last encounter of a level: shows LEVEL COMPLETE, unlocks the next level, opens the next scene.
@export var completes_level: bool = false

var is_started: bool = false
var is_cleared: bool = false
var is_finished: bool = false

var _level: StoryLevel
var _points: Array = []
var _planned: Array = [0, 0, 0, 0, 0]
var _killed: Array = [0, 0, 0, 0, 0]
var _alive: Array = []
var _pending: int = 0
var _reached: bool = true
var _prompt_ab: Ability


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2            # the player's physics layer (for the "enters zone" trigger)
	monitorable = false
	_level = _find_level()
	_collect_points(self)
	for p in _points:
		_planned[p.kind] += p.count
	_set_group(open_when_cleared, true, 0.0)       # blocking doors start closed
	_set_group(lock_during_fight, false, 0.0)      # lock doors start open
	_set_group(reveal_when_cleared, false, 0.0)    # exits start hidden
	if must_reach != null:
		_reached = false
		must_reach.collision_mask = 2
		must_reach.monitoring = true
		must_reach.body_entered.connect(_on_reach_body)
	match trigger:
		Trigger.LEVEL_START:
			_start_after_level_intro.call_deferred()
		Trigger.PLAYER_ENTERS_ZONE:
			body_entered.connect(_on_body_entered)
		Trigger.AFTER_ENCOUNTER:
			if after_encounter != null:
				after_encounter.finished.connect(start)
			else:
				push_warning("StoryEncounter '%s': Trigger is 'After Encounter' but no encounter is chosen." % encounter_name)


func _find_level() -> StoryLevel:
	var n := get_parent()
	while n != null:
		if n is StoryLevel:
			return n
		n = n.get_parent()
	return null


func _collect_points(node: Node) -> void:
	for c in node.get_children():
		if c is StorySpawnPoint:
			_points.append(c)
		_collect_points(c)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		start()


## A level with an opening run-in begins its first encounter only when the run-in is over.
func _start_after_level_intro() -> void:
	if _level != null and _level.intro_running:
		await _level.intro_finished
	start()


func _on_reach_body(body: Node) -> void:
	if is_started and not is_cleared and body.is_in_group("player"):
		_reached = true
		_publish_progress()
		_check_clear()


# =====================================================================
#  running the encounter
# =====================================================================

## Starts the encounter. Called automatically by the trigger; call it yourself for "Manual".
func start() -> void:
	if is_started:
		return
	is_started = true
	started.emit()
	_run()


func _run() -> void:
	if _level == null:
		push_warning("StoryEncounter '%s' is not inside a StoryLevel, so it has no enemy scene. Put it under your level's root node." % encounter_name)
	var start_seq := _sequence(start_dialogue_text, start_dialogue)
	if start_seq != null:
		await _say(start_seq)
	_set_group(lock_during_fight, true, door_fade_seconds)
	if start_message.strip_edges() != "":
		_notice().show_message(start_message, message_seconds)
	_publish_progress()
	if prompt_ability != "(by key below)" and _level != null:
		_prompt_ab = _level.get_or_grant_ability(prompt_ability, grant_ability_if_missing)     # this section's ability
	for p in _points:
		_spawn_from(p)
	if must_reach != null:
		for b in must_reach.get_overlapping_bodies():          # already standing there when it starts
			if b.is_in_group("player"):
				_reached = true
	await _run_prompt()
	_check_clear()


func _spawn_from(p: StorySpawnPoint) -> void:
	_pending += p.count
	if p.start_delay > 0.0:
		await _wait(p.start_delay)
	for i in range(p.count):
		if i > 0 and p.spawn_interval > 0.0:
			await _wait(p.spawn_interval)
		if is_cleared:
			_pending -= (p.count - i)
			return
		_spawn_one(p)
		_pending -= 1
	_check_clear()


func _spawn_one(p: StorySpawnPoint) -> void:
	if _level == null:
		return
	var is_boss: bool = p.kind == StorySpawnPoint.Kind.BOSS
	var scene: PackedScene = _level.boss_scene if is_boss else _level.enemy_scene
	if scene == null:
		push_warning("StoryLevel needs an %s (Inspector > Enemies used by every encounter)." % ("Boss Scene" if is_boss else "Enemy Scene"))
		return
	var e := scene.instantiate()
	var stats: EnemyStats = p.stats_override if p.stats_override != null else _level.get_stats(p.kind)
	if p.hp_override > 0.0 or p.damage_override > 0.0 or (is_boss and p.boss_attack_slowdown != 1.0):
		stats = stats.duplicate() as EnemyStats             # tune a copy, never the shared stats
		if p.hp_override > 0.0:
			stats.max_hp = p.hp_override
		if p.damage_override > 0.0:
			stats.damage = p.damage_override
		if is_boss and "attack_interval_phase_1" in stats:
			stats.attack_interval_phase_1 *= p.boss_attack_slowdown
			stats.attack_interval_phase_2 *= p.boss_attack_slowdown
	e.stats = stats
	_level.add_child(e)
	var offset := Vector2.ZERO
	if p.scatter_radius > 0.0:
		offset = Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * p.scatter_radius
	e.global_position = p.global_position + offset
	e.add_to_group("story_enemy")
	_alive.append(e)
	e.died.connect(_on_enemy_died.bind(p.kind))
	if is_boss and _level.hud != null:
		_level.hud.show_boss(e)


func _on_enemy_died(enemy: Node, kind: int) -> void:
	_alive.erase(enemy)
	_killed[kind] += 1
	if _level != null:
		_level.register_kill()
	_publish_progress()
	_check_clear()


# =====================================================================
#  requirements
# =====================================================================

func _required() -> Array:
	return [grunts_to_defeat, runners_to_defeat, tanks_to_defeat, shooters_to_defeat, bosses_to_defeat]


func _enemy_requirements_met() -> bool:
	if defeat_all:
		return _pending == 0 and _alive.is_empty()
	var req := _required()
	var surplus := 0
	for k in range(5):
		if _killed[k] < req[k]:
			return false
		surplus += _killed[k] - req[k]
	return surplus >= any_other_to_defeat


func _check_clear() -> void:
	if is_cleared or not is_started:
		return
	var met := _enemy_requirements_met()
	if not met and _alive.is_empty() and _pending == 0:
		# nothing is left to defeat: never trap the player behind an impossible requirement
		if _planned[0] + _planned[1] + _planned[2] + _planned[3] + _planned[4] > 0:
			push_warning("StoryEncounter '%s': the spawn points can't produce the enemies the requirements ask for. Clearing it anyway." % encounter_name)
		met = true
	if met and _reached:
		_on_cleared()


## Text like "Tanks 2/5   Grunts 1/3" (or "Enemies defeated 4/8").
func progress_text() -> String:
	var total_killed := 0
	for k in _killed:
		total_killed += k
	if defeat_all:
		var total := 0
		for k in _planned:
			total += k
		if total == 0:
			return ""                          # nothing to fight (a corridor, a conversation): no counter
		return "Enemies defeated  %d/%d" % [total_killed, total]
	var req := _required()
	var parts := PackedStringArray()
	var surplus := 0
	for k in range(5):
		if req[k] > 0:
			parts.append("%s %d/%d" % [KIND_LABELS[k], mini(_killed[k], req[k]), req[k]])
		surplus += maxi(_killed[k] - req[k], 0)
	if any_other_to_defeat > 0:
		parts.append("Others %d/%d" % [mini(surplus, any_other_to_defeat), any_other_to_defeat])
	return "   ".join(parts)


func _publish_progress() -> void:
	var text := progress_text()

	progress_changed.emit(text)
	if show_progress and not is_cleared:
		_notice().set_progress(text)


func _on_cleared() -> void:
	is_cleared = true
	cleared.emit()
	_notice().clear_progress()
	if clear_message.strip_edges() != "":
		_notice().show_message(clear_message, 3.0)
	else:
		_notice().hide_message()
	_set_group(lock_during_fight, false, door_fade_seconds)
	_set_group(open_when_cleared, false, door_fade_seconds)
	_set_group(reveal_when_cleared, true, door_fade_seconds)
	var clear_seq := _sequence(clear_dialogue_text, clear_dialogue)
	if clear_seq != null:
		await _wait(1.0)                       # let the player see the doors open first
		await _say(clear_seq)
	is_finished = true
	finished.emit()
	if completes_level and _level != null:
		_level.complete_level()


# =====================================================================
#  doors, messages, dialogue
# =====================================================================

func _set_group(nodes: Array, on: bool, fade: float) -> void:
	for n in nodes:
		if n != null and is_instance_valid(n):
			_set_enabled(n, on, fade)


## Enabled = visible and solid. Disabled = hidden and walk-through.
func _set_enabled(n: Node, on: bool, fade: float) -> void:
	_set_collisions(n, on)
	if not (n is CanvasItem):
		return
	var ci := n as CanvasItem
	if n.has_meta("_gate_tween"):                      # (asking for a missing meta value prints an error, so check first)
		var old = n.get_meta("_gate_tween")
		if old is Tween and old.is_valid():
			old.kill()
	if on:
		ci.visible = true
		if fade > 0.0:
			ci.modulate.a = 0.0
			var tw := ci.create_tween()
			tw.tween_property(ci, "modulate:a", 1.0, fade)
			n.set_meta("_gate_tween", tw)
		else:
			ci.modulate.a = 1.0
	else:
		if fade > 0.0 and ci.visible:
			var tw2 := ci.create_tween()
			tw2.tween_property(ci, "modulate:a", 0.0, fade)
			tw2.tween_callback(func(): ci.visible = false)
			n.set_meta("_gate_tween", tw2)
		else:
			ci.visible = false


func _set_collisions(n: Node, on: bool) -> void:
	if n is CollisionShape2D or n is CollisionPolygon2D:
		n.set_deferred("disabled", not on)
	elif n is TileMapLayer:
		n.collision_enabled = on
	for c in n.get_children():
		_set_collisions(c, on)


func _notice() -> StoryNotice:
	if _level != null:
		return _level.get_notice()
	var n := get_tree().get_first_node_in_group("story_notice") as StoryNotice
	if n == null:
		n = StoryNotice.new()
		get_tree().current_scene.add_child(n)
	return n


## The text typed on this node, or the DialogueSequence file. null = nothing to play.
func _sequence(text: String, file: DialogueSequence) -> DialogueSequence:
	if text.strip_edges() != "":
		var d := DialogueSequence.new()
		d.text = text
		return d
	if file != null and not file.is_empty():
		return file
	return null


func _say(seq: DialogueSequence) -> void:
	var box: DialogueBox
	if _level != null:
		box = _level.get_dialogue()
	else:
		box = get_tree().get_first_node_in_group("story_dialogue") as DialogueBox
		if box == null:
			box = DialogueBox.new()
			get_tree().current_scene.add_child(box)
			box.add_to_group("story_dialogue")
	box.play_sequence(seq)
	await box.finished


# =====================================================================
#  key prompt ("PRESS [ 1 ]")
# =====================================================================

func _run_prompt() -> void:
	if _level == null:
		return
	var action := prompt_action
	var ab: Ability = null
	if prompt_ability != "(by key below)":
		ab = _prompt_ab
		if ab == null:
			return                                   # not given (or not found): nothing to teach
		action = _level.action_for_ability(ab)
	elif action == "(none)" or action == "":
		return
	else:
		ab = _ability_for(action)
	if action == "":
		return
	if prompt_when == PromptWhen.WHEN_SHOT_INCOMING:
		var hit := await _wait_until(_laser_incoming, prompt_wait_limit)
		if not hit:
			return
	else:
		await _wait(prompt_delay)
	if is_cleared:
		return
	action = _level.action_for_ability(ab) if ab != null else action        # (the list may have changed while waiting)
	var title := prompt_title
	if title == "":
		title = ab.ability_name.to_upper() if ab != null else action.to_upper()
	var body := prompt_text if prompt_text != "" else StoryPrompt.default_body(action)
	if prompt_text == "" and ab != null:
		body = _ability_blurb(ab, action)
	await _level.get_prompt().ask(action, title, body)
	if ab != null:
		ab.try_activate()                          # do what the player asked for, so they see it work
	if ab != null and _ability_kind(ab) == "AbilityDash" and _level.player != null:
		_level.player._invuln_left = maxf(_level.player._invuln_left, 0.6)     # make sure the dodge works


## "AbilityDash", "AbilityFanBurst"... from the ability's script (its class_name, or its file name).
func _ability_kind(ab: Ability) -> String:
	var sc: Script = ab.get_script()
	if sc == null:
		return ""
	var g := String(sc.get_global_name())
	return g if g != "" else sc.resource_path.get_file().get_basename()


## A one-line description for the pop-up, by ability kind (so it is right whichever key the ability is on).
func _ability_blurb(ab: Ability, fallback_action: String) -> String:
	match _ability_kind(ab):
		"AbilityFanBurst":
			return StoryPrompt.INFO["ability_1"]
		"AbilityShockwave":
			return StoryPrompt.INFO["ability_2"]
		"AbilityBouquet":
			return StoryPrompt.INFO["ability_3"]
		"AbilityUltimate":
			return StoryPrompt.INFO["ability_4"]
		"AbilityDash":
			return StoryPrompt.INFO["ability_5"]
	return StoryPrompt.default_body(fallback_action)


func _ability_for(action: String) -> Ability:
	if _level == null or _level.player == null:
		return null
	var i := action.get_slice("_", 1).to_int() - 1
	if i >= 0 and i < _level.player.abilities.size():
		return _level.player.abilities[i]
	return null


## True when a laser is flying toward the player and is about to hit.
func _laser_incoming() -> bool:
	if _level == null or _level.player == null:
		return false
	for c in _level.get_children():
		if c is EnemyProjectile and c.laser:
			var to_player: Vector2 = _level.player.global_position - c.global_position
			if to_player.length() < 100.0 and c.direction.dot(to_player) > 0.0:
				return true
	return false


func _wait_until(cond: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if cond.call():
			return true
		await _wait(0.05)
		waited += 0.05
	return false


## Waits using a Timer node, so nothing is left hanging if the scene is closed meanwhile.
func _wait(seconds: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.start(maxf(seconds, 0.01))
	await t.timeout
	t.queue_free()
