extends Node2D

const CharacterMotion = preload("res://scripts/character_motion.gd")
const Run = preload("res://scripts/run.gd")
const Profile = preload("res://scripts/profile.gd")
const SteamBridge = preload("res://scripts/steam_bridge.gd")
const Sound = preload("res://scripts/sound.gd")
const INK := Color("e9f3f0")
const MUTED := Color("8daba9")
const MINT := Color("94f3c0")
const GOLD := Color("edca82")
const CORAL := Color("fc818d")
const PURPLE := Color("baa2f8")
const CENTER := Vector2(560, 420)
const WEAPON_NAMES := {"pulse": "星辉弹", "orbit": "环刃", "nova": "引力新星", "turret": "锚灯炮台"}

const ROLE_IDS := ["guard", "ranger", "engineer", "starmapper", "robot", "assassin"]
const ROLE_NOTES := ["范围伤害 +15% · 投射伤害 −10%", "每第四轮星辉弹额外穿透", "炮台伤害 +20% · 冲刺稍慢", "每6秒标记强敌 · 对其增伤25%", "脱战6秒恢复20护盾 · 治疗75%", "冲刺后1.2秒直击暴击率 +20%"]
var custom_setup := false
var guide_enabled := false
var guide_distance := 0.0
var guide_upgrade_done := false
var pending_part := ""
var selected_role := "guard"
var selected_weapon := "orbit"
var character_textures: Dictionary = {}
var walk_textures: Dictionary = {}
var character_motion = CharacterMotion.new()
var steam = SteamBridge.new()
var profile = Profile.new()
var run: RefCounted
var sound: Node
var screen := "menu"
var paused := false
var buttons: Array[Button] = []
var font: Font
var view_signature := ""
var reward := 0
var settled := false
var test_mode := false
var visual_time := 0.0

func _ready() -> void:
    font = load("res://art/fonts/NotoSansCJKsc-Regular.otf")
    for id in ROLE_IDS:
        character_textures[id] = load("res://art/runtime/characters/%s.png" % id)
        walk_textures[id] = load("res://art/runtime/characters/%s-walk.png" % id)
    steam.initialize()
    if "--test" in OS.get_cmdline_user_args():
        test_mode = true
    if not test_mode:
        profile.load_profile()
    sound = Sound.new()
    add_child(sound)
    refresh_buttons()

func start_run(starter: String = "") -> void:
    run = Run.new(selected_weapon if starter == "" else starter, profile.rank, 0, selected_role)
    character_motion = CharacterMotion.new()
    guide_enabled = profile.total_runs == 0
    guide_distance = 0.0
    guide_upgrade_done = false
    screen = "game"
    paused = false
    settled = false
    reward = 0
    refresh_buttons()

func go_menu() -> void:
    custom_setup = false
    screen = "menu"
    run = null
    paused = false
    refresh_buttons()

func buy_core() -> void:
    profile.buy_upgrade()
    refresh_buttons()

func toggle_pause() -> void:
    if screen == "game" and run.state == "playing":
        paused = not paused
        refresh_buttons()

func toggle_sound() -> void:
    sound.muted = not sound.muted
    if sound.muted:
        for voice in sound.voices:
            voice.stop()
    refresh_buttons()

func pick_upgrade(index: int) -> void:
    if run != null:
        run.choose_upgrade(index)
        guide_upgrade_done = true
        sound.play_event("upgrade")
        refresh_buttons()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if screen == "menu" and event.physical_keycode == KEY_ESCAPE and custom_setup:
        close_custom_setup()
        return
    if screen == "menu" and event.physical_keycode == KEY_ENTER and not custom_setup:
        start_recommended()
        return
    if screen == "game" and event.physical_keycode == KEY_H:
        guide_enabled = not guide_enabled
        return
    if event.physical_keycode == KEY_M:
        toggle_sound()
    elif screen == "game":
        if run.state == "maintenance":
            if event.physical_keycode == KEY_ESCAPE:
                run.close_maintenance()
                pending_part = ""
                refresh_buttons()
            return
        if run.state == "equipment":
            if event.physical_keycode in [KEY_ESCAPE, KEY_TAB]:
                toggle_equipment()
            return
        if event.physical_keycode == KEY_TAB and not paused and run.state == "playing":
            toggle_equipment()
            return
        if event.physical_keycode == KEY_E and not paused and run.open_maintenance():
            pending_part = ""
            refresh_buttons()
            return
        if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P:
            toggle_pause()
        elif event.physical_keycode == KEY_SPACE and not paused:
            run.dash()
            sound.play_event("dash")
        elif run.state == "upgrade" and event.physical_keycode == KEY_R:
            reroll_upgrades()
        elif run.state == "upgrade":
            var keys := [KEY_1, KEY_2, KEY_3]
            if event.physical_keycode in keys:
                pick_upgrade(keys.find(event.physical_keycode))
        elif run.state in ["won", "lost"] and event.physical_keycode == KEY_R:
            start_run()

func _physics_process(delta: float) -> void:
    if screen != "game" or paused or run == null:
        return
    var direction := Vector2(
        float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
        float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    )
    var old_position: Vector2 = run.player
    var was_playing: bool = run.state == "playing"
    var was_dashing: bool = run.dash_timer > 0
    run.step(delta, direction, Input.is_physical_key_pressed(KEY_E))
    if was_playing:
        guide_distance += run.player.distance_to(old_position)
        character_motion.advance(run.player - old_position, was_dashing or run.dash_timer > 0, run.hurt_timer > 0)
    for event_name in run.events:
        sound.play_event(event_name)
    if run.state in ["won", "lost"] and not settled:
        settled = true
        if not test_mode:
            reward = profile.record_run(run.elapsed, run.kills, run.state == "won", run.salvage_bonus + run.facilities.completed_count() * 5)
    var signature := current_signature()
    if signature != view_signature:
        refresh_buttons()

func _process(delta: float) -> void:
    visual_time += delta
    steam.poll()
    queue_redraw()

func current_signature() -> String:
    return screen + (str(run.state) + str(run.level) if run != null else "") + str(paused) + str(sound.muted)

func add_button(label: String, rect: Rect2, action: Callable, accent: Color = MINT, disabled: bool = false) -> void:
    var button := Button.new()
    button.text = label
    button.position = rect.position
    button.size = rect.size
    button.disabled = disabled
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_override("font", font)
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", accent)
    button.add_theme_color_override("font_hover_color", INK)
    button.add_theme_color_override("font_disabled_color", Color("56716e"))
    for mode in ["normal", "hover", "pressed", "focus", "disabled"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color("142c2c") if mode == "normal" else Color("24443f")
        if mode == "disabled":
            style.bg_color = Color("142323")
        style.border_color = accent if mode in ["hover", "focus"] else Color("36574d")
        style.set_border_width_all(2 if mode == "focus" else 1)
        style.set_corner_radius_all(8)
        button.add_theme_stylebox_override(mode, style)
    button.pressed.connect(action)
    add_child(button)
    buttons.append(button)

func refresh_buttons() -> void:
    for button in buttons:
        button.hide()
        button.queue_free()
    buttons.clear()
    view_signature = current_signature()
    add_button("静音 [M]" if not sound.muted else "声音已关 [M]", Rect2(950, 22, 140, 35), toggle_sound, MUTED)
    if screen == "menu":
        if not custom_setup:
            add_button("直接开始 · 推荐搭配 [Enter]", Rect2(62, 420, 430, 62), start_recommended)
            add_button("自定义角色与武器", Rect2(62, 503, 310, 44), open_custom_setup, MUTED)
            if profile.total_runs > 0:
                add_button("营地核心 Lv.%d · 强化 %d 星砂" % [profile.rank, profile.upgrade_cost()], Rect2(62, 630, 430, 44), buy_core, GOLD, profile.crystals < profile.upgrade_cost())
            return
        add_button("返回推荐入口 [Esc]", Rect2(840, 287, 222, 43), close_custom_setup, MUTED)
        for index in range(6):
            var id: String = ROLE_IDS[index]
            add_button(("✓ " if id == selected_role else "") + Run.ROLES[id][0], Rect2(58 + (index % 3) * 337, 360 + (index / 3) * 55, 310, 45), select_role.bind(id), GOLD if id == selected_role else MUTED)
            buttons.back().icon = character_textures[id]
            buttons.back().expand_icon = true
            buttons.back().add_theme_constant_override("icon_max_width", 36)
        var starters := ["pulse", "orbit", "nova", "turret"]
        for index in range(4):
            var key: String = starters[index]
            add_button(("✓ " if key == selected_weapon else "") + WEAPON_NAMES[key], Rect2(58 + index * 253, 486, 236, 42), select_weapon.bind(key), GOLD if key == selected_weapon else MUTED)
        add_button("开始探索 · " + Run.ROLES[selected_role][0], Rect2(690, 625, 372, 48), start_run)
        add_button("强化核心  ·  %d 星砂" % profile.upgrade_cost(), Rect2(58, 625, 310, 48), buy_core, GOLD, profile.crystals < profile.upgrade_cost())
    elif run.state == "maintenance":
        var cache: Dictionary = run.maintenance_caches[run.active_cache]
        for index in range(cache["offers"].size()):
            var id: String = cache["offers"][index]
            var info: Dictionary = Run.Parts.DATA[id]
            add_button(("✓ " if pending_part == id else "") + "选择 · " + info["name"], Rect2(65 + index * 335, 370, 320, 45), select_part.bind(id), GOLD if pending_part == id else MINT, run.installed_parts[info["weapon"]] == id)
        add_button("确认安装 / 替换", Rect2(65, 574, 310, 46), confirm_part, GOLD, pending_part.is_empty())
        add_button(("维修包 · 恢复11.25生命" if run.role_id == "robot" else "维修包 · 恢复15生命") if run.health < run.max_health else "维修包 · 当前满血，无回复", Rect2(400, 574, 320, 46), claim_repair, MINT)
        add_button("取消 · 稍后再来 [Esc]", Rect2(745, 574, 310, 46), cancel_maintenance, MUTED)
    elif run.state == "equipment":
        add_button("返回战斗 [Tab / Esc]", Rect2(380, 614, 360, 46), toggle_equipment)
    elif run.state == "upgrade":
        for index in range(run.choices.size()):
            add_button("选择此强化  [%d]" % (index + 1), Rect2(79 + index * 326, 493, 310, 50), pick_upgrade.bind(index), [MINT, GOLD, PURPLE][index])
        add_button("重抽全部 [R] · 剩余 %d 次" % run.rerolls_left, Rect2(380, 558, 360, 43), reroll_upgrades, GOLD, run.rerolls_left <= 0)
    elif run.state in ["won", "lost"]:
        add_button("再来一局  [R]", Rect2(330, 518, 220, 52), start_run, MINT)
        add_button("返回营地", Rect2(570, 518, 220, 52), go_menu, GOLD)
    elif paused:
        add_button("继续探索  [P]", Rect2(380, 387, 360, 52), toggle_pause)
        add_button("放弃本局 · 返回营地", Rect2(380, 457, 360, 52), go_menu, CORAL)
    else:
        add_button("暂停 [P]", Rect2(840, 22, 100, 35), toggle_pause, MUTED)

func text_at(value: String, point: Vector2, size: int = 18, color: Color = INK) -> void:
    draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, fill: Color = Color("102323"), border: Color = Color("2c4941")) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    draw_style_box(style, rect)

func bar(rect: Rect2, ratio: float, color: Color) -> void:
    draw_rect(rect, Color("1c3031"))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)), color)

func diamond(point: Vector2, radius: float, color: Color) -> void:
    draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius * 0.7, 0), point + Vector2(0, radius), point + Vector2(-radius * 0.7, 0)]), color)

func timer_label(seconds: float) -> String:
    return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1120, 760), Color("071413"))
    if screen == "menu":
        draw_menu()
    elif run != null:
        draw_world()
        draw_hud()
        if run.state == "maintenance":
            draw_maintenance()
        elif run.state == "equipment":
            draw_equipment()
        elif run.state == "upgrade":
            draw_upgrades()
        elif run.state in ["won", "lost"]:
            draw_results()
        elif paused:
            draw_rect(Rect2(0, 0, 1120, 760), Color(0.02, 0.06, 0.06, 0.86))
            text_at("时光暂歇", Vector2(435, 305), 42, MINT)
            text_at("战斗、弹幕与计时均已暂停", Vector2(414, 350), 18, MUTED)
    draw_rect(Rect2(0, 734, 1120, 26), Color("081211"))
    draw_circle(Vector2(24, 747), 3, MINT if steam.connected else MUTED)
    text_at(steam.status.left(115), Vector2(36, 752), 12, MUTED)

func draw_menu() -> void:
    for index in range(65):
        var point := Vector2(fmod(index * 139.7, 1120), fmod(index * 83.3 + visual_time * (2 + index % 4), 730))
        draw_circle(point, 1 + index % 2, Color(0.5, 0.8, 0.6, 0.12 + sin(visual_time + index) * 0.06))
    for radius in [145, 185, 245, 310]:
        draw_arc(Vector2(925, 190), radius, 0, TAU, 100, Color(0.6, 0.85, 0.6, 0.07), 1, true)
    draw_arc(Vector2(925, 190), 94, visual_time * 0.15, visual_time * 0.15 + PI * 1.55, 70, GOLD, 2, true)
    text_at("ORBIT / SURVIVOR     ·     原生 Godot 肉鸽生存", Vector2(58, 48), 14, MINT)
    text_at("星环余烬", Vector2(55, 151), 76)
    text_at("在失落的观测站，守住最后一束星光。", Vector2(62, 205), 23, MUTED)
    text_at("10 分钟生存   /   自动攻击   /   随机强化   /   核心守卫", Vector2(62, 249), 17, GOLD)
    if not custom_setup:
        draw_simple_menu()
        return
    text_at("自定义搭配 · 不确定时使用推荐即可", Vector2(58, 305), 20)
    text_at(ROLE_NOTES[ROLE_IDS.find(selected_role)], Vector2(58, 340), 18, GOLD)
    draw_texture_rect(character_textures[selected_role], Rect2(867, 90, 150, 150), false)
    draw_line(Vector2(58, 568), Vector2(1062, 568), Color("2c4941"))
    text_at("营地核心  Lv.%d" % profile.rank, Vector2(58, 607), 20, GOLD)
    text_at("星砂  %d" % profile.crystals, Vector2(415, 607), 22, GOLD)
    text_at("每级：生命 +8 / 伤害 +4%", Vector2(58, 700), 15, MUTED)
    text_at("最佳生存  " + timer_label(profile.best_seconds), Vector2(415, 650), 17, MUTED)
    text_at("最高击败  %d     已完成  %d 局" % [profile.best_kills, profile.total_runs], Vector2(415, 685), 17, MUTED)
    text_at("WASD 移动 · 空格冲刺", Vector2(790, 610), 17)
    text_at("1 / 2 / 3 选择强化 · P 暂停", Vector2(790, 646), 16, MUTED)
    text_at("击败敌人 → 拾取经验 → 三选一升级", Vector2(790, 682), 14, MUTED)
    if not profile.last_error.is_empty():
        text_at(profile.last_error, Vector2(58, 725), 13, CORAL)

func weapon_icon(point: Vector2, kind: int, color: Color, scale_factor: float) -> void:
    if kind == 0:
        draw_line(point - Vector2(18, -10) * scale_factor, point + Vector2(18, -10) * scale_factor, color, 4, true)
        diamond(point + Vector2(7, -5), 7 * scale_factor, INK)
    elif kind == 1:
        draw_arc(point, 18 * scale_factor, 0, TAU, 30, color, 2, true)
        diamond(point + Vector2(18, 0) * scale_factor, 8 * scale_factor, color)
        diamond(point - Vector2(18, 0) * scale_factor, 8 * scale_factor, color)
    elif kind == 3:
        draw_line(point + Vector2(-17, 18) * scale_factor, point + Vector2(0, -12) * scale_factor, color, 2, true)
        draw_line(point + Vector2(17, 18) * scale_factor, point + Vector2(0, -12) * scale_factor, color, 2, true)
        draw_circle(point + Vector2(0, -6) * scale_factor, 10 * scale_factor, color)
        draw_circle(point + Vector2(0, -6) * scale_factor, 4 * scale_factor, INK)
    else:
        for radius in [8, 16, 23]:
            draw_arc(point, radius * scale_factor, -PI, PI, 36, Color(color, 0.95 - radius * 0.02), 2, true)

func draw_world() -> void:
    var camera_offset := world_offset()
    var camera_position := CENTER - camera_offset
    draw_set_transform(camera_offset)
    draw_rect(Run.WORLD, Color("102422"))
    var left := int((camera_position.x - 600) / 80.0) * 80 - 80
    var top := int((camera_position.y - 430) / 80.0) * 80 - 80
    for x in range(left, left + 1360, 80):
        for y in range(top, top + 1040, 80):
            var tile := Rect2(x + 2, y + 2, 76, 76)
            if Run.WORLD.has_point(tile.position):
                var variation := posmod(x * 31 + y * 73, 7)
                draw_rect(tile, Color("142a27") if variation < 3 else Color("122724"))
                if variation == 0:
                    draw_line(Vector2(x + 12, y + 60), Vector2(x + 20, y + 45), Color("28503a"), 2)
                    draw_line(Vector2(x + 20, y + 58), Vector2(x + 26, y + 50), Color("28503a"), 2)
                if variation == 4:
                    draw_line(Vector2(x + 40, y), Vector2(x + 36, y + 18), Color("203a34"), 1)
    draw_arc(Vector2.ZERO, 190, 0, TAU, 100, Color("355044"), 3, true)
    draw_arc(Vector2.ZERO, 174, 0, TAU, 100, Color("29453b"), 1, true)
    for index in range(8):
        var point := Vector2.from_angle(index * TAU / 8) * 190
        diamond(point, 7, Color("55765a"))
    draw_rect(Run.WORLD, Color("5b7a63"), false, 8)
    draw_facilities()
    for cache in run.maintenance_caches:
        var point: Vector2 = cache["pos"]
        draw_ellipse_shadow(point, 20)
        draw_line(point + Vector2(-17, 14), point + Vector2(-13, -20), MUTED if cache["used"] else GOLD, 3)
        draw_line(point + Vector2(17, 14), point + Vector2(13, -20), MUTED if cache["used"] else GOLD, 3)
        draw_rect(Rect2(point + Vector2(-22, -19), Vector2(44, 12)), Color("62745c") if cache["used"] else GOLD)
        text_at("已使用" if cache["used"] else "随行维修架", point + Vector2(-35, -30), 13, MUTED if cache["used"] else GOLD)
    for item in run.loot:
        var point: Vector2 = item["pos"]
        draw_circle(point, 10, Color(0.4, 0.9, 0.7, 0.08))
        if item["heal"]:
            draw_line(point - Vector2(5, 0), point + Vector2(5, 0), CORAL, 3)
            draw_line(point - Vector2(0, 5), point + Vector2(0, 5), CORAL, 3)
        else:
            diamond(point, 6 if item["value"] < 4 else 9, MINT)
    for ring in run.rings:
        var progress: float = 1 - ring["life"] / ring["max_life"]
        draw_circle(ring["pos"], ring["radius"] * progress, Color(0.65, 0.5, 1, 0.07 * (1 - progress)))
        draw_arc(ring["pos"], maxf(1, ring["radius"] * progress), 0, TAU, 80, Color(PURPLE, 1 - progress), 3, true)
    for enemy in run.enemies:
        draw_enemy(enemy)
    for shot in run.shots:
        var point: Vector2 = shot["pos"]
        var color := CORAL if shot["hostile"] else GOLD
        draw_circle(point, 10, Color(color, 0.08))
        if shot["hostile"]:
            draw_circle(point, 5, color)
            draw_circle(point - Vector2(1, 1), 2, INK)
        else:
            draw_line(point - shot["vel"].normalized() * 17, point, color, 3, true)
            draw_circle(point, 3, INK)
    if run.weapons["orbit"] > 0:
        draw_arc(run.player, run.orbit_radius(), 0, TAU, 60, Color(GOLD, 0.1), 1, true)
        for blade in run.blade_positions():
            draw_circle(blade, 16, Color(GOLD, 0.1))
            diamond(blade, 12, GOLD)
    draw_player()
    for turret in run.turrets:
        var base: Vector2 = turret["pos"]
        draw_line(base + Vector2(-12, 12), base + Vector2(0, -8), GOLD, 3)
        draw_line(base + Vector2(12, 12), base + Vector2(0, -8), GOLD, 3)
        draw_circle(base + Vector2(0, -8), 10, Color("657961"))
        draw_circle(base + Vector2(0, -8), 4, GOLD)
    for number in run.damage_numbers:
        text_at(("✦ " if number["critical"] else "") + str(number["amount"]), number["pos"], 19 if number["critical"] else 14, GOLD if number["critical"] else INK)
    for particle in run.particles:
        draw_circle(particle["pos"], 2, Color(particle["color"], minf(1, particle["life"] * 3)))
    draw_set_transform(Vector2.ZERO)
    draw_rect(Rect2(0, 0, 1120, 100), Color(0.02, 0.07, 0.07, 0.95))
    draw_rect(Rect2(0, 666, 1120, 68), Color(0.02, 0.07, 0.07, 0.95))

func draw_enemy(enemy: Dictionary) -> void:
    var point: Vector2 = enemy["pos"]
    var kind: int = enemy["kind"]
    var radius: float = enemy["radius"]
    var color: Color = [Color("91bb8a"), CORAL, Color("d2a268"), PURPLE, GOLD][kind]
    if enemy["flash"] > 0:
        color = INK
    if enemy["id"] == run.mark_id:
        draw_arc(point, radius + 7, 0, TAU, 30, MINT, 2, true)
    draw_ellipse_shadow(point, radius)
    if kind == 0:
        draw_colored_polygon(PackedVector2Array([point + Vector2(-15, 10), point + Vector2(-11, -10), point + Vector2(0, -19), point + Vector2(11, -10), point + Vector2(15, 10)]), Color("17352b"))
        draw_arc(point, 13, PI, TAU, 20, color, 3, true)
        draw_circle(point + Vector2(-5, -2), 3, color)
        draw_circle(point + Vector2(5, -2), 3, color)
    elif kind == 1:
        var aim: Vector2 = (run.player - point).normalized()
        var side := aim.orthogonal()
        draw_colored_polygon(PackedVector2Array([point + aim * 17, point - aim * 11 + side * 10, point - aim * 5, point - aim * 11 - side * 10]), color)
    elif kind == 2:
        draw_rect(Rect2(point - Vector2(20, 18), Vector2(40, 36)), Color("6e5742"))
        draw_rect(Rect2(point - Vector2(16, 21), Vector2(32, 28)), color)
        draw_line(point + Vector2(-9, -5), point + Vector2(9, -5), Color("382f28"), 4)
        draw_circle(point + Vector2(0, -5), 3, GOLD)
    elif kind == 3:
        diamond(point, 23, Color("43365e"))
        draw_arc(point, 17, 0, TAU, 30, color, 2, true)
        draw_circle(point, 5, color)
        draw_line(point + Vector2(-22, 0), point + Vector2(22, 0), color, 2, true)
    else:
        draw_circle(point, 54, Color("302e26"))
        draw_arc(point, 53, visual_time * 0.3, visual_time * 0.3 + TAU * 0.85, 60, GOLD, 4, true)
        for index in range(6):
            var offset := Vector2.from_angle(index * TAU / 6 + run.elapsed * 0.4) * 39
            diamond(point + offset, 10, CORAL)
        diamond(point, 28, GOLD)
        draw_circle(point, 8, CORAL)
    if enemy["hp"] < enemy["max_hp"] and kind != 4:
        bar(Rect2(point.x - radius, point.y - radius - 12, radius * 2, 3), enemy["hp"] / enemy["max_hp"], CORAL)

func world_offset() -> Vector2:
    return CENTER - run.player.clamp(Vector2(-840, -680), Vector2(840, 754))

func draw_ellipse_shadow(point: Vector2, radius: float) -> void:
    draw_set_transform(world_offset() + point + Vector2(0, 9), 0, Vector2(1, 0.38))
    draw_circle(Vector2.ZERO, radius + 3, Color(0.01, 0.04, 0.04, 0.5))
    draw_set_transform(world_offset())

func draw_player() -> void:
    var point: Vector2 = run.player
    draw_ellipse_shadow(point, 19)
    if run.dash_timer > 0:
        for index in range(1, 5):
            draw_circle(point - run.facing * index * 17, 14 - index * 2, Color(MINT, 0.2 - index * 0.035))
    if run.hurt_timer > 0 and int(run.hurt_timer * 20) % 2 == 0:
        return
    if run.role_id == "robot" and run.shield > 0:
        draw_arc(point + Vector2(0, -12), 34, 0, TAU, 40, Color(0.4, 0.8, 0.85, 0.5), 2, true)
    if run.assault_timer > 0:
        draw_arc(point, 24, 0, PI * 1.5, 24, MINT, 2, true)
    var texture: Texture2D = character_textures[run.role_id]
    var tint := Color(1, 0.65, 0.65) if run.hurt_timer > 0 else Color.WHITE
    # Mirror around the world-space foot anchor, never shift the destination.
    draw_set_transform(world_offset() + point, 0, Vector2(-1 if character_motion.face_left else 1, 1))
    var destination := Rect2(Vector2(-48, -76), Vector2(96, 96))
    if character_motion.walking:
        var sheet: Texture2D = walk_textures[run.role_id]
        var frame_size := Vector2(sheet.get_width() / 4.0, sheet.get_height())
        draw_texture_rect_region(sheet, destination, Rect2(Vector2(character_motion.frame_index() * frame_size.x, 0), frame_size), tint)
    else:
        draw_texture_rect(texture, destination, false, tint)
    draw_set_transform(world_offset())

func select_role(id: String) -> void:
    custom_setup = true
    selected_role = id
    selected_weapon = Run.ROLES[id][4]
    refresh_buttons()

func select_weapon(id: String) -> void:
    selected_weapon = id
    refresh_buttons()

func draw_hud() -> void:
    text_at(Run.ROLES[run.role_id][0], Vector2(27, 38), 24)
    text_at("LV. %02d" % run.level, Vector2(190, 38), 20, MINT)
    text_at("击败 %d" % run.kills, Vector2(291, 38), 18, MUTED)
    text_at(timer_label(run.elapsed), Vector2(505, 45), 34, GOLD)
    text_at("/ 10:00", Vector2(608, 43), 17, MUTED)
    bar(Rect2(27, 63, 280, 10), run.health / run.max_health, CORAL)
    text_at("%d / %d" % [ceili(run.health), int(run.max_health)], Vector2(321, 74), 14, CORAL)
    bar(Rect2(0, 92, 1120, 5), float(run.xp) / run.xp_needed(), MINT)
    text_at("经验 %d / %d" % [run.xp, run.xp_needed()], Vector2(451, 80), 12, MUTED)
    if run.role_id == "robot":
        text_at("护盾 %d / 20" % run.shield, Vector2(27, 87), 12, MINT)
    elif run.assault_timer > 0:
        text_at("突袭 %.1fs" % run.assault_timer, Vector2(27, 87), 12, GOLD)
    var wave := "核心守卫正在苏醒…" if run.elapsed >= 510 else "第 %d 波 · %s" % [1 + int(run.elapsed / 30), ["迷途回声", "疾行者", "铁甲与术士", "星潮来袭"][mini(3, int(run.elapsed / 65))]]
    if run.boss_defeated:
        wave = "核心守卫已击败 · 坚持至 10:00"
    elif run.boss_spawned:
        wave = "终局 · 击败核心守卫"
    text_at(wave, Vector2(701, 78), 16, GOLD)
    if run.boss_spawned and not run.boss_defeated:
        for enemy in run.enemies:
            if enemy["kind"] == 4:
                panel(Rect2(275, 111, 570, 49), Color("15231f"))
                text_at("观测站 · 核心守卫", Vector2(295, 132), 14, GOLD)
                bar(Rect2(295, 140, 530, 7), enemy["hp"] / enemy["max_hp"], GOLD)
                break
    var index := 0
    for key in WEAPON_NAMES:
        var x := 20 + index * 145
        weapon_icon(Vector2(x + 15, 697), index, [MINT, GOLD, PURPLE, GOLD][index], 0.55)
        text_at(WEAPON_NAMES[key], Vector2(x + 41, 692), 16, INK if run.weapons[key] > 0 else MUTED)
        text_at("Lv.%d" % run.weapons[key] if run.weapons[key] > 0 else "未解锁", Vector2(x + 41, 713), 12, MUTED)
        var part: String = run.installed_parts[key]
        if not part.is_empty():
            text_at("⬡ " + Run.Parts.DATA[part]["name"], Vector2(x + 41, 728), 10, GOLD)
        index += 1
    var dash_ready: bool = run.dash_cooldown <= 0
    text_at("空格 · 冲刺" if dash_ready else "冲刺 %.1fs" % run.dash_cooldown, Vector2(625, 693), 17, MINT if dash_ready else MUTED)
    bar(Rect2(625, 705, 115, 4), 1 - run.dash_cooldown / run.dash_period, MINT)
    text_at("WASD / 方向键移动", Vector2(849, 693), 16, MUTED)
    text_at("Tab 装备 · P 暂停 · M 静音", Vector2(849, 715), 13, MUTED)
    # Small local radar keeps off-screen threats and the arena boundary legible.
    panel(Rect2(972, 115, 122, 94), Color(0.04, 0.11, 0.1, 0.88))
    for enemy in run.enemies:
        var relative: Vector2 = (enemy["pos"] - run.player) * 0.055
        if absf(relative.x) < 52 and absf(relative.y) < 36:
            draw_circle(Vector2(1033, 162) + relative, 3 if enemy["kind"] == 4 else 1.5, CORAL)
    draw_circle(Vector2(1033, 162), 3, MINT)
    for site in run.facilities.sites:
        if run.elapsed < 90:
            continue
        var relative: Vector2 = ((site["pos"] - run.player) * 0.055).clamp(Vector2(-50, -34), Vector2(50, 34))
        var color := MINT if site["complete"] else GOLD if site["selected"] else MUTED
        diamond(Vector2(1033, 162) + relative, 4, color)
    draw_objective_hud()
    for cache in run.maintenance_caches:
        if not cache["used"]:
            var relative: Vector2 = ((cache["pos"] - run.player) * 0.055).clamp(Vector2(-50, -34), Vector2(50, 34))
            diamond(Vector2(1033, 162) + relative, 4, GOLD)
            var marker: Vector2 = (cache["pos"] + world_offset()).clamp(Vector2(45, 180), Vector2(915, 625))
            text_at("维修架 %dm" % int(run.player.distance_to(cache["pos"])), marker + Vector2(-25, -42), 12, GOLD)
    if run.nearest_cache() >= 0 and run.nearest_interaction_facility() < 0:
        panel(Rect2(340, 602, 440, 42))
        text_at("[E] 打开随行维修架 · 装配时暂停战斗", Vector2(360, 629), 17, GOLD)

func draw_upgrades() -> void:
    draw_rect(Rect2(0, 0, 1120, 734), Color(0.02, 0.06, 0.06, 0.9))
    text_at("星光汇聚", Vector2(443, 203), 42, MINT)
    text_at("战斗已暂停，先升级手中的武器即可" if guide_enabled and not guide_upgrade_done else "等级 %d · 选择一项强化，战斗已暂停" % run.level, Vector2(374, 247), 19, MUTED)
    for index in range(run.choices.size()):
        var key: String = run.choices[index]
        var info: Array = Run.UPGRADE_INFO[key]
        var x := 79 + index * 326
        var accent: Color = [MINT, GOLD, PURPLE][index]
        panel(Rect2(x, 285, 310, 190), Color("102624"), accent.darkened(0.5))
        text_at("0%d  /  %s" % [index + 1, "武器强化" if run.weapons.has(key) else "模块" if run.modules.has(key) else "补给"], Vector2(x + 22, 319), 14, accent)
        text_at(info[0], Vector2(x + 22, 368), 28, accent)
        wrapped_text(run.upgrade_preview(key), Vector2(x + 22, 406), 264, 16)
        if run.weapons.has(key) or run.modules.has(key):
            var level: int = run.upgrade_level(key)
            text_at("Lv.%d → %d" % [level, level + 1], Vector2(x + 188, 319), 13, accent)
    text_at("模块 %d / 4 槽 · 每种最多3级；武器最多6级。配件不占模块槽。" % run.module_slots_used(), Vector2(265, 630), 16, MUTED)
    text_at("随机候选会随持有装备、空槽与等级变化；前两次保证有已持武器升级。", Vector2(265, 662), 15, MUTED)

func draw_results() -> void:
    draw_rect(Rect2(0, 0, 1120, 734), Color(0.02, 0.06, 0.06, 0.91))
    panel(Rect2(269, 170, 582, 435))
    var won: bool = run.state == "won"
    text_at("星光长存" if won else "余烬未熄", Vector2(442, 244), 44, MINT if won else GOLD)
    text_at("核心守卫已击败，观测站重获新生。" if won else "带回星砂，下一次将走得更远。", Vector2(375, 292), 19, MUTED)
    text_at("生存时间", Vector2(325, 357), 17, MUTED)
    text_at(timer_label(run.elapsed), Vector2(325, 398), 31)
    text_at("击败敌人", Vector2(507, 357), 17, MUTED)
    text_at(str(run.kills), Vector2(507, 398), 31)
    text_at("角色等级", Vector2(689, 357), 17, MUTED)
    text_at(str(run.level), Vector2(689, 398), 31)
    text_at("本次带回  +%d 星砂" % reward, Vector2(420, 461), 23, GOLD)
    if not profile.last_error.is_empty():
        text_at(profile.last_error, Vector2(320, 494), 15, CORAL)

func select_part(id: String) -> void:
    pending_part = id
    refresh_buttons()

func confirm_part() -> void:
    if run.claim_maintenance(pending_part):
        pending_part = ""
        refresh_buttons()

func claim_repair() -> void:
    if run.claim_maintenance("heal"):
        pending_part = ""
        refresh_buttons()

func cancel_maintenance() -> void:
    run.close_maintenance()
    pending_part = ""
    refresh_buttons()

func toggle_equipment() -> void:
    run.state = "playing" if run.state == "equipment" else "equipment"
    refresh_buttons()

func wrapped_text(value: String, point: Vector2, width: float, size: int = 17, color: Color = MUTED) -> void:
    var line := ""
    var y := point.y
    for character in value:
        if character == "\n":
            text_at(line, Vector2(point.x, y), size, color)
            y += size + 9
            line = ""
            continue
        if font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
            text_at(line, Vector2(point.x, y), size, color)
            y += size + 9
            line = ""
        line += character
    if not line.is_empty():
        text_at(line, Vector2(point.x, y), size, color)

func draw_maintenance() -> void:
    draw_rect(Rect2(0, 0, 1120, 734), Color(0.02, 0.06, 0.06, 0.96))
    text_at("随行维护 / 选择一个配件", Vector2(65, 106), 34, GOLD)
    text_at("战斗已冻结 · 每把武器一个槽 · 每架仅领取一次 · 取消不消耗", Vector2(65, 145), 17, MUTED)
    var cache: Dictionary = run.maintenance_caches[run.active_cache]
    text_at("当前可用配件 %d 项；选中后确认安装，或领取维修包。" % cache["offers"].size(), Vector2(65, 181), 16, MUTED)
    for index in range(cache["offers"].size()):
        var id: String = cache["offers"][index]
        var info: Dictionary = Run.Parts.DATA[id]
        var x := 65 + index * 335
        panel(Rect2(x, 207, 320, 150), Color("142c2c"), GOLD if pending_part == id else MUTED.darkened(0.5))
        text_at(info["name"], Vector2(x + 20, 242), 24, GOLD)
        text_at("仅 " + WEAPON_NAMES[info["weapon"]] + " 生效", Vector2(x + 20, 273), 15, MINT)
        wrapped_text(info["note"], Vector2(x + 20, 305), 280, 16)
    if not pending_part.is_empty():
        var info: Dictionary = Run.Parts.DATA[pending_part]
        var old: String = run.installed_parts[info["weapon"]]
        text_at(WEAPON_NAMES[info["weapon"]] + "：" + ("空槽" if old.is_empty() else Run.Parts.DATA[old]["name"]) + " → " + info["name"], Vector2(65, 460), 23, GOLD)
        text_at("旧配件拆除后不保留；已发射子弹和已部署炮台不受影响。", Vector2(65, 502), 18, MUTED)
        text_at("下一轮攻击或下一座炮台生效；不重置当前冷却。", Vector2(65, 534), 18, MUTED)
    else:
        text_at("选择配件查看替换结果；每种配件只作用于卡片所示武器。", Vector2(65, 474), 19, MUTED)
    text_at("维护机会：2:00 / 4:30 / 7:00 · 维修架会一直保留，不必立即使用", Vector2(65, 675), 16, MUTED)

func draw_equipment() -> void:
    draw_rect(Rect2(0, 0, 1120, 734), Color(0.02, 0.06, 0.06, 0.96))
    text_at("装备档案 / 当前构筑", Vector2(65, 115), 36, GOLD)
    text_at("战斗暂停 · 配件只改变绑定武器，不占经验升级候选", Vector2(65, 156), 18, MUTED)
    var index := 0
    for key in WEAPON_NAMES:
        var y := 190 + index * 86
        panel(Rect2(65, y, 990, 76))
        text_at(WEAPON_NAMES[key] + "  Lv.%d" % run.weapons[key], Vector2(85, y + 31), 22, MINT if run.weapons[key] > 0 else MUTED)
        var id: String = run.installed_parts[key]
        text_at("空配件槽" if id.is_empty() else Run.Parts.DATA[id]["name"], Vector2(330, y + 31), 20, GOLD)
        text_at("未装配 · 靠近维修架按 E 选择" if id.is_empty() else Run.Parts.DATA[id]["note"], Vector2(330, y + 60), 16, MUTED)
        index += 1

    var labels: Array[String] = []
    for key in run.modules:
        if run.modules[key] > 0:
            labels.append(Run.UPGRADE_INFO[key][0] + " Lv.%d" % run.modules[key])
    text_at("模块 %d / 4：" % run.module_slots_used() + ("尚未装备" if labels.is_empty() else " · ".join(labels)), Vector2(65, 573), 18, GOLD)
    var facilities: Array[String] = []
    for site in run.facilities.sites:
        facilities.append(Run.Facilities.INFO[site["id"]][0] + (" 已启用" if site["complete"] else " 占点中" if site["selected"] else " 未选") + " %dm" % int(run.player.distance_to(site["pos"])))
    text_at("设施：" + " / ".join(facilities), Vector2(65, 601), 13, MUTED)


func reroll_upgrades() -> void:
    if run.reroll_upgrades():
        refresh_buttons()

func draw_facilities() -> void:
    if run.elapsed < 90:
        return
    for site in run.facilities.sites:
        var point: Vector2 = site["pos"]
        var color := MINT if site["complete"] else GOLD if site["selected"] else MUTED
        draw_arc(point, 180, 0, TAU, 64, Color(color, 0.23), 2, true)
        draw_ellipse_shadow(point, 30)
        if site["id"] == 0:
            draw_rect(Rect2(point - Vector2(24, 20), Vector2(48, 40)), Color("4d6156"))
            draw_circle(point - Vector2(0, 10), 18, color)
            draw_line(point - Vector2(0, 10), point + Vector2(30, -18), color, 9, true)
        elif site["id"] == 1:
            for radius in [18, 30, 42]:
                draw_arc(point, radius, 0, TAU, 32, color, 2, true)
            diamond(point, 10, color)
        else:
            draw_colored_polygon(PackedVector2Array([point + Vector2(-34, 20), point + Vector2(-34, -8), point + Vector2(0, -35), point + Vector2(34, -8), point + Vector2(34, 20)]), Color("3c6051"))
            draw_line(point + Vector2(-15, 5), point + Vector2(15, 5), color, 3)
            draw_line(point + Vector2(0, -10), point + Vector2(0, 20), color, 3)
        text_at(Run.Facilities.INFO[site["id"]][0], point + Vector2(-38, -51), 17, color)
        if site["selected"] and not site["complete"]:
            bar(Rect2(point + Vector2(-50, -42), Vector2(100, 5)), site["progress"] / run.facilities.duration(run.role_id), GOLD)
        if not site["selected"] and run.facilities.selected_count() >= 2:
            text_at("本局未选定", point + Vector2(-36, 48), 13, MUTED)
    for hazard in run.facilities.hazards:
        var point: Vector2 = hazard["pos"]
        draw_circle(point, 46, Color(1.0, 0.3, 0.4, 0.12 if hazard["time"] < 1.2 else 0.4))
        draw_arc(point, 46, 0, TAU, 36, CORAL, 2, true)
        if hazard["time"] < 1.2:
            draw_arc(point, 8 + hazard["time"] / 1.2 * 38, 0, TAU, 36, CORAL, 1, true)

func draw_objective_hud() -> void:
    if run.elapsed < 90:
        var message := guide_message()
        panel(Rect2(20, 116, 455, 99), Color(0.03, 0.1, 0.09, 0.9))
        text_at(message[0], Vector2(35, 145), 19, MINT)
        wrapped_text(message[1], Vector2(35, 175), 425, 16)
        return
    var nearest := 0
    var distance := INF
    for index in range(run.facilities.sites.size()):
        var current: float = run.player.distance_to(run.facilities.sites[index]["pos"])
        if current < distance:
            nearest = index
            distance = current
    var site: Dictionary = run.facilities.sites[nearest]
    var label: String = Run.Facilities.INFO[nearest][0]
    var top := 170.0 if run.boss_spawned and not run.boss_defeated else 116.0
    panel(Rect2(20, top, 455, 103), Color(0.03, 0.1, 0.09, 0.9))
    text_at("可选设施（可跳过）· 已选 %d / 2 · 完成 %d" % [run.facilities.selected_count(), run.facilities.completed_count()], Vector2(35, top + 25), 17, GOLD)
    text_at(label + " · %dm" % int(distance) + (" · 1:30可选定" if run.elapsed < 90 else ""), Vector2(35, top + 51), 16, MINT)
    wrapped_text(Run.Facilities.INFO[nearest][1], Vector2(35, top + 76), 425, 13)
    if run.facilities.capture_target >= 0:
        var current: Dictionary = run.facilities.sites[run.facilities.capture_target]
        panel(Rect2(330, 576, 460, 66))
        text_at("守住区域 / " + Run.Facilities.INFO[current["id"]][0] + " %.1f / %.1fs" % [current["progress"], run.facilities.duration(run.role_id)], Vector2(345, 601), 17, GOLD)
        text_at("圈内可移动作战；离开暂停进度，不回退", Vector2(345, 625), 14, MUTED)
    elif run.nearest_interaction_facility() >= 0:
        var index: int = run.nearest_interaction_facility()
        panel(Rect2(260, 576, 600, 66))
        text_at("按住 E 选定 " + Run.Facilities.INFO[index][0] + " · 占用一处名额", Vector2(280, 603), 18, GOLD)
        bar(Rect2(280, 618, 560, 5), run.facilities.hold_time / 0.6, GOLD)
    elif site["selected"] and not site["complete"]:
        text_at("已选设施占点暂停；返回圈内继续", Vector2(35, top + 127), 15, GOLD)

func start_recommended() -> void:
    selected_role = "guard"
    selected_weapon = "orbit"
    start_run()

func open_custom_setup() -> void:
    custom_setup = true
    refresh_buttons()

func close_custom_setup() -> void:
    custom_setup = false
    refresh_buttons()

func draw_simple_menu() -> void:
    text_at("第一次来到观测站？先走起来。", Vector2(62, 310), 27, INK)
    text_at("已经为你准备好灯卫和环刃，武器会自动攻击。", Vector2(62, 351), 19, MUTED)
    text_at("你只需要移动、避开敌人，跟着场内提示熟悉操作。", Vector2(62, 386), 18, MUTED)
    draw_texture_rect(character_textures["guard"], Rect2(755, 300, 250, 250), false)
    text_at("岩灯 · 灯卫", Vector2(820, 585), 24, GOLD)
    text_at("生命较多 · 近身自动防线", Vector2(770, 617), 16, MUTED)
    text_at("先认识角色，再慢慢尝试其他搭配。", Vector2(62, 585), 16, MUTED)
    if profile.total_runs > 0:
        text_at("已完成 %d 局 · 星砂 %d" % [profile.total_runs, profile.crystals], Vector2(62, 615), 16, GOLD)
    else:
        text_at("无需预先选择任务，也不用记住所有武器。", Vector2(62, 650), 17, GOLD)
    text_at("自动攻击 / WASD移动 / 空格冲刺 / P暂停", Vector2(62, 708), 15, MUTED)
    if not profile.last_error.is_empty():
        text_at(profile.last_error, Vector2(62, 730), 12, CORAL)

func guide_message() -> Array[String]:
    if guide_enabled:
        if guide_distance < 80:
            return ["先试着移动", "按 WASD 或方向键。武器会自动攻击，不用按攻击键。"]
        if run.effective_dashes == 0 and run.elapsed < 35:
            return ["试一次冲刺", "按空格向移动方向冲刺，可以短暂躲开伤害。"]
        if not guide_upgrade_done:
            return ["拾起地上的绿色星光", "靠近即可拾取经验；升级时战斗会暂停，放心选择。"]
        if run.elapsed < 45:
            return ["基础操作已掌握", "继续移动和拾取经验。暂时不用找任务；按 H 可关闭提示。"]
    return ["先站稳脚步，再探索遗迹", "移动避敌、自动攻击、拾取经验。1:30后开放可选设施。"]
