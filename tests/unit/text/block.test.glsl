// text/block.glsl: placing a text block and reading its distance field.
//
// Unit tests bind no textures, so the functions that sample one are tested here
// against a sampler with nothing bound (an incomplete texture, which GL defines to read
// (0, 0, 0, 1): no ink, the distance field at its far-outside value) and outside the
// block; tests/text draws them on real blocks and tests/golden/text.png pins the result.
#include <text/block.glsl>

uniform sampler2D uNothing;

// A block like the engine makes: 400 x 120 texels, em 64, first baseline 70 from the
// top, pitch 76.8, padding 8.
const vec3 RES = vec3(400.0, 120.0, 1.0);
const vec4 META = vec4(64.0, 70.0, 76.8, 8.0);
const vec2 FRAME = vec2(1920.0, 1080.0);

void test_place_centre() {
    // Centred on the frame centre at 1/16.875 frame heights per em: 1 texel = 1 px.
    float em = 64.0 / 1080.0;
    kit_text_box b = kit_text_place(RES, META, FRAME * 0.5, FRAME, vec2(0.5), em);
    expect_near(b.scale, 1.0, 1e-5);
    expect_near(b.texel, vec2(200.0, 60.0), 1e-3);
    expect_near(b.uv, vec2(0.5, 0.5), 1e-6);
    expect_near(b.local, vec2(0.5, 0.5), 1e-6);
    expect_eq(b.size, RES.xy);
    expect_eq(b.meta, META);
    // One frame pixel right and up is one texel right and up (texel y runs down, v up).
    kit_text_box c = kit_text_place(RES, META, FRAME * 0.5 + vec2(1.0, 1.0), FRAME, vec2(0.5), em);
    expect_near(c.texel - b.texel, vec2(1.0, -1.0), 1e-3);
    expect(c.uv.y > b.uv.y, c.uv);
}

void test_place_scales_by_em() {
    // Twice the em: twice the frame pixels per texel, whatever the raster size.
    kit_text_box a = kit_text_place(RES, META, vec2(0.0), FRAME, vec2(0.5), 0.1);
    kit_text_box b = kit_text_place(RES, META, vec2(0.0), FRAME, vec2(0.5), 0.2);
    expect_rel(b.scale, 2.0 * a.scale, 1e-6);
    expect_rel(a.scale * META.x, 0.1 * FRAME.y, 1e-6);   // an em is 0.1 frame heights
    // A block rasterised at twice the size, placed at the same em, has the same p.
    vec4 big = vec4(128.0, 140.0, 153.6, 16.0);
    vec2 f = vec2(900.0, 500.0);
    kit_text_box s = kit_text_place_baseline(RES, META, f, FRAME, vec2(0.3, 0.4), 0.1, 0.0);
    kit_text_box l = kit_text_place_baseline(RES * vec3(2.0, 2.0, 1.0), big, f, FRAME, vec2(0.3, 0.4), 0.1, 0.0);
    expect_near(s.p, l.p, 1e-4);
    expect_rel(l.scale, 0.5 * s.scale, 1e-6);
}

void test_place_anchor_corners() {
    float em = 0.08;
    // Anchor (0, 0) at pos: that pixel is the text's bottom-left corner, padding excluded.
    kit_text_box a = kit_text_place_anchor(RES, META, vec2(100.0, 50.0), FRAME, vec2(100.0, 50.0) / FRAME, em, vec2(0.0));
    expect_near(a.local, vec2(0.0), 1e-5);
    expect_near(a.texel, vec2(8.0, 112.0), 1e-3);
    kit_text_box b = kit_text_place_anchor(RES, META, vec2(1800.0, 1000.0), FRAME, vec2(1800.0, 1000.0) / FRAME, em, vec2(1.0));
    expect_near(b.local, vec2(1.0), 1e-5);
    expect_near(b.texel, vec2(392.0, 8.0), 1e-3);
    // Centre anchor is kit_text_place.
    kit_text_box c = kit_text_place_anchor(RES, META, vec2(700.0, 300.0), FRAME, vec2(0.4, 0.6), em, vec2(0.5));
    kit_text_box d = kit_text_place(RES, META, vec2(700.0, 300.0), FRAME, vec2(0.4, 0.6), em);
    expect_near(c.texel, d.texel, 1e-3);
}

// Wherever the pixel, local and p agree with texel, and uv is the vflipped texel.
void test_box_coordinates(vec2 f) {
    vec2 frag = f * FRAME;
    kit_text_box b = kit_text_place_anchor(RES, META, frag, FRAME, vec2(0.3, 0.7), 0.15, vec2(0.2, 0.8));
    expect_near(b.uv * RES.xy, vec2(b.texel.x, RES.y - b.texel.y), 2e-3);
    expect_near(b.local * (RES.xy - 2.0 * META.w), vec2(b.texel.x - META.w, RES.y - META.w - b.texel.y), 2e-3);
    expect_near(b.p * META.x, vec2(b.texel.x - META.w, META.y - b.texel.y), 2e-3);
}

void test_place_baseline() {
    // pos.y is the first baseline: p.y = 0 there, and align moves the text along it.
    vec2 f = vec2(400.0, 216.0);
    kit_text_box b = kit_text_place_baseline(RES, META, f, FRAME, f / FRAME, 0.1, 0.0);
    expect_near(b.p, vec2(0.0), 1e-5);
    expect_near(b.texel, vec2(META.w, META.y), 1e-3);
    kit_text_box e = kit_text_place_baseline(RES, META, f, FRAME, f / FRAME, 0.1, 1.0);
    expect_near(e.texel, vec2(RES.x - META.w, META.y), 1e-3);
    expect_near(e.local.x, 1.0, 1e-5);
    // One em above the baseline is p.y = 1.
    kit_text_box u = kit_text_place_baseline(RES, META, f + vec2(0.0, 108.0), FRAME, f / FRAME, 0.1, 0.0);
    expect_near(u.p, vec2(0.0, 1.0), 1e-5);
}

void test_place_degenerate() {
    // Not a text channel (meta all zero, size zero): no division by zero.
    kit_text_box b = kit_text_place(vec3(0.0), vec4(0.0), vec2(10.0), FRAME, vec2(0.5), 0.1);
    expect_finite(b.uv);
    expect_finite(b.local);
    expect_finite(b.p);
    expect_finite(b.scale);
}

void test_offset(vec2 o) {
    vec2 off = mix(vec2(-0.3), vec2(0.3), o);
    kit_text_box b = kit_text_place(RES, META, vec2(960.0, 540.0), FRAME, vec2(0.5), 0.1);
    kit_text_box m = kit_text_offset(b, off);
    // The box looks off ems back: the block appears moved by +off.
    expect_near(m.p, b.p - off, 1e-4);
    expect_near(m.texel, b.texel - vec2(off.x, -off.y) * META.x, 1e-3);
    expect_eq(m.scale, b.scale);
    // Offsetting the pixel by off ems in the frame lands back on the same point.
    kit_text_box back = kit_text_offset(kit_text_place(RES, META, vec2(960.0, 540.0) + off * 0.1 * FRAME.y, FRAME, vec2(0.5), 0.1), off);
    expect_near(back.texel, b.texel, 2e-3);
}

void test_reach_and_distance() {
    expect_eq(kit_text_reach(META), 0.125);
    expect_eq(kit_text_reach(vec4(96.0, 0.0, 0.0, 16.0)), 1.0 / 6.0);
    expect_eq(kit_text_distance_em(0.5, META), 0.0);
    expect_eq(kit_text_distance_em(1.0, META), 0.125);
    expect_eq(kit_text_distance_em(0.0, META), -0.125);
    // One texel inside the outline is 1/64 em.
    expect_near(kit_text_distance_em(0.5 + 0.5 / 8.0, META), 1.0 / 64.0, 1e-7);
    expect_finite(kit_text_distance_em(0.7, vec4(0.0)));
}

void test_distance_em_is_monotonic(float g) {
    expect(kit_text_distance_em(g + 1e-3, META) > kit_text_distance_em(g, META), g);
    float d = kit_text_distance_em(g, META);
    expect(abs(d) <= kit_text_reach(META) + 1e-6, d);
}

void test_ink(float x) {
    float d = mix(-2.0, 2.0, x);
    float i = kit_text_ink(d, 0.5);
    expect(i >= 0.0 && i <= 1.0, i);
    expect(kit_text_ink(d + 0.01, 0.5) >= i, i);
    // Symmetric about the edge.
    expect_near(i + kit_text_ink(-d, 0.5), 1.0, 1e-6);
}

void test_ink_values() {
    expect_eq(kit_text_ink(0.0, 0.1), 0.5);
    expect_eq(kit_text_ink(0.05, 0.1), 1.0);
    expect_eq(kit_text_ink(-0.05, 0.1), 0.0);
    expect_near(kit_text_ink(0.025, 0.1), 0.75, 1e-6);
    // w = 0: a hard edge, no NaN.
    expect_eq(kit_text_ink(1e-3, 0.0), 1.0);
    expect_eq(kit_text_ink(-1e-3, 0.0), 0.0);
}

// With nothing bound (and outside the block) there is no ink, and the distance field
// is at its far-outside value: -reach, so no outline, glow or shadow either.
void test_sampling_without_ink(vec2 f) {
    kit_text_box b = kit_text_place(RES, META, f * FRAME, FRAME, vec2(0.5), 0.1);
    expect_near(kit_text_distance(uNothing, b), -kit_text_reach(META), 1e-6);
    expect_eq(kit_text_edge(uNothing, b, 0.0), 0.0);
    expect_eq(kit_text_edge(uNothing, b, 0.1), 0.0);
    expect_eq(kit_text_coverage(uNothing, b), 0.0);
    expect_eq(kit_text_outline(uNothing, b, 0.05), 0.0);
    expect_eq(kit_text_glow(uNothing, b, 0.1), 0.0);
    expect_eq(kit_text_shadow(uNothing, b, vec2(0.05, -0.05), 0.1), 0.0);
}

// Growing the letters by the whole reach turns the far-outside value into the edge.
void test_edge_offset_at_reach() {
    kit_text_box b = kit_text_place(RES, META, vec2(5.0), FRAME, vec2(0.5), 0.1);
    expect_eq(kit_text_edge(uNothing, b, kit_text_reach(META)), 0.5);
    float g = 1.0 - smoothstep(0.0, 0.2, 0.125);
    expect_near(kit_text_glow(uNothing, b, 0.2), g * g, 1e-6);
}
