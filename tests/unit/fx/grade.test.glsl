// fx/grade.glsl: the grade is the identity at its defaults, and each control does what its
// header says. (The file's params are macros, so the tests avoid the names lift and gain.)
#include <fx/ops.glsl>

const vec3 NONE_LO = vec3(0.0);
const vec3 NONE_GN = vec3(1.0);

void test_defaults_change_nothing(vec3 c) {
    expect_near(kit_fx_grade(c, 0.0, 1.0, 1.0, NONE_LO, NONE_GN), c, 1e-6);
}

void test_exposure_is_stops() {
    expect_near(kit_fx_grade(vec3(0.1, 0.2, 0.25), 1.0, 1.0, 1.0, NONE_LO, NONE_GN), vec3(0.2, 0.4, 0.5), 1e-6);
    expect_near(kit_fx_grade(vec3(0.4, 0.2, 0.8), -2.0, 1.0, 1.0, NONE_LO, NONE_GN), vec3(0.1, 0.05, 0.2), 1e-6);
}

void test_lift_raises_blacks_and_keeps_whites() {
    expect_near(kit_fx_grade(vec3(0.0), 0.0, 1.0, 1.0, vec3(0.1, 0.2, 0.3), NONE_GN), vec3(0.1, 0.2, 0.3), 1e-6);
    expect_near(kit_fx_grade(vec3(1.0), 0.0, 1.0, 1.0, vec3(0.1, 0.2, 0.3), NONE_GN), vec3(1.0), 1e-6);
}

void test_gain_multiplies() {
    expect_near(kit_fx_grade(vec3(0.5), 0.0, 1.0, 1.0, NONE_LO, vec3(0.5, 1.0, 1.5)), vec3(0.25, 0.5, 0.75), 1e-6);
}

void test_contrast_pivots_on_mid_grey(vec3 c) {
    expect_near(kit_fx_grade(vec3(0.5), 0.0, 3.0, 1.0, NONE_LO, NONE_GN), vec3(0.5), 1e-6);
    expect_near(kit_fx_grade(vec3(0.25), 0.0, 0.0, 1.0, NONE_LO, NONE_GN), vec3(0.5), 1e-6);
}

void test_zero_saturation_is_grey(vec3 c) {
    vec3 r = kit_fx_grade(c, 0.0, 1.0, 0.0, NONE_LO, NONE_GN);
    expect_near(r.x, r.y, 1e-6);
    expect_near(r.y, r.z, 1e-6);
    expect_near(r.x, dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
}

// Whatever the controls, the result stays a displayable colour.
void test_output_in_range(vec3 c) {
    vec3 r = kit_fx_grade(c, 3.0, 4.0, 3.0, vec3(0.5), vec3(2.0));
    expect(all(greaterThanEqual(r, vec3(0.0))) && all(lessThanEqual(r, vec3(1.0))), r);
    vec3 s = kit_fx_grade(c, -3.0, 0.1, 0.0, vec3(-0.5), vec3(0.0));
    expect(all(greaterThanEqual(s, vec3(0.0))) && all(lessThanEqual(s, vec3(1.0))), s);
}
