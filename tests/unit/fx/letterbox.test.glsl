// fx/letterbox.glsl: bars outside a picture of the given aspect, none inside, crisp edges.
// (The file's param is a macro named color; the tests don't use that name.)
#include <fx/ops.glsl>

const float FA = 16.0 / 9.0;
const float PX = 1.0 / 1080.0;

void test_widescreen_bars_top_and_bottom() {
    expect_eq(kit_fx_letterbox(vec2(0.5), FA, 2.39, PX), 0.0);
    expect_eq(kit_fx_letterbox(vec2(0.5, 0.02), FA, 2.39, PX), 1.0);
    expect_eq(kit_fx_letterbox(vec2(0.5, 0.98), FA, 2.39, PX), 1.0);
    expect_eq(kit_fx_letterbox(vec2(0.02, 0.5), FA, 2.39, PX), 0.0);     // sides are picture
    // The picture area is 1.778 / 2.39 of the height: its edge is at 0.5 - 0.3719 from the bottom.
    float edge = 0.5 - 0.5 * FA / 2.39;
    expect_eq(kit_fx_letterbox(vec2(0.5, edge + 0.01), FA, 2.39, PX), 0.0);
    expect_eq(kit_fx_letterbox(vec2(0.5, edge - 0.01), FA, 2.39, PX), 1.0);
    expect_near(kit_fx_letterbox(vec2(0.5, edge), FA, 2.39, PX), 0.5, 1e-3);
}

void test_narrow_aspect_bars_left_and_right() {
    expect_eq(kit_fx_letterbox(vec2(0.5), FA, 1.0, PX), 0.0);
    expect_eq(kit_fx_letterbox(vec2(0.05, 0.5), FA, 1.0, PX), 1.0);
    expect_eq(kit_fx_letterbox(vec2(0.95, 0.5), FA, 1.0, PX), 1.0);
    expect_eq(kit_fx_letterbox(vec2(0.5, 0.02), FA, 1.0, PX), 0.0);
}

// The frame's own aspect leaves no bar anywhere inside the frame.
void test_frame_aspect_has_no_bars(vec2 p) {
    vec2 uv = mix(vec2(0.001), vec2(0.999), p);   // a pixel in from the edge
    expect_eq(kit_fx_letterbox(uv, FA, FA, PX), 0.0);
}

void test_in_range_and_symmetric(vec2 p) {
    float a = kit_fx_letterbox(p, 1.5, 2.0, 0.01);
    expect(a >= 0.0 && a <= 1.0, a);
    expect_near(kit_fx_letterbox(1.0 - p, 1.5, 2.0, 0.01), a, 1e-6);
}

// A wider aspect never has less bar.
void test_wider_means_more_bar(vec2 p) {
    expect(kit_fx_letterbox(p, FA, 2.39, PX) >= kit_fx_letterbox(p, FA, 2.0, PX) - 1e-6, p);
}
