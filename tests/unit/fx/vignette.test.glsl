// fx/vignette.glsl: clear in the middle, `strength` in the corners, and core's falloff.
#include <fx/ops.glsl>
#include <kit/color.glsl>

void test_middle_is_clear_and_corners_full() {
    expect_eq(kit_fx_vignette(vec2(0.5), 0.4, 0.6), 0.0);
    expect_near(kit_fx_vignette(vec2(0.0), 0.4, 0.6), 0.4, 1e-6);
    expect_near(kit_fx_vignette(vec2(1.0, 0.0), 0.4, 0.6), 0.4, 1e-6);
}

void test_no_strength_no_vignette(vec2 p) {
    expect_eq(kit_fx_vignette(p, 0.0, 0.6), 0.0);
}

void test_in_range_and_symmetric(vec2 p) {
    float v = kit_fx_vignette(p, 0.7, 0.5);
    expect(v >= 0.0 && v <= 0.7 + 1e-6, v);
    expect_near(kit_fx_vignette(1.0 - p, 0.7, 0.5), v, 1e-6);
}

// It is 1 - core's multiplier, so the two agree.
void test_matches_core(vec2 p) {
    expect_near(kit_fx_vignette(p, 0.4, 0.6), 1.0 - kit_vignette(p, 0.4, 0.6), 1e-6);
}

// A wider softness starts closer to the middle: never less covered.
void test_softness_widens(vec2 p) {
    expect(kit_fx_vignette(p, 0.5, 0.9) >= kit_fx_vignette(p, 0.5, 0.3) - 1e-6, p);
}
