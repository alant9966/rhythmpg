extends SceneTree
const Rules = preload("res://combat/battle_state.gd")
const Helpers = preload("res://tests/combat_test_helpers.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func plan_all(battle: RefCounted, indices: Array = [0, 0, 0]) -> void:
	for actor in range(battle.party.size()):
		if battle.party[actor].hp > 0:
			battle.queue_action(actor, battle.actions(actor)[indices[actor]], -1)

func execute(battle: RefCounted, accuracy: float = 1.0) -> Dictionary:
	var entry: Dictionary = battle.take_next_action()
	if entry.is_empty():
		return {}
	if entry.actor == battle.party.size():
		return battle.apply_enemy()
	return battle.apply_player(entry.actor, battle.action_for(entry.actor, entry.action_id), entry.target, accuracy)

func until_rhythm(scene: Node) -> bool:
	for tick in range(200):
		if scene.phase == "rhythm":
			return true
		await create_timer(0.02).timeout
	return false

func run() -> void:
	var battle = Rules.new()
	check(battle.enemy.speed == 13, "Warden has speed between Rowan and Lyra")
	check(battle.speed_order() == [0, 3, 1, 2], "All four combatants share speed order")
	check(battle.queue_action(0, battle.actions(0)[1], -1), "First command can be selected without a score")
	check(not battle.queued_for(0).has("accuracy") and battle.enemy.hp == 650 and battle.party[0].mp == 24, "Planning neither performs nor spends resources")
	check(not battle.begin_resolution(), "Incomplete plan cannot execute")
	check(not battle.queue_action(0, battle.actions(0)[0], -1), "Duplicate selections rejected")
	battle.queue_action(1, battle.actions(1)[0], -1)
	battle.queue_action(2, battle.actions(2)[0], -1)
	check(battle.begin_resolution(), "Whole-party plan starts execution")
	check(execute(battle, 0).actor == 0, "Fastest ally resolves first")
	check(execute(battle).id == "enemy" and battle.party[0].hp == 155, "Enemy executes before slower allies")
	check(execute(battle).actor == 1 and execute(battle).actor == 2, "Slower allies resolve after enemy")
	check(execute(battle).is_empty(), "Each combatant acts only once")
	battle.finish_round()
	check(battle.round_number == 2 and battle.turn_cursor == 0 and battle.queued_actions.is_empty(), "Round ends only after entire mixed sequence")
	battle = Rules.new()
	battle.enemy.speed = 99
	plan_all(battle)
	battle.begin_resolution()
	check(execute(battle).id == "enemy", "A fast enemy can act first")
	battle = Rules.new()
	battle.enemy.speed = 1
	plan_all(battle)
	battle.begin_resolution()
	check(execute(battle).actor == 0 and execute(battle).actor == 1 and execute(battle).actor == 2 and execute(battle).id == "enemy", "A slow enemy acts last")
	battle = Rules.new()
	for hero in battle.party:
		hero.speed = 13
	plan_all(battle)
	battle.begin_resolution()
	check(execute(battle).actor == 0 and execute(battle).actor == 1 and execute(battle).actor == 2 and execute(battle).id == "enemy", "Speed ties are deterministic")
	battle = Rules.new()
	plan_all(battle, [1, 0, 0])
	battle.begin_resolution()
	var event: Dictionary = execute(battle, 0.5)
	check(event.amount == 56 and battle.enemy.slow == 2 and battle.effective_speed(3) == 11, "Partial Rending Riff scales enemy slow")
	check(execute(battle).actor == 1 and execute(battle).id == "enemy" and execute(battle).actor == 2, "Slow immediately reorders remaining actions")
	battle = Rules.new()
	battle.party[2].speed = 20
	plan_all(battle, [0, 0, 2])
	battle.begin_resolution()
	check(execute(battle).actor == 2 and battle.effective_speed(1) == 16, "Rallying Beat grants allied haste")
	check(execute(battle).actor == 0 and execute(battle).actor == 1 and execute(battle).id == "enemy" and execute(battle).is_empty(), "Haste moves pending allies ahead without repeating the caster")
	battle.finish_round()
	check(battle.party[0].haste == 4, "New speed status survives application round")
	battle.finish_round()
	check(battle.party[0].haste_turns == 1, "Speed status ticks once at round boundary")
	battle.finish_round()
	check(battle.party[0].haste == 0 and battle.effective_speed(0) == 15, "Expired speed buff restores base speed")
	battle = Rules.new()
	battle.round_number = 3
	battle.turn_cursor = 3
	event = battle.apply_enemy()
	check(event.hits.size() == 3 and battle.party[0].slow == 3 and battle.effective_speed(0) == 12, "Dissonant Wave slows all surviving allies")
	battle.change_speed(battle.party[0], "haste", 4)
	check(battle.effective_speed(0) == 16, "Haste and slow coexist")
	battle.party[0].slow = 999
	check(battle.effective_speed(0) == 1, "Effective speed cannot fall below one")
	battle = Rules.new()
	battle.party[0].hp = 1
	battle.enemy.speed = 99
	plan_all(battle, [1, 0, 0])
	battle.begin_resolution()
	execute(battle)
	check(execute(battle).actor == 1 and battle.party[0].mp == 24, "Enemy kill skips fallen actor and unspent MP")
	battle = Rules.new()
	battle.enemy.hp = 1
	plan_all(battle, [0, 1, 0])
	battle.begin_resolution()
	execute(battle)
	check(battle.outcome == "victory" and execute(battle).is_empty() and battle.party[1].mp == 32, "Victory cancels enemy and unused ally actions")
	battle = Rules.new()
	battle.tonics = 1
	check(battle.queue_action(0, battle.actions(0)[4], 0), "Tonic command reserves inventory")
	check(battle.available_tonics() == 0 and not battle.can_plan(1, battle.actions(1)[4]), "Shared tonic cannot be overbooked")
	# Actual scene and editor-created visuals.
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await Helpers.settle(self)
	check(scene.stage == scene.get_node("Battlefield") and scene.heroes[0] == scene.get_node("Battlefield/Actors/Rowan"), "Controller uses authored nodes")
	check(scene.stage.get_child_count() == 4 and scene.heroes[2].timpani.get_child_count() == 2, "No duplicate stage and Maro retains drums")
	check(scene.heroes[0].animation_player.has_animation("attack") and scene.foe.sprite.flip_h and scene.foe.sprite.position.y == -32, "Combat animations and enemy cell size are configured")
	scene.choose_action(0)
	check(scene.phase == "select" and scene.battle.turn_cursor == 1 and not scene.rhythm.active, "Command immediately advances planning with no minigame")
	var saved: Dictionary = scene.make_save()
	check(saved.queue.size() == 1 and not saved.queue[0].has("accuracy") and scene.valid_save(saved), "Unscored planned action is saveable")
	scene._open_lab()
	await Helpers.settle(self)
	current_scene.mode_button.pressed.emit()
	await Helpers.settle(self)
	scene = current_scene
	check(scene.battle.queued_actions.size() == 1 and scene.battle.turn_cursor == 1, "Lab return preserves unscored plan")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.queue.append(invalid.queue[0].duplicate())
	check(not scene.valid_save(invalid), "Duplicate queue entries rejected on load")
	invalid = saved.duplicate(true)
	invalid.queue[0].accuracy = 1.1
	check(not scene.valid_save(invalid), "Invalid legacy score rejected")
	scene.choose_action(0)
	scene.choose_action(0)
	check(scene.phase == "rhythm" and scene.battle.turn_cursor == 0 and scene.battle.resolution_active, "Rhythm starts only when first ally executes")
	Helpers.perfect(scene.rhythm)
	await create_timer(scene.rhythm_focus_out_seconds + scene.rhythm_hud_fade_seconds + 0.05).timeout
	check(scene.phase == "resolve" and scene.history.size() == 1 and scene.battle.enemy.hp == 542, "Performance applies its action after returning to full combat")
	var shell = root.get_node("GameShell")
	shell.open_menu()
	await create_timer(0.3).timeout
	check(scene.history.size() == 1 and scene.battle.party[0].hp == 180, "Pause freezes pending enemy and action animation")
	shell.resume_game(false)
	check(await until_rhythm(scene) and scene.rhythm.instrument == "piano" and scene.history.size() == 2 and scene.battle.party[0].hp == 155, "Enemy resolves between guitar and piano performances")
	check(await Helpers.finish_round(scene) and scene.history.size() == 4 and scene.battle.round_number == 2, "Three performances and enemy complete exactly once")
	scene.restore_save(saved)
	scene.choose_action(0)
	scene.choose_action(0)
	Helpers.perfect(scene.rhythm)
	var checkpoint: Dictionary = scene.make_save()
	check(checkpoint.enemy.hp == 650 and checkpoint.queue.size() == 2 and checkpoint.party[0].mp == 24, "Execution saves use pre-sequence planning checkpoint")
	scene.restore_save(checkpoint)
	await create_timer(1).timeout
	check(scene.battle.enemy.hp == 650 and scene.history.is_empty() and scene.phase == "select", "Restore cancels stale animation and damage callbacks")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.queue[0].accuracy = 1.0
	legacy.enemy.speed = 10
	for entity in legacy.party + [legacy.enemy]:
		for field in Rules.SPEED_FIELDS:
			entity.erase(field)
	check(scene.valid_save(legacy), "Previous scored queues and speed-10 Warden saves validate")
	scene.restore_save(legacy)
	check(not scene.battle.queued_for(0).has("accuracy") and scene.battle.enemy.slow == 0, "Legacy plan migrates to execution-time performance")
	legacy.erase("queue")
	legacy.erase("spent")
	scene.restore_save(legacy)
	check(scene.battle.spent_actors == [0] and scene.battle.turn_cursor == 1, "Old turn-by-turn saves preserve spent actors")
	scene.restart()
	scene.battle.change_speed(scene.battle.party[1], "haste", 4)
	scene.battle.change_speed(scene.battle.enemy, "slow", 3)
	scene._show_commands()
	var speed_save: Dictionary = JSON.parse_string(JSON.stringify(scene.make_save()))
	check(scene.valid_save(speed_save), "Serialized speed-status save validates")
	scene.restore_save(speed_save)
	check(scene.battle.effective_speed(1) == 16 and scene.battle.effective_speed(3) == 10 and scene.battle.party[1].haste_turns == 2, "Save/load preserves speed magnitudes and expiry")
	invalid = speed_save.duplicate(true)
	invalid.enemy.slow = -1
	check(not scene.valid_save(invalid), "Malformed speed status is rejected")
	# Restart preserves all authored scenery and removes transient effects only.
	var scenery = scene.get_node("Battlefield/Atmosphere")
	scene._effect("strike", Vector2(300, 300))
	scene.restart()
	await process_frame
	check(is_instance_valid(scenery) and scene.effects.get_child_count() == 0 and scene.heroes[0].position == scene.heroes[0].ground, "Restart preserves editor scenery and actors")
	# Stagger earned after the enemy acts carries into its following action.
	scene.choose_action(0)
	scene.choose_action(0)
	scene.choose_action(1)
	check(await Helpers.finish_round(scene) and scene.battle.enemy.stagger_turns == 1, "Late Thunder Roll preserves stagger for next enemy action")
	var hp_before: int = scene.battle.party[1].hp
	scene.choose_action(3)
	scene.choose_action(3)
	scene.choose_action(3)
	check(await Helpers.finish_round(scene) and scene.battle.party[1].hp == hp_before and scene.battle.enemy.stagger_turns == 0 and scene.history.any(func(line: String): return line.contains("staggered")), "Next enemy action consumes stagger without attacking")
	scene.restart()
	# A complete high-speed enemy wipe never launches a hero performance.
	scene.battle.enemy.speed = 99
	for hero in scene.battle.party:
		hero.hp = 1
	scene.battle.round_number = 3
	scene.choose_action(0)
	scene.choose_action(0)
	scene.choose_action(0)
	check(await Helpers.finish_round(scene) and scene.phase == "defeat" and scene.resonance.is_empty(), "Enemy-first wipe cancels all hero minigames")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.1).timeout
	print("Action queue checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
