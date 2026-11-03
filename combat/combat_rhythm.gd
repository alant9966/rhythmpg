extends Control
## Compact battle performance, reusing the standalone scoring engine.
signal completed(result: Dictionary)
const Session = preload("res://rhythm/rhythm_session.gd")
const BEAT := 0.5
const LEAD := 0.65
const END := LEAD + 4 * BEAT
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
	player.play()
	active = true
	show()
	queue_redraw()

func cancel() -> void:
	active = false
	paused = false
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

func _process(_delta: float) -> void:
	if not active or paused:
		return
	time = _clock()
	session.advance(time - offset_ms / 1000.0, held)
	if time >= END + maxf(0, offset_ms / 1000.0) and session.is_complete():
		var result: Dictionary = session.result()
		cancel()
		completed.emit(result)
	queue_redraw()

func toggle_pause() -> void:
	if not active:
		return
	paused = not paused
	player.stream_paused = paused
	for voice in voices:
		voice.stream_paused = paused
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and not paused:
		toggle_pause()
		held = 0

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or event.echo:
		return
	var code: int = event.physical_keycode
	var keys := [KEY_D, KEY_F, KEY_J, KEY_K] if instrument == "piano" else [KEY_S, KEY_D, KEY_F]
	var lane: int = keys.find(code)
	if lane >= 0:
		if event.pressed:
			held |= 1 << lane
		else:
			held &= ~(1 << lane)
	get_viewport().set_input_as_handled()
	if event.pressed and code == KEY_P:
		toggle_pause()
		return
	if event.pressed and code == KEY_ESCAPE:
		resolve_now()
		return
	if paused:
		return
	var now := _clock() - offset_ms / 1000.0
	session.advance(now, held)
	if not event.pressed or now < LEAD - Session.GOOD_WINDOW:
		return
	if instrument == "piano" and lane >= 0:
		if session.press(now, lane, held):
			_sound(lane)
	elif instrument == "guitar" and code in [KEY_UP, KEY_DOWN]:
		if session.press(now, 0, held, 1 if code == KEY_DOWN else -1):
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
		_text("D / F / J / K", Vector2(16, 65), 18, COLORS[0])
		_text("Tap chords together", Vector2(16, 91), 13)
		_text("Hold long notes", Vector2(16, 112), 13)
		for lane in range(4):
			var x := 217.0 + lane * 80
			draw_rect(Rect2(x, 43, 73, 145), Color("243346"))
			draw_rect(Rect2(x, 185, 73, 24), COLORS[lane] if held & (1 << lane) else Color("d5dde8"))
			_text(["D", "F", "J", "K"][lane], Vector2(x + 29, 203), 17, Color("131c28"))
		for note in session.notes:
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
				names.append(["S", "D", "F"][lane])
		_text("HOLD " + " + ".join(names), Vector2(16, 67), 22, Color("f5cf85"))
		_text("One shape, whole phrase", Vector2(16, 91), 13)
		_text("DOWN / UP arrows strum", Vector2(16, 113), 13)
		_text("v  v ^  ^ v ^", Vector2(16, 145), 19, Color("f5cf85"))
		for lane in range(3):
			var color: Color = COLORS[lane] if held & (1 << lane) else Color("34465e")
			draw_circle(Vector2(33 + lane * 55, 181), 19, color)
			_text(["S", "D", "F"][lane], Vector2(27 + lane * 55, 187), 17)
		for y in [88, 104, 120]:
			draw_line(Vector2(232, y), Vector2(559, y), Color("806a4e"), 1)
		draw_line(Vector2(265, 54), Vector2(265, 153), Color.WHITE, 2)
		_text("HIT", Vector2(251, 176), 13)
		for note in session.notes:
			if note.state == "done":
				continue
			var x: float = 265 + (float(note.time) - time) / 1.15 * 290
			if x < 243 or x > 548:
				continue
			draw_circle(Vector2(x, 104), 18, Color("f5cf85"))
			_text("v" if int(note.direction) == 1 else "^", Vector2(x - 7, 112), 25, Color("152031"))
	_text("%d%%" % roundi(session.accuracy() * 100), Vector2(596, 77), 29, COLORS[0])
	_text("ACCURACY", Vector2(596, 100), 12)
	_text(feedback, Vector2(577, 136), 14, Color("f5cf85"))
	_text("P pause  /  Esc resolve at 0%", Vector2(380, 235), 13, Color("aebdcc"))
	draw_rect(Rect2(16, 222, 690, 3), Color("34465e"))
	draw_rect(Rect2(16, 222, 690 * clampf(time / END, 0, 1), 3), COLORS[0])
	if paused:
		draw_rect(Rect2(205, 43, 355, 166), Color(0.03, 0.05, 0.09, 0.96))
		_text("PAUSED — P TO RESUME", Vector2(242, 128), 19)
