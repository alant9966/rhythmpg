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
func click(button: Button) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.position = point
	release.button_index = MOUSE_BUTTON_LEFT
	root.push_input(release, true)
	await process_frame
func run() -> void:
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await Helpers.settle(self)
	await click(scene.buttons[0])
	check(scene.battle.turn_cursor == 1 and scene.battle.queued_for(0).get("action_id") == "attack", "Mouse selects the new command row")
	await click(scene.buttons[2])
	check(scene.phase == "target", "Mouse opens the new ally target layout")
	await click(scene.buttons[2])
	check(scene.battle.queued_for(1).get("target") == 2 and scene.battle.turn_cursor == 2, "Mouse targets Maro from his party column")
	await click(scene.buttons[3])
	check(scene.phase == "rhythm" and not scene.rhythm.gameplay_visible(), "Last command starts focus with gameplay hidden")
	var overlap := false
	for tick in range(32):
		overlap = overlap or (scene.rhythm.gameplay_visible() and scene.hud.modulate.a > 0.0001)
		await create_timer(0.05).timeout
	check(not overlap and scene.rhythm.gameplay_visible(), "No frame overlaps rhythm playfield and fading HUD")
	check(await Helpers.finish_round(scene) and scene.battle.round_number == 2, "New menu still resolves full party and returns to command selection")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	print("Menu checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
