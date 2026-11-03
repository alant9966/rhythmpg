extends Node
## Always-running shell: pause, persistent controls, and safe command-point saves.
signal bindings_changed
const SETTINGS := "user://controls.cfg"
const SAVE_DIR := "user://saves"
const DEFAULTS := {
	"piano_1": KEY_D, "piano_2": KEY_F, "piano_3": KEY_J, "piano_4": KEY_K,
	"guitar_1": KEY_S, "guitar_2": KEY_D, "guitar_3": KEY_F,
	"strum_down": KEY_DOWN, "strum_up": KEY_UP,
	"command_1": KEY_1, "command_2": KEY_2, "command_3": KEY_3, "command_4": KEY_4, "command_5": KEY_5,
	"pause": KEY_P, "back": KEY_BACKSPACE, "switch_mode": KEY_F8, "replay": KEY_R,
}
const LABELS := {
	"piano_1": "Piano · lane 1", "piano_2": "Piano · lane 2", "piano_3": "Piano · lane 3", "piano_4": "Piano · lane 4",
	"guitar_1": "Guitar · fret 1", "guitar_2": "Guitar · fret 2", "guitar_3": "Guitar · fret 3",
	"strum_down": "Guitar · down strum", "strum_up": "Guitar · up strum",
	"command_1": "Command / ally 1", "command_2": "Command / ally 2", "command_3": "Command 3", "command_4": "Command 4", "command_5": "Command 5",
	"pause": "Pause shortcut (Esc always works)", "back": "Back / reset practice / forfeit phrase", "switch_mode": "Combat ↔ Rhythm Lab", "replay": "Replay finished battle",
}
var bindings: Dictionary = DEFAULTS.duplicate()
var scene_ref: WeakRef
var pending_save: Dictionary = {}
var world_return_position := Vector2.ZERO
var world_encounter_active := false
var world_enemy_defeated := false
var is_open := false
var page := "main"
var capture_action := ""
var notice := ""
var resume_left := -1.0
var paused_audio: Array[Dictionary] = []
var paused_at := 0
var layer: CanvasLayer
var veil: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var countdown: Label
var controls_scroll := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_install_actions()
	layer = CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	veil = ColorRect.new()
	veil.color = Color(0.015, 0.025, 0.04, 0.86)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	panel = PanelContainer.new()
	panel.position = Vector2(175, 70)
	panel.size = Vector2(850, 660)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152630")
	style.border_color = Color("d7bd81")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	layer.hide()
	get_tree().auto_accept_quit = false

func register_scene(scene: Node) -> void:
	scene_ref = weakref(scene)
	if scene.has_method("refresh_bindings") and not bindings_changed.is_connected(scene.refresh_bindings):
		bindings_changed.connect(scene.refresh_bindings)
	if not pending_save.is_empty():
		call_deferred("_restore_pending")

func current_scene() -> Node:
	return scene_ref.get_ref() if scene_ref else null

func matches(event: InputEvent, action: String) -> bool:
	return event is InputEventKey and int(event.physical_keycode) == int(bindings.get(action, 0))

func key_name(action: String) -> String:
	return OS.get_keycode_string(int(bindings.get(action, 0)))

func lane(event: InputEvent, mode: String) -> int:
	for i in range(4 if mode == "piano" else 3):
		if matches(event, "%s_%d" % [mode, i + 1]):
			return i
	return -1

func lane_names(mode: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for i in range(4 if mode == "piano" else 3):
		names.append(key_name("%s_%d" % [mode, i + 1]))
	return names

func held_mask(mode: String) -> int:
	var result := 0
	for i in range(4 if mode == "piano" else 3):
		if Input.is_physical_key_pressed(int(bindings["%s_%d" % [mode, i + 1]])):
			result |= 1 << i
	return result

func is_pause_event(event: InputEvent) -> bool:
	return event is InputEventKey and (event.physical_keycode == KEY_ESCAPE or matches(event, "pause"))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo or not event.pressed:
		return
	if is_open and not capture_action.is_empty():
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			capture_action = ""
			notice = "Rebinding cancelled."
		else:
			notice = rebind(capture_action, int(event.physical_keycode))
			if notice.is_empty():
				notice = "Binding saved."
				capture_action = ""
		_render()
		return
	if is_pause_event(event):
		get_viewport().set_input_as_handled()
		if not is_open:
			open_menu()
		elif resume_left >= 0:
			resume_left = -1
			_render()
		elif page != "main":
			_show_page("main")
		else:
			resume_game()
	elif is_open:
		# Paused scenes cannot receive gameplay input. Leave menu navigation to GUI.
		return

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		open_menu()
		_show_page("quit")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
		if not is_open:
			open_menu()
		elif resume_left >= 0:
			resume_left = -1
			_render()

func open_menu() -> void:
	if is_open or not is_instance_valid(layer):
		return
	is_open = true
	page = "main"
	notice = ""
	resume_left = -1
	paused_at = Time.get_ticks_usec()
	paused_audio.clear()
	_freeze_audio(get_tree().root)
	get_tree().paused = true
	layer.show()
	_render()

func _freeze_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		paused_audio.append({"node": weakref(node), "paused": node.stream_paused})
		node.stream_paused = true
	for child in node.get_children():
		_freeze_audio(child)

func resume_game(with_countdown: bool = true) -> void:
	if not is_open:
		return
	capture_action = ""
	if with_countdown:
		resume_left = 0.85
		_render()
	else:
		_finish_resume()

func _finish_resume() -> void:
	var scene := current_scene()
	if scene and scene.has_method("sync_after_pause"):
		scene.sync_after_pause(Time.get_ticks_usec() - paused_at)
	for entry in paused_audio:
		var player = entry.node.get_ref()
		if is_instance_valid(player):
			player.stream_paused = entry.paused
	paused_audio.clear()
	resume_left = -1
	is_open = false
	layer.hide()
	get_tree().paused = false

func _process(delta: float) -> void:
	if is_open and resume_left >= 0:
		resume_left -= delta
		if resume_left <= 0:
			_finish_resume()
		elif is_instance_valid(countdown):
			countdown.text = "READY IN %.1f" % resume_left

func _show_page(next: String) -> void:
	page = next
	notice = ""
	capture_action = ""
	_render()

func _label(text: String, font_size: int = 18, color: Color = Color("e8eee9"), parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	(parent if parent else content).add_child(label)
	return label

func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	(parent if parent else content).add_child(button)
	return button

func _render() -> void:
	for child in content.get_children():
		if child is ScrollContainer:
			controls_scroll = child.scroll_vertical
		content.remove_child(child)
		child.queue_free()
	countdown = null
	_label("R H Y T H M P G   /   P A U S E D", 15, Color("eaca8a"))
	if resume_left >= 0:
		_label("Prepare to resume", 32)
		_label("Place your hands on the current keys. The game and audio remain frozen until the countdown ends.")
		countdown = _label("READY IN %.1f" % resume_left, 34, Color("83d4c4"))
		_button("Stay paused / Esc", func(): resume_left = -1; _render())
		return
	match page:
		"main":
			_label("Take a breath.", 34)
			_label("The battle, rhythm timing, animations, and audio are paused.", 16, Color("a5b4bd"))
			_button("Resume game", resume_game)
			_button("Save / Load", func(): _show_page("saves"))
			_button("Controls & keybindings", func(): _show_page("controls"))
			_button("How to play · rhythm guide", func(): _show_page("guide"))
			_button("Exit game", func(): _show_page("quit"))
		"saves":
			_label("Save / Load", 30)
			_label("Combat saves restore the latest command-selection point. An unfinished action is replayed from its command; practice saves reopen the selected instrument.", 16, Color("a5b4bd"))
			for slot in range(1, 4):
				var data := read_slot(slot)
				_label("SLOT %d  ·  %s" % [slot, str(data.get("summary", "Empty"))], 17, Color("eaca8a"))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 12)
				content.add_child(row)
				var save := _button("Save here" if data.is_empty() else "Overwrite save", func(): notice = save_slot(slot); _render(), row)
				save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var load_button := _button("Load save", func(): notice = load_slot(slot); if not notice.is_empty(): _render(), row)
				load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				load_button.disabled = data.is_empty()
		"controls":
			_label("Controls & keybindings", 30)
			_label("Click a binding, then press a key. Esc cancels capture and always opens pause. Shared piano/guitar keys are allowed; conflicting keys within a mode are rejected.", 15, Color("a5b4bd"))
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size.y = 310
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content.add_child(scroll)
			scroll.set_deferred("scroll_vertical", controls_scroll)
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(rows)
			for action in DEFAULTS:
				var row := HBoxContainer.new()
				rows.add_child(row)
				var label := _label(LABELS[action], 16, Color("e8eee9"), row)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var button := _button("Press a key…" if capture_action == action else key_name(action), func(): capture_action = action; notice = "Press a new key, or Esc to cancel."; _render(), row)
				button.custom_minimum_size.x = 190
			_button("Restore default keys", func(): reset_bindings(); notice = "Default keys restored."; _render())
		"guide":
			_label("Play the phrase. Shape the battle.", 29)
			_label("PIANO · CHORDFALL", 20, Color("83d4c4"))
			_label("Use %s from left to right. Press when falling notes reach the white line. Press chord keys together; keep long notes held until their tails finish." % " / ".join(lane_names("piano")), 17)
			_label("GUITAR · STRUMLINE", 20, Color("eaca8a"))
			_label("Hold the displayed combination of %s frets. Use %s to strum down and %s to strum up at the hit line. In practice, change shapes every 3 seconds when prompted. In combat, hold one shape for the whole short action. Fret presses are not separate rhythm notes." % [" / ".join(lane_names("guitar")), key_name("strum_down"), key_name("strum_up")], 17)
			_label("THE PATTERN · DOWN, DOWN–UP, UP, DOWN–UP", 16, Color("eaca8a"))
			_label("The rhythm view opens immediately with an empty play area for about one second, giving you time to ready your hands. Combat then plays one short 120 BPM bar; practice uses a four-beat audio count-in. Perfect timing is within 65 ms, Good within 140 ms. Accuracy strengthens damage, healing, shields, and status effects. Misses keep the baseline effect.", 16)
			_label("Esc pauses without forfeiting. Use %s to back out of target selection, reset practice, or deliberately resolve a combat phrase at 0%%. Command keys: %s. Mode switch: %s." % [key_name("back"), " / ".join([key_name("command_1"), key_name("command_2"), key_name("command_3"), key_name("command_4"), key_name("command_5")]), key_name("switch_mode")], 15, Color("a5b4bd"))
		"quit":
			_label("Exit RhythmPG?", 32)
			_label("Unsaved progress will be lost. You can create a save before leaving.", 18)
			_button("Save / Load", func(): _show_page("saves"))
			_button("Exit game", func(): get_tree().quit())
	if page != "main":
		_button("Back to pause menu / Esc", func(): _show_page("main"))
	status = _label(notice, 15, Color("83d4c4"))
	call_deferred("_focus_menu")

func _focus_menu() -> void:
	if not is_open or not capture_action.is_empty() or resume_left >= 0:
		return
	var buttons: Array[Button] = []
	_collect_buttons(content, buttons)
	if not buttons.is_empty():
		var index := clampi(controls_scroll / 48, 0, DEFAULTS.size() - 1) if page == "controls" else 0
		buttons[mini(index, buttons.size() - 1)].grab_focus()

func _collect_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button and not node.disabled:
		result.append(node)
	for child in node.get_children():
		_collect_buttons(child, result)

func _group(action: String) -> String:
	if action.begins_with("piano_"):
		return "piano"
	if action.begins_with("guitar_") or action.begins_with("strum_"):
		return "guitar"
	if action.begins_with("command_"):
		return "command"
	return "global"

func rebind(action: String, code: int) -> String:
	if not DEFAULTS.has(action) or code <= 0 or code in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return "Choose a single key. Esc and modifier-only keys cannot be assigned."
	for other in bindings:
		if other != action and int(bindings[other]) == code and (_group(other) == _group(action) or _group(other) == "global" or _group(action) == "global"):
			return "That key is already used by %s." % LABELS[other]
	bindings[action] = code
	_install_actions()
	_save_settings()
	bindings_changed.emit()
	return ""

func reset_bindings() -> void:
	bindings = DEFAULTS.duplicate()
	_install_actions()
	_save_settings()
	bindings_changed.emit()

func _install_actions() -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(bindings[action])
		InputMap.action_add_event(action, event)

func _save_settings() -> void:
	var config := ConfigFile.new()
	for action in bindings:
		config.set_value("keys", action, bindings[action])
	config.set_value("rhythm", "offset_ms", get_tree().get_meta("rhythm_offset_ms", 0.0))
	config.save(SETTINGS)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK:
		return
	# Reuse conflict validation without touching disk or signals during startup.
	var candidate: Dictionary = DEFAULTS.duplicate()
	for action in DEFAULTS:
		var value = config.get_value("keys", action, DEFAULTS[action])
		if value is int and value > 0 and value not in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			candidate[action] = value
	for action in candidate:
		for other in candidate:
			if action != other and candidate[action] == candidate[other] and (_group(action) == _group(other) or _group(action) == "global" or _group(other) == "global"):
				candidate = DEFAULTS.duplicate()
				break
	bindings = candidate
	get_tree().set_meta("rhythm_offset_ms", clampf(float(config.get_value("rhythm", "offset_ms", 0.0)), -250, 250))

func save_slot(slot: int) -> String:
	var scene := current_scene()
	if slot < 1 or slot > 3 or not scene or not scene.has_method("make_save"):
		return "This scene cannot be saved."
	var payload: Dictionary = scene.make_save()
	if payload.is_empty():
		return "No command point is available yet."
	var data := {"version": 1, "scene": scene.scene_file_path, "payload": payload,
		"summary": str(payload.get("summary", "Progress")) + "  ·  " + Time.get_datetime_string_from_system(false, true)}
	return _write_slot(slot, data)

func _write_slot(slot: int, data: Dictionary) -> String:
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if error != OK:
		return "Could not create the saves folder."
	var path := "%s/slot_%d.json" % [SAVE_DIR, slot]
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file:
		return "Could not write this save."
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return "The save could not be completed; the previous save is unchanged."
	# Rename the previous slot out of the way, retaining recovery on replacement failure.
	if FileAccess.file_exists(path):
		error = DirAccess.rename_absolute(path, path + ".bak")
		if error != OK:
			return "Could not replace the existing save."
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(path + ".bak", path)
		return "Could not finish writing this save."
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	return "Saved in slot %d." % slot

func read_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > 3:
		return {}
	var path := "%s/slot_%d.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("payload") is Dictionary:
		return {}
	if data.get("scene") not in ["res://scenes/world_map.tscn", "res://scenes/combat.tscn", "res://scenes/rhythm_lab.tscn"]:
		return {}
	return data

func load_slot(slot: int) -> String:
	var data := read_slot(slot)
	if data.is_empty():
		return "This slot is empty or contains an unreadable save."
	var script = load("res://world/world_map.gd" if data.scene == "res://scenes/world_map.tscn" else ("res://combat/combat_scene.gd" if data.scene == "res://scenes/combat.tscn" else "res://rhythm/rhythm_lab.gd"))
	if not script.valid_save(data.payload):
		return "This save contains invalid progress and cannot be loaded."
	pending_save = data
	if is_open:
		resume_game(false)
	var error := get_tree().change_scene_to_file(data.scene)
	if error != OK:
		pending_save.clear()
		open_menu()
		return "Could not open the saved scene."
	return ""

func _restore_pending() -> void:
	var scene := current_scene()
	if scene and not pending_save.is_empty():
		var payload: Dictionary = pending_save.payload
		pending_save = {}
		scene.restore_save(payload)
