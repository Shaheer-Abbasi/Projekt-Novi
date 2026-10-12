class_name StoryNotice
extends CanvasLayer
## The on-screen message for story levels, like "Defeat all the enemies to move on!"
## with a live counter under it ("Tanks 2/5   Grunts 1/3"), plus a big centered text
## for moments like LEVEL COMPLETE. StoryEncounter and StoryLevel create and drive it.
## Restyle the box with a UISkin ("Banner Box").

## Set before adding to the scene to restyle it.
var skin: UISkin

var _eff: UISkin
var _panel: PanelContainer
var _message: RichTextLabel
var _progress: Label
var _big: Label
var _msg_timer: Timer
var _big_timer: Timer
var _has_message: bool = false
var _has_progress: bool = false


func _ready() -> void:
	layer = 60
	add_to_group("story_notice")
	_eff = skin if skin != null else UISkin.new()

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _eff.box_or_default(_eff.banner_box, 14))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -_eff.banner_width * 0.5
	_panel.offset_right = _eff.banner_width * 0.5
	_panel.offset_top = _eff.banner_top
	_panel.offset_bottom = _eff.banner_top
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)

	_message = RichTextLabel.new()
	_message.bbcode_enabled = true
	_message.scroll_active = false
	_message.fit_content = true
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size = Vector2(maxf(_eff.banner_width - 60.0, 100.0), 0)
	_message.add_theme_font_size_override("normal_font_size", _eff.banner_font_size)
	_message.add_theme_font_size_override("bold_font_size", _eff.banner_font_size)
	_message.add_theme_color_override("default_color", _eff.text_color)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.visible = false
	col.add_child(_message)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", int(_eff.banner_font_size * 0.85))
	_progress.add_theme_color_override("font_color", _eff.default_name_color)
	_progress.add_theme_color_override("font_outline_color", Color.BLACK)
	_progress.add_theme_constant_override("outline_size", 6)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.visible = false
	col.add_child(_progress)
	if _eff.font != null:
		_message.add_theme_font_override("normal_font", _eff.font)
		_progress.add_theme_font_override("font", _eff.font)

	_big = Label.new()
	_big.anchor_right = 1.0
	_big.anchor_top = 0.4
	_big.anchor_bottom = 0.4
	_big.offset_top = -80.0
	_big.offset_bottom = 80.0
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_font_size_override("font_size", 110)
	_big.add_theme_color_override("font_outline_color", Color.BLACK)
	_big.add_theme_constant_override("outline_size", 14)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.modulate.a = 0.0
	root.add_child(_big)

	_msg_timer = Timer.new()
	_msg_timer.one_shot = true
	_msg_timer.timeout.connect(hide_message)
	add_child(_msg_timer)
	_big_timer = Timer.new()
	_big_timer.one_shot = true
	_big_timer.timeout.connect(_hide_big)
	add_child(_big_timer)


## Shows a message at the top. seconds = 0 keeps it until you call hide_message().
func show_message(text: String, seconds: float = 0.0) -> void:
	_message.text = text
	_has_message = not text.strip_edges().is_empty()
	_message.visible = _has_message
	if seconds > 0.0 and _has_message:
		_msg_timer.start(seconds)
	else:
		_msg_timer.stop()
	_refresh()


func hide_message() -> void:
	_has_message = false
	_message.visible = false
	_refresh()


## The live counter line under the message. Empty text hides it.
func set_progress(text: String) -> void:
	_has_progress = not text.strip_edges().is_empty()
	_progress.text = text
	_progress.visible = _has_progress
	_refresh()


func clear_progress() -> void:
	set_progress("")


## Big centered text (LEVEL COMPLETE...). Fades in, stays `seconds`, fades out.
func show_big(text: String, seconds: float = 3.0, color: Color = Color.WHITE) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_big, "modulate:a", 1.0, 0.4)
	if seconds > 0.0:
		_big_timer.start(maxf(seconds, 0.5))


func _hide_big() -> void:
	var tw := create_tween()
	tw.tween_property(_big, "modulate:a", 0.0, 0.5)


func _refresh() -> void:
	var show := _has_message or _has_progress
	if show and not _panel.visible:
		_panel.modulate.a = 0.0
		_panel.visible = true
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	elif not show:
		_panel.visible = false
