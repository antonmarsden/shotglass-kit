#include <fx/dither-ops.glsl>

void test_clamps_colour_and_preserves_endpoints(float t) {
    expect_eq(kit_fx_dither(vec3(-0.1, 0.0, 1.1), mix(2.0, 256.0, t), t),
              vec3(0.0, 0.0, 1.0));
    expect_eq(kit_fx_dither(vec3(1.0), mix(2.0, 256.0, t), t), vec3(1.0));
}

void test_threshold_selects_adjacent_levels_and_keeps_grey_neutral() {
    expect_eq(kit_fx_dither(vec3(0.625), 3.0, 0.0), vec3(1.0));
    expect_eq(kit_fx_dither(vec3(0.625), 3.0, 1.0), vec3(0.5));
    // A zero-valued texel still has a nonzero threshold, so on-grid values stay put.
    expect_eq(kit_fx_dither(vec3(0.0, 0.5, 1.0), 3.0, 0.0), vec3(0.0, 0.5, 1.0));
    expect_eq(kit_fx_dither(vec3(0.25, 0.5, 0.75), 3.0, 1.0), vec3(0.0, 0.5, 0.5));
}

void test_level_count_clamps_and_rounds(float t) {
    vec3 col = vec3(t, 1.0 - t, 0.625);
    expect_eq(kit_fx_dither(col, -1.0, t), kit_fx_dither(col, 2.0, t));
    expect_eq(kit_fx_dither(col, 300.0, t), kit_fx_dither(col, 256.0, t));
    expect_eq(kit_fx_dither(col, 2.5, t), kit_fx_dither(col, 3.0, t));
}

void test_quantization_grid_and_error_bound(vec3 t) {
    float levels = floor(mix(2.0, 256.0, t.x) + 0.5);
    float intervals = levels - 1.0;
    vec3 col = vec3(t.y, t.z, 1.0 - t.y);
    float noise = floor(t.z * 255.0 + 0.5) / 255.0;
    vec3 result = kit_fx_dither(col, levels, noise);
    vec3 grid = result * intervals;
    expect(all(greaterThanEqual(result, vec3(0.0))) &&
           all(lessThanEqual(result, vec3(1.0))), result);
    expect_near(grid, floor(grid + 0.5), 2e-5);
    expect(all(lessThanEqual(abs(result - col), vec3(1.0 / intervals + 1e-6))), result - col);
}

void test_full_8_bit_grid_passes_through(float t) {
    vec3 col = floor(vec3(t, 1.0 - t, 0.4) * 255.0 + 0.5) / 255.0;
    expect_near(kit_fx_dither(col, 256.0, 0.0), col, 1e-6);
    expect_near(kit_fx_dither(col, 256.0, 1.0), col, 1e-6);
}
