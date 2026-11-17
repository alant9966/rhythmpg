extends SceneTree
const Rules = preload("res://combat/battle_state.gd")
const Rhythm = preload("res://combat/combat_rhythm.gd")
const Helpers = preload("res://tests/combat_test_helpers.gd")
const Session = preload("res://rhythm/rhythm_session.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var battle = Rules.new()
	battle.party.resize(2)
	var event: Dictionary = battle.apply_player(0, battle.actions(0)[0], -1, 0)
	check(event.amount == 0 and battle.enemy.hp == 650 and event.missed, "Zero accuracy misses without damage")
	reset_duo(battle)
	event = battle.apply_player(0, battle.actions(0)[0], -1, 1)
	check(event.amount == 108 and event.perfect, "Perfect attack adds a critical multiplier")
	reset_duo(battle)
	check(battle.apply_player(1, battle.actions(1)[0], -1, 1).is_empty(), "Wrong actor cannot act")
	battle.party[0].mp = 0
	check(not battle.can_use(0, battle.actions(0)[1]), "Unaffordable skill disabled")
	check(battle.apply_player(0, battle.actions(0)[1], -1, 1).is_empty(), "Unaffordable skill cannot resolve")
	reset_duo(battle)
	battle.apply_player(0, battle.actions(0)[1], -1, 1)
	check(battle.party[0].mp == 18 and battle.enemy.exposed_turns == 2, "Riff spends MP and exposes enemy")
	battle.turn_cursor = 1
	event = battle.apply_player(1, battle.actions(1)[1], -1, 1)
	check(event.amount == 163, "Expose amplifies the mage's damage")
	check(battle.enemy.burn == 18 and battle.enemy.burn_turns == 2, "Accuracy scales burn")
	battle.turn_cursor = 2
	event = battle.apply_enemy()
	check(event.burn == 18 and battle.enemy.burn_turns == 1 and battle.enemy.exposed_turns == 1, "Status durations tick on enemy turn")
	check(event.hits.size() == 1 and event.hits[0].target == 0, "Round one cleave hits telegraphed warrior")
	battle.finish_round()
	check(battle.round_number == 2 and battle.turn_cursor == 0, "Round order wraps to warrior")
	check(battle.intent().target == 1, "Round two cleave targets mage")
	reset_duo(battle)
	battle.apply_player(0, battle.actions(0)[2], -1, 1)
	check(battle.party[0].shield == 51 and battle.party[1].shield == 51, "Perfect shield adds 50% potency")
	battle.turn_cursor = 2
	event = battle.apply_enemy()
	check(event.hits[0].amount == 0 and battle.party[0].shield == 26, "Shield absorbs enemy hit before HP")
	reset_duo(battle)
	battle.apply_player(0, battle.actions(0)[3], -1, 0.5)
	battle.turn_cursor = 2
	event = battle.apply_enemy()
	check(event.hits[0].amount == 16 and not battle.party[0].guard, "Guard strength scales with accuracy and consumes next hit")
	reset_duo(battle)
	battle.party[0].hp = 50
	battle.turn_cursor = 1
	event = battle.apply_player(1, battle.actions(1)[2], 0, 1)
	check(event.amount == 80 and battle.party[0].hp == 130, "Perfect healing restores 80 HP")
	battle.party[0].hp = 0
	check(battle.apply_player(1, battle.actions(1)[2], 0, 1).is_empty(), "Healing cannot revive")
	event = battle.apply_player(1, battle.actions(1)[4], 0, 0)
	check(battle.party[0].hp == 55 and battle.tonics == 1, "Tonic revives and spends inventory")
	reset_duo(battle)
	battle.party[1].hp = 0
	check(battle.queue_action(0, battle.actions(0)[0], -1, 1) and battle.next_planner() == -1, "Fallen ally is skipped during planning")
	check(battle.intent().target == 0, "Enemy retargets surviving hero")
	battle.round_number = 3
	check(battle.intent().target == -1, "Every third round announces party attack")
	reset_duo(battle)
	battle.turn_cursor = 2
	battle.enemy.hp = 5
	battle.enemy.burn = 10
	battle.enemy.burn_turns = 1
	event = battle.apply_enemy()
	check(battle.outcome == "victory" and event.hits.is_empty(), "Burn kill prevents enemy attack")
	reset_duo(battle)
	battle.party[0].hp = 1
	battle.party[1].hp = 0
	battle.turn_cursor = 2
	battle.apply_enemy()
	check(battle.outcome == "defeat", "All fallen heroes end battle in defeat")
	# Both compact charts retain a reachable perfect score at 120 BPM.
	for mode in ["piano", "guitar"]:
		var session = Session.new()
		var chart: Array[Dictionary] = Rhythm.chart(mode)
		session.setup(mode, chart)
		for note in chart:
			var lane := 0
			while mode == "piano" and (1 << lane) != int(note.mask):
				lane += 1
			session.press(note.time, lane, note.mask, note.direction)
		session.advance(Rhythm.END, 10 if mode == "piano" else 3)
		check(session.accuracy() == 1.0 and session.is_complete(), mode + " combat chart scores 100%")
		check(Rhythm.END < 3.0, mode + " combat performance lasts under three seconds")
	# Scene integration: commands first, actual instruments at execution.
	var scene = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	bench_maro(scene)
	check(scene.phase == "select" and scene.heroes.size() == 3, "Combat scene initializes editor actors")
	scene.choose_action(1)
	check(scene.phase == "select" and scene.battle.turn_cursor == 1 and not scene.rhythm.active, "Warrior command waits without a performance or cost")
	check(scene.battle.enemy.hp == 650 and scene.battle.party[0].mp == 24, "Planning applies no damage or resource costs")
	scene.choose_action(2)
	check(scene.phase == "target", "Healing opens ally target selection")
	scene._show_commands()
	for round_index in range(8):
		if not scene.battle.outcome.is_empty():
			break
		while scene.phase == "select":
			var actor: int = scene.battle.turn_cursor
			scene.choose_action(1 if scene.battle.party[actor].mp >= (6 if actor == 0 else 8) else 0)
		check(await Helpers.finish_round(scene), "Round completes through actual rhythm scoring")
	check(scene.phase == "victory" and scene.battle.enemy.hp == 0, "Full encounter reaches victory via both instruments")
	scene.restart()
	bench_maro(scene)
	check(scene.phase == "select" and scene.battle.enemy.hp == 650 and scene.battle.tonics == 2, "Replay resets battle and inventory")
	scene.choose_action(0)
	scene.choose_action(3)
	check(scene.rhythm.instrument == "guitar", "First acting ally starts guitar after all commands")
	await create_timer(scene.rhythm.EMPTY_RUNWAY_SECONDS + scene.rhythm.END + 1.2).timeout
	check(scene.battle.enemy.hp == 650 and scene.resonance == [0.0], "Actual no-input audio performance misses at execution")
	check(await Helpers.finish_round(scene), "Remaining rhythm and enemy action finish round")
	scene.restart()
	bench_maro(scene)
	scene.battle.party[0].hp = 100
	scene.choose_action(3)
	scene.choose_action(2)
	scene.choose_target(0)
	check(await Helpers.finish_round(scene) and scene.battle.party[0].hp == 180, "Queued guard precedes enemy and targeted healing still resolves")
	scene.restart()
	bench_maro(scene)
	scene.choose_action(2)
	check(scene.battle.party[0].shield == 0, "Iron Chorus waits during planning")
	scene.choose_action(3)
	play_perfect(scene.rhythm)
	check(await Helpers.finish_round(scene), "Shield and piano guard resolve around enemy action")
	check(scene.battle.party[0].hp == 180 and scene.battle.party[0].shield == 26 and scene.battle.party[1].guard_strength == 1.0, "Shield absorption and guard survive interleaved enemy turn")
	scene.restart()
	bench_maro(scene)
	scene.battle.party[1].hp = 0
	scene._update_poses()
	scene.choose_action(4)
	scene.choose_target(1)
	check(await Helpers.finish_round(scene), "Tonic-only round completes without a minigame")
	check(scene.battle.party[1].hp == 55 and not scene.heroes[1].dead and scene.battle.tonics == 1, "Tonic revives mage visually and consumes inventory")
	scene.restart()
	bench_maro(scene)
	scene.choose_action(1)
	scene.choose_action(0)
	scene.restart()
	bench_maro(scene)
	check(not scene.rhythm.active and scene.battle.party[0].mp == 24 and scene.phase == "select", "Restart cancels active execution performance without stale costs")
	# Verify packed effect coordinates against the actual supplied image dimensions.
	for spec in scene.EFFECTS.values():
		var texture: Texture2D = load(spec[0])
		var metadata := FileAccess.get_file_as_string(str(spec[0]).replace(".png", ".txt"))
		var valid := true
		for line in metadata.split("\n", false):
			var values := line.strip_edges().split(" = ")[1].split(" ", false)
			valid = valid and int(values[0]) + int(values[2]) <= texture.get_width()
			valid = valid and int(values[1]) + int(values[3]) <= texture.get_height()
		check(valid, "Effect atlas rectangles stay within " + str(spec[0]))
	scene.restart()
	bench_maro(scene)
	scene.battle.party[0].hp = 0
	scene.battle.party[1].hp = 0
	scene.battle._check_outcome()
	scene._show_outcome()
	check(scene.phase == "defeat", "Scene renders defeat state")
	scene.bgm.stop()
	scene.rhythm.cancel()
	scene.queue_free()
	await create_timer(0.2).timeout
	print("Combat checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func wait_for_command(scene: Node) -> void:
	for tick in range(100):
		if scene.phase in ["select", "victory", "defeat"]:
			return
		await create_timer(0.05).timeout
	check(false, "Scene action flow timed out")

func play_perfect(rhythm: Node) -> void:
	Helpers.prepare(rhythm)
	rhythm.preparation_left = 0
	var mode: String = rhythm.instrument
	var chart: Array[Dictionary] = rhythm.session.notes.duplicate(true)
	if mode == "guitar":
		for lane in range(3):
			if rhythm.chord_mask & (1 << lane):
				key(rhythm, [KEY_S, KEY_D, KEY_F][lane], true)
	for note in chart:
		rhythm.time = note.time
		if mode == "guitar":
			var code := KEY_DOWN if int(note.direction) == 1 else KEY_UP
			key(rhythm, code, true)
			key(rhythm, code, false)
		else:
			var lane := 0
			while (1 << lane) != int(note.mask):
				lane += 1
			var code: int = [KEY_D, KEY_F, KEY_J, KEY_K][lane]
			key(rhythm, code, true)
			if note.duration == 0:
				key(rhythm, code, false)
	rhythm.time = Rhythm.END
	rhythm._process(0.01)

func key(node: Node, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	node._input(event)

func reset_duo(battle: RefCounted) -> void:
	battle.reset()
	battle.party.resize(2)

func bench_maro(scene: Node) -> void:
	# Keep the original two-character encounter scenarios as regressions.
	scene.battle.party[2].hp = 0
	scene._update_poses()
	scene._show_commands()
