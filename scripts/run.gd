extends RefCounted

const Facilities = preload("res://scripts/facilities.gd")
const Parts = preload("res://scripts/parts.gd")
const CACHE_TIMES := [120.0, 270.0, 420.0]

const WORLD := Rect2(-1400, -1000, 2800, 2000)
const LENGTH := 600.0
const BOSS_TIME := 540.0
const UPGRADE_INFO := {
    "turret": ["锚灯炮台", "部署独立炮台，自动射击附近目标。"],
    "pulse": ["星辉弹", "解锁 / 升级追踪射击，多发弹幕自动索敌。"],
    "orbit": ["环刃", "解锁 / 升级环绕刀刃，持续切割近身敌人。"],
    "nova": ["引力新星", "解锁 / 升级范围冲击，一次击退整片敌人。"],
    "lens": ["聚光镜", "投射物伤害 +8%，全局暴击率 +3个百分点。"],
    "axle": ["稳定轴", "全局武器冷却缩短4%。"],
    "gravity": ["引力匣", "拾取半径 +25，新星半径 +4%。"],
    "battery": ["备用电池", "炮台持续时间 +12%，范围伤害 +4%。"],
    "fiber": ["生命纤维", "最大生命 +10，恢复10生命。"],
    "lightfoot": ["轻装扣", "移速 +4%，冲刺冷却缩短0.1秒。"],
    "supply_health": ["体魄补给", "最大生命 +2，恢复2生命；不占槽。"],
    "supply_power": ["火力补给", "本局伤害 +1%；不占槽。"],
    "supply_salvage": ["回收补给", "本局结算额外星砂 +3；不占槽。"]
}

const ROLES := {
    "guard": ["岩灯", 120.0, 215.0, 3.0, "orbit"],
    "ranger": ["逐隼", 85.0, 255.0, 3.0, "pulse"],
    "engineer": ["砾砂", 95.0, 230.0, 3.4, "turret"],
    "starmapper": ["霁月", 90.0, 240.0, 3.0, "pulse"],
    "robot": ["螺灯", 100.0, 210.0, 3.2, "turret"],
    "assassin": ["墨刃", 80.0, 250.0, 2.8, "orbit"]
}
var facilities = Facilities.new()
var modules := {"lens": 0, "axle": 0, "gravity": 0, "battery": 0, "fiber": 0, "lightfoot": 0}
var rerolls_left := 1
var salvage_bonus := 0
var installed_parts := {"pulse": "", "orbit": "", "nova": "", "turret": ""}
var maintenance_rng := RandomNumberGenerator.new()
var maintenance_caches: Array[Dictionary] = []
var active_cache := -1
var blade_angle := 0.0
var role_id := ""
var dash_period := 3.0
var shield := 0.0
var safe_time := 0.0
var assault_timer := 0.0
var mark_id := -1
var mark_clock := 0.0
var mark_remaining := 0.0
var volley := 0
var effective_dashes := 0
var turrets: Array[Dictionary] = []
var damage_numbers: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var state := "playing"
var player := Vector2.ZERO
var facing := Vector2.RIGHT
var elapsed := 0.0
var health := 100.0
var max_health := 100.0
var damage_scale := 1.0
var haste := 1.0
var speed := 230.0
var armor := 0.0
var magnet := 100.0
var xp := 0
var level := 1
var kills := 0
var weapons := {"pulse": 0, "orbit": 0, "nova": 0, "turret": 0}
var cooldowns := {"pulse": 0.0, "orbit": 0.0, "nova": 0.0, "turret": 0.0}
var choices: Array[String] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var events: Array[String] = []
var spawn_clock := 0.5
var hurt_timer := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var boss_spawned := false
var boss_defeated := false
var next_id := 1

func _init(starter: String = "pulse", rank: int = 0, seed_value: int = 0, character: String = "") -> void:
    if seed_value == 0:
        rng.randomize()
    else:
        rng.seed = seed_value
    maintenance_rng.seed = rng.seed ^ 0x5a17
    if ROLES.has(character):
        role_id = character
        max_health = ROLES[character][1]
        speed = ROLES[character][2]
        dash_period = ROLES[character][3]
        shield = 20.0 if character == "robot" else 0.0
    weapons[starter if weapons.has(starter) else "pulse"] = 1
    max_health += rank * 8
    health = max_health
    damage_scale += rank * 0.04

func xp_needed() -> int:
    return 6 + (level - 1) * 4

func dash() -> void:
    if state == "playing" and dash_cooldown <= 0:
        dash_timer = 0.18
        dash_cooldown = dash_period
        effective_dashes += 1
        events.append("dash")

func step(delta: float, direction: Vector2, interacting: bool = false) -> void:
    events.clear()
    if state != "playing":
        return
    elapsed += delta
    hurt_timer = maxf(0, hurt_timer - delta)
    assault_timer = maxf(0, assault_timer - delta)
    var was_dashing := dash_timer > 0
    dash_timer = maxf(0, dash_timer - delta)
    if was_dashing and dash_timer <= 0 and role_id == "assassin":
        assault_timer = 1.2
    safe_time += delta
    if role_id == "robot" and safe_time >= 6.0:
        shield = 20.0
    update_mark(delta)
    for index in range(damage_numbers.size() - 1, -1, -1):
        damage_numbers[index]["life"] -= delta
        damage_numbers[index]["pos"].y -= delta * 28
        if damage_numbers[index]["life"] <= 0:
            damage_numbers.remove_at(index)
    dash_cooldown = maxf(0, dash_cooldown - delta)
    if direction.length_squared() > 0:
        facing = direction.normalized()
    var movement := facing if dash_timer > 0 else direction.limit_length()
    player += movement * speed * (3.7 if dash_timer > 0 else 1.0) * delta
    player = player.clamp(WORLD.position + Vector2.ONE * 28, WORLD.end - Vector2.ONE * 28)
    if elapsed >= BOSS_TIME and not boss_spawned:
        var boss_offset := Vector2(-430, 0) if player.x > 0 else Vector2(430, 0)
        spawn_enemy(4, player + boss_offset)
        boss_spawned = true
        events.append("boss")
    spawn_clock -= delta
    if spawn_clock <= 0 and elapsed < LENGTH:
        spawn_clock = maxf(0.15, 0.95 - elapsed / 850.0)
        for index in range(1 + mini(3, int(elapsed / 140))):
            if enemies.size() < 140:
                var kind := 0
                if elapsed > 22:
                    kind = rng.randi_range(0, mini(3, 1 + int(elapsed / 65)))
                var angle := rng.randf_range(0, TAU)
                var point := player + Vector2.from_angle(angle) * rng.randf_range(510, 650)
                point = point.clamp(WORLD.position + Vector2.ONE * 40, WORLD.end - Vector2.ONE * 40)
                if point.distance_to(player) < 280:
                    point = player.move_toward(WORLD.get_center(), 550)
                spawn_enemy(kind, point)
    spawn_maintenance_caches()
    facilities.update(self, delta, interacting)
    update_weapons(delta)
    update_enemies(delta)
    update_shots(delta)
    collect_loot(delta)
    for index in range(particles.size() - 1, -1, -1):
        particles[index]["life"] -= delta
        particles[index]["pos"] += particles[index]["vel"] * delta
        if particles[index]["life"] <= 0:
            particles.remove_at(index)
    for index in range(rings.size() - 1, -1, -1):
        rings[index]["life"] -= delta
        if rings[index]["life"] <= 0:
            rings.remove_at(index)
    if health <= 0:
        health = 0
        assault_timer = 0.0
        state = "lost"
        events.append("lost")
    elif elapsed >= LENGTH and boss_defeated:
        state = "won"
        events.append("won")
    elif xp >= xp_needed():
        open_upgrade()

func spawn_enemy(kind: int, point: Vector2) -> Dictionary:
    var base_hp: Array = [24.0, 15.0, 95.0, 38.0, 1900.0]
    var speeds: Array = [62.0, 112.0, 38.0, 52.0, 46.0]
    var radii: Array = [15.0, 11.0, 23.0, 17.0, 53.0]
    var hp: float = base_hp[kind] * (1.0 + elapsed / 650.0)
    var enemy := {"id": next_id, "kind": kind, "pos": point, "hp": hp, "max_hp": hp,
        "speed": speeds[kind], "radius": radii[kind], "attack": rng.randf_range(0.5, 2.0), "flash": 0.0}
    next_id += 1
    enemies.append(enemy)
    return enemy

func nearest_enemy() -> Dictionary:
    var nearest: Dictionary = {}
    var distance := 760.0 * 760.0
    for enemy in enemies:
        var current: float = player.distance_squared_to(enemy["pos"])
        if current < distance:
            distance = current
            nearest = enemy
    return nearest

func update_weapons(delta: float) -> void:
    blade_angle += delta * 2.7 * haste * part_value("orbit", "rotation")
    for key in cooldowns:
        cooldowns[key] -= delta
    if weapons["pulse"] > 0 and cooldowns["pulse"] <= 0:
        var target := nearest_enemy()
        if not target.is_empty():
            volley += 1
            var aim: Vector2 = (target["pos"] - player).normalized()
            var count := 1 + int((weapons["pulse"] - 1) / 2)
            for index in range(count):
                var angle := (index - (count - 1) / 2.0) * 0.16
                shots.append({"pos": player, "vel": aim.rotated(angle) * 590, "life": 1.4,
                    "damage": (19 + weapons["pulse"] * 7) * damage_scale * weapon_multiplier("pulse") * part_value("pulse", "damage"), "hostile": false,
                    "critical": roll_crit("pulse"), "pierce": (1 if role_id == "ranger" and volley % 4 == 0 else 0) + int(part_value("pulse", "pierce", 0)), "hits": [],
                    "bounce": installed_parts["pulse"] == "P02", "max_distance": 826.0, "traveled": 0.0})
            cooldowns["pulse"] = maxf(0.18, (0.78 - weapons["pulse"] * 0.055) / haste)
            events.append("shot")
    if weapons["orbit"] > 0 and cooldowns["orbit"] <= 0:
        var blades := blade_positions()
        for index in range(enemies.size() - 1, -1, -1):
            for blade in blades:
                if blade.distance_to(enemies[index]["pos"]) < 19 + enemies[index]["radius"]:
                    damage_enemy(index, (11 + weapons["orbit"] * 6) * damage_scale * weapon_multiplier("orbit") * part_value("orbit", "damage"), roll_crit("orbit"))
                    break
        cooldowns["orbit"] = 0.22 / haste
    if weapons["nova"] > 0 and cooldowns["nova"] <= 0 and not enemies.is_empty():
        var radius: float = (115 + weapons["nova"] * 22) * (1.0 + modules["gravity"] * 0.04) * part_value("nova", "radius")
        rings.append({"pos": player, "radius": radius, "life": 0.5, "max_life": 0.5})
        var critical := roll_crit("nova")
        for index in range(enemies.size() - 1, -1, -1):
            if player.distance_to(enemies[index]["pos"]) < radius + enemies[index]["radius"]:
                enemies[index]["pos"] += (enemies[index]["pos"] - player).normalized() * 35 * (part_value("nova", "knockback") if enemies[index]["kind"] < 4 else 1.0)
                damage_enemy(index, (30 + weapons["nova"] * 13) * damage_scale * weapon_multiplier("nova") * part_value("nova", "damage"), critical)
        cooldowns["nova"] = nova_period()
        events.append("nova")

    if weapons["turret"] > 0 and cooldowns["turret"] <= 0:
        if turrets.size() >= 2:
            turrets.remove_at(0)
        turrets.append({"pos": player + Vector2(38, 16), "life": 7.0 * (1.0 + modules["battery"] * 0.12) * part_value("turret", "lifetime"), "attack": 0.0,
            "range": 380.0 * part_value("turret", "range"),
            "period": 0.65 / haste * part_value("turret", "shot_cooldown"),
            "damage": (14 + weapons["turret"] * 6) * damage_scale * weapon_multiplier("turret") * part_value("turret", "damage")})
        cooldowns["turret"] = 8.0 / haste
    for index in range(turrets.size() - 1, -1, -1):
        var turret: Dictionary = turrets[index]
        turret["life"] -= delta
        turret["attack"] -= delta
        if turret["life"] <= 0:
            turrets.remove_at(index)
            continue
        if turret["attack"] <= 0:
            var target: Dictionary = {}
            var distance: float = turret["range"]
            for enemy in enemies:
                var current: float = turret["pos"].distance_to(enemy["pos"])
                if current < distance:
                    distance = current
                    target = enemy
            if not target.is_empty():
                var aim: Vector2 = (target["pos"] - turret["pos"]).normalized()
                shots.append({"pos": turret["pos"], "vel": aim * 490, "life": turret["range"] / 490.0, "max_distance": turret["range"], "traveled": 0.0,
                    "damage": turret["damage"],
                    "hostile": false, "critical": roll_crit("turret")})
                turret["attack"] = turret["period"]

func weapon_multiplier(kind: String) -> float:
    var role_multiplier := 1.0
    if role_id == "guard":
        role_multiplier = 1.15 if kind in ["orbit", "nova"] else 0.9
    elif role_id == "engineer" and kind == "turret":
        role_multiplier = 1.2
    var module_multiplier: float = 1.0 + (modules["lens"] * 0.08 if kind in ["pulse", "turret"] else modules["battery"] * 0.04)
    return role_multiplier * module_multiplier

func crit_chance(kind: String) -> float:
    return minf(0.35, 0.05 + modules["lens"] * 0.03 + (0.05 if kind == "pulse" else 0.0) + (0.2 if role_id == "assassin" and assault_timer > 0 and kind != "turret" else 0.0))

func roll_crit(kind: String) -> bool:
    return rng.randf() < crit_chance(kind)

func update_mark(delta: float) -> void:
    if role_id != "starmapper":
        return
    mark_remaining = maxf(0, mark_remaining - delta)
    if mark_remaining <= 0:
        mark_id = -1
    mark_clock -= delta
    if mark_clock <= 0 and not enemies.is_empty():
        var target: Dictionary = {}
        for enemy in enemies:
            if player.distance_to(enemy["pos"]) <= 760 and (target.is_empty() or enemy["kind"] > target["kind"]):
                target = enemy
        if not target.is_empty():
            mark_id = target["id"]
            mark_remaining = 4.0
            mark_clock = 6.0

func blade_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    var count: int = 1 + weapons["orbit"]
    for index in range(count):
        result.append(player + Vector2.from_angle(blade_angle + TAU * index / count) * orbit_radius())
    return result

func update_enemies(delta: float) -> void:
    for enemy in enemies:
        enemy["flash"] = maxf(0, enemy["flash"] - delta)
        var towards: Vector2 = player - enemy["pos"]
        var distance := towards.length()
        var kind: int = enemy["kind"]
        if kind != 3 or distance > 300:
            enemy["pos"] += towards.normalized() * enemy["speed"] * delta
        enemy["attack"] -= delta
        if (kind == 3 or kind == 4) and enemy["attack"] <= 0:
            enemy["attack"] = 1.45 if kind == 4 else 2.6
            var count := 12 if kind == 4 else 1
            for index in range(count):
                var angle := towards.angle() if count == 1 else TAU * index / count + elapsed * 0.3
                shots.append({"pos": enemy["pos"], "vel": Vector2.from_angle(angle) * (150 if kind == 4 else 185),
                    "life": 4.0, "damage": 17.0 if kind == 4 else 10.0, "hostile": true})
        if distance < enemy["radius"] + 13:
            hurt(24.0 if kind == 4 else (16.0 if kind == 2 else 9.0))
            enemy["pos"] -= towards.normalized() * 10

func update_shots(delta: float) -> void:
    var spawned: Array[Dictionary] = []
    for index in range(shots.size() - 1, -1, -1):
        var shot: Dictionary = shots[index]
        var start: Vector2 = shot["pos"]
        var travel: float = shot["vel"].length() * minf(delta, maxf(0, shot["life"]))
        if shot.has("max_distance"):
            travel = minf(travel, maxf(0, shot["max_distance"] - shot.get("traveled", 0.0)))
        shot["pos"] += shot["vel"].normalized() * travel
        shot["traveled"] = shot.get("traveled", 0.0) + travel
        shot["life"] -= delta
        if shot["hostile"]:
            if Geometry2D.get_closest_point_to_segment(player, start, shot["pos"]).distance_to(player) < 18:
                hurt(shot["damage"])
                shot["life"] = 0
        else:
            var hits: Array[Dictionary] = []
            for enemy in enemies:
                if enemy["id"] in shot.get("hits", []):
                    continue
                if Geometry2D.get_closest_point_to_segment(enemy["pos"], start, shot["pos"]).distance_to(enemy["pos"]) < enemy["radius"] + 7:
                    hits.append(enemy)
            hits.sort_custom(func(a, b): return start.distance_squared_to(a["pos"]) < start.distance_squared_to(b["pos"]))
            for enemy in hits:
                var enemy_index := enemies.find(enemy)
                if enemy_index < 0:
                    continue
                var point: Vector2 = enemy["pos"]
                if not shot.has("hits"):
                    shot["hits"] = []
                shot["hits"].append(enemy["id"])
                damage_enemy(enemy_index, shot["damage"], shot.get("critical", false), not shot.get("world", false))
                if shot.get("pierce", 0) > 0:
                    shot["pierce"] -= 1
                else:
                    if shot.get("bounce", false):
                        var target: Dictionary = {}
                        var distance := 220.0
                        for candidate in enemies:
                            var current: float = point.distance_to(candidate["pos"])
                            if not candidate["id"] in shot["hits"] and current < distance:
                                target = candidate
                                distance = current
                        if not target.is_empty():
                            spawned.append({"pos": point, "vel": (target["pos"] - point).normalized() * 590,
                                "life": 220.0 / 590.0, "max_distance": 220.0, "traveled": 0.0,
                                "damage": shot["damage"] * 0.6, "critical": shot.get("critical", false),
                                "hostile": false, "hits": shot["hits"].duplicate(), "bounce": false})
                    shot["life"] = 0
                    break
        if shot["life"] <= 0 or (shot.has("max_distance") and shot["traveled"] >= shot["max_distance"]):
            shots.remove_at(index)
    shots.append_array(spawned)

func part_value(weapon: String, key: String, fallback: float = 1.0) -> float:
    return Parts.DATA.get(installed_parts[weapon], {}).get(key, fallback)

func orbit_radius() -> float:
    return (72 + weapons["orbit"] * 7) * part_value("orbit", "radius")

func nova_period() -> float:
    return maxf(0.8, (3.1 - weapons["nova"] * 0.16) / haste) * part_value("nova", "cooldown")

func spawn_maintenance_caches() -> void:
    while maintenance_caches.size() < CACHE_TIMES.size() and elapsed >= CACHE_TIMES[maintenance_caches.size()]:
        var angle := maintenance_rng.randf_range(0, TAU)
        var point := player + Vector2.from_angle(angle) * maintenance_rng.randf_range(180, 260)
        point = point.clamp(WORLD.position + Vector2.ONE * 40, WORLD.end - Vector2.ONE * 40)
        maintenance_caches.append({"pos": point, "used": false, "generated": false, "offers": []})

func nearest_cache() -> int:
    var result := -1
    var distance := 80.0
    for index in range(maintenance_caches.size()):
        var cache: Dictionary = maintenance_caches[index]
        var current: float = player.distance_to(cache["pos"])
        if not cache["used"] and current < distance:
            distance = current
            result = index
    return result

func open_maintenance() -> bool:
    if state != "playing":
        return false
    var index := nearest_cache()
    if index < 0 or nearest_interaction_facility() >= 0:
        return false
    var cache: Dictionary = maintenance_caches[index]
    if not cache["generated"]:
        var pool: Array[String] = []
        for id in Parts.DATA:
            var weapon: String = Parts.DATA[id]["weapon"]
            if weapons[weapon] > 0 and installed_parts[weapon] != id:
                pool.append(id)
        for n in range(mini(3, pool.size())):
            var pick := maintenance_rng.randi_range(0, pool.size() - 1)
            cache["offers"].append(pool[pick])
            pool.remove_at(pick)
        cache["generated"] = true
    active_cache = index
    state = "maintenance"
    return true

func close_maintenance() -> void:
    if state == "maintenance":
        state = "playing"
        active_cache = -1

func claim_maintenance(part_id: String) -> bool:
    if state != "maintenance" or active_cache < 0:
        return false
    var cache: Dictionary = maintenance_caches[active_cache]
    if cache["used"]:
        return false
    if part_id == "heal":
        health = minf(max_health, health + 15.0 * (0.75 if role_id == "robot" else 1.0))
    else:
        if not part_id in cache["offers"] or not Parts.DATA.has(part_id):
            return false
        var weapon: String = Parts.DATA[part_id]["weapon"]
        if weapons[weapon] <= 0 or installed_parts[weapon] == part_id:
            return false
        var old_period := nova_period()
        installed_parts[weapon] = part_id
        if weapon == "nova":
            cooldowns[weapon] = maxf(0, cooldowns[weapon]) * nova_period() / old_period
    cache["used"] = true
    close_maintenance()
    return true

func hurt(amount: float) -> void:
    if hurt_timer > 0 or dash_timer > 0:
        return
    safe_time = 0.0
    var damage := maxf(1, amount - armor)
    var absorbed := minf(shield, damage)
    shield -= absorbed
    health -= damage - absorbed
    hurt_timer = 0.65
    burst(player, Color("ff657b"), 10)
    events.append("hurt")

func damage_enemy(index: int, amount: float, critical: bool = false, affected_by_mark: bool = true) -> void:
    var enemy: Dictionary = enemies[index]
    var actual := amount * (1.5 if critical else 1.0) * (1.25 if affected_by_mark and enemy["id"] == mark_id else 1.0)
    enemy["hp"] -= actual
    if damage_numbers.size() < 80:
        damage_numbers.append({"pos": enemy["pos"] + Vector2(-10, -25), "amount": ceili(actual), "critical": critical, "life": 0.6})
    enemy["flash"] = 0.09
    if enemy["hp"] > 0:
        return
    kills += 1
    var kind: int = enemy["kind"]
    burst(enemy["pos"], Color("f9cb70") if kind == 4 else Color("7ef0cc"), 16 if kind == 4 else 5)
    if loot.size() < 350:
        loot.append({"pos": enemy["pos"], "value": 35 if kind == 4 else (4 if kind == 2 else 1), "heal": false})
    else:
        loot[0]["value"] += 1
    if rng.randf() < 0.035:
        loot.append({"pos": enemy["pos"] + Vector2(12, 0), "value": 20, "heal": true})
    if kind == 4:
        boss_defeated = true
        events.append("boss_down")
    enemies.remove_at(index)

func collect_loot(delta: float) -> void:
    for index in range(loot.size() - 1, -1, -1):
        var item: Dictionary = loot[index]
        var distance: float = player.distance_to(item["pos"])
        if distance < magnet:
            item["pos"] = item["pos"].move_toward(player, (270 + (magnet - distance) * 3) * delta)
        if player.distance_to(item["pos"]) < 20:
            if item["heal"]:
                health = minf(max_health, health + item["value"] * (0.75 if role_id == "robot" else 1.0))
            else:
                xp += item["value"]
            loot.remove_at(index)
            events.append("pickup")

func module_slots_used() -> int:
    var used := 0
    for value in modules.values():
        if value > 0:
            used += 1
    return used

func upgrade_pool() -> Array[String]:
    var pool: Array[String] = []
    for key in weapons:
        if weapons[key] < 6:
            pool.append(key)
    for key in modules:
        if modules[key] < 3 and (modules[key] > 0 or module_slots_used() < 4):
            pool.append(key)
    return pool

func draw_upgrade_choices(previous: Array[String] = []) -> void:
    choices.clear()
    var pool := upgrade_pool()
    var preferred: Array[String] = []
    for key in pool:
        if not key in previous:
            preferred.append(key)
    # Early levels always offer at least one held weapon upgrade, even on reroll.
    if level <= 3:
        var held: Array[String] = []
        for key in weapons:
            if weapons[key] > 0 and weapons[key] < 6:
                held.append(key)
        if not held.is_empty():
            var key: String = held[rng.randi_range(0, held.size() - 1)]
            choices.append(key)
            pool.erase(key)
            preferred.erase(key)
    while choices.size() < 3 and not pool.is_empty():
        var candidates: Array[String] = preferred if not preferred.is_empty() else pool
        var total := 0
        for key in candidates:
            total += 3 if weapons.get(key, modules.get(key, 0)) > 0 else 2
        var roll := rng.randi_range(1, total)
        var pick: String = candidates[0]
        for key in candidates:
            roll -= 3 if weapons.get(key, modules.get(key, 0)) > 0 else 2
            if roll <= 0:
                pick = key
                break
        choices.append(pick)
        pool.erase(pick)
        preferred.erase(pick)
    for key in ["supply_health", "supply_power", "supply_salvage"]:
        if choices.size() < 3:
            choices.append(key)

func open_upgrade() -> void:
    xp -= xp_needed()
    level += 1
    draw_upgrade_choices()
    state = "upgrade"
    events.append("upgrade")

func reroll_upgrades() -> bool:
    if state != "upgrade" or rerolls_left <= 0:
        return false
    var previous: Array[String] = choices.duplicate()
    draw_upgrade_choices(previous)
    rerolls_left -= 1
    return true

func choose_upgrade(index: int) -> void:
    if state != "upgrade" or index < 0 or index >= choices.size():
        return
    var key := choices[index]
    if weapons.has(key):
        if weapons[key] >= 6:
            return
        weapons[key] += 1
    elif modules.has(key):
        if modules[key] >= 3 or (modules[key] == 0 and module_slots_used() >= 4):
            return
        var previous: int = modules[key]
        modules[key] += 1
        match key:
            "axle": haste = 1.0 / (1.0 - modules[key] * 0.04)
            "gravity": magnet += 25
            "fiber":
                max_health += 10
                heal_player(10)
            "lightfoot":
                speed = speed / (1.0 + previous * 0.04) * (1.0 + modules[key] * 0.04)
                dash_period = maxf(1.5, dash_period - 0.1)
    else:
        match key:
            "supply_health":
                max_health += 2
                heal_player(2)
            "supply_power": damage_scale += 0.01
            "supply_salvage": salvage_bonus += 3
    choices.clear()
    state = "playing"
    if xp >= xp_needed():
        open_upgrade()

func heal_player(amount: float) -> void:
    health = minf(max_health, health + amount * (0.75 if role_id == "robot" else 1.0))

func upgrade_level(key: String) -> int:
    return weapons.get(key, modules.get(key, 0))

func upgrade_preview(key: String) -> String:
    var lv := upgrade_level(key)
    var next := lv + 1
    match key:
        "pulse": return "单发伤害 %.1f → %.1f\n弹数 %d → %d" % [preview_damage(key, lv), preview_damage(key, next), 1 + int((lv - 1) / 2) if lv > 0 else 0, 1 + int((next - 1) / 2)]
        "orbit": return "单次伤害 %.1f → %.1f\n刀刃 %d → %d" % [preview_damage(key, lv), preview_damage(key, next), 1 + lv if lv > 0 else 0, 1 + next]
        "nova": return "爆发伤害 %.1f → %.1f\n半径 %.0f → %.0f" % [preview_damage(key, lv), preview_damage(key, next), (115 + lv * 22) * (1 + modules["gravity"] * 0.04) * part_value(key, "radius") if lv > 0 else 0, (115 + next * 22) * (1 + modules["gravity"] * 0.04) * part_value(key, "radius")]
        "turret": return "炮台单发伤害 %.1f → %.1f\n升级后新部署炮台生效" % [preview_damage(key, lv), preview_damage(key, next)]
        "lens": return "投射增伤 %d%% → %d%%；暴击 +%d → +%d 点" % [lv * 8, next * 8, lv * 3, next * 3]
        "axle": return "全局冷却缩短 %d%% → %d%%" % [lv * 4, next * 4]
        "gravity": return "拾取半径 %d → %d；新星半径 +%d%%" % [int(magnet), int(magnet) + 25, next * 4]
        "battery": return "炮台时长 +%d%% → +%d%%；范围伤害 +%d%%" % [lv * 12, next * 12, next * 4]
        "fiber": return "生命上限 %d → %d；立即恢复 %s" % [int(max_health), int(max_health) + 10, "7.5" if role_id == "robot" else "10"]
        "lightfoot": return "移速 %d → %d；冲刺 %.1fs → %.1fs" % [int(speed), int(speed / (1.0 + lv * 0.04) * (1.0 + next * 0.04)), dash_period, maxf(1.5, dash_period - 0.1)]
    return UPGRADE_INFO[key][1]

func burst(point: Vector2, color: Color, count: int) -> void:
    for index in range(count):
        if particles.size() >= 250:
            break
        particles.append({"pos": point, "vel": Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(35, 150),
            "life": rng.randf_range(0.2, 0.5), "color": color})

func nearest_interaction_facility() -> int:
    if elapsed < 90 or facilities.selected_count() >= 2:
        return -1
    var index: int = facilities.nearest(player)
    if index < 0:
        return -1
    var cache := nearest_cache()
    if cache >= 0 and player.distance_to(maintenance_caches[cache]["pos"]) <= player.distance_to(facilities.sites[index]["pos"]):
        return -1
    return index

func preview_damage(key: String, lv: int) -> float:
    if lv <= 0:
        return 0.0
    var base: float = {"pulse": 19 + lv * 7, "orbit": 11 + lv * 6, "nova": 30 + lv * 13, "turret": 14 + lv * 6}[key]
    return base * damage_scale * weapon_multiplier(key) * part_value(key, "damage")
