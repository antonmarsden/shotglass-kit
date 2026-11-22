// core/camera.glsl: an orthonormal look-at basis aimed at the target, rays through
// pixels, orbit/dolly placement, dolly zoom and depth of field.
#include <kit/camera.glsl>

vec3 orbit_point(vec2 c) {
    return kit_cam_orbit(vec3(0.3, -0.2, 0.1), vec2(6.2831853 * c.x, 3.0 * c.y - 1.5), 4.0);
}

void test_look_at_is_orthonormal_and_aimed(vec2 c) {
    vec3 ta = vec3(0.3, -0.2, 0.1);
    vec3 ro = orbit_point(c);
    mat3 m = kit_cam_look_at(ro, ta, 0.7 * c.x);
    expect_near(transpose(m) * m * vec3(1.0, 2.0, 3.0), vec3(1.0, 2.0, 3.0), 1e-5);
    // (right, up, forward) with forward = the camera's +z is left-handed by design:
    // the same handedness from every viewpoint and roll, never a mirror flip
    expect_near(determinant(m), -1.0, 1e-5);
    expect_near(m[2], normalize(ta - ro), 1e-5);        // looks down its own +z
}

void test_look_at_known_frames() {
    // At (0, 0, 5) looking at the origin, +x is on the right of the screen.
    mat3 m = kit_cam_look_at(vec3(0.0, 0.0, 5.0), vec3(0.0), 0.0);
    expect_near(m[2], vec3(0.0, 0.0, -1.0), 1e-6);
    expect_near(m[1], vec3(0.0, 1.0, 0.0), 1e-6);
    expect_near(m[0], vec3(1.0, 0.0, 0.0), 1e-6);
    // positive roll rolls the camera anticlockwise: "up" leans towards -right
    mat3 r = kit_cam_look_at(vec3(0.0, 0.0, 5.0), vec3(0.0), 1.5707963);
    expect_near(r[1], -m[0], 1e-6);
    // straight down: up on screen is -z; straight up: +z
    expect_near(kit_cam_look_at(vec3(0.0, 5.0, 0.0), vec3(0.0), 0.0)[1], vec3(0.0, 0.0, -1.0), 1e-6);
    expect_near(kit_cam_look_at(vec3(0.0, -5.0, 0.0), vec3(0.0), 0.0)[1], vec3(0.0, 0.0, 1.0), 1e-6);
    // ro = ta looks down -z
    expect_near(kit_cam_look_at(vec3(1.0), vec3(1.0), 0.0)[2], vec3(0.0, 0.0, -1.0), 1e-6);
}

void test_ray_through_pixels(vec2 c) {
    mat3 m = kit_cam_look_at(vec3(0.0, 1.0, 5.0), vec3(0.0), 0.0);
    vec2 res = vec2(320.0, 180.0);
    vec3 rd = kit_cam_ray(m, c * res, res, 0.8);
    expect_near(length(rd), 1.0, 1e-6);
    expect(dot(rd, m[2]) > 0.0, rd);                     // in front of the camera
    // the vertical field of view: the top-centre pixel is fov / 2 off the axis
    vec3 top = kit_cam_ray(m, vec2(160.0, 180.0), res, 0.8);
    expect_near(acos(clamp(dot(top, m[2]), -1.0, 1.0)), 0.4, 1e-4);
}

void test_ray_centre_and_aspect() {
    mat3 m = kit_cam_look_at(vec3(0.0, 0.0, 5.0), vec3(0.0), 0.0);
    vec2 res = vec2(320.0, 180.0);
    expect_near(kit_cam_ray(m, 0.5 * res, res, 0.8), m[2], 1e-6);
    // square pixels: equal pixel offsets give equal angles horizontally and vertically
    vec3 right = kit_cam_ray(m, vec2(160.0 + 50.0, 90.0), res, 0.8);
    vec3 up = kit_cam_ray(m, vec2(160.0, 90.0 + 50.0), res, 0.8);
    expect_near(dot(right, m[2]), dot(up, m[2]), 1e-6);
}

void test_orbit(vec2 c) {
    vec3 ta = vec3(0.3, -0.2, 0.1);
    expect_near(length(orbit_point(c) - ta), 4.0, 1e-5);
    expect(abs(orbit_point(c).y - ta.y) <= 4.0 * sin(1.55) + 1e-5, orbit_point(c));   // never over the top
}

void test_orbit_values() {
    expect_near(kit_cam_orbit(vec3(0.0), vec2(0.0), 5.0), vec3(0.0, 0.0, 5.0), 1e-6);
    expect_near(kit_cam_orbit(vec3(0.0), vec2(1.5707963, 0.0), 5.0), vec3(5.0, 0.0, 0.0), 1e-5);
    expect_near(kit_cam_orbit(vec3(1.0), vec2(0.3), -2.0), vec3(1.0), 1e-6);   // dist >= 0
}

void test_dolly() {
    vec3 ro = vec3(0.0, 1.0, 6.0), ta = vec3(0.0);
    float len = length(ta - ro);
    expect_near(kit_cam_dolly(ro, ta, 2.0), ro + normalize(ta - ro) * 2.0, 1e-5);
    expect_near(kit_cam_dolly(ro, ta, -1.0), ro - normalize(ta - ro), 1e-5);
    expect_near(length(kit_cam_dolly(ro, ta, 100.0) - ta), 0.001, 1e-5);   // stops short
    expect_eq(kit_cam_dolly(ta, ta, 3.0), ta);
    expect_near(length(kit_cam_dolly(ro, ta, 1.0) - ta), len - 1.0, 1e-5);
}

// Dolly zoom keeps the subject's size: tan(fov / 2) * dist stays the same.
void test_dolly_zoom(vec2 c) {
    float fov = 0.2 + 2.0 * c.x, d0 = 6.0, d = 1.0 + 9.0 * c.y;
    float f = kit_cam_dolly_zoom(fov, d0, d);
    expect_rel(tan(0.5 * f) * d, tan(0.5 * fov) * d0, 1e-4);
    expect(f > 0.0 && f < 3.1415927, f);
    if (d < d0) expect(f > fov, vec2(f, fov));
}

void test_dolly_zoom_identity() {
    expect_near(kit_cam_dolly_zoom(0.8, 6.0, 6.0), 0.8, 1e-6);
}

// Depth of field: the new ray still passes through the pinhole ray's point on the focal
// plane, and the origin stays on the lens (within the aperture, in the right/up plane).
void test_dof(vec2 xi) {
    vec3 ro0 = vec3(0.0, 1.0, 5.0);
    mat3 cam = kit_cam_look_at(ro0, vec3(0.0), 0.0);
    vec3 rd0 = kit_cam_ray(cam, vec2(100.0, 60.0), vec2(320.0, 180.0), 0.8);
    vec3 ro = ro0, rd = rd0;
    kit_cam_dof(ro, rd, cam, 0.05, 5.1, xi);
    vec3 fp = ro0 + rd0 * (5.1 / dot(rd0, cam[2]));
    vec3 hit = ro + rd * (dot(fp - ro, cam[2]) / dot(rd, cam[2]));
    expect_near(hit, fp, 1e-4);
    expect(length(ro - ro0) <= 0.05 + 1e-6, ro - ro0);
    expect_near(dot(ro - ro0, cam[2]), 0.0, 1e-6);
    expect_near(length(rd), 1.0, 1e-6);
}

void test_dof_without_aperture() {
    vec3 ro = vec3(0.0, 1.0, 5.0);
    mat3 cam = kit_cam_look_at(ro, vec3(0.0), 0.0);
    vec3 rd0 = kit_cam_ray(cam, vec2(100.0, 60.0), vec2(320.0, 180.0), 0.8);
    vec3 rd = rd0;
    kit_cam_dof(ro, rd, cam, 0.0, 5.1, vec2(0.7, 0.3));
    expect_eq(ro, vec3(0.0, 1.0, 5.0));
    expect_near(rd, rd0, 1e-6);
}
