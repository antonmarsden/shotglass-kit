// shotglass-kit/transitions: dissolve
//
// Noisy dissolve: blotches of the new shot eat through the old one.
//   scale     > 0                  blotch density across the frame height (default 9)
//   softness  0..0.5               edge blur of the blotches (default 0.08)
//   cost:     both shots render, plus 3 noise lookups per pixel
//   e.g.      transition = { type = "fx/dissolve.glsl", duration = 1.0, params = { scale = 6.0 } }
//
// The hash is the engine's original sin() hash, kept so this renders exactly like the
// built-in "dissolve".
#ifndef scale
#define scale 9.0
#endif
#ifndef softness
#define softness 0.08
#endif
float kit_private_dissolve_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float kit_private_dissolve_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(kit_private_dissolve_hash(i), kit_private_dissolve_hash(i + vec2(1, 0)), f.x),
               mix(kit_private_dissolve_hash(i + vec2(0, 1)), kit_private_dissolve_hash(i + vec2(1, 1)), f.x), f.y);
}
vec4 transition(vec2 uv) {
    vec2 p = uv * vec2(ratio, 1.0) * scale;
    float n = 0.6 * kit_private_dissolve_noise(p) + 0.3 * kit_private_dissolve_noise(p * 2.1)
            + 0.1 * kit_private_dissolve_noise(p * 4.3);
    float t = mix(-softness, 1.0 + softness, progress);
    float m = smoothstep(t - softness, t + softness, n);
    return mix(getToColor(uv), getFromColor(uv), m);
}
