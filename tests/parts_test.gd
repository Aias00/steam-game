extends SceneTree
const Run = preload("res://scripts/run.gd")
func cache_at_player(r) -> void:
    r.elapsed = 120
    r.spawn_maintenance_caches()
    r.maintenance_caches[0].pos = r.player
func install(r, id: String) -> void:
    r.maintenance_caches.append({"pos": r.player, "used": false, "generated": true, "offers": [id]})
    r.active_cache = r.maintenance_caches.size() - 1
    r.state = "maintenance"
    assert(r.claim_maintenance(id))
func _initialize() -> void:
    var r = Run.new("pulse", 0, 123, "ranger")
    cache_at_player(r)
    assert(r.maintenance_caches.size() == 1)
    var combat_rng: int = r.rng.state
    assert(r.open_maintenance())
    assert(r.rng.state == combat_rng)
    var offers: Array = r.maintenance_caches[0].offers.duplicate()
    assert(offers.size() == 2 and offers.has("P01") and offers.has("P02"))
    var time: float = r.elapsed
    r.step(1, Vector2.ONE)
    assert(r.elapsed == time)
    assert(not r.claim_maintenance("P03"))
    r.close_maintenance()
    assert(not r.maintenance_caches[0].used)
    assert(r.open_maintenance() and r.maintenance_caches[0].offers == offers)
    assert(r.claim_maintenance("P01"))
    assert(not r.claim_maintenance("heal") and r.installed_parts.pulse == "P01")
    r.spawn_enemy(2, Vector2(100, 0))
    r.update_weapons(0)
    assert(is_equal_approx(r.shots[0].damage, 26 * 0.85) and r.shots[0].pierce == 2)
    var old_damage: float = r.shots[0].damage
    install(r, "P02")
    assert(r.shots[0].damage == old_damage and r.shots[0].pierce == 2)
    r.shots.clear()
    r.enemies.clear()
    r.spawn_enemy(2, Vector2(50, 0))
    r.spawn_enemy(2, Vector2(150, 30))
    r.cooldowns.pulse = 0
    r.update_weapons(0)
    r.shots[0].critical = true
    r.update_shots(0.1)
    assert(r.shots.size() == 1 and not r.shots[0].bounce)
    assert(is_equal_approx(r.shots[0].damage, 26 * 0.75 * 0.6) and r.shots[0].critical)
    r.update_shots(0.3)
    assert(r.shots.is_empty())
    var ring = Run.new("orbit", 0, 123)
    var radius: float = ring.orbit_radius()
    ring.blade_angle = 1.1
    ring.cooldowns.orbit = 0.1
    install(ring, "P03")
    assert(is_equal_approx(ring.orbit_radius(), radius * 0.8) and ring.cooldowns.orbit == 0.1)
    install(ring, "P04")
    assert(is_equal_approx(ring.orbit_radius(), radius * 1.25) and ring.blade_angle == 1.1)
    var nova = Run.new("nova", 0, 123)
    nova.cooldowns.nova = nova.nova_period() * 0.5
    install(nova, "P05")
    assert(is_equal_approx(nova.cooldowns.nova / nova.nova_period(), 0.5))
    install(nova, "P06")
    assert(is_equal_approx(nova.cooldowns.nova / nova.nova_period(), 0.5))
    var turret = Run.new("turret", 0, 123, "engineer")
    install(turret, "P07")
    turret.update_weapons(0)
    var old: Dictionary = turret.turrets[0].duplicate()
    assert(is_equal_approx(old.life, 7.0 * 0.85) and is_equal_approx(old.damage, 24.0 * 0.8))
    install(turret, "P08")
    assert(turret.turrets[0] == old)
    turret.cooldowns.turret = 0
    turret.update_weapons(0)
    assert(is_equal_approx(turret.turrets[1].range, 570.0))
    assert(is_equal_approx(turret.turrets[1].period, 0.65 * 1.25))
    var robot = Run.new("pulse", 0, 123, "robot")
    robot.health = 50
    cache_at_player(robot)
    robot.open_maintenance()
    assert(robot.claim_maintenance("heal") and is_equal_approx(robot.health, 61.25))
    assert(not robot.claim_maintenance("heal") and is_equal_approx(robot.health, 61.25))
    # Pierce a dense line once per enemy, including a frame spanning all targets.
    var line = Run.new("pulse", 0, 123)
    install(line, "P01")
    for x in [40, 80, 120, 160]:
        line.spawn_enemy(2, Vector2(x, 0))
    line.update_weapons(0)
    line.shots[0].critical = false
    line.update_shots(0.3)
    assert(line.shots.is_empty())
    for i in range(4):
        assert(is_equal_approx(line.enemies[i].hp, 95.0 - (22.1 if i < 3 else 0.0)))
    # Existing turret keeps the owning damage/haste snapshot after global upgrades.
    turret.damage_scale = 5
    turret.haste = 3
    assert(turret.turrets[0] == old)
    # P05 and P06 are mutually exclusive and affect the actual emitted ring.
    var burst = Run.new("nova", 0, 123)
    install(burst, "P05")
    burst.spawn_enemy(2, Vector2(0, 0))
    burst.update_weapons(0)
    assert(is_equal_approx(burst.rings[0].radius, 137.0 * 0.85))
    install(burst, "P06")
    burst.cooldowns.nova = 0
    burst.update_weapons(0)
    assert(is_equal_approx(burst.rings[1].radius, 137.0 * 1.3))
    var fresh = Run.new("pulse", 0, 123)
    fresh.elapsed = 500
    fresh.spawn_maintenance_caches()
    fresh.spawn_maintenance_caches()
    assert(fresh.maintenance_caches.size() == 3 and fresh.installed_parts.pulse == "")
    print("PASS: maintenance timing, stable offers/independent RNG, pause/cancel/atomic claims, eight part modifiers, replacement cooldown, projectile/turret snapshots, single bounce/crit inheritance, robot repair and fresh run")
    quit()
