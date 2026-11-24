// shotglass-kit/quality: picture/outlines.glsl
//
// Outline width in screen space: each ink pixel's line thickness against the declared
// WIDTH, so lines that swell, thin or pop as things move or scale are caught. A pixel
// is ink when its luma is at most LEVEL; its thickness is the shortest run of ink
// through it across, down or along either diagonal (a diagonal pixel counts sqrt(2)),
// following each run up to MAXW pixels each way. Measure per pixel: |thickness - WIDTH|
// in pixels of the measured frame on ink, 0 elsewhere. Thickness comes in whole pixels,
// so allow about one. Filled dark shapes are thick (up to 2 MAXW + 1) and score high:
// keep fills lighter than LEVEL.
//   params:
//     WIDTH  number, frame heights  the declared line width (default 0.012: 2.6 px at 216)
//     LEVEL  number, 0..1           luma at or below which a pixel is ink (default 0.25)
//     MAXW   number, pixels         how far a run is followed each way (default 12)
//   typical limits: `range = [0, 8]`, `threshold = 1.5`, over = { max = 0.002 } (share
//   of all pixels off by more than 1.5 px), or p99 = { max = 1.5 }.
//   reads: @frame
//   cost: up to 8 MAXW + 1 texture reads on ink pixels, 1 elsewhere
//   e.g.  [[metric]]  use = "quality/picture/outlines"  params = { WIDTH = 0.014 }
//         range = [0, 8]  threshold = 1.5  over = { max = 0.002 }
// sound: picture only
#include "../ops.glsl"
#ifndef WIDTH
#define WIDTH 0.012
#endif
#ifndef LEVEL
#define LEVEL 0.25
#endif
#ifndef MAXW
#define MAXW 12.0
#endif

bool kit__q_ink(vec2 p) {
    if (any(lessThan(p, vec2(0.0))) || any(greaterThan(p, iResolution.xy))) return false;
    return kit_q_luma(getFrame(p / iResolution.xy).rgb) <= LEVEL;
}

// Ink pixels in a row through p along dir (p's own included).
float kit__q_run(vec2 p, vec2 dir) {
    int n = int(MAXW);
    float run = 1.0;
    for (int s = -1; s <= 1; s += 2) {
        for (int k = 1; k <= n; k++) {
            if (!kit__q_ink(p + float(s * k) * dir)) break;
            run += 1.0;
        }
    }
    return run;
}

void mainMetric(out vec4 value, in vec2 fragCoord) {
    if (!kit__q_ink(fragCoord)) {
        value = vec4(0.0);
        return;
    }
    float straight = min(kit__q_run(fragCoord, vec2(1.0, 0.0)), kit__q_run(fragCoord, vec2(0.0, 1.0)));
    float diagonal = min(kit__q_run(fragCoord, vec2(1.0, 1.0)), kit__q_run(fragCoord, vec2(1.0, -1.0)));
    float d = abs(min(straight, 1.41421356 * diagonal) - WIDTH * iResolution.y);
    value = vec4(max(kit_q_heat(d / 4.0), vec3(0.0, 0.0, 0.3)), d);
}
