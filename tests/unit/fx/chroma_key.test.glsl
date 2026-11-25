#include <fx/ops.glsl>

const vec3 GREEN = vec3(0.0, 1.0, 0.0);
const vec3 BLUE = vec3(0.0, 0.0, 1.0);
const vec3 WARM = vec3(0.875, 0.25, 0.125);

void test_screen_is_removed(float alpha) {
    expect_eq(kit_fx_chroma_key(vec4(GREEN, alpha), GREEN, 0.0, 0.0, 1.0).a, 0.0);
    expect_eq(kit_fx_chroma_key(vec4(BLUE, alpha), BLUE, 0.12, 0.30, 1.0).a, 0.0);
}

void test_neutral_offset_does_not_change_coverage(float t) {
    vec3 screen = vec3(0.0, 0.75, 0.0);
    vec3 col = screen + 0.25 * t;
    expect_eq(kit_fx_chroma_key(vec4(col, 1.0), screen, 0.01, 0.2, 0.0).a, 0.0);
}

void test_soft_edge_endpoints_and_midpoint() {
    // A green-only change of g gives a chroma distance of g * sqrt(2/3).
    float unit = sqrt(2.0 / 3.0);
    float cutoff = 0.125 * unit;
    float width = 0.25 * unit;
    expect_eq(kit_fx_chroma_key(vec4(0.0, 0.90, 0.0, 1.0), GREEN, cutoff, width, 0.0).a, 0.0);
    expect_near(kit_fx_chroma_key(vec4(0.0, 0.75, 0.0, 0.5), GREEN, cutoff, width, 0.0).a, 0.25, 1e-6);
    expect_eq(kit_fx_chroma_key(vec4(0.0, 0.60, 0.0, 1.0), GREEN, cutoff, width, 0.0).a, 1.0);
}

void test_hard_edge_and_minimum_positive_width() {
    vec4 plate = vec4(0.0, 0.75, 0.0, 0.5);
    expect_eq(kit_fx_chroma_key(plate, GREEN, 0.21, 0.0, 1.0).a, 0.0);
    expect_eq(kit_fx_chroma_key(plate, GREEN, 0.20, 0.0, 1.0).a, 0.5);
    float cutoff = 0.25 * sqrt(2.0 / 3.0) - 5e-7;
    expect_eq(kit_fx_chroma_key(plate, GREEN, cutoff, 1e-8, 1.0),
              kit_fx_chroma_key(plate, GREEN, cutoff, 1e-6, 1.0));
}

void test_matte_is_monotonic_and_despill_independent(float t) {
    vec4 plate = vec4(mix(GREEN, WARM, t), 0.75);
    vec4 next = vec4(mix(GREEN, WARM, min(t + 0.01, 1.0)), plate.a);
    vec4 raw = kit_fx_chroma_key(plate, GREEN, 0.12, 0.30, 0.0);
    vec4 clean = kit_fx_chroma_key(plate, GREEN, 0.12, 0.30, 1.0);
    float later = kit_fx_chroma_key(next, GREEN, 0.12, 0.30, 1.0).a;
    expect_eq(raw.rgb, plate.rgb);
    expect_eq(raw.a, clean.a);
    expect(clean.a >= 0.0 && clean.a <= plate.a && clean.a <= later + 1e-6, vec2(clean.a, later));
}

void test_foreground_keeps_straight_rgb_and_source_alpha(float alpha) {
    expect_eq(kit_fx_chroma_key(vec4(WARM, alpha), GREEN, 0.12, 0.30, 1.0), vec4(WARM, alpha));
}

void test_spill_strength_and_non_green_key(float t) {
    vec4 plate = vec4(0.25, 0.25, 0.625, 1.0);
    vec3 clean = mix(plate.rgb, vec3(0.375), t);
    expect_near(kit_fx_chroma_key(plate, BLUE, 0.12, 0.30, t), vec4(clean, 1.0), 1e-6);
}

void test_despill_preserves_neutral_foreground(float t) {
    vec4 plate = vec4(vec3(t), 1.0);
    expect_eq(kit_fx_chroma_key(plate, GREEN, 0.12, 0.30, 1.0), plate);
}

void test_neutral_key_has_no_spill_direction(vec3 col) {
    expect_eq(kit_fx_chroma_key(vec4(col, 1.0), vec3(0.5), 0.12, 0.30, 1.0).rgb, col);
}

void test_output_range_and_option_clamps(vec3 col) {
    vec3 key = vec3(col.b, 1.0 - col.r, col.g);
    float t = col.r;
    vec4 plate = vec4(col, t);
    vec4 clean = kit_fx_chroma_key(plate, key, 2.0 * t, 2.0 * (1.0 - t), t);
    expect(all(greaterThanEqual(clean, vec4(0.0))) && all(lessThanEqual(clean, vec4(1.0))), clean);
    expect_eq(kit_fx_chroma_key(plate, key, -1.0, -1.0, -1.0),
              kit_fx_chroma_key(plate, key, 0.0, 0.0, 0.0));
    expect_eq(kit_fx_chroma_key(plate, key, 0.0, 3.0, 2.0),
              kit_fx_chroma_key(plate, key, 0.0, 2.0, 1.0));
    expect_eq(kit_fx_chroma_key(plate, key, 3.0, 0.0, 1.0).a, 0.0);
}
