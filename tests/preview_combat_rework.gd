extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_rework_%s.png" % name)

func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.1).timeout
	scene.rhythm.rng.seed = 19
	scene.choose_action(1)
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 1.2
	scene.rhythm.paused = true
	scene.rhythm.held = scene.rhythm.chord_mask
	scene.rhythm.queue_redraw()
	await shot("variation")
	scene.rhythm.resolve_now()
	scene.choose_action(0)
	scene.rhythm.resolve_now()
	scene.choose_action(0)
	scene.rhythm.resolve_now()
	await create_timer(0.23).timeout
	await shot("miss")
	await create_timer(3.6).timeout
	scene.choose_action(1)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	scene.choose_action(1)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	scene.choose_action(1)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	await create_timer(1.0).timeout
	await shot("perfect")
	await create_timer(3.1).timeout
	scene.restart()
	scene.choose_action(3)
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 1.2
	scene.rhythm.paused = true
	scene.rhythm.queue_redraw()
	await shot("guard")
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	scene.choose_action(3)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	scene.choose_action(3)
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": 1.0})
	await create_timer(2.55).timeout
	await shot("block")
	await create_timer(0.9).timeout
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
