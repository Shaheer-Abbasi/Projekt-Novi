extends Control

const STARTING_COINS := 10
const CAPSULE_SHEET_PATH := "res://assets/Gacha/CapsuleSheet.png"
const CAPSULE_FRAME_SIZE := Vector2(64, 64)
const CAPSULE_FRAMES := 15

@onready var coin_count_label: Label = $Margin/Layout/TopBar/CoinCount
@onready var roll_button: Button = $Margin/Layout/MainPanel/Content/ShopSide/RollButton
@onready var status_label: Label = $Margin/Layout/MainPanel/Content/ShopSide/Status
@onready var reward_panel: PanelContainer = $Margin/Layout/MainPanel/Content/ShopSide/RewardPanel
@onready var capsule_texture: TextureRect = $Margin/Layout/MainPanel/Content/MachineArea/CapsuleTexture
@onready var capsule_fallback: Panel = $Margin/Layout/MainPanel/Content/MachineArea/CapsuleFallback

var coins := STARTING_COINS
var rolling := false

func _ready() -> void:
    reward_panel.visible = false
    capsule_texture.visible = false
    capsule_fallback.visible = false
    _update_coin_display()

func _update_coin_display() -> void:
    coin_count_label.text = str(coins)
    roll_button.disabled = rolling or coins <= 0

func _on_roll_button_pressed() -> void:
    if rolling or coins <= 0:
        return

    rolling = true
    coins -= 1
    reward_panel.visible = false
    status_label.text = "Dispensing capsule..."
    _update_coin_display()

    await _play_capsule_sequence()

    status_label.text = "Capsule opened!"
    await get_tree().create_timer(0.25).timeout

    capsule_texture.visible = false
    capsule_fallback.visible = false
    reward_panel.visible = true
    status_label.text = "Vow unlocked!"

    rolling = false
    _update_coin_display()

func _play_capsule_sequence() -> void:
    var start_position := Vector2(246.0, 345.0)
    var end_position := Vector2(246.0, 430.0)

    if ResourceLoader.exists(CAPSULE_SHEET_PATH):
        var sheet := load(CAPSULE_SHEET_PATH) as Texture2D
        capsule_texture.visible = true
        capsule_fallback.visible = false
        capsule_texture.position = start_position

        var drop_tween := create_tween()
        drop_tween.tween_property(capsule_texture, "position", end_position, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

        for frame_index in range(CAPSULE_FRAMES):
            var atlas := AtlasTexture.new()
            atlas.atlas = sheet
            atlas.region = Rect2(
                frame_index * CAPSULE_FRAME_SIZE.x,
                0,
                CAPSULE_FRAME_SIZE.x,
                CAPSULE_FRAME_SIZE.y
            )
            capsule_texture.texture = atlas
            await get_tree().create_timer(0.085).timeout

        await drop_tween.finished
    else:
        capsule_texture.visible = false
        capsule_fallback.visible = true
        capsule_fallback.position = start_position
        capsule_fallback.scale = Vector2(0.75, 0.75)

        var tween := create_tween()
        tween.set_parallel(true)
        tween.tween_property(capsule_fallback, "position", end_position, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
        tween.tween_property(capsule_fallback, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        await tween.finished

        for i in range(3):
            capsule_fallback.modulate.a = 0.35
            await get_tree().create_timer(0.09).timeout
            capsule_fallback.modulate.a = 1.0
            await get_tree().create_timer(0.09).timeout

func _on_back_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/MainMenuScenes/main_menu.tscn")
