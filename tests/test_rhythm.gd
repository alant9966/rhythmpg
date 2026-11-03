extends SceneTree

const Session = preload("res://rhythm/rhythm_session.gd")
const Charts = preload("res://rhythm/practice_charts.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func note(time: float, mask: int, duration: float = 0.0, direction: int = 0) -> Dictionary:
	return {"time": time, "mask": mask, "duration": duration, "direction": direction}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session = Session.new()
	var chord: Array[Dictionary] = [note(1, 1), note(1, 4)]
	session.setup("piano", chord)
	check(session.press(1.0, 0, 5), "First chord key hits")
	check(session.press(1.02, 2, 5), "Second chord key hits independently")
	check(session.perfect == 2 and session.is_complete(), "Chord resolves both notes")
	check(is_equal_approx(session.accuracy(), 1.0), "Perfect chord scores 100%")
	check(not chord[0].has("state"), "Source chart remains immutable")
	session.setup("piano", [note(1, 1)])
	check(session.press(1.1, 0, 1) and session.good == 1, "Good timing window")
	check(is_equal_approx(session.accuracy(), 0.7), "Good credit is 70%")
	session.setup("piano", [note(1, 1)])
	check(not session.press(0.8, 0, 1), "Early press is rejected")
	session.advance(1.15, 0)
	check(session.missed == 1 and session.is_complete(), "Late note expires")
	check(session.accuracy() == 0.0, "Misses and strays cannot produce negative score")
	session.setup("piano", [note(1, 1, 1)])
	session.press(1, 0, 1)
	session.advance(1.5, 0)
	check(session.broken_holds == 1 and session.combo == 0, "Early hold release breaks combo")
	check(is_equal_approx(session.accuracy(), 0.5), "Broken hold keeps only onset credit")
	session.setup("piano", [note(1, 1, 1)])
	session.press(1, 0, 1)
	session.advance(1.95, 0)
	check(session.broken_holds == 0 and session.accuracy() == 1.0, "Release grace accepts near-tail release")
	session.setup("guitar", [note(1, 3, 1, -1)])
	check(not session.press(1, 0, 1, -1), "Wrong guitar chord rejected")
	check(not session.press(1, 0, 7, -1), "Extra fret rejected")
	check(not session.press(1, 0, 3, 1), "Wrong strum direction rejected")
	check(session.press(1, 0, 3, -1), "Correct frets and up-strum accepted")
	session.advance(2, 3)
	check(session.is_complete() and session.broken_holds == 0, "Guitar chord sustain completes")
	check(session.stray_inputs == 3, "Wrong strums are penalized")
	var guitar: Array[Dictionary] = Charts.make_chart("guitar")
	var chord_blocks: Array[Dictionary] = Charts.guitar_chords()
	check(is_equal_approx(4 * Charts.beat_seconds("guitar"), 3.0), "Guitar four-beat bar is three seconds")
	check(guitar.size() == 24, "Guitar repeats six strums over four chord blocks")
	for block in range(4):
		var consistent := true
		for strum in range(6):
			var n: Dictionary = guitar[block * 6 + strum]
			consistent = consistent and n.mask == chord_blocks[block].mask
			consistent = consistent and n.duration == 0.0
			consistent = consistent and n.direction == Charts.STRUM_DIRECTIONS[strum]
			consistent = consistent and is_equal_approx(n.time, 3.0 + block * 3.0 + Charts.STRUM_BEATS[strum] * 0.75)
		check(consistent, "Guitar block %d holds one shape and repeats D D U U D U" % block)
	# Play every supplied chart perfectly, including overlaps and sustain tails.
	for instrument in ["piano", "guitar"]:
		var chart: Array[Dictionary] = Charts.make_chart(instrument)
		session.setup(instrument, chart)
		var index := 0
		for tick in range(1701):
			var time := tick / 100.0
			var held := 0
			for n in chart:
				# Release within tail grace before preparing the next chord.
				if time >= n.time - 0.00001 and time <= n.time + maxf(0.0, n.duration - 0.04) + 0.00001:
					held |= int(n.mask)
			if instrument == "guitar":
				# Keep the whole chord down between strums, as a player does.
				for block in chord_blocks:
					if time >= block.time and time < block.time + block.duration:
						held = int(block.mask)
			session.advance(time, held)
			while index < chart.size() and float(chart[index].time) <= time + 0.00001:
				var n: Dictionary = chart[index]
				var lane := 0
				while (1 << lane) != int(n.mask) and instrument == "piano":
					lane += 1
				session.press(float(n.time), lane, held, int(n.direction))
				index += 1
		check(session.is_complete(), instrument + " entire chart completes")
		if session.accuracy() < 1.0:
			print(instrument, " ", session.result())
			for n in session.notes:
				if n.quality < 1.0:
					print(n)
		check(session.accuracy() == 1.0, instrument + " entire chart can score 100%")
		check(session.missed == 0 and session.broken_holds == 0, instrument + " has playable hold overlaps")
		session.setup(instrument, chart)
		session.advance(100, 0)
		check(session.missed == chart.size() and session.is_complete(), instrument + " idle play completes with misses")
	# Test the real host lifecycle and input routing, without waiting for music.
	var lab = load("res://scenes/rhythm_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.start_performance("piano")
	lab.song_time = 4 * Charts.BEAT
	key(lab, KEY_A, true)
	check(lab.session.perfect == 0 and lab.held_mask == 0, "Old piano A key is inactive")
	key(lab, KEY_A, false)
	key(lab, KEY_D, true)
	check(lab.session.perfect == 1, "Piano D routes to first lane")
	key(lab, KEY_D, false)
	for lane in range(1, 4):
		lab.song_time = (4 + lane) * Charts.BEAT
		var code: int = [KEY_D, KEY_F, KEY_J, KEY_K][lane]
		key(lab, code, true)
		check(lab.session.perfect == lane + 1, "Piano D/F/J/K lane %d works" % lane)
		key(lab, code, false)
	lab._toggle_pause()
	check(lab.paused and lab.music.stream_paused, "Pause suspends audio")
	lab._reset()
	check(not lab.running and not lab.paused and lab.session.perfect == 0, "Reset clears performance")
	lab.start_performance("guitar")
	lab.song_time = 4 * Charts.beat_seconds("guitar")
	key(lab, KEY_S, true)
	key(lab, KEY_D, true)
	check(lab.held_mask == 3 and lab.session.perfect == 0, "Guitar S/D hold frets without rhythm judgments")
	key(lab, KEY_SPACE, true)
	check(lab.session.perfect == 0 and lab.session.stray_inputs == 0, "Old space strum is inactive")
	key(lab, KEY_DOWN, true)
	key(lab, KEY_DOWN, false)
	check(lab.session.perfect == 1, "Down arrow strums held guitar chord")
	lab.song_time = 3.75
	key(lab, KEY_DOWN, true)
	key(lab, KEY_DOWN, false)
	lab.song_time = 4.125
	key(lab, KEY_UP, true)
	key(lab, KEY_UP, false)
	check(lab.session.perfect == 3 and lab.held_mask == 3, "One held chord accepts repeated down/down/up strums")
	# Prepare D+F at the next three-second boundary, without a fret timing test.
	lab.song_time = 5.9
	key(lab, KEY_S, false)
	key(lab, KEY_F, true)
	check(lab.held_mask == 6 and lab.session.stray_inputs == 0, "Guitar F selects third fret; chord changes are not rhythm inputs")
	lab.song_time = 6.0
	key(lab, KEY_DOWN, true)
	check(lab.session.perfect == 4, "New chord is accepted on next bar's downbeat")
	lab.song_time = 30.0
	lab._process(0.01)
	check(not lab.running and not lab.results.is_empty(), "Host emits finished results")
	check(lab.results.instrument == "guitar", "Result identifies the instrument")
	lab.start_performance("piano")
	check(lab.results.is_empty() and lab.session.perfect == 0, "Replay creates fresh state")
	lab._reset()
	lab.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("Rhythm checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func key(lab: Node, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	lab._input(event)
