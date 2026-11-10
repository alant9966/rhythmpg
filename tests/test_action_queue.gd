extends SceneTree
const Rules = preload("res://combat/battle_state.gd")
const Rhythm = preload("res://combat/combat_rhythm.gd")
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

func plan(battle: RefCounted, actor: int, index: int, accuracy: float = 1.0, target: int = -1) -> bool:
	return battle.queue_action(actor, battle.actions(actor)[index], target, accuracy)

func execute(battle: RefCounted) -> Dictionary:
	var entry: Dictionary = battle.take_next_action()
	if entry.is_empty():
		return {}
	return battle.apply_player(entry.actor, battle.action_for(entry.actor, entry.action_id), entry.target, entry.accuracy)

func run() -> void:
	var battle = duo()
	battle.party[0].mp = 10
	battle.party[1].mp = 20
	check(plan(battle, 0, 1), "First action can be queued")
	check(battle.enemy.hp == 650 and battle.enemy.exposed_turns == 0 and battle.party[0].mp == 10, "Planning changes no combat effects or resources")
	check(battle.turn_cursor == 1 and battle.queued_for(0).accuracy == 1, "Planning advances and retains rhythm score")
	check(not battle.begin_resolution(), "Incomplete party plan cannot resolve")
	check(not plan(battle, 0, 0), "Duplicate actor action rejected")
	check(plan(battle, 1, 1, 0.5) and battle.next_planner() == -1, "Last ally completes planning")
	check(battle.begin_resolution(), "Full queue enters resolution")
	check(execute(battle).actor == 0 and battle.enemy.exposed == 0.25, "Fast warrior resolves first and applies expose")
	var event: Dictionary = execute(battle)
	check(event.actor == 1 and event.amount == 81 and not event.perfect, "Stored partial score resolves with earlier ally's expose")
	check(battle.party[0].mp == 4 and battle.party[1].mp == 12, "MP charged once during resolution")
	check(execute(battle).is_empty() and battle.turn_cursor == 2, "Enemy response follows completed party queue")
	battle.apply_enemy()
	battle.finish_round()
	check(battle.round_number == 2 and battle.turn_cursor == 0 and battle.queued_actions.is_empty(), "Enemy completion starts a clean planning round")
	check(battle.party[0].mp == 6 and battle.party[1].mp == 14, "Both living allies recover two MP once per round")
	battle = duo()
	battle.party[1].speed = 23
	plan(battle, 0, 1)
	check(battle.turn_cursor == 1, "Planning stays in party order regardless of speed")
	plan(battle, 1, 1, 0.5)
	battle.begin_resolution()
	event = execute(battle)
	check(event.actor == 1 and event.amount == 65, "Higher mage speed changes action order and damage interactions")
	check(execute(battle).actor == 0, "Slower warrior resolves second")
	battle = duo()
	battle.party[1].speed = battle.party[0].speed
	plan(battle, 0, 0)
	plan(battle, 1, 0)
	battle.begin_resolution()
	check(execute(battle).actor == 0 and execute(battle).actor == 1, "Speed ties use stable party order")
	battle = duo()
	battle.tonics = 1
	battle.party[0].hp = 20
	check(plan(battle, 0, 4, 0, 0), "Tonic can be queued without rhythm")
	check(battle.tonics == 1 and battle.party[0].hp == 20 and battle.available_tonics() == 0, "Queued tonic reserves stock without using it or healing")
	check(not battle.can_plan(1, battle.actions(1)[4]) and not plan(battle, 1, 4, 0, 1), "Second ally cannot overbook shared tonic")
	plan(battle, 1, 0, 0)
	battle.begin_resolution()
	execute(battle)
	check(battle.tonics == 0 and battle.party[0].hp == 85, "Tonic is consumed and heals once at execution")
	execute(battle)
	check(battle.enemy.hp == 650, "Queued zero accuracy still misses")
	battle = duo()
	battle.party[0].hp = 0
	battle.turn_cursor = battle.next_planner()
	check(battle.turn_cursor == 1, "Fallen actor is skipped while planning")
	plan(battle, 1, 4, 0, 0)
	battle.begin_resolution()
	execute(battle)
	check(battle.party[0].hp == 55 and execute(battle).is_empty(), "Revived actor does not gain an unplanned action mid-round")
	battle.apply_enemy()
	battle.finish_round()
	check(battle.next_planner() == 0, "Revived actor joins the next planning round")
	battle = duo()
	battle.enemy.hp = 1
	plan(battle, 0, 0)
	plan(battle, 1, 1)
	battle.begin_resolution()
	execute(battle)
	check(battle.outcome == "victory" and execute(battle).is_empty() and battle.party[1].mp == 32, "Victory stops unused queue entries without charging their MP")
	battle = duo()
	plan(battle, 0, 0)
	plan(battle, 1, 0)
	battle.begin_resolution()
	battle.party[0].hp = 0
	check(execute(battle).actor == 1, "Actor fallen before execution is skipped safely")
	# Scene: records first performance, saves its plan, resolves by speed after second.
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.battle.party[2].hp = 0
	scene._update_poses()
	scene._show_commands()
	scene.battle.party[1].speed = 23
	scene.choose_action(1)
	play_perfect(scene.rhythm)
	check(scene.phase == "select" and scene.battle.turn_cursor == 1 and scene.battle.enemy.hp == 650 and scene.battle.party[0].mp == 24, "First minigame ends in planning without attack or MP charge")
	var saved: Dictionary = scene.make_save()
	check(saved.queue.size() == 1 and scene.valid_save(saved), "Save contains completed queued action and score")
	scene._open_lab()
	await settle_scene()
	var lab = current_scene
	lab.mode_button.pressed.emit()
	await settle_scene()
	scene = current_scene
	check(scene.battle.queued_actions.size() == 1 and scene.battle.turn_cursor == 1 and scene.battle.enemy.hp == 650, "Rhythm Lab return preserves the first planned action")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.queue.append(invalid.queue[0].duplicate())
	check(not scene.valid_save(invalid), "Save rejects duplicate actor queue entries")
	invalid = saved.duplicate(true)
	invalid.queue[0].accuracy = 1.1
	check(not scene.valid_save(invalid), "Save rejects invalid rhythm scores")
	scene.restore_save(saved)
	check(scene.battle.queued_actions.size() == 1 and scene.battle.queued_for(0).accuracy == 1 and scene.battle.turn_cursor == 1, "Loading retains planned skill and skips its minigame")
	scene.choose_action(1)
	play_perfect(scene.rhythm)
	check(scene.phase == "resolve" and scene.history.size() == 1 and scene.history[0].begins_with("Flame Sonata"), "Scene begins with faster mage only after all planning finishes")
	var shell: Shell = root.get_node("GameShell")
	shell.open_menu()
	await create_timer(0.3).timeout
	check(scene.history.size() == 1, "Pause freezes queue animation and subsequent actions")
	shell.resume_game(false)
	await wait_for_command(scene)
	check(scene.history.size() == 3 and scene.history[1].begins_with("Rending Riff") and scene.history[2].begins_with("Heavy Cleave"), "Whole party resolves in speed order before enemy response")
	check(scene.battle.round_number == 2 and scene.battle.queued_actions.is_empty(), "Scene returns to next round planning")
	# Saving mid-resolution rolls back to the pre-batch command checkpoint.
	scene.restore_save(saved)
	scene.choose_action(1)
	play_perfect(scene.rhythm)
	var checkpoint: Dictionary = scene.make_save()
	check(checkpoint.enemy.hp == 650 and checkpoint.queue.size() == 1 and checkpoint.party[1].mp == 32, "Mid-resolution checkpoint avoids partial damage and costs")
	scene.restore_save(checkpoint)
	await create_timer(1).timeout
	check(scene.battle.enemy.hp == 650 and scene.history.is_empty() and scene.phase == "select", "Restoring cancels stale resolution callbacks")
	# Older turn-by-turn saves must not replay an already completed actor.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("queue")
	legacy.erase("spent")
	legacy.enemy.hp = 538
	scene.restore_save(legacy)
	check(scene.battle.spent_actors == [0] and scene.battle.turn_cursor == 1, "Legacy mid-round save marks prior actor spent")
	scene.choose_action(0)
	play_perfect(scene.rhythm)
	await wait_for_command(scene)
	check(scene.history.size() == 2 and scene.history[0].begins_with("Spark"), "Legacy restore resolves only remaining ally then enemy")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	print("Action queue checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func wait_for_command(scene: Node) -> void:
	for tick in range(120):
		if scene.phase in ["select", "victory", "defeat"]:
			return
		await create_timer(0.05).timeout
	check(false, "Queue resolution timed out")

func settle_scene() -> void:
	await process_frame
	await process_frame
	await process_frame

func play_perfect(rhythm: Node) -> void:
	rhythm.preparation_left = 0
	for note in rhythm.session.notes:
		var lane := 0
		while rhythm.instrument == "piano" and (1 << lane) != int(note.mask):
			lane += 1
		rhythm.session.press(note.time, lane, note.mask, note.direction)
	rhythm.time = Rhythm.END
	rhythm.held = 15
	rhythm._process(0.01)

func duo() -> RefCounted:
	var battle = Rules.new()
	battle.party.resize(2)
	return battle
