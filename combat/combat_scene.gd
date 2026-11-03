extends Control
const Shell = preload("res://global/game_shell.gd")
@onready var shell: Shell = get_node("/root/GameShell")

const Rules = preload("res://combat/battle_state.gd")
const Actor = preload("res://combat/battle_actor.gd")
const Stage = preload("res://combat/battle_stage.gd")
const BattleRhythm = preload("res://combat/combat_rhythm.gd")
const GOLD := Color("eaca8a")
const WHITE := Color("eef0e9")
const MUTED := Color("a5b4bd")
const TEAL := Color("83d4c4")
const BLUE := Color("9fb9ef")
const EFFECTS := {
	"strike": ["res://assets/effects/Impacts/symmetrical_impact_004/symmetrical_impact_004_small_yellow/spritesheet.png", 48, 8],
	"fire": ["res://assets/effects/Fire/fire_looping_004B/fire_looping_004B_small_orange/spritesheet.png", 64, 0],
	"magic": ["res://assets/effects/Magic Bursts/round_sparkle_burst_001/round_sparkle_burst_001_small_blue/spritesheet.png", 32, 14],
	"shield": ["res://assets/effects/Fantasy Spells/spell_defense_up_001/spell_defense_up_001_small_blue/spritesheet.png", 64, 18],
	"heal": ["res://assets/effects/Fantasy Spells/status_sparkling_001/status_sparkling_001_small_yellow/spritesheet.png", 32, 0],
}

var battle = Rules.new()
var phase := "select"
var generation := 0
var stage: Node2D
var heroes: Array[Node2D] = []
var foe: Node2D
var rhythm: Control
var font: Font
var buttons: Array[Button] = []
var selected_action: Dictionary = {}
var selected_target := -1
var description := "Choose an action. Strong timing amplifies damage and support effects."
var banner := "The Warden stirs. Rowan takes the lead."
var popups: Array[Dictionary] = []
var history: Array[String] = []
var resonance: Array[float] = []
var elapsed := 0.0
var enemy_hp := 650.0
var hero_hp := [180.0, 124.0]
var bgm: AudioStreamPlayer
var impact: AudioStreamPlayer
var live_tweens: Array[Tween] = []
var save_checkpoint: Dictionary = {}
var returning_to_world := false

func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage = Stage.new()
	stage.z_index = -20
	add_child(stage)
	# Back-to-front staging: mage in the distance, enemy midground, warrior near.
	var mage = Actor.new()
	mage.setup("res://assets/characters/mage.png", Vector2(1010, 398), 2.7)
	mage.z_index = 1
	stage.add_child(mage)
	foe = Actor.new()
	foe.setup("res://assets/enemies/Monster_4 SV Battler.png", Vector2(302, 454), 3.6, true)
	foe.z_index = 2
	stage.add_child(foe)
	var warrior = Actor.new()
	warrior.setup("res://assets/characters/warrior.png", Vector2(858, 504), 3.4)
	warrior.z_index = 3
	stage.add_child(warrior)
	heroes = [warrior, mage]
	rhythm = BattleRhythm.new()
	rhythm.position = Vector2(435, 546)
	rhythm.size = Vector2(730, 242)
	add_child(rhythm)
	rhythm.completed.connect(_performance_finished)
	bgm = AudioStreamPlayer.new()
	bgm.stream = load("res://audio/battle_theme.wav")
	bgm.volume_db = -17
	add_child(bgm)
	bgm.finished.connect(func(): bgm.play())
	bgm.play()
	impact = AudioStreamPlayer.new()
	impact.stream = load("res://audio/battle_impact.wav")
	impact.volume_db = -9
	add_child(impact)
	_show_commands()
	shell.register_scene(self)

func _new_button(text: String, bounds: Rect2, callback: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _box(Color("1c2c37"), Color("52615f")))
	button.add_theme_stylebox_override("hover", _box(Color("31434b"), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color("41534e"), GOLD))
	button.add_theme_stylebox_override("disabled", _box(Color("17242d"), Color("303f47")))
	button.pressed.connect(callback)
	add_child(button)
	buttons.append(button)
	return button

func _clear_buttons() -> void:
	for button in buttons:
		button.hide()
		button.queue_free()
	buttons.clear()

func _show_commands() -> void:
	_clear_buttons()
	if not battle.outcome.is_empty():
		_show_outcome()
		return
	phase = "select"
	save_checkpoint = _snapshot()
	var actor: int = battle.turn_cursor
	var actions: Array[Dictionary] = battle.actions(actor)
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var cost := "%d MP" % action.cost if action.cost > 0 else ("x%d" % battle.tonics if action.id == "tonic" else "FREE")
		var button := _new_button("%s   %s     %s" % [shell.key_name("command_%d" % (i + 1)), action.name, cost], Rect2(447 + (i % 2) * 359, 590 + (i / 2) * 51, 345, 43), func(): choose_action(i), battle.can_use(actor, action))
		button.tooltip_text = action.description
		button.mouse_entered.connect(func(): description = action.description)
	description = "Choose an action. Accuracy grants up to 2x damage; support skills scale too."
	_new_button("Rhythm Lab / " + shell.key_name("switch_mode"), Rect2(991, 23, 178, 34), _open_lab)
	_new_button("World map", Rect2(620, 23, 174, 34), _open_map)
	_new_button("Restart encounter", Rect2(806, 23, 174, 34), restart)
	queue_redraw()

func choose_action(index: int) -> void:
	if phase != "select" or index < 0 or index >= 5:
		return
	var action: Dictionary = battle.actions(battle.turn_cursor)[index]
	if not battle.can_use(battle.turn_cursor, action):
		return
	selected_action = action
	selected_target = -1
	if action.target == "ally":
		phase = "target"
		_clear_buttons()
		description = action.description
		for i in range(2):
			var hero: Dictionary = battle.party[i]
			_new_button("%s   %s   %d / %d HP" % [shell.key_name("command_%d" % (i + 1)), hero.name, hero.hp, hero.max_hp], Rect2(447 + i * 359, 617, 345, 55), func(): choose_target(i), action.id == "tonic" or hero.hp > 0)
		_new_button("Back / " + shell.key_name("back"), Rect2(447, 689, 230, 40), _show_commands)
	else:
		_begin_action()

func choose_target(index: int) -> void:
	if phase != "target" or index < 0 or index > 1:
		return
	if selected_action.id == "heal" and battle.party[index].hp <= 0:
		return
	selected_target = index
	_begin_action()

func _begin_action() -> void:
	_clear_buttons()
	var actor: int = battle.turn_cursor
	if selected_action.id in ["guard", "tonic"]:
		phase = "resolve"
		_resolve_player(0.0)
		return
	phase = "rhythm"
	heroes[actor].play(2 if actor == 1 else 3)
	bgm.volume_db = -29
	banner = "%s — %s" % [battle.party[actor].name, selected_action.name]
	var mask := 3 if selected_action.id == "attack" else (6 if selected_action.id == "rend" else 5)
	rhythm.start(battle.party[actor].instrument, selected_action.name, mask)

func _performance_finished(result: Dictionary) -> void:
	if phase != "rhythm":
		return
	phase = "resolve"
	bgm.volume_db = -17
	resonance.append(float(result.accuracy))
	_resolve_player(float(result.accuracy))

func _resolve_player(accuracy: float) -> void:
	var token := generation
	var actor: int = battle.turn_cursor
	var event: Dictionary = battle.apply_player(actor, selected_action, selected_target, accuracy)
	if event.is_empty():
		_show_commands()
		return
	phase = "resolve"
	banner = str(selected_action.name)
	history.append(battle.last_event)
	heroes[actor].play(7 if actor == 0 else 10)
	var enemy_action: bool = selected_action.target == "enemy"
	var origin: Vector2 = heroes[actor].ground
	var tween := create_tween()
	live_tweens.append(tween)
	tween.tween_property(heroes[actor], "position", Vector2(foe.ground.x + 150, foe.ground.y + 20) if actor == 0 and enemy_action else origin + Vector2(-18, -5), 0.18).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	if token != generation:
		return
	if enemy_action:
		_effect("fire" if selected_action.id == "flame" else ("strike" if actor == 0 else "magic"), foe.position + Vector2(0, -95))
		_popup(str(event.amount), foe.position + Vector2(0, -150), GOLD if accuracy >= 0.8 else WHITE)
		foe.flash = 0.22
		foe.play(4)
		impact.play()
		_shake(7 if accuracy >= 0.8 else 3)
		if selected_action.id == "rend":
			_popup("EXPOSED", foe.position + Vector2(0, -205), GOLD)
		if selected_action.id == "flame":
			_popup("BURN", foe.position + Vector2(0, -205), Color("ffa374"))
	elif selected_action.id == "shield":
		for i in range(2):
			if battle.party[i].hp > 0:
				_effect("shield", heroes[i].position + Vector2(0, -65))
				_popup("SHIELD +%d" % event.amount, heroes[i].position + Vector2(0, -140), BLUE)
	elif selected_action.id in ["heal", "tonic"]:
		_effect("heal", heroes[selected_target].position + Vector2(0, -65))
		_popup("+%d HP" % event.amount, heroes[selected_target].position + Vector2(0, -145), TEAL)
	else:
		_popup("GUARD / +4 MP", origin + Vector2(0, -155), BLUE)
	var back := create_tween()
	live_tweens.append(back)
	back.tween_property(heroes[actor], "position", origin, 0.22)
	await back.finished
	if token != generation:
		return
	await get_tree().create_timer(0.36, false).timeout
	if token != generation:
		return
	_update_poses()
	_next_turn()

func _next_turn() -> void:
	if not battle.outcome.is_empty():
		_show_outcome()
		return
	battle.advance_turn()
	if battle.turn_cursor == 2:
		_enemy_turn()
	else:
		banner = "%s's turn" % battle.party[battle.turn_cursor].name
		_show_commands()

func _enemy_turn() -> void:
	phase = "enemy"
	_clear_buttons()
	var token := generation
	var announced: Dictionary = battle.intent()
	banner = str(announced.name)
	await get_tree().create_timer(0.4, false).timeout
	if token != generation:
		return
	var event: Dictionary = battle.apply_enemy()
	history.append(battle.last_event)
	if event.burn > 0:
		_popup("BURN %d" % event.burn, foe.position + Vector2(0, -160), Color("ffa374"))
		_effect("fire", foe.position + Vector2(0, -90))
	if battle.outcome == "victory":
		await get_tree().create_timer(0.5, false).timeout
		if token == generation:
			_show_outcome()
		return
	foe.play(7)
	var tween := create_tween()
	live_tweens.append(tween)
	tween.tween_property(foe, "position", foe.ground + Vector2(75, 0), 0.2)
	await tween.finished
	if token != generation:
		return
	impact.play()
	_shake(5)
	for hit in event.hits:
		var hero: Node2D = heroes[hit.target]
		hero.flash = 0.23
		hero.play(4)
		_effect("magic" if announced.target == -1 else "strike", hero.position + Vector2(0, -80))
		_popup(str(hit.amount) if hit.amount > 0 else "BLOCK", hero.position + Vector2(0, -155), Color("ffc2ac"))
		if hit.absorbed > 0:
			_popup("SHIELD -%d" % hit.absorbed, hero.position + Vector2(0, -195), BLUE)
	var back := create_tween()
	live_tweens.append(back)
	back.tween_property(foe, "position", foe.ground, 0.25)
	await back.finished
	if token != generation:
		return
	await get_tree().create_timer(0.4, false).timeout
	if token != generation:
		return
	_update_poses()
	_next_turn()

func _update_poses() -> void:
	for i in range(2):
		heroes[i].dead = battle.party[i].hp <= 0
		heroes[i].play(17 if heroes[i].dead else (3 if battle.party[i].guard else 1))
	foe.dead = battle.enemy.hp <= 0
	foe.play(17 if foe.dead else 1)

func _show_outcome() -> void:
	if shell.world_encounter_active and not returning_to_world:
		if battle.outcome == "victory":
			shell.world_enemy_defeated = true
		returning_to_world = true
		call_deferred("_return_to_world")
		return
	phase = battle.outcome
	save_checkpoint = _snapshot()
	rhythm.cancel()
	_clear_buttons()
	_update_poses()
	if phase == "victory":
		for i in range(2):
			if battle.party[i].hp > 0:
				heroes[i].play(13)
	banner = "The path is clear." if phase == "victory" else "The melody fades. Try a different arrangement."
	_new_button("Play again / " + shell.key_name("replay"), Rect2(389, 420, 210, 45), restart)
	_new_button("Rhythm Lab / " + shell.key_name("switch_mode"), Rect2(613, 420, 210, 45), _open_lab)

func _return_to_world() -> void:
	await get_tree().create_timer(1.0, false).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func restart() -> void:
	generation += 1
	for tween in live_tweens:
		if tween and tween.is_valid():
			tween.kill()
	live_tweens.clear()
	rhythm.cancel()
	for node in stage.get_children():
		if node != foe and node not in heroes:
			node.queue_free()
	battle.reset()
	selected_action.clear()
	selected_target = -1
	popups.clear()
	history.clear()
	resonance.clear()
	stage.position = Vector2.ZERO
	foe.position = foe.ground
	for hero in heroes:
		hero.position = hero.ground
	bgm.volume_db = -17
	banner = "The Warden stirs. Rowan takes the lead."
	_update_poses()
	_show_commands()

func _open_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/rhythm_lab.tscn")

func _open_map() -> void:
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func _effect(key: String, point: Vector2) -> void:
	var spec: Array = EFFECTS[key]
	var texture: Texture2D = load(spec[0])
	var effect := Sprite2D.new()
	effect.texture = texture
	# The supplied effects are packed atlases, not uniform horizontal strips.
	var frames: Array[Rect2] = []
	var metadata := FileAccess.get_file_as_string(str(spec[0]).replace(".png", ".txt"))
	for line in metadata.split("\n", false):
		var parts := line.strip_edges().split(" = ")
		if parts.size() != 2:
			continue
		var values := parts[1].split(" ", false)
		if values.size() == 4:
			frames.append(Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])))
	if frames.is_empty():
		effect.free()
		return
	effect.region_enabled = true
	effect.region_rect = frames[0]
	effect.position = point
	effect.scale = Vector2.ONE * (3.5 if key in ["fire", "magic"] else 2.6)
	effect.z_index = 6
	stage.add_child(effect)
	var tween := create_tween()
	live_tweens.append(tween)
	tween.tween_method(func(frame: float): effect.region_rect = frames[mini(frames.size() - 1, int(frame))], 0.0, float(frames.size() - 1), 0.65)
	tween.tween_callback(effect.queue_free)

func _shake(strength: float) -> void:
	var tween := create_tween()
	live_tweens.append(tween)
	for i in range(4):
		tween.tween_property(stage, "position", Vector2(strength * (-1 if i % 2 else 1), -strength * 0.4), 0.035)
	tween.tween_property(stage, "position", Vector2.ZERO, 0.08)

func _popup(text: String, point: Vector2, color: Color) -> void:
	popups.append({"text": text, "position": point, "life": 1.3, "color": color})

func _process(delta: float) -> void:
	elapsed += delta
	enemy_hp = lerpf(enemy_hp, float(battle.enemy.hp), minf(1, delta * 10))
	for i in range(2):
		hero_hp[i] = lerpf(hero_hp[i], float(battle.party[i].hp), minf(1, delta * 12))
	for i in range(popups.size() - 1, -1, -1):
		popups[i].life -= delta
		popups[i].position.y -= delta * 25
		if popups[i].life <= 0:
			popups.remove_at(i)
	live_tweens = live_tweens.filter(func(tween: Tween): return tween and tween.is_valid())
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or shell.is_pause_event(event):
		return
	if shell.matches(event, "switch_mode") and phase != "rhythm":
		_open_lab()
	elif phase in ["select", "target"]:
		if phase == "target" and shell.matches(event, "back"):
			_show_commands()
		else:
			for index in range(5 if phase == "select" else 2):
				if shell.matches(event, "command_%d" % (index + 1)):
					if phase == "select":
						choose_action(index)
					else:
						choose_target(index)
					break
	elif phase in ["victory", "defeat"] and shell.matches(event, "replay"):
		restart()

func refresh_bindings() -> void:
	if phase == "select":
		_show_commands()
	elif phase in ["victory", "defeat"]:
		_show_outcome()
	elif phase == "target":
		# Recreate target prompts without changing the selected skill.
		var index: int = 4 if selected_action.id == "tonic" else 2
		phase = "select"
		choose_action(index)
	rhythm.queue_redraw()
	queue_redraw()

func sync_after_pause(_duration_usec: int) -> void:
	rhythm.held = shell.held_mask(rhythm.instrument)

func _snapshot() -> Dictionary:
	return {"party": battle.party.duplicate(true), "enemy": battle.enemy.duplicate(true),
		"round": battle.round_number, "turn": battle.turn_cursor, "tonics": battle.tonics,
		"outcome": battle.outcome, "history": history.duplicate(), "resonance": resonance.duplicate(),
		"summary": "Round %d · %s" % [battle.round_number, "Command" if battle.outcome.is_empty() else str(battle.outcome).capitalize()]}

func make_save() -> Dictionary:
	return save_checkpoint.duplicate(true)

static func valid_save(data: Dictionary) -> bool:
	if not data.get("party") is Array or data.party.size() != 2 or not data.get("enemy") is Dictionary:
		return false
	var template = Rules.new()
	for i in range(2):
		if not data.party[i] is Dictionary:
			return false
		var hero: Dictionary = data.party[i]
		for key in template.party[i]:
			if not hero.has(key):
				return false
			if key not in ["hp", "mp", "shield", "guard"] and hero[key] != template.party[i][key]:
				return false
		if not _in_range(hero.hp, 0, hero.max_hp) or not _in_range(hero.mp, 0, hero.max_mp) or not _in_range(hero.shield, 0, 1000) or not hero.guard is bool:
			return false
	for key in template.enemy:
		if not data.enemy.has(key):
			return false
		if key not in ["hp", "burn", "burn_turns", "exposed", "exposed_turns"] and data.enemy[key] != template.enemy[key]:
			return false
	if not _in_range(data.enemy.hp, 0, 650) or not _in_range(data.enemy.burn, 0, 100) or not _in_range(data.enemy.burn_turns, 0, 2) or not _in_range(data.enemy.exposed, 0, 1, false) or not _in_range(data.enemy.exposed_turns, 0, 2):
		return false
	if not _in_range(data.get("round"), 1, 100000) or not _in_range(data.get("turn"), 0, 2) or not _in_range(data.get("tonics"), 0, 2) or data.get("outcome") not in ["", "victory", "defeat"]:
		return false
	if data.outcome.is_empty() and (data.turn == 2 or data.party[int(data.turn)].hp <= 0 or data.enemy.hp <= 0):
		return false
	if data.outcome == "victory" and data.enemy.hp != 0:
		return false
	if data.outcome == "defeat" and (data.party[0].hp > 0 or data.party[1].hp > 0):
		return false
	if not data.get("history") is Array or not data.get("resonance") is Array:
		return false
	for entry in data.history:
		if not entry is String:
			return false
	for value in data.resonance:
		if not _in_range(value, 0, 1, false):
			return false
	return true

static func _in_range(value: Variant, low: float, high: float, integer: bool = true) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and (not integer or value == floor(value))

func restore_save(data: Dictionary) -> void:
	if not valid_save(data):
		return
	restart()
	for i in range(2):
		for key in battle.party[i]:
			battle.party[i][key] = int(data.party[i][key]) if battle.party[i][key] is int else data.party[i][key]
	for key in battle.enemy:
		battle.enemy[key] = int(data.enemy[key]) if battle.enemy[key] is int else data.enemy[key]
	battle.round_number = int(data.round)
	battle.turn_cursor = int(data.turn)
	battle.tonics = int(data.tonics)
	battle.outcome = data.outcome
	history.assign(data.history)
	resonance.assign(data.resonance)
	enemy_hp = battle.enemy.hp
	hero_hp = [float(battle.party[0].hp), float(battle.party[1].hp)]
	battle.last_event = "Save loaded. Choose your next action."
	_update_poses()
	_show_commands()

func _box(fill: Color, border: Color = Color("57605c")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _text(text: String, point: Vector2, px: int = 18, color: Color = WHITE) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _bar(bounds: Rect2, ratio: float, color: Color) -> void:
	draw_rect(bounds, Color("253440"))
	draw_rect(Rect2(bounds.position, Vector2(bounds.size.x * clampf(ratio, 0, 1), bounds.size.y)), color)

func _draw() -> void:
	if not font:
		return
	# Foreground silhouettes frame the near plane without hiding combatants.
	for side in [0, 1]:
		for leaf in range(7):
			var x: float = side * 1200
			var direction := 1 if side == 0 else -1
			var y := 460.0 + leaf * 14
			draw_colored_polygon(PackedVector2Array([Vector2(x, y + 30), Vector2(x + direction * (70 + leaf * 11), y - 24), Vector2(x + direction * 30, y + 47)]), Color(0.035, 0.10, 0.09, 0.83))
	draw_rect(Rect2(0, 0, 1200, 82), Color(0.025, 0.045, 0.06, 0.88))
	draw_line(Vector2(32, 81), Vector2(1168, 81), Color("7c8268"), 1)
	_text("T H E   H O L L O W   P A S S A G E", Vector2(33, 35), 19, GOLD)
	_text("WOODLAND SENTINEL  /  RHYTHMPG  /  ESC PAUSE", Vector2(33, 62), 12, MUTED)
	_text("ROUND %02d" % battle.round_number, Vector2(623, 47), 21)
	# Enemy identity, HP, statuses, and telegraphed intent stay visible.
	draw_style_box(_box(Color(0.045, 0.07, 0.09, 0.91)), Rect2(35, 109, 355, 131))
	_text("THE HOLLOW WARDEN", Vector2(53, 138), 21, GOLD)
	_text("Sentinel  /  Lv. 4", Vector2(53, 159), 13, MUTED)
	_bar(Rect2(53, 173, 317, 7), enemy_hp / battle.enemy.max_hp, Color("c28e74"))
	_text("%d / %d HP" % [battle.enemy.hp, battle.enemy.max_hp], Vector2(53, 204), 15)
	var statuses := ""
	if battle.enemy.exposed_turns > 0:
		statuses += "EXPOSED +%d%%  " % roundi(battle.enemy.exposed * 100)
	if battle.enemy.burn_turns > 0:
		statuses += "BURN %d x%d" % [battle.enemy.burn, battle.enemy.burn_turns]
	_text(statuses if not statuses.is_empty() else "ATK 39   DEF 12   RES 10", Vector2(53, 226), 13, MUTED)
	var intent: Dictionary = battle.intent()
	_text("NEXT: " + str(intent.name).to_upper(), Vector2(38, 269), 14, GOLD)
	_text(intent.description, Vector2(38, 290), 14, WHITE)
	var turn_names := ["ROWAN", "LYRA", "WARDEN"]
	_text("TURN ORDER", Vector2(727, 111), 11, Color("edf1de"))
	for i in range(3):
		var x := 727 + i * 146
		var active: bool = battle.turn_cursor == i and battle.outcome.is_empty()
		draw_style_box(_box(Color(0.055, 0.085, 0.10, 0.9), GOLD if active else Color("5b6b63")), Rect2(x, 122, 134, 34))
		_text(turn_names[i], Vector2(x + 13, 144), 15, GOLD if active else MUTED)
	# Subtle active-character ring establishes foot placement on the ground.
	if battle.turn_cursor < 2 and battle.outcome.is_empty():
		var ground: Vector2 = heroes[battle.turn_cursor].ground
		draw_set_transform(ground, 0, Vector2(1, 0.27))
		draw_arc(Vector2.ZERO, 53, 0, TAU, 64, Color(0.92, 0.82, 0.53, 0.8), 3)
		draw_set_transform(Vector2.ZERO)
	# Persistent lower HUD; the performance replaces commands in the same space.
	draw_rect(Rect2(0, 532, 1200, 268), Color("101d28"))
	draw_line(Vector2(32, 533), Vector2(1168, 533), GOLD, 1)
	for i in range(2):
		_draw_hero_card(i)
	draw_style_box(_box(Color("152530")), Rect2(430, 545, 738, 243))
	if phase != "rhythm":
		var actor_name: String = battle.party[mini(battle.turn_cursor, 1)].name
		var heading := "CHOOSE AN ALLY" if phase == "target" else (actor_name.to_upper() + "  /  COMMAND" if phase == "select" else banner.to_upper())
		_text(heading, Vector2(447, 574), 18, GOLD)
		if phase in ["select", "target"]:
			draw_multiline_string(font, Vector2(447, 755), description, HORIZONTAL_ALIGNMENT_LEFT, 697, 14, 2, MUTED)
		else:
			_text(battle.last_event, Vector2(447, 621), 16)
			_text("The next phrase is gathering...", Vector2(447, 652), 14, MUTED)
	# Battlefield action caption and damage numbers are separate from the HUD.
	if phase in ["rhythm", "resolve", "enemy"]:
		draw_style_box(_box(Color(0.04, 0.07, 0.1, 0.9)), Rect2(419, 472, 374, 42))
		_text(banner, Vector2(438, 499), 18, GOLD)
	for popup in popups:
		var pos: Vector2 = popup.position
		var color: Color = popup.color
		color.a = minf(1, popup.life * 2)
		var px := 31 if str(popup.text).is_valid_int() else 17
		var width := font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string_outline(font, pos - Vector2(width / 2, 0), popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 5, Color("101c27"))
		_text(popup.text, pos - Vector2(width / 2, 0), px, color)
	if phase in ["victory", "defeat"]:
		_draw_outcome()

func _draw_hero_card(index: int) -> void:
	var hero: Dictionary = battle.party[index]
	var y := 547 + index * 122
	var active: bool = battle.turn_cursor == index and battle.outcome.is_empty()
	draw_style_box(_box(Color("1b2b35"), GOLD if active else Color("49585b")), Rect2(32, y, 379, 111))
	_text(str(hero.name).to_upper(), Vector2(49, y + 28), 22, GOLD if active else WHITE)
	_text("%s / %s" % [hero.job, hero.instrument.capitalize()], Vector2(176, y + 26), 13, MUTED)
	_bar(Rect2(49, y + 45, 223, 7), hero_hp[index] / hero.max_hp, TEAL if hero.hp > 0 else Color("a26464"))
	_text("%d / %d HP" % [hero.hp, hero.max_hp], Vector2(283, y + 54), 14)
	_bar(Rect2(49, y + 66, 223, 4), float(hero.mp) / hero.max_mp, BLUE)
	_text("%d / %d MP" % [hero.mp, hero.max_mp], Vector2(283, y + 76), 14, BLUE)
	var status := "FALLEN — tonic to revive" if hero.hp <= 0 else "ATK %d  MAG %d  DEF %d  SPD %d" % [hero.attack, hero.magic, hero.defense, hero.speed]
	if hero.shield > 0:
		status = "SHIELD %d  /  " % hero.shield + status
	if hero.guard:
		status = "GUARDING  /  SHIELD %d" % hero.shield
	_text(status, Vector2(49, y + 97), 12, MUTED)

func _draw_outcome() -> void:
	draw_rect(Rect2(0, 83, 1200, 449), Color(0.02, 0.04, 0.06, 0.65))
	draw_style_box(_box(Color("172a32"), GOLD), Rect2(340, 175, 530, 310))
	_text("P A S S A G E   O P E N" if phase == "victory" else "T H E   M E L O D Y   F A D E S", Vector2(379, 223), 17, GOLD)
	_text("VICTORY" if phase == "victory" else "DEFEAT", Vector2(378, 283), 45)
	var average := 0.0
	for value in resonance:
		average += value
	average /= maxf(1, resonance.size())
	_text("%d rounds   /   %d%% average accuracy" % [battle.round_number, roundi(average * 100)], Vector2(380, 324), 20, TEAL)
	draw_multiline_string(font, Vector2(380, 361), "The forest falls quiet. Your duet carries onward." if phase == "victory" else "Guard the telegraphed attacks. Use tonics to revive, and protect Lyra with Iron Chorus.", HORIZONTAL_ALIGNMENT_LEFT, 450, 16, 2, MUTED)
