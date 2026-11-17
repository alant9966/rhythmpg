extends SceneTree
const Helpers = preload("res://tests/combat_test_helpers.gd")
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_rework_%s.png" % name)

func plan(scene: Node, index: int) -> void:
	for i in range(3):
		scene.choose_action(index)

func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	plan(scene, 1)
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 1.2
	scene.rhythm.paused = true
	scene.rhythm.held = scene.rhythm.chord_mask
	scene.rhythm.queue_redraw()
	await shot("variation")
	scene.rhythm.resolve_now()
	await create_timer(0.23).timeout
	await shot("miss")
	await Helpers.finish_round(scene, 0.0)
	plan(scene, 1)
	Helpers.perfect(scene.rhythm)
	await create_timer(0.23).timeout
	await shot("perfect")
	await Helpers.finish_round(scene)
	scene.restart()
	plan(scene, 3)
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 1.2
	scene.rhythm.paused = true
	scene.rhythm.queue_redraw()
	await shot("guard")
	scene.rhythm.paused = false
	Helpers.perfect(scene.rhythm)
	await create_timer(1.25).timeout
	await shot("block")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
