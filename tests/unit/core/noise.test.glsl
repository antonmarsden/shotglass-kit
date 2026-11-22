// core/noise.glsl: integer hashes give the same bits everywhere (checked against values
// computed on the CPU), and the noises stay in their documented ranges.
#include <kit/noise.glsl>

// The reference values are lowbias32 computed in 64-bit integer arithmetic on the CPU.
void test_hash_u_matches_the_cpu() {
    expect(kit_hash_u(0u) == 0u);
    expect(kit_hash_u(1u) == 0x688990c0u, float(kit_hash_u(1u)));
    expect(kit_hash_u(2u) == 0xd1132181u, float(kit_hash_u(2u)));
    expect(kit_hash_u(12345u) == 0x912efcf7u, float(kit_hash_u(12345u)));
    expect(kit_hash_u(0xffffffffu) == 0x6768824au, float(kit_hash_u(0xffffffffu)));
    expect(kit_hash_u(uvec2(3u, 7u)) == 0x0795498eu, float(kit_hash_u(uvec2(3u, 7u))));
    expect(kit_hash_u(uvec3(1u, 2u, 3u)) == 0x2f60c84eu, float(kit_hash_u(uvec3(1u, 2u, 3u))));
}

void test_hash_matches_the_cpu() {
    // 24 bits as a float: exact in float32
    expect_eq(kit_hash(1), 0.40834903717041016);
    expect_eq(kit_hash(ivec2(3, 7)), 0.029621660709381104);
    expect_eq(kit_hash(ivec3(1, 2, 3)), 0.18507051467895508);
}

void test_hash_range(vec2 c) {
    ivec2 cell = ivec2(floor(c * 2000.0)) - 1000;
    float h2 = kit_hash(cell), h3 = kit_hash(ivec3(cell, 7));
    expect(h2 >= 0.0 && h2 < 1.0, h2);
    expect(h3 >= 0.0 && h3 < 1.0, h3);
    float hp = kit_hash(c * 10.0 - 5.0), hq = kit_hash(vec3(c, 0.5));
    expect(hp >= 0.0 && hp < 1.0, hp);
    expect(hq >= 0.0 && hq < 1.0, hq);
}

// A rough look at the distribution: 4096 consecutive seeds, mean 1/2, variance 1/12,
// and no value repeated next to itself.
void test_hash_distribution() {
    float sum = 0.0, sq = 0.0;
    int repeats = 0;
    float prev = -1.0;
    for (int i = 0; i < 4096; i++) {
        float h = kit_hash(i);
        sum += h;
        sq += h * h;
        if (h == prev) repeats++;
        prev = h;
    }
    float mean = sum / 4096.0;
    expect_near(mean, 0.5, 0.02);
    expect_near(sq / 4096.0 - mean * mean, 1.0 / 12.0, 0.005);
    expect_eq(repeats, 0);
}

void test_float_hash_uses_exact_bits() {
    expect(kit_hash(vec2(0.0, 1.0)) != kit_hash(vec2(-0.0, 1.0)));
    expect(kit_hash(vec2(0.5, 1.0)) != kit_hash(vec2(0.5000001, 1.0)));
    expect_eq(kit_hash(vec3(0.25, 0.5, 0.75)), kit_hash(vec3(0.25, 0.5, 0.75)));
}

void test_value_noise_range_and_cells(vec2 c) {
    vec2 p = c * 40.0 - 20.0;
    float n2 = kit_value_noise(p);
    float n3 = kit_value_noise(vec3(p, 0.37 * p.x));
    expect(n2 >= 0.0 && n2 <= 1.0, n2);
    expect(n3 >= 0.0 && n3 <= 1.0, n3);
    // at whole-number points it is the cell's hash
    vec2 i = floor(p);
    expect_eq(kit_value_noise(i), kit_hash(ivec2(i)));
    expect_eq(kit_value_noise(vec3(i, 3.0)), kit_hash(ivec3(ivec2(i), 3)));
}

// Smooth: the smoothstep fade's slope is at most 1.5, and hashes differ by at most 1.
void test_value_noise_is_continuous(vec2 c) {
    vec2 p = c * 40.0 - 20.0;
    float h = 1e-3;
    float n = kit_value_noise(p);
    expect(abs(kit_value_noise(p + vec2(h, 0.0)) - n) <= 1.5 * h + 1e-5, n);
    expect(abs(kit_value_noise(p + vec2(0.0, h)) - n) <= 1.5 * h + 1e-5, n);
    float m = kit_value_noise(vec3(p, 0.5));
    expect(abs(kit_value_noise(vec3(p, 0.5 + h)) - m) <= 1.5 * h + 1e-5, m);
}

void test_gradient_noise(vec2 c) {
    vec2 p = c * 40.0 - 20.0;
    float n = kit_gradient_noise(p);
    expect(abs(n) <= 1.0 + 1e-5, n);             // gradients of length sqrt(2): |n| <= 1
    expect_eq(kit_gradient_noise(floor(p)), 0.0); // 0 at every whole-number point
    // continuous: gradients sqrt(2) long, fade slope 1.875
    float h = 1e-3;
    expect(abs(kit_gradient_noise(p + vec2(h, 0.0)) - n) <= 4.0 * h, n);
}

void test_fbm(vec2 c) {
    vec2 p = c * 20.0 - 10.0;
    for (int o = 1; o <= 12; o += 3) {
        float f2 = kit_fbm(p, o), f3 = kit_fbm(vec3(p, 1.5), o);
        expect(f2 >= 0.0 && f2 <= 1.0, f2);
        expect(f3 >= 0.0 && f3 <= 1.0, f3);
    }
    // one octave is plain value noise; no octaves is 0
    expect_eq(kit_fbm(p, 1), kit_value_noise(p));
    expect_eq(kit_fbm(p, 0), 0.0);
    expect_eq(kit_fbm(vec3(p, 1.5), 0), 0.0);
}
