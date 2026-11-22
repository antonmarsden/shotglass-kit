// core/ease.glsl: every ease clamps x to 0..1, returns 0..1, f(0) = 0 and f(1) = 1.
#include <kit/ease.glsl>

float ease(int k, float x) {
    if (k == 0) return kit_ease_linear(x);
    if (k == 1) return kit_ease_smooth(x);
    if (k == 2) return kit_ease_smoother(x);
    if (k == 3) return kit_ease_in(x);
    if (k == 4) return kit_ease_out(x);
    return kit_ease_inout(x);
}

void test_endpoints_are_exact() {
    for (int k = 0; k < 6; k++) {
        expect_eq(ease(k, 0.0), 0.0);
        expect_eq(ease(k, 1.0), 1.0);
    }
    expect_eq(kit_ease_step(0.0), 0.0);
    expect_eq(kit_ease_step(1.0), 1.0);
}

void test_input_is_clamped() {
    for (int k = 0; k < 6; k++) {
        expect_eq(ease(k, -3.0), 0.0);
        expect_eq(ease(k, 7.0), 1.0);
    }
}

// Monotonic and within 0..1, over the whole range.
void test_monotonic_and_in_range(float x) {
    for (int k = 0; k < 6; k++) {
        float y = ease(k, x);
        expect(y >= 0.0 && y <= 1.0, y);
        expect(ease(k, x + 1e-3) >= y - 1e-6, vec2(y, ease(k, x + 1e-3)));
    }
}

// smooth, smoother and inout are point-symmetric about (0.5, 0.5); out mirrors in.
void test_symmetry(float x) {
    expect_near(kit_ease_smooth(1.0 - x), 1.0 - kit_ease_smooth(x), 1e-6);
    expect_near(kit_ease_smoother(1.0 - x), 1.0 - kit_ease_smoother(x), 2e-6);   // float rounding near 1
    expect_near(kit_ease_inout(1.0 - x), 1.0 - kit_ease_inout(x), 1e-6);
    expect_near(kit_ease_out(x), 1.0 - kit_ease_in(1.0 - x), 1e-6);
}

void test_known_values() {
    expect_eq(kit_ease_smooth(0.5), 0.5);
    expect_eq(kit_ease_smoother(0.5), 0.5);
    expect_eq(kit_ease_in(0.5), 0.25);
    expect_eq(kit_ease_out(0.5), 0.75);
    expect_eq(kit_ease_inout(0.25), 0.125);
    expect_eq(kit_ease_linear(0.3), 0.3);
}

void test_step_holds_until_one(float x) {
    expect_eq(kit_ease_step(x * 0.999), 0.0);
}

void test_tween() {
    expect_eq(kit_tween(2.0, 3.5, 1.0), 0.0);
    expect_eq(kit_tween(2.0, 3.5, 2.0), 0.0);
    expect_near(kit_tween(2.0, 3.5, 2.75), 0.5, 1e-6);
    expect_eq(kit_tween(2.0, 3.5, 3.5), 1.0);
    expect_eq(kit_tween(2.0, 3.5, 9.0), 1.0);
    // to <= from: a step at `to`
    expect_eq(kit_tween(3.0, 3.0, 2.999), 0.0);
    expect_eq(kit_tween(3.0, 3.0, 3.0), 1.0);
    expect_eq(kit_tween(4.0, 3.0, 3.5), 1.0);
}
