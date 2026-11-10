extends CanvasLayer
## Instanced into every arena; listens to the existing XpManager singleton.
## Pauses the game until a choice is made. Queues simultaneous level-ups.
##
## STYLED VERSION. It does everything the plain version did (same scene, same nodes, controller and Interact-key support), and adds a look
## you can change in the Inspector with no code: click this node (LevelUpUI) in the scene and open the groups below.
##   Style    CYBER (made in code, no art needed), SPRITES (your own pictures), or SCENE (leave the scene's own look alone)
##   Cards    each card shows an ICON, the upgrade's NAME and its DESCRIPTION as separate pieces you can style
##   Anim     the screen and cards pop in, cards grow when you point at them, the chosen card flashes
## The upgrade names and descriptions themselves are still written in level_up_upgrades.gd.

enum Style { SCENE, CYBER, SPRITES }

@export_group("Look")
## CYBER: dark angled cards with a coloured edge (no pictures needed). SPRITES: your own pictures (below). SCENE: leave the scene's own look as it is.
@export var style: Style = Style.CYBER
## The colour of the edges, glow and underline in the CYBER style.
@export var accent_color: Color = Color(0.78, 0.95, 0.10)
## How dark the screen behind the cards gets (CYBER and SPRITES; SCENE keeps the scene's own overlay).
@export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.72)
## The title. {level} becomes the level number.
@export var title_format: String = "LEVEL {level}  -  CHOOSE AN UPGRADE"

@export_group("Your pictures (SPRITES style)")
## Each picture is stretched like a 9-slice: the corners stay sharp, the middle stretches. The margin is how many pixels in from each edge are the corner.
@export var panel_texture: Texture2D
@export var panel_margin: int = 24
## The card. If you leave Hover / Pressed / Disabled empty, the card picture is made brighter / darker for them.
@export var card_texture: Texture2D
@export var card_hover_texture: Texture2D
@export var card_pressed_texture: Texture2D
@export var card_disabled_texture: Texture2D
@export var card_margin: int = 20
## A banner picture behind the title (optional).
@export var title_texture: Texture2D
@export var title_margin: int = 16

@export_group("Text")
## The font for everything on this screen. Empty = the scene's / Godot's default font.
@export var font: Font
@export var title_size: int = 34
@export var name_size: int = 26
@export var description_size: int = 18
@export var title_color: Color = Color(1.0, 1.0, 1.0)
@export var name_color: Color = Color(1.0, 1.0, 1.0)
@export var description_color: Color = Color(0.82, 0.86, 0.90)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.9)
@export var outline_size: int = 6

@export_group("Cards")
## ON: each card is built from an icon, a name and a description (so each can be styled). OFF: the plain button text of the old version.
@export var rich_cards: bool = true
## The smallest size of a card. (0,0 = keep the size set in the scene.)
@export var card_min_size: Vector2 = Vector2(250.0, 230.0)
@export var icon_size: Vector2 = Vector2(84.0, 84.0)
## One icon per upgrade (drag a picture on). An upgrade without one shows "Icon Other", or no icon.
@export var icon_damage: Texture2D
@export var icon_health: Texture2D
@export var icon_movement: Texture2D
@export var icon_attack_speed: Texture2D
@export var icon_range: Texture2D
@export var icon_cooldowns: Texture2D
@export var icon_other: Texture2D

@export_group("Animation")
## The screen fades in, the panel and cards pop in one after another, cards grow when pointed at, and the chosen card flashes.
@export var animate: bool = true
@export var open_seconds: float = 0.28
## Seconds between one card popping in and the next.
@export var card_stagger: float = 0.09
## How much a card grows when the mouse or the keyboard / pad focus is on it (1.0 = not at all).
@export_range(1.0, 1.3, 0.01) var hover_scale: float = 1.07
## How long the chosen card flashes before the screen closes (0 = closes at once).
@export var pick_flash_seconds: float = 0.22

@export_group("Sounds (optional)")
@export var open_sound: AudioStream
@export var hover_sound: AudioStream
@export var pick_sound: AudioStream
@export var sound_volume_db: float = 0.0
## The screen waits until the kills stop (an ability has finished hitting everything), then fades in.

## Extra seconds to wait after the level-up, on top of the kill wait below. 0 = none.
@export var show_delay: float = 0.0
## The screen only appears once no enemy has died (no XP gained) for this many seconds.
## Raise it if your ability's hits are spread out and the screen still pops up too early.
@export var settle_seconds: float = 0.6
## Never wait longer than this (seconds), even if enemies keep dying (a big swarm).
@export var max_wait_seconds: float = 4.0
## ON: also wait for the Ultimate's cinematic, a dash, and the clear slow motion to finish.
@export var wait_for_effects: bool = false
## How long the screen takes to fade in. 0 = instant.
@export var fade_seconds: float = 0.7
## Seconds the choices ignore input after appearing, so mashing buttons can't pick one by accident.
@export var input_guard_seconds: float = 0.25

@onready var overlay: ColorRect = $Overlay
@onready var level_title: Label = $Overlay/Center/Panel/Margin/Content/LevelTitle
@onready var options_row: HBoxContainer = $Overlay/Center/Panel/Margin/Content/Options
@onready var player: PlaytestPlayer = get_parent().get_node("Player") as PlaytestPlayer

var _pending_levels: Array[int] = []
var _offered: Array[String] = []
var _show_scheduled: bool = false
var _choosing: bool = false
var _opening: bool = false

var _card_icon: Array[TextureRect] = []
var _card_name: Array[Label] = []
var _card_desc: Array[Label] = []
var _card_content: Array[Control] = []
var _tweens: Dictionary = {}
var _accepting: bool = false
var _fade_tween: Tween
var _last_xp_ms: int = 0          # when XP last changed = when an enemy last died


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	for i in range(options_row.get_child_count()):
		var button := options_row.get_child(i) as Button
		button.pressed.connect(_choose.bind(i))
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_entered.connect(_on_card_hover.bind(button, true))
		button.mouse_exited.connect(_on_card_hover.bind(button, false))
		button.focus_entered.connect(_on_card_hover.bind(button, true))
		button.focus_exited.connect(_on_card_hover.bind(button, false))
	_apply_style()
	_build_cards()
	XpManager.leveled_up.connect(_on_leveled_up)


	XpManager.xp_changed.connect(_on_xp_changed)
	XpManager.leveled_up.connect(_on_leveled_up)


## Every kill gives XP, so this tells us enemies are still dying.
func _on_xp_changed(_current_xp: int, _xp_to_next: int) -> void:
	_last_xp_ms = Time.get_ticks_msec()


func _on_leveled_up(new_level: int) -> void:
	_last_xp_ms = Time.get_ticks_msec()
	_pending_levels.append(new_level)
	if not overlay.visible and not _show_scheduled:
		_show_scheduled = true
		_show_when_calm()


## Waits until the kills have stopped for a moment, then shows the screen.
func _show_when_calm() -> void:
	if show_delay > 0.0:
		await get_tree().create_timer(show_delay, true, false, true).timeout
	var waited := 0.0
	while true:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if player != null and player._dead:
			_show_scheduled = false
			return                                   # game over: no level-up screen
		if get_tree().paused:
			continue                                 # a conversation, the pause menu, the shop...: just wait
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)   # real seconds, even in slow motion
		var kills_settling := (Time.get_ticks_msec() - _last_xp_ms) < int(settle_seconds * 1000.0)
		var effects_playing := wait_for_effects and _effects_playing()
		if (not kills_settling and not effects_playing) or waited >= max_wait_seconds:
			break
	_show_next()


## True while the Ultimate's cinematic, a dash or the clear slow motion is still playing.
func _effects_playing() -> bool:
	if Engine.time_scale < 0.99:
		return true
	if player != null and (player._input_locked or player._dashing):
		return true
	var level := get_parent()
	if "is_cinematic" in level and level.is_cinematic:
		return true
	return false



func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var focused := get_viewport().gui_get_focus_owner()
	if is_pad and (focused == null or not overlay.is_ancestor_of(focused)):
		(options_row.get_child(0) as Button).grab_focus()
		return
	if _accepting and event.is_action_pressed("interact") and focused is Button and not (focused as Button).disabled:
		get_viewport().set_input_as_handled()
		(focused as Button).pressed.emit()


func _show_next() -> void:
	_show_scheduled = false
	if _pending_levels.is_empty():
		overlay.hide()
		get_tree().paused = false
		return

	_offered = LevelUpUpgrades.roll_choices()
	level_title.text = title_format.replace("{level}", str(_pending_levels.front()))
	for i in range(options_row.get_child_count()):
		var id: String = _offered[i]
		var data: Dictionary = LevelUpUpgrades.OPTIONS[id]
		var button := options_row.get_child(i) as Button
		if rich_cards and i < _card_name.size():
			button.text = ""
			_card_name[i].text = str(data["name"])
			_card_desc[i].text = str(data["description"])
			var icon := _icon_for(id, data)
			_card_icon[i].texture = icon
			_card_icon[i].visible = icon != null
		else:
			button.text = "%s\n\n%s" % [data["name"], data["description"]]
		button.disabled = false

	if rich_cards and card_min_size != Vector2.ZERO:
		for c in options_row.get_children():
			(c as Button).custom_minimum_size.y = card_min_size.y
	_opening = true
	var already_showing := overlay.visible
	overlay.show()
	get_tree().paused = true
	_play(open_sound)
	_animate_in()
	(options_row.get_child(0) as Button).grab_focus.call_deferred()
	_fade_in(already_showing)


## Fades the screen in (only the first time; a second queued level-up just swaps the choices).
func _fade_in(already_showing: bool) -> void:
	_accepting = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if already_showing or fade_seconds <= 0.0:
		overlay.modulate.a = 1.0
	else:
		overlay.modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.set_ignore_time_scale(true)
		_fade_tween.tween_property(overlay, "modulate:a", 1.0, fade_seconds)
		await _fade_tween.finished
	await get_tree().create_timer(input_guard_seconds, true, false, true).timeout
	_accepting = true


func _choose(index: int) -> void:
	if not _accepting or not overlay.visible or index < 0 or index >= _offered.size():
		return
	_choosing = true
	# Prevent accidental double-clicks / double reward grants.
	for child in options_row.get_children():
		(child as Button).disabled = true
	if not LevelUpUpgrades.apply(player, _offered[index]):
		push_error("Could not apply the selected level-up upgrade")
		for child in options_row.get_children():
			(child as Button).disabled = false
		_choosing = false
		return
	_play(pick_sound)
	if animate and pick_flash_seconds > 0.0:
		_flash_pick(index)
		await get_tree().create_timer(pick_flash_seconds, true, false, true).timeout
		if not is_inside_tree() or not overlay.visible:
			_choosing = false
			return

	_offered.clear()
	_pending_levels.pop_front()
	if _pending_levels.is_empty():
		_accepting = false
		overlay.hide()
		get_tree().paused = false
	else:
		# If a large XP pickup gave multiple levels, make a NEW set of 3.
		_show_next()
	_choosing = false


func _exit_tree() -> void:
	# Don't leave the game paused if this scene is unloaded with the menu open.
	if overlay != null and overlay.visible:
		get_tree().paused = false


# =====================================================================
#  the look
# =====================================================================

func _apply_style() -> void:
	var panel := overlay.get_node_or_null("Center/Panel") as Control
	var restyle := style != Style.SCENE
	if restyle:
		overlay.color = dim_color
	# the title
	if restyle or font != null:
		_style_label(level_title, title_size, title_color, true)
	if restyle:
		level_title.add_theme_stylebox_override("normal", _title_box())
	# the panel
	if restyle and panel != null:
		panel.add_theme_stylebox_override("panel", _panel_box())
	# the cards
	for i in range(options_row.get_child_count()):
		var b := options_row.get_child(i) as Button
		if restyle:
			b.add_theme_stylebox_override("normal", _card_box("normal"))
			b.add_theme_stylebox_override("hover", _card_box("hover"))
			b.add_theme_stylebox_override("pressed", _card_box("pressed"))
			b.add_theme_stylebox_override("disabled", _card_box("disabled"))
			b.add_theme_stylebox_override("focus", _card_box("hover"))
			b.add_theme_stylebox_override("hover_pressed", _card_box("pressed"))
		if (restyle or rich_cards) and card_min_size != Vector2.ZERO:
			b.custom_minimum_size = card_min_size
		if not rich_cards and (restyle or font != null):
			_style_label_like(b, description_size, name_color)


func _style_label(l: Label, size: int, color: Color, outline: bool) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	if outline and outline_size > 0:
		l.add_theme_constant_override("outline_size", outline_size)
		l.add_theme_color_override("font_outline_color", outline_color)


## A plain-text button (Rich Cards OFF): the same font and colours on its own text.
func _style_label_like(b: Button, size: int, color: Color) -> void:
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_focus_color", color)
	b.add_theme_color_override("font_pressed_color", color)
	b.add_theme_color_override("font_disabled_color", Color(color.r, color.g, color.b, 0.5))
	if font != null:
		b.add_theme_font_override("font", font)


func _title_box() -> StyleBox:
	if style == Style.SPRITES and title_texture != null:
		return _tex_box(title_texture, title_margin, Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.border_color = accent_color
	sb.border_width_bottom = 3
	sb.content_margin_bottom = 12.0
	sb.content_margin_top = 4.0
	return sb


func _panel_box() -> StyleBox:
	if style == Style.SPRITES and panel_texture != null:
		return _tex_box(panel_texture, panel_margin, Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.04, 0.9)
	sb.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.7)
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 18
	return sb


func _card_box(state: String) -> StyleBox:
	if style == Style.SPRITES and card_texture != null:
		match state:
			"hover":
				return _tex_box(card_hover_texture if card_hover_texture != null else card_texture, card_margin, Color.WHITE if card_hover_texture != null else Color(1.25, 1.25, 1.25))
			"pressed":
				return _tex_box(card_pressed_texture if card_pressed_texture != null else card_texture, card_margin, Color.WHITE if card_pressed_texture != null else Color(0.78, 0.78, 0.78))
			"disabled":
				return _tex_box(card_disabled_texture if card_disabled_texture != null else card_texture, card_margin, Color.WHITE if card_disabled_texture != null else Color(0.55, 0.55, 0.55, 0.8))
		return _tex_box(card_texture, card_margin, Color.WHITE)
	var a := accent_color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.07, 0.94)
	sb.border_color = Color(a.r, a.g, a.b, 0.55)
	sb.set_border_width_all(2)
	sb.border_width_left = 6                                             # the coloured bar on the left edge
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(14.0)
	match state:
		"hover":
			sb.bg_color = Color(0.07, 0.09, 0.13, 0.98)
			sb.border_color = a
			sb.shadow_color = Color(a.r, a.g, a.b, 0.45)
			sb.shadow_size = 14
		"pressed":
			sb.bg_color = Color(a.r * 0.25, a.g * 0.25, a.b * 0.25, 0.97)
			sb.border_color = a
		"disabled":
			sb.bg_color = Color(0.03, 0.035, 0.05, 0.85)
			sb.border_color = Color(a.r, a.g, a.b, 0.2)
	return sb


func _tex_box(tex: Texture2D, margin: int, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(float(margin))
	sb.set_content_margin_all(float(margin) * 0.6)
	sb.modulate_color = tint
	return sb


## Builds, inside each card, an icon + a name + a thin line + a description.
func _build_cards() -> void:
	_card_icon.clear()
	_card_name.clear()
	_card_desc.clear()
	_card_content.clear()
	if not rich_cards:
		return
	for i in range(options_row.get_child_count()):
		var b := options_row.get_child(i) as Button
		var pad := MarginContainer.new()
		pad.name = "CardContent"
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE                     # clicks go to the button underneath
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 16)
		b.add_child(pad)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(box)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = icon_size
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		box.add_child(icon)
		var nm := Label.new()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(nm, name_size, name_color, true)
		box.add_child(nm)
		if style == Style.CYBER:
			var line := ColorRect.new()
			line.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.8)
			line.custom_minimum_size = Vector2(0.0, 2.0)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(line)
		var ds := Label.new()
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_label(ds, description_size, description_color, false)
		box.add_child(ds)
		_card_icon.append(icon)
		_card_name.append(nm)
		_card_desc.append(ds)
		_card_content.append(box)


## A button does not grow to fit what is inside it, so measure the content and make every card as tall as the tallest one needs.
func _fit_cards() -> void:
	if not rich_cards or card_min_size == Vector2.ZERO:
		return
	var tallest := card_min_size.y
	for box in _card_content:
		tallest = maxf(tallest, box.get_combined_minimum_size().y + 32.0)      # 32 = the padding inside the card
	for c in options_row.get_children():
		var b := c as Button
		b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, card_min_size.x), tallest)


## The icon for an upgrade: the one you dragged on, else one named in level_up_upgrades.gd ("icon": "res://..."), else Icon Other.
func _icon_for(id: String, data: Dictionary) -> Texture2D:
	var t: Texture2D = null
	match id:
		"damage": t = icon_damage
		"health": t = icon_health
		"movement": t = icon_movement
		"attack_speed": t = icon_attack_speed
		"range": t = icon_range
		"cooldowns": t = icon_cooldowns
	if t == null and data.has("icon"):
		var raw = data["icon"]
		if raw is Texture2D:
			t = raw
		elif raw is String and ResourceLoader.exists(raw):
			t = load(raw) as Texture2D
	return t if t != null else icon_other


# =====================================================================
#  animation and sound
# =====================================================================

func _tween_for(key: Object) -> Tween:
	var id := key.get_instance_id()
	if _tweens.has(id) and _tweens[id] is Tween and (_tweens[id] as Tween).is_valid():
		(_tweens[id] as Tween).kill()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)                    # real time, even during slow motion
	_tweens[id] = tw
	return tw


func _animate_in() -> void:
	var panel := overlay.get_node_or_null("Center/Panel") as Control
	var buttons: Array[Button] = []
	for c in options_row.get_children():
		buttons.append(c as Button)
	if animate:
		overlay.modulate.a = 0.0
		for b in buttons:
			b.modulate = Color(1, 1, 1, 0)
			b.scale = Vector2(0.86, 0.86)
		if panel != null:
			panel.scale = Vector2(0.94, 0.94)
	else:
		overlay.modulate.a = 1.0
		for b in buttons:
			b.modulate = Color.WHITE
			b.scale = Vector2.ONE
		if panel != null:
			panel.scale = Vector2.ONE
	await get_tree().process_frame                    # the layout now knows how wide each label is...
	if not overlay.visible:
		return
	_fit_cards()                                      # ...so the cards can grow to fit their text
	await get_tree().process_frame
	if not overlay.visible:
		return
	if not animate:
		_opening = false
		_refresh_focus_scale()
		return
	if panel != null:
		panel.pivot_offset = panel.size * 0.5
	for b in buttons:
		b.pivot_offset = b.size * 0.5
	var tw := _tween_for(overlay)
	tw.set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, open_seconds * 0.5)
	if panel != null:
		tw.tween_property(panel, "scale", Vector2.ONE, open_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(buttons.size()):
		var delay := open_seconds * 0.3 + card_stagger * float(i)
		tw.tween_property(buttons[i], "modulate:a", 1.0, open_seconds * 0.7).set_delay(delay)
		tw.tween_property(buttons[i], "scale", Vector2.ONE, open_seconds * 0.9).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		_opening = false
		_refresh_focus_scale())


## Once the screen has opened, the card that has the focus (keyboard / pad) or the mouse is shown slightly larger.
func _refresh_focus_scale() -> void:
	if hover_scale <= 1.0 or not overlay.visible:
		return
	for c in options_row.get_children():
		var b := c as Button
		var lit := b.has_focus() or b.is_hovered()
		b.pivot_offset = b.size * 0.5
		_tween_for(b).tween_property(b, "scale", Vector2(hover_scale, hover_scale) if lit else Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_card_hover(button: Button, on: bool) -> void:
	if hover_scale <= 1.0 or not overlay.visible or _choosing:
		return
	if on and button.disabled:
		return
	if on and not _opening:
		_play(hover_sound)
	if _opening and not on:
		return
	var tw := _tween_for(button)
	tw.tween_property(button, "scale", Vector2(hover_scale, hover_scale) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _flash_pick(index: int) -> void:
	for i in range(options_row.get_child_count()):
		var b := options_row.get_child(i) as Button
		var tw := _tween_for(b)
		tw.set_parallel(true)
		if i == index:
			b.pivot_offset = b.size * 0.5
			tw.tween_property(b, "modulate", Color(1.9, 1.9, 1.9, 1.0), pick_flash_seconds * 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2(hover_scale * 1.06, hover_scale * 1.06), pick_flash_seconds * 0.5)
			tw.chain().tween_property(b, "modulate", Color.WHITE, pick_flash_seconds * 0.5)
		else:
			tw.tween_property(b, "modulate:a", 0.25, pick_flash_seconds * 0.6)


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = sound_volume_db
	sfx.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
