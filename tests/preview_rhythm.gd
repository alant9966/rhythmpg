extends SceneTree
## Render both instrument layouts for visual QA (requires a graphics renderer).
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var lab = load("res://scenes/rhythm_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	for mode in ["piano", "guitar"]:
		lab._select(mode)
		lab.song_time = 7.0
		lab.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/preview_%s.png" % mode)
	lab.queue_free()
	await process_frame
	quit()
