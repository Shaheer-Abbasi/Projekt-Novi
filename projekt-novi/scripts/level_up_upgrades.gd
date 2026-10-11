class_name LevelUpUpgrades
extends RefCounted
## Single source of truth for repeatable level-up upgrades.
## No upgrade is removed after selection: all six remain available next time.

const OPTIONS := {
    "damage": {
        "name": "Sharpened Edge",
        "description": "+3 damage to basic attacks",
    },
    "health": {
        "name": "Reinforced Body",
        "description": "+20 maximum HP and heal 20 HP",
    },
    "movement": {
        "name": "Quickstep",
        "description": "+10% movement speed",
    },
    "attack_speed": {
        "name": "Rapid Strikes",
        "description": "Basic attacks fire 10% faster",
    },
    "range": {
        "name": "Extended Reach",
        "description": "+20 basic attack range",
    },
    "cooldowns": {
        "name": "Overclock",
        "description": "All 4 abilities recharge 10% faster",
    },
}


static func roll_choices() -> Array[String]:
    # Uniform sample of 3 different options, without replacement within this roll.
    # Every call starts with all six again; upgrades can stack across levels.
    var pool: Array[String] = []
    for id in OPTIONS.keys():
        pool.append(id)
    pool.shuffle()
    var choices: Array[String] = []
    for i in range(3):
        choices.append(pool[i])
    return choices


static func apply(player: PlaytestPlayer, upgrade_id: String) -> bool:
    if not is_instance_valid(player) or not OPTIONS.has(upgrade_id):
        return false

    match upgrade_id:
        "damage":
            # Both the bullet damage formula and legacy robot hit path read this stat.
            XpManager.attack_damage += 3
        "health":
            player.max_hp += 20.0
            player.current_hp = minf(player.current_hp + 20.0, player.max_hp)
            player.health_changed.emit(player.current_hp, player.max_hp)
        "movement":
            player.speed *= 1.10
        "attack_speed":
            # Multiplier affects future basic attacks without modifying shared resources.
            player.basic_attack_cooldown_multiplier *= 0.90
        "range":
            player.aim_radius += 20.0
            player.queue_redraw()
        "cooldowns":
            for ability in player.abilities:
                ability.cooldown_time = maxf(0.20, ability.cooldown_time * 0.90)
        _:
            return false
    return true
