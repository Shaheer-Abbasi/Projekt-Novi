extends BaseButton
## Level select button. Works on a normal Button OR a TextureButton
## (both are kinds of BaseButton, which is why this script can go on either).
##
## HOVER PREVIEW: give a button a "Preview Image" and that picture fades in on the
## side of the screen while the button is hovered (or selected with keyboard / controller).
## It is shown in a TextureRect named "LevelPreview". If your scene has no node with that
## name, one is created automatically on the right edge. To place it yourself, add a
## TextureRect called LevelPreview to the scene and put it wherever you like.

## Which level this button opens. 0 = automatic: its position among its siblings
## (1st button = level 1, 2nd = level 2, ...). Set a number here to choose it yourself.
@export var level: int = 0

## Picture shown on the side while this button is hovered. Leave empty for none.
@export var preview_image: Texture2D

var is_unlocked: bool = false


func _ready() -> void:
	if level <= 0:
		level = get_index() + 1
	_show_number()
	is_unlocked = level <= LevelManager.level_unlocked
	modulate.a = 1.0 if is_unlocked else 0.5

	var existing := _find_preview()
	if existing != null:
		existing.modulate.a = 0.0                      # hidden until a button is hovered
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never steals the mouse from the buttons
	mouse_entered.connect(_show_preview)
	mouse_exited.connect(_hide_preview)
	focus_entered.connect(_show_preview)
	focus_exited.connect(_hide_preview)


## A normal Button shows the number as its text. A TextureButton can't show text,
## so it fills in a Label child instead (add a Label under the TextureButton if you want a number).
func _show_number() -> void:
	if "text" in self:
		set("text", str(level))
	else:
		for c in get_children():
			if c is Label:
				c.text = str(level)


func _pressed() -> void:
	if is_unlocked:
		LevelManager.current_level = level
		get_tree().call_deferred("change_scene_to_file", LevelManager._load_level(level))


# --- hover preview ----------------------------------------------------------

func _preview_root() -> Node:
	return owner if owner != null else get_tree().current_scene


func _find_preview() -> TextureRect:
	var r := _preview_root()
	if r == null:
		return null
	return r.find_child("LevelPreview", true, false) as TextureRect


func _show_preview() -> void:
	if preview_image == null:
		return
	var p := _find_preview()
	if p == null:
		p = _make_preview()
	if p == null:
		return
	p.texture = preview_image
	if p.has_meta("auto_layout"):
		_fit_auto_preview(p)
	p.set_meta("shown_by", self)
	_fade(p, 1.0, 0.15)


func _hide_preview() -> void:
	var p := _find_preview()
	# only hide it if THIS button is the one showing it (moving between buttons must not flicker)
	if p != null and p.get_meta("shown_by", null) == self:
		p.remove_meta("shown_by")
		_fade(p, 0.0, 0.12)


func _fade(p: Control, to: float, seconds: float) -> void:
	var old = p.get_meta("fade_tween", null)
	if old is Tween and old.is_valid():
		old.kill()
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", to, seconds)
	p.set_meta("fade_tween", tw)


## Used only when your scene has no node called LevelPreview: a full-height picture on the right edge.
func _make_preview() -> TextureRect:
	var r := _preview_root()
	if r == null:
		return null
	var t := TextureRect.new()
	t.name = "LevelPreview"
	t.anchor_left = 1.0
	t.anchor_right = 1.0
	t.anchor_top = 0.0
	t.anchor_bottom = 1.0
	t.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = 0.0
	t.set_meta("auto_layout", true)
	r.add_child(t)
	return t


func _fit_auto_preview(p: TextureRect) -> void:
	var tex := p.texture
	if tex == null or tex.get_height() <= 0:
		return
	var h := get_viewport().get_visible_rect().size.y
	p.offset_right = 0.0
	p.offset_left = -h * float(tex.get_width()) / float(tex.get_height())
