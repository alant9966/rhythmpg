extends SceneTree
const Helpers = preload("res://tests/combat_test_helpers.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await Helpers.settle(self)
	var actors: Array = scene.heroes + [scene.foe]
	var frames: Array = []
	for actor in actors:
		check(actor.animation_player.current_animation == actor.idle_animation and actor.animation_player.is_playing(), "Idle playback starts on " + actor.name)
		frames.append(actor.sprite.frame)
	await create_timer(0.28).timeout
	for index in range(actors.size()):
		var actor = actors[index]
		var valid_frame: bool = actor.sprite.frame != frames[index] if actor == scene.foe else actor.sprite.frame == frames[index]
		check(valid_frame and actor.sprite.offset == Vector2.ZERO and actor.sprite.scale == Vector2.ONE, "Idle uses real frames or static pose, never transform oscillation: " + actor.name)
	check(scene.font.multichannel_signed_distance_field and scene.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Text uses scalable font and smooth filtering")
	check(scene.heroes[0].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and scene.stage.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Sprites retain pixel filtering")
	check(not scene.stage.has_node("Foreground") and not scene.stage.has_node("Atmosphere/BackgroundTint") and scene.get_node("Battlefield/Background").modulate == Color.WHITE, "Ambient tint and added foliage are removed")
	for actor in scene.heroes:
		check(frame_hash(actor, 9) == frame_hash(actor, 10) and frame_hash(actor, 10) == frame_hash(actor, 11), "Hero idle cells are duplicate artwork: " + actor.name)
	check(frame_hash(scene.foe, 0) != frame_hash(scene.foe, 1) and frame_hash(scene.foe, 1) != frame_hash(scene.foe, 2), "Warden idle uses distinct visible sprite frames")
	var base_scale: Vector2 = scene.heroes[0].scale
	scene.choose_action(0)
	scene.choose_action(0)
	scene.choose_action(0)
	await create_timer(0.25).timeout
	check(scene.stage.scale.x > 1 and scene.stage.scale.x < scene.rhythm_camera_zoom, "Focus eases in gradually")
	check(scene.hud.modulate.a == 1.0, "HUD stays opaque while zoom-in leaves lower background uncovered")
	check(not scene.rhythm.gameplay_visible() and not scene.rhythm.gameplay_revealed, "Playfield is hidden throughout HUD and camera transition")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_DOWN
	event.pressed = true
	scene.rhythm.preparation_left = 0
	scene.rhythm._input(event)
	check(scene.rhythm.session.stray_inputs == 0 and scene.rhythm.session.perfect == 0, "Hidden playfield accepts no rhythm judgments")
	await create_timer(scene.rhythm_focus_in_seconds).timeout
	check(scene.focused_actor == scene.heroes[0] and scene.heroes[0].z_index > scene.rhythm.z_index and not scene.heroes[0].z_as_relative, "Only real active actor is above dimmer")
	check(scene.stage.scale.x > 1 and scene.heroes[0].scale.x > base_scale.x, "Performance zooms battlefield and active actor")
	check((scene.stage.position + scene.heroes[0].position * scene.stage.scale).is_equal_approx(scene.rhythm_actor_feet), "Actor is framed beside open playfield")
	await process_frame
	check(scene.rhythm.gameplay_visible() and is_zero_approx(scene.hud.modulate.a), "Gameplay reveals only once HUD is fully transparent")
	var shell = root.get_node("GameShell")
	shell.open_menu()
	var focus_position: Vector2 = scene.stage.position
	var frame: int = scene.heroes[0].sprite.frame
	await create_timer(0.15).timeout
	check(scene.stage.position == focus_position and scene.heroes[0].sprite.frame == frame, "Pause freezes focused presentation and animation")
	shell.resume_game(false)
	Helpers.perfect(scene.rhythm)
	check(scene.phase == "focus_return" and scene.rhythm.presentation_outro and scene.history.is_empty(), "Performance returns to full view before applying action")
	await create_timer(scene.rhythm_focus_out_seconds * 0.5).timeout
	check(scene.stage.scale.x > 1 and scene.stage.scale.x < scene.rhythm_camera_zoom and scene.rhythm.presentation_weight > 0 and scene.rhythm.presentation_weight < 1, "Return zoom and tint fade continuously")
	check(is_equal_approx(scene.hud.modulate.a, 1.0), "HUD returns before zoom-out exposes unpainted bottom")
	var returning_position: Vector2 = scene.stage.position
	shell.open_menu()
	await create_timer(0.15).timeout
	check(scene.stage.position == returning_position, "Pause freezes zoom-out")
	shell.resume_game(false)
	await create_timer(scene.rhythm_focus_out_seconds * 0.5 + scene.rhythm_hud_fade_seconds + 0.08).timeout
	check(scene.focused_actor == null and scene.stage.scale == Vector2.ONE and scene.heroes[0].scale == base_scale and scene.heroes[0].z_as_relative, "Performance restores actor and camera before attack")
	check(await Helpers.finish_round(scene), "All focused instruments still execute")
	scene.choose_action(0)
	scene.choose_action(0)
	scene.choose_action(0)
	await create_timer(0.1).timeout
	scene.restart()
	check(scene.focused_actor == null and scene.stage.position == Vector2.ZERO and scene.stage.scale == Vector2.ONE and scene.heroes[0].z_index == 4, "Restart interrupts focus tween and restores original scene")
	await create_timer(0.4).timeout
	check(scene.stage.position == Vector2.ZERO and scene.heroes[0].scale == base_scale, "Interrupted tween cannot restore stale focus")
	# A wide viewport gives the fitted root a left offset; tint must cover it too.
	root.size = Vector2i(1800, 900)
	await Helpers.settle(self)
	var backdrop_coverage: Rect2 = scene.screen_backdrop.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, scene.screen_backdrop.size)
	check(backdrop_coverage.grow(0.01).encloses(scene.rhythm.get_viewport_rect()), "Forest backdrop covers viewport margins at wide aspect ratios")
	var coverage: Rect2 = scene.rhythm.get_global_transform_with_canvas() * scene.rhythm.dimmer_rect()
	check(coverage.encloses(scene.rhythm.get_viewport_rect()), "Tint covers viewport and left/right letterbox strips")
	scene.choose_action(0)
	scene.choose_action(0)
	scene.choose_action(0)
	Helpers.perfect(scene.rhythm)
	await create_timer(0.2).timeout
	scene.restart()
	await create_timer(scene.rhythm_focus_out_seconds + scene.rhythm_hud_fade_seconds + 0.15).timeout
	check(scene.phase == "select" and scene.history.is_empty() and scene.focused_actor == null and not scene.rhythm.visible, "Restart during zoom-out cancels pending action and restores tint")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	print("Presentation checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func frame_hash(actor: Node, frame_index: int) -> int:
	var sheet: Image = actor.sprite.texture.get_image()
	var cell := Vector2i(sheet.get_width() / 9, sheet.get_height() / 6)
	var image := sheet.get_region(Rect2i(Vector2i(frame_index % 9, frame_index / 9) * cell, cell))
	for y in range(cell.y):
		for x in range(cell.x):
			if image.get_pixel(x, y).a == 0:
				image.set_pixel(x, y, Color.TRANSPARENT)
	return hash(image.get_data())
