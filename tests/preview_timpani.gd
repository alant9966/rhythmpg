extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://tests/preview_timpani_%s.png" % name
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.2).timeout
	await shot("party")
	for i in range(2):
		scene.choose_action(0)
		scene.rhythm.resolve_now()
	scene.rhythm.rng.seed = 19
	scene.choose_action(1)
	scene.rhythm.preparation_left = 0
	scene.rhythm.paused = true
	scene.rhythm.time = 0.5
	scene.rhythm.queue_redraw()
	await shot("circles")
	scene.rhythm.resolve_now()
	await create_timer(3.7).timeout
	scene._open_lab()
	await process_frame
	await process_frame
	var lab = current_scene
	lab.start_performance("timpani")
	lab.preparation_left = 0
	lab.set_process(false)
	lab.song_time = 2.25
	lab.feedback = "Aim for the gold circle first."
	lab.queue_redraw()
	await shot("lab")
	lab.music.stop()
	lab.queue_free()
	await create_timer(0.1).timeout
	quit()
