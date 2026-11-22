// core/raymarch.glsl, on a scene with known answers: a unit sphere at the origin on the
// floor y = -1.
#include <kit/raymarch.glsl>
#include <kit/sdf.glsl>

float kit_scene(vec3 p) {
    return min(kit_sd_sphere(p, 1.0), kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 1.0));
}

void test_raymarch_hits_and_misses() {
    expect_near(kit_raymarch(vec3(0.0, 0.0, 5.0), vec3(0.0, 0.0, -1.0), 128, 1e-4, 20.0), 4.0, 2e-4);
    expect_near(kit_raymarch(vec3(3.0, 2.0, 0.0), vec3(0.0, -1.0, 0.0), 128, 1e-4, 20.0), 3.0, 2e-4);
    expect_eq(kit_raymarch(vec3(0.0, 0.0, 5.0), vec3(0.0, 1.0, 0.0), 128, 1e-4, 20.0), -1.0);
    expect_eq(kit_raymarch(vec3(0.0, 0.0, 5.0), vec3(0.0, 0.0, -1.0), 128, 1e-4, 3.0), -1.0);  // tmax
    expect_eq(kit_raymarch(vec3(0.0, 0.0, 5.0), vec3(0.0, 0.0, -1.0), 1, 1e-4, 20.0), -1.0);   // steps
}

// From a ring of cameras, every ray aimed at the sphere hits it at the analytic distance.
void test_raymarch_matches_the_sphere(vec2 c) {
    float a = 6.2831853 * c.x;
    vec3 ro = vec3(4.0 * cos(a), 0.5, 4.0 * sin(a));
    vec3 aim = vec3(0.0, 0.0, 0.0) + 0.9 * (c.y - 0.5) * vec3(-sin(a), 1.0, cos(a));
    vec3 rd = normalize(aim - ro);
    float b = dot(ro, rd), disc = b * b - (dot(ro, ro) - 1.0);
    float t = kit_raymarch(ro, rd, 256, 1e-5, 20.0);
    if (disc > 1e-3) {
        float want = -b - sqrt(disc);
        // or the floor first, which a ray can only meet after the sphere here if it misses it
        expect_near(t, want, 2e-3);
    }
}

void test_normal(vec2 c) {
    float th = 6.2831853 * c.x, ph = 0.1 + 1.4 * c.y;   // upper part, away from the floor
    vec3 n = vec3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th));
    expect_near(kit_normal(n, 1e-3), n, 2e-3);
    expect_near(length(kit_normal(n, 1e-3)), 1.0, 1e-5);
}

void test_normal_of_the_floor() {
    expect_near(kit_normal(vec3(5.0, -1.0, 3.0), 1e-3), vec3(0.0, 1.0, 0.0), 1e-4);
}

void test_soft_shadow() {
    vec3 up = vec3(0.0, 1.0, 0.0);
    float under = kit_soft_shadow(vec3(0.0, -0.998, 0.0), up, 0.01, 10.0, 8.0);
    float open = kit_soft_shadow(vec3(6.0, -0.998, 0.0), up, 0.01, 10.0, 8.0);
    float edge = kit_soft_shadow(vec3(1.1, -0.998, 0.0), up, 0.01, 10.0, 8.0);
    expect_near(under, 0.0, 1e-3);
    expect_near(open, 1.0, 1e-3);
    expect(edge > under && edge < open, edge);   // the penumbra is in between
}

void test_soft_shadow_range(vec2 c) {
    vec3 p = vec3(c.x * 6.0 - 3.0, -0.998, c.y * 6.0 - 3.0);
    float s = kit_soft_shadow(p, normalize(vec3(0.3, 1.0, 0.2)), 0.01, 10.0, 8.0);
    expect(s >= 0.0 && s <= 1.0, s);
}

void test_ao() {
    vec3 up = vec3(0.0, 1.0, 0.0);
    expect_near(kit_ao(vec3(6.0, -1.0, 0.0), up, 0.3), 1.0, 1e-5);   // open floor
    float crease = kit_ao(vec3(0.3, -1.0 + 1e-4, 0.0), up, 0.3);       // where the sphere meets it
    expect(crease < 0.7, crease);
    expect(crease >= 0.0, crease);
}
