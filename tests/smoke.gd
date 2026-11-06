extends SceneTree

const Run = preload("res://scripts/run.gd")

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    create_timer(45).timeout.connect(func(): quit(1))
    var game = Run.new("pulse", 2, 42)
    assert(game.health == 116 and game.weapons.pulse == 1, "Starter and permanent stats")
    game.spawn_clock = 999
    var start: Vector2 = game.player
    game.step(0.1, Vector2.ONE)
    assert(is_equal_approx(game.player.distance_to(start), game.speed * 0.1), "Normalized movement")
    game.player = Vector2(-9000, -9000)
    game.step(0, Vector2.ZERO)
    assert(Run.WORLD.has_point(game.player), "World bounds")
    game.player = Vector2.ZERO
    game.dash()
    game.hurt(100)
    assert(game.health == 116, "Dash invulnerability")
    assert(game.dash_cooldown == 3, "Dash cooldown")
    game.step(0.2, Vector2.ZERO)
    game.hurt(10)
    var hp: float = game.health
    game.hurt(10)
    assert(game.health == hp, "Hit grace period")
    game.enemies.clear()
    var enemy: Dictionary = game.spawn_enemy(0, game.player + Vector2(90, 0))
    game.cooldowns.pulse = 0
    for step in range(15):
        game.step(0.05, Vector2.ZERO)
    assert(game.kills == 1, "Auto-target projectile kills")
    game.loot.clear()
    game.loot.append({"pos": game.player, "value": 30, "heal": false})
    game.step(0, Vector2.ZERO)
    assert(game.state == "upgrade" and game.choices.size() == 3, "XP opens choice")
    assert(game.choices[0] != game.choices[1] and game.choices[1] != game.choices[2] and game.choices[0] != game.choices[2], "Unique choices")
    var before: float = game.elapsed
    game.step(1, Vector2.ONE)
    assert(game.elapsed == before, "Upgrade pauses combat")
    game.choose_upgrade(-1)
    assert(game.state == "upgrade", "Reject invalid choice")
    while game.state == "upgrade":
        game.choose_upgrade(0)
    assert(game.level >= 3 and game.xp < game.xp_needed(), "Overflow XP grants all levels")
    var orbit = Run.new("orbit", 0, 1)
    orbit.spawn_clock = 999
    orbit.spawn_enemy(0, orbit.blade_positions()[0])
    orbit.update_weapons(0)
    orbit.cooldowns.orbit = 0
    orbit.update_weapons(0)
    assert(orbit.kills == 1, "Orbit damage")
    var nova = Run.new("nova", 0, 1)
    nova.spawn_clock = 999
    nova.spawn_enemy(0, Vector2(70, 0))
    nova.update_weapons(0)
    assert(nova.kills == 1 and nova.rings.size() == 1, "Nova damage and ring")
    var ranged = Run.new("pulse", 0, 1)
    var spitter: Dictionary = ranged.spawn_enemy(3, Vector2(250, 0))
    spitter.attack = 0
    ranged.update_enemies(0.01)
    assert(ranged.shots.size() == 1 and ranged.shots[0].hostile, "Ranged attack")
    ranged.shots[0].pos = ranged.player
    ranged.update_shots(0)
    assert(ranged.health == 90, "Enemy projectile damage")
    var boss = Run.new("pulse", 0, 1)
    boss.spawn_clock = 999
    boss.elapsed = 539.99
    boss.step(0.02, Vector2.ZERO)
    assert(boss.boss_spawned and boss.enemies.size() == 1 and boss.enemies[0].kind == 4, "Boss arrival")
    boss.enemies[0].attack = 0
    boss.update_enemies(0)
    assert(boss.shots.filter(func(s): return s.hostile).size() == 12, "Boss radial barrage")
    boss.elapsed = 600
    boss.step(0, Vector2.ZERO)
    assert(boss.state == "playing", "Timer alone cannot win")
    boss.damage_enemy(0, 100000)
    boss.step(0, Vector2.ZERO)
    assert(boss.state == "won" and boss.boss_defeated, "Boss kill plus survival wins")
    var death = Run.new()
    death.health = 0
    death.step(0, Vector2.ZERO)
    assert(death.state == "lost", "Death settles run")
    # Deterministic 10-minute accelerated soak; invulnerability is test-only.
    var soak = Run.new("pulse", 0, 90210)
    soak.weapons = {"pulse": 6, "orbit": 6, "nova": 6, "turret": 6}
    soak.damage_scale = 2
    soak.magnet = 400
    var frames := 0
    var started := Time.get_ticks_msec()
    while soak.elapsed < 601:
        if soak.state == "upgrade":
            soak.choose_upgrade(0)
        elif soak.state == "playing":
            soak.hurt_timer = 1
            soak.step(0.1, Vector2.from_angle(soak.elapsed * 0.03))
            frames += 1
        else:
            break
    assert(soak.elapsed >= 600 and soak.boss_spawned, "Full duration simulation")
    assert(soak.enemies.size() <= 141 and soak.loot.size() <= 360 and soak.particles.size() <= 250, "Entity bounds")
    print("PASS: movement, dash, grace period, auto fire, loot, unique upgrades, overflow, all weapons, ranged damage, boss, victory, death")
    print("SOAK: ", frames, " steps / ", snappedf(soak.elapsed, 0.1), " game seconds / ", Time.get_ticks_msec() - started, "ms real / kills=", soak.kills, " enemies=", soak.enemies.size(), " shots=", soak.shots.size())
    quit(0)
