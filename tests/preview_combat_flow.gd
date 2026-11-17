extends SceneTree
const Helpers = preload("res://tests/combat_test_helpers.gd")
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_flow_%s.png" % name)

func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.15).timeout
	await shot("planning")
	scene.choose_action(0)
	scene.choose_action(0)
	await shot("commands")
	scene.choose_action(0)
	await create_timer(scene.rhythm_focus_in_seconds + scene.rhythm_hud_fade_seconds + 0.1).timeout
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 1.0
	scene.rhythm.paused = true
	scene.rhythm.queue_redraw()
	await shot("guitar")
	scene.rhythm.paused = false
	Helpers.perfect(scene.rhythm)
	await create_timer(scene.rhythm_focus_out_seconds + scene.rhythm_hud_fade_seconds + 0.95).timeout
	await shot("enemy")
	for tick in range(150):
		if scene.phase == "rhythm":
			break
		await create_timer(0.02).timeout
	await create_timer(scene.rhythm_focus_in_seconds + scene.rhythm_hud_fade_seconds + 0.1).timeout
	await shot("piano_ready")
	Helpers.perfect(scene.rhythm)
	await create_timer(scene.rhythm_focus_out_seconds + scene.rhythm_hud_fade_seconds + 0.85).timeout
	await create_timer(scene.rhythm_focus_in_seconds + scene.rhythm_hud_fade_seconds + 0.1).timeout
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 0.5
	scene.rhythm.paused = true
	scene.rhythm.queue_redraw()
	await shot("timpani")
	scene.rhythm.paused = false
	Helpers.perfect(scene.rhythm)
	await Helpers.finish_round(scene)
	await shot("next_round")
	scene.restart()
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
