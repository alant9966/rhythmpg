extends SceneTree
const Shell = preload("res://global/game_shell.gd")
var shell: Shell
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_pause_%s.png" % name)

func run() -> void:
	shell = root.get_node("GameShell")
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.2).timeout
	scene.choose_action(1)
	await shot("prepare")
	shell.open_menu()
	for page in ["main", "saves", "controls", "guide", "quit"]:
		shell._show_page(page)
		await shot(page)
	shell.resume_game(false)
	scene.rhythm.cancel()
	scene.bgm.stop()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
