// core/color.glsl: tonemapping, sRGB, palettes, vignette and grain.
#include <kit/color.glsl>

void test_srgb_round_trip(vec3 c) {
    expect_near(kit_srgb_decode(kit_srgb_encode(c)), c, 2e-6);
    expect_near(kit_srgb_encode(kit_srgb_decode(c)), c, 2e-6);
}

void test_srgb_values() {
    expect_eq(kit_srgb_encode(vec3(0.0)), vec3(0.0));
    expect_near(kit_srgb_encode(vec3(1.0)), vec3(1.0), 1e-6);
    expect_near(kit_srgb_encode(vec3(0.5)), vec3(0.7353569830524495), 1e-6);   // f64 reference
    expect_near(kit_srgb_encode(vec3(0.002)), vec3(0.002 * 12.92), 1e-7);     // the linear toe
    expect_near(kit_srgb_decode(vec3(0.7353569830524495)), vec3(0.5), 1e-6);
    // clamped to 0..1
    expect_eq(kit_srgb_encode(vec3(-1.0)), vec3(0.0));
    expect_near(kit_srgb_encode(vec3(4.0)), vec3(1.0), 1e-6);
}

// Monotonic through the joint between the linear toe and the power curve.
void test_srgb_is_monotonic(float x) {
    vec3 c = vec3(x * 0.1);
    expect(all(greaterThanEqual(kit_srgb_encode(c + 1e-5), kit_srgb_encode(c))), kit_srgb_encode(c));
    expect(all(greaterThanEqual(kit_srgb_decode(c + 1e-5), kit_srgb_decode(c))), kit_srgb_decode(c));
}

void test_aces(float x) {
    float v = x * x * 1000.0;               // 0..1000, dense near 0
    vec3 y = kit_aces(vec3(v, 0.5 * v, 2.0 * v));
    expect(all(greaterThanEqual(y, vec3(0.0))) && all(lessThanEqual(y, vec3(1.0))), y);
    expect(kit_aces(vec3(v + 0.01)).x >= y.x, y);   // brighter in, brighter out
}

void test_aces_values() {
    expect_eq(kit_aces(vec3(0.0)), vec3(0.0));
    expect_eq(kit_aces(vec3(-5.0)), vec3(0.0));
    expect_near(kit_aces(vec3(1e6)), vec3(1.0), 1e-6);
}

void test_palette() {
    vec3 a = vec3(0.5), b = vec3(0.4), c = vec3(1.0), d = vec3(0.0, 0.25, 0.5);
    expect_near(kit_palette(0.0, a, b, c, d), vec3(0.9, 0.5, 0.1), 1e-6);
    expect_near(kit_palette(1.0, a, b, c, d), kit_palette(0.0, a, b, c, d), 1e-5);   // period 1/c
}

void test_vignette(vec2 uv) {
    float v = kit_vignette(uv, 0.4, 0.6);
    expect(v >= 0.6 - 1e-6 && v <= 1.0, v);
}

void test_vignette_values() {
    expect_eq(kit_vignette(vec2(0.5), 0.4, 0.6), 1.0);
    expect_near(kit_vignette(vec2(0.0), 0.4, 0.6), 0.6, 1e-6);
    expect_near(kit_vignette(vec2(1.0, 0.0), 0.4, 0.6), 0.6, 1e-6);
    expect_eq(kit_vignette(vec2(0.3), 0.0, 0.6), 1.0);
}

void test_grain(vec2 c) {
    vec2 frag = floor(c * 1000.0) + 0.5;
    vec3 col = vec3(0.5, 0.2, 0.8);
    vec3 g = kit_grain(col, frag, 17, 0.04);
    expect(all(lessThanEqual(abs(g - col), vec3(0.02))), g - col);
    expect_eq(g, kit_grain(col, frag, 17, 0.04));                 // same frame, same grain
    expect_eq(kit_grain(col, frag, 17, 0.0), col);
    expect_near(g.r - col.r, g.g - col.g, 1e-6);                  // one value per pixel
}
