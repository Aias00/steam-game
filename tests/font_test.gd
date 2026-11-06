extends SceneTree
func _initialize() -> void:
    call_deferred("check_font")
func check_font() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    scene.set_physics_process(false)
    scene.start_recommended()
    scene.run.state = "upgrade"
    scene.run.choices.assign(["axle", "lens", "gravity"])
    scene.refresh_buttons()
    var characters := "稳定轴远弧支架贯星导轨回响棱镜急放线圈广域振片急速齿轮长焦灯罩霁月螺灯墨刃"
    var rid: RID = scene.font.get_rids()[0]
    for character in characters:
        assert(TextServerManager.get_primary_interface().font_has_char(rid, character.unicode_at(0)), character)
    await process_frame
    await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("res://artifacts/font-upgrade.png") == OK)
    print("PASS: bundled font contains all weapon/module/character sample glyphs; upgrade card rendered")
    quit()
