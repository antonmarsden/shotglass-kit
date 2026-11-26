#include <kit/sdf_coverage.glsl>

void test_constant_field() {
    expect_eq(kit_sd_fill(-1.0), 1.0);
    expect_eq(kit_sd_fill(0.0), 0.5);
    expect_eq(kit_sd_fill(1.0), 0.0);
    expect_eq(kit_sd_outline(0.0, 2.0), 0.0);
    expect_eq(kit_sd_outline(-1.0, 2.0), 0.0);
}

// Every 2x2 fragment quad sees the same four local positions.
vec2 local_pixel() {
    return mod(gl_FragCoord.xy, 2.0) - 0.5;
}

void test_axis_aligned(float t) {
    float x = local_pixel().x;
    for (int i = 0; i <= 16; ++i) {
        float d = x - float(i) / 16.0;
        float width_px = t;
        // Intersection length of the strip and the pixel's [-0.5, 0.5] interval.
        float half_width = 0.5 * width_px;
        float expected = max(0.0, min(0.5, half_width - d) - max(-0.5, -half_width - d));
        float coverage = kit_sd_outline(d, width_px);
        expect_near(coverage, expected, 1e-6);
        expect_near(kit_sd_outline(-d * 0.03125, width_px), coverage, 1e-6);
        expect_near(kit_sd_fill(d * 8.0), clamp(0.5 - d, 0.0, 1.0), 1e-6);
        expect_eq(kit_sd_outline(d, -1.0), 0.0);
        expect_eq(kit_sd_outline(d, 4.0), 1.0);
    }
}

void test_diagonal(float t) {
    float d = dot(local_pixel(), vec2(1.0));
    // Offsets sweep the full pixel footprint in 1/16-pixel steps.
    for (int i = -16; i <= 16; ++i) {
        float edge = d + float(i) / 16.0;
        float tail = 0.5 * pow(max(1.0 - abs(edge), 0.0), 2.0);
        float fill = kit_sd_fill(edge);
        expect_near(fill, edge < 0.0 ? 1.0 - tail : tail, 1e-6);
        expect_near(kit_sd_fill(-edge), 1.0 - fill, 1e-6);
        // This width offsets the diagonal field by +/- 0.25 distance units.
        float outline = kit_sd_outline(edge, 0.353553391);
        expect(outline >= 0.0 && outline <= 1.0);
        expect_near(outline, kit_sd_fill(edge - 0.25) - kit_sd_fill(edge + 0.25), 1e-6);
        expect_near(outline, kit_sd_outline(-edge, 0.353553391), 1e-6);
        expect(kit_sd_outline(edge, 0.353553391 * t) <= outline + 1e-6);
    }
}
