// shotglass-kit/quality: palette.glsl
//
// Conformance to a declared palette: how far each pixel is from the nearest palette
// colour, as CIE76 ΔE (about 1 is just visible side by side, 2-3 a near match, 10
// plainly different). Antialiased edges blend two palette colours and score in
// between, so judge the share of pixels off the palette, not the maximum.
//   params:
//     PALETTE  list of "#rrggbb"  the palette (default black and white)
//     TOL      number, ΔE         heatmap: a pixel shows red from TOL, white from 4 TOL
//                                 (default 5)
//   typical limits: `range = [0, 50]`, `threshold = 5` and `over = { max = 0.05 }`: at
//   most 5% of the frame (edges included) more than ΔE 5 from the palette.
//   reads: @frame
//   cost: 1 texture read, PALETTE_COUNT kit_q_delta_e
//   e.g.  [[metric]]  use = "quality/palette"  params = { PALETTE = ["#1d2b53", "#ff004d", "#fff1e8"] }
//         range = [0, 50]  threshold = 5  over = { max = 0.05 }
// sound: picture only
#include "ops.glsl"
#ifndef PALETTE
#define PALETTE vec3[2](vec3(0.0), vec3(1.0))
#define PALETTE_COUNT 2
#endif
#ifndef TOL
#define TOL 5.0
#endif

void mainMetric(out vec4 value, in vec2 fragCoord) {
    vec3 c = getFrame(fragCoord / iResolution.xy).rgb;
    vec3 pal[PALETTE_COUNT] = PALETTE;
    float de = 1e9;
    for (int i = 0; i < PALETTE_COUNT; i++) de = min(de, kit_q_delta_e(c, pal[i]));
    value = vec4(kit_q_heat((de - TOL) / (3.0 * TOL) + step(TOL, de) * 0.34), de);
}
