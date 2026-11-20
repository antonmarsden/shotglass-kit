// shotglass-kit/core: noise.glsl
//
// Hashes and noise built on integer arithmetic, so they give the same bits on every
// GPU and in browsers (sin()-based hashes don't). Same input, same output, always.
// sound: yes

// kit_hash_u(x): mixes the bits of x (lowbias32). Full 32-bit output.
//   cost: 5 integer ops (uvec2: 2 rounds, uvec3: 3)
uint kit_hash_u(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352dU;
    x ^= x >> 15;
    x *= 0x846ca68bU;
    x ^= x >> 16;
    return x;
}
uint kit_hash_u(uvec2 v) { return kit_hash_u(v.x ^ kit_hash_u(v.y + 0x9e3779b9U)); }
uint kit_hash_u(uvec3 v) {
    return kit_hash_u(v.x ^ kit_hash_u(v.y ^ kit_hash_u(v.z + 0x9e3779b9U) + 0x7f4a7c15U));
}

// 24 random bits as a float in 0..1 (exact in float32).
float kit__unit(uint h) { return float(h >> 8) * (1.0 / 16777216.0); }

// kit_hash(c): a random number in 0..1 for an integer cell (or frame, or seed).
//   e.g. float r = kit_hash(ivec2(floor(uv * 10.0)));   // one value per grid cell
float kit_hash(int c) { return kit__unit(kit_hash_u(uint(c))); }
float kit_hash(ivec2 c) { return kit__unit(kit_hash_u(uvec2(c))); }
float kit_hash(ivec3 c) { return kit__unit(kit_hash_u(uvec3(c))); }

// kit_hash(p): a random number in 0..1 for a float position, from its exact bits:
// any change to p gives an unrelated value (0.0 and -0.0 differ). For smooth
// randomness use the noise below.
float kit_hash(vec2 p) { return kit__unit(kit_hash_u(floatBitsToUint(p))); }
float kit_hash(vec3 p) { return kit__unit(kit_hash_u(floatBitsToUint(p))); }

// kit_value_noise(p): smooth noise, cells 1 unit wide.
//   p   any position; scale it for bigger or smaller blobs
//   ->  0..1
//   cost: 4 hashes (vec2), 8 (vec3)
//   e.g. float n = kit_value_noise(uv * 8.0);
//        float n = kit_value_noise(vec3(uv * 8.0, iTime));   // animated
float kit_value_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    ivec2 c = ivec2(i);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = kit_hash(c), b = kit_hash(c + ivec2(1, 0));
    float d = kit_hash(c + ivec2(0, 1)), e = kit_hash(c + ivec2(1, 1));
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}
float kit_value_noise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    ivec3 c = ivec3(i);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float n000 = kit_hash(c), n100 = kit_hash(c + ivec3(1, 0, 0));
    float n010 = kit_hash(c + ivec3(0, 1, 0)), n110 = kit_hash(c + ivec3(1, 1, 0));
    float n001 = kit_hash(c + ivec3(0, 0, 1)), n101 = kit_hash(c + ivec3(1, 0, 1));
    float n011 = kit_hash(c + ivec3(0, 1, 1)), n111 = kit_hash(c + ivec3(1, 1, 1));
    return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
               mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

// One of 8 gradient directions (4 diagonal, 4 axis), all of length sqrt(2), chosen
// by bits of h: no trigonometry, so it's exact everywhere.
vec2 kit__gradient(uint h) {
    vec2 g = vec2((h & 1U) == 0U ? 1.0 : -1.0, (h & 2U) == 0U ? 1.0 : -1.0);
    if ((h & 4U) != 0U) {
        g = (h & 8U) == 0U ? vec2(g.x * 1.41421356, 0.0) : vec2(0.0, g.y * 1.41421356);
    }
    return g;
}

// kit_gradient_noise(p): smooth noise without value noise's blocky look (Perlin-style).
//   p   any position, cells 1 unit wide
//   ->  about -1..1, 0 at every whole-number point
//   cost: 4 hashes + quintic fade
//   e.g. float n = 0.5 + 0.5 * kit_gradient_noise(uv * 6.0);
float kit_gradient_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    uvec2 c = uvec2(ivec2(i));
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = dot(kit__gradient(kit_hash_u(c)), f);
    float b = dot(kit__gradient(kit_hash_u(c + uvec2(1U, 0U))), f - vec2(1.0, 0.0));
    float d = dot(kit__gradient(kit_hash_u(c + uvec2(0U, 1U))), f - vec2(0.0, 1.0));
    float e = dot(kit__gradient(kit_hash_u(c + uvec2(1U, 1U))), f - vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

// kit_fbm(p, octaves): fractal (layered) value noise: clouds, terrain, smoke.
// Each octave is twice as fine, half as strong, and rotated to hide the grid.
//   p        any position
//   octaves  1..12 (more = more detail, more cost)
//   ->       0..1
//   cost:    octaves x kit_value_noise
//   e.g.     float clouds = kit_fbm(uv * 3.0 + vec2(iTime * 0.1, 0.0), 5);
float kit_fbm(vec2 p, int octaves) {
    const mat2 turn = mat2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0, amp = 0.5, total = 0.0;
    for (int o = 0; o < 12; o++) {
        if (o >= octaves) break;
        sum += amp * kit_value_noise(p);
        total += amp;
        p = turn * p * 2.0 + vec2(17.0, 31.0);
        amp *= 0.5;
    }
    return total > 0.0 ? sum / total : 0.0;
}
float kit_fbm(vec3 p, int octaves) {
    float sum = 0.0, amp = 0.5, total = 0.0;
    for (int o = 0; o < 12; o++) {
        if (o >= octaves) break;
        sum += amp * kit_value_noise(p);
        total += amp;
        p = p.yzx * 2.0 + vec3(17.0, 31.0, 47.0);
        amp *= 0.5;
    }
    return total > 0.0 ? sum / total : 0.0;
}
