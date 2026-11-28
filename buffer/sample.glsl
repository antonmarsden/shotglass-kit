// shotglass-kit/buffer: sample.glsl
//
// Reading buffer state from a sampler (iChannelN bound to "@prev", "@<buffer>" or a
// `frame = -k` history): texel-exact fetches with wrapped or clamped edges,
// neighbourhoods, Laplacian, gradient, blur, and bilinear reads for zoom, advection
// and other transform feedback. Every read is a texelFetch, so it works the same on
// rgba32f state (which shotglass reads with nearest filtering, float filtering being
// unportable) and needs no derivatives. The maths is in math.glsl (included).
//
// Determinism: functions of the state and their arguments only; `wrap` picks a torus
// (true) or clamped edges (false). Sizes come from textureSize, never the render
// scale. Unit tests have no samplers, so these are tested through the buffer films
// (tests/buffer, tests/buffer-loop) and their maths through math.glsl's unit tests.
// sound: picture only
#include "math.glsl"

ivec2 kit_private_buf_edge(ivec2 p, ivec2 size, bool wrap) {
    if (wrap) return ((p % size) + size) % size;
    return clamp(p, ivec2(0), size - 1);
}

// kit_buf_fetch(s, p, wrap): the state at integer texel p, edges wrapped or clamped.
//   s     the buffer's sampler; p  texel, ivec2(fragCoord) plus an offset
//   wrap  true: the state is a torus; false: edge texels repeat
//   ->    the raw state (no clamp, may be negative or above 1 in float formats)
//   e.g. vec4 c = kit_buf_fetch(iChannel0, ivec2(fragCoord) + ivec2(1, 0), false);
vec4 kit_buf_fetch(sampler2D s, ivec2 p, bool wrap) {
    ivec2 size = textureSize(s, 0);
    return texelFetch(s, kit_private_buf_edge(p, size, wrap), 0);
}

// kit_buf_laplacian(s, p, wrap): the 9-point Laplacian of the state at texel p (see
// math.glsl), per texel squared.
//   cost: 9 fetches
//   e.g. vec4 lap = kit_buf_laplacian(iChannel0, ivec2(fragCoord), true);
vec4 kit_buf_laplacian(sampler2D s, ivec2 p, bool wrap) {
    vec4 edges = kit_buf_fetch(s, p + ivec2(1, 0), wrap) + kit_buf_fetch(s, p - ivec2(1, 0), wrap) +
                 kit_buf_fetch(s, p + ivec2(0, 1), wrap) + kit_buf_fetch(s, p - ivec2(0, 1), wrap);
    vec4 corners = kit_buf_fetch(s, p + ivec2(1, 1), wrap) + kit_buf_fetch(s, p + ivec2(-1, 1), wrap) +
                   kit_buf_fetch(s, p + ivec2(1, -1), wrap) + kit_buf_fetch(s, p - ivec2(1, 1), wrap);
    return kit_buf_laplacian(kit_buf_fetch(s, p, wrap), edges, corners);
}

// kit_buf_neighbours(s, p, wrap): the sum of the 8 texels around p (not p itself): a
// live-neighbour count for kit_buf_life, or a ring average (divide by 8).
//   cost: 8 fetches
vec4 kit_buf_neighbours(sampler2D s, ivec2 p, bool wrap) {
    vec4 sum = vec4(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (x != 0 || y != 0) sum += kit_buf_fetch(s, p + ivec2(x, y), wrap);
        }
    }
    return sum;
}

// kit_buf_gradient(s, p, wrap, w): the central-difference gradient of dot(state, w)
// at texel p: slopes for refraction, normals of a height field, flow from density.
//   w   channel weights, e.g. vec4(1, 0, 0, 0) for red
//   ->  vec2(d/dx, d/dy), per texel
//   cost: 4 fetches
//   e.g. vec2 g = kit_buf_gradient(iChannel0, ivec2(fragCoord), false, vec4(1.0, 0.0, 0.0, 0.0));
vec2 kit_buf_gradient(sampler2D s, ivec2 p, bool wrap, vec4 w) {
    float e = dot(kit_buf_fetch(s, p + ivec2(1, 0), wrap), w);
    float x = dot(kit_buf_fetch(s, p - ivec2(1, 0), wrap), w);
    float n = dot(kit_buf_fetch(s, p + ivec2(0, 1), wrap), w);
    float d = dot(kit_buf_fetch(s, p - ivec2(0, 1), wrap), w);
    return 0.5 * vec2(e - x, n - d);
}

// kit_buf_blur(s, p, wrap): 3x3 binomial blur (1 2 1) of the state at texel p:
// diffusion that keeps the total, softening, bleed.
//   cost: 9 fetches
vec4 kit_buf_blur(sampler2D s, ivec2 p, bool wrap) {
    vec4 edges = kit_buf_fetch(s, p + ivec2(1, 0), wrap) + kit_buf_fetch(s, p - ivec2(1, 0), wrap) +
                 kit_buf_fetch(s, p + ivec2(0, 1), wrap) + kit_buf_fetch(s, p - ivec2(0, 1), wrap);
    vec4 corners = kit_buf_fetch(s, p + ivec2(1, 1), wrap) + kit_buf_fetch(s, p + ivec2(-1, 1), wrap) +
                   kit_buf_fetch(s, p + ivec2(1, -1), wrap) + kit_buf_fetch(s, p - ivec2(1, 1), wrap);
    return (4.0 * kit_buf_fetch(s, p, wrap) + 2.0 * edges + corners) / 16.0;
}

// kit_buf_box(s, p, wrap): 3x3 box average of the state at texel p.
//   cost: 9 fetches
vec4 kit_buf_box(sampler2D s, ivec2 p, bool wrap) {
    return (kit_buf_neighbours(s, p, wrap) + kit_buf_fetch(s, p, wrap)) / 9.0;
}

// kit_buf_sample(s, uv, wrap): bilinear read of the state at any uv, from four
// texelFetches (exact on float state, whatever the channel's filtering).
//   uv  0..1 across the buffer (texel centres at (i + 0.5) / size)
//   cost: 4 fetches
//   e.g. vec4 c = kit_buf_sample(iChannel0, vec2(0.5), false);
vec4 kit_buf_sample(sampler2D s, vec2 uv, bool wrap) {
    vec2 size = vec2(textureSize(s, 0));
    vec2 t = uv * size - 0.5;
    vec2 i = floor(t);
    vec2 f = t - i;
    ivec2 p = ivec2(i);
    vec4 a = kit_buf_fetch(s, p, wrap);
    vec4 b = kit_buf_fetch(s, p + ivec2(1, 0), wrap);
    vec4 c = kit_buf_fetch(s, p + ivec2(0, 1), wrap);
    vec4 d = kit_buf_fetch(s, p + ivec2(1, 1), wrap);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// kit_buf_zoom(s, uv, center, zoom, angle, fade): the previous state zoomed by `zoom`
// and turned by `angle` about `center` (kit_buf_zoom_uv), weighed by
// kit_buf_edge_fade(fade) so nothing smears in from outside: the feedback tunnel.
//   center  uv; zoom  growth per step (> 1 grows); angle  radians per step
//   fade    edge fade width, uv, 0..0.5
//   cost: 4 fetches
//   e.g. vec4 c = kit_buf_zoom(iChannel0, vec2(0.5), vec2(0.5), 0.97, 0.02, 0.05);
vec4 kit_buf_zoom(sampler2D s, vec2 uv, vec2 center, float zoom, float angle, float fade) {
    vec2 size = vec2(textureSize(s, 0));
    vec2 q = kit_buf_zoom_uv(uv, center, zoom, angle, size.x / size.y);
    return kit_buf_sample(s, q, false) * kit_buf_edge_fade(q, fade);
}

// kit_buf_advect(s, uv, vel, dt, wrap): the previous state carried along a velocity
// field for one step (semi-Lagrangian: read where it came from, bilinear).
//   vel  uv per second at uv; dt  step length in seconds (iTimeDelta)
//   cost: 4 fetches
//   e.g. vec4 c = kit_buf_advect(iChannel0, vec2(0.5), vec2(0.0, 0.1), iTimeDelta, false);
vec4 kit_buf_advect(sampler2D s, vec2 uv, vec2 vel, float dt, bool wrap) {
    return kit_buf_sample(s, kit_buf_advect_uv(uv, vel, dt), wrap);
}
