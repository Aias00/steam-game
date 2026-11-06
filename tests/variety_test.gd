extends SceneTree
const Run = preload("res://scripts/run.gd")
func pick(r, key: String) -> void:
    r.state = "upgrade"
    r.choices.assign([key])
    r.choose_upgrade(0)
func _initialize() -> void:
    create_timer(15).timeout.connect(func(): quit(1))
    var fingerprints := {}
    for seed_value in range(1, 20):
        var r = Run.new("pulse", 0, seed_value)
        r.open_upgrade()
        assert(r.choices.size() == 3 and r.choices.has("pulse"))
        assert(r.choices[0] != r.choices[1] and r.choices[1] != r.choices[2] and r.choices[0] != r.choices[2])
        fingerprints[str(r.choices)] = true
        var old: Array = r.choices.duplicate()
        assert(r.reroll_upgrades() and r.rerolls_left == 0 and r.choices.has("pulse"))
        assert(not r.reroll_upgrades())
        assert(r.choices[1] not in old and r.choices[2] not in old)
    assert(fingerprints.size() > 5)
    var full = Run.new("pulse", 0, 42, "assassin")
    for key in ["lens", "axle", "fiber", "lightfoot"]:
        for n in range(3):
            pick(full, key)
    assert(full.module_slots_used() == 4)
    assert(not full.upgrade_pool().has("gravity") and not full.upgrade_pool().has("battery"))
    for key in full.weapons:
        full.weapons[key] = 6
    full.level = 20
    full.draw_upgrade_choices()
    assert(full.choices == ["supply_health", "supply_power", "supply_salvage"])
    assert(full.health == 110 and full.max_health == 110)
    assert(is_equal_approx(full.speed, 250 * 1.12))
    assert(is_equal_approx(full.dash_period, 2.5))
    full.assault_timer = 1
    assert(is_equal_approx(full.crit_chance("pulse"), 0.35))
    assert(is_equal_approx(full.crit_chance("turret"), 0.14))
    var gravity = Run.new("nova", 0, 42)
    pick(gravity, "gravity")
    assert(gravity.magnet == 125)
    gravity.spawn_enemy(2, Vector2(100, 0))
    gravity.update_weapons(0)
    assert(is_equal_approx(gravity.rings[0].radius, 137 * 1.04))
    # Hold-to-select reserves a slot once; leaving the ring preserves progress.
    var facility = Run.new("pulse", 0, 42, "engineer")
    facility.elapsed = 90
    facility.spawn_clock = 999
    facility.player = facility.facilities.sites[0].pos
    facility.facilities.update(facility, 0.3, true)
    facility.facilities.update(facility, 0.3, false)
    assert(facility.facilities.selected_count() == 0)
    facility.facilities.update(facility, 0.6, true)
    assert(facility.facilities.selected_count() == 1 and facility.enemies.size() == 4)
    facility.facilities.update(facility, 1, true)
    assert(facility.enemies.size() == 4)
    var progress: float = facility.facilities.sites[0].progress
    facility.player = Vector2.ZERO
    facility.facilities.update(facility, 2, false)
    assert(facility.facilities.sites[0].progress == progress)
    facility.player = facility.facilities.sites[0].pos
    facility.facilities.update(facility, 14.4 - progress, false)
    assert(facility.facilities.sites[0].complete)
    facility.facilities.select_site(facility, 1)
    facility.facilities.select_site(facility, 2)
    assert(facility.facilities.selected_count() == 2 and not facility.facilities.sites[2].selected)
    facility.enemies.clear()
    facility.shots.clear()
    facility.spawn_enemy(2, facility.player + Vector2(70, 0))
    facility.mark_id = facility.enemies[0].id
    facility.damage_scale = 50
    facility.facilities.update_reward(facility, facility.facilities.sites[0], 1)
    assert(facility.shots.size() > 0 and facility.shots.back().world and not facility.shots.back().critical)
    var hp: float = facility.enemies[0].hp
    var damage: float = facility.shots.back().damage
    facility.update_shots(0.2)
    assert(is_equal_approx(facility.enemies[0].hp, hp - damage))
    var magnet = Run.new()
    magnet.loot.assign([{"pos": Vector2(0, 10), "value": 4, "heal": false}, {"pos": Vector2(0, 20), "value": 15, "heal": true}])
    var heal_pos: Vector2 = magnet.loot[1].pos
    magnet.facilities.update_reward(magnet, magnet.facilities.sites[1], 30)
    assert(magnet.loot[0].value == 4 and magnet.loot[1].pos == heal_pos and magnet.loot.size() == 2)
    var greenhouse = Run.new()
    var garden: Dictionary = greenhouse.facilities.sites[2]
    for n in range(4):
        greenhouse.facilities.update_reward(greenhouse, garden, 60)
    assert(greenhouse.loot.size() == 2)
    var spores = Run.new()
    spores.elapsed = 90
    spores.spawn_clock = 999
    spores.player = spores.facilities.sites[2].pos
    spores.facilities.select_site(spores, 2)
    spores.enemies.clear()
    spores.facilities.update(spores, 2.0, false)
    assert(spores.facilities.hazards.size() == 1 and spores.health == 100)
    spores.facilities.update(spores, 1.1, false)
    assert(spores.health == 100)
    spores.facilities.update(spores, 0.11, false)
    assert(spores.health == 88)
    var frozen_progress: float = spores.facilities.sites[2].progress
    var frozen_hazard: float = spores.facilities.hazards[0].time
    spores.state = "equipment"
    spores.step(10, Vector2.ZERO)
    assert(spores.facilities.sites[2].progress == frozen_progress and spores.facilities.hazards[0].time == frozen_hazard)
    # E chooses only the nearest object; a tie goes to the repair cache.
    var interaction = Run.new()
    interaction.elapsed = 120
    interaction.player = interaction.facilities.sites[0].pos
    interaction.maintenance_caches.append({"pos": interaction.player, "used": false, "generated": false, "offers": []})
    assert(interaction.nearest_interaction_facility() == -1 and interaction.open_maintenance())
    interaction.close_maintenance()
    interaction.maintenance_caches[0].pos += Vector2(50, 0)
    assert(interaction.nearest_interaction_facility() == 0 and not interaction.open_maintenance())
    print("PASS: varied weighted choices, early weapon guarantee/reroll, four module slots/level caps/supplies, actual module stats, facility hold/capture/slot cap/guards, unbuffed tower, conservative magnet, capped greenhouse and exclusive E interaction")
    quit()
