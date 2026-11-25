// core/noise.glsl: integer hashes give the same bits everywhere (checked against values
// computed on the CPU), and the noises stay in their documented ranges.
#include <kit/noise.glsl>

void test_cellular_noise(vec2 c) {
    vec2 p = (c - 0.5) * 32.0;
    vec2 f = kit_cellular_noise(p);
    expect(f.x >= 0.0 && f.x <= f.y && f.y <= 1.288, f.y);

    // Distances to the first and second nearest features are both 1-Lipschitz.
    const float step_size = 0.001953125;
    vec2 shifted = kit_cellular_noise(p + vec2(step_size, 0.0));
    expect(all(lessThanEqual(abs(shifted - f), vec2(step_size + 1e-6))), shifted.y);
}

void test_cellular_noise_feature() {
    ivec2 cell = ivec2(-3, 2);
    vec2 p = vec2(cell) + 0.375 + 0.25 * vec2(kit_hash(ivec3(cell, 0)),
                                             kit_hash(ivec3(cell, 1)));
    vec2 f = kit_cellular_noise(p);
    expect_near(f.x, 0.0, 1e-6);
    expect(f.y >= 0.75, f.y);
}

void test_simplex_flow_period_and_gradient(vec2 c) {
    // Binary fractions keep the test coordinates exact after adding a period.
    vec2 p = (floor(c * 255.0 + 0.5) - 128.0) * (1.0 / 16.0);
    ivec2 period = ivec2(7, 4);
    float angle = 1.7;
    vec2 g, gx, gy, unused;
    float n = kit_simplex_flow(p, period, angle, g);
    expect(abs(n) <= 1.05, n);
    expect_near(kit_simplex_flow(p + vec2(7.0, 0.0), period, angle, gx), n, 1e-5);
    expect_near(kit_simplex_flow(p - vec2(0.0, 4.0), period, angle, gy), n, 1e-5);
    expect_near(gx, g, 1e-5);
    expect_near(gy, g, 1e-5);

    const float h = 0.001953125;
    vec2 dx = vec2(h, 0.0), dy = vec2(0.0, h);
    vec2 positive = vec2(kit_simplex_flow(p + dx, period, angle, unused),
                         kit_simplex_flow(p + dy, period, angle, unused));
    vec2 negative = vec2(kit_simplex_flow(p - dx, period, angle, unused),
                         kit_simplex_flow(p - dy, period, angle, unused));
    expect_near((positive - negative) / (2.0 * h), g, 3e-4);
}

void test_simplex_flow_rotation() {
    vec2 p = vec2(-0.25, 0.37);
    vec2 g, rotated;
    float n = kit_simplex_flow(p, ivec2(0), 0.0, g);
    expect_near(kit_simplex_flow(p, ivec2(0), 3.14159265, rotated), -n, 1e-6);
    expect_near(rotated, -g, 1e-6);
}

void test_curl_noise_rotates_gradient(vec2 c) {
    vec2 p = (2.0 * c - 1.0) * 1048575.0;
    float angle = 6.28318531 * c.x;
    ivec2 period = ivec2(c.x < 0.5 ? 0 : 1048576, c.y < 0.5 ? 0 : 1048576);
    vec2 gradient;
    kit_simplex_flow(p, period, angle, gradient);
    expect_near(kit_curl_noise(p, period, angle), vec2(gradient.y, -gradient.x), 1e-5);
}

void test_curl_noise_tiles_and_loops(vec2 c) {
    // Binary fractions keep period shifts exact, including across negative coordinates.
    vec2 p = (floor(c * 255.0 + 0.5) - 128.0) / 16.0;
    ivec2 period = ivec2(6, 4);
    float angle = 6.28318531 * c.x;
    vec2 field = kit_curl_noise(p, period, angle);
    expect_near(kit_curl_noise(p + vec2(6.0, 0.0), period, angle), field, 1e-5);
    expect_near(kit_curl_noise(p - vec2(0.0, 4.0), period, angle), field, 1e-5);

    // Endpoints and periods of the visual fixture's base field.
    vec2 start = kit_curl_noise(p, period, 0.0);
    expect_near(kit_curl_noise(p, period, 6.28318531), start, 1e-5);
}

void test_curl_noise_divergence(vec2 c) {
    // Small, exactly representable coordinates keep the step well above the
    // local float spacing. The tolerance allows central-difference truncation
    // and roundoff when subtracting neighbouring field values.
    vec2 p = (floor(c * 255.0 + 0.5) - 128.0) / 16.0;
    ivec2 period = ivec2(7, 4);
    float angle = 6.28318531 * c.y;
    const float h = 0.001953125;
    vec2 dx = vec2(h, 0.0), dy = vec2(0.0, h);
    float du = kit_curl_noise(p + dx, period, angle).x - kit_curl_noise(p - dx, period, angle).x;
    float dv = kit_curl_noise(p + dy, period, angle).y - kit_curl_noise(p - dy, period, angle).y;
    expect_near((du + dv) / (2.0 * h), 0.0, 0.002);
}

void test_dither() {
    expect_eq(kit_dither(0.0, 8, 0.01), 0.0);
    expect_eq(kit_dither(1.0, 256, 0.99), 1.0);
    expect_eq(kit_dither(0.625, 3, 0.5), 0.5);
    expect_eq(kit_dither(0.625, 3, 0.25), 1.0);
}

// The reference values are lowbias32 computed in 64-bit integer arithmetic on the CPU.
void test_hash_u_matches_the_cpu() {
    expect_eq(kit_hash_u(0u), 0u);
    expect_eq(kit_hash_u(1u), 0x688990c0u);
    expect_eq(kit_hash_u(2u), 0xd1132181u);
    expect_eq(kit_hash_u(12345u), 0x912efcf7u);
    expect_eq(kit_hash_u(0xffffffffu), 0x6768824au);
    expect_eq(kit_hash_u(uvec2(3u, 7u)), 0x0795498eu);
    expect_eq(kit_hash_u(uvec3(1u, 2u, 3u)), 0x2f60c84eu);
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
