extends Node2D
## Traversable overworld. Add zones and encounter definitions as the journey expands.
const Shell = preload("res://global/game_shell.gd")
const Actor = preload("res://combat/battle_actor.gd")
@onready var shell: Shell = get_node("/root/GameShell")

const ZONES := {
	"city": {
		"name": "Lumen's Rest",
		"bounds": Rect2(40, 100, 430, 620),
		"entry": Vector2(410, 455),
	},
	"wilderness": {
		"name": "Whispering Wilds",
		"bounds": Rect2(470, 100, 710, 620),
		"entry": Vector2(550, 455),
	},
}
const PLAYER_START := Vector2(180, 455)
const ENCOUNTER_SCENE := "res://scenes/combat.tscn"
const SPEED := 210.0
const TRAIL_DISTANCE := 4.5
const WORLD_BOUNDS := Rect2(40, 100, 1140, 620)
const LOAD_ZONE := Rect2(438, 390, 84, 130)
const MAP_KEY := KEY_M
const BARRIERS := {
	"city": [
		Rect2(50, 145, 180, 150), Rect2(270, 205, 155, 130),
		Rect2(55, 575, 155, 115), Rect2(280, 565, 170, 125),
	],
	"wilderness": [
		Rect2(535, 105, 150, 125), Rect2(760, 105, 130, 110),
		Rect2(1040, 105, 120, 130), Rect2(540, 565, 155, 115),
		Rect2(1030, 545, 145, 135),
	],
}

var player: Actor
var followers: Array[Actor] = []
var enemy: Actor
var position_history: Array[Vector2] = []
var encounter_started := false
var current_zone := "city"
var prompt: Label
var location_label: Label
var controls_label: Label
var world_art: WorldArt
var moving := false
var current_area := "city"
var visited_areas: Dictionary = {"city": true}
var travel_panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	shell.register_scene(self)
	_build_world()
	_build_hud()
	_load_position_from_pending()
	_refresh_area()

func _build_world() -> void:
	world_art = WorldArt.new()
	world_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_art)

	player = _actor("res://assets/characters/warrior.png", PLAYER_START, 1.65)
	add_child(player)
	player.z_index = 10
	position_history.append(PLAYER_START)

	var mage := _actor("res://assets/characters/mage.png", PLAYER_START + Vector2(-20, 20), 1.55)
	add_child(mage)
	mage.z_index = 9
	followers.append(mage)

	var cleric := _actor("res://assets/characters/cleric.png", PLAYER_START + Vector2(-38, 6), 1.55)
	add_child(cleric)
	cleric.z_index = 8
	followers.append(cleric)

	enemy = _actor("res://assets/enemies/Monster_4 SV Battler.png", Vector2(965, 390), 1.7, true)
	add_child(enemy)
	enemy.z_index = 7
	if shell.world_enemy_defeated or current_area == "city":
		enemy.queue_free()
		enemy = null

func _actor(path: String, feet: Vector2, scale: float, is_enemy: bool = false) -> Actor:
	var actor := Actor.new()
	actor.setup(path, feet, scale, is_enemy)
	actor.play(Actor.MOTION_IDLE)
	return actor

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var header := PanelContainer.new()
	header.position = Vector2(28, 24)
	header.size = Vector2(1144, 62)
	header.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.11, 0.13, 0.92), Color("52615f")))
	layer.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 20)
	header.add_child(header_row)
	location_label = Label.new()
	location_label.custom_minimum_size.x = 280
	location_label.add_theme_font_size_override("font_size", 24)
	location_label.add_theme_color_override("font_color", Color("eaca8a"))
	header_row.add_child(location_label)
	controls_label = Label.new()
	controls_label.text = "WASD / arrows to move"
	controls_label.add_theme_font_size_override("font_size", 16)
	controls_label.add_theme_color_override("font_color", Color("a5b4bd"))
	header_row.add_child(controls_label)
	var map_button := Button.new()
	map_button.text = "Travel map (M)"
	map_button.custom_minimum_size = Vector2(170, 40)
	map_button.pressed.connect(_toggle_travel_map)
	header_row.add_child(map_button)
	prompt = Label.new()
	prompt.position = Vector2(390, 710)
	prompt.size = Vector2(420, 50)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 19)
	prompt.add_theme_color_override("font_color", Color("eaca8a"))
	layer.add_child(prompt)

func _physics_process(delta: float) -> void:
	if encounter_started:
		return
	if is_instance_valid(travel_panel):
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S):
		direction.y += 1
	moving = direction.length_squared() > 0
	if moving:
		direction = direction.normalized()
		player.face_direction(direction)
		var next_position := player.position + direction * SPEED * delta
		if _walkable(next_position):
			player.position = next_position
		player.position.x = clampf(player.position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
		player.position.y = clampf(player.position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)
		if position_history.is_empty() or player.position.distance_to(position_history[0]) > 4:
			position_history.push_front(player.position)
			if position_history.size() > 240:
				position_history.pop_back()
	_set_walking(player, moving)
	_update_followers()
	if _try_load_zone():
		return
	current_zone = current_area
	location_label.text = ZONES[current_area].name
	if not is_instance_valid(enemy):
		prompt.text = "The road is clear. Keep exploring."
		return
	var distance := player.position.distance_to(enemy.position)
	if distance < 145:
		prompt.text = "The Warden blocks the road."
	elif current_zone == "city":
		prompt.text = "Leave the city and follow the road into the wilds."
	else:
		prompt.text = "Walk up to the enemy to begin the encounter."
	if distance < 72:
		_start_encounter()

func _update_followers() -> void:
	for index in followers.size():
		var trail_index := mini(position_history.size() - 1, int((index + 1) * TRAIL_DISTANCE))
		if trail_index < 0:
			continue
		var follower := followers[index]
		var target := position_history[trail_index]
		var travel := target - follower.position
		follower.position = follower.position.lerp(target, 0.18)
		follower.face_direction(travel)
		_set_walking(follower, follower.position.distance_to(target) > 3.0)

func _set_walking(actor: Actor, should_walk: bool) -> void:
	var motion := Actor.MOTION_WALK if should_walk else Actor.MOTION_IDLE
	if actor.motion != motion:
		actor.play(motion)

func _zone_at(point: Vector2) -> String:
	for zone_id in ZONES:
		if ZONES[zone_id].bounds.has_point(point):
			return zone_id
	return "wilderness"

func _walkable(point: Vector2) -> bool:
	if not WORLD_BOUNDS.has_point(point):
		return false
	for barrier in BARRIERS[current_area]:
		if barrier.grow(10).has_point(point):
			return false
	return true

func _try_load_zone() -> bool:
	if current_area == "city" and LOAD_ZONE.has_point(player.position):
		_enter_area("wilderness")
		return true
	if current_area == "wilderness" and LOAD_ZONE.has_point(player.position):
		_enter_area("city")
		return true
	return false

func _enter_area(area_id: String) -> void:
	current_area = area_id
	visited_areas[area_id] = true
	player.position = ZONES[area_id].entry
	position_history.clear()
	position_history.append(player.position)
	_refresh_area()

func _refresh_area() -> void:
	world_art.current_area = current_area
	world_art.queue_redraw()
	if current_area == "wilderness" and not shell.world_enemy_defeated:
		_spawn_enemy()
	elif current_area == "city" and is_instance_valid(enemy):
		enemy.queue_free()
		enemy = null

func _spawn_enemy() -> void:
	if is_instance_valid(enemy):
		return
	enemy = _actor("res://assets/enemies/Monster_4 SV Battler.png", Vector2(965, 390), 1.7, true)
	enemy.z_index = 7
	add_child(enemy)

func _toggle_travel_map() -> void:
	if is_instance_valid(travel_panel):
		travel_panel.queue_free()
		travel_panel = null
		return
	travel_panel = PanelContainer.new()
	travel_panel.position = Vector2(320, 170)
	travel_panel.size = Vector2(560, 390)
	travel_panel.add_theme_stylebox_override("panel", _panel_style(Color("152630"), Color("d7bd81")))
	add_child(travel_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	travel_panel.add_child(content)
	var title := Label.new()
	title.text = "TRAVEL MAP"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("eaca8a"))
	content.add_child(title)
	var hint := Label.new()
	hint.text = "Only visited areas can be reached."
	hint.add_theme_color_override("font_color", Color("a5b4bd"))
	content.add_child(hint)
	for area_id in visited_areas:
		var button := Button.new()
		button.text = ZONES[area_id].name + ("  · current" if area_id == current_area else "")
		button.custom_minimum_size.y = 52
		button.disabled = area_id == current_area
		button.pressed.connect(func(): _travel_to(area_id))
		content.add_child(button)
	var close := Button.new()
	close.text = "Close / M"
	close.pressed.connect(_toggle_travel_map)
	content.add_child(close)

func _travel_to(area_id: String) -> void:
	if not visited_areas.has(area_id):
		return
	travel_panel.queue_free()
	travel_panel = null
	_enter_area(area_id)

func _start_encounter() -> void:
	if encounter_started:
		return
	encounter_started = true
	prompt.text = "Encounter!"
	shell.world_return_position = player.position
	shell.world_encounter_active = true
	get_tree().change_scene_to_file(ENCOUNTER_SCENE)

func _load_position_from_pending() -> void:
	var pending: Dictionary = shell.pending_save
	if not pending.is_empty() and pending.get("scene") == scene_file_path:
		var payload: Dictionary = pending.get("payload", {})
		if valid_save(payload):
			player.position = Vector2(payload.position.x, payload.position.y)
			current_area = str(payload.zone)
			visited_areas = {}
			for area_id in payload.get("visited", ["city"]):
				if area_id in ZONES:
					visited_areas[area_id] = true
			position_history.clear()
			position_history.append(player.position)
			return
	if shell.world_encounter_active:
		player.position = shell.world_return_position
		position_history.clear()
		position_history.append(player.position)
		shell.world_encounter_active = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == MAP_KEY:
		_toggle_travel_map()

func make_save() -> Dictionary:
	return {
		"position": {"x": player.position.x, "y": player.position.y},
		"zone": current_area,
		"visited": visited_areas.keys(),
		"summary": "World map · " + str(ZONES[current_area].name),
	}

static func valid_save(data: Dictionary) -> bool:
	var position: Variant = data.get("position", {})
	return position is Dictionary \
		and (position.get("x") is float or position.get("x") is int) \
		and (position.get("y") is float or position.get("y") is int) \
		and WORLD_BOUNDS.has_point(Vector2(position.x, position.y)) \
		and data.get("zone", "") in ZONES

func restore_save(data: Dictionary) -> void:
	if not valid_save(data) or not is_instance_valid(player):
		return
	player.position = Vector2(data.position.x, data.position.y)
	current_area = str(data.zone)
	visited_areas = {}
	for area_id in data.get("visited", ["city"]):
		if area_id in ZONES:
			visited_areas[area_id] = true
	position_history.clear()
	position_history.append(player.position)

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

class WorldArt extends Control:
	var current_area := "city"

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("101e23"))
		draw_rect(Rect2(40, 100, 430, 620), Color("375b45"))
		draw_line(Vector2(350, 455), Vector2(965, 390), Color("a88a5a"), 58, true)
		draw_line(Vector2(350, 455), Vector2(965, 390), Color("d1b378"), 5, true)
		draw_rect(Rect2(50, 145, 180, 150), Color("6b4d43"))
		draw_colored_polygon(PackedVector2Array([Vector2(45, 145), Vector2(140, 92), Vector2(235, 145)]), Color("8d594c"))
		draw_rect(Rect2(270, 205, 155, 130), Color("6b4d43"))
		draw_colored_polygon(PackedVector2Array([Vector2(260, 205), Vector2(347, 155), Vector2(435, 205)]), Color("8d594c"))
		draw_rect(Rect2(55, 575, 155, 115), Color("4c6744"))
		draw_rect(Rect2(280, 565, 170, 125), Color("4c6744"))
		draw_texture_rect(load("res://assets/map/map samples/sample 1.png"), Rect2(470, 100, 710, 620), false)
		draw_rect(Rect2(438, 390, 84, 130), Color(0.83, 0.74, 0.46, 0.18), true)
		draw_string(ThemeDB.fallback_font, Vector2(62, 690), "LUMEN'S REST", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eaca8a"))
		draw_string(ThemeDB.fallback_font, Vector2(940, 690), "WHISPERING WILDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("83d4c4"))
		draw_string(ThemeDB.fallback_font, Vector2(430, 380), "LOAD ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff0b0"))
