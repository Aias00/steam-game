extends SceneTree

const Run = preload("res://scripts/run.gd")

func _initialize() -> void:
    call_deferred("check")

func check() -> void:
    create_timer(45).timeout.connect(func(): quit(1))
    for starter in ["pulse", "orbit", "nova", "turret"]:
        var game = Run.new(starter, 0, 7654)
        var frames := 0
        while game.state != "lost" and game.state != "won" and frames < 15000:
            if game.state == "upgrade":
                var chosen := 0
                for desired in ["orbit", "nova", "pulse", "turret", "fiber", "axle", "lens", "battery", "lightfoot", "gravity"]:
                    if game.choices.has(desired):
                        chosen = game.choices.find(desired)
                        break
                game.choose_upgrade(chosen)
            else:
                var target := Vector2.from_angle(game.elapsed * 0.06) * 470
                var direction: Vector2 = (target - game.player).normalized()
                # An ordinary kiting bot, with no health or damage cheats.
                for enemy in game.enemies:
                    if game.player.distance_to(enemy.pos) < enemy.radius + 45:
                        direction = (game.player - enemy.pos).normalized()
                        game.dash()
                        break
                game.step(0.05, direction)
            frames += 1
        print("BALANCE ", starter, ": ", snappedf(game.elapsed, 0.1), "s, kills=", game.kills, " level=", game.level, " outcome=", game.state)
        assert(game.elapsed >= 60 and game.kills >= 10, "Starter offers a playable first minute")
    quit(0)
