// buffer/math.glsl: the maths of feedback buffers, on plain values.
#include <buffer/math.glsl>

// --- decay -----------------------------------------------------------------------

void test_decay_halves_after_one_half_life(float t) {
    float h = mix(0.05, 10.0, t);
    expect_near(kit_buf_decay(h, h), 0.5, 1e-6);
    expect_near(kit_buf_decay(h, 2.0 * h), 0.25, 1e-6);
}

// Frame-rate independent: n steps at fps n give the same decay over a second.
void test_decay_is_frame_rate_independent(float t) {
    float h = mix(0.1, 4.0, t);
    float at24 = pow(kit_buf_decay(h, 1.0 / 24.0), 24.0);
    float at60 = pow(kit_buf_decay(h, 1.0 / 60.0), 60.0);
    expect_rel(at24, kit_buf_decay(h, 1.0), 1e-4);
    expect_rel(at60, kit_buf_decay(h, 1.0), 1e-4);
}

void test_decay_endpoints() {
    expect_eq(kit_buf_decay(1.0, 0.0), 1.0);
    expect_eq(kit_buf_decay(0.0, 0.04), 0.0);
    expect_eq(kit_buf_decay(-1.0, 0.04), 0.0);
    expect_eq(kit_buf_decay(1.0, -1.0), 1.0);
}

void test_decay_in_range(vec2 v) {
    float d = kit_buf_decay(mix(0.01, 10.0, v.x), v.y);
    expect(d >= 0.0 && d <= 1.0, d);
}

// --- trails ----------------------------------------------------------------------

void test_trail_keeps_the_brighter(vec3 c) {
    vec4 prev = vec4(c, 1.0);
    vec4 elem = vec4(c.zyx, 0.5);
    vec4 r = kit_buf_trail(prev, elem, 0.5, 0.5);
    expect_near(r, max(elem, prev * 0.5), 1e-6);
}

void test_trail_stays_premultiplied(vec3 c) {
    vec4 prev = vec4(c * c.x, c.x);           // rgb <= a
    vec4 elem = vec4(c.yzx * c.y, c.y);
    vec4 r = kit_buf_trail(prev, elem, 0.3, 1.0 / 30.0);
    expect(all(lessThanEqual(r.rgb, vec3(r.a + 1e-6))), r);
    vec4 o = kit_buf_trail_over(prev, elem, 0.3, 1.0 / 30.0);
    expect(all(lessThanEqual(o.rgb, vec3(o.a + 1e-6))) && o.a <= 1.0 + 1e-6, o);
}

void test_trail_over_endpoints() {
    vec4 prev = vec4(0.2, 0.4, 0.6, 0.8);
    expect_near(kit_buf_trail_over(prev, vec4(0.0), 1.0, 1.0), prev * 0.5, 1e-6);
    vec4 opaque = vec4(0.1, 0.2, 0.3, 1.0);
    expect_eq(kit_buf_trail_over(prev, opaque, 1.0, 1.0), opaque);
}

// --- Laplacians ------------------------------------------------------------------

void test_laplacians_vanish_on_ramps(vec3 g) {
    vec2 k = g.xy * 4.0 - 2.0;               // any slope
    float c = g.z;
    float e = c + k.x, w = c - k.x, n = c + k.y, s = c - k.y;
    expect_near(kit_buf_laplacian(vec4(c), vec4(e), vec4(w), vec4(n), vec4(s)), vec4(0.0), 1e-5);
    float corners = (c + k.x + k.y) + (c - k.x + k.y) + (c + k.x - k.y) + (c - k.x - k.y);
    expect_near(kit_buf_laplacian(vec4(c), vec4(e + w + n + s), vec4(corners)), vec4(0.0), 1e-5);
}

// x² + y² has Laplacian 4 everywhere: both stencils are exact on quadratics.
void test_laplacians_of_a_paraboloid(vec2 v) {
    vec2 p = v * 10.0 - 5.0;
    float c = dot(p, p);
    float e = dot(p + vec2(1, 0), p + vec2(1, 0)), w = dot(p - vec2(1, 0), p - vec2(1, 0));
    float n = dot(p + vec2(0, 1), p + vec2(0, 1)), s = dot(p - vec2(0, 1), p - vec2(0, 1));
    expect_near(kit_buf_laplacian(vec4(c), vec4(e), vec4(w), vec4(n), vec4(s)).x, 4.0, 1e-4);
    float corners = dot(p + vec2(1, 1), p + vec2(1, 1)) + dot(p + vec2(-1, 1), p + vec2(-1, 1)) +
                    dot(p + vec2(1, -1), p + vec2(1, -1)) + dot(p - vec2(1, 1), p - vec2(1, 1));
    expect_near(kit_buf_laplacian(vec4(c), vec4(e + w + n + s), vec4(corners)).x, 4.0, 1e-4);
}

// --- wave ------------------------------------------------------------------------

void test_wave_flat_water_stays_flat(float t) {
    expect_eq(kit_buf_wave(0.0, 0.0, 0.0, t, 1.0, 1.0 / 30.0), 0.0);
}

void test_wave_keeps_moving_without_curvature() {
    // No curvature, no damping: constant velocity (2 * cur - prev).
    expect_near(kit_buf_wave(0.3, 0.1, 0.0, 0.5, 1e30, 1.0 / 30.0), 0.5, 1e-6);
    // Damping by one half-life halves it; a zero half-life stops it.
    expect_near(kit_buf_wave(0.3, 0.1, 0.0, 0.5, 1.0, 1.0), 0.25, 1e-6);
    expect_eq(kit_buf_wave(0.3, 0.1, 0.0, 0.5, 0.0, 1.0), 0.0);
}

void test_wave_speed_is_clamped() {
    expect_near(kit_buf_wave(0.0, 0.0, 1.0, 5.0, 1e30, 0.0), 0.49, 1e-6);
    expect_eq(kit_buf_wave(0.0, 0.0, 1.0, -1.0, 1e30, 0.0), 0.0);
}

// --- Gray-Scott ------------------------------------------------------------------

void test_gray_scott_empty_state_is_fixed() {
    expect_eq(kit_buf_gray_scott(vec2(1.0, 0.0), vec2(0.0), kit_buf_gs_coral()), vec2(1.0, 0.0));
    expect_eq(kit_buf_gray_scott(vec2(1.0, 0.0), vec2(0.0), kit_buf_gs_mitosis()), vec2(1.0, 0.0));
    expect_eq(kit_buf_gray_scott(vec2(1.0, 0.0), vec2(0.0), kit_buf_gs_maze()), vec2(1.0, 0.0));
    expect_eq(kit_buf_gray_scott(vec2(1.0, 0.0), vec2(0.0), kit_buf_gs_spots()), vec2(1.0, 0.0));
    expect_eq(kit_buf_gray_scott(vec2(1.0, 0.0), vec2(0.0), kit_buf_gs_waves()), vec2(1.0, 0.0));
}

void test_gray_scott_known_step() {
    // A = 0.5, B = 0.25, flat: abb = 0.03125.
    vec2 fk = vec2(0.04, 0.06);
    vec2 r = kit_buf_gray_scott(vec2(0.5, 0.25), vec2(0.0), fk);
    expect_near(r, vec2(0.5 - 0.03125 + 0.02, 0.25 + 0.03125 - 0.025), 1e-6);
    // Diffusion: A at 1/4 and B at 1/8 of the Laplacian.
    r = kit_buf_gray_scott(vec2(0.5, 0.5), vec2(0.4, 0.4), vec2(0.0));
    expect_near(r, vec2(0.5 - 0.125 + 0.1, 0.5 + 0.125 + 0.05), 1e-6);
}

void test_gray_scott_in_range(vec3 v) {
    vec2 lap = (v.z - 0.5) * vec2(8.0, -8.0);
    vec2 r = kit_buf_gray_scott(v.xy, lap, kit_buf_gs_coral());
    expect(all(greaterThanEqual(r, vec2(0.0))) && all(lessThanEqual(r, vec2(1.0))), r);
}

void test_presets_are_in_the_documented_range() {
    vec2 p[5] = vec2[5](kit_buf_gs_coral(), kit_buf_gs_mitosis(), kit_buf_gs_maze(),
                        kit_buf_gs_spots(), kit_buf_gs_waves());
    for (int i = 0; i < 5; i++) expect(all(greaterThan(p[i], vec2(0.0))) && all(lessThan(p[i], vec2(0.1))), p[i]);
}

// --- life ------------------------------------------------------------------------

void test_life_rule() {
    expect_eq(kit_buf_life(0.0, 3.0), 1.0);   // birth
    expect_eq(kit_buf_life(0.0, 2.0), 0.0);
    expect_eq(kit_buf_life(1.0, 2.0), 1.0);   // survival
    expect_eq(kit_buf_life(1.0, 3.0), 1.0);
    expect_eq(kit_buf_life(1.0, 1.0), 0.0);   // loneliness
    expect_eq(kit_buf_life(1.0, 4.0), 0.0);   // crowding
    expect_eq(kit_buf_life(1.0, 2.9), 1.0);   // counts round
}

// --- transforms ------------------------------------------------------------------

void test_zoom_uv_identity_and_fixed_point(vec2 uv) {
    expect_near(kit_buf_zoom_uv(uv, vec2(0.3, 0.6), 1.0, 0.0, 1.777), uv, 1e-6);
    vec2 c = vec2(0.3, 0.6);
    expect_near(kit_buf_zoom_uv(c, c, 1.3, 0.7, 1.777), c, 1e-6);
}

void test_zoom_uv_scales_and_turns_round() {
    // Growing 2x: the texel at 0.25 from the centre came from 0.125.
    expect_near(kit_buf_zoom_uv(vec2(0.75, 0.5), vec2(0.5), 2.0, 0.0, 2.0), vec2(0.625, 0.5), 1e-6);
    // A quarter turn anticlockwise at aspect 2: (x + 0.25 uv) is 0.5 heights right of the
    // centre; it came from 0.5 heights below it.
    expect_near(kit_buf_zoom_uv(vec2(0.75, 0.5), vec2(0.5), 1.0, 1.57079633, 2.0), vec2(0.5, 0.0), 1e-6);
}

void test_advect_uv() {
    expect_near(kit_buf_advect_uv(vec2(0.5), vec2(0.3, -0.6), 0.5), vec2(0.35, 0.8), 1e-6);
    expect_eq(kit_buf_advect_uv(vec2(0.25), vec2(1.0), 0.0), vec2(0.25));
}

void test_edge_fade(vec2 v) {
    vec2 uv = v * 1.4 - 0.2;
    float f = kit_buf_edge_fade(uv, 0.1);
    expect(f >= 0.0 && f <= 1.0, f);
    bool outside = any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)));
    if (outside) expect_eq(f, 0.0);
    bool deep = all(greaterThanEqual(uv, vec2(0.1))) && all(lessThanEqual(uv, vec2(0.9)));
    if (deep) expect_eq(f, 1.0);
}

void test_edge_fade_hard() {
    expect_eq(kit_buf_edge_fade(vec2(0.0, 1.0), 0.0), 1.0);
    expect_eq(kit_buf_edge_fade(vec2(-0.001, 0.5), 0.0), 0.0);
    expect_near(kit_buf_edge_fade(vec2(0.05, 0.5), 0.1), 0.5, 1e-6);
}

// --- seeds -----------------------------------------------------------------------

void test_seed_disc() {
    expect_eq(kit_buf_seed_disc(vec2(0.5), vec2(0.5), 0.1, 0.02), 1.0);
    expect_eq(kit_buf_seed_disc(vec2(0.9), vec2(0.5), 0.1, 0.02), 0.0);
    expect_near(kit_buf_seed_disc(vec2(0.6, 0.5), vec2(0.5), 0.1, 0.02), 0.5, 1e-4);
    expect_eq(kit_buf_seed_disc(vec2(0.55, 0.5), vec2(0.5), 0.1, 0.0), 1.0);
}

// samples: 65536
void test_seed_noise_density(vec2 v) {
    ivec2 cell = ivec2(v * 255.0);
    float a = kit_buf_seed_noise(cell, 7, 0.0);
    float b = kit_buf_seed_noise(cell, 7, 1.0);
    expect_eq(a, 0.0);
    expect_eq(b, 1.0);
    float c = kit_buf_seed_noise(cell, 7, 0.3);
    expect(c == 0.0 || c == 1.0, c);
}

// The density holds on average over a block of cells.
void test_seed_noise_mean() {
    float sum = 0.0;
    for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) sum += kit_buf_seed_noise(ivec2(x, y), 3, 0.25);
    }
    expect_near(sum / 4096.0, 0.25, 0.03);
}

void test_drop() {
    expect_eq(kit_buf_drop(vec2(0.4), vec2(0.4), 0.05), 1.0);
    expect_near(kit_buf_drop(vec2(0.45, 0.4), vec2(0.4), 0.05), 0.1, 1e-5);
}

void test_drop_falls_off(float t) {
    float a = kit_buf_drop(vec2(t, 0.0), vec2(0.0), 0.2);
    float b = kit_buf_drop(vec2(t + 0.01, 0.0), vec2(0.0), 0.2);
    expect(b <= a && a >= 0.0 && a <= 1.0, vec2(a, b));
}

// --- packing ---------------------------------------------------------------------

vec4 rgba8(vec4 c) { return floor(c * 255.0 + 0.5) / 255.0; }

void test_signed_round_trip(vec3 v) {
    vec4 x = vec4(v * 2.0 - 1.0, 0.0) * 3.0;
    expect_near(kit_buf_unpack_signed(kit_buf_pack_signed(x, 3.0), 3.0), x, 1e-5);
    // Through rgba8: within half a step, range / 255.
    expect_near(kit_buf_unpack_signed(rgba8(kit_buf_pack_signed(x, 3.0)), 3.0), x, 3.0 / 255.0 + 1e-5);
}

void test_signed_pack_clamps() {
    expect_eq(kit_buf_pack_signed(vec4(-10.0, 10.0, 0.0, 1.0), 1.0), vec4(0.0, 1.0, 0.5, 1.0));
}

void test_pack16_round_trip(float x) {
    vec2 c = kit_buf_pack16(x);
    expect_eq(rgba8(vec4(c, 0.0, 0.0)).xy, c);            // survives an 8-bit store exactly
    expect_near(kit_buf_unpack16(c), x, 0.5 / 65535.0 + 1e-7);
}

void test_pack16_endpoints() {
    expect_eq(kit_buf_pack16(0.0), vec2(0.0));
    expect_eq(kit_buf_pack16(1.0), vec2(1.0));
    expect_eq(kit_buf_unpack16(vec2(1.0)), 1.0);
    expect_eq(kit_buf_pack16(-1.0), vec2(0.0));
}
