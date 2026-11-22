// sound/drum.glsl and sound/instrument.glsl: every hit and note is silent before it
// starts and from its documented end, starts from 0 (no click), stays finite and bounded.
#include <sound/drum.glsl>
#include <sound/instrument.glsl>

// Voice k at time t, and when it must be silent from.
float voice(int k, float t) {
    if (k == 0) return kit_drum_kick(t, 50.0, 0.4);
    if (k == 1) return kit_drum_snare(t, 190.0, 0.25);
    if (k == 2) return kit_drum_hat(t, 2000.0, 0.06);
    if (k == 3) return kit_inst_pluck(t, 330.0, 1.2, 0.6);
    if (k == 4) return kit_inst_bell(t, 660.0, 2.5, 3.0);
    if (k == 5) return kit_inst_epiano(t, 262.0, 0.8, 0.5);
    return kit_inst_pad(t, 220.0, 1.0, 0.3, 0.6);
}
float silent_from(int k) {
    float ends[7] = float[7](0.4, 0.25, 0.06, 1.2, 2.5, 0.8 + 0.25, 1.0 + 0.6);
    return ends[k];
}
const int VOICES = 7;

// samples: 16384
void test_bounded_and_finite(float x) {
    for (int k = 0; k < VOICES; k++) {
        float t = x * silent_from(k);
        float v = voice(k, t);
        expect_finite(v);
        expect(abs(v) <= 1.0, vec2(float(k), v));
    }
}

void test_silent_before_and_after() {
    for (int k = 0; k < VOICES; k++) {
        expect_eq(voice(k, -0.001), 0.0);
        expect_eq(voice(k, -10.0), 0.0);
        expect_eq(voice(k, silent_from(k)), 0.0);
        expect_eq(voice(k, silent_from(k) + 0.01), 0.0);
        expect_eq(voice(k, 59.0), 0.0);
    }
}

// No click in: the first half millisecond stays small and starts at 0.
void test_starts_from_zero(float x) {
    for (int k = 0; k < VOICES; k++) {
        expect_near(voice(k, 0.0), 0.0, 1e-6);
        expect(abs(voice(k, x * 2e-5)) <= 0.05, vec2(float(k), voice(k, x * 2e-5)));
    }
}

// Each note is a pure function of t: computing it twice gives the same bits.
void test_deterministic(float x) {
    for (int k = 0; k < VOICES; k++) {
        float t = x * silent_from(k);
        expect_eq(voice(k, t), voice(k, t));
    }
}
