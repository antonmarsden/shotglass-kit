// core/animate.glsl: the overshooting eases, squash and stretch, anticipation and
// settle, keyed poses and animating on twos.
#include <kit/animate.glsl>

// --- eases: exact endpoints, documented ranges, mirrors -------------------------------

float anim_ease(int k, float x) {
    if (k == 0) return kit_ease_back_in(x);
    if (k == 1) return kit_ease_back_out(x);
    if (k == 2) return kit_ease_back_inout(x);
    if (k == 3) return kit_ease_elastic_in(x);
    if (k == 4) return kit_ease_elastic_out(x);
    if (k == 5) return kit_ease_elastic_inout(x);
    if (k == 6) return kit_ease_bounce_in(x);
    if (k == 7) return kit_ease_bounce_out(x);
    return kit_ease_bounce_inout(x);
}

void test_endpoints_are_exact() {
    for (int k = 0; k < 9; k++) {
        expect_eq(anim_ease(k, 0.0), 0.0);
        expect_eq(anim_ease(k, 1.0), 1.0);
        expect_eq(anim_ease(k, -2.0), 0.0);
        expect_eq(anim_ease(k, 5.0), 1.0);
    }
    expect_near(kit_ease_back_inout(0.5), 0.5, 1e-6);
    expect_near(kit_ease_elastic_inout(0.5), 0.5, 1e-6);
    expect_near(kit_ease_bounce_inout(0.5), 0.5, 1e-6);
}

void test_documented_ranges(float x) {
    float bi = kit_ease_back_in(x), bo = kit_ease_back_out(x), bio = kit_ease_back_inout(x);
    expect(bi >= -0.1003 && bi <= 1.0, bi);      // dips 10% of the move
    expect(bo >= 0.0 && bo <= 1.1003, bo);       // overshoots 10%
    expect(bio >= -0.1003 && bio <= 1.1003, bio);
    float eo = kit_ease_elastic_out(x), ei = kit_ease_elastic_in(x);
    // "about 1.3": the first swing peaks at 1.33594 (x = 0.1479), computed in f64
    expect(eo >= 0.0 && eo <= 1.3360, eo);
    expect(ei >= -0.3360 && ei <= 1.0, ei);
    float eio = kit_ease_elastic_inout(x);
    expect(eio >= -0.1680 && eio <= 1.1680, eio);   // "about -0.16..1.16": 1.16797
    for (int k = 6; k < 9; k++) {                // bounce never leaves 0..1
        float b = anim_ease(k, x);
        expect(b >= 0.0 && b <= 1.0, b);
    }
}

void test_back_overshoot_is_ten_percent() {
    // The extreme of back_out with the default s is at x = 1 - 2s / (3(s + 1)).
    float s = 1.70158;
    float x = 1.0 - 2.0 * s / (3.0 * (s + 1.0));
    expect_near(kit_ease_back_out(x), 1.1, 2e-4);
    expect_near(kit_ease_back_in(1.0 - x), -0.1, 2e-4);
}

void test_mirrors(float x) {
    expect_near(kit_ease_back_in(x), 1.0 - kit_ease_back_out(1.0 - x), 1e-6);
    expect_near(kit_ease_elastic_in(x), 1.0 - kit_ease_elastic_out(1.0 - x), 1e-6);
    expect_near(kit_ease_bounce_in(x), 1.0 - kit_ease_bounce_out(1.0 - x), 1e-6);
    expect_near(kit_ease_back_inout(1.0 - x), 1.0 - kit_ease_back_inout(x), 1e-6);
    expect_near(kit_ease_bounce_inout(1.0 - x), 1.0 - kit_ease_bounce_inout(x), 1e-6);
}

void test_back_with_no_pull_is_a_cubic(float x) {
    expect_near(kit_ease_back_in(x, 0.0), x * x * x, 1e-6);
    expect_near(kit_ease_back_in(x, -1.0), x * x * x, 1e-6);   // s < 0 clamps to 0
}

void test_bounce_lands_on_the_floor() {
    expect_near(kit_ease_bounce_out(1.0 / 2.75), 1.0, 1e-5);
    expect_near(kit_ease_bounce_out(2.0 / 2.75), 1.0, 1e-5);
    expect_near(kit_ease_bounce_out(2.5 / 2.75), 1.0, 1e-5);
}

// --- squash and stretch ------------------------------------------------------------

vec2 dir2(float a) { return vec2(cos(a), sin(a)); }

// The mapping is linear: its determinant is the area (volume) factor, which must be 1.
void test_squash_keeps_area(vec2 c) {
    vec2 axis = 3.0 * dir2(6.2831853 * c.x);
    float s = mix(0.05, 20.0, c.y * c.y);
    vec2 ex = kit_squash(vec2(1.0, 0.0), axis, s);
    vec2 ey = kit_squash(vec2(0.0, 1.0), axis, s);
    expect_rel(ex.x * ey.y - ex.y * ey.x, 1.0, 1e-4);   // s and 1/s up to 20: float rounding
    // along the axis it shrinks by s (the shape grows by s)
    vec2 a = normalize(axis);
    expect_near(dot(kit_squash(a, axis, s), a), 1.0 / s, 1e-5);
}

// samples: 32768
void test_squash_keeps_volume(vec3 c) {
    float th = 6.2831853 * c.x, ph = 3.1415927 * c.y;
    vec3 axis = 0.5 * vec3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th));
    float s = mix(0.05, 20.0, c.z * c.z);
    mat3 m = mat3(kit_squash(vec3(1.0, 0.0, 0.0), axis, s),
                  kit_squash(vec3(0.0, 1.0, 0.0), axis, s),
                  kit_squash(vec3(0.0, 0.0, 1.0), axis, s));
    expect_rel(determinant(m), 1.0, 2e-4);
}

void test_squash_edge_cases() {
    expect_eq(kit_squash(vec2(0.3, -0.7), vec2(0.0), 2.0), vec2(0.3, -0.7));
    expect_eq(kit_squash(vec3(0.3, -0.7, 0.2), vec3(0.0), 2.0), vec3(0.3, -0.7, 0.2));
    expect_near(kit_squash(vec2(0.3, -0.7), vec2(0.0, 2.0), 1.0), vec2(0.3, -0.7), 1e-6);
    // s is clamped to 0.05..20
    expect_near(kit_squash(vec2(0.0, 1.0), vec2(0.0, 1.0), 100.0), vec2(0.0, 1.0 / 20.0), 1e-6);
    expect_near(kit_squash(vec2(0.0, 1.0), vec2(0.0, 1.0), 0.0), vec2(0.0, 20.0), 1e-4);
}

void test_stretch_speed(float x) {
    float v = mix(-50.0, 50.0, x);
    float s = kit_stretch_speed(v, 0.4);
    expect(s >= 1.0 && s < 2.0, s);
    expect_eq(s, kit_stretch_speed(-v, 0.4));
    expect(kit_stretch_speed(abs(v) + 0.1, 0.4) >= s, s);
}

void test_stretch_speed_values() {
    expect_eq(kit_stretch_speed(0.0, 0.4), 1.0);
    expect_near(kit_stretch_speed(2.5, 0.4), 1.5, 1e-6);   // speed 1/k: 1.5x
    expect_eq(kit_stretch_speed(3.0, -1.0), 1.0);          // k < 0 clamps to 0
    expect_eq(kit_squash_impact(0.0), 1.0);
    expect_eq(kit_squash_impact(1.0), 0.5);
    expect_eq(kit_squash_impact(0.5), 0.75);
    expect_eq(kit_squash_impact(-1.0), 1.0);
    expect_eq(kit_squash_impact(3.0), 0.5);
}

// --- anticipation and settle ------------------------------------------------------

void test_anticipate_values() {
    expect_eq(kit_anticipate(0.0, 0.2, 0.35), 0.0);
    expect_near(kit_anticipate(0.35, 0.2, 0.35), -0.2, 1e-6);
    expect_eq(kit_anticipate(1.0, 0.2, 0.35), 1.0);
    expect_eq(kit_anticipate(2.0, 0.2, 0.35), 1.0);
}

void test_anticipate_range_and_no_windup(float x) {
    float y = kit_anticipate(x, 0.2, 0.35);
    expect(y >= -0.2 - 1e-6 && y <= 1.0, y);
    // windup 0: a plain smoothstep move, whatever the amount
    expect_near(kit_anticipate(x, 0.5, 0.0), kit_ease_smooth(x), 1e-6);
}

void test_settle(float x) {
    float y = kit_settle(x, 0.12, 2.0);
    expect(abs(y) <= 0.12 * 1.5, y);
}

void test_settle_values() {
    expect_eq(kit_settle(0.0, 0.12, 2.0), 0.0);
    expect_near(kit_settle(1.0, 0.12, 2.0), 0.0, 1e-7);
    expect(kit_settle(0.01, 0.12, 2.0) > 0.0);    // moving forward at arrival
    expect(kit_settle(0.01, -0.12, 2.0) < 0.0);   // negative swings the other way first
}

// --- keyed poses ---------------------------------------------------------------

const float TIMES[8] = float[8](1.0, 2.0, 4.0, 5.0, 0.0, 0.0, 0.0, 0.0);
const float VALUES[8] = float[8](10.0, 20.0, -5.0, 3.0, 99.0, 99.0, 99.0, 99.0);

void test_keys() {
    expect_eq(kit_keys(0.0, TIMES, 4, 0.0), vec2(0.0, 0.0));     // before the first key
    expect_eq(kit_keys(1.5, TIMES, 4, 0.0), vec2(0.0, 0.5));
    expect_eq(kit_keys(3.0, TIMES, 4, 0.0), vec2(1.0, 0.5));
    expect_eq(kit_keys(9.0, TIMES, 4, 0.0), vec2(2.0, 1.0));     // after the last
    expect_eq(kit_keys(9.0, TIMES, 1, 0.0), vec2(0.0));          // one key
    expect_eq(kit_keys(2.4, TIMES, 4, 0.5), vec2(1.0, 0.0));     // holding key 1
    expect_near(kit_keys(3.25, TIMES, 4, 0.5), vec2(1.0, 0.5), 1e-6);
    expect_eq(kit_keys(4.9, TIMES, 4, 2.0), vec2(2.0, 0.0));     // hold > gap: a cut
    expect_eq(kit_keys(5.0, TIMES, 4, 2.0), vec2(2.0, 1.0));
}

void test_pose_hits_every_key(float x) {
    // at each key's time the pose is that key's value, with or without a hold
    int k = int(floor(x * 3.999));
    float hold = 0.3 * x;
    expect_near(kit_pose(TIMES[k], TIMES, VALUES, 4, hold), VALUES[k], 1e-5);
}

void test_pose_ends_and_overloads() {
    expect_eq(kit_pose(-1.0, TIMES, VALUES, 4, 0.2), 10.0);
    expect_eq(kit_pose(50.0, TIMES, VALUES, 4, 0.2), 3.0);
    expect_eq(kit_pose(50.0, TIMES, VALUES, 2, 0.2), 20.0);
    expect_near(kit_pose(1.5, TIMES, VALUES, 4, 0.0), 15.0, 1e-5);
    vec2 v2[8] = vec2[8](vec2(0.0), vec2(1.0, 2.0), vec2(0.0), vec2(0.0),
                         vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0));
    expect_near(kit_pose(1.5, TIMES, v2, 2, 0.0), vec2(0.5, 1.0), 1e-6);
    vec3 v3[8] = vec3[8](vec3(1.0), vec3(3.0), vec3(0.0), vec3(0.0),
                         vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
    expect_near(kit_pose(2.0, TIMES, v3, 2, 0.0), vec3(3.0), 1e-6);
}

// --- on twos ---------------------------------------------------------------

void test_on_twos(float x) {
    float t = 600.0 * x;
    float d = kit_on_twos(t, 12.0);
    float n = d * 12.0;
    expect_near(n, floor(n + 0.5), 1e-2);          // a whole number of drawings
    expect(d <= t + 1e-3 / 12.0 + 1e-4, vec2(d, t));
    expect(t - d < 1.0 / 12.0 + 1e-4, vec2(d, t));
}

void test_on_twos_lands_on_drawings() {
    // frame times that should land exactly on a drawing don't lose it to rounding
    for (int i = 0; i < 240; i++) {
        float t = float(i) / 24.0;                 // 24 fps frame times
        expect_near(kit_on_twos(t, 12.0), float(i / 2) / 12.0, 1e-6);
    }
    expect_eq(kit_on_twos(1.234, 0.0), 1.234);
    expect_eq(kit_on_twos(1.234, -3.0), 1.234);
}
