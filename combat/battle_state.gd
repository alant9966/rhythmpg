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

func _init() -> void:
	reset()

func reset() -> void:
	party = [
		{"name": "Rowan", "job": "Warrior", "instrument": "guitar", "hp": 180, "max_hp": 180,
			"mp": 24, "max_mp": 24, "attack": 24, "magic": 8, "defense": 14, "speed": 15, "shield": 0, "guard": false},
		{"name": "Lyra", "job": "Mage", "instrument": "piano", "hp": 124, "max_hp": 124,
			"mp": 32, "max_mp": 32, "attack": 10, "magic": 30, "defense": 8, "speed": 12, "shield": 0, "guard": false},
	]
	enemy = {"name": "The Hollow Warden", "hp": 650, "max_hp": 650, "attack": 39,
		"defense": 12, "resist": 10, "speed": 10, "burn": 0, "burn_turns": 0,
		"exposed": 0.0, "exposed_turns": 0}
	round_number = 1
	turn_cursor = 0
	tonics = 2
	outcome = ""
	last_event = "An ancient sentinel bars the woodland passage."

func actions(actor: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if actor == 0:
		result = [
			{"id": "attack", "name": "Downstroke", "cost": 0, "target": "enemy", "power": 24,
				"description": "A sharp guitar-led strike. 36–72 damage."},
			{"id": "rend", "name": "Rending Riff", "cost": 6, "target": "enemy", "power": 44,
				"description": "56–112 damage. Expose the foe: +10–25% damage for 2 enemy turns."},
			{"id": "shield", "name": "Iron Chorus", "cost": 4, "target": "party", "power": 14,
				"description": "Grant both allies a 14–34 HP shield. Replaces weaker shields."},
		]
	else:
		result = [
			{"id": "attack", "name": "Spark", "cost": 0, "target": "enemy", "power": 22,
				"description": "A bright piano-led bolt. 42–84 magic damage."},
			{"id": "flame", "name": "Flame Sonata", "cost": 8, "target": "enemy", "power": 45,
				"description": "65–130 damage. Burn for 6–18 HP over 2 enemy turns."},
			{"id": "heal", "name": "Mending Chord", "cost": 7, "target": "ally", "power": 35,
				"description": "Restore 35–80 HP to a living ally. Choose a target."},
		]
	result.append({"id": "guard", "name": "Guard / Recover", "cost": 0, "target": "self", "power": 0,
		"description": "Halve the next hit and recover 4 MP. No performance needed."})
	result.append({"id": "tonic", "name": "Field Tonic", "cost": 0, "target": "ally", "power": 65,
		"description": "Restore 65 HP, or revive a fallen ally with 55 HP. Two per battle."})
	return result

func can_use(actor: int, action: Dictionary) -> bool:
	return outcome.is_empty() and turn_cursor == actor and party[actor].hp > 0 and party[actor].mp >= action.cost and (action.id != "tonic" or tonics > 0)

func intent() -> Dictionary:
	if round_number % 3 == 0:
		return {"name": "Dissonant Wave", "target": -1, "description": "A wave will strike both allies."}
	var target := 0 if round_number % 2 == 1 else 1
	if party[target].hp <= 0:
		target = 1 - target
	return {"name": "Heavy Cleave", "target": target, "description": "A heavy strike aimed at " + str(party[target].name) + "."}

func apply_player(actor: int, action: Dictionary, target: int, accuracy: float) -> Dictionary:
	if not can_use(actor, action):
		return {}
	if action.target == "ally" and (target < 0 or target >= party.size() or (action.id == "heal" and party[target].hp <= 0)):
		return {}
	var a := clampf(accuracy, 0.0, 1.0)
	party[actor].mp -= int(action.cost)
	var event := {"id": action.id, "actor": actor, "target": target, "accuracy": a, "amount": 0, "hits": []}
	match action.id:
		"guard":
			party[actor].guard = true
			party[actor].mp = mini(party[actor].max_mp, party[actor].mp + 4)
			last_event = str(party[actor].name) + " braces and recovers 4 MP."
		"tonic", "heal":
			var amount: int = 65 if action.id == "tonic" else roundi(35 + 45 * a)
			if action.id == "tonic":
				tonics -= 1
				if party[target].hp == 0:
					amount = 55
			var before: int = party[target].hp
			party[target].hp = mini(party[target].max_hp, party[target].hp + amount)
			event.amount = party[target].hp - before
			last_event = "%s restores %d HP to %s." % [party[actor].name, event.amount, party[target].name]
		"shield":
			event.amount = roundi(14 + 20 * a)
			for hero in party:
				if hero.hp > 0:
					hero.shield = maxi(hero.shield, event.amount)
			last_event = "Iron Chorus grants each living ally a %d HP shield." % event.amount
		_:
			var stat: int = party[actor].attack if actor == 0 else party[actor].magic
			var defense: int = enemy.defense if actor == 0 else enemy.resist
			event.amount = roundi(maxi(1, action.power + stat - defense) * (1.0 + a) * (1.0 + float(enemy.exposed)))
			enemy.hp = maxi(0, enemy.hp - event.amount)
			if action.id == "rend":
				enemy.exposed = 0.10 + 0.15 * a
				enemy.exposed_turns = 2
			if action.id == "flame":
				enemy.burn = roundi(6 + 12 * a)
				enemy.burn_turns = 2
			last_event = "%s deals %d damage — %d%% resonance." % [action.name, event.amount, roundi(a * 100)]
	_check_outcome()
	return event

func apply_enemy() -> Dictionary:
	if turn_cursor != 2 or not outcome.is_empty():
		return {}
	var event := {"id": "enemy", "hits": [], "burn": 0, "name": ""}
	if enemy.burn_turns > 0:
		event.burn = enemy.burn
		enemy.hp = maxi(0, enemy.hp - enemy.burn)
		enemy.burn_turns -= 1
		_check_outcome()
		if not outcome.is_empty():
			last_event = "The Warden falls to the lingering flame."
			return event
	var next: Dictionary = intent()
	event.name = next.name
	for target in range(2):
		if party[target].hp <= 0 or (next.target != -1 and next.target != target):
			continue
		var hero: Dictionary = party[target]
		var damage: int = maxi(1, (34 if next.target == -1 else enemy.attack) - hero.defense)
		if hero.guard:
			damage = ceili(damage * 0.5)
			hero.guard = false
		var absorbed: int = mini(hero.shield, damage)
		hero.shield -= absorbed
		damage -= absorbed
		hero.hp = maxi(0, hero.hp - damage)
		event.hits.append({"target": target, "amount": damage, "absorbed": absorbed})
	if enemy.exposed_turns > 0:
		enemy.exposed_turns -= 1
		if enemy.exposed_turns == 0:
			enemy.exposed = 0.0
	last_event = str(next.name) + " crashes through the clearing."
	_check_outcome()
	return event

func advance_turn() -> void:
	_check_outcome()
	if not outcome.is_empty():
		return
	for step in range(3):
		turn_cursor = (turn_cursor + 1) % 3
		if turn_cursor == 0:
			round_number += 1
		if turn_cursor == 2 or party[turn_cursor].hp > 0:
			if turn_cursor < 2:
				party[turn_cursor].mp = mini(party[turn_cursor].max_mp, party[turn_cursor].mp + 2)
			return

func _check_outcome() -> void:
	if enemy.hp <= 0:
		outcome = "victory"
	elif party[0].hp <= 0 and party[1].hp <= 0:
		outcome = "defeat"
