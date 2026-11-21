// The mix test's drums (the shot's sound, so they're on the sfx bus): a snare on
// beats 2 and 4 for the first five bars, then a loud kick on every beat for the
// ducking bar (10-12 s), kick and snare together for the loud bar (12-14 s), and one
// last snare with the final note at 14 s.
#include <sound/tempo.glsl>
#include <sound/drum.glsl>

vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    int beat = kit_beat_step(samp, rate, 120, 1);
    float s = 0.0;
    for (int j = 0; j < 2; j++) {   // this beat's hit and the previous one's tail
        int b = beat - j;
        float since = kit_beat_since(samp, rate, 120, 1) + 0.5 * float(j);
        int bar = b / 4;
        if (b < 0) continue;
        if (bar < 5 && b % 2 == 1) s += 0.45 * kit_drum_snare(since, 190.0, 0.25);
        if (bar == 5) s += 0.9 * kit_drum_kick(since, 50.0, 0.45);
        if (bar == 6) s += 0.6 * kit_drum_kick(since, 55.0, 0.35)
                         + (b % 2 == 1 ? 0.5 * kit_drum_snare(since, 200.0, 0.2) : 0.0);
        if (b == 28) s += 0.5 * kit_drum_snare(since, 180.0, 0.3);
    }
    return vec2(s);
}
