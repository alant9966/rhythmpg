extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_queue_%s.png" % name)

func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.1).timeout
	scene.battle.party[1].speed = 23
	scene._show_commands()
	await shot("planning")
	scene.choose_action(1)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	await shot("queued")
	scene.choose_action(1)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	scene.choose_action(0)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	await create_timer(0.23).timeout
	await shot("mage_first")
	await create_timer(0.78).timeout
	await shot("warrior_second")
	await create_timer(0.75).timeout
	await shot("percussionist_third")
	await create_timer(0.75).timeout
	await shot("enemy")
	await create_timer(1.5).timeout
	await shot("next_round")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
