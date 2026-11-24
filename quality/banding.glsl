// shotglass-kit/quality: banding.glsl
//
// Gradient stepping: band edges, where a smooth gradient steps by 1..MAXSTEP 8-bit
// levels between flat runs at least RUN pixels long on both sides, across or down the
// frame. An undithered slow gradient is all such edges; a dithered one, or texture,
// has no long flat runs; a flat fill has no steps. Measure per pixel: 1 on a band
// edge, else 0, so the mean is the share of pixels on one (a band every 20 pixels
// scores about 0.05).
//   params:
//     RUN      number, pixels  shortest flat run that makes a band (default 6)
//     MAXSTEP  number, levels  largest step that counts as banding, not an edge (default 2)
//   typical limits: mean max 0.002; dither smooth gradients (kit_grain, or a
//   one-level hash) to pass.
//   reads: @frame
//   cost: 4 RUN + 4 texture reads
//   e.g.  [[metric]]  use = "quality/banding"  mean = { max = 0.002 }
// sound: picture only
#include "ops.glsl"
#ifndef RUN
#define RUN 6.0
#endif
#ifndef MAXSTEP
#define MAXSTEP 2.0
#endif

vec3 kit__q_px(vec2 p) { return getFrame(p / iResolution.xy).rgb * 255.0; }

// Whether the edge between fragCoord and fragCoord + dir is a band edge.
float kit__q_band_along(vec2 fragCoord, vec2 dir) {
    vec3 a = kit__q_px(fragCoord), b = kit__q_px(fragCoord + dir);
    float before = 0.0, after = 0.0;
    int n = int(RUN);
    vec3 pa = a, pb = b;
    for (int k = 1; k < n; k++) {
        vec3 qa = kit__q_px(fragCoord - float(k) * dir);
        vec3 qb = kit__q_px(fragCoord + float(k + 1) * dir);
        before = max(before, kit_q_diff(qa, pa));
        after = max(after, kit_q_diff(qb, pb));
        pa = qa;
        pb = qb;
    }
    // The largest channel step: one channel stepping further than MAXSTEP is an edge.
    return kit_q_band(kit_q_diff(a, b), before, after, MAXSTEP);
}

void mainMetric(out vec4 value, in vec2 fragCoord) {
    float b = max(kit__q_band_along(fragCoord, vec2(1.0, 0.0)),
                  kit__q_band_along(fragCoord, vec2(0.0, 1.0)));
    value = vec4(kit_q_heat(b), b);
}
