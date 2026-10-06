class_name UltimateCutscene
extends CanvasLayer
## Short scene that plays BEFORE the Ultimate fires.
## Pauses the game, shows letterbox bars + a big portrait + banner text, then
## unpauses and emits `finished`. AbilityUltimate waits on that signal.
##
## Drawing order (back to front): dim > black bars > PORTRAIT > TEXT.
## So she overlaps the bars and the text sits on top of her art.
##
## Tip: press F2 any time while playing to preview this scene (no cooldown).

signal finished

## Seconds the banner stays fully visible.
@export var hold_time: float = 0.8
## Your portrait art. Leave empty to use the old Vow idle sprite.
@export var portrait: Texture2D

@export_group("Portrait layout")
## Portrait height as a multiple of the SCREEN height. 1.0 = exactly fills the screen,
## bigger = more zoomed in (the edges of the screen crop her).
@export var portrait_height: float = 1.75
## Nudge the portrait. Fractions of the screen: -0.1 = 10% left/up, 0.1 = 10% right/down.
@export var portrait_x: float = -0.03
@export var portrait_y: float = -0.03

@export_group("Text")
## Big text. Leave empty to use the ability's name ("ULTIMATE").
@export var banner_text: String = ""
## Small text under it. Leave empty to use the character's name.
@export var subtitle_text: String = ""
@export var banner_font_size: int = 110
@export var banner_color: Color = Color(0.2, 0.95, 1.0)
## Where the text sits, as a fraction of the screen. (0.5, 0.5) = dead centre.
@export var text_center: Vector2 = Vector2(0.62, 0.5)
## Press F2 during play to preview this scene.
@export var debug_preview_key: bool = true
@export_group("Voice line")
## Played the moment the Ultimate starts. Drag a .wav or .ogg here. Empty = no voice line.
@export var voice_line: AudioStream
## Volume in dB (0 = normal, -6 = quieter, +3 = louder).
@export var voice_volume_db: float = 0.0

var _root: Control
var _dim: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _banner: Label
var _sub: Label
var _portrait_rect: TextureRect
var _playing: bool = false
var _voice: AudioStreamPlayer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS  # must keep running while the game is paused
	add_to_group("ultimate_cutscene")
	# The voice line must keep playing while the game is paused for the cinematic.
	_voice = AudioStreamPlayer.new()
	_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	_voice.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	add_child(_voice)
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.anchor_right = 1.0
	_bar_top.offset_bottom = 110.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_top)

	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.offset_top = -110.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bottom)

	# Portrait: sized and placed in _layout_portrait() (it depends on the screen size).
	_portrait_rect = TextureRect.new()
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait_rect)

	# Text is added AFTER the portrait, so it draws on top of her.
	_banner = _make_label(banner_font_size, banner_color)
	_place_text(_banner, -80.0, 60.0)
	_banner.pivot_offset = Vector2(600.0, 70.0)
	_root.add_child(_banner)

	_sub = _make_label(36, Color.WHITE)
	_place_text(_sub, 60.0, 110.0)
	_root.add_child(_sub)


## Centres a 1200px-wide text box on `text_center` (fractions of the screen).
func _place_text(l: Label, top: float, bottom: float) -> void:
	l.anchor_left = text_center.x
	l.anchor_right = text_center.x
	l.anchor_top = text_center.y
	l.anchor_bottom = text_center.y
	l.offset_left = -600.0
	l.offset_right = 600.0
	l.offset_top = top
	l.offset_bottom = bottom


func _make_label(font_size: int, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Sizes the portrait from the CURRENT screen size, keeping its proportions.
func _layout_portrait() -> void:
	var tex := _portrait_rect.texture
	if tex == null or tex.get_height() <= 0:
		return
	var screen := get_viewport().get_visible_rect().size
	var h := screen.y * portrait_height
	var w := h * float(tex.get_width()) / float(tex.get_height())
	_portrait_rect.anchor_left = 0.0
	_portrait_rect.anchor_top = 0.0
	_portrait_rect.anchor_right = 0.0
	_portrait_rect.anchor_bottom = 0.0
	_portrait_rect.offset_left = screen.x * portrait_x
	_portrait_rect.offset_top = screen.y * portrait_y
	_portrait_rect.offset_right = _portrait_rect.offset_left + w
	_portrait_rect.offset_bottom = _portrait_rect.offset_top + h


func _unhandled_input(event: InputEvent) -> void:
	if not debug_preview_key or _playing or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		play("ULTIMATE", "VOW")


func play(ability_name: String, character_name: String) -> void:
	if _playing:
		return
	_playing = true
	get_tree().paused = true

	_banner.text = banner_text if banner_text != "" else ability_name.to_upper()
	_sub.text = subtitle_text if subtitle_text != "" else character_name.to_upper()
	if portrait != null:
		_portrait_rect.texture = portrait
	else:
		_portrait_rect.texture = load("res://player/vow/idle/idle_01.png") as Texture2D
	_layout_portrait()
	if voice_line != null:
		_voice.stream = voice_line
		_voice.volume_db = voice_volume_db
		_voice.play()

	for n in [_dim, _bar_top, _bar_bottom, _banner, _sub, _portrait_rect]:
		n.modulate.a = 0.0
	_root.visible = true

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(_bar_top, "modulate:a", 1.0, 0.2)
	tw.tween_property(_bar_bottom, "modulate:a", 1.0, 0.2)
	tw.tween_property(_portrait_rect, "modulate:a", 1.0, 0.3).set_delay(0.1)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2).set_delay(0.1)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.3).from(Vector2(2.4, 2.4)).set_delay(0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.25).set_delay(0.3)
	tw.chain().tween_interval(hold_time)
	tw.chain().tween_callback(_fade_out)


func _fade_out() -> void:
	var tw := create_tween().set_parallel(true)
	for n in [_dim, _bar_top, _bar_bottom, _banner, _sub, _portrait_rect]:
		tw.tween_property(n, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(_finish)


func _finish() -> void:
	_root.visible = false
	_playing = false
	get_tree().paused = false
	finished.emit()
