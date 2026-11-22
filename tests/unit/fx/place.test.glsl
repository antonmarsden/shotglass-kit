// fx/place.glsl: where a placed picture falls, its proportions, its anchor and its edges.
// (The file's param is a macro named anchor; the tests don't use that name.)
#include <fx/ops.glsl>

const float FA = 1.5;
const float PX = 1.0 / 1000.0;

void test_centred_picture() {
    vec3 q = kit_fx_place(vec2(0.5), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX);
    expect_near(q.xy, vec2(0.5), 1e-6);
    expect_eq(q.z, 1.0);
}

// A 2:1 picture 0.2 frame heights tall is 0.4 frame heights wide: 0.4 / 1.5 of the width.
void test_proportions_are_kept() {
    float w = 0.4 / FA;
    vec3 right = kit_fx_place(vec2(0.5 + 0.25 * w, 0.5), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX);
    expect_near(right.x, 0.75, 1e-5);
    vec3 up = kit_fx_place(vec2(0.5, 0.5 + 0.25 * 0.2), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX);
    expect_near(up.y, 0.75, 1e-5);
}

void test_outside_is_empty() {
    expect_eq(kit_fx_place(vec2(0.1, 0.5), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 0.0);
    expect_eq(kit_fx_place(vec2(0.5, 0.9), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 0.0);
    expect_eq(kit_fx_place(vec2(0.5, 0.1), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 0.0);
}

void test_nothing_bound_is_empty(vec2 p) {
    expect_eq(kit_fx_place(p, FA, 0.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 0.0);
}

// The anchor is the point of the picture that sits at pos, whatever the size.
void test_anchor_pins_a_point() {
    vec3 corner = kit_fx_place(vec2(0.9, 0.9) - 0.005, FA, 2.0, vec2(0.9), 0.1, vec2(1.0), PX);
    expect_near(corner.xy, vec2(1.0), 0.06);                // just inside the top right corner
    expect_eq(corner.z, 1.0);
    vec3 beyond = kit_fx_place(vec2(0.9, 0.9) + 0.01, FA, 2.0, vec2(0.9), 0.1, vec2(1.0), PX);
    expect_eq(beyond.z, 0.0);
    vec3 low = kit_fx_place(vec2(0.2), FA, 2.0, vec2(0.2), 0.1, vec2(0.0), PX);
    expect_near(low.xy, vec2(0.0), 1e-5);
}

void test_edge_is_one_pixel_wide() {
    float h = 0.2 * 0.5;                                    // half the height, frame heights
    float edge = 0.5 + h;                                   // top edge, uv.y
    expect_near(kit_fx_place(vec2(0.5, edge), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 0.5, 1e-3);
    expect_eq(kit_fx_place(vec2(0.5, edge - 2.0 * PX), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 1.0);
    expect_eq(kit_fx_place(vec2(0.5, edge + 2.0 * PX), FA, 2.0, vec2(0.5), 0.2, vec2(0.5), PX).z, 0.0);
}

void test_outputs_in_range(vec2 p) {
    vec3 q = kit_fx_place(p, FA, 1.3, vec2(0.6, 0.4), 0.5, vec2(0.3, 0.7), PX);
    expect(all(greaterThanEqual(q, vec3(0.0))) && all(lessThanEqual(q, vec3(1.0))), q);
}
