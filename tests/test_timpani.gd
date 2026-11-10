extends SceneTree
const Rules = preload("res://combat/battle_state.gd")
const Maps = preload("res://combat/combat_beatmaps.gd")
const Rhythm = preload("res://combat/combat_rhythm.gd")
const Session = preload("res://rhythm/rhythm_session.gd")
const Circles = preload("res://rhythm/circle_visuals.gd")
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

func center(note: Dictionary, area: Rect2) -> Vector2:
	return area.position + note.position * area.size

func mouse_click(node: Control, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	if node is Rhythm:
		var zoom := minf(node.size.x / 1200.0, node.size.y / 800.0)
		position = position * zoom + (node.size - Vector2(1200, 800) * zoom) * 0.5
	event.position = node.get_global_transform_with_canvas() * position
	node._input(event)

func settle_scene() -> void:
	await process_frame
	await process_frame
	await process_frame

func wait_for_round(scene: Node, round_number: int) -> void:
	for tick in range(130):
		if scene.phase == "select" and scene.battle.round_number == round_number:
			return
		await create_timer(0.05).timeout
	check(false, "Three-character round did not finish")

func finish_as(scene: Node, accuracy: float) -> void:
	scene.rhythm.cancel()
	scene._performance_finished({"accuracy": accuracy})

func run() -> void:
	var area: Rect2 = Circles.COMBAT_AREA
	var chart: Array[Dictionary] = Maps.chart("timpani", 1, 0)
	var session = Session.new()
	session.setup("timpani", chart)
	check(not session.press(chart[0].time, 0, 1), "Keyboard lane hits cannot score circles")
	check(not session.click(chart[0].time - 0.2, center(chart[0], area), area) and session.stray_inputs == 1, "Early clicks are rejected")
	check(not session.click(chart[0].time, center(chart[1], area), area) and session.stray_inputs == 2, "Future circles cannot be clicked out of order")
	check(session.click(chart[0].time + 0.1, center(chart[0], area), area) and session.good == 1, "On-target good timing scores partial credit")
	session.setup("timpani", chart)
	session.advance(chart[0].time + 0.15, 0)
	check(session.missed == 1 and session.click(chart[1].time, center(chart[1], area), area), "Missed circle advances to next target")
	var variants := {}
	for index in range(Maps.count("timpani")):
		chart = Maps.chart("timpani", 1, index)
		variants[JSON.stringify(chart)] = true
		session.setup("timpani", chart)
		var valid := true
		for note in chart:
			valid = valid and area.has_point(center(note, area)) and note.time < Rhythm.END and note.duration == 0
			valid = valid and session.click(note.time, center(note, area), area)
		check(valid and session.accuracy() == 1.0 and session.is_complete(), "Circle map %d is valid and perfectly playable" % index)
	check(variants.size() == 6, "Six distinct timpani patterns")
	check(Circles.logical_point(Vector2(968.75, 450), Vector2(1600, 900)).is_equal_approx(Vector2(750, 400)), "Mouse coordinates track the centered overlay at widescreen size")
	var battle = Rules.new()
	check(battle.party.size() == 3 and battle.party[2].instrument == "timpani", "Maro is a real third battle actor")
	battle.turn_cursor = 2
	check(battle.apply_player(2, battle.actions(2)[0], -1, 0.5).amount == 40, "Timpani attack uses physical damage and scales")
	check(battle.apply_player(2, battle.actions(2)[0], -1, 1).amount == 120, "Perfect drum attack gains critical multiplier")
	battle.reset()
	battle.turn_cursor = 2
	battle.apply_player(2, battle.actions(2)[1], -1, 0.99)
	check(battle.enemy.stagger_turns == 0, "Partial Thunder Roll cannot stagger")
	battle.apply_player(2, battle.actions(2)[1], -1, 1)
	check(battle.enemy.stagger_turns == 1, "Perfect Thunder Roll staggers")
	battle.turn_cursor = 3
	var event: Dictionary = battle.apply_enemy()
	check(event.staggered and event.hits.is_empty() and battle.enemy.stagger_turns == 0, "Stagger consumes one enemy response")
	battle.round_number = 3
	event = battle.apply_enemy()
	check(event.hits.size() == 3 and event.hits[2].target == 2, "Party-wide enemy attack reaches Maro")
	battle.round_number = 4
	check(battle.intent().target == 2, "Single-target enemy intent rotates to Maro")
	battle.reset()
	battle.turn_cursor = 2
	battle.party[0].hp = 80
	battle.party[0].mp = 3
	battle.party[1].hp = 0
	battle.apply_player(2, battle.actions(2)[2], -1, 1)
	check(battle.party[0].hp == 100 and battle.party[0].mp == 7 and battle.party[1].hp == 0, "Perfect Rallying Beat restores HP and MP to living allies")
	# Real scene: two queued scores, then actual mouse input for the third actor.
	var shell: Shell = root.get_node("GameShell")
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await settle_scene()
	check(scene.heroes.size() == 3 and scene.heroes[2].has_timpani, "Maro sprite and drums are staged")
	scene.choose_action(0)
	finish_as(scene, 0)
	scene.choose_action(0)
	finish_as(scene, 0)
	check(scene.phase == "select" and scene.battle.turn_cursor == 2 and scene.battle.queued_actions.size() == 2 and scene.battle.enemy.hp == 650, "First two selections wait for Maro")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(scene.make_save()))
	check(scene.valid_save(saved), "Serialized three-member queue can be saved while Maro plans")
	scene.restore_save(saved)
	check(scene.battle.turn_cursor == 2 and scene.battle.queued_actions.size() == 2, "Three-member queue restores its third planning slot")
	scene.choose_action(1)
	check(scene.phase == "rhythm" and scene.rhythm.instrument == "timpani" and scene.rhythm.samples.size() == 4, "Maro launches CircleStrike with drum audio")
	scene.rhythm.preparation_left = 0
	var first: Dictionary = scene.rhythm.session.notes[0]
	scene.rhythm.time = first.time
	shell.open_menu()
	mouse_click(scene.rhythm, center(first, area))
	check(scene.rhythm.session.perfect == 0, "Paused circle input is ignored")
	shell.resume_game(false)
	for note in scene.rhythm.session.notes:
		scene.rhythm.time = note.time
		mouse_click(scene.rhythm, center(note, area))
	check(scene.rhythm.session.accuracy() == 1.0, "Combat mouse events score all six circles")
	scene.rhythm.time = Rhythm.END
	scene.rhythm._process(0)
	await wait_for_round(scene, 2)
	check(scene.history.size() == 4 and scene.history[2].begins_with("Thunder Roll") and scene.history[3].contains("staggered"), "Third queued action resolves then skips enemy response")
	check(scene.battle.enemy.hp == 534 and scene.battle.party[2].mp == 22 and scene.battle.party[0].hp == 180, "Timpani resolution applies damage and round costs once")
	scene.restart()
	scene.battle.party[2].hp = 70
	scene.choose_action(0)
	finish_as(scene, 0)
	scene.choose_action(2)
	var key := InputEventKey.new()
	key.physical_keycode = int(shell.bindings.command_3)
	key.pressed = true
	scene._unhandled_key_input(key)
	check(scene.phase == "rhythm" and scene.selected_target == 2, "Third ally is keyboard-targetable")
	finish_as(scene, 1)
	scene.choose_action(3)
	check(scene.rhythm.instrument == "timpani", "Guard launches CircleStrike too")
	finish_as(scene, 1)
	await wait_for_round(scene, 2)
	check(scene.battle.party[2].hp == 148 and scene.battle.party[2].guard_strength == 1.0, "Maro receives a queued heal and earns a perfect guard")
	var legacy: Dictionary = scene.make_save()
	legacy.party.resize(2)
	legacy.enemy.erase("stagger_turns")
	check(scene.valid_save(legacy), "Legacy two-member save remains valid")
	scene.restore_save(legacy)
	check(scene.battle.party[2].hp == 148 and scene.battle.party[2].mp == 28 and scene.battle.enemy.stagger_turns == 0, "Legacy save adds Maro at full health and mana")
	# Lab playback uses the same click judgment with its own play area and patterns.
	scene._open_lab()
	await settle_scene()
	var lab = current_scene
	lab.timpani_button.pressed.emit()
	check(lab.instrument == "timpani", "Rhythm Lab offers a Timpani tab")
	lab.start_performance("timpani")
	var variant: int = lab.timpani_variation
	check(lab.session.notes.size() == 24 and lab.music.stream != null, "Practice uses four circle patterns with backing audio")
	lab.start_performance("timpani")
	check(variant != lab.timpani_variation, "Practice restart varies its opening pattern")
	lab.preparation_left = 0
	first = lab.session.notes[0]
	lab.song_time = first.time
	mouse_click(lab, center(first, Circles.PRACTICE_AREA))
	check(lab.session.perfect == 1, "Practice mouse events hit a circle")
	check(lab.valid_save(lab.make_save()), "Timpani practice selection can be saved")
	lab.mode_button.pressed.emit()
	await settle_scene()
	scene = current_scene
	check(scene.battle.party.size() == 3 and scene.battle.round_number == 2, "Lab return preserves three-party battle")
	# The new audio clock actually completes with no input.
	var rhythm = Rhythm.new()
	root.add_child(rhythm)
	await process_frame
	var results: Array[Dictionary] = []
	rhythm.completed.connect(func(result: Dictionary): results.append(result))
	var previous := -1
	var seen := {}
	var repeat_free := true
	for i in range(12):
		rhythm.start("timpani", "Drumstrike")
		repeat_free = repeat_free and previous != rhythm.variation_index
		previous = rhythm.variation_index
		seen[previous] = true
	check(repeat_free and seen.size() == 6, "Timpani shuffle covers all maps without immediate repeats")
	await create_timer(Rhythm.EMPTY_RUNWAY_SECONDS + Rhythm.END + 0.5).timeout
	check(results.size() == 1 and results[0].accuracy == 0 and results[0].missed == 6, "Actual timpani audio run finishes and accounts for misses")
	rhythm.queue_free()
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	print("Timpani checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
