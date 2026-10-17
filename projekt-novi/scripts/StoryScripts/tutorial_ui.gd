class_name TutorialUI
extends CanvasLayer
## The tutorial's screens, built in code: freeze prompt ("Press SHIFT to dash"), hint banner,
## fades, letterbox bars, title card, intro video and logo. Conversations use a DialogueBox.
## Everything can be restyled with a UISkin (assign it on the TutorialDirector).

signal dialogue_finished
signal logo_dismissed
signal video_finished

const LIME := Color(0.78, 0.95, 0.10)

## Set before adding to the scene to restyle everything.
var skin: UISkin

var is_prompt_open: bool = false
var is_waiting_at_logo: bool = false
var is_playing_video: bool = false
var is_dialogue_open: bool:
	get:
		return _dialogue != null and _dialogue.is_open

var _eff: UISkin
var _dialogue: DialogueBox
var _root: Control
var _fade: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _title: Label
var _title_sub: Label
var _logo: TextureRect
var _logo_label: Label
var _logo_hint: Label
var _video: VideoStreamPlayer
var _hint_panel: PanelContainer
var _hint_label: RichTextLabel
var _dim: ColorRect
var _prompt_panel: PanelContainer
var _prompt_title: Label
var _prompt_body: RichTextLabel
var _prompt_key: Label
var _skip_label: Label
var _skip_hint_on: bool = false


## The name of the key bound to an input action, e.g. "ability_5" -> "SHIFT".
static func key_text(action: String) -> String:
	if action == "attack":
		return "LEFT CLICK"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return (e as InputEventKey).as_text_physical_keycode().to_upper()
	return action.to_upper()


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS   # must keep working while the game is frozen
	_eff = skin if skin != null else UISkin.new()
	_build()


## Safety net: if the tutorial is closed while the game is frozen, never leave the next scene frozen.
func _exit_tree() -> void:
	if is_prompt_open and get_tree() != null:
		get_tree().paused = false


# --- building the screens -------------------------------------------------

func _label(text: String, size: int, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	if _eff.font != null:
		l.add_theme_font_override("font", _eff.font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rich(size: int, align_center: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", _eff.text_color)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_constant_override("outline_size", 6)
	if _eff.font != null:
		r.add_theme_font_override("normal_font", _eff.font)
		r.add_theme_font_override("bold_font", _eff.font)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if align_center:
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return r


func _build() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# intro video (sits under the fade so the director can fade it out)
	_video = VideoStreamPlayer.new()
	_video.anchor_right = 1.0
	_video.anchor_bottom = 1.0
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.visible = false
	_video.finished.connect(_on_video_finished)
	_root.add_child(_video)

	# fade to black
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_root.add_child(_fade)

	# letterbox bars
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.anchor_right = 1.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bottom)

	# title card
	_title = _label("", 96, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_title.anchor_right = 1.0
	_title.anchor_top = 0.38
	_title.anchor_bottom = 0.38
	_title.offset_top = -70.0
	_title.offset_bottom = 70.0
	_title.modulate.a = 0.0
	_root.add_child(_title)
	_title_sub = _label("", 30, _eff.prompt_title_color, HORIZONTAL_ALIGNMENT_CENTER)
	_title_sub.anchor_right = 1.0
	_title_sub.anchor_top = 0.38
	_title_sub.anchor_bottom = 0.38
	_title_sub.offset_top = 70.0
	_title_sub.offset_bottom = 120.0
	_title_sub.modulate.a = 0.0
	_root.add_child(_title_sub)

	# logo
	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.anchor_left = 0.5
	_logo.anchor_right = 0.5
	_logo.anchor_top = 0.45
	_logo.anchor_bottom = 0.45
	_logo.offset_left = -430.0
	_logo.offset_right = 430.0
	_logo.offset_top = -230.0
	_logo.offset_bottom = 230.0
	_logo.pivot_offset = Vector2(430.0, 230.0)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.visible = false
	_root.add_child(_logo)
	_logo_label = _label("", 120, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_logo_label.anchor_right = 1.0
	_logo_label.anchor_top = 0.45
	_logo_label.anchor_bottom = 0.45
	_logo_label.offset_top = -90.0
	_logo_label.offset_bottom = 90.0
	_logo_label.pivot_offset = Vector2(576.0, 90.0)
	_logo_label.visible = false
	_root.add_child(_logo_label)
	_logo_hint = _label("PRESS ANY KEY", 26, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_logo_hint.anchor_right = 1.0
	_logo_hint.anchor_top = 0.88
	_logo_hint.anchor_bottom = 0.88
	_logo_hint.offset_top = -20.0
	_logo_hint.offset_bottom = 20.0
	_logo_hint.visible = false
	_root.add_child(_logo_hint)

	# hint banner (top, does not freeze the game)
	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", _eff.box_or_default(_eff.banner_box, 12))
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.offset_left = -_eff.banner_width * 0.5
	_hint_panel.offset_right = _eff.banner_width * 0.5
	_hint_panel.offset_top = _eff.banner_top        # clear of the HUD's left block and right counters
	_hint_panel.offset_bottom = _eff.banner_top
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	_root.add_child(_hint_panel)
	_hint_label = _rich(_eff.banner_font_size, true)
	_hint_label.fit_content = true
	_hint_label.custom_minimum_size = Vector2(maxf(_eff.banner_width - 60.0, 100.0), 0)
	_hint_panel.add_child(_hint_label)

	# freeze prompt
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	_root.add_child(_dim)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", _eff.box_or_default(_eff.prompt_box, 22))
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 0.5
	_prompt_panel.anchor_bottom = 0.5
	_prompt_panel.offset_left = -320.0
	_prompt_panel.offset_right = 320.0
	_prompt_panel.offset_top = -150.0
	_prompt_panel.offset_bottom = 150.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	_root.add_child(_prompt_panel)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 10)
	_prompt_panel.add_child(pv)
	_prompt_title = _label("", 50, _eff.prompt_title_color, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(_prompt_title)
	_prompt_body = _rich(_eff.prompt_text_size, true)
	_prompt_body.custom_minimum_size = Vector2(580, 90)
	pv.add_child(_prompt_body)
	_prompt_key = _label("", _eff.prompt_key_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_key.custom_minimum_size = Vector2(580, 70)
	pv.add_child(_prompt_key)

	# conversations
	_dialogue = DialogueBox.new()
	_dialogue.skin = _eff
	add_child(_dialogue)
	_dialogue.layer = 72
	_dialogue.finished.connect(func(): dialogue_finished.emit())

	# small skip reminder, bottom-right
	_skip_label = _label("TAB - skip tutorial", 18, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	_skip_label.anchor_left = 1.0
	_skip_label.anchor_right = 1.0
	_skip_label.anchor_top = 1.0
	_skip_label.anchor_bottom = 1.0
	_skip_label.offset_left = -260.0
	_skip_label.offset_right = -16.0
	_skip_label.offset_top = -34.0
	_skip_label.offset_bottom = -8.0
	_skip_label.visible = false
	_root.add_child(_skip_label)


# --- screen effects -------------------------------------------------------

func set_skip_hint_visible(on: bool) -> void:
	_skip_hint_on = on
	_skip_label.visible = on and not is_dialogue_open


## Fades the black overlay to `alpha` (1 = fully black). Returns the tween so you can await tween.finished.
func fade_to(alpha: float, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, maxf(seconds, 0.001))
	return tw


func bars(on: bool, seconds: float = 0.7) -> Tween:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", 84.0 if on else 0.0, seconds)
	tw.tween_property(_bar_bottom, "offset_top", -84.0 if on else 0.0, seconds)
	return tw


func show_title(text: String, sub: String = "", seconds: float = 0.8) -> void:
	_title.text = text
	_title_sub.text = sub
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, seconds)
	tw.tween_property(_title_sub, "modulate:a", 1.0, seconds).set_delay(0.3)


func hide_title(seconds: float = 0.6) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 0.0, seconds)
	tw.tween_property(_title_sub, "modulate:a", 0.0, seconds)


# --- intro video ------------------------------------------------------------

## Plays a video full screen. Emits video_finished when it ends OR when the player presses any key / clicks.
func play_video(stream: VideoStream) -> void:
	if stream == null:
		video_finished.emit()
		return
	_video.stream = stream
	_video.visible = true
	is_playing_video = true
	_video.play()


func stop_video() -> void:
	if not is_playing_video:
		return
	is_playing_video = false
	_video.stop()
	_video.visible = false
	video_finished.emit()


func _on_video_finished() -> void:
	stop_video()


# --- logo -------------------------------------------------------------------

func show_logo(tex: Texture2D, fallback_text: String) -> void:
	var node: Control
	if tex != null:
		_logo.texture = tex
		_logo.visible = true
		node = _logo
	else:
		_logo_label.text = fallback_text
		_logo_label.visible = true
		node = _logo_label
	node.modulate.a = 0.0
	node.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 1.4)
	tw.tween_property(node, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_logo_ready)


func _logo_ready() -> void:
	is_waiting_at_logo = true
	_logo_hint.visible = true


# --- hint banner ------------------------------------------------------------

func show_hint(bbcode: String) -> void:
	_hint_label.text = bbcode
	_hint_panel.modulate = Color.WHITE
	_hint_panel.visible = true


func complete_hint(message: String = "DONE") -> void:
	_hint_label.text = "[color=#6cff6c]%s[/color]" % message
	_hint_panel.modulate = Color(1, 1, 1, 1)


func hide_hint() -> void:
	_hint_panel.visible = false


# --- freeze prompt ----------------------------------------------------------

func show_prompt(title: String, body: String, key_name: String) -> void:
	_prompt_title.text = title
	_prompt_body.text = body
	_prompt_key.text = "%s  [ %s ]" % [_eff.press_text, key_name]
	_dim.visible = true
	_prompt_panel.visible = true
	is_prompt_open = true


func hide_prompt() -> void:
	_dim.visible = false
	_prompt_panel.visible = false
	is_prompt_open = false


# --- dialogue ---------------------------------------------------------------

## lines = [[speaker, text], ...]   portraits = {speaker: Texture2D} (used for speakers not in the skin).
## Freezes the game while it is open and unfreezes when the last line is dismissed.
func play_dialogue(lines: Array, portraits: Dictionary = {}) -> void:
	_dialogue.extra_portraits = portraits
	_dialogue.play(lines)


func _process(_delta: float) -> void:
	_skip_label.visible = _skip_hint_on and not is_dialogue_open     # keep the corner free for the Skip / Next hints
	var t := Time.get_ticks_msec() / 1000.0
	if is_prompt_open:
		_prompt_key.pivot_offset = _prompt_key.size * 0.5
		_prompt_key.scale = Vector2.ONE * (1.0 + 0.06 * sin(t * 6.0))
	if _logo_hint.visible:
		_logo_hint.modulate.a = 0.4 + 0.6 * absf(sin(t * 2.5))


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	if is_playing_video:
		stop_video()
		get_viewport().set_input_as_handled()
	elif is_waiting_at_logo:
		is_waiting_at_logo = false
		_logo_hint.visible = false
		logo_dismissed.emit()
