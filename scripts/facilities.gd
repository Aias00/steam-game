extends RefCounted

const INFO := [
    ["旧式炮塔", "激活时迎战近战守卫；完成后持续攻击附近敌人", Vector2(650, 250)],
    ["回收磁阵", "迎战远程守卫；每30秒把附近经验聚到阵旁", Vector2(-620, -430)],
    ["修复温室", "留意孢子预警；完成后每60秒产出治疗包", Vector2(-650, 280)]
]
var sites: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var hold_time := 0.0
var hold_target := -1
var capture_target := -1

func _init() -> void:
    for index in range(INFO.size()):
        sites.append({"id": index, "pos": INFO[index][2], "selected": false, "complete": false,
            "progress": 0.0, "clock": 0.0, "hazard_clock": 2.0})

func selected_count() -> int:
    var count := 0
    for site in sites:
        if site["selected"]:
            count += 1
    return count

func completed_count() -> int:
    var count := 0
    for site in sites:
        if site["complete"]:
            count += 1
    return count

func nearest(player: Vector2) -> int:
    var result := -1
    var distance := 180.0
    for index in range(sites.size()):
        var current := player.distance_to(sites[index]["pos"])
        if not sites[index]["selected"] and current < distance:
            result = index
            distance = current
    return result

func duration(role: String) -> float:
    return 14.4 if role == "engineer" else 18.0

func update(run, delta: float, interacting: bool) -> void:
    capture_target = -1
    if run.elapsed < 90:
        return
    for index in range(hazards.size() - 1, -1, -1):
        var hazard: Dictionary = hazards[index]
        hazard["time"] += delta
        if hazard["time"] >= 1.2 and not hazard["hit"]:
            hazard["hit"] = true
            if run.player.distance_to(hazard["pos"]) < 46:
                run.hurt(12)
        if hazard["time"] >= 1.7:
            hazards.remove_at(index)

    var target: int = run.nearest_interaction_facility()
    if interacting and target >= 0 and selected_count() < 2:
        if hold_target != target:
            hold_time = 0.0
        hold_target = target
        hold_time += delta
        if hold_time >= 0.6:
            select_site(run, target)
            hold_time = 0.0
            hold_target = -1
    else:
        hold_time = 0.0
        hold_target = -1
    var distance := 180.0
    for index in range(sites.size()):
        var site: Dictionary = sites[index]
        var current: float = run.player.distance_to(site["pos"])
        if site["selected"] and not site["complete"] and current < distance:
            capture_target = index
            distance = current
    if capture_target >= 0:
        var site: Dictionary = sites[capture_target]
        site["progress"] = minf(duration(run.role_id), site["progress"] + delta)
        if site["progress"] >= duration(run.role_id):
            site["complete"] = true
            site["clock"] = 0.0
            run.events.append("upgrade")
    for site in sites:
        if site["complete"]:
            update_reward(run, site, delta)
        elif site["selected"] and site["id"] == 2 and run.player.distance_to(site["pos"]) < 180:
            site["hazard_clock"] -= delta
            if site["hazard_clock"] <= 0:
                site["hazard_clock"] = 4.0
                hazards.append({"pos": run.player, "time": 0.0, "hit": false})

func select_site(run, index: int) -> void:
    if index < 0 or index >= sites.size() or selected_count() >= 2 or sites[index]["selected"]:
        return
    var site: Dictionary = sites[index]
    site["selected"] = true
    var count := 2 if index == 1 else 4
    for n in range(count):
        var point: Vector2 = site["pos"] + Vector2.from_angle(n * TAU / count) * 210
        run.spawn_enemy(3 if index == 1 else 0, point)
    run.events.append("boss")

func update_reward(run, site: Dictionary, delta: float) -> void:
    var index: int = site["id"]
    if index == 2:
        var stored := 0
        for item in run.loot:
            if item.get("facility_pack", -1) == index:
                stored += 1
        if stored >= 2:
            return
    site["clock"] += delta
    var period: float = [0.8, 30.0, 60.0][index]
    if site["clock"] < period:
        return
    if index == 0:
        var target: Dictionary = {}
        var distance := 400.0
        for enemy in run.enemies:
            var current: float = site["pos"].distance_to(enemy["pos"])
            if current < distance:
                distance = current
                target = enemy
        if target.is_empty():
            return
        run.shots.append({"pos": site["pos"], "vel": (target["pos"] - site["pos"]).normalized() * 490,
            "life": 400.0 / 490.0, "max_distance": 400.0, "traveled": 0.0,
            "damage": 18.0 + 2.0 * floor(run.elapsed / 60.0), "hostile": false, "critical": false, "world": true})
    elif index == 1:
        var count := 0
        for item in run.loot:
            if not item["heal"] and site["pos"].distance_to(item["pos"]) <= 900:
                item["pos"] = site["pos"] + Vector2.from_angle(count * 2.4) * (20 + count % 4 * 8)
                count += 1
    else:
        run.loot.append({"pos": site["pos"] + Vector2(22, 0), "value": 15, "heal": true, "facility_pack": index})
    site["clock"] = 0.0
