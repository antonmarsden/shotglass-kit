// shotglass-kit/quality: picture/flatness.glsl
//
// Flat, toon shading: the share of the frame in soft shading, where the luma ramps
// steadily (LO..HI 8-bit levels per pixel, at the pixel and two pixels either side,
// across or down). Toon-shaded pictures are flat fills with hard or antialiased edges
// between a few levels, and score near 0; smooth (Lambert, gradient) shading scores
// the share of the frame it covers. Gradients gentler than LO levels per pixel read as
// flat (they are banding's business). Measure per pixel: 1 in soft shading, else 0.
//   params:
//     LO  number, levels/pixel  the gentlest slope that counts as shading (default 0.75)
//     HI  number, levels/pixel  the steepest; steeper is an edge (default 16)
//   typical limits: mean max 0.01 for a toon brief.
//   reads: @frame
//   cost: 12 texture reads
//   e.g.  [[metric]]  use = "quality/picture/flatness"  mean = { max = 0.01 }
// sound: picture only
#include "../ops.glsl"
#ifndef LO
#define LO 0.75
#endif
#ifndef HI
#define HI 16.0
#endif

float kit_private_q_level(vec2 p) { return 255.0 * kit_q_luma(getFrame(p / iResolution.xy).rgb); }

// The slope at p along dir, in levels per pixel (central difference).
float kit_private_q_slope(vec2 p, vec2 dir) { return 0.5 * (kit_private_q_level(p + dir) - kit_private_q_level(p - dir)); }

float kit_private_q_soft_along(vec2 p, vec2 dir) {
    return kit_q_soft(kit_private_q_slope(p, dir), kit_private_q_slope(p - 2.0 * dir, dir),
                      kit_private_q_slope(p + 2.0 * dir, dir), LO, HI);
}

void mainMetric(out vec4 value, in vec2 fragCoord) {
    float s = max(kit_private_q_soft_along(fragCoord, vec2(1.0, 0.0)), kit_private_q_soft_along(fragCoord, vec2(0.0, 1.0)));
    value = vec4(kit_q_heat(0.6 * s), s);
}
