extends SceneTree

const Run = preload("res://scripts/run.gd")
const DURATION := 60.0
const DT := 1.0 / 60.0
var results: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("audit")

# Controlled damage benchmark: immortal stationary targets; no waves, XP, modules
# or permanent upgrades. Actual weapon/projectile collision code, including misses.
func sample(weapon: String, lv: int, scenario: String, part: String = "", role: String = "") -> Dictionary:
    var run = Run.new(weapon, 0, 4242, role)
    run.weapons[weapon] = lv
    run.installed_parts[weapon] = part
    var count := 8 if scenario in ["crowd100", "crowd200"] else 4 if scenario == "line" else 1
    var radius := 120.0 if scenario == "boss120" else 600.0 if scenario == "single600" else 400.0 if scenario == "single400" else 200.0 if scenario == "crowd200" else 100.0
    for n in range(count):
        var point := Vector2(50 + n * 55, 0) if scenario == "line" else Vector2.from_angle(TAU * n / count) * radius
        var enemy: Dictionary = run.spawn_enemy(4 if scenario == "boss120" else 0, point)
        enemy["anchor"] = point
        enemy.hp = 1000000000.0
        enemy.max_hp = enemy.hp
    for tick in range(int(DURATION / DT)):
        for enemy in run.enemies:
            enemy.pos = enemy.anchor
        run.elapsed = tick * DT
        if scenario == "kite400":
            run.player = Vector2.from_angle(run.elapsed * 0.55) * 400
        run.update_mark(DT)
        run.update_weapons(DT)
        run.update_shots(DT)
    var damage := 0.0
    for enemy in run.enemies:
        damage += 1000000000.0 - enemy.hp
    return {"weapon": weapon, "level": lv, "scenario": scenario, "part": part, "role": role, "damage": snappedf(damage, 0.01), "dps": snappedf(damage / DURATION, 0.01)}

func survival(starter: String, seed_value: int) -> Dictionary:
    var game = Run.new(starter, 0, seed_value)
    var frames := 0
    while game.state not in ["lost", "won"] and frames < 13200:
        if game.state == "upgrade":
            var chosen := 0
            for desired in [starter, "fiber", "axle", "lens", "battery", "lightfoot", "gravity"]:
                if game.choices.has(desired):
                    chosen = game.choices.find(desired)
                    break
            game.choose_upgrade(chosen)
        else:
            var target := Vector2.from_angle(game.elapsed * 0.06) * 470
            var direction: Vector2 = (target - game.player).normalized()
            for enemy in game.enemies:
                if game.player.distance_to(enemy.pos) < enemy.radius + 45:
                    direction = (game.player - enemy.pos).normalized()
                    game.dash()
                    break
            game.step(0.05, direction)
        frames += 1
    return {"weapon": starter, "seed": seed_value, "seconds": snappedf(game.elapsed, 0.1), "kills": game.kills, "level": game.level, "outcome": game.state, "weapons": game.weapons.duplicate(), "modules": game.modules.duplicate()}

func audit() -> void:
    create_timer(120).timeout.connect(func(): quit(1))
    for weapon in ["pulse", "orbit", "nova", "turret"]:
        for lv in [1, 3, 6]:
            for scenario in ["single100", "single400", "boss120", "crowd100", "crowd200", "line", "kite400"]:
                results.append(sample(weapon, lv, scenario))
        for id in Run.Parts.DATA:
            if Run.Parts.DATA[id].weapon == weapon:
                for scenario in ["single100", "boss120", "crowd100", "crowd200", "line"]:
                    results.append(sample(weapon, 6, scenario, id))
    for weapon in ["pulse", "orbit", "nova", "turret"]:
        results.append(sample(weapon, 6, "single600"))
        for id in Run.Parts.DATA:
            if Run.Parts.DATA[id].weapon == weapon:
                results.append(sample(weapon, 6, "single600", id))
    for lv in [2, 4, 5]:
        results.append(sample("pulse", lv, "single400"))
    var runs: Array[Dictionary] = []
    for weapon in ["pulse", "orbit", "nova", "turret"]:
        for seed_value in range(1, 11):
            runs.append(survival(weapon, seed_value))
    var file := FileAccess.open("res://artifacts/balance/audit.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"duration": DURATION, "dt": DT, "seed": 4242, "benchmarks": results, "survival": runs}, "  "))
    print("AUDIT saved: ", results.size(), " damage scenarios + ", runs.size(), " normal-stat seeded survival runs")
    quit()
