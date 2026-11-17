class_name BattleState
extends RefCounted
## Pure encounter rules. Accuracy is normalized, shared with RhythmSession.
var party: Array[Dictionary] = []
var enemy: Dictionary = {}
var round_number := 1
var turn_cursor := 0
var tonics := 2
var outcome := ""
var last_event := ""
var queued_actions: Array[Dictionary] = []
var resolution_queue: Array[Dictionary] = []
var resolution_index := 0
var resolution_active := false
const SPEED_FIELDS := ["haste", "haste_turns", "haste_round", "slow", "slow_turns", "slow_round"]
var spent_actors: Array[int] = [] # Migration of saves made after an old-style turn.

func _init() -> void:
	reset()

func reset() -> void:
	party = [
		{"name": "Rowan", "job": "Warrior", "instrument": "guitar", "hp": 180, "max_hp": 180,
			"mp": 24, "max_mp": 24, "attack": 24, "magic": 8, "defense": 14, "speed": 15, "shield": 0, "guard": false, "guard_strength": 0.0},
		{"name": "Lyra", "job": "Mage", "instrument": "piano", "hp": 124, "max_hp": 124,
			"mp": 32, "max_mp": 32, "attack": 10, "magic": 30, "defense": 8, "speed": 12, "shield": 0, "guard": false, "guard_strength": 0.0},
		{"name": "Maro", "job": "Percussionist", "instrument": "timpani", "hp": 148, "max_hp": 148,
			"mp": 28, "max_mp": 28, "attack": 28, "magic": 14, "defense": 12, "speed": 10, "shield": 0, "guard": false, "guard_strength": 0.0},
	]
	enemy = {"name": "The Hollow Warden", "hp": 650, "max_hp": 650, "attack": 39,
		"defense": 12, "resist": 10, "speed": 13, "burn": 0, "burn_turns": 0,
		"exposed": 0.0, "exposed_turns": 0, "stagger_turns": 0}
	for entity in party + [enemy]:
		for key in SPEED_FIELDS:
			entity[key] = 0
	round_number = 1
	turn_cursor = 0
	tonics = 2
	outcome = ""
	last_event = "An ancient sentinel bars the woodland passage."
	queued_actions.clear()
	resolution_queue.clear()
	resolution_index = 0
	resolution_active = false
	spent_actors.clear()

func actions(actor: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if actor == 0:
		result = [
			{"id": "attack", "name": "Downstroke", "cost": 0, "target": "enemy", "power": 24,
				"perfect": "CRITICAL x1.5", "description": "Up to 72 damage, scaled by accuracy. Perfect: critical strike for 108 damage. 0% misses."},
			{"id": "rend", "name": "Rending Riff", "cost": 6, "target": "enemy", "power": 44,
				"perfect": "EXPOSE +25% / 2 TURNS", "description": "Up to 112 damage and up to -4 enemy SPD for 2 rounds, scaled by accuracy. Perfect: expose the foe (+25% damage, 2 enemy turns)."},
			{"id": "shield", "name": "Iron Chorus", "cost": 4, "target": "party", "power": 14,
				"perfect": "SHIELD x1.5", "description": "Up to 34 shield HP per ally, scaled by accuracy. Perfect: 51 shield HP. 0% fails."},
		]
	elif actor == 1:
		result = [
			{"id": "attack", "name": "Spark", "cost": 0, "target": "enemy", "power": 22,
				"perfect": "ARCANE CRITICAL x1.5", "description": "Up to 84 magic damage, scaled by accuracy. Perfect: critical bolt for 126 damage. 0% misses."},
			{"id": "flame", "name": "Flame Sonata", "cost": 8, "target": "enemy", "power": 45,
				"perfect": "BURN 18 / 2 TURNS", "description": "Up to 130 damage, scaled by accuracy. Perfect: burn for 18 HP on each of 2 enemy turns."},
			{"id": "heal", "name": "Mending Chord", "cost": 7, "target": "ally", "power": 35,
				"perfect": "RESTORE 6 MP", "description": "Restore up to 80 HP, scaled by accuracy. Perfect: also restore 6 MP. Living allies only."},
		]
	else:
		result = [
			{"id": "attack", "name": "Drumstrike", "cost": 0, "target": "enemy", "power": 24,
				"perfect": "THUNDER CRITICAL x1.5", "description": "Up to 80 damage, scaled by accuracy. Perfect: a 120-damage thunder critical."},
			{"id": "thunder", "name": "Thunder Roll", "cost": 8, "target": "enemy", "power": 42,
				"perfect": "STAGGER / SKIP ENEMY RESPONSE", "description": "Up to 116 damage, scaled by accuracy. Perfect: stagger the enemy, skipping its next response."},
			{"id": "rally", "name": "Rallying Beat", "cost": 6, "target": "party", "power": 4,
				"perfect": "PARTY HEAL 20 HP", "description": "Restore up to 4 MP and grant up to +4 SPD for 2 rounds to every living ally, scaled by accuracy. Perfect: also restore 20 HP each."},
		]
	result.append({"id": "guard", "name": "Guard / Recover", "cost": 0, "target": "self", "power": 0,
		"perfect": "FULL BLOCK / +4 BONUS MP", "description": "Play your instrument: up to 75% next-hit reduction and 4 MP, scaled by accuracy. Perfect: full block and 8 MP."})
	result.append({"id": "tonic", "name": "Field Tonic", "cost": 0, "target": "ally", "power": 65,
		"description": "Restore 65 HP, or revive a fallen ally with 55 HP. Two per battle."})
	return result

func can_use(actor: int, action: Dictionary) -> bool:
	return outcome.is_empty() and turn_cursor == actor and party[actor].hp > 0 and party[actor].mp >= action.cost and (action.id != "tonic" or tonics > 0)

func action_for(actor: int, id: String) -> Dictionary:
	for action in actions(actor):
		if action.id == id:
			return action
	return {}

func queued_for(actor: int) -> Dictionary:
	for entry in queued_actions:
		if entry.actor == actor:
			return entry
	return {}

func available_tonics() -> int:
	var reserved := 0
	for entry in queued_actions:
		if entry.action_id == "tonic":
			reserved += 1
	return maxi(0, tonics - reserved)

func can_plan(actor: int, action: Dictionary) -> bool:
	return not resolution_active and actor not in spent_actors and queued_for(actor).is_empty() and can_use(actor, action) and (action.id != "tonic" or available_tonics() > 0)

func next_planner() -> int:
	for actor in range(party.size()):
		if party[actor].hp > 0 and actor not in spent_actors and queued_for(actor).is_empty():
			return actor
	return -1

func queue_action(actor: int, action: Dictionary, target: int, accuracy: float = -1.0) -> bool:
	if not can_plan(actor, action) or action_for(actor, action.id).is_empty():
		return false
	if action.target == "ally" and (target < 0 or target >= party.size() or (action.id == "heal" and party[target].hp <= 0)):
		return false
	# Scores are earned at execution. Optional scores support standalone rules callers.
	var entry := {"actor": actor, "action_id": action.id, "target": target}
	if accuracy >= 0:
		entry.accuracy = clampf(accuracy, 0, 1)
	queued_actions.append(entry)
	var next := next_planner()
	if next >= 0:
		turn_cursor = next
	return true

func effective_speed(actor: int) -> int:
	var entity: Dictionary = enemy if actor == party.size() else party[actor]
	return maxi(1, int(entity.speed) + int(entity.get("haste", 0)) - int(entity.get("slow", 0)))

func speed_order() -> Array[int]:
	var order: Array[int] = []
	for actor in range(party.size()):
		if party[actor].hp > 0 and actor not in spent_actors:
			order.append(actor)
	if enemy.hp > 0:
		order.append(party.size())
	order.sort_custom(func(a: int, b: int):
		return a < b if effective_speed(a) == effective_speed(b) else effective_speed(a) > effective_speed(b))
	return order

func begin_resolution() -> bool:
	if resolution_active or not outcome.is_empty() or next_planner() >= 0 or queued_actions.is_empty():
		return false
	resolution_queue = queued_actions.duplicate(true)
	resolution_queue.append({"actor": party.size(), "action_id": "enemy", "target": -1})
	resolution_index = 0
	resolution_active = true
	return true

func take_next_action() -> Dictionary:
	_check_outcome()
	if not resolution_active or not outcome.is_empty():
		return {}
	# Reorder only the unacted suffix. Haste/slow cannot grant extra actions.
	var pending: Array[Dictionary] = []
	for index in range(resolution_index, resolution_queue.size()):
		pending.append(resolution_queue[index])
	pending.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.actor < b.actor if effective_speed(a.actor) == effective_speed(b.actor) else effective_speed(a.actor) > effective_speed(b.actor))
	for index in range(pending.size()):
		resolution_queue[resolution_index + index] = pending[index]
	while resolution_index < resolution_queue.size():
		var entry: Dictionary = resolution_queue[resolution_index]
		resolution_index += 1
		if entry.actor < party.size() and party[entry.actor].hp <= 0:
			continue
		turn_cursor = int(entry.actor)
		return entry.duplicate(true)
	return {}

func change_speed(entity: Dictionary, kind: String, amount: int) -> void:
	entity[kind] = maxi(int(entity.get(kind, 0)), amount)
	entity[kind + "_turns"] = 2
	entity[kind + "_round"] = round_number

func _tick_speed() -> void:
	for entity in party + [enemy]:
		for kind in ["haste", "slow"]:
			if int(entity.get(kind + "_turns", 0)) > 0 and int(entity.get(kind + "_round", 0)) < round_number:
				entity[kind + "_turns"] -= 1
				if entity[kind + "_turns"] == 0:
					entity[kind] = 0

func finish_round() -> void:
	_check_outcome()
	if not outcome.is_empty():
		return
	queued_actions.clear()
	resolution_queue.clear()
	resolution_index = 0
	resolution_active = false
	spent_actors.clear()
	_tick_speed()
	round_number += 1
	for hero in party:
		if hero.hp > 0:
			hero.mp = mini(hero.max_mp, hero.mp + 2)
	turn_cursor = next_planner()

func intent() -> Dictionary:
	if enemy.stagger_turns > 0:
		return {"name": "Staggered", "target": -1, "description": "The Warden will skip its response."}
	if round_number % 3 == 0:
		return {"name": "Dissonant Wave", "target": -1, "description": "A wave will strike the party and inflict -3 SPD for 2 rounds."}
	var cleave := round_number - 1 - floori((round_number - 1) / 3.0)
	var target := cleave % party.size()
	for offset in range(party.size()):
		if party[(target + offset) % party.size()].hp > 0:
			target = (target + offset) % party.size()
			break
	return {"name": "Heavy Cleave", "target": target, "description": "A heavy strike aimed at " + str(party[target].name) + "."}

func apply_player(actor: int, action: Dictionary, target: int, accuracy: float) -> Dictionary:
	if not can_use(actor, action):
		return {}
	if action.target == "ally" and (target < 0 or target >= party.size() or (action.id == "heal" and party[target].hp <= 0)):
		return {}
	var a := clampf(accuracy, 0.0, 1.0)
	party[actor].mp -= int(action.cost)
	var perfect: bool = a == 1.0 and action.id != "tonic"
	var event := {"id": action.id, "actor": actor, "target": target, "accuracy": a, "amount": 0, "hits": [],
		"missed": a == 0.0 and action.id != "tonic", "perfect": perfect, "bonus": "", "mp": 0}
	if event.missed:
		last_event = "%s MISSED — 0%% accuracy. No effect." % action.name
		return event
	if perfect:
		event.bonus = action.get("perfect", "")
	match action.id:
		"guard":
			party[actor].guard = true
			party[actor].guard_strength = 1.0 if perfect else 0.75 * a
			event.amount = roundi(party[actor].guard_strength * 100)
			event.mp = 8 if perfect else maxi(1, roundi(4 * a))
			party[actor].mp = mini(party[actor].max_mp, party[actor].mp + event.mp)
			last_event = "%s guards the next hit by %d%% and recovers %d MP." % [party[actor].name, event.amount, event.mp]
		"tonic", "heal":
			var amount: int = 65 if action.id == "tonic" else maxi(1, roundi(80 * a))
			if action.id == "tonic":
				tonics -= 1
				if party[target].hp == 0:
					amount = 55
			var before: int = party[target].hp
			party[target].hp = mini(party[target].max_hp, party[target].hp + amount)
			event.amount = party[target].hp - before
			if perfect:
				var mp_before: int = party[target].mp
				party[target].mp = mini(party[target].max_mp, party[target].mp + 6)
				event.mp = party[target].mp - mp_before
			last_event = "%s restores %d HP to %s." % [party[actor].name, event.amount, party[target].name]
		"shield":
			event.amount = 51 if perfect else maxi(1, roundi(34 * a))
			for hero in party:
				if hero.hp > 0:
					hero.shield = maxi(hero.shield, event.amount)
			last_event = "Iron Chorus grants each living ally a %d HP shield." % event.amount
		"rally":
			event.amount = maxi(1, roundi(4 * a))
			for hero in party:
				if hero.hp > 0:
					hero.mp = mini(hero.max_mp, hero.mp + event.amount)
					change_speed(hero, "haste", maxi(1, roundi(4 * a)))
					if perfect:
						hero.hp = mini(hero.max_hp, hero.hp + 20)
			last_event = "Rallying Beat restores up to %d MP and grants +%d SPD to every living ally." % [event.amount, maxi(1, roundi(4 * a))]
		_:
			var stat: int = party[actor].magic if actor == 1 else party[actor].attack
			var defense: int = enemy.resist if actor == 1 else enemy.defense
			var critical := 1.5 if perfect and action.id == "attack" else 1.0
			event.amount = maxi(1, roundi(maxi(1, action.power + stat - defense) * 2.0 * a * critical * (1.0 + float(enemy.exposed))))
			enemy.hp = maxi(0, enemy.hp - event.amount)
			if action.id == "rend":
				change_speed(enemy, "slow", maxi(1, roundi(4 * a)))
			if perfect and action.id == "rend":
				enemy.exposed = 0.25
				enemy.exposed_turns = 2
			if perfect and action.id == "flame":
				enemy.burn = 18
				enemy.burn_turns = 2
			if perfect and action.id == "thunder":
				enemy.stagger_turns = 1
			last_event = "%s deals %d damage — %.1f%% accuracy." % [action.name, event.amount, a * 100]
	if perfect:
		last_event += " PERFECT: " + str(event.bonus) + "."
	_check_outcome()
	return event

func apply_enemy() -> Dictionary:
	if turn_cursor != party.size() or not outcome.is_empty():
		return {}
	var event := {"id": "enemy", "hits": [], "burn": 0, "name": "", "staggered": false}
	if enemy.burn_turns > 0:
		event.burn = enemy.burn
		enemy.hp = maxi(0, enemy.hp - enemy.burn)
		enemy.burn_turns -= 1
		_check_outcome()
		if not outcome.is_empty():
			last_event = "The Warden falls to the lingering flame."
			return event
	if enemy.stagger_turns > 0:
		enemy.stagger_turns -= 1
		event.staggered = true
		event.name = "STAGGERED"
		last_event = "Thunder Roll staggered the Warden — its response is skipped."
		_tick_expose()
		return event
	var next: Dictionary = intent()
	event.name = next.name
	for target in range(party.size()):
		if party[target].hp <= 0 or (next.target != -1 and next.target != target):
			continue
		var hero: Dictionary = party[target]
		var damage: int = maxi(1, (34 if next.target == -1 else enemy.attack) - hero.defense)
		if hero.guard:
			damage = ceili(damage * (1.0 - float(hero.guard_strength)))
			hero.guard = false
			hero.guard_strength = 0.0
		var absorbed: int = mini(hero.shield, damage)
		hero.shield -= absorbed
		damage -= absorbed
		hero.hp = maxi(0, hero.hp - damage)
		if next.target == -1 and hero.hp > 0:
			change_speed(hero, "slow", 3)
		event.hits.append({"target": target, "amount": damage, "absorbed": absorbed})
	_tick_expose()
	last_event = str(next.name) + " crashes through the clearing."
	_check_outcome()
	return event

func _tick_expose() -> void:
	if enemy.exposed_turns > 0:
		enemy.exposed_turns -= 1
		if enemy.exposed_turns == 0:
			enemy.exposed = 0.0

func _check_outcome() -> void:
	if enemy.hp <= 0:
		outcome = "victory"
	elif party.all(func(hero: Dictionary): return hero.hp <= 0):
		outcome = "defeat"
