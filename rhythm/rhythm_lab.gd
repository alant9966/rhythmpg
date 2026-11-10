extends Control
const Shell = preload("res://global/game_shell.gd")
@onready var shell: Shell = get_node("/root/GameShell")
## Standalone host. Instantiate this scene later, call start_performance(), and
## consume performance_finished. Escape opens the global pause menu.
signal performance_finished(result: Dictionary)

const Charts = preload("res://rhythm/practice_charts.gd")
const Session = preload("res://rhythm/rhythm_session.gd")
const StrumVisuals = preload("res://rhythm/strum_visuals.gd")
const Circles = preload("res://rhythm/circle_visuals.gd")
const CombatMaps = preload("res://combat/combat_beatmaps.gd")
const Style = preload("res://rhythm/rhythm_theme.gd")
const BACKGROUND = preload("res://assets/backgrounds/1280x720/forest_clearing.png")
const PIANO_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const GUITAR_KEYS := [KEY_S, KEY_D, KEY_F]
const LANE_COLORS := [Color("79d8d0"), Color("97b9ff"), Color("c6a0ed"), Color("f2c675")]
const INK := Style.INK
const MUTED := Style.MUTED
const HIT_Y := 630.0
const TOP_Y := 230.0
const TRAVEL := 2.0
const EMPTY_RUNWAY_SECONDS := 1.0

var session = Session.new()
var instrument := "piano"
var running := false
var paused := false
var held_mask := 0
var song_time := 0.0
var feedback := "Choose an instrument, then start a phrase."
var feedback_color := INK
var feedback_life := 0.0
var offset_ms := 0.0
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Array[AudioStream] = []
var font: Font
var start_button: Button
var pause_button: Button
var piano_button: Button
var guitar_button: Button
var timpani_button: Button
var timpani_variation := -1
var offset_control: SpinBox
var mute_button: CheckButton
var results: Dictionary = {}
var audio_ended_at := -1
var performance_end_time := 0.0
var preparation_left := 0.0
var mode_button: Button

func _ready() -> void:
	font = ThemeDB.fallback_font
	music = AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(func(): audio_ended_at = Time.get_ticks_usec())
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	session.judged.connect(_on_judged)
	piano_button = _button("01  PIANO", Rect2(52, 114, 160, 44), func(): _select("piano"))
	guitar_button = _button("02  GUITAR", Rect2(224, 114, 160, 44), func(): _select("guitar"))
	timpani_button = _button("03  TIMPANI", Rect2(396, 114, 160, 44), func(): _select("timpani"))
	mode_button = _button("Return to battle / " + shell.key_name("switch_mode"), Rect2(830, 24, 318, 44), _return_to_battle)
	start_button = _button("Start phrase", Rect2(730, 114, 160, 44), func(): start_performance(instrument))
	pause_button = _button("Pause", Rect2(902, 114, 110, 44), _toggle_pause)
	_button("Reset", Rect2(1024, 114, 124, 44), _reset)
	offset_control = SpinBox.new()
	offset_control.position = Vector2(947, 730)
	offset_control.size = Vector2(100, 36)
	offset_control.min_value = -250
	offset_control.max_value = 250
	offset_control.step = 5
	offset_control.suffix = "ms"
	offset_control.value_changed.connect(func(value: float):
		offset_ms = value
		get_tree().set_meta("rhythm_offset_ms", value))
	offset_control.value_changed.connect(func(_value: float): shell._save_settings())
	add_child(offset_control)
	offset_control.value = float(get_tree().get_meta("rhythm_offset_ms", 0.0))
	offset_control.get_line_edit().focus_mode = Control.FOCUS_NONE
	mute_button = CheckButton.new()
	mute_button.text = "Mute"
	mute_button.position = Vector2(1055, 730)
	mute_button.toggled.connect(_set_muted)
	add_child(mute_button)
	_select("piano")
	get_viewport().size_changed.connect(queue_redraw)
	shell.register_scene(self)

func _button(title: String, bounds: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	Style.button(button)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _select(mode: String) -> void:
	_reset()
	instrument = mode
	session.setup(instrument, Charts.make_chart(instrument))
	performance_end_time = Charts.phrase_end(instrument)
	sounds.clear()
	for lane in range(4):
		sounds.append(load("res://audio/%s_%d.wav" % [instrument, lane]))
	music.stream = load("res://audio/%s_practice.wav" % instrument)
	piano_button.disabled = mode == "piano"
	guitar_button.disabled = mode == "guitar"
	timpani_button.disabled = mode == "timpani"
	for tab in [piano_button, guitar_button, timpani_button]:
		tab.add_theme_color_override("font_disabled_color", Style.GOLD)
		tab.add_theme_stylebox_override("disabled", Style.panel(Color("273b40"), Style.GOLD))
	queue_redraw()

func start_performance(mode: String = "piano", chart: Array[Dictionary] = [], backing: AudioStream = null) -> void:
	_select(mode)
	if mode == "timpani" and chart.is_empty():
		var count := CombatMaps.count(mode)
		var next := randi_range(0, count - 1 if timpani_variation < 0 else count - 2)
		if timpani_variation >= 0 and next >= timpani_variation:
			next += 1
		timpani_variation = next
		session.setup(mode, Charts.make_chart(mode, next))
	if not chart.is_empty():
		session.setup(mode, chart)
		performance_end_time = 0.0
		for note in chart:
			performance_end_time = maxf(performance_end_time, float(note.time) + float(note.duration))
	if backing:
		music.stream = backing
	results.clear()
	held_mask = 0
	song_time = -0.1
	running = true
	audio_ended_at = -1
	feedback = "Listen to four count-in beats."
	preparation_left = EMPTY_RUNWAY_SECONDS
	start_button.text = "Restart phrase"
	pause_button.disabled = false

func _reset() -> void:
	if music:
		music.stop()
		music.stream_paused = false
	for voice in voices:
		voice.stop()
		voice.stream_paused = false
	running = false
	paused = false
	preparation_left = 0.0
	held_mask = 0
	song_time = 0.0
	results.clear()
	feedback = "Choose an instrument, then start a phrase."
	feedback_color = INK
	feedback_life = 0.0
	session.setup(instrument, Charts.make_chart(instrument))
	if start_button:
		start_button.text = "Start phrase"
		pause_button.text = "Pause"
		pause_button.disabled = true
	queue_redraw()

func _toggle_pause() -> void:
	shell.open_menu()

func _set_muted(value: bool) -> void:
	music.volume_db = -80.0 if value else 0.0
	for voice in voices:
		voice.volume_db = -80.0 if value else 0.0

func _clock() -> float:
	# Monotonic, speaker-aligned clock per Godot's audio synchronization guide.
	if audio_ended_at >= 0:
		return maxf(song_time, music.stream.get_length() + (Time.get_ticks_usec() - audio_ended_at) / 1000000.0)
	return maxf(song_time, music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

func _process(delta: float) -> void:
	feedback_life = maxf(0.0, feedback_life - delta)
	if running and not paused:
		if preparation_left > 0:
			preparation_left = maxf(0, preparation_left - delta)
			if preparation_left == 0:
				music.play()
			queue_redraw()
			return
		song_time = _clock()
		session.advance(song_time - offset_ms / 1000.0, held_mask)
		if session.is_complete() and song_time >= performance_end_time:
			_finish()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if running and instrument == "timpani" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not shell.is_open:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Circles.PRACTICE_AREA.has_point(point):
			get_viewport().set_input_as_handled()
			click_circle(point)
		return
	if not event is InputEventKey or event.echo or shell.is_open or shell.is_pause_event(event):
		return
	if event.pressed and shell.matches(event, "switch_mode"):
		_return_to_battle()
		return
	var lane: int = shell.lane(event, instrument)
	var lane_count := 4 if instrument == "piano" else 3
	var is_lane := lane >= 0 and lane < lane_count
	if is_lane:
		if event.pressed:
			held_mask |= 1 << lane
		else:
			held_mask &= ~(1 << lane)
	if event.pressed and shell.matches(event, "back"):
		_reset()
		return
	if not running or paused or preparation_left > 0:
		return
	if is_lane or (instrument == "guitar" and (shell.matches(event, "strum_down") or shell.matches(event, "strum_up"))):
		get_viewport().set_input_as_handled()
	var time := _clock() - offset_ms / 1000.0
	# Settle elapsed holds/misses before evaluating this input event.
	# On a key release, advance observes the updated held mask immediately.
	session.advance(time, held_mask)
	if not event.pressed:
		return
	# Count-in inputs are harmless practice, not score penalties.
	if time < 4.0 * Charts.beat_seconds(instrument) - Session.GOOD_WINDOW:
		return
	if instrument == "piano" and is_lane:
		if session.press(time, lane, held_mask):
			_play_note(lane)
	elif instrument == "guitar" and (shell.matches(event, "strum_down") or shell.matches(event, "strum_up")):
		if session.press(time, 0, held_mask, 1 if shell.matches(event, "strum_down") else -1):
			for fret in range(3):
				if held_mask & (1 << fret):
					_play_note(fret)

func click_circle(point: Vector2) -> bool:
	if not running or instrument != "timpani" or paused or preparation_left > 0 or shell.is_open or not Circles.PRACTICE_AREA.has_point(point):
		return false
	var now := _clock() - offset_ms / 1000.0
	if now < 4.0 * Charts.BEAT - Session.GOOD_WINDOW:
		return false
	if session.click(now, point, Circles.PRACTICE_AREA, Circles.RADIUS):
		_play_note((session.perfect + session.good - 1) % 4)
		return true
	return false

func _play_note(lane: int) -> void:
	for voice in voices:
		if not voice.playing:
			voice.stream_paused = false
			voice.stream = sounds[lane]
			voice.play()
			return
	voices[0].stream = sounds[lane]
	voices[0].play()

func _on_judged(message: String, successful: bool) -> void:
	feedback = message
	feedback_color = Color("83e2c3") if successful else Color("ff9b93")
	feedback_life = 0.65

func _finish() -> void:
	running = false
	session.finished = true
	music.stop()
	results = session.result()
	pause_button.disabled = true
	feedback = "Phrase complete — replay or try the other instrument."
	feedback_color = INK
	performance_finished.emit(results)

func _text(value: String, position: Vector2, size_px: int = 20, color: Color = INK) -> void:
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d28"))
	draw_texture_rect(BACKGROUND, Rect2(0, -42, maxf(1200, size.x), maxf(800, size.y)), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.06, 0.91))
	draw_rect(Rect2(0, 0, size.x, 92), Color(0.025, 0.045, 0.06, 0.85))
	_text("R H Y T H M P G   /   P R A C T I C E", Vector2(52, 33), 14, Style.GOLD)
	_text("Rhythm Lab", Vector2(50, 73), 32)
	draw_line(Vector2(52, 91), Vector2(1148, 91), Style.GOLD, 1)
	_text("PRACTICE MODE", Vector2(574, 142), 13, MUTED)
	_text("CIRCLESTRIKE / TIMPANI" if instrument == "timpani" else ("CHORDFALL / PIANO" if instrument == "piano" else "STRUMLINE / GUITAR"), Vector2(52, 184), 14, Style.GOLD)
	_text("%d BPM  /  4-BEAT COUNT-IN" % (Charts.GUITAR_BPM if instrument == "guitar" else Charts.BPM), Vector2(840, 183), 16, MUTED)
	if instrument == "timpani":
		_draw_timpani_lab()
		_draw_footer()
		return
	_text(" / ".join(shell.lane_names("piano")) + " · Tap at the line. Hold long notes; press chords together." if instrument == "piano" else "Hold " + " / ".join(shell.lane_names("guitar")) + " shapes for 3s. Strum " + shell.key_name("strum_down") + " / " + shell.key_name("strum_up") + " at the line.", Vector2(52, 214), 17)
	var count := 4 if instrument == "piano" else 3
	var left := 290.0
	var width := 620.0
	var lane_width := width / count
	var required_mask := int(_current_guitar_chord().mask) if instrument == "guitar" else 0
	draw_style_box(_panel(), Rect2(52, TOP_Y, 1096, 470))
	for lane in range(count):
		var x := left + lane * lane_width
		var pressed := (held_mask & (1 << lane)) != 0
		if instrument == "guitar":
			StrumVisuals.fret(self, Rect2(x + 3, TOP_Y + 4, lane_width - 6, HIT_Y - TOP_Y + 52), (required_mask & (1 << lane)) != 0, pressed)
		else:
			draw_rect(Rect2(x + 3, TOP_Y + 4, lane_width - 6, HIT_Y - TOP_Y + 52), Color("1c293a"))
		if instrument == "guitar":
			draw_line(Vector2(x + lane_width / 2, TOP_Y), Vector2(x + lane_width / 2, HIT_Y), Color("927752"), 2)
		if instrument == "piano":
			draw_rect(Rect2(x + 4, HIT_Y + 12, lane_width - 8, 42), LANE_COLORS[lane] if pressed else Color("dce3ed"))
		else:
			draw_circle(Vector2(x + lane_width / 2, HIT_Y + 33), 23, LANE_COLORS[lane] if pressed else Color("34445b"))
		_text(shell.key_name("%s_%d" % [instrument, lane + 1]), Vector2(x + lane_width / 2 - 12, HIT_Y + 41), 18, Color("101724") if pressed or instrument == "piano" else INK)
	if instrument == "piano":
		for boundary in range(1, count):
			draw_rect(Rect2(left + boundary * lane_width - 12, HIT_Y + 12, 24, 19), Color("101724"))
	# Beat grid travels with the notes; stronger lines indicate measure starts.
	for beat in range(29):
		var y := HIT_Y - (beat * Charts.beat_seconds(instrument) - song_time) / TRAVEL * (HIT_Y - TOP_Y)
		if y >= TOP_Y and y <= HIT_Y:
			draw_line(Vector2(left, y), Vector2(left + width, y), Color("46536a") if beat % 4 == 0 else Color("29374b"), 1)
	for note in session.notes:
		if preparation_left > 0:
			break
		if note.state == "done":
			continue
		var y: float = HIT_Y - (float(note.time) - song_time) / TRAVEL * (HIT_Y - TOP_Y)
		var tail_y: float = HIT_Y - (float(note.time) + float(note.duration) - song_time) / TRAVEL * (HIT_Y - TOP_Y)
		if y < TOP_Y or tail_y > HIT_Y + 30:
			continue
		if note.state == "holding":
			y = HIT_Y
		if instrument == "guitar":
			# Frets stay in one shape; only strum cues travel to the hit line.
			draw_line(Vector2(left + 35, y), Vector2(left + width - 35, y), Color("927752"), 2)
			draw_style_box(_note_style(Color("f2c675")), Rect2(left + width / 2 - 56, y - 15, 112, 30))
			StrumVisuals.arrow(self, Vector2(left + width / 2 - 37, y), int(note.direction), 24, Color("101724"))
			_text("DOWN" if int(note.direction) == 1 else "UP", Vector2(left + width / 2 - 22, y + 7), 20, Color("101724"))
			continue
		for lane in range(count):
			if not (int(note.mask) & (1 << lane)):
				continue
			var x := left + lane_width * (lane + 0.5)
			if note.duration > 0.0:
				draw_line(Vector2(x, maxf(TOP_Y, tail_y)), Vector2(x, minf(y, HIT_Y)), Color(LANE_COLORS[lane], 0.5), 16)
			draw_style_box(_note_style(LANE_COLORS[lane]), Rect2(x - 45, y - 10, 90, 20))
	draw_line(Vector2(left - 12, HIT_Y), Vector2(left + width + 12, HIT_Y), INK, 3)
	_text("HIT", Vector2(left - 58, HIT_Y + 6), 15, MUTED)
	_text("COMBO", Vector2(82, 280), 14, MUTED)
	_text(str(session.combo), Vector2(82, 323), 36)
	_text("ACCURACY", Vector2(82, 372), 14, MUTED)
	_text("%.1f%%" % (session.accuracy() * 100), Vector2(82, 408), 26)
	_text("%d / %d" % [session.perfect + session.good + session.missed, session.notes.size()], Vector2(977, 280), 22)
	_text("NOTES", Vector2(977, 305), 14, MUTED)
	if instrument == "guitar":
		_draw_guitar_chord(left, lane_width)
		_text("STRUM PATTERN", Vector2(977, 365), 14, MUTED)
		StrumVisuals.pattern(self, Vector2(986, 388), 26, 22)
		StrumVisuals.arrow(self, Vector2(984, 430), 1, 18, Color("f2c675"))
		_text("= " + shell.key_name("strum_down"), Vector2(1000, 435), 14, MUTED)
		StrumVisuals.arrow(self, Vector2(984, 455), -1, 18, Color("f2c675"))
		_text("= " + shell.key_name("strum_up"), Vector2(1000, 460), 14, MUTED)
	_draw_footer()

func _draw_timpani_lab() -> void:
	_text("Left-click each numbered circle when its shrinking ring meets the target edge.", Vector2(52, 214), 17)
	draw_style_box(_panel(), Rect2(52, TOP_Y, 1096, 470))
	draw_style_box(Style.panel(Color("101d28")), Rect2(276, 241, 676, 448))
	_text("COMBO", Vector2(82, 280), 14, MUTED)
	_text(str(session.combo), Vector2(82, 323), 36)
	_text("ACCURACY", Vector2(82, 372), 14, MUTED)
	_text("%.1f%%" % (session.accuracy() * 100), Vector2(82, 408), 26, Style.TEAL)
	_text("GOLD = NEXT", Vector2(82, 477), 16, Style.GOLD)
	_text("Aim, then click once.", Vector2(82, 507), 14, MUTED)
	_text("%d / %d" % [session.perfect + session.good + session.missed, session.notes.size()], Vector2(977, 280), 22)
	_text("CIRCLES", Vector2(977, 305), 14, MUTED)
	if running and preparation_left <= 0:
		Circles.draw(self, session.notes, song_time, Circles.PRACTICE_AREA, font)
	elif results.is_empty() and not running:
		_text("Click Start phrase to practice CircleStrike.", Vector2(426, 476), 19, MUTED)

func _draw_footer() -> void:
	var progress := clampf(song_time / maxf(performance_end_time, 0.01), 0, 1)
	draw_rect(Rect2(52, 709, 1096, 3), Color("29374b"))
	draw_rect(Rect2(52, 709, 1096 * progress, 3), Color("83e2c3"))
	if not results.is_empty():
		draw_style_box(_panel(), Rect2(310, 320, 580, 220))
		_text("PHRASE COMPLETE", Vector2(340, 359), 24, Color("83e2c3"))
		_text("%.1f%% accuracy   /   %d best combo" % [results.accuracy * 100, results.max_combo], Vector2(340, 403), 24)
		_text("%d perfect   •   %d good   •   %d missed" % [results.perfect, results.good, results.missed], Vector2(340, 446), 19)
		_text("%d broken holds   •   %d stray inputs" % [results.broken_holds, results.stray_inputs], Vector2(340, 480), 19, MUTED)
	elif paused:
		draw_style_box(_panel(), Rect2(370, 370, 460, 130))
		_text("PAUSED", Vector2(530, 418), 28)
		_text("Resume when you’re ready." if instrument == "timpani" else "Re-hold the keys you were playing.", Vector2(393, 465), 17, MUTED)
	_text(feedback, Vector2(52, 746), 16, feedback_color)
	_text("Esc pause menu    " + shell.key_name("back") + " reset", Vector2(52, 776), 15, MUTED)
	_text("Timing offset", Vector2(832, 754), 15, MUTED)

func _fret_text(mask: int) -> String:
	var names: PackedStringArray = []
	for lane in range(3):
		if mask & (1 << lane):
			names.append(shell.key_name("guitar_%d" % (lane + 1)))
	return " + ".join(names)

func _current_guitar_chord() -> Dictionary:
	var chords: Array[Dictionary] = Charts.guitar_chords()
	for chord in chords:
		if song_time < float(chord.time) + float(chord.duration):
			return chord
	return chords.back()

func _draw_guitar_chord(left: float, lane_width: float) -> void:
	var chords: Array[Dictionary] = Charts.guitar_chords()
	var index := 0
	while index < chords.size() - 1 and song_time >= float(chords[index].time) + float(chords[index].duration):
		index += 1
	var chord: Dictionary = chords[index]
	var preparing := song_time < float(chord.time)
	_text("PREPARE CHORD" if preparing else "HOLD CHORD", Vector2(82, 468), 14, MUTED)
	_text(_fret_text(int(chord.mask)), Vector2(82, 501), 25, Color("f2c675"))
	var remaining: float = maxf(0, float(chord.time) + float(chord.duration) - song_time)
	if preparing:
		_text("Hold this shape", Vector2(82, 532), 17, MUTED)
	else:
		_text("%.1fs left" % remaining, Vector2(82, 532), 17, MUTED)
	if index + 1 < chords.size():
		_text("NEXT: " + _fret_text(int(chords[index + 1].mask)), Vector2(82, 575), 18)
	else:
		_text("FINAL CHORD", Vector2(82, 575), 16, MUTED)
	draw_rect(Rect2(82, 548, 170, 4), Color("34445b"))
	draw_rect(Rect2(82, 548, 170 * clampf(remaining / Charts.GUITAR_CHORD_SECONDS, 0, 1), 4), Color("f2c675"))
	for lane in range(3):
		if int(chord.mask) & (1 << lane):
			draw_arc(Vector2(left + lane_width * (lane + 0.5), HIT_Y + 33), 27, 0, TAU, 40, Color("f2c675"), 2)

func refresh_bindings() -> void:
	mode_button.text = "Return to battle / " + shell.key_name("switch_mode")
	queue_redraw()

func _return_to_battle() -> void:
	shell.return_from_rhythm_lab()

func sync_after_pause(duration_usec: int) -> void:
	held_mask = shell.held_mask(instrument)
	if audio_ended_at >= 0:
		audio_ended_at += duration_usec

func make_save() -> Dictionary:
	return {"instrument": instrument, "summary": "Rhythm Lab · " + instrument.capitalize()}

static func valid_save(data: Dictionary) -> bool:
	return data.get("instrument") in ["piano", "guitar", "timpani"]

func restore_save(data: Dictionary) -> void:
	if valid_save(data):
		_select(data.instrument)

func _panel() -> StyleBoxFlat:
	return Style.panel(Color("152530"))

func _note_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
