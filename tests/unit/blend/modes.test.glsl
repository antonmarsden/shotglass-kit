// blend/modes.glsl: the modes' identities and known values, the premultiplied handling
// and the range of every mode over all colours (the separable modes work per channel, so
// a scalar pair swept over 0..1 covers them).
#include <blend/modes.glsl>

vec3 g(float x) { return vec3(x); }

void test_source_unpremultiplies() {
    expect_near(kit_blend_source(vec4(0.5, 0.25, 0.0, 0.5)), vec3(1.0, 0.5, 0.0), 1e-6);
    expect_near(kit_blend_source(vec4(0.2, 0.4, 0.6, 1.0)), vec3(0.2, 0.4, 0.6), 1e-6);
}

void test_source_of_nothing_is_black() {
    expect_eq(kit_blend_source(vec4(0.0)), vec3(0.0));
}

// 8-bit premultiplied storage can leave rgb above alpha: still 0..1 out.
void test_source_is_clamped() {
    expect_eq(kit_blend_source(vec4(0.6, 0.5, 0.0, 0.5)), vec3(1.0, 1.0, 0.0));
}

void test_composite_follows_coverage() {
    vec4 base = vec4(0.2, 0.4, 0.8, 1.0);
    vec3 mixed = vec3(1.0, 0.0, 0.5);
    expect_eq(kit_blend_composite(base, vec4(0.0), mixed), base);
    expect_eq(kit_blend_composite(base, vec4(0.0, 0.0, 0.0, 1.0), mixed), vec4(mixed, 1.0));
    expect_near(kit_blend_composite(base, vec4(0.0, 0.0, 0.0, 0.25), mixed),
                vec4(mix(base.rgb, mixed, 0.25), 1.0), 1e-6);
}

// A layer with no coverage changes nothing in any mode, whatever colour it holds.
void test_no_coverage_leaves_the_picture(vec3 c) {
    vec4 base = vec4(c, 1.0);
    vec4 none = vec4(0.0);
    vec3 cs = kit_blend_source(none);
    expect_eq(kit_blend_composite(base, none, kit_blend_multiply(c, cs)).rgb, c);
    expect_eq(kit_blend_composite(base, none, kit_blend_difference(c, cs)).rgb, c);
    expect_eq(kit_blend_composite(base, none, kit_blend_colordodge(c, cs)).rgb, c);
}

void test_known_values() {
    expect_near(kit_blend_multiply(g(0.5), g(0.5)), g(0.25), 1e-6);
    expect_near(kit_blend_screen(g(0.5), g(0.5)), g(0.75), 1e-6);
    expect_near(kit_blend_add(g(0.5), g(0.25)), g(0.75), 1e-6);
    expect_near(kit_blend_add(g(0.8), g(0.5)), g(1.0), 1e-6);
    expect_near(kit_blend_darken(g(0.2), g(0.7)), g(0.2), 1e-6);
    expect_near(kit_blend_lighten(g(0.2), g(0.7)), g(0.7), 1e-6);
    expect_near(kit_blend_difference(g(0.2), g(0.7)), g(0.5), 1e-6);
    expect_near(kit_blend_hardlight(g(0.8), g(0.25)), g(0.4), 1e-6);       // multiply 0.8 x 0.5
    expect_near(kit_blend_hardlight(g(0.5), g(0.75)), g(0.75), 1e-6);      // screen 0.5, 0.5
    expect_near(kit_blend_overlay(g(0.25), g(0.8)), g(0.4), 1e-6);         // hard light, swapped
    expect_near(kit_blend_colordodge(g(0.25), g(0.5)), g(0.5), 1e-6);
    expect_near(kit_blend_colorburn(g(0.75), g(0.5)), g(0.5), 1e-6);
    expect_near(kit_blend_softlight(g(0.5), g(1.0)), g(sqrt(0.5)), 1e-6);  // dodge branch: D(0.5) = sqrt
    expect_near(kit_blend_softlight(g(0.5), g(0.0)), g(0.25), 1e-6);       // darken branch: 0.5 - 1 x 0.5 x 0.5
}

// Neutral colours: the layer value that leaves the picture alone.
void test_identities(vec3 c) {
    expect_near(kit_blend_multiply(c, g(1.0)), c, 1e-6);
    expect_near(kit_blend_screen(c, g(0.0)), c, 1e-6);
    expect_near(kit_blend_add(c, g(0.0)), c, 1e-6);
    expect_near(kit_blend_darken(c, g(1.0)), c, 1e-6);
    expect_near(kit_blend_lighten(c, g(0.0)), c, 1e-6);
    expect_near(kit_blend_difference(c, c), g(0.0), 1e-6);
    expect_near(kit_blend_difference(c, g(0.0)), c, 1e-6);
    expect_near(kit_blend_hardlight(c, g(0.5)), c, 1e-6);
    expect_near(kit_blend_overlay(c, g(0.5)), c, 1e-6);
    expect_near(kit_blend_softlight(c, g(0.5)), c, 1e-6);
    expect_near(kit_blend_colordodge(c, g(0.0)), c, 1e-6);
    expect_near(kit_blend_colorburn(c, g(1.0)), c, 1e-6);
}

// The documented extremes of dodge and burn, which divide by something that can be 0.
void test_dodge_and_burn_extremes(float x) {
    expect_eq(kit_blend_colordodge(g(0.0), g(x)), g(0.0));
    expect_eq(kit_blend_colorburn(g(1.0), g(x)), g(1.0));
    float lit = mix(0.01, 1.0, x);
    expect_eq(kit_blend_colordodge(g(lit), g(1.0)), g(1.0));
    float unlit = mix(0.0, 0.99, x);
    expect_eq(kit_blend_colorburn(g(unlit), g(0.0)), g(0.0));
}

// Every mode keeps 0..1 in, 0..1 out, and is finite everywhere including the ends.
void test_range(vec2 p) {
    vec3 cb = g(p.x), cs = g(p.y);
    vec3 r[11] = vec3[11](
        kit_blend_multiply(cb, cs), kit_blend_screen(cb, cs), kit_blend_overlay(cb, cs),
        kit_blend_hardlight(cb, cs), kit_blend_add(cb, cs), kit_blend_darken(cb, cs),
        kit_blend_lighten(cb, cs), kit_blend_difference(cb, cs), kit_blend_colordodge(cb, cs),
        kit_blend_colorburn(cb, cs), kit_blend_softlight(cb, cs));
    for (int i = 0; i < 11; i++) {
        expect_finite(r[i]);
        expect(r[i].x >= -1e-6 && r[i].x <= 1.0 + 1e-6, vec2(float(i), r[i].x));
    }
}

// Screen and multiply are mirror images, and screen never darkens, multiply never lightens.
void test_screen_multiply(vec2 p) {
    expect_near(kit_blend_screen(g(p.x), g(p.y)), g(1.0) - kit_blend_multiply(g(1.0 - p.x), g(1.0 - p.y)), 1e-6);
    expect(kit_blend_screen(g(p.x), g(p.y)).x >= max(p.x, p.y) - 1e-6, p);
    expect(kit_blend_multiply(g(p.x), g(p.y)).x <= min(p.x, p.y) + 1e-6, p);
}
