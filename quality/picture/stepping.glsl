// shotglass-kit/quality: picture/stepping.glsl
//
// Animation on twos (or threes): the picture may change only on step frames (OFFSET,
// OFFSET + STEP, ...) and must hold in between. On a frame between steps, the measure
// per pixel is how far it moved from the previous frame (the largest channel
// difference, 0..1); on a step frame it is 0. A film animated on twos scores 0 (to
// within the renderer's noise); one animated on ones does not. Sample frames that land
// on steps say nothing, so judge the max, not the mean, and sample enough frames
// (`count`) that some fall between steps.
//   params:
//     STEP    number, frames  the cadence: 2 = twos, 3 = threes (default 2)
//     OFFSET  number, frames  a film frame that is a step (default 0)
//   typical limits: max = { max = 0.004 } (one 8-bit level, for renderer noise).
//   Limits apply to the whole film: measure a film that is all on one cadence.
//   reads: @frame, @prev
//   cost: 2 texture reads
//   e.g.  [[metric]]  use = "quality/picture/stepping"  params = { STEP = 2 }  max = { max = 0.004 }
// sound: picture only
#include "../ops.glsl"
#ifndef STEP
#define STEP 2.0
#endif
#ifndef OFFSET
#define OFFSET 0.0
#endif

void mainMetric(out vec4 value, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float d = kit_q_diff(getFrame(uv).rgb, getPrev(uv).rgb);
    if (kit_q_on_step(iFrame, int(STEP), int(OFFSET))) d = 0.0;
    value = vec4(kit_q_heat(d * 16.0), d);
}
