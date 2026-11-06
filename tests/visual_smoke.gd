extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func capture(name: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    assert(image.save_png("res://artifacts/" + name + ".png") == OK)

func run_tests() -> void:
    create_timer(30).timeout.connect(func(): quit(1))
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    scene.set_physics_process(false)
    scene.sound.muted = true
    await capture("menu")
    assert(not scene.custom_setup)
    assert(scene.buttons.size() == 3)
    scene.buttons.filter(func(b): return b.text.begins_with("直接开始"))[0].pressed.emit()
    assert(scene.run.role_id == "guard" and scene.run.weapons.orbit == 1)
    assert(scene.guide_message()[0] == "先试着移动")
    await capture("first-run-guide")
    scene.go_menu()
    scene.open_custom_setup()
    assert(scene.buttons.filter(func(b): return b.text == "返回推荐入口 [Esc]").size() == 1)
    scene.close_custom_setup()

    for id in scene.ROLE_IDS:
        scene.select_role(id)
        scene.start_run()
        assert(scene.run.role_id == id and scene.run.weapons[scene.Run.ROLES[id][4]] == 1)
        scene.run.spawn_clock = 999
        scene.run.spawn_enemy(2, Vector2(150, 0))
        scene.run.step(0.05, Vector2.ZERO)
        await capture("role-" + id)
        scene.run.enemies.clear()
        var walk_key := InputEventKey.new()
        walk_key.physical_keycode = KEY_D
        walk_key.pressed = true
        Input.parse_input_event(walk_key)
        await process_frame
        scene._physics_process(0.1)
        assert(scene.character_motion.walking)
        var frame: int = scene.character_motion.frame_index()
        await capture("walk-" + id)
        scene.character_motion.face_left = true
        await capture("walk-left-" + id)
        scene.character_motion.walking = false
        await capture("idle-left-" + id)

        scene.toggle_pause()
        scene._physics_process(0.1)
        assert(scene.character_motion.frame_index() == frame)
        scene.toggle_pause()
        walk_key.pressed = false
        Input.parse_input_event(walk_key)
        await process_frame
        scene._physics_process(0)
        assert(not scene.character_motion.walking)

        scene.go_menu()
    # Use the actual starter button's connected action.
    scene.select_role("ranger")
    scene.buttons.filter(func(b): return b.text.begins_with("开始探索"))[0].pressed.emit()
    assert(scene.screen == "game" and scene.run.weapons.pulse == 1, "Starter button")
    var initial: Vector2 = scene.run.player
    var key := InputEventKey.new()
    key.physical_keycode = KEY_D
    key.pressed = true
    Input.parse_input_event(key)
    await process_frame
    scene._physics_process(0.1)
    key.pressed = false
    Input.parse_input_event(key)
    assert(scene.run.player.x > initial.x, "Keyboard movement")
    scene.toggle_pause()
    var time: float = scene.run.elapsed
    scene._physics_process(1)
    assert(scene.run.elapsed == time, "Pause freezes timer")
    await capture("pause")
    scene.toggle_pause()
    # Render a reproducible mid-run fixture without modifying player saves.
    scene.run = scene.Run.new("pulse", 0, 777, "ranger")
    scene.run.weapons = {"pulse": 3, "orbit": 3, "nova": 2, "turret": 2}
    scene.run.health = 100000
    scene.run.max_health = 100000
    for index in range(1200):
        if scene.run.state == "upgrade":
            scene.run.choose_upgrade(0)
        scene.run.hurt_timer = 1
        var target := Vector2.from_angle(scene.run.elapsed * 0.04) * 320
        scene.run.step(0.1, (target - scene.run.player).normalized())
    scene.run.health = 72
    scene.run.max_health = 120
    scene.run.hurt_timer = 0
    scene.refresh_buttons()
    await capture("gameplay")
    scene.run.elapsed = 120
    scene.run.spawn_maintenance_caches()
    scene.run.maintenance_caches[0].pos = scene.run.player
    var interact := InputEventKey.new()
    interact.pressed = true
    interact.physical_keycode = KEY_E
    scene._unhandled_key_input(interact)
    assert(scene.run.state == "maintenance")
    var frozen: float = scene.run.elapsed
    scene._physics_process(1)
    assert(scene.run.elapsed == frozen)
    await capture("maintenance")
    scene.buttons.filter(func(b): return b.text.begins_with("选择 ·"))[0].pressed.emit()
    assert(not scene.pending_part.is_empty())
    await capture("maintenance-confirm")
    scene.buttons.filter(func(b): return b.text == "确认安装 / 替换")[0].pressed.emit()
    assert(scene.run.state == "playing" and scene.run.maintenance_caches[0].used)
    var installed := false
    for id in scene.run.installed_parts.values():
        installed = installed or not id.is_empty()
    assert(installed)
    interact.physical_keycode = KEY_TAB
    scene._unhandled_key_input(interact)
    assert(scene.run.state == "equipment")
    scene._physics_process(1)
    assert(scene.run.elapsed == frozen)
    await capture("equipment")
    scene.buttons.filter(func(b): return b.text.begins_with("返回战斗"))[0].pressed.emit()
    assert(scene.run.state == "playing")

    scene.run.xp = scene.run.xp_needed()
    scene.run.step(0, Vector2.ZERO)
    scene.refresh_buttons()
    assert(scene.run.state == "upgrade", "Upgrade menu")
    await capture("upgrade")
    var reroll: Button = scene.buttons.filter(func(b): return b.text.begins_with("重抽全部"))[0]
    reroll.pressed.emit()
    assert(scene.run.rerolls_left == 0 and scene.run.choices.size() == 3)
    await capture("upgrade-reroll")

    var upgrade_time: float = scene.run.elapsed
    scene.buttons[1].pressed.emit()
    assert(scene.run.state == "playing" and scene.run.elapsed == upgrade_time, "Upgrade button")
    scene.run.elapsed = 541
    scene.run.boss_spawned = true
    scene.run.spawn_enemy(4, scene.run.player + Vector2(260, -80))
    scene.refresh_buttons()
    await capture("boss")

    scene.run.enemies.clear()
    scene.run.shots.clear()
    scene.run.player = scene.run.facilities.sites[2].pos
    scene.run.elapsed = 120
    scene.run.boss_spawned = false
    scene.run.boss_defeated = false
    scene.run.spawn_clock = 999
    var use_key := InputEventKey.new()
    use_key.physical_keycode = KEY_E
    use_key.pressed = true
    Input.parse_input_event(use_key)
    await process_frame
    for tick in range(7):
        scene._physics_process(0.1)
    use_key.pressed = false
    Input.parse_input_event(use_key)
    await process_frame
    assert(scene.run.facilities.sites[2].selected)
    await capture("facility-capture")
    scene.run.facilities.sites[2].progress = scene.run.facilities.duration(scene.run.role_id) - 0.1
    scene._physics_process(0.11)
    assert(scene.run.facilities.sites[2].complete)
    await capture("facility-complete")
    scene.run.state = "won"
    scene.run.elapsed = 600
    scene.reward = 120
    scene.refresh_buttons()
    await capture("victory")
    scene.buttons[2].pressed.emit()
    assert(scene.screen == "menu" and scene.run == null, "Return to camp")
    var temporary_path := "user://test_app_profile_%d.cfg" % Time.get_ticks_usec()
    scene.profile = scene.Profile.new()
    scene.profile.path = temporary_path
    scene.test_mode = false
    scene.start_run()
    scene.run.health = 0
    scene._physics_process(0)
    scene._physics_process(0)
    assert(scene.profile.total_runs == 1 and scene.profile.crystals == 3, "Settle reward once")
    scene.start_run()
    assert(scene.run.health == 85 and scene.run.kills == 0 and not scene.settled, "Fresh restart")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
    print("PASS: menu starter, keyboard, pause, upgrade button, results navigation, one-time rewards, fresh restart; six-role render checks plus maintenance confirmation/equipment screenshots")
    quit(0)
