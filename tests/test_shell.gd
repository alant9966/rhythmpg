extends SceneTree
const Shell = preload("res://global/game_shell.gd")
var shell: Shell
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func key(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	shell = root.get_node("GameShell")
	shell.reset_bindings()
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	Input.parse_input_event(key(KEY_ESCAPE))
	Input.parse_input_event(key(KEY_ESCAPE, false))
	await process_frame
	check(shell.is_open and paused, "Esc opens global pause")
	Input.parse_input_event(key(KEY_TAB))
	Input.parse_input_event(key(KEY_TAB, false))
	await process_frame
	check(root.gui_get_focus_owner() != null, "Menu supports keyboard focus navigation")
	var clock: float = scene.stage.elapsed
	await create_timer(0.15).timeout
	check(is_equal_approx(scene.stage.elapsed, clock) and scene.bgm.stream_paused, "Pause freezes stage and audio")
	for page in ["controls", "guide", "saves", "quit", "main"]:
		shell._show_page(page)
		check(shell.is_open and shell.page == page, "Pause page opens: " + page)
	shell.resume_game()
	check(paused and shell.resume_left > 0, "Resume has a preparation countdown")
	await create_timer(1.0).timeout
	check(not paused and not shell.is_open and not scene.bgm.stream_paused, "Resume restores game and audio")
	shell.open_menu()
	shell.resume_game()
	shell._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(shell.is_open and paused and shell.resume_left < 0, "Focus loss cancels resume countdown")
	shell.resume_game(false)
	check(shell.rebind("piano_1", KEY_Q).is_empty(), "Piano key can be changed")
	check(shell.matches(key(KEY_Q), "piano_1") and not shell.matches(key(KEY_D), "piano_1"), "Input matches new binding")
	check(not shell.rebind("piano_2", KEY_Q).is_empty(), "Duplicate within instrument rejected")
	check(not shell.rebind("guitar_1", KEY_ESCAPE).is_empty(), "Esc remains reserved")
	check(shell.rebind("piano_1", KEY_S).is_empty(), "Piano and guitar can share keys")
	check(not shell.rebind("guitar_1", KEY_P).is_empty(), "Global pause key cannot conflict")
	check(shell.rebind("piano_1", KEY_Q).is_empty(), "Return to custom test key")
	shell.bindings.piano_1 = KEY_D
	shell._load_settings()
	check(shell.key_name("piano_1") == "Q", "Binding persists to disk")
	shell._install_actions()
	scene.choose_action(1)
	check(scene.rhythm.preparation_left > 0 and not scene.rhythm.player.playing, "Combat prepares before playing audio")
	scene.rhythm._input(key(KEY_D))
	scene.rhythm._input(key(KEY_F))
	scene.rhythm._input(key(KEY_DOWN))
	check(scene.rhythm.session.stray_inputs == 0 and scene.rhythm.session.perfect == 0, "Preparation inputs are not judged")
	var preparation: float = scene.rhythm.preparation_left
	check(preparation >= 1.9, "Combat rhythm has a two-second preparation pause")
	shell.open_menu()
	await create_timer(0.15).timeout
	check(is_equal_approx(scene.rhythm.preparation_left, preparation), "Global pause freezes preparation countdown")
	shell.resume_game(false)
	await create_timer(2.5).timeout
	check(scene.rhythm.preparation_left == 0 and scene.rhythm.player.playing, "Countdown launches actual chart audio")
	var song: float = scene.rhythm.time
	shell.open_menu()
	await create_timer(0.2).timeout
	check(is_equal_approx(scene.rhythm.time, song) and scene.rhythm.player.stream_paused, "Pause freezes active rhythm clock and audio")
	check(shell.save_slot(1) == "Saved in slot 1.", "Create combat save slot")
	var saved := shell.read_slot(1)
	check(saved.payload.enemy.hp == 650 and saved.payload.turn == 0, "Mid-action save uses command checkpoint")
	check(scene.valid_save(saved.payload), "Serialized combat snapshot validates")
	var invalid: Dictionary = saved.payload.duplicate(true)
	invalid.party[0].hp = -1
	check(not scene.valid_save(invalid), "Invalid HP rejected")
	invalid = saved.payload.duplicate(true)
	invalid.turn = 9
	check(not scene.valid_save(invalid), "Invalid turn rejected")
	shell.resume_game(false)
	scene.restart()
	scene.battle.party[0].hp = 89
	scene.battle.party[1].mp = 19
	scene.battle.tonics = 1
	scene.battle.round_number = 2
	scene.battle.enemy.hp = 420
	scene.battle.enemy.burn = 12
	scene.battle.enemy.burn_turns = 2
	scene._show_commands()
	check(shell.save_slot(1) == "Saved in slot 1.", "Overwrite save slot")
	scene.battle.party[0].hp = 1
	shell.open_menu()
	check(shell.load_slot(1).is_empty(), "Load changes to saved scene")
	await process_frame
	await process_frame
	await process_frame
	scene = current_scene
	check(scene.battle.party[0].hp == 89 and scene.battle.party[1].mp == 19, "Loading restores HP and MP")
	check(scene.battle.tonics == 1 and scene.battle.round_number == 2 and scene.battle.enemy.hp == 420, "Loading restores round, inventory and enemy")
	check(scene.battle.enemy.burn == 12 and scene.battle.enemy.burn_turns == 2 and scene.phase == "select", "Loading restores status effects at safe command point")
	check(not paused and not shell.is_open, "Loading unpauses safely")
	# No enemy damage or turn handoff may run through a global pause.
	scene.restart()
	scene.battle.turn_cursor = 2
	scene._enemy_turn()
	shell.open_menu()
	await create_timer(0.9).timeout
	check(scene.battle.party[0].hp == 180 and scene.phase == "enemy", "Enemy timers remain frozen behind menu")
	shell.resume_game(false)
	await create_timer(1.6).timeout
	check(scene.battle.party[0].hp == 155 and scene.phase == "select", "Enemy action resumes exactly once")
	# Practice shares bindings, preparation, pause, and save/load.
	change_scene_to_file("res://scenes/rhythm_lab.tscn")
	await process_frame
	await process_frame
	var lab = current_scene
	lab.start_performance("piano")
	lab._input(key(KEY_Q))
	check(lab.preparation_left > 0 and lab.session.stray_inputs == 0 and not lab.music.playing, "Practice also has unjudged preparation")
	lab.preparation_left = 0
	lab.song_time = 2.4
	lab._input(key(KEY_Q, false))
	lab._input(key(KEY_Q))
	check(lab.session.perfect == 1 and lab.held_mask == 1, "Practice uses remapped piano key")
	check(shell.save_slot(2) == "Saved in slot 2.", "Practice instrument can be saved")
	var data := shell.read_slot(2)
	check(data.payload.instrument == "piano" and lab.valid_save(data.payload), "Practice snapshot records instrument")
	check(shell.load_slot(2).is_empty(), "Practice save loads its scene")
	await process_frame
	await process_frame
	await process_frame
	lab = current_scene
	check(lab.instrument == "piano" and not lab.running, "Practice loads ready for a fresh phrase")
	shell.reset_bindings()
	lab._reset()
	shell.open_menu()
	shell._input(key(KEY_ESCAPE))
	await create_timer(1).timeout
	check(not paused and not shell.is_open, "Esc closes main menu through resume countdown")
	print("Shell checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
