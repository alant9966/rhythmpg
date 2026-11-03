extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview_combat_%s.png" % name)

func capture() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.3).timeout
	await shot("commands")
	scene.choose_action(1)
	await create_timer(2.1).timeout
	await shot("guitar")
	scene.rhythm.resolve_now()
	await create_timer(1.0).timeout
	scene.choose_action(1)
	await create_timer(2.1).timeout
	await shot("piano")
	scene.rhythm.resolve_now()
	await create_timer(0.23).timeout
	await shot("impact")
	await create_timer(2.7).timeout
	scene.battle.enemy.hp = 0
	scene.battle._check_outcome()
	scene._show_outcome()
	await create_timer(0.1).timeout
	await shot("victory")
	scene.bgm.stop()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
