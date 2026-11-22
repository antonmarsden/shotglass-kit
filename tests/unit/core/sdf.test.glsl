// core/sdf.glsl and sdf_ops.glsl: exact distances at known points, the sign, and the
// property raymarching relies on: a distance never changes faster than the point moves
// (Lipschitz 1), so a step of that size can't pass through a surface.
#include <kit/sdf_ops.glsl>

void test_known_distances() {
    expect_eq(kit_sd_circle(vec2(3.0, 4.0), 2.0), 3.0);
    expect_eq(kit_sd_circle(vec2(0.0), 2.0), -2.0);
    expect_eq(kit_sd_box(vec2(3.0, 0.0), vec2(1.0, 0.5)), 2.0);
    expect_near(kit_sd_box(vec2(4.0, 4.5), vec2(1.0, 0.5)), 5.0, 1e-6);    // corner: 3-4-5
    expect_eq(kit_sd_box(vec2(0.0), vec2(1.0, 0.5)), -0.5);
    expect_eq(kit_sd_segment(vec2(0.5, 2.0), vec2(0.0), vec2(1.0, 0.0)), 2.0);
    expect_eq(kit_sd_segment(vec2(4.0, 4.0), vec2(0.0), vec2(1.0, 0.0)), 5.0);
    expect_eq(kit_sd_segment(vec2(3.0, 4.0), vec2(0.0), vec2(0.0)), 5.0);   // a point
    expect_eq(kit_sd_sphere(vec3(0.0, 3.0, 4.0), 1.0), 4.0);
    expect_eq(kit_sd_box(vec3(0.0, 0.0, 3.0), vec3(1.0)), 2.0);
    expect_eq(kit_sd_box(vec3(0.5, 0.0, 0.0), vec3(1.0)), -0.5);
    expect_near(kit_sd_round_box(vec3(0.0, 0.0, 3.0), vec3(1.0), 0.25), 2.0, 1e-6);
    expect_near(kit_sd_capsule(vec3(0.0, 5.0, 0.0), vec3(0.0), vec3(0.0, 2.0, 0.0), 0.5), 2.5, 1e-6);
    expect_near(kit_sd_capsule(vec3(3.0, 1.0, 0.0), vec3(0.0), vec3(0.0, 2.0, 0.0), 0.5), 2.5, 1e-6);
    expect_eq(kit_sd_cylinder(vec3(3.0, 0.0, 0.0), 1.0, 2.0), 2.0);
    expect_eq(kit_sd_cylinder(vec3(0.0, 5.0, 0.0), 1.0, 2.0), 3.0);
    expect_eq(kit_sd_cylinder(vec3(0.0), 1.0, 2.0), -1.0);
    expect_eq(kit_sd_plane(vec3(0.0, 2.0, 0.0), vec3(0.0, 1.0, 0.0), 1.0), 3.0);   // plane y = -1
}

void test_ellipsoid_is_zero_on_its_surface(vec2 c) {
    vec3 r = vec3(2.0, 1.0, 0.5);
    float th = 6.2831853 * c.x, ph = 3.1415927 * c.y;
    vec3 u = vec3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th));
    expect_near(kit_sd_ellipsoid(u * r, r), 0.0, 1e-5);
    expect(kit_sd_ellipsoid(u * r * 0.5, r) < 0.0);
    expect(kit_sd_ellipsoid(u * r * 1.5, r) > 0.0);
}

// Every exact SDF, at points in -3..3, along a few directions.
float shape(int k, vec3 p) {
    if (k == 0) return kit_sd_circle(p.xy, 1.0);
    if (k == 1) return kit_sd_box(p.xy, vec2(1.0, 0.4));
    if (k == 2) return kit_sd_segment(p.xy, vec2(-1.0, 0.2), vec2(0.7, -0.5));
    if (k == 3) return kit_sd_sphere(p, 1.2);
    if (k == 4) return kit_sd_box(p, vec3(1.0, 0.3, 0.6));
    if (k == 5) return kit_sd_round_box(p, vec3(1.0, 0.5, 0.8), 0.2);
    if (k == 6) return kit_sd_capsule(p, vec3(-1.0, 0.0, 0.0), vec3(1.0, 1.0, 0.5), 0.3);
    if (k == 7) return kit_sd_cylinder(p, 0.8, 1.1);
    if (k == 8) return kit_sd_plane(p, normalize(vec3(1.0, 2.0, -0.5)), 0.3);
    if (k == 9) return kit_op_smin(kit_sd_sphere(p, 1.0), kit_sd_box(p - vec3(1.2, 0.0, 0.0), vec3(0.5)), 0.4);
    if (k == 10) return kit_op_smax(kit_sd_sphere(p, 1.0), kit_sd_box(p, vec3(0.8)), 0.3);
    if (k == 11) return kit_op_ssubtract(kit_sd_box(p, vec3(1.0)), kit_sd_sphere(p, 1.25), 0.1);
    if (k == 12) return kit_op_onion(kit_sd_sphere(p, 1.0), 0.1);
    if (k == 13) return kit_sd_sphere(vec3(kit_op_repeat(p.xz, vec2(2.0)), p.y).xzy, 0.5);
    return kit_sd_sphere(vec3(kit_op_repeat_polar(p.xz, 6.0), p.y).xzy - vec3(1.5, 0.0, 0.0), 0.3);
}

// samples: 32768
void test_lipschitz(vec3 c) {
    vec3 p = c * 6.0 - 3.0;
    const float h = 1e-2;
    for (int k = 0; k < 15; k++) {
        float d = shape(k, p);
        for (int j = 0; j < 4; j++) {
            vec3 u = normalize(vec3(j == 1 ? -1.0 : 1.0, j == 2 ? -2.0 : 0.7, j == 3 ? 3.0 : 0.3));
            float e = shape(k, p + h * u);
            expect(abs(e - d) <= h * 1.0005 + 1e-6, vec3(float(k), d, e));
        }
    }
}

void test_smooth_operators(vec3 c) {
    float a = c.x * 4.0 - 2.0, b = c.y * 4.0 - 2.0, k = c.z;
    float s = kit_op_smin(a, b, k);
    expect(s <= min(a, b) && s >= min(a, b) - 0.25 * k - 1e-6, vec3(a, b, s));
    float x = kit_op_smax(a, b, k);
    expect(x >= max(a, b) && x <= max(a, b) + 0.25 * k + 1e-6, vec3(a, b, x));
    expect_eq(kit_op_smin(a, b, 0.0), min(a, b));
    expect_eq(kit_op_smin(a, b, -1.0), min(a, b));
    expect_eq(kit_op_ssubtract(a, b, 0.0), kit_op_subtract(a, b));
    // blend: the same distance as smin, a weight 0..1 that follows the nearer shape
    vec2 m = kit_op_smin_blend(a, b, k);
    expect_eq(m.x, k > 0.0 ? s : min(a, b));
    expect(m.y >= 0.0 && m.y <= 1.0, m.y);
    if (a < b - k) expect_eq(m.y, 0.0);
    if (b < a - k) expect_eq(m.y, 1.0);
}

void test_plain_operators() {
    expect_eq(kit_op_union(0.3, -0.2), -0.2);
    expect_eq(kit_op_subtract(0.3, -0.2), 0.3);
    expect_eq(kit_op_subtract(-0.5, -0.2), 0.2);
    expect_eq(kit_op_intersect(0.3, -0.2), 0.3);
    expect_near(kit_op_round(0.3, 0.1), 0.2, 1e-7);
    expect_near(kit_op_onion(-0.5, 0.1), 0.4, 1e-7);
    expect_eq(kit_op_union(vec2(0.5, 1.0), vec2(0.2, 2.0)), vec2(0.2, 2.0));
    expect_eq(kit_op_union(vec2(0.5, 1.0), vec2(0.5, 2.0)), vec2(0.5, 1.0));   // a on a tie
    expect_eq(kit_op_smin_blend(0.1, 0.2, 0.0), vec2(0.1, 0.0));
    expect_eq(kit_op_smin_blend(0.3, 0.2, 0.0), vec2(0.2, 1.0));
}

void test_repeat(vec2 c) {
    vec2 p = c * 40.0 - 20.0, s = vec2(1.5, 2.5);
    vec2 q = kit_op_repeat(p, s);
    expect(all(lessThanEqual(abs(q), 0.5 * s + 1e-5)), q);
    ivec2 id = kit_op_repeat_id(p, s);
    expect_near(q + s * vec2(id), p, 1e-4);              // the copy and the id agree
    vec3 p3 = vec3(p, p.x - p.y), s3 = vec3(s, 0.75);
    expect_near(kit_op_repeat(p3, s3) + s3 * vec3(kit_op_repeat_id(p3, s3)), p3, 1e-4);
}

void test_repeat_limited(vec2 c) {
    vec2 p = c * 40.0 - 20.0, s = vec2(1.5, 2.0), n = vec2(2.0, 0.0);
    vec2 q = kit_op_repeat_limited(p, s, n);
    expect_eq(q.y, p.y);                                  // n = 0: no repeat on that axis
    if (abs(p.x) < 2.5 * s.x) expect_near(q.x, kit_op_repeat(p, s).x, 1e-5);
    if (p.x > 2.5 * s.x) expect_near(q.x, p.x - 2.0 * s.x, 1e-5);   // the last copy
    vec3 q3 = kit_op_repeat_limited(vec3(p, 0.3), vec3(s, 1.0), vec3(1.0));
    expect(abs(q3.z - 0.3) < 1e-6, q3);
}

void test_repeat_polar(vec2 c) {
    vec2 p = (c * 2.0 - 1.0) * 5.0;
    if (length(p) < 1e-3) return;
    float n = 7.0, cell = 6.2831853 / n;
    vec2 q = kit_op_repeat_polar(p, n);
    expect_near(length(q), length(p), 1e-4 * length(p));        // a rotation
    expect(abs(atan(q.y, q.x)) <= 0.5 * cell + 1e-4, q);        // into the copy on +x
    float a = atan(p.y, p.x) + cell;                             // one copy round: the same
    expect_near(kit_op_repeat_polar(length(p) * vec2(cos(a), sin(a)), n), q, 2e-4 * length(p));
}

void test_repeat_polar_edge_cases() {
    expect_eq(kit_op_repeat_polar(vec2(0.0), 6.0), vec2(0.0));
    expect_near(kit_op_repeat_polar(vec2(0.0, 2.0), 1.0), vec2(0.0, 2.0), 1e-5);   // one copy
    expect_near(kit_op_repeat_polar(vec2(0.0, 2.0), 0.0), vec2(0.0, 2.0), 1e-5);   // n < 1
    expect_near(kit_op_repeat_polar(vec2(0.0, 2.0), 4.9), vec2(2.0, 0.0), 1e-5);   // 4 copies
}
