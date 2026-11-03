# RhythmPG — woodland combat prototype

Press **F5** to play the complete encounter in `scenes/combat.tscn`. Rowan uses
the supplied warrior sprite and guitar; Lyra uses the mage sprite and piano.
The Hollow Warden uses `Monster_4 SV Battler.png`, against `forest_clearing.png`.
This is a fully 2D scene with a receding painted ground, staggered positions and
sprite scales, contact shadows, foreground foliage, light shafts, and motes.
The supplied battle sheets animate idle, attack, casting, damage, guard, victory,
and defeat poses; packed effect atlases provide impacts, fire, shielding, and healing.

## Playing the encounter

- Click a command or press **1–5**. Healing and tonics then ask for ally **1/2**.
- **Warrior:** hold the displayed **S/D/F** shape for the whole action and strum
  with **Down/Up arrows**. Each action repeats the familiar D D U U D U pattern.
- **Mage:** use **D/F/J/K** for the falling notes, chords, and brief holds.
- Battle performances use **120 BPM**, a **0.65-second pickup**, and one bar,
  taking about **2.65 seconds**. Commands stay in the same lower panel as the
  performance, keeping the battlefield visible. The longer practice charts remain available.
- **P** pauses a performance (focus loss also pauses). **Escape** resolves the
  action at 0% accuracy. It still spends MP and has its baseline effect.
- **F8** switches between combat and Rhythm Lab, starting a fresh encounter on
  return. **R** replays after victory/defeat. A restart button is available during command selection.
- The timing offset set in Rhythm Lab carries into combat for the current game
  session. It is not saved after closing the game.

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

The battle is split into `combat/battle_state.gd` (rules), `combat/combat_scene.gd`
(turn flow and HUD), `combat/combat_rhythm.gd` (compact performance using the same
`RhythmSession` as practice), and actor/stage presentation scripts. Placeholder
music, note samples, and impact audio are generated originally by the included tool.

Run `godot --headless --path . --script tests/test_combat.gd` for combat rules,
all skill paths, full victory through instrument input, real-time audio completion,
revival, replay, defeat, and packed-atlas checks. Render battle previews with
`godot --path . --rendering-method gl_compatibility --script tests/preview_combat.gd`.

## Standalone rhythm practice

Open `project.godot` in Godot 4.7 and press **F6** on `scenes/rhythm_lab.tscn`,
or enter **Rhythm Lab / F8** from combat.
Choose Piano or Guitar, then click **Start phrase**. Listen to four count-in
beats; notes arrive at the white hit line on the following beat.

| Mode | Controls |
| --- | --- |
| Piano / Chordfall | D, F, J, K play the four lanes. Press simultaneous notes together. Hold keys through long tails. |
| Guitar / Strumline | Hold S, D, F chord shapes. DOWN ARROW strums down (`v`); UP ARROW strums up (`^`). Keep the same shape for each three-second bar. |
| Both | P pauses/resumes. Escape or Reset clears the phrase. Start/Restart replays from the beginning. |

The game automatically pauses on focus loss. To resume a sustain, re-hold its
keys while paused, then press P. Timing offset is adjustable from -250 to +250 ms;
positive values accept later input. This setting shifts judgment, not the note
display. Mute preserves the audio clock so silent practice still works.

Guitar runs at a relaxed **80 BPM**, so each four-beat bar lasts exactly **three
seconds**. Hold **S+D → D+F → S+F → S+D**, changing shape once per bar.
The current shape, next shape, and change countdown appear on the left; gold
rings identify the required fret keys. Only strum cues fall toward the hit line.
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
broken holds, stray inputs, maximum combo, and note count. Escape cancels without
emitting a completed result. No combat formulas or game-state dependencies exist.

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
phrases against actual audio playback, including pause and completion (~34 seconds).

Optional visual check: `godot --path . --rendering-method gl_compatibility
--script tests/preview_rhythm.gd` writes preview PNGs under `tests/`.
