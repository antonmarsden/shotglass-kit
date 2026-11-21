// The sound library's test music: every function in sound/ is called here, and every
// sound/ file is included, so CI checks each one as a sound shader. Four bars of C
// major at 120 bpm (pad, bass and kick, a sixteenth-note arpeggio, a melody, offbeat
// ticks), then a held chord that rings out.
#include <sound/envelope.glsl>
#include <sound/note.glsl>
#include <sound/tempo.glsl>

const int BPM = 120;
const float BPM_F = 120.0;
const int BARS = 4;   // then the closing chord

// A sine with its phase from a small time since the note began (see tempo.glsl).
float osc(float hz, float since) { return sin(6.28318531 * fract(hz * since)); }
float voice(float hz, float since) {
    return osc(hz, since) + 0.3 * osc(2.0 * hz, since) + 0.12 * osc(3.0 * hz, since);
}

// The chord of half-bar h (0..7), as an arpeggio note: i = 0, 1, 2, ... climbs.
int arp_note(int h, int i) {
    if (h == 0) return kit_chord_major(i, 60);   // C
    if (h == 1) return kit_chord_min7(i, 57);    // Am7
    if (h == 2) return kit_chord_maj7(i, 53);    // Fmaj7
    if (h == 3) return kit_chord_minor(i, 50);   // Dm
    if (h == 4) return kit_chord_sus4(i, 55);    // Gsus4
    if (h == 5) return kit_chord_dom7(i, 55);    // G7
    if (h == 6) return kit_chord_dim(i, 59);     // Bdim
    return kit_chord_aug(i, 60);                 // Caug, leading back to C
}

// A melody note at degree d in a scale that suits half-bar h's chord.
int melody_note(int h, int d) {
    if (h == 0) return kit_scale_major(d, 72);
    if (h == 1) return kit_scale_minor(d, 69);
    if (h == 2) return kit_scale_note(d, 65, 0xAD5);   // F lydian: 0 2 4 6 7 9 11
    if (h == 3) return kit_scale_dorian(d, 62);
    if (h == 4) return kit_scale_pentatonic(d, 67);
    if (h == 5) return kit_scale_blues(d, 67);
    if (h == 6) return kit_scale_harmonic_minor(d, 69);
    return kit_scale_minor_pentatonic(d, 72);
}

// The pad of bar b: the diatonic triad on I, vi, IV, V of C major, then a Csus2.
float pad(int b, float since) {
    if (b < 0) return 0.0;
    float s = 0.0;
    for (int i = 0; i < 3; i++) {
        int n = b < BARS ? kit_scale_chord(int[4](0, 5, 3, 4)[b], i, 48, 0xAB5)
                         : kit_chord_sus2(i, 48);
        // two voices, one slightly sharp (float notes detune)
        s += osc(kit_note_hz(n), since) + osc(kit_note_hz(float(n) + 0.08), since);
    }
    float held = b < BARS ? kit_beat_seconds(3.8, BPM_F) : kit_beat_seconds(3.0, BPM_F);
    float release = b < BARS ? 0.4 : 1.5;
    return s * kit_env_adsr(since, held, 0.08, 0.6, 0.6, release) / 6.0;
}

// Sixteenth-note arpeggio step k (0 8 16ths per half-bar, up and down the chord).
float arp(int k, float since) {
    if (k < 0 || k >= BARS * 16) return 0.0;
    int h = kit_beat_bar(k, 8);
    int up = kit_beat_in_bar(k, 8);
    int i = up < 5 ? up : 8 - up;   // 0 1 2 3 4 3 2 1
    return voice(kit_note_hz(arp_note(h, i)), since) * kit_env_ar(since, 0.003, 0.22);
}

// Eighth-note melody step k: a rest on the last eighth of every other half-bar.
float melody(int k, float since) {
    if (k < 0 || k >= BARS * 8) return 0.0;
    int h = kit_beat_bar(k, 4);
    int j = kit_beat_in_bar(k, 4);
    if (j == 3 && h % 2 == 1) return 0.0;
    int d = int[4](4, 2, 3, 0)[j] - (h % 3);
    float held = kit_beat_seconds(0.4, BPM_F);
    return voice(kit_note_hz(melody_note(h, d)), since)
         * kit_env_adsr(since, held, 0.01, 0.1, 0.7, 0.12);
}

vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    float beat_len = kit_beat_seconds(1.0, BPM_F);

    int beat = kit_beat_step(samp, rate, BPM, 1);
    float since_beat = kit_beat_since(samp, rate, BPM, 1);
    int bar = kit_beat_bar(beat, 4);
    float since_bar = float(kit_beat_in_bar(beat, 4)) * beat_len + since_beat;
    float bar_len = 4.0 * beat_len;

    // pad: this bar's chord, and the previous one's release; the last chord rings on
    float p;
    if (bar <= BARS) p = pad(bar, since_bar) + pad(bar - 1, since_bar + bar_len);
    else p = pad(BARS, since_bar + float(bar - BARS) * bar_len);

    // bass on every beat (the chord's root, two octaves down), kick on beats 1 and 3,
    // and one last low C under the closing chord
    float bass = 0.0, kick = 0.0, since_hit = since_beat;
    if (bar < BARS) {
        int root = kit_scale_chord(int[4](0, 5, 3, 4)[bar], 0, 36, 0xAB5);
        bass = voice(kit_note_hz(root), since_beat) * kit_env_ar(since_beat, 0.005, 0.45);
    } else {
        since_hit = since_bar + float(bar - BARS) * bar_len;   // since the closing chord
        bass = voice(kit_note_hz(36), since_hit) * kit_env_ar(since_hit, 0.005, 2.5);
    }
    if (beat % 2 == 0 || bar >= BARS) {
        // pitch glides from 150 Hz down to the note nearest 50 Hz (G1, 49 Hz);
        // the phase is the glide's integral, so the sweep has no jumps
        float lo = kit_note_hz(floor(kit_hz_note(50.0) + 0.5)), hi = 150.0, tau = 0.03;
        float phase = lo * since_hit + (hi - lo) * tau * (1.0 - exp(-since_hit / tau));
        kick = sin(6.28318531 * fract(phase)) * kit_env_ar(since_hit, 0.001, 0.35);
    }

    // arpeggio and melody: this step plus the previous one's tail, so nothing clicks
    int k16 = kit_beat_step(samp, rate, BPM, 4);
    float s16 = kit_beat_since(samp, rate, BPM, 4);
    float a = arp(k16, s16) + arp(k16 - 1, s16 + 0.25 * beat_len);
    int k8 = kit_beat_step(samp, rate, BPM, 2);
    float s8 = kit_beat_since(samp, rate, BPM, 2);
    float m = melody(k8, s8) + melody(k8 - 1, s8 + 0.5 * beat_len);

    // ticks on the offbeat eighths
    float tick = 0.0;
    if (k8 % 2 == 1 && bar < BARS)
        tick = (osc(3170.0, s8) + osc(3730.0, s8)) * kit_env_ar(s8, 0.001, 0.04);

    // the arpeggio drifts across the stereo field once every two bars
    float pan = 0.5 + 0.35 * sin(6.28318531 * kit_beat(time, BPM_F) / 8.0);

    vec2 s = vec2(0.2 * p + 0.22 * bass + 0.4 * kick + 0.1 * m)
           + 0.07 * a * vec2(1.0 - pan, pan)
           + 0.05 * tick * vec2(0.4, 0.6);
    return s;
}
