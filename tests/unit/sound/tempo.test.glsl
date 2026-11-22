// sound/tempo.glsl: exact steps from the integer sample index, at any point in a film.
#include <sound/tempo.glsl>

void test_beat_step_values() {
    // 120 bpm at 48 kHz: a beat every 24000 samples
    expect_eq(kit_beat_step(0, 48000, 120, 1), 0);
    expect_eq(kit_beat_step(23999, 48000, 120, 1), 0);
    expect_eq(kit_beat_step(24000, 48000, 120, 1), 1);
    expect_eq(kit_beat_step(-1, 48000, 120, 1), -1);
    expect_eq(kit_beat_step(-24000, 48000, 120, 1), -1);
    expect_eq(kit_beat_step(-24001, 48000, 120, 1), -2);
    expect_eq(kit_beat_step(12000, 48000, 120, 4), 2);       // sixteenths
    expect_eq(kit_beat_step(16000, 48000, 120, 3), 2);       // triplets
    expect_near(kit_beat_since(23999, 48000, 120, 1), 23999.0 / 48000.0, 1e-6);
    expect_eq(kit_beat_since(24000, 48000, 120, 1), 0.0);
}

// Against the plain formula, where samp * steps-per-minute still fits in an int.
void test_beat_step_matches_the_formula(float x) {
    int samp = int(floor(mix(-200000.0, 200000.0, x)));
    int rate = 44100, bpm = 97, per = 4;               // 388 steps a minute
    int den = bpm * per, minute = 60 * rate;
    int prod = samp * den;
    int want = prod >= 0 ? prod / minute : -((minute - 1 - prod) / minute);
    expect_eq(kit_beat_step(samp, rate, bpm, per), want);
    float since = kit_beat_since(samp, rate, bpm, per);
    expect_near(since, float(prod - want * minute) / float(den * rate), 1e-6);
}

// Far into a film (hours of samples): steps never go backwards, and the time since the
// step began grows by exactly one sample per sample, or restarts at a new step.
void test_beat_far_into_a_film(float x) {
    int samp = int(floor(mix(0.0, 2.0e9, x)));
    int rate = 48000, bpm = 120, per = 2;
    int s0 = kit_beat_step(samp, rate, bpm, per), s1 = kit_beat_step(samp + 1, rate, bpm, per);
    float t0 = kit_beat_since(samp, rate, bpm, per), t1 = kit_beat_since(samp + 1, rate, bpm, per);
    float len = 60.0 / float(bpm * per);
    expect(t0 >= 0.0 && t0 < len, t0);
    if (s1 == s0) expect_near(t1 - t0, 1.0 / float(rate), 1e-7);
    else expect(s1 == s0 + 1 && t1 < 1.0 / float(rate) + 1e-7, vec2(float(s1 - s0), t1));
    // the step agrees with samp / step length: float(samp) is within 64 samples of samp
    // at 2e9, a few thousandths of a step here
    expect_near(float(s0), float(samp) / float(rate) / len - t0 / len, 0.05);
}

void test_bars() {
    expect_eq(ivec2(kit_beat_bar(0, 4), kit_beat_in_bar(0, 4)), ivec2(0, 0));
    expect_eq(ivec2(kit_beat_bar(7, 4), kit_beat_in_bar(7, 4)), ivec2(1, 3));
    expect_eq(ivec2(kit_beat_bar(-1, 4), kit_beat_in_bar(-1, 4)), ivec2(-1, 3));
    expect_eq(ivec2(kit_beat_bar(-4, 4), kit_beat_in_bar(-4, 4)), ivec2(-1, 0));
    expect_eq(ivec2(kit_beat_bar(-5, 4), kit_beat_in_bar(-5, 4)), ivec2(-2, 3));
    expect_eq(kit_beat_bar(5, 0), 5);                   // per_bar >= 1
}

void test_bar_identity(float x) {
    int step = int(floor(mix(-1000.0, 1000.0, x)));
    int b = kit_beat_bar(step, 16), i = kit_beat_in_bar(step, 16);
    expect_eq(b * 16 + i, step);
    expect(i >= 0 && i < 16, float(i));
}

void test_float_beats() {
    expect_eq(kit_beat(30.0, 120.0), 60.0);
    expect_eq(kit_beat_seconds(0.75, 120.0), 0.375);
    expect_near(kit_beat(kit_beat_seconds(13.0, 97.0), 97.0), 13.0, 1e-5);
}
