// shotglass-kit/quality: picture/shimmer.glsl
//
// Temporal aliasing: crawl, sparkle and flicker. Each pixel against the average of
// the frames either side (@prev, @next): steady motion and fades change a pixel at a
// steady rate and cancel out, while detail that pops on and off from frame to frame
// (aliased stripes and edges crawling, sub-pixel highlights winking) doesn't. Measure
// per pixel: the largest channel of |frame - (prev + next) / 2|, 0..1. Fast motion of
// sharp detail scores too (an edge crossing a pixel within one frame), so set limits
// per film, from a run you have looked at.
//   params:
//     GAIN  number   heatmap brightness: a value of 1/GAIN shows white (default 4)
//   typical limits: mean max 0.005 for slow camera moves; aliased fine detail in
//   motion scores 0.03 and up.
//   reads: @frame, @prev, @next
//   cost: 3 texture reads
//   e.g.  [[metric]]  use = "quality/picture/shimmer"  mean = { max = 0.005 }
// sound: picture only
#include "../ops.glsl"
#ifndef GAIN
#define GAIN 4.0
#endif

void mainMetric(out vec4 value, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 around = 0.5 * (getPrev(uv).rgb + getNext(uv).rgb);
    float d = kit_q_diff(getFrame(uv).rgb, around);
    value = vec4(kit_q_heat(d * GAIN), d);
}
