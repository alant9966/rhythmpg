extends Control
const Shell = preload("res://global/game_shell.gd")
@onready var shell: Shell = get_node("/root/GameShell")
## Compact battle performance, reusing the standalone scoring engine.
signal completed(result: Dictionary)
const Session = preload("res://rhythm/rhythm_session.gd")
const Beatmaps = preload("res://combat/combat_beatmaps.gd")
const RhythmView = preload("res://combat/combat_rhythm_view.gd")
const Circles = preload("res://rhythm/circle_visuals.gd")
const StrumVisuals = preload("res://rhythm/strum_visuals.gd")
const BEAT := 0.5
const LEAD := 0.65
const END := LEAD + 4 * BEAT
const EMPTY_RUNWAY_SECONDS := 2.0
const COLORS := [Color("88dbd3"), Color("abc7ff"), Color("d3b0ec"), Color("f5cf85")]
var session = Session.new()
var instrument := "guitar"
var active := false
var paused := false
var time := -0.1
var held := 0
var chord_mask := 3
var feedback := "READY"
var player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var samples: Array[AudioStream] = []
var font: Font
var offset_ms := 0.0
var title := ""
var preparation_left := 0.0
var variation_index := 0
var pattern_name := ""
var pattern_directions: Array = []
var bonus_hint := ""
var rng := RandomNumberGenerator.new()
var variation_bags: Dictionary = {}
var last_variation: Dictionary = {}

func _ready() -> void:
	font = ThemeDB.fallback_font
	rng.randomize()
	player = AudioStreamPlayer.new()
	add_child(player)
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	session.judged.connect(func(message: String, _success: bool): feedback = message)
	hide()

static func chart(mode: String, mask: int = 3, variation: int = 0) -> Array[Dictionary]:
	return Beatmaps.chart(mode, mask, variation)

func _next_variation(mode: String) -> int:
	var bag: Array = variation_bags.get(mode, [])
	if bag.is_empty():
		bag = range(Beatmaps.count(mode))
		for i in range(bag.size() - 1, 0, -1):
			var other := rng.randi_range(0, i)
			var value: int = bag[i]
			bag[i] = bag[other]
			bag[other] = value
		if bag.back() == last_variation.get(mode, -1):
			var value: int = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = value
	var selected: int = bag.pop_back()
	variation_bags[mode] = bag
	last_variation[mode] = selected
	return selected

func start(mode: String, action_name: String, mask: int = 3, perfect_bonus: String = "") -> void:
	cancel()
	offset_ms = float(get_tree().get_meta("rhythm_offset_ms", 0.0))
	instrument = mode
	chord_mask = mask
	title = action_name
	bonus_hint = perfect_bonus
	variation_index = _next_variation(mode)
	pattern_name = Beatmaps.pattern_name(mode, variation_index)
	pattern_directions.clear()
	if mode == "guitar":
		pattern_directions.assign(Beatmaps.GUITAR[variation_index].directions)
	session.setup(mode, chart(mode, mask, variation_index))
	held = 0
	time = -0.1
	paused = false
	feedback = "READY"
	samples.clear()
	for lane in range(4):
		samples.append(load("res://audio/%s_%d.wav" % [mode, lane]))
	player.stream = load("res://audio/combat_%s.wav" % mode)
	player.stream_paused = false
	preparation_left = EMPTY_RUNWAY_SECONDS
	active = true
	show()
	queue_redraw()

func cancel() -> void:
	active = false
	paused = false
	preparation_left = 0.0
	if player:
		player.stop()
	for voice in voices:
		voice.stop()
	hide()

func resolve_now() -> void:
	if not active:
		return
	var result: Dictionary = session.result()
	result.accuracy = 0.0
	cancel()
	completed.emit(result)

func _clock() -> float:
	return maxf(time, player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

func _process(delta: float) -> void:
	if not active or paused:
		return
	if preparation_left > 0:
		preparation_left = maxf(0, preparation_left - delta)
		if preparation_left == 0:
			player.play()
		queue_redraw()
		return
	time = _clock()
	session.advance(time - offset_ms / 1000.0, held)
	if time >= END + maxf(0, offset_ms / 1000.0) and session.is_complete():
		var result: Dictionary = session.result()
		cancel()
		completed.emit(result)
	queue_redraw()

func toggle_pause() -> void:
	shell.open_menu()

func _input(event: InputEvent) -> void:
	if active and instrument == "timpani" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not shell.is_open:
		get_viewport().set_input_as_handled()
		if preparation_left <= 0 and not paused:
			var point := Circles.logical_point(get_global_transform_with_canvas().affine_inverse() * event.position, size)
			click_circle(point)
		return
	if not active or not event is InputEventKey or event.echo or shell.is_open or shell.is_pause_event(event):
		return
	var lane: int = shell.lane(event, instrument)
	if lane >= 0:
		if event.pressed:
			held |= 1 << lane
		else:
			held &= ~(1 << lane)
	get_viewport().set_input_as_handled()
	if event.pressed and shell.matches(event, "back"):
		resolve_now()
		return
	if paused or preparation_left > 0:
		return
	var now := _clock() - offset_ms / 1000.0
	session.advance(now, held)
	if not event.pressed or now < LEAD - Session.GOOD_WINDOW:
		return
	if instrument == "piano" and lane >= 0:
		if session.press(now, lane, held):
			_sound(lane)
	elif instrument == "guitar" and (shell.matches(event, "strum_up") or shell.matches(event, "strum_down")):
		if session.press(now, 0, held, 1 if shell.matches(event, "strum_down") else -1):
			for fret in range(3):
				if held & (1 << fret):
					_sound(fret)

func click_circle(point: Vector2) -> bool:
	if not active or instrument != "timpani" or preparation_left > 0 or paused or shell.is_open or not Circles.COMBAT_AREA.has_point(point):
		return false
	var now := _clock() - offset_ms / 1000.0
	if now < LEAD - Session.GOOD_WINDOW:
		return false
	if session.click(now, point, Circles.COMBAT_AREA, Circles.RADIUS):
		_sound((session.perfect + session.good - 1) % 4)
		return true
	return false

func _sound(lane: int) -> void:
	for voice in voices:
		if not voice.playing:
			voice.stream = samples[lane]
			voice.stream_paused = false
			voice.volume_db = -7
			voice.play()
			return

func _text(text: String, pos: Vector2, px: int = 16, color: Color = Color("eef1f5")) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _draw() -> void:
	RhythmView.draw(self)
