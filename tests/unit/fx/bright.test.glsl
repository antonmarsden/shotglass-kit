// fx/bright.glsl: nothing below the threshold, everything above it, smooth between.
// (The file's param is a macro named knee; the tests don't use that name.)
#include <fx/ops.glsl>

void test_below_threshold_is_black(vec3 c) {
    vec3 dim = c * 0.5;                                   // luma <= 0.5
    expect_eq(kit_fx_bright(dim, 0.5, 0.25), vec3(0.0));
}

void test_above_threshold_is_untouched(vec3 c) {
    vec3 lit = mix(vec3(0.9), vec3(1.0), c);              // luma >= 0.9
    expect_near(kit_fx_bright(lit, 0.5, 0.25), lit, 1e-6);
}

void test_grey_ramp_is_smooth_and_monotonic(float x) {
    vec3 a = kit_fx_bright(vec3(x), 0.3, 0.4);
    vec3 b = kit_fx_bright(vec3(x + 1e-3), 0.3, 0.4);
    expect(b.x >= a.x - 1e-6, vec2(a.x, b.x));
    expect(a.x >= 0.0 && a.x <= x + 1e-6, a.x);
}

void test_hard_cut_when_width_is_zero() {
    expect_eq(kit_fx_bright(vec3(0.59), 0.6, 0.0), vec3(0.0));
    expect_near(kit_fx_bright(vec3(0.61), 0.6, 0.0), vec3(0.61), 1e-6);
}

// The colour keeps its hue: scaled, never mixed.
void test_hue_is_kept(vec3 c) {
    vec3 r = kit_fx_bright(c, 0.2, 0.5);
    expect_near(r * dot(c, c), c * dot(r, c), 1e-5);
}
