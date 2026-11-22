// sound/envelope.glsl: silent before the note, peak 1, no jumps, true silence at the
// documented end.
#include <sound/envelope.glsl>

void test_ar_values() {
    expect_eq(kit_env_ar(-0.1, 0.01, 0.3), 0.0);
    expect_eq(kit_env_ar(0.0, 0.01, 0.3), 0.0);
    expect_near(kit_env_ar(0.005, 0.01, 0.3), 0.5, 1e-6);
    expect_eq(kit_env_ar(0.01, 0.01, 0.3), 1.0);              // the peak
    expect_eq(kit_env_ar(0.31, 0.01, 0.3), 0.0);              // silent from attack + release
    expect_eq(kit_env_ar(5.0, 0.01, 0.3), 0.0);
    expect_eq(kit_env_ar(0.0, 0.0, 0.3), 1.0);                // instant start
    expect_eq(kit_env_ar(0.1, 0.0, 0.0), 0.0);                // release 0 cuts off
}

void test_ar_range_and_continuity(float x) {
    float t = mix(-0.05, 0.4, x), h = 1e-4;
    float v = kit_env_ar(t, 0.01, 0.3);
    expect(v >= 0.0 && v <= 1.0, v);
    // slope at most 1/attack: no jumps
    expect(abs(kit_env_ar(t + h, 0.01, 0.3) - v) <= h / 0.01 + 1e-5, v);
}

void test_adsr_values() {
    float held = 0.4, a = 0.01, d = 0.15, s = 0.6, r = 0.3;
    expect_eq(kit_env_adsr(-0.1, held, a, d, s, r), 0.0);
    expect_eq(kit_env_adsr(a, held, a, d, s, r), 1.0);
    expect_near(kit_env_adsr(a + d, held, a, d, s, r), s, 1e-6);   // decayed to sustain
    expect_near(kit_env_adsr(0.3, held, a, d, s, r), s, 1e-6);     // holding
    expect_eq(kit_env_adsr(held + r, held, a, d, s, r), 0.0);      // released
    expect_eq(kit_env_adsr(9.0, held, a, d, s, r), 0.0);
    // sustain is clamped to 0..1
    expect_near(kit_env_adsr(0.3, held, a, d, 3.0, r), 1.0, 1e-6);
    expect_near(kit_env_adsr(0.3, held, a, d, -1.0, r), 0.0, 1e-6);
}

// Released from wherever it is, even mid-attack: no jump at the release.
void test_adsr_releases_without_a_jump(vec2 c) {
    float held = mix(0.0, 0.5, c.x), a = 0.05, d = 0.15, s = mix(0.0, 1.0, c.y), r = 0.3;
    float before = kit_env_adsr(held - 1e-5, held, a, d, s, r);
    float after = kit_env_adsr(held + 1e-5, held, a, d, s, r);
    if (held > 1e-4) expect_near(after, before, 1e-3);
    float v = kit_env_adsr(held + 0.5 * r, held, a, d, s, r);
    expect(v >= 0.0 && v <= 1.0, v);
}
