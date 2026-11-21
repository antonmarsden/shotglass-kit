// The instruments' test music: a short phrase on each instrument in turn, one bar
// each at 120 bpm (the pad gets two), then two bars with all of them together and a
// bar for the tails to ring out:
//   bar 0 pluck, 1 bell, 2 electric piano, 3-4 pad, 5 kick, 6 snare, 7 hat, 8-9 all.
// Every note is scheduled on the eighth-note grid; each part adds the notes of the
// last few steps too, so a note keeps ringing after the next one starts.
#include <sound/envelope.glsl>
#include <sound/note.glsl>
#include <sound/tempo.glsl>
#include <sound/instrument.glsl>
#include <sound/drum.glsl>

const int BPM = 120;
const float EIGHTH = 0.25;   // seconds

// Each part: the note (if any) that starts on eighth-note step k, at `since` seconds
// after it began. Steps count from 0 at the start of the film, 8 to a bar.

float pluck(int k, float since) {
    if (k >= 0 && k < 8)   // a pentatonic run, up and back
        return kit_inst_pluck(since, kit_note_hz(kit_scale_pentatonic(int[8](0, 2, 4, 7, 5, 4, 2, 4)[k], 60)), 0.9, 0.7);
    if (k >= 64 && k < 80) {   // in the groove: a softer, darker line
        int d = int[8](0, 0, 4, 3, 2, 0, 1, 2)[k % 8] - (k >= 72 ? 1 : 0);
        return 0.8 * kit_inst_pluck(since, kit_note_hz(kit_scale_pentatonic(d, 57)), 1.1, 0.3);
    }
    return 0.0;
}

float bell(int k, float since) {
    if (k >= 8 && k < 16 && k % 2 == 0)   // four quarter notes
        return kit_inst_bell(since, kit_note_hz(kit_scale_major(int[4](7, 4, 5, 9)[(k - 8) / 2], 72)), 1.6, 3.0);
    if (k == 64 || k == 72)
        return 0.6 * kit_inst_bell(since, kit_note_hz(k == 64 ? 81 : 79), 2.0, 2.0);
    return 0.0;
}

float epiano(int k, float since) {
    float s = 0.0;
    if (k == 16 || k == 20) {   // two held chords: Fmaj7, then G (three notes each)
        for (int i = 0; i < 3; i++) {
            int n = k == 16 ? kit_chord_maj7(i + 1, 53) : kit_chord_major(i, 55);
            s += kit_inst_epiano(since, kit_note_hz(n), 0.9, 0.6);
        }
        return s / 3.0;
    }
    if (k >= 64 && k < 80 && k % 4 == 3) {   // offbeat stabs in the groove
        for (int i = 0; i < 3; i++)
            s += kit_inst_epiano(since, kit_note_hz(kit_chord_min7(i + 1, k < 72 ? 57 : 50)), 0.12, 0.9);
        return 0.7 * s / 3.0;
    }
    return 0.0;
}

// The pad's chords are long, so they're given by start step directly.
float pad(int k, float since) {
    float s = 0.0;
    if (k == 24) {   // A minor, bars 3-4
        for (int i = 0; i < 3; i++)
            s += kit_inst_pad(since, kit_note_hz(kit_chord_minor(i, 57)), 3.2, 0.6, 1.2);
        return s / 2.0;
    }
    if (k == 64) {   // under the groove, ringing out at the end
        for (int i = 0; i < 4; i++)
            s += kit_inst_pad(since, kit_note_hz(kit_chord_min7(i, 45)), 3.6, 0.3, 1.8);
        return 0.6 * s / 2.0;
    }
    return 0.0;
}

float kick(int k, float since) {
    if (k >= 40 && k < 48 && k % 2 == 0) return kit_drum_kick(since, 50.0, 0.4);
    int j = k % 8;
    if (k >= 64 && k < 80 && (j == 0 || j == 3 || j == 4)) return kit_drum_kick(since, 48.0, 0.35);
    return 0.0;
}

float snare(int k, float since) {
    int j = k % 8;
    if (k >= 48 && k < 56) {
        if (j == 2 || j == 6) return kit_drum_snare(since, 190.0, 0.25);
        if (j == 7) return 0.35 * kit_drum_snare(since, 190.0, 0.12);   // a ghost note
    }
    if (k >= 64 && k < 80 && (j == 2 || j == 6)) return kit_drum_snare(since, 180.0, 0.3);
    return 0.0;
}

float hat(int k, float since) {
    int j = k % 8;
    bool open = j == 7;
    if ((k >= 56 && k < 64) || (k >= 64 && k < 80))
        return (open ? 0.8 : 1.0 - 0.3 * float(j % 2)) * kit_drum_hat(since, 2000.0, open ? 0.35 : 0.06);
    return 0.0;
}

vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    int k = kit_beat_step(samp, rate, BPM, 2);
    float s = kit_beat_since(samp, rate, BPM, 2);

    // this step's note plus the tails of earlier ones (longest note / 0.25 s steps)
    float pl = 0.0, be = 0.0, ep = 0.0, ki = 0.0, sn = 0.0, ha = 0.0, pa = 0.0;
    for (int j = 0; j < 5; j++) pl += pluck(k - j, s + float(j) * EIGHTH);
    for (int j = 0; j < 9; j++) be += bell(k - j, s + float(j) * EIGHTH);
    for (int j = 0; j < 5; j++) ep += epiano(k - j, s + float(j) * EIGHTH);
    for (int j = 0; j < 2; j++) ki += kick(k - j, s + float(j) * EIGHTH);
    for (int j = 0; j < 2; j++) sn += snare(k - j, s + float(j) * EIGHTH);
    for (int j = 0; j < 2; j++) ha += hat(k - j, s + float(j) * EIGHTH);
    for (int start = 24; start <= 64; start += 40)   // the two pad chords
        if (k >= start) pa += pad(start, s + float(k - start) * EIGHTH);

    vec2 out_ = vec2(0.0);
    out_ += 0.5 * pl * vec2(0.65, 0.35);
    out_ += 0.3 * be * vec2(0.4, 0.6);
    out_ += 0.35 * ep;
    out_ += 0.55 * pa * vec2(0.55, 0.45);
    out_ += 0.5 * ki;
    out_ += 0.6 * sn * vec2(0.48, 0.52);
    out_ += 0.4 * ha * vec2(0.35, 0.65);
    return out_;
}
