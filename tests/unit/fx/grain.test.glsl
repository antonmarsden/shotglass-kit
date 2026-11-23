// fx/grain.glsl: bounded, deterministic, new every frame, zero-mean, the same as core's
// kit_grain with one channel, and independent per channel with tint.
#include <fx/ops.glsl>
#include <kit/color.glsl>

void test_zero_strength_changes_nothing(vec3 c) {
    expect_eq(kit_fx_grain(c, c.xy * 1000.0, 7, 0.0, 0.0), c);
    expect_eq(kit_fx_grain(c, c.xy * 1000.0, 7, 0.0, 1.0), c);
}

// From mid grey (where nothing clamps), the grain stays within +-strength/2.
void test_grain_is_bounded(vec2 p) {
    float s = 0.2;
    vec3 r = kit_fx_grain(vec3(0.5), p * 500.0, int(p.x * 100.0), s, 1.0);
    expect(all(lessThanEqual(abs(r - 0.5), vec3(0.5 * s + 1e-6))), r);
}

void test_same_frame_same_grain(vec2 p) {
    vec2 fc = p * 640.0;
    expect_eq(kit_fx_grain(vec3(0.5), fc, 12, 0.1, 1.0), kit_fx_grain(vec3(0.5), fc, 12, 0.1, 1.0));
}

void test_matches_core_grain(vec2 p) {
    vec2 fc = p * 640.0;
    expect_near(kit_fx_grain(vec3(0.5), fc, 3, 0.1, 0.0), kit_grain(vec3(0.5), fc, 3, 0.1), 1e-6);
}

// tint 0: one grain for all three channels; tint 1: three different ones.
void test_tint(vec2 p) {
    vec3 a = kit_fx_grain(vec3(0.5), p * 640.0, 1, 0.2, 0.0) - 0.5;
    expect_eq(a.x, a.y);
    expect_eq(a.y, a.z);
}

void test_grain_changes_with_frame_and_position_and_channel() {
    vec3 a = kit_fx_grain(vec3(0.5), vec2(10.5, 20.5), 0, 0.2, 1.0);
    expect(a != kit_fx_grain(vec3(0.5), vec2(10.5, 20.5), 1, 0.2, 1.0));
    expect(a != kit_fx_grain(vec3(0.5), vec2(11.5, 20.5), 0, 0.2, 1.0));
    expect(a.x != a.y && a.y != a.z, a);
}

// Over a block of pixels the grain averages out to nothing: it doesn't brighten or darken.
void test_grain_has_no_bias() {
    vec3 sum = vec3(0.0);
    for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
            sum += kit_fx_grain(vec3(0.5), vec2(float(x), float(y)) + 0.5, 5, 1.0, 1.0) - 0.5;
        }
    }
    expect_near(sum / 4096.0, vec3(0.0), 0.02);
}
