// The mix test's music: a plucked arpeggio on eighth notes over a pad, one chord a
// bar (C, Am, F, G, ...) for seven bars at 120 bpm, then one last note at 14 s for
// the effects to ring out on. Each pluck sits somewhere else in the stereo field, so
// the width bar has a side to widen. The drums are the shot's sound (sfx/drums.glsl).
// sound/master.glsl is included here too: it's sound-safe, so CI checks it as music.
#include <sound/envelope.glsl>
#include <sound/note.glsl>
#include <sound/tempo.glsl>
#include <sound/instrument.glsl>
#include <sound/master.glsl>

const int BPM = 120;
const int BARS = 7;

int chord_root(int bar) { return int[4](0, 5, 3, 4)[bar % 4]; }   // I vi IV V

// The pluck starting on eighth step k, `since` seconds in, panned: vec2(left, right).
vec2 pluck(int k, float since) {
    if (k < 0) return vec2(0.0);
    int bar = k / 8;
    float v;
    if (bar < BARS) {
        int i = int[8](0, 1, 2, 3, 2, 1, 2, 1)[k % 8];   // up and down the chord
        v = kit_inst_pluck(since, kit_note_hz(kit_scale_chord(chord_root(bar), i, 60, 0xAB5)), 0.8, 0.6);
    } else if (k == 8 * BARS) {
        v = kit_inst_pluck(since, kit_note_hz(72), 1.2, 0.7);   // the last note
    } else {
        return vec2(0.0);
    }
    float pan = 0.5 + 0.4 * float(int[8](-1, 1, -2, 2, 0, -2, 1, -1)[k % 8]) / 2.0;
    return v * vec2(1.0 - pan, pan);
}

float pad(int bar, float since) {
    if (bar < 0 || bar >= BARS) return 0.0;
    float s = 0.0;
    for (int i = 0; i < 3; i++)
        s += kit_inst_pad(since, kit_note_hz(kit_scale_chord(chord_root(bar), i, 48, 0xAB5)), 1.8, 0.15, 0.4);
    return s / 3.0;
}

vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    int k = kit_beat_step(samp, rate, BPM, 2);       // eighth notes
    float since = kit_beat_since(samp, rate, BPM, 2);
    int bar = k / 8;
    float since_bar = float(k % 8) * 0.25 + since;
    vec2 p = vec2(0.0);
    for (int j = 0; j < 6; j++) p += pluck(k - j, since + 0.25 * float(j));   // and the tails
    float pd = pad(bar, since_bar) + pad(bar - 1, since_bar + 2.0);
    return 0.35 * p + vec2(0.18 * pd);
}
