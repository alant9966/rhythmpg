class_name RhythmSession
extends RefCounted
## Pure gameplay state: no scene, audio, input, or combat dependencies.
signal judged(text: String, successful: bool)

const PERFECT_WINDOW := 0.065
const GOOD_WINDOW := 0.140
const HOLD_RELEASE_GRACE := 0.080

var instrument := "piano"
var notes: Array[Dictionary] = []
var combo := 0
var max_combo := 0
var perfect := 0
var good := 0
var missed := 0
var broken_holds := 0
var stray_inputs := 0
var earned := 0.0
var possible := 0.0
var finished := false

func setup(mode: String, chart: Array[Dictionary]) -> void:
	instrument = mode
	notes = chart.duplicate(true)
	combo = 0
	max_combo = 0
	perfect = 0
	good = 0
	missed = 0
	broken_holds = 0
	stray_inputs = 0
	earned = 0.0
	possible = 0.0
	finished = false
	for note in notes:
		note["state"] = "pending"
		note["quality"] = 0.0
		possible += 2.0 if note.duration > 0.0 else 1.0

func advance(time: float, held_mask: int) -> void:
	if finished:
		return
	for note in notes:
		if note.state == "pending" and time > note.time + GOOD_WINDOW:
			note.state = "done"
			missed += 1
			combo = 0
			judged.emit("MISS", false)
		elif note.state == "holding":
			var end: float = note.time + note.duration
			if time >= end - HOLD_RELEASE_GRACE:
				note.state = "done"
				earned += float(note.quality)
				judged.emit("SUSTAIN", true)
			elif (held_mask & int(note.mask)) != int(note.mask):
				note.state = "done"
				broken_holds += 1
				combo = 0
				judged.emit("HOLD BROKEN", false)

func press(time: float, lane: int, held_mask: int, direction: int = 0) -> bool:
	if finished:
		return false
	var candidate := -1
	var closest := GOOD_WINDOW + 0.00001
	for i in range(notes.size()):
		var note: Dictionary = notes[i]
		if note.state != "pending":
			continue
		if instrument == "piano" and int(note.mask) != (1 << lane):
			continue
		var distance: float = absf(time - float(note.time))
		if distance < closest:
			closest = distance
			candidate = i
	if candidate < 0:
		_stray()
		return false
	var selected: Dictionary = notes[candidate]
	if instrument == "guitar" and (held_mask != int(selected.mask) or direction != int(selected.direction)):
		_stray("WRONG FRETS" if held_mask != int(selected.mask) else "WRONG STRUM")
		return false
	var precise := closest <= PERFECT_WINDOW
	selected.quality = 1.0 if precise else 0.7
	earned += float(selected.quality)
	selected.state = "holding" if selected.duration > 0.0 else "done"
	if precise:
		perfect += 1
	else:
		good += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	judged.emit("PERFECT" if precise else "GOOD", true)
	return true

func _stray(message: String = "STRAY INPUT") -> void:
	stray_inputs += 1
	combo = 0
	judged.emit(message, false)

func accuracy() -> float:
	return clampf((earned - stray_inputs * 0.1) / maxf(possible, 1.0), 0.0, 1.0)

func is_complete() -> bool:
	for note in notes:
		if note.state != "done":
			return false
	return true

func result() -> Dictionary:
	return {"instrument": instrument, "accuracy": accuracy(), "perfect": perfect,
		"good": good, "missed": missed, "broken_holds": broken_holds,
		"stray_inputs": stray_inputs, "max_combo": max_combo, "note_count": notes.size()}
