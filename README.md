# RhythmPG — woodland combat prototype

Press **F5** to play the complete encounter in `scenes/combat.tscn`. Rowan uses
the supplied warrior sprite and guitar; Lyra uses the mage sprite and piano;
Maro uses the fighter sprite and timpani.
The Hollow Warden uses `Monster_4 SV Battler.png`, against `forest_clearing.png`.
This is a fully 2D scene with a receding painted ground, staggered positions and
sprite scales, contact shadows, foreground foliage, light shafts, and motes.
The supplied battle sheets animate idle, attack, casting, damage, guard, victory,
and defeat poses; packed effect atlases provide impacts, fire, shielding, and healing.

## Playing the encounter

- **Esc** opens a global pause menu in combat and practice. Resume, save/load,
  edit keybindings, read the rhythm guide, or exit from this menu. **P** is a
  second pause shortcut by default. The scene, enemy timers, animations, and
  audio all freeze. Resume includes a 0.85-second countdown to ready your hands.
- Click a command or press **1–5**. Healing and tonics then ask for ally **1/2/3**.
- **Plan the whole party first:** choose Rowan's action and play his rhythm, then
  do the same for Lyra and Maro. The scores and targets are recorded; attacks,
  healing, guarding, MP costs, and item consumption wait until planning is complete.
  The party then executes its queue from **highest speed to lowest**, followed
  by the enemy response. Speed ties use stable party order. The queue HUD shows
  selected skills, scores, speed, and the actor currently planning or acting.
- **Warrior:** hold the displayed **S/D/F** shape for the whole action and strum
  with **Down/Up arrows**. Combat chooses among six strumming patterns; follow
  the actual arrow sequence shown for the current action.
- **Mage:** use **D/F/J/K** for the falling notes, chords, and brief holds.
- **Percussionist:** **left-click** the numbered circles in order. Click when
  the shrinking ring reaches the circle edge. The next target is gold.
- Combat performances open a **large screen-filling overlay**, dimming the battle
  behind it. Large lanes, arrows, highlighted frets, and a clear hit line replace
  the former command-panel layout. The overlay scales to fit the viewport.
  Current timing stays the same: a two-second preparation (an empty playfield for timpani), **120 BPM**, a
  **0.65-second pickup**, and one bar (**2.65 seconds** of performance).
  Rhythm Lab retains its one-second empty opening and longer practice charts.
- Focus loss also opens global pause. **Backspace** deliberately resolves a
  combat performance at 0% accuracy; the action spends its turn and MP but has
  **no effect**. Esc always pauses without forfeiting. Backspace also returns from ally
  targeting and resets a practice phrase.
- **F8** opens Rhythm Lab from combat. Its persistent **Return to battle** button
  or the same shortcut restores the last command-selection point with HP, MP,
  enemy status, items, and round preserved. Opening the lab directly returns to
  a fresh encounter. **R** replays after victory/defeat.
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

Combat saves capture the **latest planning point**, including HP/MP, shields,
guard, enemy HP/statuses, round, tonics, completed queued selections, targets,
rhythm scores, and performance history. Saving during an unfinished rhythm or
queue animation restores that planning point. Completed selections stay queued;
the unfinished selection is replayed. This prevents duplicate damage or item
costs from partially completed batches. Finished battles can
also be saved. Practice saves restore the selected instrument, ready to start
a new phrase; they do not resume a partially completed practice chart.
Earlier two-member combat saves add Maro when loaded.

### Example combat rules

| Character | HP / MP | ATK / MAG / DEF / SPD | Actions |
| --- | --- | --- | --- |
| Rowan, warrior / guitar | 180 / 24 | 24 / 8 / 14 / 15 | Downstroke; Rending Riff (6 MP); Iron Chorus (4 MP) |
| Lyra, mage / piano | 124 / 32 | 10 / 30 / 8 / 12 | Spark; Flame Sonata (8 MP); Mending Chord (7 MP) |
| Maro, percussionist / timpani | 148 / 28 | 28 / 14 / 12 / 10 | Drumstrike; Thunder Roll (8 MP); Rallying Beat (6 MP) |
| Hollow Warden | 650 HP | ATK 39 / DEF 12 / RES 10 / SPD 10 | Telegraphed Heavy Cleave; every third round, Dissonant Wave hits the party |

Planning proceeds in party order, skipping fallen allies. Action resolution uses
the party's speed stats (normally Rowan 15 → Lyra 12 → Maro 10), then the Warden responds.
Heroes recover 2 MP each at the start of the next planning round, once per round.
**Guard / Recover also launches the character's
instrument minigame**; its protection and MP recovery depend on accuracy.
Two shared Field Tonics restore 65 HP or revive a fallen ally with 55 HP.
Queued tonics reserve shared stock so two allies cannot promise the same item.
Items and MP are spent once, when the action executes. A revived ally rejoins
planning next round. Victory cancels remaining actions without charging them.
Perfect expose, shielding, healing, and guard take effect in execution order,
so a faster character can set up a slower ally's attack. Existing saves from
the old turn system remain loadable; already-completed actors are not replayed.

**0% accuracy misses:** no damage, healing, shield, guard, MP recovery, or new
status effects. The skill still spends its turn and MP. Tonics remain usable
without a rhythm performance. **Partial accuracy scales the action linearly**.
Normal full damage is `2 × max(1, power + offensive stat - enemy defense)`;
actual damage is that value times normalized accuracy (0–1), rounded to an
integer, with at least 1 damage for a positive score. Existing expose multiplies
damage afterward. Exactly **100%** adds a skill-specific bonus; 99% does not.

| Skill | Normal potency at full accuracy | Extra effect at exactly 100% |
| --- | --- | --- |
| Downstroke | 72 damage | Critical ×1.5: 108 damage |
| Spark | 84 magic damage | Critical ×1.5: 126 damage |
| Rending Riff | 112 damage | Expose: +25% incoming damage for 2 enemy turns |
| Flame Sonata | 130 magic damage | Burn: 18 HP at the start of each of 2 enemy turns |
| Iron Chorus | 34 shield HP for each living ally | ×1.5 shield potency: 51 HP |
| Mending Chord | 80 HP to one living ally | Also restore 6 MP to that ally |
| Drumstrike | 80 damage | Critical ×1.5: 120 damage |
| Thunder Roll | 116 damage | Stagger: skip the Warden’s next response |
| Rallying Beat | 4 MP restored to each living ally | Also heal each living ally by 20 HP |
| Guard / Recover | 75% next-hit reduction and up to 4 MP, scaled by accuracy | Fully block the next hit and recover up to 8 MP |

For example, a 50% Downstroke deals 36 damage; a 50% guard reduces the next hit
by 37.5%. Guard is consumed by the next incoming hit, including a party-wide
attack. Shields absorb the remaining damage. HP/MP recovery is capped at the
character's maximum. A burn kill prevents that enemy turn's attack. Partial
Rending Riff and Flame Sonata do not apply expose/burn; those are perfect bonuses.

### Beatmap variety

`combat/combat_beatmaps.gd` supplies **six distinct short maps per instrument**.
Each action, including guard, draws a randomized map from its instrument's
shuffle bag: all six appear before the bag refills, and the first map of a new
bag cannot repeat the previous map. Guitar keeps one chord shape through the
action while varying downstrokes, alternating eighths, folk, island, and
syncopated patterns. Piano varies rising/falling phrases, repeated notes,
arpeggios, chord pulses, and brief holds. Timpani varies both the placement and
timing of six hits across patterns such as crescents, zigzags, and orbits. The
overlay shows the current map's
name, actual strum pattern, and the skill's perfect bonus. Tempo and phrase
length are unchanged; the longer Rhythm Lab teaching charts remain available.

The always-running `global/game_shell.gd` autoload owns pause, controls, settings,
and save/load. The battle is split into `combat/battle_state.gd` (rules), `combat/combat_scene.gd`
(turn flow and HUD), `combat/combat_rhythm.gd` (compact performance using the same
`RhythmSession` as practice), `combat/combat_rhythm_view.gd` (large overlay), and
actor/stage presentation scripts. The overlay and Rhythm Lab share presentation
styles in `rhythm/rhythm_theme.gd`. Placeholder
music, note samples, and impact audio are generated originally by the included tool.

Run `godot --headless --path . --script tests/test_combat.gd` for combat rules,
all skill paths, full victory through instrument input, real-time audio completion,
revival, replay, defeat, and packed-atlas checks. Render battle previews with
`godot --path . --rendering-method gl_compatibility --script tests/preview_combat.gd`.

`godot --headless --path . --script tests/test_combat_accuracy.gd` covers zero
effects, 1–99% damage scaling, strict perfect bonuses, guard consumption, all
twelve perfectly playable keyboard maps, and shuffle-bag coverage/repeat prevention.
`tests/preview_combat_rework.gd` renders variation, miss, perfect, and guard states.

`tests/test_action_queue.gd` checks deferred effects, speed changes and ties,
stored rhythm scores, shared-item reservation, round recovery, fallen/revived
actors, early victory, pause, save/load, legacy-save migration, and Lab return.
Run with `godot --headless --path . --script tests/test_action_queue.gd`.
`tests/preview_action_queue.gd` renders planning and a full speed-ordered round.

Run `godot --headless --path . --script tests/test_shell.gd` for global pause,
resume countdown, preparation, rebinding persistence/conflicts, slot creation,
overwrite, load, validation, and paused enemy/rhythm timing. It uses slots 1/2;
run it with an isolated user-data directory when preserving personal saves.
`tests/preview_pause.gd` renders the menu pages and empty rhythm opening.

`tests/test_rhythm_ui.gd` checks overlay coverage, pause above the performance,
return navigation during practice, preserved battle progress, and standalone
lab navigation. Run it with `godot --headless --path . --script tests/test_rhythm_ui.gd`.

Run `godot --headless --path . --script tests/test_timpani.gd` to check
all six circle maps, mouse input, shuffled patterns, a full three-hero round,
and compatibility with two-hero saves. `tests/preview_timpani.gd` renders the
three-hero formation, combat circles, and Rhythm Lab.

## Standalone rhythm practice

Open `project.godot` in Godot 4.7 and press **F6** on `scenes/rhythm_lab.tscn`,
or enter **Rhythm Lab / F8** from combat.
Choose Piano, Guitar, or Timpani, then click **Start phrase**. Listen to four
count-in beats. Piano and guitar notes arrive at the hit line on the following
beat; timpani circles use shrinking timing rings.
The lab uses the battle's forest backdrop, gold trim, and dark panels. The
**Return to battle** button stays available at the top right while practicing.

| Mode | Controls |
| --- | --- |
| Piano / Chordfall | D, F, J, K play the four lanes. Press simultaneous notes together. Hold keys through long tails. |
| Guitar / Strumline | Hold S, D, F chord shapes. DOWN ARROW strums down (`v`); UP ARROW strums up (`^`). Keep the same shape for each three-second bar. |
| Timpani / CircleStrike | Left-click the numbered circles in order as their approach rings reach the target. The opening pattern varies each run. |
| All modes | Esc or P opens global pause. Backspace or Reset clears the phrase. Start/Restart replays from the beginning. |

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
- `rhythm/practice_charts.gd`: 100 BPM piano and timpani charts and 80 BPM guitar charts, each with
  a four-beat lead-in; guitar also defines three-second chord blocks.
- `rhythm/rhythm_lab.gd`: visual host, keyboard and mouse input, audio clock, test controls.
- `scenes/rhythm_lab.tscn`: independently instantiable practice scene.
- `audio/`: original synthesized placeholder backing tracks and note samples.
  Python is **not** required to play. `python tools/generate_practice_audio.py`
  regenerates those assets using only Python's standard library.

To integrate later, instantiate the scene, connect `performance_finished`, and
call `start_performance("piano")`, `start_performance("guitar")`, or
`start_performance("timpani")`. The signal
returns an instrument ID, normalized `accuracy` (0–1), perfect/good/miss counts,
broken holds, stray inputs, maximum combo, and note count. Backspace cancels practice
without emitting a completed result; Esc opens pause. No combat formulas exist in the rhythm scorer.

Custom charts can be supplied as the second argument and a matching non-looping
`AudioStream` as the third. Each chart entry contains `time` (seconds from audio
start), `mask` (piano D=1/F=2/J=4/K=8; guitar S=1/D=2/F=4), `duration` (seconds), and `direction`
(piano=0, guitar down=1/up=-1). Use one entry per piano key, guitar strum, or timpani circle. For timpani, also
set `position` to a normalized Vector2 inside the play area.
Charts should be time-sorted with a count-in, and avoid same-lane overlapping holds.
Default backing tracks use 100 BPM for piano and timpani, and 80 BPM for guitar; custom tempos require matching audio.
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
