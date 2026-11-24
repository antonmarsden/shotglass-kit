// quality/ops.glsl: the maths under the quality metrics. Each helper must say yes to
// what its metric has to catch and no to what it has to let through, so a metric
// can't go blind (or over-report) through its helper.
#include <quality/ops.glsl>

// kit_q_diff: the largest channel difference, symmetric, 0 for the same colour.
void test_diff_is_the_largest_channel(vec3 c) {
    expect_eq(kit_q_diff(c, c), 0.0);
    expect_near(kit_q_diff(vec3(0.2, 0.5, 0.9), vec3(0.25, 0.3, 0.9)), 0.2, 1e-6);
    vec3 d = c.zxy;
    expect_eq(kit_q_diff(c, d), kit_q_diff(d, c));
    expect(kit_q_diff(c, d) <= 1.0);
}

// kit_q_luma: Rec. 709 weights, 0 for black and 1 for white, green brightest.
void test_luma() {
    expect_eq(kit_q_luma(vec3(0.0)), 0.0);
    expect_near(kit_q_luma(vec3(1.0)), 1.0, 1e-6);
    expect_near(kit_q_luma(vec3(0.0, 1.0, 0.0)), 0.7152, 1e-6);
    expect(kit_q_luma(vec3(0.0, 1.0, 0.0)) > kit_q_luma(vec3(1.0, 0.0, 0.0)));
}

void test_luma_in_range(vec3 c) {
    float y = kit_q_luma(c);
    expect(y >= 0.0 && y <= 1.0 + 1e-6, y);
}

// kit_q_lab: known values (white, black, sRGB primaries, from the CIE formulas).
void test_lab_known_values() {
    expect_near(kit_q_lab(vec3(1.0)), vec3(100.0, 0.0, 0.0), 0.05);
    expect_near(kit_q_lab(vec3(0.0)), vec3(0.0), 1e-4);
    expect_near(kit_q_lab(vec3(1.0, 0.0, 0.0)), vec3(53.24, 80.09, 67.20), 0.1);
    expect_near(kit_q_lab(vec3(0.0, 1.0, 0.0)), vec3(87.73, -86.18, 83.18), 0.1);
    expect_near(kit_q_lab(vec3(0.0, 0.0, 1.0)), vec3(32.30, 79.19, -107.86), 0.1);
    expect_near(kit_q_lab(vec3(0.5)).x, 53.39, 0.05);
}

// Greys are neutral (a* = b* = 0) and L* climbs with the grey.
void test_lab_greys_are_neutral(float t) {
    vec3 lab = kit_q_lab(vec3(t));
    expect_near(lab.yz, vec2(0.0), 0.01);
    expect(lab.x >= -1e-4 && lab.x <= 100.05, lab);
    expect(kit_q_lab(vec3(min(t + 0.01, 1.0))).x >= lab.x);
}

// Lab distance is ΔE (CIE76), as the header says: 100 from black to white, one 8-bit
// level of mid grey under 1 (invisible), a palette swap far over.
float de(vec3 a, vec3 b) { return length(kit_q_lab(a) - kit_q_lab(b)); }

void test_lab_distance_is_delta_e() {
    expect_near(de(vec3(0.0), vec3(1.0)), 100.0, 0.05);
    expect(de(vec3(0.5), vec3(0.5 + 1.0 / 255.0)) < 1.0);
    expect(de(vec3(1.0, 0.0, 0.302), vec3(0.0, 0.894, 0.212)) > 50.0);
}

// kit_q_heat: black at 0, white at 1, clamped, and never darker as x climbs.
void test_heat_ends() {
    expect_eq(kit_q_heat(0.0), vec3(0.0));
    expect_eq(kit_q_heat(1.0), vec3(1.0));
    expect_eq(kit_q_heat(-3.0), vec3(0.0));
    expect_eq(kit_q_heat(7.0), vec3(1.0));
    expect_near(kit_q_heat(1.0 / 3.0), vec3(1.0, 0.0, 0.0), 1e-6);
}

void test_heat_climbs(float t) {
    vec3 a = kit_q_heat(t), b = kit_q_heat(t + 0.01);
    expect(all(greaterThanEqual(b, a)), a);
    expect(all(greaterThanEqual(a, vec3(0.0))) && all(lessThanEqual(a, vec3(1.0))), a);
}

// kit_q_band: a one- or two-level step between flat runs is a band edge, either sign;
// no step, a big step (an edge), or noise beside it (dither, texture) is not.
void test_band() {
    expect_eq(kit_q_band(1.0, 0.0, 0.0, 2.0), 1.0);
    expect_eq(kit_q_band(-2.0, 0.0, 0.0, 2.0), 1.0);
    expect_eq(kit_q_band(0.0, 0.0, 0.0, 2.0), 0.0);
    expect_eq(kit_q_band(3.0, 0.0, 0.0, 2.0), 0.0);
    expect_eq(kit_q_band(1.0, 1.0, 0.0, 2.0), 0.0);
    expect_eq(kit_q_band(1.0, 0.0, 1.0, 2.0), 0.0);
    expect_eq(kit_q_band(5.0, 0.0, 0.0, 8.0), 1.0);
}

// kit_q_soft: a steady ramp is soft; a flat fill, a hard edge and an antialiased edge
// (one steep pixel, flat either side) are not.
void test_soft() {
    expect_eq(kit_q_soft(2.0, 2.0, 2.0, 0.75, 16.0), 1.0);
    expect_eq(kit_q_soft(-2.0, -1.5, -3.0, 0.75, 16.0), 1.0);
    expect_eq(kit_q_soft(0.0, 0.0, 0.0, 0.75, 16.0), 0.0);
    expect_eq(kit_q_soft(60.0, 60.0, 60.0, 0.75, 16.0), 0.0);
    expect_eq(kit_q_soft(10.0, 0.0, 0.0, 0.75, 16.0), 0.0);
    expect_eq(kit_q_soft(10.0, 10.0, 0.0, 0.75, 16.0), 0.0);
}

// kit_q_on_step: on twos every other frame from the offset, both ways; on ones always.
void test_on_step() {
    expect(kit_q_on_step(0, 2, 0));
    expect(!kit_q_on_step(1, 2, 0));
    expect(kit_q_on_step(2, 2, 0));
    expect(kit_q_on_step(1, 2, 1));
    expect(!kit_q_on_step(2, 2, 1));
    expect(kit_q_on_step(6, 3, 0));
    expect(!kit_q_on_step(7, 3, 0));
    expect(kit_q_on_step(0, 3, 6));
    expect(!kit_q_on_step(1, 3, 6));
    expect(kit_q_on_step(5, 1, 0));
    expect(kit_q_on_step(5, 0, 0));
}

// kit_q_slope_jump: 0 on a straight line, a step's size at a step, the larger channel,
// and small on a smooth sine (amplitude x w^2, w = 2 pi hz / rate).
void test_slope_jump(float t) {
    float a = 2.0 * t - 1.0;
    expect_near(kit_q_slope_jump(vec2(a - 0.1), vec2(a), vec2(a + 0.1)), 0.0, 1e-6);
    expect_near(kit_q_slope_jump(vec2(0.0), vec2(0.0), vec2(a)), abs(a), 1e-6);
    expect_near(kit_q_slope_jump(vec2(0.0), vec2(0.0), vec2(0.1, -0.5)), 0.5, 1e-6);
}

void test_slope_jump_of_a_sine(float t) {
    float w = 6.28318531 * 440.0 / 48000.0;
    float x = t * 200.0;
    float j = kit_q_slope_jump(vec2(sin(w * (x - 1.0))), vec2(sin(w * x)), vec2(sin(w * (x + 1.0))));
    expect(j <= w * w * 1.01 + 1e-6, j);
}
