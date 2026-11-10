extends SceneTree
const Rules = preload("res://combat/battle_state.gd")
const Rhythm = preload("res://combat/combat_rhythm.gd")
const Maps = preload("res://combat/combat_beatmaps.gd")
const Session = preload("res://rhythm/rhythm_session.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func state(actor: int = 0):
	var battle = Rules.new()
	battle.turn_cursor = actor
	return battle

func run() -> void:
	# All rhythmic commands fail at zero, without creating statuses or MP recovery.
	for actor in range(2):
		for index in range(4):
			var battle = state(actor)
			battle.party[0].hp = 50
			battle.party[1].hp = 50
			battle.party[actor].mp = 12
			var action: Dictionary = battle.actions(actor)[index]
			var event: Dictionary = battle.apply_player(actor, action, 0 if action.target == "ally" else -1, 0)
			check(event.missed and event.amount == 0 and not event.perfect, "%s zero accuracy misses" % action.name)
			check(battle.enemy.hp == 650 and battle.enemy.burn_turns == 0 and battle.enemy.exposed_turns == 0, "%s miss does not damage or debuff" % action.name)
			check(battle.party[0].hp == 50 and battle.party[1].hp == 50 and battle.party[0].shield == 0 and not battle.party[actor].guard, "%s miss grants no support" % action.name)
			check(battle.party[actor].mp == 12 - action.cost, "%s miss spends its MP cost without recovery" % action.name)
	# Every integer accuracy 1..99 scales direct damage monotonically without bonus.
	for actor in range(2):
		for index in range(2):
			var previous := 0
			var valid := true
			for percent in range(1, 100):
				var battle = state(actor)
				var action: Dictionary = battle.actions(actor)[index]
				var event: Dictionary = battle.apply_player(actor, action, -1, percent / 100.0)
				var full: int = (action.power + (battle.party[actor].attack if actor == 0 else battle.party[actor].magic) - (battle.enemy.defense if actor == 0 else battle.enemy.resist)) * 2
				valid = valid and event.amount == maxi(1, roundi(full * percent / 100.0)) and event.amount >= previous
				valid = valid and not event.perfect and event.bonus.is_empty() and battle.enemy.burn_turns == 0 and battle.enemy.exposed_turns == 0
				previous = event.amount
			check(valid, "Actor %d attack %d scales over 1–99%% without perfect effects" % [actor, index])
	var battle = state()
	check(battle.apply_player(0, battle.actions(0)[0], -1, 0.5).amount == 36, "50% Downstroke deals half normal full damage")
	battle = state()
	check(battle.apply_player(0, battle.actions(0)[0], -1, 1).amount == 108, "Perfect Downstroke gains x1.5 critical")
	battle = state(1)
	check(battle.apply_player(1, battle.actions(1)[0], -1, 1).amount == 126, "Perfect Spark gains x1.5 critical")
	battle = state()
	battle.apply_player(0, battle.actions(0)[1], -1, 1)
	check(battle.enemy.exposed == 0.25 and battle.enemy.exposed_turns == 2, "Perfect Rending Riff exposes for two enemy turns")
	battle = state(1)
	battle.apply_player(1, battle.actions(1)[1], -1, 1)
	check(battle.enemy.burn == 18 and battle.enemy.burn_turns == 2, "Perfect Flame Sonata creates DOT")
	battle = state(1)
	battle.apply_player(1, battle.actions(1)[1], -1, 0.9999999)
	check(battle.enemy.burn_turns == 0, "Almost perfect does not receive perfect bonus")
	battle = state()
	battle.apply_player(0, battle.actions(0)[2], -1, 0.5)
	check(battle.party[0].shield == 17 and battle.party[1].shield == 17, "50% shield grants half potency")
	battle = state()
	battle.apply_player(0, battle.actions(0)[2], -1, 1)
	check(battle.party[0].shield == 51, "Perfect shield grants 50% bonus potency")
	battle = state(1)
	battle.party[0].hp = 20
	battle.party[0].mp = 0
	battle.apply_player(1, battle.actions(1)[2], 0, 0.5)
	check(battle.party[0].hp == 60 and battle.party[0].mp == 0, "Partial heal restores scaled HP with no MP bonus")
	battle = state(1)
	battle.party[0].hp = 20
	battle.party[0].mp = 0
	battle.apply_player(1, battle.actions(1)[2], 0, 1)
	check(battle.party[0].hp == 100 and battle.party[0].mp == 6, "Perfect heal also restores six MP")
	for actor in range(2):
		battle = state(actor)
		battle.party[actor].mp = 0
		battle.apply_player(actor, battle.actions(actor)[3], -1, 1)
		check(battle.party[actor].guard_strength == 1 and battle.party[actor].mp == 8, "Perfect guard fully protects actor %d and recovers eight MP" % actor)
		battle.round_number = 1 if actor == 0 else 2
		battle.turn_cursor = battle.party.size()
		var event: Dictionary = battle.apply_enemy()
		check(event.hits[0].amount == 0 and not battle.party[actor].guard and battle.party[actor].guard_strength == 0, "Perfect guard is consumed by one hit for actor %d" % actor)
	# Every variation is unique, sorted, valid for its instrument and 100%-playable.
	for mode in ["guitar", "piano"]:
		var unique := {}
		for variation in range(Maps.count(mode)):
			var chart: Array[Dictionary] = Maps.chart(mode, 3, variation)
			unique[JSON.stringify(chart)] = true
			var session = Session.new()
			session.setup(mode, chart)
			var valid := true
			var last := -1.0
			for n in chart:
				valid = valid and n.time >= last and n.time >= Rhythm.LEAD and n.time + n.duration < Rhythm.END
				last = n.time
				if mode == "guitar":
					valid = valid and n.mask == 3 and n.duration == 0 and n.direction in [-1, 1]
				else:
					valid = valid and n.mask in [1, 2, 4, 8] and n.direction == 0
				var lane := 0
				while mode == "piano" and (1 << lane) != int(n.mask):
					lane += 1
				session.press(n.time, lane, n.mask, n.direction)
			session.advance(Rhythm.END, 15)
			check(valid and session.accuracy() == 1 and session.is_complete(), "%s variation %d is valid and perfectly playable" % [mode, variation])
		check(unique.size() == 6, mode + " has six distinct beatmaps")
	# Shuffle bags are independent per instrument, cover all maps, and avoid repeats.
	var rhythm = Rhythm.new()
	root.add_child(rhythm)
	await process_frame
	rhythm.rng.seed = 4721
	for mode in ["guitar", "piano"]:
		var previous := -1
		for cycle in range(3):
			var seen := {}
			var repeat_free := true
			for use in range(6):
				rhythm.start(mode, "Guard / Recover", 3, "FULL BLOCK")
				seen[rhythm.variation_index] = true
				repeat_free = repeat_free and rhythm.variation_index != previous
				previous = rhythm.variation_index
			check(seen.size() == 6 and repeat_free, "%s shuffle cycle %d covers every map without repeats" % [mode, cycle])
	rhythm.cancel()
	rhythm.queue_free()
	await create_timer(0.1).timeout
	print("Accuracy and beatmap checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
