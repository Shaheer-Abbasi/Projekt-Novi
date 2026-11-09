extends Control

const STARTING_COINS := 10

@onready var coin_count_label: Label = $Margin/Layout/TopBar/CoinCount
@onready var roll_button: Button = $Margin/Layout/MainPanel/Content/ShopSide/RollButton
@onready var status_label: Label = $Margin/Layout/MainPanel/Content/ShopSide/Status
@onready var reward_panel: PanelContainer = $Margin/Layout/MainPanel/Content/ShopSide/RewardPanel
@onready var capsule: TextureRect = $Margin/Layout/MainPanel/Content/MachineArea/CapsuleTexture
@onready var vow_pop: TextureRect = $Margin/Layout/MainPanel/Content/MachineArea/VowPop

var coins := STARTING_COINS
var rolling := false

func _ready() -> void:
    reward_panel.visible = false
    capsule.visible = false
    vow_pop.visible = false
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
    vow_pop.visible = false
    status_label.text = "Dispensing capsule..."
    _update_coin_display()

    await _dispense_capsule()
    await _pop_vow_from_capsule()

    reward_panel.visible = true
    status_label.text = "Vow unlocked!"
    rolling = false
    _update_coin_display()

func _dispense_capsule() -> void:
    capsule.visible = true
    capsule.modulate = Color.WHITE
    capsule.scale = Vector2(0.65, 0.65)
    capsule.pivot_offset = capsule.size / 2.0
    capsule.position = Vector2(255.0, 330.0)
    capsule.rotation = -0.18

    var drop := create_tween()
    drop.set_parallel(true)
    drop.tween_property(capsule, "position", Vector2(255.0, 435.0), 0.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    drop.tween_property(capsule, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    drop.tween_property(capsule, "rotation", 0.12, 0.28).set_trans(Tween.TRANS_SINE)
    await drop.finished

    var settle := create_tween()
    settle.tween_property(capsule, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
    await settle.finished
    await get_tree().create_timer(0.2).timeout

func _pop_vow_from_capsule() -> void:
    status_label.text = "Capsule opening..."

    vow_pop.visible = true
    vow_pop.modulate = Color(1, 1, 1, 0)
    vow_pop.scale = Vector2(0.15, 0.15)
    vow_pop.pivot_offset = vow_pop.size / 2.0
    vow_pop.position = Vector2(236.0, 425.0)

    var pop := create_tween()
    pop.set_parallel(true)
    pop.tween_property(capsule, "scale", Vector2(1.3, 0.35), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    pop.tween_property(capsule, "modulate:a", 0.0, 0.22)
    pop.tween_property(vow_pop, "modulate:a", 1.0, 0.12)
    pop.tween_property(vow_pop, "position", Vector2(220.0, 250.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop.tween_property(vow_pop, "scale", Vector2(1.15, 1.15), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await pop.finished

    capsule.visible = false
    status_label.text = "Vow!"

    var settle := create_tween()
    settle.tween_property(vow_pop, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
    await settle.finished
    await get_tree().create_timer(0.55).timeout

func _on_back_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/MainMenuScenes/main_menu.tscn")
