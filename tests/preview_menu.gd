extends SceneTree
const Helpers = preload("res://tests/combat_test_helpers.gd")
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_menu_%s.png" % name)
func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await Helpers.settle(self)
	scene.buttons[1].grab_focus()
	await shot("commands")
	scene.choose_action(0)
	scene.choose_action(2)
	await shot("target")
	scene.restart()
	scene.battle.enemy.hp = 0
	scene.battle._check_outcome()
	scene._show_outcome()
	await shot("victory")
	var shell = root.get_node("GameShell")
	shell.open_menu()
	await shot("pause")
	shell.resume_game(false)
	scene.restart()
	scene._open_lab()
	await Helpers.settle(self)
	await shot("lab")
	current_scene.music.stop()
	current_scene.queue_free()
	await create_timer(0.1).timeout
	quit()
