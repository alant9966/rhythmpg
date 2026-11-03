class_name PracticeCharts
extends RefCounted
## Beats are relative to the audio start; four beats are reserved for count-in.
const BPM := 100.0
const BEAT := 60.0 / BPM
const GUITAR_BPM := 80.0
const GUITAR_CHORD_SECONDS := 3.0
# A relaxed four-beat bar: down, down-up, (rest)-up, down-up.
const STRUM_BEATS := [0.0, 1.0, 1.5, 2.5, 3.0, 3.5]
const STRUM_DIRECTIONS := [1, 1, -1, -1, 1, -1]

static func beat_seconds(instrument: String) -> float:
	return 60.0 / GUITAR_BPM if instrument == "guitar" else BEAT

static func guitar_chords() -> Array[Dictionary]:
	var chords: Array[Dictionary] = []
	# S+D -> D+F -> S+F -> S+D. One finger stays down at each change.
	for mask in [3, 6, 5, 3]:
		chords.append({"time": 3.0 + chords.size() * GUITAR_CHORD_SECONDS,
			"duration": GUITAR_CHORD_SECONDS, "mask": mask})
	return chords

static func phrase_end(instrument: String) -> float:
	return 15.0 if instrument == "guitar" else 26.0 * BEAT

static func make_chart(instrument: String) -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	if instrument == "piano":
		# beat, lane, hold length. Simultaneous entries form a chord.
		var phrase := [
			[4, 0, 0], [5, 1, 0], [6, 2, 0], [7, 3, 0],
			[8, 0, 0], [8, 2, 0], [9, 1, 0], [9, 3, 0],
			[10, 0, 2], [11, 2, 0], [12, 1, 0], [12.5, 2, 0],
			[13, 3, 0], [14, 1, 1.5], [14, 3, 1.5],
			[16, 0, 0], [16.5, 1, 0], [17, 2, 0], [17.5, 3, 0],
			[18, 0, 0], [18, 3, 0], [19, 1, 0], [19, 2, 0],
			[20, 0, 2], [20, 2, 2], [22, 1, 0], [23, 3, 0],
			[24, 0, 2], [24, 1, 2], [24, 3, 2],
		]
		for item in phrase:
			notes.append({"time": float(item[0]) * BEAT, "mask": 1 << int(item[1]),
				"duration": float(item[2]) * BEAT, "direction": 0})
	else:
		# Keep one chord for a whole three-second bar. Only strums are timed.
		for chord in guitar_chords():
			for i in range(STRUM_BEATS.size()):
				notes.append({"time": chord.time + STRUM_BEATS[i] * beat_seconds("guitar"),
					"mask": chord.mask, "duration": 0.0, "direction": STRUM_DIRECTIONS[i]})
	return notes
