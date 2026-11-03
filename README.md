# RhythmPG — woodland combat prototype

Press **F5** to open the world map in `scenes/world_map.tscn`. Begin in
**Lumen's Rest**, the small starting city, then walk along the road into the
**Whispering Wilds**. Rowan leads while Lyra and the cleric trail behind; walk
up to the enemy to start the first encounter. Rowan uses
the supplied warrior sprite and guitar; Lyra uses the mage sprite and piano.
The Hollow Warden uses `Monster_4 SV Battler.png`, against `forest_clearing.png`.
This is a fully 2D scene with a receding painted ground, staggered positions and
sprite scales, contact shadows, foreground foliage, light shafts, and motes.
The supplied battle sheets animate idle, attack, casting, damage, guard, victory,
and defeat poses; packed effect atlases provide impacts, fire, shielding, and healing.
The overworld uses the same sheets for walking/idle animation, keeps the party
close together, and returns to the encounter entry position after a battle. A
defeated overworld enemy is removed when the party returns.
The supplied forest map sample is used for the wilderness backdrop; collision
barriers keep the party on the road. The city-to-wilderness boundary is a load
zone, and **M** opens a travel map for areas already visited.

## Playing the encounter

### World map

The map is data-driven in `world/world_map.gd`. Each entry in `ZONES` defines
its label, route position, description, and whether it starts an encounter.
Add a zone entry and a route in that file to expand the journey; encounter
zones can point to their own scene as the map grows. The city and wilderness
are connected by the first route, and the map is reachable from combat and
Rhythm Lab.

- **Esc** opens a global pause menu in combat and practice. Resume, save/load,
  edit keybindings, read the rhythm guide, or exit from this menu. **P** is a
  second pause shortcut by default. The scene, enemy timers, animations, and
  audio all freeze. Resume includes a 0.85-second countdown to ready your hands.
- Click a command or press **1–5**. Healing and tonics then ask for ally **1/2**.
- **Warrior:** hold the displayed **S/D/F** shape for the whole action and strum
  with **Down/Up arrows**. Each action repeats the familiar D D U U D U pattern.
- **Mage:** use **D/F/J/K** for the falling notes, chords, and brief holds.
- Every performance opens the **full rhythm view immediately**, showing its
  keys/chord and hit line with an **empty play area for one second**. Notes then
  begin approaching, with no separate preparation screen or countdown. Battle performances use
  **120 BPM**, a **0.65-second pickup**, and one bar, taking **2.65 seconds**
  after the empty opening. Commands stay in the same lower panel as the
  performance, keeping the battlefield visible. The longer practice charts remain available.
- Focus loss also opens global pause. **Backspace** deliberately resolves a
  combat performance at 0% accuracy; the action spends MP and keeps its baseline
  effect. Esc always pauses without forfeiting. Backspace also returns from ally
  targeting and resets a practice phrase.
- **F8** switches between combat and Rhythm Lab, starting a fresh encounter on
  return. **R** replays after victory/defeat. A restart button is available during command selection.
- Controls & keybindings lets you remap the instruments, strum directions,
  commands/targets, and utility shortcuts. Click a binding and press a new key;
  Esc cancels capture. Duplicate keys within one instrument or conflicting global
  shortcuts are rejected. Piano and guitar may share keys. Restore Defaults is
  available. All key prompts and instructions use the live bindings.
- Keybindings and Rhythm Lab's timing offset persist across launches in
  `user://controls.cfg`.

### Save slots

Open **Esc → Save / Load** to create, overwrite, or load one of **three slots**.
Slots show a timestamp and encounter round/instrument. Saves are versioned JSON
under `user://saves`, written via a temporary file with a backup during replacement.
Invalid saves are rejected before the current scene changes.

Combat saves capture the **latest command-selection point**, including HP/MP,
shields, guard, enemy HP/statuses, turn, round, tonics, and performance history.
Saving during an unfinished rhythm/action/enemy animation restores that last
safe command point, replaying that action from selection. This prevents duplicate
damage or item costs from partially completed animations. Finished battles can
also be saved. Practice saves restore the selected instrument, ready to start
a new phrase; they do not resume a partially completed practice chart.

### Example combat rules

| Character | HP / MP | ATK / MAG / DEF / SPD | Actions |
| --- | --- | --- | --- |
| Rowan, warrior / guitar | 180 / 24 | 24 / 8 / 14 / 15 | Downstroke; Rending Riff (6 MP); Iron Chorus (4 MP) |
| Lyra, mage / piano | 124 / 32 | 10 / 30 / 8 / 12 | Spark; Flame Sonata (8 MP); Mending Chord (7 MP) |
| Hollow Warden | 650 HP | ATK 39 / DEF 12 / RES 10 / SPD 10 | Telegraphed Heavy Cleave; every third round, Dissonant Wave hits the party |

Turn order is Rowan → Lyra → Warden, skipping fallen allies. Heroes recover 2 MP
when their next turn begins. Guard halves the next hit and restores another 4 MP.
Two shared Field Tonics restore 65 HP or revive a fallen ally with 55 HP.

Attack damage is `(power + offensive stat - enemy defense) × (1 + accuracy)`;
accuracy is clamped to 0–1. Expose then applies its additional damage multiplier.
Rending Riff exposes the foe for +10–25% damage over two enemy turns. Flame Sonata
burns for 6–18 HP at the start of each of two enemy turns; a burn kill prevents
the attack. Iron Chorus grants both living allies 14–34 shield HP, absorbed before
health damage. Mending Chord restores 35–80 HP and requires a living target.
Support bonuses scale with accuracy too. Missed performances retain baseline
effects; perfect timing doubles direct attack damage. HP/MP and healing are capped.

The always-running `global/game_shell.gd` autoload owns pause, controls, settings,
and save/load. The battle is split into `combat/battle_state.gd` (rules), `combat/combat_scene.gd`
(turn flow and HUD), `combat/combat_rhythm.gd` (compact performance using the same
`RhythmSession` as practice), and actor/stage presentation scripts. Placeholder
music, note samples, and impact audio are generated originally by the included tool.

Run `godot --headless --path . --script tests/test_combat.gd` for combat rules,
all skill paths, full victory through instrument input, real-time audio completion,
revival, replay, defeat, and packed-atlas checks. Render battle previews with
`godot --path . --rendering-method gl_compatibility --script tests/preview_combat.gd`.

Run `godot --headless --path . --script tests/test_shell.gd` for global pause,
resume countdown, preparation, rebinding persistence/conflicts, slot creation,
overwrite, load, validation, and paused enemy/rhythm timing. It uses slots 1/2;
run it with an isolated user-data directory when preserving personal saves.
`tests/preview_pause.gd` renders the menu pages and empty rhythm opening.

## Standalone rhythm practice

Open `project.godot` in Godot 4.7 and press **F6** on `scenes/rhythm_lab.tscn`,
or enter **Rhythm Lab / F8** from combat.
Choose Piano or Guitar, then click **Start phrase**. Listen to four count-in
beats; notes arrive at the white hit line on the following beat.

| Mode | Controls |
| --- | --- |
| Piano / Chordfall | D, F, J, K play the four lanes. Press simultaneous notes together. Hold keys through long tails. |
| Guitar / Strumline | Hold S, D, F chord shapes. DOWN ARROW strums down (`v`); UP ARROW strums up (`^`). Keep the same shape for each three-second bar. |
| Both | Esc or P opens global pause. Backspace or Reset clears the phrase. Start/Restart replays from the beginning. |

The game automatically pauses on focus loss. To resume a sustain, re-hold its
keys during the resume countdown. Timing offset is adjustable from -250 to +250 ms;
positive values accept later input. This setting shifts judgment, not the note
display. Mute preserves the audio clock so silent practice still works.

Guitar runs at a relaxed **80 BPM**, so each four-beat bar lasts exactly **three
seconds**. Hold **S+D → D+F → S+F → S+D**, changing shape once per bar.
The current shape, next shape, and change countdown appear on the left. Required
frets are highlighted across their full area in gold, turning green when held;
an incorrect held fret turns red. Full up/down arrows show strum directions in
both practice and combat. Only strum cues fall toward the hit line in practice.
Frets can be prepared freely; they are checked when you strum, rather than judged
as separate timed notes. The same common **down, down-up, up, down-up** pattern
repeats in every bar, on counts **1, 2, & of 2, & of 3, 4, & of 4**.
Piano remains at **100 BPM**.

## Scoring

- Perfect: within 65 ms; Good: within 140 ms. Later notes become misses.
- Piano chord keys are judged separately; each guitar strum judges one chord.
- A note onset is worth one unit; a sustain tail adds one more. Perfect earns
  100% of a unit, Good earns 70%. Hold tails inherit the onset quality.
- For piano sustains (or custom charts with sustains), releasing more than 80 ms
  before the tail ends breaks the hold and combo. Default guitar has no timed
  fret holds or sustain-tail judgments; only the strums are scored.
- Stray presses, incorrect guitar frets, and wrong strum directions reset combo
  and deduct 0.1 units. They do not consume an otherwise valid pending note.
- Accuracy uses the full chart's possible units, so it rises during the phrase.
  An untouched phrase finishes with 0%; every supplied chart can reach 100%.

## Structure and future integration

- `rhythm/rhythm_session.gd`: scene-independent judgment, holds, combo, scoring.
- `rhythm/practice_charts.gd`: 100 BPM piano and 80 BPM guitar charts, each with
  a four-beat lead-in; guitar also defines three-second chord blocks.
- `rhythm/rhythm_lab.gd`: visual host, keyboard input, audio clock, test controls.
- `scenes/rhythm_lab.tscn`: independently instantiable practice scene.
- `audio/`: original synthesized placeholder backing tracks and note samples.
  Python is **not** required to play. `python tools/generate_practice_audio.py`
  regenerates those assets using only Python's standard library.

To integrate later, instantiate the scene, connect `performance_finished`, and
call `start_performance("piano")` or `start_performance("guitar")`. The signal
returns an instrument ID, normalized `accuracy` (0–1), perfect/good/miss counts,
broken holds, stray inputs, maximum combo, and note count. Backspace cancels practice
without emitting a completed result; Esc opens pause. No combat formulas exist in the rhythm scorer.

Custom charts can be supplied as the second argument and a matching non-looping
`AudioStream` as the third. Each chart entry contains `time` (seconds from audio
start), `mask` (piano D=1/F=2/J=4/K=8; guitar S=1/D=2/F=4), `duration` (seconds), and `direction`
(piano=0, guitar down=1/up=-1). Use one entry per piano key, one per guitar chord.
Charts should be time-sorted with a count-in, and avoid same-lane overlapping holds.
Default backing tracks use 100 BPM for piano and 80 BPM for guitar; custom tempos require matching audio.
The host continues its clock silently if a custom chart outlasts the recording.

Audio timing follows [Godot's speaker-aligned playback clock guidance](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html),
including mix timing, output latency compensation, and monotonic progression.

## Checks

Run `godot --headless --path . --script tests/test_rhythm.gd` after importing
the project. Checks cover judgments, piano chords, guitar fret/direction errors,
hold release, both complete charts, zero-input completion, and the scene's input,
pause, reset, replay, and completion flow.

`godot --headless --path . --script tests/test_realtime.gd` also verifies both
phrases against actual audio playback, including preparation, pause and completion (~38 seconds).

Optional visual check: `godot --path . --rendering-method gl_compatibility
--script tests/preview_rhythm.gd` writes preview PNGs under `tests/`.
