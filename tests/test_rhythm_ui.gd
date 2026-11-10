extends SceneTree
const Shell = preload("res://global/game_shell.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle_scene() -> void:
	await process_frame
	await process_frame
	await process_frame

func run() -> void:
	var shell: Shell = root.get_node("GameShell")
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await settle_scene()
	scene.choose_action(0)
	await process_frame
	check(scene.rhythm.visible and scene.rhythm.size.is_equal_approx(scene.size), "Performance covers battle viewport")
	check(scene.rhythm.position.is_zero_approx() and scene.rhythm.z_index > 0, "Overlay renders above HUD")
	shell.open_menu()
	check(shell.is_open and paused, "Global pause remains accessible over performance")
	shell.resume_game(false)
	scene.restart()
	scene.battle.party[0].hp = 91
	scene.battle.party[1].mp = 17
	scene.battle.enemy.hp = 407
	scene.battle.round_number = 3
	scene.battle.tonics = 1
	scene._show_commands()
	scene._open_lab()
	await settle_scene()
	var lab = current_scene
	check(lab.scene_file_path == "res://scenes/rhythm_lab.tscn", "Battle opens Rhythm Lab")
	check(lab.mode_button.visible and lab.mode_button.text.begins_with("Return to battle"), "Lab exposes return button")
	lab.start_performance("guitar")
	lab.mode_button.pressed.emit()
	await settle_scene()
	scene = current_scene
	check(scene.scene_file_path == "res://scenes/combat.tscn" and scene.phase == "select", "Return during practice restores combat selection")
	check(scene.battle.party[0].hp == 91 and scene.battle.party[1].mp == 17, "Return preserves hero HP and MP")
	check(scene.battle.enemy.hp == 407 and scene.battle.tonics == 1 and scene.battle.round_number == 3, "Return preserves encounter progress")
	scene._open_lab()
	await settle_scene()
	lab = current_scene
	var event := InputEventKey.new()
	event.physical_keycode = int(shell.bindings.switch_mode)
	event.pressed = true
	lab._input(event)
	await settle_scene()
	scene = current_scene
	check(scene.scene_file_path == "res://scenes/combat.tscn" and scene.battle.enemy.hp == 407, "Shortcut returns to saved battle")
	change_scene_to_file("res://scenes/rhythm_lab.tscn")
	await settle_scene()
	lab = current_scene
	lab.mode_button.pressed.emit()
	await settle_scene()
	scene = current_scene
	check(scene.battle.enemy.hp == 650 and scene.phase == "select", "Standalone lab returns to fresh encounter")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	print("Rhythm UI checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
