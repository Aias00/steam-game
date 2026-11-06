extends RefCounted

var path := "user://orbit_survivor_profile.cfg"
var crystals := 0
var rank := 0
var best_seconds := 0.0
var best_kills := 0
var total_runs := 0
var last_error := ""

func load_profile() -> void:
    var config := ConfigFile.new()
    var error := config.load(path)
    if error == ERR_FILE_NOT_FOUND:
        return
    if error != OK:
        last_error = "存档无法读取，本次使用初始进度。"
        return
    crystals = int(read_number(config, "crystals", 0, 100000000))
    rank = int(read_number(config, "rank", 0, 1000))
    best_seconds = read_number(config, "best_seconds", 0, 1000000)
    best_kills = int(read_number(config, "best_kills", 0, 10000000))
    total_runs = int(read_number(config, "total_runs", 0, 10000000))

func read_number(config: ConfigFile, key: String, minimum: int, maximum: int) -> float:
    var value: Variant = config.get_value("progress", key, 0)
    if (value is int or value is float) and is_finite(float(value)):
        return clampf(float(value), minimum, maximum)
    return 0

func save_profile() -> bool:
    var config := ConfigFile.new()
    for key in ["crystals", "rank", "best_seconds", "best_kills", "total_runs"]:
        config.set_value("progress", key, get(key))
    var temporary := path + ".tmp"
    var error := config.save(temporary)
    if error == OK:
        error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
    if error != OK:
        last_error = "存档写入失败：%s" % error_string(error)
        return false
    last_error = ""
    return true

func upgrade_cost() -> int:
    return 30 + rank * 25

func buy_upgrade() -> bool:
    var cost := upgrade_cost()
    if crystals < cost:
        return false
    crystals -= cost
    rank += 1
    if save_profile():
        return true
    rank -= 1
    crystals += cost
    return false

func record_run(seconds: float, count: int, victory: bool, bonus: int = 0) -> int:
    var old := [crystals, total_runs, best_seconds, best_kills]
    var reward := maxi(3, int(count / 4) + int(seconds / 30) + (30 if victory else 0)) + maxi(0, bonus)
    crystals += reward
    total_runs += 1
    best_seconds = maxf(best_seconds, seconds)
    best_kills = maxi(best_kills, count)
    if save_profile():
        return reward
    crystals = old[0]
    total_runs = old[1]
    best_seconds = old[2]
    best_kills = old[3]
    return 0
