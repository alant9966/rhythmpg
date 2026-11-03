extends Control
const Shell = preload("res://global/game_shell.gd")
@onready var shell: Shell = get_node("/root/GameShell")
## Compact battle performance, reusing the standalone scoring engine.
signal completed(result: Dictionary)
const Session = preload("res://rhythm/rhythm_session.gd")
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

func _ready() -> void:
	font = ThemeDB.fallback_font
	player = AudioStreamPlayer.new()
	add_child(player)
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	session.judged.connect(func(message: String, _success: bool): feedback = message)
	hide()

static func chart(mode: String, mask: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if mode == "guitar":
		var beats := [0.0, 1.0, 1.5, 2.5, 3.0, 3.5]
		var directions := [1, 1, -1, -1, 1, -1]
		for i in range(beats.size()):
			result.append({"time": LEAD + beats[i] * BEAT, "mask": mask, "duration": 0.0, "direction": directions[i]})
	else:
		for item in [[0, 0], [0.5, 1], [1, 2], [1.5, 3], [2, 0], [2, 2], [3, 1], [3, 3]]:
			result.append({"time": LEAD + float(item[0]) * BEAT, "mask": 1 << int(item[1]),
				"duration": 0.35 if float(item[0]) == 3 else 0.0, "direction": 0})
	return result

func start(mode: String, action_name: String, mask: int = 3) -> void:
	cancel()
	offset_ms = float(get_tree().get_meta("rhythm_offset_ms", 0.0))
	instrument = mode
	chord_mask = mask
	title = action_name
	session.setup(mode, chart(mode, mask))
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
	if not font:
		return
	_text(title.to_upper(), Vector2(16, 29), 20, Color("f5cf85"))
	_text("120 BPM  /  " + ("STRUMLINE" if instrument == "guitar" else "CHORDFALL"), Vector2(455, 28), 14)
	var hit := 177.0
	if instrument == "piano":
		_text(" / ".join(shell.lane_names("piano")), Vector2(16, 65), 16, COLORS[0])
		_text("Tap chords together", Vector2(16, 91), 13)
		_text("Hold long notes", Vector2(16, 112), 13)
		for lane in range(4):
			var x := 217.0 + lane * 80
			draw_rect(Rect2(x, 43, 73, 145), Color("243346"))
			draw_rect(Rect2(x, 185, 73, 24), COLORS[lane] if held & (1 << lane) else Color("d5dde8"))
			_text(shell.key_name("piano_%d" % (lane + 1)), Vector2(x + 12, 203), 15, Color("131c28"))
		for note in session.notes:
			if preparation_left > 0:
				break
			if note.state == "done":
				continue
			var lane := 0
			while (1 << lane) != int(note.mask):
				lane += 1
			var y: float = hit - (float(note.time) - time) / 0.85 * 130
			var tail: float = hit - (float(note.time) + float(note.duration) - time) / 0.85 * 130
			if note.state == "holding":
				y = hit
			if y < 49 or tail > 190:
				continue
			var x := 253.0 + lane * 80
			if note.duration > 0:
				draw_line(Vector2(x, maxf(47, tail)), Vector2(x, y), Color(COLORS[lane], 0.6), 10)
			draw_rect(Rect2(x - 29, y - 5, 58, 10), COLORS[lane])
		draw_line(Vector2(212, hit), Vector2(535, hit), Color.WHITE, 2)
	else:
		var names: PackedStringArray = []
		for lane in range(3):
			if chord_mask & (1 << lane):
				names.append(shell.key_name("guitar_%d" % (lane + 1)))
		_text("HOLD " + " + ".join(names), Vector2(16, 67), 22, Color("f5cf85"))
		_text("One shape, whole phrase", Vector2(16, 91), 13)
		_text(shell.key_name("strum_down") + " / " + shell.key_name("strum_up") + " strum", Vector2(16, 113), 13)
		StrumVisuals.pattern(self, Vector2(27, 137), 27, 19)
		for lane in range(3):
			StrumVisuals.fret(self, Rect2(10 + lane * 55, 158, 49, 51), (chord_mask & (1 << lane)) != 0, (held & (1 << lane)) != 0)
			_text(shell.key_name("guitar_%d" % (lane + 1)), Vector2(25 + lane * 55, 189), 16)
		for y in [88, 104, 120]:
			draw_line(Vector2(232, y), Vector2(559, y), Color("806a4e"), 1)
		draw_line(Vector2(265, 54), Vector2(265, 153), Color.WHITE, 2)
		_text("HIT", Vector2(251, 176), 13)
		for note in session.notes:
			if preparation_left > 0:
				break
			if note.state == "done":
				continue
			var x: float = 265 + (float(note.time) - time) / 1.15 * 290
			if x < 243 or x > 548:
				continue
			draw_circle(Vector2(x, 104), 18, Color("f5cf85"))
			StrumVisuals.arrow(self, Vector2(x, 104), int(note.direction), 25, Color("152031"))
	_text("%d%%" % roundi(session.accuracy() * 100), Vector2(596, 77), 29, COLORS[0])
	_text("ACCURACY", Vector2(596, 100), 12)
	_text(feedback, Vector2(577, 136), 14, Color("f5cf85"))
	_text("Esc pause / " + shell.key_name("back") + " forfeit", Vector2(380, 235), 13, Color("aebdcc"))
	draw_rect(Rect2(16, 222, 690, 3), Color("34465e"))
	draw_rect(Rect2(16, 222, 690 * clampf(time / END, 0, 1), 3), COLORS[0])
	if preparation_left > 0:
		draw_rect(Rect2(205, 43, 355, 166), Color(0.03, 0.05, 0.09, 0.93))
		_text("GET READY", Vector2(322, 92), 18, Color("f5cf85"))
		_text("%d" % ceili(preparation_left), Vector2(366, 145), 42, COLORS[0])
		draw_rect(Rect2(250, 166, 265, 8), Color("34465e"))
		draw_rect(Rect2(250, 166, 265 * clampf(preparation_left / EMPTY_RUNWAY_SECONDS, 0, 1), 8), COLORS[0])
	if paused:
		draw_rect(Rect2(205, 43, 355, 166), Color(0.03, 0.05, 0.09, 0.96))
		_text("PAUSED — P TO RESUME", Vector2(242, 128), 19)
