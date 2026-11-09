class_name RoundIntro
extends Node
## The ROUND START title sequence. Drop this node into a level (your regular playtest scene, or a story level) and, when the scene starts:
##   1. the game FREEZES and shrinks a little, with black borders and a slight dim,
##   2. your wide BANNER slides in from the left, holds, and fades,
##   3. your tall PORTRAIT slides in, and the lines  MODE / MAP / USER  slide out beside it,
##   4. they fade, and  START  grows in the middle of the screen,
##   5. the game zooms up to full size, the screen FLASHES, and the round begins.
## Everything is drawn here: you only need to drag in your two pictures and fill in the words.
##
## Measured from the reference video (1920 x 1080); on any other screen size everything scales to match.

## The moment the game un-freezes (at the peak of the flash). Start your spawns / timers from this if they should not begin before it.
signal round_started
## Everything is cleaned up and the game is back to normal.
signal finished

## Plays by itself when the scene starts. Turn off and call play() yourself if you want to choose the moment.
@export var play_on_ready: bool = true
## Any key or click jumps to the zoom and the flash (after the first half second).
@export var skippable: bool = true

@export_group("The words")
@export var mode_name: String = "SURVIVAL"
@export var stage_name: String = "CORPORATE HQ"
## The character's name as shown on the USER line. Empty = the player's own character name.
@export var character_name: String = ""
@export var mode_label: String = "MODE:"
@export var stage_label: String = "MAP:"
@export var character_label: String = "USER:"
@export var start_text: String = "START"

@export_group("The pictures")
## The wide banner that slides in first (yours is 2000 x 300). Empty = skipped.
@export var banner: Texture2D
## The tall portrait (yours is 400 x 1100). Empty = skipped.
@export var portrait: Texture2D

@export_group("The look")
## The font for all the words. Empty = Godot's default font made bold. Drag in your own .ttf / .otf for the real look.
@export var font: Font
## Size of the MODE and MAP lines (in pixels on a 1080-high screen).
@export var small_size: int = 66
## Size of the USER line.
@export var big_size: int = 100
## Size of START.
@export var start_size: int = 230
@export var text_color: Color = Color(1.0, 1.0, 1.0)
## The colour of the outline around the letters.
@export var outline_color: Color = Color(0.65, 0.61, 0.06)
## Outline thickness of the three info lines (Godot's outline value: the visible edge is about a third of it).
@export var outline_size: int = 20
## Outline thickness of START.
@export var start_outline_size: int = 14
## How big the game is while the titles play (0.92 = 92%, with black borders around it).
@export_range(0.7, 1.0, 0.01) var game_scale: float = 0.92
## How dark the game is behind the titles (0 = not at all).
@export_range(0.0, 0.9, 0.01) var dim_strength: float = 0.46
## The colour behind the picture's edges, shown around the shrunken game.
@export var border_color: Color = Color.BLACK

@export_group("Timing")
## 1.0 = the speed of the reference video (about 5 seconds). 2.0 = twice as fast.
@export_range(0.5, 3.0, 0.05) var speed: float = 1.0
## How long the portrait and the three lines stay on screen once they are all in (seconds).
@export var info_hold_seconds: float = 1.2
## How long START stays (seconds, not counting its grow-in and fade-out).
@export var start_hold_seconds: float = 0.8

@export_group("Sounds (optional)")
## A whoosh for the banner, the portrait and each line sliding in.
@export var slide_sound: AudioStream
## When START appears.
@export var start_sound: AudioStream
## At the flash.
@export var flash_sound: AudioStream
@export var sound_volume_db: float = 0.0

# ---- the timeline, in "design" seconds (the reference video's own clock) ----
const BANNER_IN := 0.5                       # the slide (it flickers while it arrives)
const BANNER_FADE_AT := 0.85
const BANNER_OUT := 0.15
const BANNER_FLICKER: Array = [0.27, 0.60, 0.71, 0.58, 0.0, 0.21, 0.79, 1.0]       # how solid the banner is in each 0.05 s of its arrival
const PORTRAIT_AT := 0.9
const PORTRAIT_IN := 0.75
const LINE_AT: Array = [1.28, 1.36, 1.43]
const LINE_IN: Array = [0.08, 0.09, 0.22]
const INFO_OUT := 0.2
const START_GAP := 0.25                      # a short empty moment between the titles and START
const START_IN := 0.45
const START_OUT := 0.35                      # dims to about 65% over the first 0.25 s, then goes quickly as the zoom begins
const ZOOM_TIME := 0.23
const FLASH_RISE := 0.07
const FLASH_FALL := 0.10
const DESIGN_H := 1080.0

const FLASH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 over = c * (1.0 + 7.0 * flash) + vec3(0.25 * flash);
	COLOR = vec4(mix(over, vec3(1.0), smoothstep(0.55, 1.0, flash)), 1.0);
}
"""

var is_playing: bool = false

var _t: float = 0.0
var _frames: int = 0
var _was_paused: bool = false
var _prev_clear: Color = Color(0.3, 0.3, 0.3)
var _round_started: bool = false
var _layer: CanvasLayer
var _stage: Stage
var _flash_layer: CanvasLayer
var _flash_mat: ShaderMaterial
var _flash_rect: ColorRect
var _font: Font
var _played: Dictionary = {}
var _start_clock: float = 0.0           # where the design clock begins (later if there is no banner)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # it must keep running while the game is frozen
	set_process(false)
	if play_on_ready:
		_begin()


func _exit_tree() -> void:
	if is_playing:
		_end()                                       # never leave the game shrunken or frozen after a scene change


## Plays the sequence. Returns when it is completely finished (use `await intro.play()`).
func play() -> void:
	if is_playing:
		return
	_begin()
	await finished


# ---------------------------------------------------------------- the clock

func _design_time() -> float:
	return _t * speed + _start_clock


func _times() -> Dictionary:
	var info_end: float = float(LINE_AT[2]) + float(LINE_IN[2]) + info_hold_seconds
	var start_at := info_end + INFO_OUT + START_GAP
	var start_end := start_at + START_IN + start_hold_seconds + START_OUT
	var zoom_start := start_end - 0.2
	var flash_start := zoom_start + ZOOM_TIME
	return {
		"info_end": info_end, "start_at": start_at, "start_end": start_end, "zoom_start": zoom_start,
		"flash_start": flash_start, "flash_peak": flash_start + FLASH_RISE, "end": flash_start + FLASH_RISE + FLASH_FALL + 0.03,
	}


func _begin() -> void:
	is_playing = true
	_round_started = false
	_t = 0.0
	_frames = 0
	_played.clear()
	_start_clock = 0.0 if banner != null else PORTRAIT_AT - 0.1         # no banner: begin where the portrait starts
	_was_paused = get_tree().paused
	get_tree().paused = true                          # the game waits (this node still runs: it is Always)
	_prev_clear = RenderingServer.get_default_clear_color()           # whatever it is right now, so we put back exactly that
	RenderingServer.set_default_clear_color(border_color)
	_font = font
	if _font == null:
		var bold := FontVariation.new()
		bold.base_font = ThemeDB.fallback_font
		bold.variation_embolden = 0.9
		_font = bold
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_stage = Stage.new()
	_stage.intro = self
	_layer.add_child(_stage)
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 140
	add_child(_flash_layer)
	var sh := Shader.new()
	sh.code = FLASH_SHADER
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = sh
	_flash_rect = ColorRect.new()
	_flash_rect.material = _flash_mat
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)          # (without a size it would be invisible)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false
	_flash_layer.add_child(_flash_rect)
	_apply_game_scale(1.0)
	set_process(true)


func _process(delta: float) -> void:
	if not is_playing:
		return
	_frames += 1
	if _frames > 2:                                   # the first frames of a new scene can be very long: do not let them eat the sequence
		_t += minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	var td := _design_time()
	var tm := _times()
	# sounds
	if banner != null:
		_once("banner", td >= 0.0, slide_sound)
	_once("portrait", td >= PORTRAIT_AT, slide_sound)
	for i in range(3):
		_once("line%d" % i, td >= float(LINE_AT[i]), slide_sound)
	_once("start", td >= tm["start_at"], start_sound)
	# the game: smaller, dimmer, creeping up, then zooming to full size
	_apply_game_scale(_game_scale(td, tm))
	_stage.queue_redraw()
	# the flash, and the moment the round begins
	var f := _flash_amount(td, tm)
	_flash_rect.visible = f > 0.0
	_flash_mat.set_shader_parameter("flash", f)
	_once("flash", td >= tm["flash_start"], flash_sound)
	if not _round_started and td >= tm["flash_peak"]:
		_round_started = true
		get_tree().paused = _was_paused               # the game starts NOW, at the brightest moment
		round_started.emit()
	if td >= tm["end"]:
		_end()


func _input(event: InputEvent) -> void:
	if not is_playing or not skippable or _t < 0.5:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if pressed:
		var tm := _times()
		var target := (float(tm["zoom_start"]) - _start_clock - 0.05) / maxf(speed, 0.05)
		if _t < target:
			_t = target
		get_viewport().set_input_as_handled()


func _end() -> void:
	is_playing = false
	set_process(false)
	get_viewport().global_canvas_transform = Transform2D.IDENTITY
	RenderingServer.set_default_clear_color(_prev_clear)
	if not _round_started:
		get_tree().paused = _was_paused
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	if _flash_layer != null and is_instance_valid(_flash_layer):
		_flash_layer.queue_free()
	_layer = null
	_flash_layer = null
	_stage = null
	finished.emit()


# ---------------------------------------------------------------- the game's size, dim and flash

func _game_scale(td: float, tm: Dictionary) -> float:
	var z0: float = tm["zoom_start"]
	var z1: float = tm["flash_start"]
	var creep := game_scale + 0.01
	if td < z0:
		var s := lerpf(game_scale, creep, clampf(td / z0, 0.0, 1.0))      # a very slow push in while the titles play
		var shrink := _ease_out(clampf(td / 0.25, 0.0, 1.0))               # at the very start it shrinks from full size, not a snap
		return lerpf(1.0, s, shrink)
	var p := clampf((td - z0) / (z1 - z0), 0.0, 1.0)
	return lerpf(creep, 1.0, p * p)                                         # then it speeds up into full size


func _dim_amount(td: float, tm: Dictionary) -> float:
	var z0: float = tm["zoom_start"]
	var z1: float = tm["flash_start"]
	var fade_in := _ease_out(clampf(td / 0.25, 0.0, 1.0))
	var fade_out := 1.0 - clampf((td - z0) / (z1 - z0 + 0.02), 0.0, 1.0)
	return dim_strength * fade_in * fade_out


func _flash_amount(td: float, tm: Dictionary) -> float:
	var tf: float = td - float(tm["flash_start"])
	if tf < 0.0:
		return 0.0
	if tf < FLASH_RISE:
		return tf / FLASH_RISE
	return 1.0 - smoothstep(0.0, 1.0, (tf - FLASH_RISE) / FLASH_FALL)        # stays bright a moment, then drops away fast, like the video


## Shrinks the whole picture (world AND HUD) about the screen's centre, and cancels it on our own layers so the titles stay full size.
func _apply_game_scale(s: float) -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var t := Transform2D().scaled(Vector2(s, s))
	t.origin = size * (1.0 - s) * 0.5
	vp.global_canvas_transform = t
	if _layer != null:
		_layer.transform = t.affine_inverse()
	if _flash_layer != null:
		_flash_layer.transform = t.affine_inverse()


func _once(key: String, condition: bool, stream: AudioStream) -> void:
	if condition and not _played.has(key):
		_played[key] = true
		if stream != null:
			var sfx := AudioStreamPlayer.new()
			sfx.stream = stream
			sfx.volume_db = sound_volume_db
			sfx.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
			sfx.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(sfx)
			sfx.finished.connect(sfx.queue_free)
			sfx.play()


static func _ease_out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


func _player_name() -> String:
	if character_name.strip_edges() != "":
		return character_name
	var p := get_tree().get_first_node_in_group("player")
	if p != null and "character_name" in p:
		return str(p.character_name)
	return "PLAYER"


# ---------------------------------------------------------------- drawing

## Draws something several times in a row, spread over `blur` pixels, the front copy sharp and the trailing ones faint: a motion blur.
func _blurred(blur: float, alpha: float, drawer: Callable) -> void:
	var n := clampi(int(blur / 5.0), 9, 30) if blur > 2.0 else 1
	for i in range(n):
		var f := float(i) / float(maxi(n - 1, 1))
		var a := alpha * (0.10 + 0.90 * f * f) * (9.0 / float(n) * 0.6 + 0.4 * f) if n > 1 else alpha
		drawer.call(Vector2(-blur * (1.0 - f), 0.0), a)


## A slide that eases out for a long time (the banner and the portrait). `travel` is how far away it starts, in pixels.
## Returns where it is (offset from its resting place, 0 when it has arrived), and how fast it is moving (for the motion blur).
func _slide_expo(td: float, t0: float, dur: float, travel: float, tau: float) -> Dictionary:
	var sec := clampf(td - t0, 0.0, dur)
	var e0 := exp(-dur / tau)
	var v := (exp(-sec / tau) - e0) / (1.0 - e0)
	var speed_px := travel * exp(-sec / tau) / (tau * (1.0 - e0)) if td < t0 + dur else 0.0
	return {"offset": travel * v, "blur": clampf(speed_px * 0.016, 0.0, travel * 0.16), "started": td >= t0}


## A short, sharp slide (the three lines): quick at first, slowing to a stop.
func _slide_quad(td: float, t0: float, dur: float, travel: float) -> Dictionary:
	var p := clampf((td - t0) / maxf(dur, 0.001), 0.0, 1.0)
	var speed_px := 2.0 * travel * (1.0 - p) / maxf(dur, 0.001) if p < 1.0 else 0.0
	return {"offset": travel * (1.0 - p) * (1.0 - p), "blur": clampf(speed_px * 0.016, 0.0, travel * 0.2), "started": td >= t0}


func _paint(c: Control) -> void:
	var td := _design_time()
	var tm := _times()
	var size := c.size
	var k := size.y / DESIGN_H
	# 1. the dim over the shrunken game
	var dim := _dim_amount(td, tm)
	if dim > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, dim))
	# 2. the banner
	if banner != null:
		_paint_banner(c, td, k, size)
	# 3. the three lines, then the portrait on top of them (so the lines come out from behind it)
	var info_alpha := 1.0 - clampf((td - float(tm["info_end"])) / INFO_OUT, 0.0, 1.0)
	if info_alpha > 0.0 and td >= float(LINE_AT[0]):
		_paint_lines(c, td, k, size, info_alpha)
	if portrait != null and info_alpha > 0.0 and td >= PORTRAIT_AT:
		_paint_portrait(c, td, k, size, info_alpha)
	# 4. START
	if td >= float(tm["start_at"]):
		_paint_start(c, td, tm, k, size)


func _paint_banner(c: Control, td: float, k: float, size: Vector2) -> void:
	var tex_size := banner.get_size() * k
	var final_pos := Vector2((size.x - tex_size.x) * 0.5, (size.y - tex_size.y) * 0.5)
	var sl := _slide_expo(td, 0.0, BANNER_IN, 1500.0 * k, 0.16)
	var idx := clampi(int(td / 0.05), 0, BANNER_FLICKER.size() - 1)
	var alpha := float(BANNER_FLICKER[idx]) if td < 0.4 else 1.0                       # an electronic flicker as it arrives
	alpha *= 1.0 - clampf((td - BANNER_FADE_AT) / BANNER_OUT, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var off: float = -float(sl["offset"])
	_blurred(float(sl["blur"]), alpha, func(dx: Vector2, a: float): c.draw_texture_rect(banner, Rect2(final_pos + Vector2(off, 0.0) + dx, tex_size), false, Color(1, 1, 1, a)))


func _paint_portrait(c: Control, td: float, k: float, size: Vector2, group_alpha: float) -> void:
	var tex_size := portrait.get_size() * k
	var final_pos := Vector2(136.0 * k, (size.y - tex_size.y) * 0.5)
	var sl := _slide_expo(td, PORTRAIT_AT, PORTRAIT_IN, 700.0 * k, 0.17)
	var alpha := clampf((td - PORTRAIT_AT) / 0.05, 0.0, 1.0) * group_alpha
	var off: float = -float(sl["offset"])
	_blurred(float(sl["blur"]), alpha, func(dx: Vector2, a: float): c.draw_texture_rect(portrait, Rect2(final_pos + Vector2(off, 0.0) + dx, tex_size), false, Color(1, 1, 1, a)))


## The three information lines as they will be shown (MODE and MAP in capitals, the character's name as written).
func info_lines() -> Array[String]:
	return [
		("%s %s" % [mode_label, mode_name]).to_upper(),
		("%s %s" % [stage_label, stage_name]).to_upper(),
		"%s %s" % [character_label, _player_name()],
	]


func _paint_lines(c: Control, td: float, k: float, size: Vector2, group_alpha: float) -> void:
	var left := (136.0 + 400.0 + 42.0) * k if portrait != null else 200.0 * k
	var texts := info_lines()
	var lines := [
		{"text": texts[0], "base": 468.0, "size": small_size, "i": 0},
		{"text": texts[1], "base": 552.0, "size": small_size, "i": 1},
		{"text": texts[2], "base": 649.0, "size": big_size, "i": 2},
	]
	for ln in lines:
		var i: int = ln["i"]
		var t0: float = float(LINE_AT[i])
		if td < t0:
			continue
		var sl := _slide_quad(td, t0, float(LINE_IN[i]), 1500.0 * k)                  # they fly in from the RIGHT
		var alpha := group_alpha
		var fs := int(float(ln["size"]) * k)
		var pos := Vector2(left + float(sl["offset"]), float(ln["base"]) * k)
		var text: String = ln["text"]
		var ol := maxi(int(float(outline_size) * k), 1)
		_blurred(float(sl["blur"]), alpha, func(dx: Vector2, a: float):
			c.draw_string_outline(_font, pos + dx, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color(outline_color.r, outline_color.g, outline_color.b, a))
			c.draw_string(_font, pos + dx, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(text_color.r, text_color.g, text_color.b, a)))


func _paint_start(c: Control, td: float, tm: Dictionary, k: float, size: Vector2) -> void:
	var t0: float = tm["start_at"]
	var in_p := clampf((td - t0) / START_IN, 0.0, 1.0)
	var hold_end: float = t0 + START_IN + start_hold_seconds
	var dim_p := clampf((td - hold_end) / 0.25, 0.0, 1.0)                           # dims to 65%...
	var cut_p := clampf((td - (hold_end + 0.25)) / (START_OUT - 0.25), 0.0, 1.0)    # ...then goes
	var alpha := clampf(0.3 + 0.7 * _ease_out(in_p), 0.0, 1.0) * lerpf(1.0, 0.65, dim_p) * (1.0 - cut_p) if td > t0 else 0.0
	if alpha <= 0.0:
		return
	var grow := lerpf(0.4, 1.0, _ease_out(in_p))                                    # shoots up to size...
	var creep := clampf((td - (t0 + START_IN)) / maxf(start_hold_seconds + START_OUT, 0.01), 0.0, 1.0)
	grow *= 1.0 + 0.07 * creep                                                      # ...then creeps larger
	var fs := int(float(start_size) * k)
	var center := Vector2(size.x * 0.5, size.y * 0.5 + 12.0 * k)
	c.draw_set_transform(center, 0.0, Vector2(grow, grow))
	var width := _font.get_string_size(start_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := _font.get_ascent(fs)
	var desc := _font.get_descent(fs)
	var pos := Vector2(-width * 0.5, (asc - desc) * 0.5)
	var ol := maxi(int(float(start_outline_size) * k), 1)
	c.draw_string_outline(_font, pos, start_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color(outline_color.r, outline_color.g, outline_color.b, alpha))
	c.draw_string(_font, pos, start_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(text_color.r, text_color.g, text_color.b, alpha))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The full-screen canvas the titles are drawn on.
class Stage extends Control:
	var intro: RoundIntro

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if intro != null and intro.is_playing:
			intro._paint(self)
