// shotglass-kit/core: color.glsl
//
// Getting from "light" to pixels: tonemapping, sRGB, palettes and finishing touches.
// shotglass writes your colour to the screen as is, like Shadertoy: if you light a
// scene in linear units, finish with kit_aces and kit_srgb_encode.
// sound: yes
#include "noise.glsl"

// kit_aces(c): squeeze any brightness into 0..1 with a filmic curve, so highlights
// roll off instead of clipping (Narkowicz's ACES fit).
//   c   linear colour, 0..anything
//   ->  linear colour, 0..1
//   e.g. col = kit_srgb_encode(kit_aces(col * exposure));
vec3 kit_aces(vec3 c) {
    c = max(c, 0.0);
    return clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0);
}

// kit_srgb_encode(c): linear 0..1 to the display's sRGB (the exact curve, not a 2.2 gamma).
// kit_srgb_decode(c): the reverse, e.g. for a colour picked in a paint program.
vec3 kit_srgb_encode(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
vec3 kit_srgb_decode(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// kit_palette(t, a, b, c, d): a smooth colour ramp, a + b * cos(2 pi (c t + d)).
//   t     usually 0..1
//   a, b  centre and amplitude (both around 0.5 for 0..1 output)
//   c, d  frequency and phase per channel
//   e.g.  vec3 col = kit_palette(n, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
vec3 kit_palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318531 * (c * t + d));
}

// kit_vignette(uv, amount, softness): a multiplier that darkens towards the corners.
//   uv        0..1 across the frame (fragCoord / iResolution.xy)
//   amount    0..1, how dark the corners get
//   softness  0..1, how far in the darkening starts (1 = from the centre)
//   ->        1 in the middle, 1 - amount in the corners
//   e.g.      col *= kit_vignette(uv, 0.4, 0.6);
float kit_vignette(vec2 uv, float amount, float softness) {
    float d = length(uv - 0.5) * 1.41421356;   // 0 centre, 1 corner
    return 1.0 - amount * smoothstep(1.0 - clamp(softness, 0.001, 1.0), 1.0, d);
}

// kit_grain(col, fragCoord, frame, amount): film grain, different every frame.
// It's deterministic (frame n always gets the same grain), so stills and exports match.
//   amount  0..0.2 typically; the grain's full range, in colour units
//   e.g.    col = kit_grain(col, fragCoord, iFrame, 0.04);
vec3 kit_grain(vec3 col, vec2 fragCoord, int frame, float amount) {
    float g = kit_hash(ivec3(ivec2(floor(fragCoord)), frame)) - 0.5;
    return col + g * amount;
}
