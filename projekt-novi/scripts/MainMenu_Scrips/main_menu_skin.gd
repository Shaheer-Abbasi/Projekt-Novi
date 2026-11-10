class_name MainMenuSkin
extends Node
## Restyles the main menu like your mockup: the night-city background, the slanted neon panel, the logo, and START / OPTIONS / EXIT
## with a selection bar that fades in, a scale-up on hover, and a press effect.
##
## Add it as a child of the MainMenu node (the one with main_menu.gd) and drag your pictures onto its fields.
## It does NOT change main_menu.gd: pressing an option "presses" your existing Start_button / Option_button / Exit_button, so everything
## they already do (the level select page, the options page, quitting) keeps working exactly as before.

## Fires when an option is chosen (0 = the first one), a moment before the old button is pressed.
signal option_chosen(index: int)

@export var enabled: bool = true:
	set(v):
		enabled = v
		if _ui != null:
			_apply_enabled()
## Hide the old video background and the old texture buttons (they stay in the scene and keep working underneath).
@export var hide_old_background: bool = true
## Other OLD nodes of your menu scene to hide so they do not cover the new menu (your earlier Background and logo pictures, for example). Names of nodes directly under MainMenu.
@export var hide_old_nodes: PackedStringArray = PackedStringArray(["Background", "NewLogo"])

@export_group("Your pictures")
@export var background: Texture2D
@export var logo: Texture2D
## The part of the logo picture to use, in the picture's own pixels. Your logo file has a few stray pixels far to the right of the artwork;
## this leaves them out. Set it to 0, 0, 0, 0 to use the whole picture.
@export var logo_region: Rect2 = Rect2(0.0, 0.0, 750.0, 272.0)
## The bar that appears behind the selected option.
@export var selection_bar: Texture2D
## Optional: your own picture for the whole slanted panel (a transparent 1920 x 1080 picture). It replaces the one drawn here.
@export var panel_texture: Texture2D

@export_group("Options")
## The words shown, top to bottom.
@export var option_labels: PackedStringArray = PackedStringArray(["START", "OPTIONS", "EXIT"])
## The names of your OLD buttons that each option presses, in the same order. Add a name here and a word above to add an option.
## If a name is not found, the old buttons under MainButtons are used in the order they appear (first = START, second = OPTIONS, third = EXIT).
@export var option_buttons: PackedStringArray = PackedStringArray(["Start_button", "Option_button", "Exit_button"])
## The names of your pages (level select, options). The menu fades away while any of them is open, even if your script leaves the main buttons showing.
@export var subpage_nodes: PackedStringArray = PackedStringArray(["LevelSelect", "Options Panel"])
## Highlight the first option when the menu opens (for keyboard and controller players).
@export var select_first_on_open: bool = true

@export_group("Layout (pixels on a 1920 x 1080 canvas, like your mockup)")
## Where the logo picture's top-left goes.
@export var logo_position: Vector2 = Vector2(117.0, 161.0)
@export var logo_scale: float = 0.71
## The top-left corner of the FIRST option's selection bar.
@export var first_option_position: Vector2 = Vector2(227.0, 503.0)
## How far each next option is from the one before (the sideways part gives the staggered look that follows the panel's slant).
@export var option_step: Vector2 = Vector2(41.5, 123.5)
## Space between the bar's left edge and the first letter.
@export var text_inset: float = 24.0

@export_group("Slanted panel (drawn in code)")
@export var show_panel: bool = true
## Where the panel's right edge is at the top of the screen, and how far it leans to the right by the bottom.
@export var panel_top_right_x: float = 566.0
@export var panel_slant: float = 170.0
@export var panel_color: Color = Color(0.02, 0.02, 0.05, 0.93)
@export var edge_glow_color: Color = Color(0.10, 0.30, 0.80, 0.55)
@export var edge_glow_width: float = 120.0
@export var neon_color: Color = Color(0.25, 0.95, 1.0)
## Where the cyan neon line starts at the top of the screen.
@export var neon_top_x: float = 69.0
@export var strip_color: Color = Color(0.16, 0.38, 0.69, 0.6)

@export_group("Text")
## Drag your own font here. Without one, the engine's default font is used.
@export var font: Font
@export var font_size: int = 56
## Extra space between letters (pixels on the 1920 x 1080 canvas).
@export var letter_spacing: int = 16
## Makes the default font heavier. Leave at 0 if you use your own bold font.
@export var font_embolden: float = 0.4
@export var text_color: Color = Color.WHITE
## Nudge the words (pixels on the 1920 x 1080 canvas). Capital letters sit low in a line of text, so the default lifts them a little; change it if you use your own font.
@export var text_offset: Vector2 = Vector2(-5.0, -9.0)
## 1 = the options that are not selected look the same. Lower (for example 0.7) to dim them.
@export_range(0.0, 1.0) var unselected_alpha: float = 1.0

@export_group("Feedback")
## How much bigger the selected option gets (1 = no change).
@export var hover_scale: float = 1.08
@export var scale_in_time: float = 0.18
@export var scale_out_time: float = 0.22
## The selection bar fades in and out over these times.
@export var fade_in_time: float = 0.18
@export var fade_out_time: float = 0.28
## The bar also slides in from the left by this many pixels as it appears.
@export var bar_slide: float = 26.0
## When pressed, the option shrinks to this fraction of its size for a moment.
@export var press_scale: float = 0.95
## How long the press effect plays before the old button is actually pressed.
@export var activate_delay: float = 0.16
## How bright the bar flashes when you choose an option (0 = no flash).
@export var flash_strength: float = 0.9

@export_group("Sounds")
@export var hover_sound: AudioStream
@export var click_sound: AudioStream
@export var sound_bus: StringName = &"Master"

@export_group("Opening")
## How long the panel, logo and options take to slide in when the menu appears (0 = instantly).
@export var intro_seconds: float = 0.7
## How long the whole menu takes to fade when you go to another page (options, level select) and back.
@export var page_fade_seconds: float = 0.25

const DESIGN_H := 1080.0

var _ui: Control
var _bg: TextureRect
var _menu: Control
var _panel: PanelArt
var _logo: TextureRect
var _options: Array[MenuOption] = []
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _old_main: Control
var _saved_old: Dictionary = {}
var _old_videos: Array = []
var _old_hidden: Dictionary = {}
var _selected: int = -1
var _busy: bool = false
var _mouse_mode: bool = false
var _page_shown: bool = false
var _first_show: bool = true
var _page_tw: Tween
var _k: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parent := get_parent()
	var main = parent.get("main_buttons") if parent != null else null            # main_menu.gd's own reference to the old buttons
	_old_main = (main as Control) if main is Control else (parent.find_child("MainButtons", true, false) as Control if parent != null else null)
	if parent != null:
		for v in parent.find_children("*", "VideoStreamPlayer", false, false):
			_old_videos.append(v)
	_build()
	# The drawing must be a DIRECT child of the menu: a drawn node under a plain Node (like this one) is attached to the whole screen and ends up
	# above everything, which would hide your level select and options pages. As a first child of the menu it is drawn in order, under them.
	if parent != null:
		parent.add_child.call_deferred(_ui)
		parent.move_child.call_deferred(_ui, 0)
	else:
		add_child.call_deferred(_ui)
	_finish_setup.call_deferred()


func _finish_setup() -> void:
	_apply_enabled()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	_restore_old()
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()


func _build() -> void:
	_ui = Control.new()
	_ui.name = "MenuSkinRoot"
	# It is pinned to the screen's corner in _layout(), whatever the menu's own position is.
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = TextureRect.new()
	_bg.name = "SkinBackground"
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bg)
	_menu = Control.new()
	_menu.name = "MenuPage"
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_menu)
	_panel = PanelArt.new(self)
	_panel.name = "Panel"
	_menu.add_child(_panel)
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_SCALE
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_logo)
	for i in range(option_labels.size()):
		var o := MenuOption.new(i, self)
		o.name = "Option%d" % (i + 1)
		_menu.add_child(o)
		o.hovered.connect(_on_hover)
		o.unhovered.connect(_on_unhover)
		o.pressed_down.connect(_on_press_down)
		o.released.connect(_on_released)
		o.clicked.connect(_on_clicked)
		_options.append(o)
	_hover_player = AudioStreamPlayer.new()
	_click_player = AudioStreamPlayer.new()
	for p in [_hover_player, _click_player]:
		p.bus = sound_bus
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
	_menu.visible = false


func _apply_enabled() -> void:
	_ui.visible = enabled
	if enabled:
		_hide_old()
	else:
		_restore_old()


## Hides the old video and makes the old buttons invisible and un-clickable (they are still pressed by this menu).
func _hide_old() -> void:
	if not hide_old_background:
		return
	for v in _old_videos:
		if is_instance_valid(v):
			(v as CanvasItem).visible = false
			if v is VideoStreamPlayer:
				(v as VideoStreamPlayer).stop()
	var parent := get_parent()
	if parent != null:
		for n in hide_old_nodes:
			var node := parent.get_node_or_null(NodePath(n))
			if node is CanvasItem and node != self and not _old_hidden.has(node):
				_old_hidden[node] = (node as CanvasItem).visible
				(node as CanvasItem).visible = false
	if _old_main != null and is_instance_valid(_old_main):
		if not _saved_old.has(_old_main):
			_saved_old[_old_main] = [_old_main.modulate, _old_main.mouse_filter]
		_old_main.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_old_main.mouse_filter = Control.MOUSE_FILTER_IGNORE          # the old container sits above the new menu and would swallow the mouse
		for c in _old_main.get_children():
			if c is Control:
				if not _saved_old.has(c):
					_saved_old[c] = [(c as Control).mouse_filter, (c as Control).focus_mode]
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
				(c as Control).focus_mode = Control.FOCUS_NONE


func _restore_old() -> void:
	for n in _old_hidden.keys():
		if is_instance_valid(n):
			(n as CanvasItem).visible = _old_hidden[n]
	_old_hidden.clear()
	for v in _old_videos:
		if is_instance_valid(v):
			(v as CanvasItem).visible = true
			if v is VideoStreamPlayer and not (v as VideoStreamPlayer).is_playing():
				(v as VideoStreamPlayer).play()
	for n in _saved_old.keys():
		if not is_instance_valid(n):
			continue
		var s: Array = _saved_old[n]
		if n == _old_main:
			_old_main.modulate = s[0]
			_old_main.mouse_filter = s[1]
		else:
			(n as Control).mouse_filter = s[0]
			(n as Control).focus_mode = s[1]
	_saved_old.clear()


## Sizes and places everything for the current window.
func _layout() -> void:
	if _ui == null or not _ui.is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	_k = vs.y / DESIGN_H
	_ui.size = vs
	_pin_to_screen()
	_bg.texture = background
	_bg.position = Vector2.ZERO
	_bg.size = vs
	_menu.position = Vector2.ZERO
	_menu.size = vs
	_panel.k = _k
	_panel.position = Vector2.ZERO
	_panel.size = vs
	_panel.visible = show_panel
	_panel.queue_redraw()
	if logo != null:
		if logo_region.size.x > 0.0 and logo_region.size.y > 0.0:
			var at := AtlasTexture.new()
			at.atlas = logo
			at.region = logo_region
			_logo.texture = at
			_logo.size = logo_region.size * logo_scale * _k
		else:
			_logo.texture = logo
			_logo.size = logo.get_size() * logo_scale * _k
	else:
		_logo.texture = null
		_logo.size = Vector2.ZERO
	_logo.position = logo_position * _k
	var fv := FontVariation.new()
	fv.base_font = font if font != null else ThemeDB.fallback_font
	fv.spacing_glyph = int(round(float(letter_spacing) * _k))
	if font == null or font_embolden > 0.0:
		fv.variation_embolden = font_embolden
	for i in range(_options.size()):
		var o := _options[i]
		o.k = _k
		o.base_position = (first_option_position + option_step * float(i)) * _k
		o.setup(selection_bar, option_labels[i], fv)


## The menu root may be offset or odd-sized (yours is), so the skin pins itself to the screen's top-left corner.
func _pin_to_screen() -> void:
	if _ui == null or not _ui.is_inside_tree():
		return
	var parent := get_parent()
	if parent is CanvasItem:
		var gs := (parent as CanvasItem).get_global_transform().get_scale()
		_ui.scale = Vector2(1.0 / maxf(gs.x, 0.0001), 1.0 / maxf(gs.y, 0.0001))
	_ui.global_position = Vector2.ZERO


func _process(_delta: float) -> void:
	if not enabled or _ui == null or not _ui.is_inside_tree():
		return
	if _ui.global_position.length_squared() > 0.25:
		_pin_to_screen()
	var shown := true
	if _old_main != null and is_instance_valid(_old_main):
		shown = _old_main.is_visible_in_tree()
	if shown and _subpage_open():
		shown = false
	if shown != _page_shown:
		_set_page(shown)


func _subpage_open() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	for n in subpage_nodes:
		var node := parent.get_node_or_null(NodePath(n))
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
			return true
	return false


## The menu page appears when your old main buttons are shown, and fades away when another page (options, level select) takes over.
func _set_page(shown: bool) -> void:
	_page_shown = shown
	if _page_tw != null and _page_tw.is_valid():
		_page_tw.kill()
	if shown:
		_menu.visible = true
		_busy = false
		_selected = -1
		for o in _options:
			o.reset_look()
		var first := _first_show
		_first_show = false
		var total := intro_seconds if first else page_fade_seconds
		_menu.modulate.a = 0.0 if total > 0.0 else 1.0
		_page_tw = create_tween().set_parallel(true)
		if total > 0.0:
			_page_tw.tween_property(_menu, "modulate:a", 1.0, minf(total, 0.4 if first else page_fade_seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_play_intro(total, first)
		_page_tw.chain().tween_callback(_after_intro)
	else:
		_page_tw = create_tween()
		_page_tw.tween_property(_menu, "modulate:a", 0.0, maxf(page_fade_seconds * 0.6, 0.01))
		_page_tw.tween_callback(func(): _menu.visible = false)


func _play_intro(total: float, first: bool) -> void:
	var slide := (110.0 if first else 40.0) * _k
	_panel.position.x = -slide
	_page_tw.tween_property(_panel, "position:x", 0.0, total).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var lp := logo_position * _k
	_logo.position = lp + Vector2(0.0, -22.0 * _k)
	_page_tw.tween_property(_logo, "position", lp, total * 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in range(_options.size()):
		var o := _options[i]
		var delay := total * 0.28 + float(i) * total * 0.12
		o.modulate.a = 0.0
		o.position = o.base_position + Vector2(-70.0 * _k, 0.0)
		_page_tw.tween_property(o, "position", o.base_position, total * 0.55).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_page_tw.tween_property(o, "modulate:a", 1.0, total * 0.45).set_delay(delay)


func _after_intro() -> void:
	for o in _options:
		o.position = o.base_position
		o.modulate.a = 1.0
	if select_first_on_open and not _mouse_mode and _selected < 0 and not _options.is_empty():
		_select(0, false)


func _active() -> bool:
	return enabled and _page_shown and _menu.visible and not _busy and not _options.is_empty()


# ----------------------------------------------------------------------------- selection

func _select(i: int, sound: bool = true) -> void:
	if i == _selected:
		return
	if _selected >= 0 and _selected < _options.size():
		_options[_selected].set_selected(false)
	_selected = i
	if i >= 0 and i < _options.size():
		_options[i].set_selected(true)
		if sound:
			_play(_hover_player, hover_sound)


func _on_hover(i: int) -> void:
	if _active():
		_select(i)


func _on_unhover(i: int) -> void:
	# with the mouse, the highlight leaves when the pointer leaves; with keys or a controller it stays put
	if _active() and _mouse_mode and _selected == i:
		_select(-1)


func _on_press_down(i: int) -> void:
	if _active():
		_select(i, false)
		_options[i].press(true)


func _on_released(i: int) -> void:
	if i >= 0 and i < _options.size():
		_options[i].press(false)


func _on_clicked(i: int) -> void:
	if _active():
		_activate(i, true)


func _activate(i: int, from_mouse: bool = false) -> void:
	if _busy or i < 0 or i >= _options.size():
		return
	_busy = true
	_select(i, false)
	if not from_mouse:
		_options[i].press(true)                                  # a key or button press dips the option too (the mouse already did on button-down)
	_options[i].flash()
	_play(_click_player, click_sound)
	option_chosen.emit(i)
	var half := maxf(activate_delay * 0.5, 0.0)
	await get_tree().create_timer(half).timeout
	if i < _options.size():
		_options[i].press(false)
	await get_tree().create_timer(half).timeout
	_busy = false
	_press_old_button(i)


func _press_old_button(i: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var b: Node = null
	if i < option_buttons.size() and option_buttons[i] != "":
		b = parent.find_child(option_buttons[i], true, false)
	var found: PackedStringArray = PackedStringArray()
	if _old_main != null and is_instance_valid(_old_main):
		var in_order: Array = []
		for c in _old_main.get_children():
			if c is BaseButton:
				in_order.append(c)
				found.append(String(c.name))
		if b == null and i < in_order.size():
			b = in_order[i]                                     # not found by name: use the old buttons in the order they appear
	if b is BaseButton:
		(b as BaseButton).pressed.emit()
	elif b != null and b.has_signal("pressed"):
		b.emit_signal("pressed")
	else:
		push_warning("MainMenuSkin: option %d ('%s') could not find an old button to press. It looked for '%s'. The buttons under your main buttons are: %s. Put their names, in order, in 'Option Buttons' on the MainMenuSkin node, or connect the 'option_chosen' signal." % [i + 1, option_labels[i] if i < option_labels.size() else "?", option_buttons[i] if i < option_buttons.size() else "(no name)", str(found)])


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null or player == null:
		return
	player.stream = stream
	player.play()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_mode = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_mouse_mode = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_mouse_mode = false


func _unhandled_input(event: InputEvent) -> void:
	if not _active():
		return
	if event.is_action_pressed("ui_down"):
		_select(0 if _selected < 0 else (_selected + 1) % _options.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_select(_options.size() - 1 if _selected < 0 else (_selected - 1 + _options.size()) % _options.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _selected >= 0:
		_activate(_selected)
		get_viewport().set_input_as_handled()


# ----------------------------------------------------------------------------- one option: the word plus its selection bar

class MenuOption extends Control:
	signal hovered(index: int)
	signal unhovered(index: int)
	signal pressed_down(index: int)
	signal released(index: int)
	signal clicked(index: int)

	var index: int = 0
	var skin: MainMenuSkin
	var k: float = 1.0
	var base_position: Vector2 = Vector2.ZERO
	var bar: TextureRect
	var label: Label
	var is_selected: bool = false
	var _hover: bool = false
	var _holding: bool = false
	var _tw: Tween                                               # the bar and the letters (fade, slide)
	var _tw_scale: Tween                                         # the size: ONE tween owns it, so a press during a hover never fights it
	var _tw_flash: Tween

	func _init(i: int, s: MainMenuSkin) -> void:
		index = i
		skin = s
		mouse_filter = Control.MOUSE_FILTER_STOP
		bar = TextureRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar.stretch_mode = TextureRect.STRETCH_SCALE
		bar.modulate.a = 0.0
		add_child(bar)
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(label)
		mouse_entered.connect(func():
			_hover = true
			hovered.emit(index))
		mouse_exited.connect(func():
			_hover = false
			if _holding:
				_holding = false
				released.emit(index)
			unhovered.emit(index))

	func setup(bar_tex: Texture2D, text: String, f: Font) -> void:
		bar.texture = bar_tex
		var sz := (bar_tex.get_size() * k) if bar_tex != null else Vector2(375.0, 38.0)
		size = sz
		position = base_position
		pivot_offset = Vector2(0.0, sz.y * 0.5)                  # grows to the right, so the words stay lined up on the left
		bar.size = sz
		label.text = text
		label.position = Vector2(skin.text_inset * k, 0.0) + skin.text_offset * k
		label.size = Vector2(sz.x - skin.text_inset * k, sz.y)
		label.add_theme_font_override("font", f)
		label.add_theme_font_size_override("font_size", int(round(float(skin.font_size) * k)))
		label.add_theme_color_override("font_color", skin.text_color)
		reset_look()

	## The un-selected look, at once (no animation).
	func reset_look() -> void:
		for t in [_tw, _tw_scale, _tw_flash]:
			if t != null and t.is_valid():
				t.kill()
		is_selected = false
		_holding = false
		scale = Vector2.ONE
		bar.modulate.a = 0.0
		bar.self_modulate = Color.WHITE
		bar.position = Vector2(-skin.bar_slide * k, 0.0)
		label.modulate.a = skin.unselected_alpha

	## Grows or shrinks to a size, replacing whatever size animation was running.
	func _scale_to(target: float, seconds: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
		if _tw_scale != null and _tw_scale.is_valid():
			_tw_scale.kill()
		_tw_scale = create_tween()
		_tw_scale.tween_property(self, "scale", Vector2.ONE * target, seconds).set_trans(trans).set_ease(ease_type)

	func set_selected(on: bool) -> void:
		is_selected = on
		if _tw != null and _tw.is_valid():
			_tw.kill()
		_tw = create_tween().set_parallel(true)
		if on:
			_scale_to(skin.hover_scale * (skin.press_scale if _holding else 1.0), skin.scale_in_time, Tween.TRANS_BACK, Tween.EASE_OUT)
			_tw.tween_property(bar, "modulate:a", 1.0, skin.fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tw.tween_property(bar, "position:x", 0.0, skin.fade_in_time * 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tw.tween_property(label, "modulate:a", 1.0, skin.fade_in_time)
		else:
			_scale_to(1.0, skin.scale_out_time, Tween.TRANS_CUBIC, Tween.EASE_OUT)
			_tw.tween_property(bar, "modulate:a", 0.0, skin.fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tw.tween_property(bar, "position:x", -skin.bar_slide * 0.5 * k, skin.fade_out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tw.tween_property(label, "modulate:a", skin.unselected_alpha, skin.fade_out_time)

	## Pushed down (true) or let go (false).
	func press(down: bool) -> void:
		var target := skin.hover_scale * (skin.press_scale if down else 1.0)
		if not is_selected and not down:
			target = 1.0
		_scale_to(target, 0.06 if down else 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT)

	## The bright flash when the option is chosen.
	func flash() -> void:
		if skin.flash_strength <= 0.0:
			return
		if _tw_flash != null and _tw_flash.is_valid():
			_tw_flash.kill()
		var s := skin.flash_strength
		bar.self_modulate = Color(1.0 + s, 1.0 + s, 1.0 + s, 1.0)
		_tw_flash = create_tween()
		_tw_flash.tween_property(bar, "self_modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if (event as InputEventMouseButton).pressed:
				_holding = true
				pressed_down.emit(index)
			else:
				var was := _holding
				_holding = false
				released.emit(index)
				if was and _hover:
					clicked.emit(index)


# ----------------------------------------------------------------------------- the slanted neon panel

class PanelArt extends Control:
	var skin: MainMenuSkin
	var k: float = 1.0

	func _init(s: MainMenuSkin) -> void:
		skin = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if skin.panel_texture != null:
			draw_texture_rect(skin.panel_texture, Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0) * k), false)
			return
		var h := 1080.0 * k
		var sl := skin.panel_slant * k
		var xr := skin.panel_top_right_x * k
		# the dark glass: it starts at the neon line and gets more see-through toward the right, so the city shows through a little
		var nx := skin.neon_top_x * k
		var pc := skin.panel_color
		var c_left := pc
		var c_right := Color(pc.r, pc.g, pc.b, pc.a * 0.78)
		draw_polygon(PackedVector2Array([Vector2(nx - 6.0 * k, 0.0), Vector2(xr, 0.0), Vector2(xr + sl, h), Vector2(nx - 6.0 * k + sl, h)]), PackedColorArray([c_left, c_right, c_right, c_left]))
		# only a faint tint to the left of the neon line (the buildings behind show through there)
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(nx - 6.0 * k, 0.0), Vector2(nx - 6.0 * k + sl, h), Vector2(0.0, h)]), Color(pc.r, pc.g, pc.b, 0.4))
		# the blue glow that builds up toward the right edge
		var gw := skin.edge_glow_width * k
		var c1 := skin.edge_glow_color
		var c0 := Color(c1.r, c1.g, c1.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(xr - gw, 0.0), Vector2(xr, 0.0), Vector2(xr + sl, h), Vector2(xr + sl - gw, h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_line(Vector2(xr, 0.0), Vector2(xr + sl, h), Color(minf(c1.r + 0.25, 1.0), minf(c1.g + 0.25, 1.0), 1.0, 0.85), maxf(2.0 * k, 1.0))
		# the steel-blue strip, the dark teal band, and the neon line (all lean the same way as the edge)
		_slanted_band(nx - 44.0 * k, 34.0 * k, sl, h, skin.strip_color)
		_slanted_band(nx + 8.0 * k, 30.0 * k, sl, h, Color(0.0, 0.2, 0.42, 0.55))
		var nc := skin.neon_color
		for g in [[16.0, 0.07], [9.0, 0.14], [5.0, 0.28]]:
			draw_line(Vector2(nx, 0.0), Vector2(nx + sl, h), Color(nc.r, nc.g, nc.b, g[1]), g[0] * k)
		draw_line(Vector2(nx, 0.0), Vector2(nx + sl, h), nc, maxf(2.5 * k, 1.0))

	func _slanted_band(x_top: float, width: float, slant: float, h: float, c: Color) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(x_top, 0.0), Vector2(x_top + width, 0.0), Vector2(x_top + width + slant, h), Vector2(x_top + slant, h)]), c)
