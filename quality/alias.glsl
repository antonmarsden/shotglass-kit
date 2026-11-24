// shotglass-kit/quality: alias.glsl
//
// Spatial aliasing: how far each pixel of the frame is from the supersampled reference
// (@reference, `reference = N` in quality.toml). Jaggies, moiré, sparkling detail and
// thin lines that break up all differ from their N×N average; smooth, well filtered
// pictures don't. Measure per pixel: the largest channel difference, 0..1 (1/255 is
// one 8-bit level).
//   params:
//     GAIN  number   heatmap brightness: a difference of 1/GAIN shows white (default 4)
//   typical limits: mean 0.002-0.01 for a clean film (a shader without its own
//   antialiasing scores 0.02 and up); `threshold = 0.1` with `over` counts the pixels
//   that visibly stair-step.
//   reads: @frame, @reference
//   cost: 2 texture reads
//   e.g.  [[metric]]  use = "quality/alias"  mean = { max = 0.01 }
// sound: picture only
#include "ops.glsl"
#ifndef GAIN
#define GAIN 4.0
#endif

void mainMetric(out vec4 value, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float d = kit_q_diff(getFrame(uv).rgb, getReference(uv).rgb);
    value = vec4(kit_q_heat(d * GAIN), d);
}
