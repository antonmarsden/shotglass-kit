// sound/master.glsl: stereo width, ducking and the soft clip.
#include <sound/master.glsl>

void test_width(vec2 c) {
    vec2 s = c * 2.0 - 1.0;
    float mid = s.x + s.y;
    for (int i = 0; i < 5; i++) {
        float w = 0.5 * float(i);
        vec2 o = kit_width(s, w);
        expect_near(o.x + o.y, mid, 1e-6);                        // the mid is kept
        expect_near(o.x - o.y, (s.x - s.y) * w, 1e-6);            // the side scaled
    }
    expect_near(kit_width(s, 1.0), s, 1e-6);
    expect_near(kit_width(s, 5.0), kit_width(s, 2.0), 1e-6);      // clamped to 0..2
    vec2 m = kit_width(s, 0.0);
    expect_eq(m.x, m.y);                                          // mono
}

void test_duck(float x) {
    float level = x;
    float g = kit_duck(level, 0.12, 0.35, 0.7);
    expect(g >= 0.3 - 1e-6 && g <= 1.0, g);
    expect(kit_duck(level + 1e-3, 0.12, 0.35, 0.7) <= g + 1e-7, g);   // louder never raises it
}

void test_duck_values() {
    expect_eq(kit_duck(0.0, 0.12, 0.35, 0.7), 1.0);
    expect_near(kit_duck(0.5, 0.12, 0.35, 0.7), 0.3, 1e-6);
    expect_near(kit_duck(0.5, 0.12, 0.35, 1.0), 0.0, 1e-6);
    expect_eq(kit_duck(0.5, 0.12, 0.35, 0.0), 1.0);
    expect_near(kit_duck(0.5, 0.2, 0.2, 0.7), 0.3, 1e-6);           // hi <= lo: a step
}

void test_soft_clip(float x) {
    float s = mix(-20.0, 20.0, x), c = 0.9;
    float y = kit_soft_clip(s, c);
    expect_finite(y);
    expect(abs(y) <= c, y);
    expect_eq(kit_soft_clip(-s, c), -y);                            // odd: no DC offset
    if (abs(s) <= 0.45) expect_eq(y, s);                            // untouched below the knee
    expect(kit_soft_clip(s + 1e-3, c) >= y, y);                     // monotonic
    vec2 st = kit_soft_clip(vec2(s, -0.5 * s), c);
    expect_eq(st, vec2(y, kit_soft_clip(-0.5 * s, c)));
}

// Smooth at the knee: the slope just above it is still 1.
void test_soft_clip_knee() {
    float c = 1.0, k = 0.5, h = 1e-3;
    expect_near((kit_soft_clip(k + h, c) - kit_soft_clip(k, c)) / h, 1.0, 2e-3);
    expect_finite(kit_soft_clip(1e30, c));
    // it reaches the ceiling in float32 (tanh rounds to 1), never passes it
    expect_eq(kit_soft_clip(1e30, c), c);
    expect_eq(kit_soft_clip(-1e30, c), -c);
}
