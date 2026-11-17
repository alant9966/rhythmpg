extends Control
const Shell = preload("res://global/game_shell.gd")
@onready var shell: Shell = get_node("/root/GameShell")

const HUDView = preload("res://combat/battle_hud_view.gd")
const CommandButton = preload("res://combat/command_button.gd")
const Rules = preload("res://combat/battle_state.gd")
const GOLD := Color("c5ae7b")
const WHITE := Color("eee7d7")
const MUTED := Color("ada99e")
const TEAL := Color("9ca984")
const BLUE := Color("98a6b8")
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
@onready var screen_backdrop: TextureRect = $ScreenBackdrop
@onready var stage: Node2D = $Battlefield
@onready var effects: Node2D = $Battlefield/Effects
@onready var hud: Control = $HUD
var heroes: Array[Node2D] = []
@onready var foe: Node2D = $Battlefield/Actors/Warden
@onready var rhythm: Control = $RhythmOverlay
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
var hero_hp := [180.0, 124.0, 148.0]
@onready var bgm: AudioStreamPlayer = $Audio/BattleMusic
@onready var impact: AudioStreamPlayer = $Audio/ImpactSound
var live_tweens: Array[Tween] = []
var save_checkpoint: Dictionary = {}
@export_category("Rhythm Focus")
@export_range(1.0, 1.4, 0.01) var rhythm_camera_zoom := 1.05
@export_range(1.0, 1.4, 0.01) var rhythm_actor_zoom := 1.04
@export var rhythm_actor_feet := Vector2(965, 535)
@export_range(0.2, 2.0, 0.05) var rhythm_focus_in_seconds := 1.1
@export_range(0.2, 2.0, 0.05) var rhythm_focus_out_seconds := 1.0
@export_range(0.1, 0.5, 0.05) var rhythm_hud_fade_seconds := 0.25
var focused_actor: Node2D
var focus_tween: Tween
var focus_restore: Dictionary = {}

func _begin_rhythm_focus(actor: Node2D) -> void:
	_end_rhythm_focus()
	focused_actor = actor
	focus_restore = {"stage_position": stage.position, "stage_scale": stage.scale,
		"actor_scale": actor.scale, "z_index": actor.z_index, "z_relative": actor.z_as_relative,
		"background_scale": $Battlefield/Background.scale, "background_position": $Battlefield/Background.position}
	# Lift the real actor, including its props, above the full-scene dimmer.
	actor.z_as_relative = false
	actor.z_index = 40
	focus_tween = create_tween().set_parallel(true)
	focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rhythm.gameplay_revealed = false
	rhythm.presentation_weight = 0.0
	focus_tween.tween_property(rhythm, "presentation_weight", 1.0, rhythm_focus_in_seconds)
	focus_tween.tween_property(stage, "scale", Vector2.ONE * rhythm_camera_zoom, rhythm_focus_in_seconds)
	focus_tween.tween_property(stage, "position", rhythm_actor_feet - actor.ground * rhythm_camera_zoom, rhythm_focus_in_seconds)
	focus_tween.tween_property(actor, "scale", actor.scale * rhythm_actor_zoom, rhythm_focus_in_seconds)
	# Overscan the painted backdrop so the camera pan never reveals empty edges.
	var backdrop: Sprite2D = $Battlefield/Background
	var center := backdrop.position + backdrop.texture.get_size() * backdrop.scale * 0.5
	var enlarged := backdrop.scale * 1.35
	focus_tween.tween_property(backdrop, "scale", enlarged, rhythm_focus_in_seconds)
	focus_tween.tween_property(backdrop, "position", center - backdrop.texture.get_size() * enlarged * 0.5, rhythm_focus_in_seconds)
	# The HUD covers the unpainted lower stage until the backdrop has expanded.
	focus_tween.chain().tween_property(hud, "modulate:a", 0.0, rhythm_hud_fade_seconds)
	focus_tween.chain().tween_callback(rhythm.reveal_gameplay)

func _return_rhythm_focus() -> void:
	if focus_tween and focus_tween.is_valid():
		focus_tween.kill()
	rhythm.begin_outro()
	focus_tween = create_tween().set_parallel(true)
	focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Fully restore the lower HUD before shrinking the painted backdrop.
	focus_tween.tween_property(hud, "modulate:a", 1.0, rhythm_hud_fade_seconds)
	focus_tween.chain().tween_property(stage, "scale", focus_restore.stage_scale, rhythm_focus_out_seconds)
	focus_tween.tween_property(stage, "position", focus_restore.stage_position, rhythm_focus_out_seconds)
	focus_tween.tween_property(focused_actor, "scale", focus_restore.actor_scale, rhythm_focus_out_seconds)
	focus_tween.tween_property($Battlefield/Background, "scale", focus_restore.background_scale, rhythm_focus_out_seconds)
	focus_tween.tween_property($Battlefield/Background, "position", focus_restore.background_position, rhythm_focus_out_seconds)
	focus_tween.tween_property(rhythm, "presentation_weight", 0.0, rhythm_focus_out_seconds)
	# This timer pauses with gameplay and still completes safely if restart kills the tween.
	await get_tree().create_timer(rhythm_hud_fade_seconds + rhythm_focus_out_seconds, false).timeout

func _end_rhythm_focus() -> void:
	if focus_tween and focus_tween.is_valid():
		focus_tween.kill()
	if is_instance_valid(focused_actor) and not focus_restore.is_empty():
		focused_actor.scale = focus_restore.actor_scale
		focused_actor.z_index = focus_restore.z_index
		focused_actor.z_as_relative = focus_restore.z_relative
		stage.position = focus_restore.stage_position
		stage.scale = focus_restore.stage_scale
		$Battlefield/Background.scale = focus_restore.background_scale
		$Battlefield/Background.position = focus_restore.background_position
	focused_actor = null
	focus_restore.clear()
	hud.modulate.a = 1.0
	rhythm.end_outro()


func _ready() -> void:
	_fit_canvas()
	get_viewport().size_changed.connect(_fit_canvas)
	font = preload("res://ui/clear_font.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	heroes = [$Battlefield/Actors/Rowan, $Battlefield/Actors/Lyra, $Battlefield/Actors/Maro]
	rhythm.completed.connect(_performance_finished)
	bgm.finished.connect(func(): bgm.play())
	bgm.play()
	_show_commands()
	shell.register_scene(self)

func _fit_canvas() -> void:
	# Preserve editor coordinates while fitting the project's current viewport.
	var available := get_viewport_rect().size
	var zoom := minf(available.x / size.x, available.y / size.y)
	scale = Vector2.ONE * zoom
	position = (available - size * zoom) * 0.5
	# Forest artwork also fills any margins outside the fitted combat canvas.
	var backdrop_bounds := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	screen_backdrop.position = backdrop_bounds.position
	screen_backdrop.size = backdrop_bounds.size

func _new_button(text: String, bounds: Rect2, callback: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _menu_style(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _menu_style(Color(0.9, 0.86, 0.76, 0.1)))
	button.add_theme_stylebox_override("pressed", _menu_style(Color(0.9, 0.86, 0.76, 0.18)))
	button.add_theme_stylebox_override("disabled", _menu_style(Color(0, 0, 0, 0)))
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
	var planner: int = battle.next_planner()
	if planner >= 0:
		battle.turn_cursor = planner
	save_checkpoint = _snapshot()
	var actor: int = battle.turn_cursor
	var actions: Array[Dictionary] = battle.actions(actor)
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var cost := "%d MP" % action.cost if action.cost > 0 else ("x%d" % battle.available_tonics() if action.id == "tonic" else "")
		var button := CommandButton.new()
		button.position = Vector2(36, 590 + i * 33)
		button.size = Vector2(286, 31)
		button.configure(shell.key_name("command_%d" % (i + 1)), str(action.name), cost)
		button.disabled = not battle.can_plan(actor, action)
		button.pressed.connect(func(): choose_action(i))
		button.mouse_entered.connect(func(): description = action.description)
		button.focus_entered.connect(func(): description = action.description)
		add_child(button)
		buttons.append(button)
	description = "Choose %s’s action." % battle.party[actor].name
	_new_button("Practice  " + shell.key_name("switch_mode"), Rect2(953, 18, 114, 31), _open_lab)
	_new_button("Restart", Rect2(867, 18, 78, 31), restart)
	_new_button("Menu  Esc", Rect2(1075, 18, 92, 31), shell.open_menu)
	hud.queue_redraw()

func choose_action(index: int) -> void:
	if phase != "select" or index < 0 or index >= 5:
		return
	var action: Dictionary = battle.actions(battle.turn_cursor)[index]
	if not battle.can_plan(battle.turn_cursor, action):
		return
	selected_action = action
	selected_target = -1
	if action.target == "ally":
		phase = "target"
		_clear_buttons()
		description = action.description
		for i in range(battle.party.size()):
			var hero: Dictionary = battle.party[i]
			var target_button := _new_button("%s  %s  %d/%d HP" % [shell.key_name("command_%d" % (i + 1)), hero.name, hero.hp, hero.max_hp], Rect2(382 + i * 258, 709, 238, 36), func(): choose_target(i), action.id == "tonic" or hero.hp > 0)
			target_button.add_theme_font_size_override("font_size", 14)
		_new_button("Back / " + shell.key_name("back"), Rect2(42, 710, 278, 35), _show_commands)
	else:
		_begin_action()

func choose_target(index: int) -> void:
	if phase != "target" or index < 0 or index >= battle.party.size():
		return
	if selected_action.id == "heal" and battle.party[index].hp <= 0:
		return
	selected_target = index
	_begin_action()

func _begin_action() -> void:
	_clear_buttons()
	_queue_selection()

func _start_performance() -> void:
	var actor: int = battle.turn_cursor
	phase = "rhythm"
	_begin_rhythm_focus(heroes[actor])
	heroes[actor].play(2 if actor == 1 else 3)
	bgm.volume_db = -29
	banner = "%s — %s" % [battle.party[actor].name, selected_action.name]
	var mask := 3 if selected_action.id == "attack" else (6 if selected_action.id == "rend" else 5)
	rhythm.start(battle.party[actor].instrument, selected_action.name, mask, selected_action.get("perfect", ""))

func _performance_finished(result: Dictionary) -> void:
	if phase != "rhythm":
		return
	var token := generation
	var accuracy := float(result.accuracy)
	resonance.append(accuracy)
	phase = "focus_return"
	await _return_rhythm_focus()
	if token != generation or phase != "focus_return":
		return
	_end_rhythm_focus()
	bgm.volume_db = -17
	_resolve_player(accuracy)

func _queue_selection() -> void:
	var actor: int = battle.turn_cursor
	if not battle.queue_action(actor, selected_action, selected_target):
		_show_commands()
		return
	banner = "%s selected %s" % [battle.party[actor].name, selected_action.name]
	_update_poses()
	if battle.next_planner() >= 0:
		_show_commands()
	else:
		_clear_buttons()
		phase = "resolve"
		if battle.begin_resolution():
			_resolve_next_queued_action()

func _resolve_next_queued_action() -> void:
	popups.clear()
	if not battle.outcome.is_empty():
		_show_outcome()
		return
	var entry: Dictionary = battle.take_next_action()
	if not battle.outcome.is_empty():
		_show_outcome()
		return
	if entry.is_empty():
		battle.finish_round()
		banner = "Round %d — plan your party's actions" % battle.round_number
		_show_commands()
		return
	if entry.actor == battle.party.size():
		_enemy_turn()
		return
	selected_action = battle.action_for(int(entry.actor), str(entry.action_id))
	selected_target = int(entry.target)
	# A target may fall, or an actor may lose resources, before its action.
	if not battle.can_use(entry.actor, selected_action) or (selected_action.id == "heal" and battle.party[selected_target].hp <= 0):
		history.append("%s could not use %s." % [battle.party[entry.actor].name, selected_action.name])
		_resolve_next_queued_action()
	elif selected_action.id == "tonic":
		_resolve_player(0.0)
	else:
		_start_performance()

func _resolve_player(accuracy: float) -> void:
	var token := generation
	var actor: int = battle.turn_cursor
	var event: Dictionary = battle.apply_player(actor, selected_action, selected_target, accuracy)
	if event.is_empty():
		_resolve_next_queued_action()
		return
	phase = "resolve"
	banner = str(selected_action.name)
	history.append(battle.last_event)
	heroes[actor].play(3 if selected_action.id == "guard" else (7 if actor == 0 else (10 if actor == 1 else 9)))
	var enemy_action: bool = selected_action.target == "enemy"
	var origin: Vector2 = heroes[actor].ground
	var tween := create_tween()
	live_tweens.append(tween)
	tween.tween_property(heroes[actor], "position", Vector2(foe.ground.x + 150, foe.ground.y + 20) if actor == 0 and enemy_action else origin + Vector2(-18, -5), 0.18).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	if token != generation:
		return
	if event.missed:
		var point: Vector2 = foe.position if enemy_action else (heroes[selected_target].position if selected_target >= 0 else origin)
		_popup("MISS", point + Vector2(0, -150), MUTED)
	elif enemy_action:
		_effect("fire" if selected_action.id == "flame" else ("magic" if actor == 1 else "strike"), foe.position + Vector2(0, -95))
		_popup(str(event.amount), foe.position + Vector2(0, -150), GOLD if accuracy >= 0.8 else WHITE)
		foe.flash = 0.22
		foe.play(4)
		impact.play()
		_shake(7 if accuracy >= 0.8 else 3)
	elif selected_action.id == "shield":
		for i in range(battle.party.size()):
			if battle.party[i].hp > 0:
				_effect("shield", heroes[i].position + Vector2(0, -65))
				_popup("SHIELD +%d" % event.amount, heroes[i].position + Vector2(0, -140), BLUE)
	elif selected_action.id in ["heal", "tonic"]:
		_effect("heal", heroes[selected_target].position + Vector2(0, -65))
		_popup("+%d HP" % event.amount, heroes[selected_target].position + Vector2(0, -145), TEAL)
	elif selected_action.id == "rally":
		for i in range(battle.party.size()):
			if battle.party[i].hp > 0:
				_effect("heal", heroes[i].position + Vector2(0, -65))
				_popup("+%d MP" % event.amount, heroes[i].position + Vector2(0, -145), TEAL)
	else:
		_effect("shield", origin + Vector2(0, -65))
		_popup("GUARD %d%% / +%d MP" % [event.amount, event.mp], origin + Vector2(0, -155), BLUE)
	if event.perfect:
		_popup("PERFECT: " + str(event.bonus), (foe.position if enemy_action else origin) + Vector2(0, -205), GOLD)
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
	_resolve_next_queued_action()

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
	if event.staggered:
		banner = "WARDEN STAGGERED"
		_popup("STAGGERED", foe.position + Vector2(0, -155), GOLD)
		await get_tree().create_timer(0.65, false).timeout
		if token == generation:
			_update_poses()
			_next_turn()
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
	for i in range(battle.party.size()):
		heroes[i].dead = battle.party[i].hp <= 0
		heroes[i].play(17 if heroes[i].dead else (3 if battle.party[i].guard else 1))
	foe.dead = battle.enemy.hp <= 0
	foe.play(17 if foe.dead else 1)

func _show_outcome() -> void:
	_end_rhythm_focus()
	phase = battle.outcome
	save_checkpoint = _snapshot()
	rhythm.cancel()
	_clear_buttons()
	_update_poses()
	if phase == "victory":
		for i in range(battle.party.size()):
			if battle.party[i].hp > 0:
				heroes[i].play(13)
	banner = "The path is clear." if phase == "victory" else "The melody fades. Try a different arrangement."
	_new_button("Play again / " + shell.key_name("replay"), Rect2(389, 420, 210, 45), restart)
	_new_button("Rhythm Lab / " + shell.key_name("switch_mode"), Rect2(613, 420, 210, 45), _open_lab)

func restart() -> void:
	_end_rhythm_focus()
	generation += 1
	for tween in live_tweens:
		if tween and tween.is_valid():
			tween.kill()
	live_tweens.clear()
	rhythm.cancel()
	for node in effects.get_children():
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
	shell.enter_rhythm_lab()

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
	effects.add_child(effect)
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
	for i in range(battle.party.size()):
		hero_hp[i] = lerpf(hero_hp[i], float(battle.party[i].hp), minf(1, delta * 12))
	for i in range(popups.size() - 1, -1, -1):
		popups[i].life -= delta
		popups[i].position.y -= delta * 25
		if popups[i].life <= 0:
			popups.remove_at(i)
	live_tweens = live_tweens.filter(func(tween: Tween): return tween and tween.is_valid())
	hud.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or shell.is_pause_event(event):
		return
	if shell.matches(event, "switch_mode") and phase != "rhythm":
		_open_lab()
	elif phase in ["select", "target"]:
		if phase == "target" and shell.matches(event, "back"):
			_show_commands()
		else:
			for index in range(5 if phase == "select" else battle.party.size()):
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
	hud.queue_redraw()

func sync_after_pause(_duration_usec: int) -> void:
	rhythm.held = shell.held_mask(rhythm.instrument)

func _snapshot() -> Dictionary:
	return {"flow": "execution_rhythm", "party": battle.party.duplicate(true), "enemy": battle.enemy.duplicate(true),
		"round": battle.round_number, "turn": battle.turn_cursor, "tonics": battle.tonics,
		"outcome": battle.outcome, "history": history.duplicate(), "resonance": resonance.duplicate(),
		"queue": battle.queued_actions.duplicate(true) if not battle.resolution_active else [],
		"spent": battle.spent_actors.duplicate(),
		"summary": "Round %d · %s" % [battle.round_number, "Command" if battle.outcome.is_empty() else str(battle.outcome).capitalize()]}

func make_save() -> Dictionary:
	return save_checkpoint.duplicate(true)

static func valid_save(data: Dictionary) -> bool:
	if not data.get("party") is Array or data.party.size() not in [2, 3] or not data.get("enemy") is Dictionary:
		return false
	var template = Rules.new()
	for i in range(data.party.size()):
		if not data.party[i] is Dictionary:
			return false
		var hero: Dictionary = data.party[i]
		for key in template.party[i]:
			if key == "guard_strength" or key in Rules.SPEED_FIELDS:
				continue # Older version-1 saves stored a flat 50% guard.
			if not hero.has(key):
				return false
			if key not in ["hp", "mp", "shield", "guard", "speed"] and hero[key] != template.party[i][key]:
				return false
		if not _in_range(hero.hp, 0, hero.max_hp) or not _in_range(hero.mp, 0, hero.max_mp) or not _in_range(hero.shield, 0, 1000) or not hero.guard is bool:
			return false
		if hero.has("guard_strength") and not _in_range(hero.guard_strength, 0, 1, false):
			return false
		if not _in_range(hero.speed, 1, 999):
			return false
	for key in template.enemy:
		if key in Rules.SPEED_FIELDS or (key == "stagger_turns" and not data.enemy.has(key)):
			continue
		if not data.enemy.has(key):
			return false
		if key not in ["hp", "burn", "burn_turns", "exposed", "exposed_turns", "stagger_turns", "speed"] and data.enemy[key] != template.enemy[key]:
			return false
	if not _in_range(data.enemy.hp, 0, 650) or not _in_range(data.enemy.burn, 0, 100) or not _in_range(data.enemy.burn_turns, 0, 2) or not _in_range(data.enemy.exposed, 0, 1, false) or not _in_range(data.enemy.exposed_turns, 0, 2):
		return false
	if not _in_range(data.enemy.get("speed"), 1, 999):
		return false
	for entity in data.party + [data.enemy]:
		for key in Rules.SPEED_FIELDS:
			var high := 100000 if key.ends_with("_round") else (2 if key.ends_with("_turns") else 999)
			if not _in_range(entity.get(key, 0), 0, high):
				return false
	if not _in_range(data.enemy.get("stagger_turns", 0), 0, 1):
		return false
	if not _in_range(data.get("round"), 1, 100000) or not _in_range(data.get("turn"), 0, data.party.size()) or not _in_range(data.get("tonics"), 0, 2) or data.get("outcome") not in ["", "victory", "defeat"]:
		return false
	if data.outcome.is_empty() and (data.turn == data.party.size() or data.party[int(data.turn)].hp <= 0 or data.enemy.hp <= 0):
		return false
	if data.outcome == "victory" and data.enemy.hp != 0:
		return false
	if data.outcome == "defeat" and data.party.any(func(hero: Dictionary): return hero.hp > 0):
		return false
	if not data.get("history") is Array or not data.get("resonance") is Array:
		return false
	for entry in data.history:
		if not entry is String:
			return false
	for value in data.resonance:
		if not _in_range(value, 0, 1, false):
			return false
	if not _valid_queue(data):
		return false
	return true

static func _valid_queue(data: Dictionary) -> bool:
	var queue = data.get("queue", [])
	var spent = data.get("spent", [])
	var count: int = data.party.size()
	if not queue is Array or queue.size() > count or not spent is Array or spent.size() > count:
		return false
	var seen := {}
	for actor in spent:
		if not _in_range(actor, 0, count - 1) or seen.has(int(actor)):
			return false
		seen[int(actor)] = true
	var reserved_tonics := 0
	var template = Rules.new()
	for entry in queue:
		if not entry is Dictionary or not _in_range(entry.get("actor"), 0, count - 1) or not entry.get("action_id") is String or (entry.has("accuracy") and not _in_range(entry.accuracy, 0, 1, false)) or not _in_range(entry.get("target"), -1, count - 1):
			return false
		var actor := int(entry.actor)
		if seen.has(actor) or data.party[actor].hp <= 0:
			return false
		seen[actor] = true
		var action: Dictionary = template.action_for(actor, entry.action_id)
		if action.is_empty() or data.party[actor].mp < action.cost:
			return false
		if action.target == "ally":
			if entry.target < 0 or (action.id == "heal" and data.party[int(entry.target)].hp <= 0):
				return false
		elif entry.target != -1:
			return false
		if action.id == "tonic":
			reserved_tonics += 1
	if reserved_tonics > data.tonics:
		return false
	if data.outcome.is_empty() and data.has("queue"):
		var next := -1
		for actor in range(count):
			if data.party[actor].hp > 0 and not seen.has(actor):
				next = actor
				break
		if next != int(data.turn):
			return false
	return true

static func _in_range(value: Variant, low: float, high: float, integer: bool = true) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and (not integer or value == floor(value))

func restore_save(data: Dictionary) -> void:
	if not valid_save(data):
		return
	restart()
	for i in range(data.party.size()):
		for key in battle.party[i]:
			if key in Rules.SPEED_FIELDS:
				battle.party[i][key] = int(data.party[i].get(key, 0))
				continue
			if key == "guard_strength":
				battle.party[i][key] = float(data.party[i].get(key, 0.5 if data.party[i].guard else 0.0))
				continue
			battle.party[i][key] = int(data.party[i][key]) if battle.party[i][key] is int else data.party[i][key]
	for key in battle.enemy:
		battle.enemy[key] = int(data.enemy.get(key, 0)) if battle.enemy[key] is int else data.enemy[key]
	battle.round_number = int(data.round)
	battle.turn_cursor = int(data.turn)
	battle.tonics = int(data.tonics)
	battle.outcome = data.outcome
	if battle.outcome == "defeat" and data.party.size() < battle.party.size():
		battle.party[2].hp = 0
	battle.queued_actions.clear()
	for entry in data.get("queue", []):
		battle.queued_actions.append({"actor": int(entry.actor), "action_id": str(entry.action_id),
			"target": int(entry.target)})
	battle.spent_actors.clear()
	if data.has("queue"):
		for actor in data.get("spent", []):
			battle.spent_actors.append(int(actor))
	elif battle.outcome.is_empty():
		# Legacy mid-round saves already applied earlier actors' effects.
		for actor in range(battle.turn_cursor):
			battle.spent_actors.append(actor)
	history.assign(data.history)
	resonance.assign(data.resonance)
	enemy_hp = battle.enemy.hp
	hero_hp.clear()
	for hero in battle.party:
		hero_hp.append(float(hero.hp))
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

func _menu_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(0)
	return style

func draw_hud() -> void:
	HUDView.draw(self)
