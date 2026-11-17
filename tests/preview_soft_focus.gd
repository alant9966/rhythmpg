extends SceneTree
const Helpers = preload("res://tests/combat_test_helpers.gd")
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	captured.save_png("res://tests/preview_soft_%s.png" % name)
	return captured
func run() -> void:
	root.size = Vector2i(1500, 800)
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.15).timeout
	var before: Image = await shot("full")
	scene.choose_action(0)
	scene.choose_action(0)
	scene.choose_action(0)
	await create_timer(scene.rhythm_focus_in_seconds + scene.rhythm_hud_fade_seconds + 0.1).timeout
	scene.rhythm.preparation_left = 0
	scene.rhythm.time = 1.0
	scene.rhythm.paused = true
	scene.rhythm.queue_redraw()
	var after: Image = await shot("focused")
	var opacity: float = scene.rhythm.dim_opacity
	scene.rhythm.dim_opacity = 0.0
	scene.rhythm.queue_redraw()
	var undimmed: Image = await shot("undimmed")
	scene.rhythm.dim_opacity = opacity
	scene.rhythm.queue_redraw()
	var pixel_after := after.get_pixel(0, after.get_height() / 2)
	var pixel_undimmed := undimmed.get_pixel(0, undimmed.get_height() / 2)
	var dim_luminance := pixel_after.r + pixel_after.g + pixel_after.b
	var base_luminance := pixel_undimmed.r + pixel_undimmed.g + pixel_undimmed.b
	if dim_luminance >= base_luminance * 0.4:
		push_error("Wide viewport border was not dimmed")
		quit(1)
		return
	print("Wide viewport left edge tint verified")
	scene.rhythm.paused = false
	Helpers.perfect(scene.rhythm)
	await create_timer(scene.rhythm_focus_out_seconds * 0.5).timeout
	await shot("returning")
	await create_timer(scene.rhythm_focus_out_seconds * 0.5 + scene.rhythm_hud_fade_seconds + 0.05).timeout
	await shot("action")
	scene.restart()
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	quit()
