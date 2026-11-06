extends SceneTree

const Profile = preload("res://scripts/profile.gd")

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    create_timer(15).timeout.connect(func(): quit(1))
    var path := "user://test_profile_%d.cfg" % Time.get_ticks_usec()
    var profile = Profile.new()
    profile.path = path
    profile.load_profile()
    assert(profile.crystals == 0 and profile.rank == 0, "Fresh save")
    assert(not profile.buy_upgrade(), "Insufficient funds")
    var reward: int = profile.record_run(120, 80, true)
    assert(reward == 54 and profile.total_runs == 1, "Rewards")
    var restored = Profile.new()
    restored.path = path
    restored.load_profile()
    assert(restored.crystals == 54 and restored.best_kills == 80 and restored.best_seconds == 120, "Roundtrip")
    assert(restored.buy_upgrade() and restored.rank == 1 and restored.crystals == 24, "Permanent purchase")
    assert(not restored.buy_upgrade(), "Increasing cost")
    var invalid = Profile.new()
    invalid.path = "user://nonexistent_%d/save.cfg" % Time.get_ticks_usec()
    invalid.crystals = 100
    assert(not invalid.buy_upgrade() and invalid.crystals == 100 and invalid.rank == 0, "Failed purchase rolls back")
    assert(invalid.record_run(120, 80, true) == 0 and invalid.total_runs == 0 and invalid.crystals == 100, "Failed reward rolls back")
    assert(restored.record_run(0, 0, false, 13) == 16, "Facility and salvage bonuses settle once in reward transaction")
    assert(invalid.record_run(0, 0, false, 13) == 0 and invalid.crystals == 100, "Bonus rollback")
    var config := ConfigFile.new()
    config.set_value("progress", "crystals", "bad")
    config.set_value("progress", "rank", -3)
    config.set_value("progress", "best_kills", 1e20)
    assert(config.save(path) == OK)
    var corrupt = Profile.new()
    corrupt.path = path
    corrupt.load_profile()
    assert(corrupt.crystals == 0 and corrupt.rank == 0 and corrupt.best_kills <= 10000000, "Validate stored numbers")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("PASS: fresh save, rewards, roundtrip, purchase, insufficient funds, rollback, malformed values")
    quit(0)
