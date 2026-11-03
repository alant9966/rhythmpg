"""Generate original, dependency-free practice audio. Run from any directory."""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
BEAT = 0.6
OUT = Path(__file__).resolve().parents[1] / "audio"
OUT.mkdir(exist_ok=True)


def tone(samples, start, frequency, duration, volume, guitar=False):
    offset = int(start * RATE)
    for i in range(int(duration * RATE)):
        if offset + i >= len(samples):
            break
        t = i / RATE
        attack = min(t / 0.006, 1)
        release = min((duration - t) / 0.04, 1)
        decay = math.exp(-t * (5 if guitar else 3))
        value = math.sin(math.tau * frequency * t)
        value += (0.35 if guitar else 0.15) * math.sin(math.tau * frequency * 2 * t)
        value += 0.08 * math.sin(math.tau * frequency * 3 * t)
        samples[offset + i] += value * attack * release * decay * volume


def write(name, samples):
    with wave.open(str(OUT / name), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


for instrument in ("piano", "guitar"):
    beat_seconds = 0.75 if instrument == "guitar" else BEAT
    beat_count = 21 if instrument == "guitar" else 29
    track = [0.0] * int(beat_count * beat_seconds * RATE)
    for beat in range(beat_count - 1):
        # Audible four-beat count-in followed by a quiet pulse throughout.
        tone(track, beat * beat_seconds, 1100 if beat % 4 == 0 else 750, 0.055, 0.23 if beat < 4 else 0.11)
        if beat >= 4:
            roots = [130.8128, 110, 87.3071, 97.9989]
            root = roots[((beat - 4) // 4) % 4]
            tone(track, beat * beat_seconds, root, 0.40, 0.11, instrument == "guitar")
            if beat % 4 == 0:
                for ratio in (2, 2.5, 3):
                    tone(track, beat * beat_seconds, root * ratio, 1.5, 0.045, instrument == "guitar")
    write(f"{instrument}_practice.wav", track)
    for lane, freq in enumerate([261.6256, 329.6276, 391.9954, 523.2511]):
        sound = [0.0] * RATE
        tone(sound, 0, freq, 1.0, 0.24, instrument == "guitar")
        write(f"{instrument}_{lane}.wav", sound)

print("Generated piano/guitar backing tracks and note samples in", OUT)

# Short battle performances: a 0.65-second pickup and one 120 BPM bar.
for instrument in ("piano", "guitar"):
    track = [0.0] * int(3.15 * RATE)
    tone(track, 0.04, 880, 0.06, 0.16)
    for beat in range(5):
        start = 0.65 + beat * 0.5
        tone(track, start, 1000 if beat == 0 else 700, 0.04, 0.13)
        if beat < 4:
            tone(track, start, 130.8128, 0.4, 0.09, instrument == "guitar")
    for freq in (261.6256, 329.6276, 391.9954):
        tone(track, 0.65, freq, 1.7, 0.035, instrument == "guitar")
    write(f"combat_{instrument}.wav", track)

# A quiet original sixteen-second battle loop, with no third-party music.
track = [0.0] * int(16 * RATE)
for beat in range(32):
    root = [110, 130.8128, 97.9989, 146.8324][(beat // 8) % 4]
    tone(track, beat * 0.5, root, 0.46, 0.13, True)
    for subdivision in range(2):
        ratio = [2, 3, 2.4, 3][(beat * 2 + subdivision) % 4]
        tone(track, beat * 0.5 + subdivision * 0.25, root * ratio, 0.23, 0.05)
write("battle_theme.wav", track)
impact_samples = [0.0] * int(0.3 * RATE)
for freq in (65, 98, 155, 230):
    tone(impact_samples, 0, freq, 0.28, 0.18, True)
write("battle_impact.wav", impact_samples)
print("Generated short combat phrases, battle loop, and impact sound")
